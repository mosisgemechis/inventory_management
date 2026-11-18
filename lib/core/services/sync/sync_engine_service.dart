import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:inventory_manager/core/db/app_database.dart';

import 'connection_service.dart';
import 'device_id_service.dart';
import 'sync_api_client.dart';
import 'api_auth_client.dart';
import '../identity_service.dart';
import '../database_service.dart';
import '../outbox_service.dart';
import '../auth_service.dart';
import '../conflict_service.dart';
import '../../models/models.dart';
import '../subscription_service.dart';

enum SyncHealth { idle, syncing, offline, error }

/// Local-first Sync Engine.
/// Pushes outbox events to FastAPI backend and pulls initial / delta data
/// into Drift SQLite database without ever blocking local UI operations.
class SyncEngineService {
  SyncEngineService({
    required AppDatabase db,
    ConnectionService? connectionService,
    IdentityService? identityService,
    Duration tickInterval = const Duration(seconds: 8),
  })  : _db = db,
        _connection = connectionService ?? ConnectionService(),
        _identity = identityService ?? IdentityService(DatabaseService()),
        _tickInterval = tickInterval,
        _outbox = SyncOutboxDao(db);

  final AppDatabase _db;
  final ConnectionService _connection;
  final IdentityService _identity;
  final Duration _tickInterval;
  final SyncOutboxDao _outbox;

  final _healthC = StreamController<SyncHealth>.broadcast();
  Stream<SyncHealth> get healthStream => _healthC.stream;
  SyncHealth _health = SyncHealth.idle;
  SyncHealth get health => _health;

  final _pendingCountC = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountC.stream;

  StreamSubscription<bool>? _connSub;
  StreamSubscription<int>? _pendingSub;
  Timer? _timer;
  bool _started = false;
  bool _isSyncing = false;
  bool _stopRequested = false;
  bool _authFailed = false;

  /// Set when a reconnect or pending-event trigger fired while a tick was running.
  /// The next tick completion will re-trigger once to avoid losing the event.
  bool _reconnectPending = false;
  bool get isSyncing => _isSyncing;
  bool get isAuthFailed => _authFailed;

  void start({String? customBaseUrl}) {
    _stopRequested = false;
    _authFailed = false;
    if (_started) return;
    _started = true;
    debugPrint('[SYNC] Engine started');

    _connection.initialize(customBaseUrl: customBaseUrl);

    _connSub = _connection.onStatusChanged.listen((online) async {
      _setHealth(online ? SyncHealth.idle : SyncHealth.offline);
      if (online) {
        final resetCount = await OutboxService(_db).resetFailedForSync();
        final pendingCount = await _outbox.pendingCount();
        debugPrint(
            '[SYNC] Reconnect detected — pendingOutbox=$pendingCount failedReset=$resetCount');
        if (_isSyncing) {
          // Tick already running — flag a re-trigger so the event is not lost.
          _reconnectPending = true;
          debugPrint(
              '[SYNC] Tick in progress — reconnect trigger coalesced (_reconnectPending=true)');
        } else {
          // ignore: unawaited_futures
          _tick();
        }
      }
    });

    _pendingSub = _outbox.watchPendingCount().listen((c) {
      if (!_pendingCountC.isClosed) {
        _pendingCountC.add(c);
      }
      if (c > 0 && !_isSyncing) {
        debugPrint('[SYNC] Pending outbox count=$c — triggering tick');
        // ignore: unawaited_futures
        _tick();
      }
    });

    _timer = Timer.periodic(_tickInterval, (_) {
      // ignore: unawaited_futures
      _tick();
    });
    // ignore: unawaited_futures
    _tick();
  }

  void resetAuthFailed() {
    _authFailed = false;
  }

  Future<void> syncNow() async {
    _authFailed = false;
    await _tick();
  }

  /// Synchronously uploads the SHOP_DELETED event for [shopId] to the backend
  /// and waits for an ACK before returning.
  ///
  /// Must be called **before** any local data is wiped or [signOut] is invoked
  /// so that the backend can deactivate the business and revoke all tokens.
  ///
  /// Returns `true` if the backend acknowledged the event, `false` if the
  /// device is offline or the upload failed (caller should still proceed with
  /// local cleanup in that case — the event will re-upload after re-install
  /// via the persisted outbox entry).
  Future<bool> syncShopDeletion(String shopId) async {
    final activeUser = await DatabaseService().getCachedUser();
    final userId = activeUser?['uid'] ?? shopId;
    final deviceId = await DeviceIdService.getOrCreate();

    debugPrint('[SHOP DELETE TRACE]');
    debugPrint('operation_id=$shopId');
    debugPrint('stage=IDENTITY_RESOLVED');
    debugPrint('business_id=$shopId');
    debugPrint('user_id=$userId');
    debugPrint('device_id=$deviceId');

    final service = OutboxService(_db);

    // 1. Find or insert the SHOP_DELETED pending event for this shop
    final pending = await service.getPendingEvents(limit: 100);
    var shopEvents = pending
        .where((e) =>
            e.entityTable == 'shops' &&
            e.shopId == shopId &&
            (e.operation == 'SHOP_DELETED' || e.operation == 'SHOP_UPDATED'))
        .toList();

    if (shopEvents.isEmpty) {
      final eventId = await service.addEvent(
        shopId: shopId,
        branchId: activeUser?['branchId'] ?? 'main',
        userId: userId,
        eventType: SyncEventType.SHOP_DELETED,
        entityType: 'shops',
        entityId: shopId,
        payload: {
          'shopId': shopId,
          'businessId': shopId,
          'business_id': shopId,
          'isActive': false,
          'is_active': false,
          'event_type': 'SHOP_DELETED',
        },
      );
      debugPrint('[SHOP DELETE TRACE]');
      debugPrint('operation_id=$shopId');
      debugPrint('stage=EVENT_CREATED');
      debugPrint('[SHOP DELETE TRACE]');
      debugPrint('operation_id=$shopId');
      debugPrint('stage=OUTBOX_INSERTED');

      final updatedPending = await service.getPendingEvents(limit: 100);
      shopEvents = updatedPending.where((e) => e.id == eventId).toList();
    }

    if (shopEvents.isEmpty) {
      debugPrint(
          '[SHOP DELETE] Error: Could not locate or create SHOP_DELETED event');
      return false;
    }

    final row = shopEvents.first;
    final online = await _connection.checkBackendReachability();
    if (!online) {
      debugPrint(
          '[SHOP DELETE] Offline — cannot upload SHOP_DELETED to backend now.');
      return false;
    }

    final baseUrl =
        (await _db.appSettingsDaoGet('api_base_url')) ?? _connection.baseUrl;
    final accessToken = await _identity.accessToken;
    final client =
        SyncApiClient(baseUrl: baseUrl.trim(), accessToken: accessToken);

    final envelope =
        row.payloadJson != null ? jsonDecode(row.payloadJson!) : {};
    final singleEvent = {
      'id': row.id,
      'business_id': shopId,
      'device_id': envelope['device_id'] ?? deviceId,
      'user_id': envelope['user_id'] ?? row.userId,
      'branch_id': envelope['branch_id'] ?? row.branchId,
      'event_type': 'SHOP_DELETED',
      'entity_type': 'shops',
      'entity_id': shopId,
      'timestamp': row.createdAt.toUtc().toIso8601String(),
      'payload': {
        ...envelope,
        'event_type': 'SHOP_DELETED',
        'business_id': shopId,
        'isActive': false,
      },
    };

    final payload = {
      'shopId': shopId,
      'deviceId': deviceId,
      'events': [singleEvent],
    };

    try {
      await service.markUploading([row.id]);
      debugPrint('[SHOP DELETE TRACE]');
      debugPrint('operation_id=$shopId');
      debugPrint('stage=BACKEND_REQUEST_STARTED');

      final resp = await client.postJson('/sync/events', payload);

      final syncedList =
          (resp['synced'] as List?)?.whereType<String>().toSet() ??
              (resp['ackedEventIds'] as List?)?.whereType<String>().toSet() ??
              <String>{};

      if (syncedList.contains(row.id)) {
        await service.markSynced([row.id]);
        debugPrint('[SHOP DELETE TRACE]');
        debugPrint('operation_id=$shopId');
        debugPrint('stage=BACKEND_RESPONSE');
        debugPrint('acked=true');
        return true;
      } else {
        await service.recordFailure(row.id, 'not_in_synced_list_but_sent');
        debugPrint('[SHOP DELETE TRACE]');
        debugPrint('operation_id=$shopId');
        debugPrint('stage=BACKEND_RESPONSE');
        debugPrint('acked=true');
        return true;
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('401') ||
          errStr.contains('deactivated') ||
          errStr.contains('deleted') ||
          errStr.contains('revoked')) {
        debugPrint('[SHOP DELETE TRACE]');
        debugPrint('operation_id=$shopId');
        debugPrint('stage=BACKEND_RESPONSE');
        debugPrint('status=401_BUSINESS_ALREADY_DELETED');
        debugPrint('acked=true');
        await service.markSynced([row.id]);
        return true;
      }
      debugPrint('[SHOP DELETE] Upload failed: $e');
      await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(row.id)))
          .write(
        SyncOutboxCompanion(
          status: const Value('PENDING'),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return false;
    }
  }

  /// Initial sync: downloads products, categories, customers, suppliers, settings,
  /// users, branches from cloud into local Drift SQLite database.
  Future<void> pullInitialData() async {
    final online = await _connection.checkBackendReachability();
    if (!online) return;

    final baseUrl =
        (await _db.appSettingsDaoGet('api_base_url')) ?? _connection.baseUrl;
    final accessToken = await _identity.accessToken;
    if (baseUrl.trim().isEmpty) return;

    final client =
        SyncApiClient(baseUrl: baseUrl.trim(), accessToken: accessToken);

    try {
      final resp = await client.getJson('/sync/initial');
      await _processInitialPayload(resp);
      debugPrint('[SYNC ENGINE] Initial data sync completed successfully.');
    } catch (e) {
      debugPrint('[SYNC ENGINE] Initial data sync error: $e');
    }
  }

  Future<void> stop() async {
    debugPrint('[SYNC] Waiting for active operations');
    // Signal any running tick to abort its next guard check
    _stopRequested = true;
    _started = false;

    // Cancel subscriptions so no new ticks are triggered
    await _connSub?.cancel();
    await _pendingSub?.cancel();
    _timer?.cancel();
    _connSub = null;
    _pendingSub = null;
    _timer = null;

    // Poll until any in-flight tick finishes (max 3 seconds)
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (_isSyncing && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _connection.dispose();
    _setHealth(SyncHealth.idle);
    debugPrint('[SYNC] Paused');
  }

  Future<void> dispose() async {
    await stop();
    if (!_healthC.isClosed) {
      await _healthC.close();
    }
    if (!_pendingCountC.isClosed) {
      await _pendingCountC.close();
    }
  }

  void _setHealth(SyncHealth h) {
    if (_health != h) {
      _health = h;
      if (!_healthC.isClosed) {
        _healthC.add(h);
      }
    }
  }

  Future<void> _resetUploadingToPending() async {
    try {
      await (_db.update(_db.syncOutbox)
            ..where((t) => t.status.equals('UPLOADING')))
          .write(SyncOutboxCompanion(
        status: const Value('PENDING'),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
    } catch (e) {
      debugPrint('[SYNC ENGINE] Error resetting UPLOADING rows to PENDING: $e');
    }
  }

  Future<void> _tick() async {
    if (!_started || _stopRequested || _authFailed) return;
    if (_isSyncing) return;
    _isSyncing = true;
    _reconnectPending = false;

    try {
      // --- STUCK UPLOADING RECOVERY ---
      try {
        final stuckCutoff =
            DateTime.now().toUtc().subtract(const Duration(minutes: 2));
        final stuckEvents = await (_db.select(_db.syncOutbox)
              ..where((t) =>
                  t.status.equals('UPLOADING') &
                  t.updatedAt.isSmallerThanValue(stuckCutoff)))
            .get();
        if (stuckEvents.isNotEmpty) {
          debugPrint(
              '[SYNC ENGINE] Recovering ${stuckEvents.length} stuck UPLOADING event(s) → PENDING');
          await (_db.update(_db.syncOutbox)
                ..where((t) =>
                    t.status.equals('UPLOADING') &
                    t.updatedAt.isSmallerThanValue(stuckCutoff)))
              .write(SyncOutboxCompanion(
            status: const Value('PENDING'),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
        }
      } catch (recoverErr) {
        debugPrint(
            '[SYNC ENGINE] Stuck-upload recovery failed (non-fatal): $recoverErr');
      }

      final online = await _connection.checkBackendReachability();
      if (!online) {
        _setHealth(SyncHealth.offline);
        debugPrint(
            '[SYNC ENGINE] Backend unreachable during tick — skipping upload+pull');
        return;
      }

      _setHealth(SyncHealth.syncing);

      // Use the URL that ConnectionService already verified via /health probe.
      // Reading api_base_url from appSettings may return a stale value written
      // from a previous session; connection.baseUrl is always current.
      final baseUrl = _connection.baseUrl;
      if (baseUrl.trim().isEmpty) {
        _setHealth(SyncHealth.idle);
        return;
      }

      var accessToken = await _identity.accessToken;
      final deviceId = await DeviceIdService.getOrCreate();
      final pendingBefore = await _outbox.pendingCount();
      debugPrint(
          '[SYNC ENGINE] Tick starting — baseUrl=$baseUrl pendingEvents=$pendingBefore deviceId=$deviceId');

      // Attempt outbox upload
      try {
        await _uploadOutbox(
            baseUrl: baseUrl, accessToken: accessToken, deviceId: deviceId);
      } on HttpException catch (e) {
        if (e.message.contains('401')) {
          debugPrint(
              '[SYNC ENGINE] Access token expired or invalid (401). Attempting silent refresh...');
          final authClient =
              ApiAuthClient(baseUrl: baseUrl, identityService: _identity);
          try {
            final newToken = await authClient.refreshToken();
            if (newToken != null && newToken.isNotEmpty) {
              debugPrint(
                  '[SYNC ENGINE] Token refreshed successfully. Retrying outbox upload...');
              accessToken = newToken;
              await _uploadOutbox(
                  baseUrl: baseUrl, accessToken: newToken, deviceId: deviceId);
            } else {
              debugPrint(
                  '[SYNC ENGINE] Refresh token invalid or revoked (HTTP 401). Halting sync and invalidating local session.');
              _authFailed = true;
              await _resetUploadingToPending();
              _setHealth(SyncHealth.error);
              await AuthService()
                  .handleForcedSecurityLogout(reason: 'session_invalidated');
              return;
            }
          } catch (refreshErr) {
            debugPrint(
                '[SYNC ENGINE] Token refresh failed due to network error (temporary): $refreshErr');
            await _resetUploadingToPending();
            _setHealth(SyncHealth.offline);
            return;
          }
        } else {
          rethrow;
        }
      }

      // --- DEFERRED OFFLINE PASSWORD CHANGE FLUSH ---
      await _flushPendingPasswordChange(
          baseUrl: baseUrl, accessToken: accessToken);

      // Delta pull
      await _pullDeltas(
          baseUrl: baseUrl, accessToken: accessToken, deviceId: deviceId);

      // Keep plan/add-on/scheduled-change state fresh too.
      try {
        await subscriptionService.refresh();
      } catch (e) {
        debugPrint('[SYNC ENGINE] subscription refresh failed: $e');
      }

      _setHealth(SyncHealth.idle);
      debugPrint('[SYNC ENGINE] Tick complete — health=idle');
    } catch (e) {
      debugPrint('[SYNC ENGINE] Sync tick error: $e');
      _setHealth(SyncHealth.error);
    } finally {
      _isSyncing = false;
      // If a reconnect fired while this tick was running, schedule one more tick
      // immediately so the pending events those reconnects triggered are not lost.
      if (_reconnectPending && _started && !_stopRequested && !_authFailed) {
        _reconnectPending = false;
        debugPrint(
            '[SYNC ENGINE] Re-triggering tick for coalesced reconnect event');
        // ignore: unawaited_futures
        _tick();
      }
    }
  }

  Future<void> _uploadOutbox({
    required String baseUrl,
    required String? accessToken,
    required String deviceId,
  }) async {
    final client = SyncApiClient(baseUrl: baseUrl, accessToken: accessToken);
    final service = OutboxService(_db);
    final batch = await service.getPendingEvents(limit: 50);

    debugPrint('[OUTBOX DEBUG] pending event count=${batch.length}');
    if (batch.isEmpty) return;

    debugPrint(
        '[SYNC ENGINE] Sequential outbox upload starting for ${batch.length} pending events.');

    for (final row in batch) {
      if (_stopRequested || !_started || _authFailed) break;

      debugPrint('[OUTBOX DEBUG] selected event_id=${row.id}');
      debugPrint('[OUTBOX DEBUG] event_type=${row.operation}');
      debugPrint('[OUTBOX DEBUG] target_user_id=${row.userId}');
      debugPrint('[OUTBOX DEBUG] current_status=${row.status}');

      final envelope =
          row.payloadJson != null ? jsonDecode(row.payloadJson!) : {};
      final singleEvent = {
        'id': row.id,
        // ── Pydantic SyncEventItem uses camelCase aliases ────────────────
        'shopId': envelope['business_id'] ?? row.shopId,
        'deviceId': envelope['device_id'] ?? row.deviceId,
        'userId': envelope['user_id'] ?? row.userId,
        'branchId': envelope['branch_id'] ?? row.branchId,
        'eventType': row.operation,
        'entityType': row.entityTable,
        'entityId': row.recordId,
        'createdAt': row.createdAt.toUtc().toIso8601String(),
        // ── Keep snake_case duplicates so older server versions still work ─
        'business_id': envelope['business_id'] ?? row.shopId,
        'device_id': envelope['device_id'] ?? row.deviceId,
        'user_id': envelope['user_id'] ?? row.userId,
        'branch_id': envelope['branch_id'] ?? row.branchId,
        'event_type': row.operation,
        'entity_type': row.entityTable,
        'entity_id': row.recordId,
        'timestamp': row.createdAt.toUtc().toIso8601String(),
        'payload': envelope,
      };

      final payload = {
        'shopId': row.shopId,
        'deviceId': deviceId,
        'events': [singleEvent],
      };

      await service.markUploading([row.id]);
      if (row.entityTable == 'users' || row.entityTable == 'user') {
        debugPrint('[SYNC TRACE]');
        debugPrint('event_id=${row.id}');
        debugPrint('stage=UPLOAD_STARTED');
        debugPrint('success=true');
        debugPrint('[USER TRACE]');
        debugPrint('event_id=${row.id}');
        debugPrint('business_id=${row.shopId}');
        debugPrint('actor_user_id=${row.userId}');
        debugPrint('target_user_id=${row.recordId}');
        debugPrint('username=${envelope['username'] ?? ''}');
        debugPrint('email=${envelope['email'] ?? ''}');
        debugPrint('event_type=${row.operation}');
        debugPrint('[USER TRACE]\nuploaded=true');
        debugPrint('[USER SYNC SEND]');
        debugPrint('cloud_user_id=${row.recordId}');
        debugPrint('business_id=${row.shopId}');
        debugPrint('event_id=${row.id}');
      }
      debugPrint('[OUTBOX UPLOAD] event_id=${row.id}');
      debugPrint('[OUTBOX UPLOAD] type=${row.operation}');
      debugPrint('[OUTBOX UPLOAD] target_user_id=${row.userId}');
      debugPrint(
          '[ACCOUNT SYNC] Uploading eventId=${row.id}, type=${row.operation}, targetId=${row.recordId}');

      try {
        final resp = await client.postJson('/sync/events', payload);
        _connection.reportSuccess();
        debugPrint('[OUTBOX RESPONSE] event_id=${row.id}');
        debugPrint('[OUTBOX RESPONSE] status_code=200');
        debugPrint('[OUTBOX RESPONSE] response=$resp');

        final syncedList =
            (resp['synced'] as List?)?.whereType<String>().toSet() ??
                (resp['ackedEventIds'] as List?)?.whereType<String>().toSet() ??
                <String>{};
        final rejectedList =
            (resp['rejectedEvents'] as List?)?.whereType<Map>().toList() ??
                const [];
        final Map<String, String> rejectedMap = {
          for (final r in rejectedList)
            r['id']?.toString() ?? '':
                r['reason']?.toString() ?? 'conflict_rejected'
        };
        final resolutions = (resp['identityResolutions'] as List?)
                ?.whereType<Map>()
                .map((value) => Map<String, dynamic>.from(value))
                .toList() ??
            const <Map<String, dynamic>>[];

        if (syncedList.contains(row.id)) {
          var acknowledgedRecordId = row.recordId;
          for (final resolution in resolutions) {
            if (resolution['eventId']?.toString() != row.id ||
                resolution['entityType']?.toString().toLowerCase() !=
                        'products' &&
                    resolution['entityType']?.toString().toLowerCase() !=
                        'product') {
              continue;
            }
            final sourceId = resolution['sourceId']?.toString() ?? row.recordId;
            final canonicalId = resolution['canonicalId']?.toString() ?? '';
            if (canonicalId.isEmpty || canonicalId == sourceId) continue;
            await _reconcileProductIdentity(
              shopId: row.shopId,
              branchId: resolution['branchId']?.toString() ?? row.branchId,
              sourceProductId: sourceId,
              canonicalProductId: canonicalId,
            );
            acknowledgedRecordId = canonicalId;
          }
          debugPrint('[OUTBOX ACK] event_id=${row.id}');
          debugPrint('[OUTBOX ACK] status changed pendingUpload -> synced');
          debugPrint(
              '[ACCOUNT SYNC] Event acknowledged and synced: eventId=${row.id}');
          await service.markSynced([row.id]);
          final isDeleteOp = row.operation.toLowerCase() == 'delete' ||
              row.operation == 'PRODUCT_DELETED';
          await _markEntitySynced(row.entityTable, acknowledgedRecordId,
              branchId: row.branchId, isDelete: isDeleteOp);
          if (row.entityTable == 'users' || row.entityTable == 'user') {
            debugPrint('[SYNC TRACE]');
            debugPrint('event_id=${row.id}');
            debugPrint('stage=LOCAL_MARKED_SYNCED');
            debugPrint('success=true');
          }
        } else if (rejectedMap.containsKey(row.id)) {
          final reason = rejectedMap[row.id]!;
          debugPrint('[OUTBOX FAILURE] event_id=${row.id} reason=$reason');

          // ── Classify rejection: technical failure vs genuine business conflict ──
          // Technical server errors (NameError, AttributeError, 500-class problems)
          // must NOT be surfaced as permanent business conflicts — they should be
          // retried once the underlying bug is fixed.
          final reasonLower = reason.toLowerCase();
          final isTechnicalError = reasonLower.contains('is not defined') ||
              reasonLower.contains('nameerror') ||
              reasonLower.contains('attributeerror') ||
              reasonLower.contains('typeerror') ||
              reasonLower.contains('internal server error') ||
              reasonLower.contains('unexpected error') ||
              reasonLower.contains('500');

          if (isTechnicalError) {
            // Treat like a network/server failure: preserve the event for retry.
            // Log it prominently so developers can diagnose the backend bug.
            debugPrint(
                '[SERVER BUG] Technical server error rejected event ${row.id}: $reason');
            debugPrint(
                '[SERVER BUG] This is a backend programming error, NOT a business conflict.');
            debugPrint('[SERVER BUG] Event will be retried after cooldown.');
            await service.recordFailure(
                row.id, 'Server technical error (will retry): $reason');
          } else {
            // Genuine business rejection (insufficient stock, validation failure, etc.)
            await service.recordConflict(row.id, reason);

            final opType = row.operation.toLowerCase();
            final isProduct = row.entityTable.contains('product');
            final isSale = row.entityTable.contains('sale');

            // ── Rollback rejected sale: mark rejected & restore deducted batch quantities ──
            if (isSale) {
              // Read current status BEFORE updating so we can skip batch
              // restoration on subsequent retries (idempotency guard).
              final preSale = await (_db.select(_db.sales)
                    ..where((t) => t.id.equals(row.recordId)))
                  .getSingleOrNull();
              final alreadyRejected = preSale?.syncStatus == 'rejected';

              await (_db.update(_db.sales)
                    ..where((t) => t.id.equals(row.recordId)))
                  .write(SalesCompanion(
                syncStatus: const Value('rejected'),
                remoteId: Value('REJECTED: $reason'),
                lastModified: Value(DateTime.now().toUtc()),
              ));

              final localSale = preSale;

              if (localSale != null && !alreadyRejected) {
                final envelopeTmp = row.payloadJson != null
                    ? (jsonDecode(row.payloadJson!) as Map<String, dynamic>)
                    : <String, dynamic>{};
                final targetBatchId =
                    envelopeTmp['batchId']?.toString() ?? localSale.batchId;
                final rawAllocations = envelopeTmp['batchAllocations'] ??
                    envelopeTmp['batch_allocations'];
                final sQty = (envelopeTmp['quantity'] as num?)?.toDouble() ??
                    localSale.quantity;
                final allocations = _parseBatchAllocationsHelper(
                    targetBatchId, rawAllocations, sQty);

                for (final alloc in allocations) {
                  final bId = alloc['batchId']?.toString() ?? '';
                  final allocQty =
                      (alloc['quantity'] as num?)?.toDouble() ?? 0.0;
                  if (bId.isNotEmpty && allocQty > 0) {
                    final b = await (_db.select(_db.batches)
                          ..where((t) => t.id.equals(bId)))
                        .getSingleOrNull();
                    if (b != null) {
                      await (_db.update(_db.batches)
                            ..where((t) => t.id.equals(bId)))
                          .write(BatchesCompanion(
                        quantity: Value(b.quantity + allocQty),
                        lastModified: Value(DateTime.now().toUtc()),
                      ));
                      debugPrint(
                          '[SALE REJECTED] Restored $allocQty units to batch $bId');
                    }
                  }
                }

                if (localSale.itemId.isNotEmpty) {
                  await DatabaseService().forceRecalculate(
                      row.shopId, localSale.itemId,
                      branchId: row.branchId);
                  debugPrint(
                      '[SALE REJECTED] Recalculated stock for ${localSale.itemId} after restoring batches');
                }
              }

              // Update local audit log so this sale attempt is explicitly marked REJECTED
              final auditLogId = 'audit_sale_${row.recordId}';
              final envelopeTmp = row.payloadJson != null
                  ? (jsonDecode(row.payloadJson!) as Map<String, dynamic>)
                  : <String, dynamic>{};
              final rejItemName = envelopeTmp['itemName']?.toString() ??
                  envelopeTmp['item_name']?.toString() ??
                  localSale?.itemName ??
                  'Unknown Product';
              final rejQty = (envelopeTmp['quantity'] as num?)?.toDouble() ??
                  localSale?.quantity ??
                  0.0;
              final rejAmt = (envelopeTmp['totalPrice'] as num?)?.toDouble() ??
                  localSale?.totalPrice ??
                  0.0;
              final rejUser = envelopeTmp['username']?.toString() ??
                  localSale?.username ??
                  row.userId;
              final rejDetails =
                  '[REJECTED SALE ATTEMPT] Attempted to sell ${rejQty.toStringAsFixed(0)} units of "$rejItemName". '
                  'Attempted Amount (NOT revenue): ${rejAmt.toStringAsFixed(2)}. '
                  'Status: Rejected. Reason: $reason. (Sale ID: ${row.recordId})';

              await _db.into(_db.auditLogs).insertOnConflictUpdate(
                    AuditLogsCompanion.insert(
                      id: auditLogId,
                      shopId: row.shopId,
                      username: rejUser,
                      action: 'SALE_REJECTED',
                      details: rejDetails,
                      timestamp: DateTime.now().toUtc(),
                      branchId: Value(row.branchId.isEmpty ? 'main' : row.branchId),
                      syncStatus: const Value('synced'),
                      lastModified: Value(DateTime.now().toUtc()),
                    ),
                  );
            }
            final conflictType = isSale
                ? ConflictType.saleRejected
                : isProduct
                    ? ConflictType.productEditConflict
                    : ConflictType.outboxRejected;

            final envelope2 = row.payloadJson != null
                ? (jsonDecode(row.payloadJson!) as Map<String, dynamic>)
                : <String, dynamic>{};
            final entityName = envelope2['name']?.toString() ??
                envelope2['itemName']?.toString() ??
                envelope2['item_name']?.toString() ??
                row.recordId;
            final saleQty = (envelope2['quantity'] as num?)?.toDouble();
            final itemName = envelope2['itemName']?.toString() ??
                envelope2['item_name']?.toString() ??
                entityName;

            // Build plain-language conflict messages.
            final String conflictTitle;
            final String conflictBody;
            final String whatHappened;
            final String whatSystemDid;
            final String requiredAction;

            if (isSale) {
              conflictTitle = 'Sale Could Not Be Completed';
              final qtyStr = saleQty != null
                  ? '${saleQty.toStringAsFixed(0)} unit(s) of '
                  : '';
              conflictBody =
                  'Your sale of $qtyStr"$itemName" was saved on this device but was rejected '
                  'by the server when it synced. The sale has NOT been counted as completed '
                  'and no stock was deducted on the server. '
                  'Reason: $reason';
              whatHappened =
                  'This device recorded a sale of $qtyStr"$itemName" while offline. '
                  'When the sale reached the server it was rejected because: $reason';
              whatSystemDid =
                  'The sale was NOT saved on the server. No revenue, profit, or stock '
                  'changes were applied on the server for this transaction. '
                  'The local record on this device still exists in audit history '
                  'so you can reference the original details.';
              requiredAction =
                  'If the goods were actually dispensed to the customer, re-enter the '
                  'sale once the stock situation is resolved. '
                  'If the goods were NOT dispensed, no further action is required — '
                  'the transaction is cancelled.';
            } else if (isProduct) {
              conflictTitle = 'Product Change Rejected';
              conflictBody =
                  'A change to "$entityName" was rejected by the server. '
                  'Reason: $reason';
              whatHappened =
                  'This device sent a "$opType" operation for "$entityName" '
                  'which was rejected by the server.';
              whatSystemDid = 'The product was not changed on the server. '
                  'The local record on this device may differ from the server.';
              requiredAction =
                  'Review the product record and correct the conflicting data, then retry.';
            } else {
              conflictTitle = 'Sync Operation Rejected';
              conflictBody =
                  'A "$opType" operation on "$entityName" was rejected. '
                  'Reason: $reason';
              whatHappened =
                  'This device sent a "$opType" event that the server rejected.';
              whatSystemDid = 'The operation was not applied on the server.';
              requiredAction =
                  'Review this record and correct the conflicting data, then retry.';
            }

            debugPrint(
                '[OUTBOX CONFLICT] event_id=${row.id} type=$conflictType');
            await ConflictService().record(
              conflictId: 'outbox_rejected_${row.id}',
              shopId: row.shopId,
              branchId: row.branchId.isEmpty ? 'main' : row.branchId,
              type: conflictType,
              affectedEntityType: row.entityTable,
              affectedEntityId: row.recordId,
              affectedEntityName: entityName,
              title: conflictTitle,
              body: conflictBody,
              whatHappened: whatHappened,
              whatSystemDid: whatSystemDid,
              requiredAction: requiredAction,
              requiresAction: true,
              severity:
                  isSale ? ConflictSeverity.high : ConflictSeverity.medium,
              sourceEventId: row.id,
              conflictData: {
                'event_id': row.id,
                'operation': row.operation,
                'entity_table': row.entityTable,
                'entity_id': row.recordId,
                'rejection_reason': reason,
              },
            );
          }
        } else {
          debugPrint('[OUTBOX FAILURE] event_id=${row.id}');
          debugPrint('[OUTBOX FAILURE] status=FAILED');
          debugPrint('[OUTBOX FAILURE] reason=server_not_acknowledged');
          debugPrint(
              '[ACCOUNT SYNC] Event not acknowledged: eventId=${row.id}');
          await service.recordFailure(row.id, 'server_not_acknowledged');
        }
      } catch (e) {
        _connection.reportFailure(e);
        debugPrint('[OUTBOX FAILURE] event_id=${row.id}');
        debugPrint('[OUTBOX FAILURE] status=FAILED');
        debugPrint('[OUTBOX FAILURE] reason=$e');
        debugPrint('[ACCOUNT SYNC] Failed to upload eventId=${row.id}: $e');
        if (e is HttpException && e.message.contains('401')) {
          // Re-throw 401 so _tick can attempt refresh or trigger forced logout without leaving row stuck in UPLOADING
          await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(row.id)))
              .write(
            SyncOutboxCompanion(
              status: const Value('PENDING'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
          rethrow;
        }
        await service.recordFailure(row.id, e.toString());
        // Stop sequential queue loop on network exception
        break;
      }
    }
  }

  /// Replaces a local-only duplicate product ID with the server canonical ID.
  /// All local references move in the same Drift transaction so the next pull
  /// cannot recreate a ghost product or detach its pending sales/batches.
  Future<void> _reconcileProductIdentity({
    required String shopId,
    required String branchId,
    required String sourceProductId,
    required String canonicalProductId,
  }) async {
    await _db.transaction(() async {
      final source = await (_db.select(_db.products)
            ..where((table) =>
                table.id.equals(sourceProductId) & table.shopId.equals(shopId)))
          .getSingleOrNull();
      final canonical = await (_db.select(_db.products)
            ..where((table) =>
                table.id.equals(canonicalProductId) &
                table.shopId.equals(shopId)))
          .getSingleOrNull();

      if (source != null && canonical == null) {
        await _db.customStatement(
          'UPDATE products SET id = ?, remote_id = ? WHERE id = ? AND shop_id = ?',
          [canonicalProductId, canonicalProductId, sourceProductId, shopId],
        );
      } else if (source != null) {
        await (_db.delete(_db.products)
              ..where((table) =>
                  table.id.equals(sourceProductId) &
                  table.shopId.equals(shopId)))
            .go();
      }

      final sourceStocks = await (_db.select(_db.productStocks)
            ..where((table) =>
                table.shopId.equals(shopId) &
                table.productId.equals(sourceProductId)))
          .get();
      for (final stock in sourceStocks) {
        final canonicalStock = await (_db.select(_db.productStocks)
              ..where((table) =>
                  table.shopId.equals(shopId) &
                  table.productId.equals(canonicalProductId) &
                  table.branchId.equals(stock.branchId)))
            .getSingleOrNull();
        if (canonicalStock == null) {
          await _db.customStatement(
            'UPDATE product_stocks SET product_id = ? WHERE shop_id = ? AND product_id = ? AND branch_id = ?',
            [canonicalProductId, shopId, sourceProductId, stock.branchId],
          );
        } else {
          await (_db.delete(_db.productStocks)
                ..where((table) =>
                    table.shopId.equals(shopId) &
                    table.productId.equals(sourceProductId) &
                    table.branchId.equals(stock.branchId)))
              .go();
        }
      }

      await _db.customStatement(
        'UPDATE batches SET item_id = ? WHERE shop_id = ? AND item_id = ?',
        [canonicalProductId, shopId, sourceProductId],
      );
      await _db.customStatement(
        'UPDATE sales SET item_id = ? WHERE shop_id = ? AND item_id = ?',
        [canonicalProductId, shopId, sourceProductId],
      );
      await _db.customStatement(
        'UPDATE purchases SET item_id = ? WHERE shop_id = ? AND item_id = ?',
        [canonicalProductId, shopId, sourceProductId],
      );

      final outboxRows = await (_db.select(_db.syncOutbox)
            ..where((table) => table.shopId.equals(shopId)))
          .get();
      for (final outboxRow in outboxRows) {
        var payload = <String, dynamic>{};
        if (outboxRow.payloadJson != null) {
          try {
            payload =
                Map<String, dynamic>.from(jsonDecode(outboxRow.payloadJson!));
          } catch (_) {}
        }
        var changed = false;
        for (final key in const [
          'id',
          'itemId',
          'item_id',
          'productId',
          'product_id',
          'entity_id'
        ]) {
          if (payload[key]?.toString() == sourceProductId) {
            payload[key] = canonicalProductId;
            changed = true;
          }
        }
        final recordId = outboxRow.recordId == sourceProductId
            ? canonicalProductId
            : outboxRow.recordId;
        if (changed || recordId != outboxRow.recordId) {
          await (_db.update(_db.syncOutbox)
                ..where((table) => table.id.equals(outboxRow.id)))
              .write(SyncOutboxCompanion(
            recordId: Value(recordId),
            payloadJson:
                changed ? Value(jsonEncode(payload)) : const Value.absent(),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
        }
      }

      // Authoritative stock recalculation after relinking all batches to canonical product
      await DatabaseService().forceRecalculate(shopId, canonicalProductId,
          branchId: branchId);
    });
    debugPrint(
        '[PRODUCT IDENTITY] Reconciled $sourceProductId -> $canonicalProductId for $shopId/$branchId');
  }

  /// Flushes a deferred offline password change to the backend.
  /// Called on every sync tick immediately after a successful outbox upload.
  Future<void> _flushPendingPasswordChange({
    required String baseUrl,
    required String? accessToken,
  }) async {
    try {
      final pending = await _db.appSettingsDaoGet('pending_pwd_change');
      if (pending != 'true') return;

      final pendingPwdRaw = await _db.appSettingsDaoGet('pending_pwd_plain');
      if (pendingPwdRaw == null || pendingPwdRaw.isEmpty) {
        // No stored plain password — clear the flag and give up
        await (_db.update(_db.appSettings)
              ..where((t) => t.key.equals('pending_pwd_change')))
            .write(AppSettingsCompanion(value: const Value('')));
        return;
      }

      debugPrint(
          '[SYNC ENGINE] Flushing deferred offline password change to cloud...');
      final authClient =
          ApiAuthClient(baseUrl: baseUrl, identityService: _identity);
      // The pair (old, new) were stored at change time. We only need new since backend
      // verification can be bypassed when token is fresh and session is valid.
      final parts = pendingPwdRaw.split('\x00');
      final oldPwd = parts.length == 2 ? parts[0] : '';
      final newPwd = parts.length == 2 ? parts[1] : pendingPwdRaw;
      if (newPwd.isEmpty) return;

      await authClient.changePassword(oldPassword: oldPwd, newPassword: newPwd);
      // Clear both flags on success
      await (_db.update(_db.appSettings)
            ..where((t) => t.key.equals('pending_pwd_change')))
          .write(AppSettingsCompanion(value: const Value('')));
      await (_db.update(_db.appSettings)
            ..where((t) => t.key.equals('pending_pwd_plain')))
          .write(AppSettingsCompanion(value: const Value('')));
      debugPrint(
          '[SYNC ENGINE] Deferred password change flushed successfully.');
    } catch (e) {
      debugPrint(
          '[SYNC ENGINE] Deferred password change flush failed (will retry): $e');
    }
  }

  Future<void> _pullDeltas({
    required String baseUrl,
    required String? accessToken,
    required String deviceId,
  }) async {
    final shopId = await _db.appSettingsDaoGet('active_shop_id') ?? '';
    if (shopId.isEmpty) return;
    final cursorKey = 'sync_cursor_$shopId';
    final cursor = await _db.appSettingsDaoGet(cursorKey) ?? '0';

    final client = SyncApiClient(baseUrl: baseUrl, accessToken: accessToken);

    try {
      final resp = await client.getJson(
        '/sync/pull',
        query: {
          'shopId': shopId,
          'deviceId': deviceId,
          'cursor': cursor,
        },
      );

      final newCursor = resp['cursor']?.toString();
      final changes =
          (resp['changes'] as List?)?.whereType<Map>().toList() ?? const [];

      // Check if the batch contains a FACTORY_RESET event.
      // Must be processed OUTSIDE _db.transaction because DatabaseService().factoryReset()
      // starts its own transaction to wipe tables and update cursor.
      final resetIndex = changes.indexWhere((raw) {
        final m = Map<String, dynamic>.from(raw);
        final table = m['table']?.toString();
        final op = (m['op']?.toString() ?? '').toUpperCase();
        final payload = m['payload'];
        final pMap = (payload is Map)
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        return op == 'FACTORY_RESET' ||
            table == 'factory_reset' ||
            pMap['action'] == 'FACTORY_RESET' ||
            pMap['event_type'] == 'FACTORY_RESET';
      });

      if (resetIndex != -1) {
        final raw = changes[resetIndex];
        final m = Map<String, dynamic>.from(raw);
        final payload = m['payload'];
        final pMap = (payload is Map)
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
        final targetShopId =
            pMap['shopId']?.toString() ?? m['recordId']?.toString() ?? shopId;

        // Stable event ID for durable consumption tracking across resets
        final resetEventId = m['id']?.toString() ??
            m['event_id']?.toString() ??
            pMap['id']?.toString() ??
            targetShopId;
        final consumedKey =
            'consumed_factory_reset_${targetShopId}_$resetEventId';

        debugPrint('[FACTORY RESET SYNC] received eventId=$resetEventId');

        // Check if this specific factory reset event ID has already been executed on this device
        final existingConsumed = await (_db.select(_db.appSettings)
              ..where((t) => t.key.equals(consumedKey)))
            .getSingleOrNull();

        final alreadyConsumed = existingConsumed != null;
        debugPrint('[FACTORY RESET SYNC] alreadyConsumed=$alreadyConsumed');

        if (alreadyConsumed) {
          debugPrint(
              '[FACTORY RESET SYNC] skipped already-consumed eventId=$resetEventId');
          debugPrint('[FACTORY RESET SYNC] continuing normal pull after reset');
        } else {
          debugPrint('[FACTORY RESET SYNC] applying eventId=$resetEventId');
          await DatabaseService().factoryReset(targetShopId, isFromSync: true);

          // Save consumption marker into appSettings (survives operational DB wipe)
          final nowIso = DateTime.now().toUtc().toIso8601String();
          await _db.into(_db.appSettings).insertOnConflictUpdate(
                AppSettingsCompanion.insert(key: consumedKey, value: nowIso),
              );
          debugPrint(
              '[FACTORY RESET SYNC] consumed marker persisted eventId=$resetEventId');
          debugPrint('[FACTORY RESET SYNC] continuing normal pull after reset');
        }

        if (newCursor != null && newCursor.isNotEmpty) {
          await _db.into(_db.appSettings).insertOnConflictUpdate(
                AppSettingsCompanion.insert(key: cursorKey, value: newCursor),
              );
        }
        return;
      }

      await _db.transaction(() async {
        for (var index = 0; index < changes.length; index++) {
          final raw = changes[index];
          final m = Map<String, dynamic>.from(raw);
          final table = m['table']?.toString();
          final op = m['op']?.toString();
          final recordId = m['recordId']?.toString();
          final payload = m['payload'];
          if (table == null || op == null || recordId == null) continue;
          // Business ID guard: only skip if the event's shopId is explicitly non-empty
          // AND doesn't match our session. The backend already filters by business_id at
          // the query level, so a mismatch here means stale identity data — log it and skip.
          final eventShopId = m['shopId']?.toString() ?? '';
          if (eventShopId.isNotEmpty && eventShopId != shopId) {
            debugPrint(
                '[BUSINESS ID MISMATCH] Skipping pull event: event_shopId=$eventShopId local_shopId=$shopId table=$table recordId=$recordId');
            continue;
          }

          if (table == 'users' || table == 'user') {
            final evId =
                m['id']?.toString() ?? m['event_id']?.toString() ?? recordId;
            debugPrint('[SYNC TRACE]');
            debugPrint('event_id=$evId');
            debugPrint('stage=REMOTE_EVENT_RECEIVED');
            debugPrint('success=true');
            debugPrint('[SYNC TRACE]');
            debugPrint('event_id=$evId');
            debugPrint('stage=REMOTE_EVENT_VALIDATED');
            debugPrint('success=true');
          }

          final opUpper = op.toUpperCase();
          final payloadMap = (payload is Map)
              ? Map<String, dynamic>.from(payload)
              : <String, dynamic>{};

          // ── CONFLICT_ACKNOWLEDGED: propagate remote acknowledgement to local SyncConflict row ──
          if (opUpper == 'CONFLICT_ACKNOWLEDGED') {
            final cid = payloadMap['conflict_id']?.toString() ?? recordId;
            final ackBy = payloadMap['acknowledged_by']?.toString() ?? '';
            final ackUsername =
                payloadMap['acknowledged_username']?.toString() ?? ackBy;
            final ackAtStr = payloadMap['acknowledged_at']?.toString() ?? '';
            final ackAt = DateTime.tryParse(ackAtStr)?.toUtc();
            if (cid.isNotEmpty && ackAt != null) {
              await (_db.update(_db.syncConflicts)
                    ..where((t) => t.conflictId.equals(cid)))
                  .write(
                SyncConflictsCompanion(
                  acknowledgedBy: Value(ackBy),
                  acknowledgedByUsername: Value(ackUsername),
                  acknowledgedAt: Value(ackAt),
                  resolutionStatus: const Value('acknowledged'),
                ),
              );
              debugPrint(
                  '[CONFLICT] Remote acknowledgement applied: conflictId=$cid acknowledgedBy=$ackUsername');
            }
            continue;
          }

          if (opUpper == 'DELETE' ||
              opUpper == 'PRODUCT_DELETED' ||
              opUpper == 'USER_DELETED' ||
              opUpper == 'SHOP_DELETED' ||
              opUpper == 'BUSINESS_DELETED' ||
              opUpper == 'DELETE_ACCOUNT' ||
              opUpper == 'DELETE_SHOP') {
            final targetTable = (opUpper == 'SHOP_DELETED' ||
                    opUpper == 'BUSINESS_DELETED' ||
                    opUpper == 'DELETE_SHOP')
                ? 'shops'
                : table;
            final branchId = payloadMap['branchId']?.toString() ??
                payloadMap['branch_id']?.toString();
            await _applyRemoteDelete(targetTable, recordId, branchId: branchId);
          } else if (payload is Map) {
            final payloadMap = Map<String, dynamic>.from(payload);
            if (eventShopId.isNotEmpty) {
              if (!payloadMap.containsKey('shopId') ||
                  payloadMap['shopId'] == null ||
                  payloadMap['shopId'].toString().isEmpty) {
                payloadMap['shopId'] = eventShopId;
              }
              if (!payloadMap.containsKey('businessId') ||
                  payloadMap['businessId'] == null ||
                  payloadMap['businessId'].toString().isEmpty) {
                payloadMap['businessId'] = eventShopId;
              }
            }
            await _applyRemoteUpsert(table, recordId, payloadMap);
          }
        }
      });

      if (newCursor != null && newCursor.isNotEmpty) {
        await _db.into(_db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(key: cursorKey, value: newCursor),
            );
      }
    } on HttpException catch (e) {
      if (e.message.contains('401')) {
        debugPrint('[SYNC ENGINE] Pull deltas got 401. Attempting refresh...');
        final authClient =
            ApiAuthClient(baseUrl: baseUrl, identityService: _identity);
        final newToken = await authClient.refreshToken();
        if (newToken != null && newToken.isNotEmpty) {
          final retryClient =
              SyncApiClient(baseUrl: baseUrl, accessToken: newToken);
          final resp = await retryClient.getJson('/sync/pull', query: {
            'shopId': shopId,
            'deviceId': deviceId,
            'cursor': cursor
          });
          final newCursor = resp['cursor']?.toString();
          if (newCursor != null && newCursor.isNotEmpty) {
            await _db.into(_db.appSettings).insertOnConflictUpdate(
                  AppSettingsCompanion.insert(key: cursorKey, value: newCursor),
                );
          }
        } else {
          // Refresh also rejected: detect if the business itself was deleted/deactivated
          final errLower = e.message.toLowerCase();
          final isBusinessDeleted =
              (errLower.contains('business') || errLower.contains('shop')) &&
                  (errLower.contains('deactivated') ||
                      errLower.contains('deleted'));
          final logoutReason =
              isBusinessDeleted ? 'business_deleted' : 'session_invalidated';
          debugPrint(
              '[SYNC ENGINE] Refresh rejected. reason=$logoutReason — halting sync.');
          _authFailed = true;
          _setHealth(SyncHealth.error);
          await AuthService().handleForcedSecurityLogout(reason: logoutReason);
        }
      }
    } catch (_) {
      // Pull deltas endpoint is optional or degrades gracefully if backend pull service is not implemented
    }
  }

  Future<void> _processInitialPayload(Map<String, dynamic> resp) async {
    final products =
        (resp['products'] as List?)?.whereType<Map>().toList() ?? [];
    final batches = (resp['batches'] as List?)?.whereType<Map>().toList() ?? [];
    final suppliers =
        (resp['suppliers'] as List?)?.whereType<Map>().toList() ?? [];
    final branches =
        (resp['branches'] as List?)?.whereType<Map>().toList() ?? [];
    final users = (resp['users'] as List?)?.whereType<Map>().toList() ?? [];
    final sales = (resp['sales'] as List?)?.whereType<Map>().toList() ?? [];
    final purchases =
        (resp['purchases'] as List?)?.whereType<Map>().toList() ?? [];
    final auditLogs =
        (resp['auditLogs'] as List?)?.whereType<Map>().toList() ?? [];
    final productStocks =
        (resp['productStocks'] as List?)?.whereType<Map>().toList() ?? [];
    final notifications =
        (resp['notifications'] as List?)?.whereType<Map>().toList() ?? [];

    await _db.transaction(() async {
      for (var index = 0; index < products.length; index++) {
        final p = products[index];
        final m = Map<String, dynamic>.from(p);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('products', id, m);
        }
      }
      for (var index = 0; index < batches.length; index++) {
        final b = batches[index];
        final m = Map<String, dynamic>.from(b);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('batches', id, m);
        }
      }
      for (var index = 0; index < suppliers.length; index++) {
        final s = suppliers[index];
        final m = Map<String, dynamic>.from(s);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('suppliers', id, m);
        }
      }
      for (var index = 0; index < branches.length; index++) {
        final b = branches[index];
        final m = Map<String, dynamic>.from(b);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('branches', id, m);
        }
      }
      for (var index = 0; index < sales.length; index++) {
        final item = sales[index];
        final m = Map<String, dynamic>.from(item);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('sales', id, m);
        }
      }
      for (var index = 0; index < purchases.length; index++) {
        final item = purchases[index];
        final m = Map<String, dynamic>.from(item);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('purchases', id, m);
        }
      }
      for (var index = 0; index < auditLogs.length; index++) {
        final item = auditLogs[index];
        final m = Map<String, dynamic>.from(item);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('audit_logs', id, m);
        }
      }
      for (var index = 0; index < productStocks.length; index++) {
        final item = productStocks[index];
        final m = Map<String, dynamic>.from(item);
        final id = m['id']?.toString() ?? '${m['productId']}@${m['branchId']}';
        await _applyRemoteUpsert('product_stocks', id, m);
      }
      for (var index = 0; index < notifications.length; index++) {
        final item = notifications[index];
        final m = Map<String, dynamic>.from(item);
        final id = m['id']?.toString();
        if (id != null) {
          await _applyRemoteUpsert('notifications', id, m);
        }
      }

      for (var index = 0; index < users.length; index++) {
        final u = users[index];
        final m = Map<String, dynamic>.from(u);
        final id = m['id']?.toString() ?? m['uid']?.toString();
        if (id != null) {
          // Guard: skip users that are explicitly inactive (is_active=false) from initial sync.
          // Active-only users are already filtered by the backend, but double-check client side.
          final isActive = m['isActive'] == true ||
              m['isActive'] == 1 ||
              m['is_active'] == true;
          if (!isActive) {
            debugPrint(
                '[USER SYNC TRACE] stage=SKIPPED reason=user_inactive target_user_id=$id');
            continue;
          }
          await _applyRemoteUpsert('users', id, m);
          final shopIdStr =
              m['shopId']?.toString() ?? m['businessId']?.toString() ?? '';
          debugPrint(
              '[USER SYNC TRACE] operation_id=initial_sync target_user_id=$id business_id=$shopIdStr');
          debugPrint(
              '[USER SYNC TRACE] stage=REMOTE_RECEIVED stage=REMOTE_APPLIED stage=DRIFT_PERSISTED stage=UI_REFRESHED');
        }
      }
    });
  }

  Future<void> _markEntitySynced(String table, String recordId,
      {String? branchId, bool isDelete = false}) async {
    switch (table) {
      case 'products':
        final effectiveBranch = branchId ?? 'main';
        debugPrint(
            '[PRODUCT SYNC] Local entity sync marked: table=products recordId=$recordId branchId=$effectiveBranch isDelete=$isDelete');
        if (isDelete) {
          if (branchId != null && branchId.isNotEmpty) {
            await (_db.delete(_db.products)
                  ..where((t) =>
                      t.id.equals(recordId) & t.branchId.equals(branchId)))
                .go();
            await (_db.delete(_db.productStocks)
                  ..where((t) =>
                      t.productId.equals(recordId) &
                      t.branchId.equals(branchId)))
                .go();
          } else {
            await (_db.delete(_db.products)
                  ..where((t) => t.id.equals(recordId)))
                .go();
            await (_db.delete(_db.productStocks)
                  ..where((t) => t.productId.equals(recordId)))
                .go();
          }
        } else {
          final query = _db.update(_db.products)
            ..where((t) => t.id.equals(recordId));
          if (branchId != null && branchId.isNotEmpty) {
            query.where((t) => t.branchId.equals(branchId));
          }
          await query.write(
            ProductsCompanion(
              syncStatus: const Value('synced'),
              lastModified: Value(DateTime.now().toUtc()),
            ),
          );
        }
        break;
      case 'sales':
        await (_db.update(_db.sales)..where((t) => t.id.equals(recordId)))
            .write(
          SalesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        final existingAudit = await (_db.select(_db.auditLogs)
              ..where((t) => t.id.equals('audit_sale_$recordId')))
            .getSingleOrNull();
        if (existingAudit != null) {
          final updatedDetails = existingAudit.details
              .replaceFirst('Status: Pending synchronization',
                  'Status: Completed / Accepted')
              .replaceFirst('Attempted sale:', 'Completed sale:')
              .replaceFirst('Attempted debt sale:', 'Completed debt sale:')
              .replaceFirst('Attempted Amount:', 'Total Price:')
              .replaceFirst('Attempted Total:', 'Total Price:');
          await (_db.update(_db.auditLogs)
                ..where((t) => t.id.equals('audit_sale_$recordId')))
              .write(
            AuditLogsCompanion(
              details: Value(updatedDetails),
              syncStatus: const Value('synced'),
              lastModified: Value(DateTime.now().toUtc()),
            ),
          );
        }
        break;
      case 'suppliers':
        await (_db.update(_db.suppliers)..where((t) => t.id.equals(recordId)))
            .write(
          SuppliersCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'purchases':
        await (_db.update(_db.purchases)..where((t) => t.id.equals(recordId)))
            .write(
          PurchasesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'batches':
        await (_db.update(_db.batches)..where((t) => t.id.equals(recordId)))
            .write(
          BatchesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'audit_logs':
        await (_db.update(_db.auditLogs)..where((t) => t.id.equals(recordId)))
            .write(
          AuditLogsCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'branches':
        await (_db.update(_db.branches)..where((t) => t.id.equals(recordId)))
            .write(
          BranchesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'notifications':
        await (_db.update(_db.notifications)
              ..where((t) => t.id.equals(recordId)))
            .write(
          NotificationsCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _applyRemoteDelete(String table, String recordId,
      {String? branchId}) async {
    switch (table) {
      case 'products':
        debugPrint(
            '[PRODUCT SYNC] Remote delete applied: table=products recordId=$recordId branchId=$branchId');
        if (branchId != null && branchId.isNotEmpty) {
          await (_db.delete(_db.products)
                ..where(
                    (t) => t.id.equals(recordId) & t.branchId.equals(branchId)))
              .go();
          await (_db.delete(_db.productStocks)
                ..where((t) =>
                    t.productId.equals(recordId) & t.branchId.equals(branchId)))
              .go();
        } else {
          await (_db.delete(_db.products)..where((t) => t.id.equals(recordId)))
              .go();
          await (_db.delete(_db.productStocks)
                ..where((t) => t.productId.equals(recordId)))
              .go();
        }
        break;
      case 'sales':
        await (_db.delete(_db.sales)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'suppliers':
        await (_db.delete(_db.suppliers)..where((t) => t.id.equals(recordId)))
            .go();
        break;
      case 'purchases':
        await (_db.delete(_db.purchases)..where((t) => t.id.equals(recordId)))
            .go();
        break;
      case 'batches':
        final batchRow = await (_db.select(_db.batches)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        await (_db.delete(_db.batches)..where((t) => t.id.equals(recordId)))
            .go();
        if (batchRow != null) {
          await DatabaseService().forceRecalculate(
              batchRow.shopId, batchRow.itemId,
              branchId: batchRow.branchId);
        }
        break;
      case 'audit_logs':
        await (_db.delete(_db.auditLogs)..where((t) => t.id.equals(recordId)))
            .go();
        break;
      case 'branches':
        await (_db.delete(_db.branches)..where((t) => t.id.equals(recordId)))
            .go();
        break;
      case 'user':
      case 'users':
        await (_db.delete(_db.users)..where((t) => t.uid.equals(recordId)))
            .go();
        debugPrint(
            '[ACCOUNT DELETE TRACE]\ntarget_user_id=$recordId\nstage=REMOTE_RECEIVED\nstage=REMOTE_REMOVED\nstage=LOCAL_DELETED\nstage=UI_REFRESHED');
        final activeUserDel = AuthService().user;
        if (activeUserDel != null && activeUserDel.id == recordId) {
          debugPrint(
              '[SECURITY] Remote user deletion detected for $recordId! Forcing logout.');
          await AuthService().signOut();
        }
        break;
      case 'shop':
      case 'shops':
      case 'business':
      case 'businesses':
        debugPrint('[SHOP DELETE TRACE]');
        debugPrint('stage=REMOTE_EVENT_APPLIED');
        debugPrint('business_id=$recordId');
        await DatabaseService()
            .deleteShopAndAccount(recordId, isFromSync: true);
        debugPrint('[SHOP DELETE TRACE]');
        debugPrint('stage=LOCAL_CLEANUP_COMPLETED');
        debugPrint('business_id=$recordId');
        debugPrint('[BUSINESS INVALIDATION]');
        debugPrint('business_id=$recordId');
        debugPrint('reason=BUSINESS_DELETED');
        debugPrint('session_valid=false');
        final activeUserShopDel = AuthService().user;
        if (activeUserShopDel != null && activeUserShopDel.shopId == recordId) {
          debugPrint(
              '[BUSINESS INVALIDATION] Active session belongs to deleted business $recordId — forcing logout.');
          await AuthService()
              .handleForcedSecurityLogout(reason: 'business_deleted');
        }
        break;
      case 'notifications':
        await (_db.delete(_db.notifications)
              ..where((t) => t.id.equals(recordId)))
            .go();
        break;
      default:
        break;
    }
  }

  static bool _parseIsActive(dynamic val) {
    if (val == null) return true;
    if (val == true || val == 1) return true;
    if (val == false || val == 0) return false;
    final s = val.toString().trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return true;
  }

  @visibleForTesting
  Future<void> applyRemoteUpsertForTest(
      String table, String recordId, Map<String, dynamic> payload) =>
      _applyRemoteUpsert(table, recordId, payload);

  Future<void> _applyRemoteUpsert(
      String table, String recordId, Map<String, dynamic> payload) async {
    switch (table) {
      case 'products':
        final effectiveBranch = payload['branchId']?.toString() ??
            payload['branch_id']?.toString() ??
            'main';

        // If the backend signals this product is deleted, apply a local soft-delete.
        final remoteIsDeleted =
            payload['isDeleted'] == true || payload['is_deleted'] == true;
        if (remoteIsDeleted) {
          await (_db.update(_db.products)
                ..where((t) =>
                    t.id.equals(recordId) & t.branchId.equals(effectiveBranch)))
              .write(
                  const ProductsCompanion(syncStatus: Value('pendingDelete')));
          await (_db.delete(_db.products)
                ..where((t) =>
                    t.id.equals(recordId) & t.branchId.equals(effectiveBranch)))
              .go();
          await (_db.delete(_db.productStocks)
                ..where((t) =>
                    t.productId.equals(recordId) &
                    t.branchId.equals(effectiveBranch)))
              .go();
          debugPrint(
              '[PRODUCT SYNC] Remote signalled is_deleted=true: deleted locally recordId=$recordId branchId=$effectiveBranch');
          break;
        }

        final local = await (_db.select(_db.products)
              ..where((t) =>
                  t.id.equals(recordId) & t.branchId.equals(effectiveBranch)))
            .getSingleOrNull();
        if (local != null && local.syncStatus != 'synced') return;

        // Name preservation: never overwrite a valid existing name with blank, placeholder, or stub.
        final rawRemoteName = payload['name']?.toString().trim() ?? '';
        String effectiveName = rawRemoteName;

        final bool isPlaceholderRemote = effectiveName.isEmpty ||
            effectiveName == 'Unnamed Product' ||
            effectiveName.startsWith('[Pending]') ||
            RegExp(r'^Product\s+[0-9a-fA-F-]+$', caseSensitive: false)
                .hasMatch(effectiveName);

        if (isPlaceholderRemote) {
          if (local != null &&
              local.name.trim().isNotEmpty &&
              local.name != 'Unnamed Product' &&
              !local.name.startsWith('[Pending]') &&
              !RegExp(r'^Product\s+[0-9a-fA-F-]+$', caseSensitive: false)
                  .hasMatch(local.name)) {
            effectiveName = local.name;
          } else {
            // Check if product exists in local DB across any branch
            final existingProducts = await (_db.select(_db.products)
                  ..where((t) => t.id.equals(recordId)))
                .get();
            final validRows = existingProducts.where(
                (p) => p.name.trim().isNotEmpty &&
                    p.name != 'Unnamed Product' &&
                    !p.name.startsWith('[Pending]') &&
                    !RegExp(r'^Product\s+[0-9a-fA-F-]+$', caseSensitive: false)
                        .hasMatch(p.name));
            if (validRows.isNotEmpty) {
              effectiveName = validRows.first.name;
            } else {
              final payloadItemName = payload['itemName']?.toString().trim() ??
                  payload['item_name']?.toString().trim() ??
                  '';
              if (payloadItemName.isNotEmpty &&
                  payloadItemName != 'Unnamed Product' &&
                  !payloadItemName.startsWith('[Pending]') &&
                  !RegExp(r'^Product\s+[0-9a-fA-F-]+$', caseSensitive: false)
                      .hasMatch(payloadItemName)) {
                effectiveName = payloadItemName;
              } else if (local != null && local.name.trim().isNotEmpty) {
                effectiveName = local.name;
              }
            }
          }
        }

        final rawExpiry = payload['expiryDate']?.toString() ??
            payload['expiry_date']?.toString() ??
            payload['expiry']?.toString() ??
            payload['exp']?.toString();
        final rawUpdated = payload['lastModified']?.toString() ??
            payload['updatedAt']?.toString() ??
            payload['updated_at']?.toString();

        final incomingShopId = payload['shopId']?.toString() ??
            payload['businessId']?.toString() ??
            payload['business_id']?.toString() ??
            '';
        final incomingQty = (payload['quantity'] as num?)?.toDouble() ??
            (payload['stockQuantity'] as num?)?.toDouble() ??
            (payload['stock_quantity'] as num?)?.toDouble();

        // --- DOUBLE-DECREMENT GUARD ---
        // Check if this device has any pending/uploading outbox events that modify stock
        // (sales, purchases, transfers, adjustments) for this product. If so, the remote
        // quantity snapshot is stale relative to our local changes — DO NOT overwrite stock;
        // let forceRecalculate recompute from the authoritative batch ledger instead.
        bool hasPendingStockEvents = false;
        if (incomingQty != null) {
          final pendingForProduct = await (_db.select(_db.syncOutbox)
                ..where((t) =>
                    t.recordId.equals(recordId) &
                    (t.status.equals('PENDING') |
                        t.status.equals('UPLOADING') |
                        t.status.equals('FAILED'))))
              .get();
          // Also check for pending sale/restock/transfer events for this product as item
          final pendingItemEvents = await (_db.select(_db.syncOutbox)
                ..where((t) =>
                    (t.entityTable.equals('sales') |
                        t.entityTable.equals('batches') |
                        t.entityTable.equals('purchases') |
                        t.entityTable.equals('transfers')) &
                    (t.status.equals('PENDING') |
                        t.status.equals('UPLOADING') |
                        t.status.equals('FAILED'))))
              .get();
          final pendingItemForProduct = pendingItemEvents.where((e) {
            try {
              final p = jsonDecode(e.payloadJson ?? '{}');
              final eid = p['itemId']?.toString() ??
                  p['item_id']?.toString() ??
                  p['productId']?.toString() ??
                  '';
              return eid == recordId;
            } catch (_) {
              return false;
            }
          });
          hasPendingStockEvents =
              pendingForProduct.isNotEmpty || pendingItemForProduct.isNotEmpty;
        }

        debugPrint(
            '[PRODUCT SYNC] Remote upsert: recordId=$recordId branchId=$effectiveBranch name=$effectiveName hasPendingStockEvents=$hasPendingStockEvents');

        await _db.into(_db.products).insertOnConflictUpdate(
              ProductsCompanion.insert(
                id: recordId,
                shopId: incomingShopId,
                branchId: effectiveBranch,
                name: effectiveName,
                barcode: Value(payload['barcode']?.toString() ??
                    payload['sku']?.toString() ??
                    ''),
                // If we have pending stock-modifying events in the outbox, preserve the local
                // quantity to avoid a double-decrement. The canonical quantity will be recomputed
                // by forceRecalculate after all pending events are flushed.
                quantity: (hasPendingStockEvents && local != null)
                    ? local.quantity
                    : (incomingQty ?? local?.quantity ?? 0.0),
                buyingPrice: (payload['buyingPrice'] as num?)?.toDouble() ??
                    (payload['buying_price'] as num?)?.toDouble() ??
                    (payload['costPrice'] as num?)?.toDouble() ??
                    (payload['cost_price'] as num?)?.toDouble() ??
                    0.0,
                sellingPrice: (payload['sellingPrice'] as num?)?.toDouble() ??
                    (payload['selling_price'] as num?)?.toDouble() ??
                    (payload['price'] as num?)?.toDouble() ??
                    0.0,
                lowStockThreshold: Value(
                    (payload['lowStockThreshold'] as num?)?.toInt() ??
                        (payload['min_stock_threshold'] as num?)?.toInt() ??
                        5),
                expiryDate: Value(DateTime.tryParse(rawExpiry ?? '')?.toUtc()),
                batchNumber: Value(payload['batchNumber']?.toString() ??
                    payload['batch_number']?.toString()),
                imageUrl: Value(payload['imageUrl']?.toString() ??
                    payload['image_url']?.toString()),
                syncStatus: const Value('synced'),
                lastModified: Value(
                    DateTime.tryParse(rawUpdated ?? '')?.toUtc() ??
                        DateTime.now().toUtc()),
                remoteId: Value(payload['remoteId']?.toString()),
                version: Value((payload['version'] as num?)?.toInt() ?? 0),
              ),
            );

        // Also sync the product_stocks (POS cache) when the incoming payload carries
        // an explicit quantity — this keeps the POS display correct on secondary devices
        // after refunds, restocks, or transfers without waiting for a batch recalculate.
        if (incomingQty != null &&
            incomingShopId.isNotEmpty &&
            !hasPendingStockEvents) {
          await _db.into(_db.productStocks).insertOnConflictUpdate(
                ProductStocksCompanion.insert(
                  shopId: incomingShopId,
                  productId: recordId,
                  branchId: effectiveBranch,
                  quantity: Value(incomingQty),
                  syncStatus: const Value('synced'),
                  lastModified: Value(DateTime.now().toUtc()),
                ),
              );
          debugPrint(
              '[PRODUCT SYNC] product_stocks updated: productId=$recordId branchId=$effectiveBranch qty=$incomingQty');
        } else if (hasPendingStockEvents && incomingShopId.isNotEmpty) {
          // Recompute from batch ledger to reconcile any in-flight stock events
          await DatabaseService().forceRecalculate(incomingShopId, recordId,
              branchId: effectiveBranch);
          debugPrint(
              '[PRODUCT SYNC] product_stocks skipped snapshot — forceRecalculate ran for $recordId (hasPendingStockEvents=true)');

          // Notify user that their in-flight events took precedence over this snapshot.
          await ConflictService().record(
            conflictId: 'stock_snapshot_${recordId}_${effectiveBranch}',
            shopId: incomingShopId,
            branchId: effectiveBranch,
            type: ConflictType.stockSnapshotConflict,
            affectedEntityType: 'products',
            affectedEntityId: recordId,
            affectedEntityName: effectiveName,
            title: 'Stock Level Conflict Detected',
            body:
                'A stock update for "$effectiveName" arrived from the server while this device had unsent sales or restocks pending. '
                'GM Inventory Everywhere preserved your local stock count and recalculated from your batch records.',
            whatHappened:
                'The server sent a stock snapshot for "$effectiveName" while this device had pending outbox events (sales, purchases, or transfers) for the same product.',
            whatSystemDid:
                'The server snapshot was ignored. Local stock was recalculated from the batch ledger (forceRecalculate). '
                'Once all pending events are flushed to the server the server will emit a fresh authoritative snapshot.',
            requiredAction: null,
            requiresAction: false,
            severity: ConflictSeverity.low,
            conflictData: {
              'product_id': recordId,
              'branch_id': effectiveBranch,
              'server_snapshot_qty': incomingQty,
              'local_qty': local?.quantity,
            },
          );
        }
        break;
      case 'app_settings':
      case 'settings':
      case 'app_setting':
      case 'setting':
        final settingKey = payload['key']?.toString() ?? recordId;
        final settingVal = payload['value']?.toString() ?? '';
        if (settingKey.isNotEmpty &&
            !DatabaseService.isLocalOnlySetting(settingKey)) {
          await DatabaseService()
              .saveSetting(settingKey, settingVal, isFromSync: true);
          debugPrint(
              '[SETTINGS SYNC] Applied remote setting: key=$settingKey value=$settingVal');
        }
        break;
      case 'suppliers':
        final localSupplier = await (_db.select(_db.suppliers)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        if (localSupplier != null && localSupplier.syncStatus != 'synced')
          return;
        await _db.into(_db.suppliers).insertOnConflictUpdate(
              SuppliersCompanion.insert(
                id: recordId,
                shopId: payload['shopId']?.toString() ?? '',
                name: payload['name']?.toString() ?? '',
                contact: Value(payload['phone']?.toString() ??
                    payload['contact']?.toString()),
                address: Value(payload['email']?.toString() ??
                    payload['address']?.toString()),
                syncStatus: const Value('synced'),
                lastModified: Value(
                    DateTime.tryParse(payload['lastModified']?.toString() ?? '')
                            ?.toUtc() ??
                        DateTime.now().toUtc()),
                remoteId: Value(payload['remoteId']?.toString()),
                version: Value((payload['version'] as num?)?.toInt() ?? 0),
              ),
            );
        break;
      case 'branches':
        await _db.into(_db.branches).insertOnConflictUpdate(
              BranchesCompanion.insert(
                id: recordId,
                shopId: payload['shopId']?.toString() ?? '',
                name: payload['name']?.toString() ?? '',
                createdAt: DateTime.now().toUtc(),
                syncStatus: const Value('synced'),
                lastModified: Value(
                    DateTime.tryParse(payload['lastModified']?.toString() ?? '')
                            ?.toUtc() ??
                        DateTime.now().toUtc()),
                remoteId: Value(payload['remoteId']?.toString()),
                version: Value((payload['version'] as num?)?.toInt() ?? 0),
              ),
            );
        break;
      case 'batches':
        final shopId = payload['shopId']?.toString() ??
            payload['businessId']?.toString() ??
            payload['business_id']?.toString() ??
            '';
        final branchId = payload['branchId']?.toString() ??
            payload['branch_id']?.toString() ??
            'main';
        var itemId = payload['itemId']?.toString() ??
            payload['item_id']?.toString() ??
            payload['productId']?.toString() ??
            payload['product_id']?.toString() ??
            '';

        final localBatch = await (_db.select(_db.batches)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        if (itemId.isEmpty && localBatch != null) {
          itemId = localBatch.itemId;
        }
        if (itemId.isEmpty) {
          debugPrint(
              '[BATCH SYNC SKIPPED] Cannot apply batch update for recordId=$recordId because itemId is empty and not found in local DB');
          break;
        }

        final rawExp = payload['expiryDate'] ??
            payload['expiry_date'] ??
            payload['expiry'] ??
            payload['exp'];
        DateTime? expiry;
        if (rawExp is DateTime) {
          expiry = DateTime.utc(rawExp.year, rawExp.month, rawExp.day);
        } else if (rawExp != null && rawExp.toString().trim().isNotEmpty) {
          final parsed = DateTime.tryParse(rawExp.toString());
          if (parsed != null) {
            expiry = DateTime.utc(parsed.year, parsed.month, parsed.day);
          }
        }

        await _db.into(_db.batches).insertOnConflictUpdate(
              BatchesCompanion.insert(
                id: recordId,
                shopId: shopId,
                branchId: Value(branchId),
                itemId: itemId,
                quantity: (payload['quantity'] as num?)?.toDouble() ?? 0.0,
                buyingPrice: (payload['buyingPrice'] as num?)?.toDouble() ??
                    (payload['buying_price'] as num?)?.toDouble() ??
                    (payload['costPrice'] as num?)?.toDouble() ??
                    (payload['cost_price'] as num?)?.toDouble() ??
                    0.0,
                sellingPrice: Value(
                    (payload['sellingPrice'] as num?)?.toDouble() ??
                        (payload['selling_price'] as num?)?.toDouble() ??
                        (payload['price'] as num?)?.toDouble()),
                expiryDate: Value(expiry),
                batchNumber: Value(payload['batchNumber']?.toString() ??
                    payload['batch_number']?.toString()),
                timestamp: DateTime.tryParse(payload['timestamp']?.toString() ??
                            payload['updatedAt']?.toString() ??
                            '')
                        ?.toUtc() ??
                    DateTime.now().toUtc(),
                type: Value(payload['type']?.toString() ?? 'restock'),
                syncStatus: const Value('synced'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
            );

        await DatabaseService()
            .forceRecalculate(shopId, itemId, branchId: branchId);
        debugPrint(
            '[BATCH SYNC] Remote upsert applied: recordId=$recordId itemId=$itemId branchId=$branchId qty=${payload['quantity']} expiry=$expiry');
        break;
      case 'sales':
      case 'sale':
        // Only block overwrite if local copy has pending unsent changes.
        // If the remote has a newer refundedQuantity or amount, always accept.
        final localSale = await (_db.select(_db.sales)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        final remoteRefunded =
            (payload['refundedQuantity'] as num?)?.toDouble() ??
                (payload['refunded_quantity'] as num?)?.toDouble() ??
                0.0;
        final localRefunded = localSale?.refundedQuantity ?? 0.0;
        // Allow remote to win if it has a higher refunded quantity (refund came from another device)
        // or if the local record is already synced (safe to overwrite with latest server state).
        if (localSale != null &&
            localSale.syncStatus != 'synced' &&
            remoteRefunded <= localRefunded) return;

        final rawTs = payload['timestamp']?.toString() ??
            payload['createdAt']?.toString() ??
            payload['created_at']?.toString();
        final ts =
            DateTime.tryParse(rawTs ?? '')?.toUtc() ?? DateTime.now().toUtc();

        final isNewSale = (localSale == null);

        // Serialize incoming batchAllocations into batchId for persistent storage.
        // The secondary device has no batchAllocations column — we encode the full
        // allocation list as JSON into batchId so _saleToMap can decode it on refund.
        final syncRawAllocations =
            payload['batchAllocations'] ?? payload['batch_allocations'];
        String? persistedBatchId;
        if (syncRawAllocations is List && syncRawAllocations.isNotEmpty) {
          try {
            persistedBatchId = jsonEncode(syncRawAllocations);
          } catch (_) {
            persistedBatchId = payload['batchId']?.toString() ??
                payload['batch_id']?.toString();
          }
        } else {
          persistedBatchId =
              payload['batchId']?.toString() ?? payload['batch_id']?.toString();
        }

        await _db.into(_db.sales).insertOnConflictUpdate(
              SalesCompanion.insert(
                id: recordId,
                shopId: payload['shopId']?.toString() ??
                    payload['businessId']?.toString() ??
                    payload['business_id']?.toString() ??
                    '',
                branchId: payload['branchId']?.toString() ??
                    payload['branch_id']?.toString() ??
                    'main',
                itemId: payload['itemId']?.toString() ??
                    payload['item_id']?.toString() ??
                    '',
                itemName: payload['itemName']?.toString() ??
                    payload['item_name']?.toString() ??
                    '',
                quantity: _toDouble(payload['quantity']),
                totalPrice: _toDouble(payload['totalPrice'],
                    _toDouble(payload['total_price'])),
                profit: _toDouble(payload['profit']),
                userId: payload['userId']?.toString() ??
                    payload['user_id']?.toString() ??
                    'unknown',
                username: () {
                  // Prefer the payload username unless it is blank/unknown;
                  // if so, resolve from cached local users by userId.
                  final raw = payload['username']?.toString() ?? '';
                  if (raw.isNotEmpty && raw != 'unknown') return raw;
                  // Will be resolved asynchronously below; seed with userId.
                  return payload['userId']?.toString() ??
                      payload['user_id']?.toString() ??
                      'unknown';
                }(),
                timestamp: ts,
                customerName: Value(payload['customerName']?.toString() ??
                    payload['customer_name']?.toString()),
                isDebt: Value(payload['isDebt'] == true ||
                    payload['is_debt'] == true ||
                    payload['isDebt'] == 1 ||
                    payload['is_debt'] == 1),
                amountPaid: Value(_toDouble(payload['amountPaid'],
                    _toDouble(payload['amount_paid']))),
                debtRemaining: Value(_toDouble(payload['debtRemaining'],
                    _toDouble(payload['debt_remaining']))),
                saleGroupId: Value(payload['saleGroupId']?.toString() ??
                    payload['sale_group_id']?.toString()),
                refundedQuantity: Value(remoteRefunded),
                batchId: Value(persistedBatchId),
                syncStatus: const Value('synced'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
            );

        // Resolve 'unknown' username from cached local users by userId.
        final insertedUserId = payload['userId']?.toString() ??
            payload['user_id']?.toString() ?? '';
        final insertedUsername = payload['username']?.toString() ?? '';
        if ((insertedUsername.isEmpty || insertedUsername == 'unknown') &&
            insertedUserId.isNotEmpty) {
          final userRow = await (_db.select(_db.users)
                ..where((t) => t.uid.equals(insertedUserId)))
              .getSingleOrNull();
          if (userRow != null) {
            final resolvedUsername = userRow.username.isNotEmpty
                ? userRow.username
                : (userRow.email.isNotEmpty ? userRow.email : insertedUserId);
            await (_db.update(_db.sales)
                  ..where((t) => t.id.equals(recordId)))
                .write(SalesCompanion(
              username: Value(resolvedUsername),
            ));
          }
        }

        if (isNewSale) {
          // ONLY deduct batch quantity for BRAND NEW sales arriving on secondary device
          final soldQty = (payload['quantity'] as num?)?.toDouble() ?? 0.0;
          final netSoldQty =
              (soldQty - remoteRefunded).clamp(0.0, double.infinity);

          if (netSoldQty > 0) {
            final rawAllocations =
                payload['batchAllocations'] ?? payload['batch_allocations'];
            if (rawAllocations is List && rawAllocations.isNotEmpty) {
              for (final alloc in rawAllocations) {
                if (alloc is Map) {
                  final bId = alloc['batchId']?.toString() ??
                      alloc['batch_id']?.toString();
                  final dedQty = (alloc['quantity'] as num?)?.toDouble() ?? 0.0;
                  if (bId != null && bId.isNotEmpty && dedQty > 0) {
                    final localBatch = await (_db.select(_db.batches)
                          ..where((t) => t.id.equals(bId)))
                        .getSingleOrNull();
                    if (localBatch != null) {
                      final newQty = (localBatch.quantity - dedQty)
                          .clamp(0.0, double.infinity);
                      await (_db.update(_db.batches)
                            ..where((t) => t.id.equals(bId)))
                          .write(
                        BatchesCompanion(
                          quantity: Value(newQty),
                          lastModified: Value(DateTime.now().toUtc()),
                          syncStatus: const Value('synced'),
                        ),
                      );
                      debugPrint(
                          '[SALE BATCH SYNC] Applied initial batch deduction: saleId=$recordId batchId=$bId deducted=$dedQty newQty=$newQty');
                    }
                  }
                }
              }
            } else {
              final singleBatchId = payload['batchId']?.toString() ??
                  payload['batch_id']?.toString();
              if (singleBatchId != null && singleBatchId.isNotEmpty) {
                final localBatch = await (_db.select(_db.batches)
                      ..where((t) => t.id.equals(singleBatchId)))
                    .getSingleOrNull();
                if (localBatch != null) {
                  final newQty = (localBatch.quantity - netSoldQty)
                      .clamp(0.0, double.infinity);
                  await (_db.update(_db.batches)
                        ..where((t) => t.id.equals(singleBatchId)))
                      .write(
                    BatchesCompanion(
                      quantity: Value(newQty),
                      lastModified: Value(DateTime.now().toUtc()),
                      syncStatus: const Value('synced'),
                    ),
                  );
                  debugPrint(
                      '[SALE BATCH SYNC] Applied single batch deduction: saleId=$recordId batchId=$singleBatchId netSold=$netSoldQty newQty=$newQty');
                }
              }
            }
          }
        } else if (remoteRefunded > localRefunded) {
          // Refund update on EXISTING sale record: restore refunded quantity directly to original batch(es)!
          final deltaRefund = remoteRefunded - localRefunded;
          final targetBatchId = payload['batchId']?.toString() ??
              payload['batch_id']?.toString() ??
              localSale.batchId;
          final rawAllocations =
              payload['batchAllocations'] ?? payload['batch_allocations'];

          final saleQty =
              (payload['quantity'] as num?)?.toDouble() ?? localSale.quantity;
          final allocations = _parseBatchAllocationsHelper(
              targetBatchId, rawAllocations, saleQty);

          if (allocations.isNotEmpty && deltaRefund > 0) {
            double remainingRefund = deltaRefund;
            double alreadyRefundedCount = localRefunded;

            for (final alloc in allocations) {
              if (remainingRefund <= 0.001) break;
              final bId = alloc['batchId']?.toString() ?? '';
              final allocQty = (alloc['quantity'] as num?)?.toDouble() ?? 0.0;
              if (bId.isEmpty || allocQty <= 0) continue;

              if (alreadyRefundedCount >= allocQty) {
                alreadyRefundedCount -= allocQty;
                continue;
              }

              final avail = allocQty - alreadyRefundedCount;
              alreadyRefundedCount = 0;

              final restoreQty =
                  remainingRefund > avail ? avail : remainingRefund;
              if (restoreQty <= 0) continue;

              final localBatch = await (_db.select(_db.batches)
                    ..where((t) => t.id.equals(bId)))
                  .getSingleOrNull();
              if (localBatch != null) {
                final newQty = localBatch.quantity + restoreQty;
                await (_db.update(_db.batches)..where((t) => t.id.equals(bId)))
                    .write(
                  BatchesCompanion(
                    quantity: Value(newQty),
                    lastModified: Value(DateTime.now().toUtc()),
                    syncStatus: const Value('synced'),
                  ),
                );
                debugPrint(
                    '[REFUND SYNC] Restored $restoreQty units to original batch $bId on secondary device (was ${localBatch.quantity}, now $newQty)');
              } else {
                final itemId = payload['itemId']?.toString() ??
                    payload['item_id']?.toString() ??
                    localSale.itemId;
                final branchId = payload['branchId']?.toString() ??
                    payload['branch_id']?.toString() ??
                    localSale.branchId;
                if (itemId.isNotEmpty) {
                  await _db.into(_db.batches).insertOnConflictUpdate(
                        BatchesCompanion.insert(
                          id: bId,
                          shopId: payload['shopId']?.toString() ??
                              payload['businessId']?.toString() ??
                              payload['business_id']?.toString() ??
                              '',
                          branchId: Value(branchId),
                          itemId: itemId,
                          quantity: restoreQty,
                          buyingPrice:
                              (payload['buyingPrice'] as num?)?.toDouble() ??
                                  0.0,
                          sellingPrice: Value(
                              (payload['sellingPrice'] as num?)?.toDouble()),
                          timestamp: DateTime.now().toUtc(),
                          syncStatus: const Value('synced'),
                          lastModified: Value(DateTime.now().toUtc()),
                        ),
                      );
                }
              }
              remainingRefund -= restoreQty;
            }
          }

          final saleShopId = payload['shopId']?.toString() ??
              payload['businessId']?.toString() ??
              payload['business_id']?.toString() ??
              '';
          final saleItemId = payload['itemId']?.toString() ??
              payload['item_id']?.toString() ??
              localSale.itemId;
          final saleBranchId = payload['branchId']?.toString() ??
              payload['branch_id']?.toString() ??
              localSale.branchId;

          if (saleShopId.isNotEmpty && saleItemId.isNotEmpty) {
            await DatabaseService().forceRecalculate(saleShopId, saleItemId,
                branchId: saleBranchId);
          }
        }

        final saleShopId = payload['shopId']?.toString() ??
            payload['businessId']?.toString() ??
            payload['business_id']?.toString() ??
            '';
        final saleItemId = payload['itemId']?.toString() ??
            payload['item_id']?.toString() ??
            '';
        final saleBranchId = payload['branchId']?.toString() ??
            payload['branch_id']?.toString() ??
            'main';
        if (saleShopId.isNotEmpty && saleItemId.isNotEmpty) {
          await DatabaseService()
              .forceRecalculate(saleShopId, saleItemId, branchId: saleBranchId);
        }
        debugPrint(
            '[SALE SYNC] Remote sale upsert applied: recordId=$recordId item=${payload['itemName']} total=${payload['totalPrice']} refunded=$remoteRefunded');
        break;
      case 'purchases':
      case 'purchase':
        final localPurchase = await (_db.select(_db.purchases)
              ..where((t) => t.id.equals(recordId)))
            .getSingleOrNull();
        // Only block if local has pending unsent changes.
        if (localPurchase != null && localPurchase.syncStatus != 'synced')
          return;

        final rawExpP = payload['expiryDate'] ??
            payload['expiry_date'] ??
            payload['expiry'] ??
            payload['exp'];
        DateTime? expP;
        if (rawExpP is DateTime) {
          expP = DateTime.utc(rawExpP.year, rawExpP.month, rawExpP.day);
        } else if (rawExpP != null && rawExpP.toString().trim().isNotEmpty) {
          final parsed = DateTime.tryParse(rawExpP.toString());
          if (parsed != null)
            expP = DateTime.utc(parsed.year, parsed.month, parsed.day);
        }

        final rawTsP = payload['timestamp']?.toString() ??
            payload['createdAt']?.toString() ??
            payload['created_at']?.toString();
        final tsP =
            DateTime.tryParse(rawTsP ?? '')?.toUtc() ?? DateTime.now().toUtc();

        await _db.into(_db.purchases).insertOnConflictUpdate(
              PurchasesCompanion.insert(
                id: recordId,
                shopId: payload['shopId']?.toString() ??
                    payload['businessId']?.toString() ??
                    payload['business_id']?.toString() ??
                    '',
                itemId: payload['itemId']?.toString() ??
                    payload['item_id']?.toString() ??
                    '',
                itemName: payload['itemName']?.toString() ??
                    payload['item_name']?.toString() ??
                    '',
                barcode: Value(payload['barcode']?.toString() ?? ''),
                quantity: (payload['quantity'] as num?)?.toDouble() ?? 0.0,
                unitCost: (payload['unitCost'] as num?)?.toDouble() ??
                    (payload['unit_cost'] as num?)?.toDouble() ??
                    0.0,
                totalCost: (payload['totalCost'] as num?)?.toDouble() ??
                    (payload['total_cost'] as num?)?.toDouble() ??
                    0.0,
                supplierName: Value(payload['supplierName']?.toString() ??
                    payload['supplier_name']?.toString()),
                batchNumber: Value(payload['batchNumber']?.toString() ??
                    payload['batch_number']?.toString()),
                expiryDate: Value(expP),
                timestamp: tsP,
                branchId: Value(payload['branchId']?.toString() ??
                    payload['branch_id']?.toString() ??
                    'main'),
                syncStatus: const Value('synced'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
            );
        debugPrint(
            '[PURCHASE SYNC] Remote purchase upsert applied: recordId=$recordId item=${payload['itemName']} totalCost=${payload['totalCost']}');
        break;
      case 'audit_logs':
      case 'audit_log':
        final rawTsA = payload['timestamp']?.toString() ??
            payload['createdAt']?.toString() ??
            payload['created_at']?.toString();
        final tsA =
            DateTime.tryParse(rawTsA ?? '')?.toUtc() ?? DateTime.now().toUtc();

        await _db.into(_db.auditLogs).insertOnConflictUpdate(
              AuditLogsCompanion.insert(
                id: recordId,
                shopId: payload['shopId']?.toString() ??
                    payload['businessId']?.toString() ??
                    payload['business_id']?.toString() ??
                    '',
                username: payload['username']?.toString() ?? 'unknown',
                action: payload['action']?.toString() ?? 'SYSTEM',
                details: payload['details']?.toString() ?? '',
                timestamp: tsA,
                branchId: Value(payload['branchId']?.toString() ??
                    payload['branch_id']?.toString() ??
                    'main'),
                syncStatus: const Value('synced'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
            );
        break;
      case 'product_stocks':
      case 'product_stock':
        final sShopId = payload['shopId']?.toString() ??
            payload['businessId']?.toString() ??
            payload['business_id']?.toString() ??
            '';
        final sProductId = payload['productId']?.toString() ??
            payload['product_id']?.toString() ??
            '';
        final sBranchId = payload['branchId']?.toString() ??
            payload['branch_id']?.toString() ??
            'main';
        final sQty = (payload['quantity'] as num?)?.toDouble() ?? 0.0;
        if (sShopId.isNotEmpty && sProductId.isNotEmpty) {
          await _db.into(_db.productStocks).insertOnConflictUpdate(
                ProductStocksCompanion.insert(
                  shopId: sShopId,
                  productId: sProductId,
                  branchId: sBranchId,
                  quantity: Value(sQty),
                  syncStatus: const Value('synced'),
                  lastModified: Value(DateTime.now().toUtc()),
                ),
              );
        }
        break;
      case 'notifications':
      case 'notification':
        final rawTsN = payload['timestamp']?.toString() ??
            payload['createdAt']?.toString() ??
            payload['created_at']?.toString();
        final tsN =
            DateTime.tryParse(rawTsN ?? '')?.toUtc() ?? DateTime.now().toUtc();
        final nShopId = payload['shopId']?.toString() ??
            payload['businessId']?.toString() ??
            payload['business_id']?.toString() ??
            '';
        await _db.into(_db.notifications).insertOnConflictUpdate(
              NotificationsCompanion.insert(
                id: recordId,
                shopId: nShopId,
                title: payload['title']?.toString() ?? 'System Notification',
                body: payload['body']?.toString() ??
                    payload['message']?.toString() ??
                    '',
                type: payload['type']?.toString() ?? 'general',
                timestamp: Value(tsN),
                branchId: Value(payload['branchId']?.toString() ??
                    payload['branch_id']?.toString()),
                isRead: Value(
                    payload['isRead'] == true || payload['is_read'] == true),
                priority: Value(payload['priority']?.toString() ?? 'normal'),
                syncStatus: const Value('synced'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
            );
        debugPrint(
            '[NOTIF SYNC] Remote notification upsert applied: recordId=$recordId title=${payload['title']}');

        // If this is a sync conflict notification from the server, also persist it as a
        // SyncConflict record so the user sees it in the Conflict Centre and must
        // explicitly acknowledge it (survives app restart, not just a toast).
        final notifType = payload['type']?.toString() ?? '';
        if (notifType == 'sync_conflict' && nShopId.isNotEmpty) {
          await ConflictService().upsertFromBackendNotification({
            ...payload,
            'id': recordId,
            'shopId': nShopId,
          });
        }
        break;
      case 'users':
      case 'user':
        final uid = recordId;
        final eventShopId = payload['shopId']?.toString() ??
            payload['businessId']?.toString() ??
            payload['business_id']?.toString() ??
            payload['shop_id']?.toString() ??
            '';
        final activeUserShopId = AuthService().user?.shopId ??
            await DatabaseService().getSetting('active_shop_id') ??
            '';

        // BUSINESS ISOLATION GUARD: Reject remote users that belong to other shop accounts
        if (eventShopId.isNotEmpty &&
            activeUserShopId.isNotEmpty &&
            eventShopId != activeUserShopId) {
          debugPrint(
              '[SECURITY] Rejecting remote user sync for $uid: event_shopId ($eventShopId) != active_shopId ($activeUserShopId)');
          break;
        }

        final targetShopId =
            eventShopId.isNotEmpty ? eventShopId : activeUserShopId;
        final username = payload['username']?.toString() ?? '';
        debugPrint(
            '[USER PULL] received user_id=$uid business_id=$targetShopId username=$username');

        if (targetShopId.isNotEmpty) {
          final localUserRow = await (_db.select(_db.users)
                ..where((t) => t.uid.equals(uid)))
              .getSingleOrNull();
          final oldLocalHash = localUserRow?.passwordHash ?? '';

          final rolesList = payload['roles'] is List
              ? (payload['roles'] as List).map((e) => e.toString()).toList()
              : [(payload['role']?.toString() ?? 'inventoryStaff')];
          final emailStr = payload['email']?.toString() ?? '';
          final branchIdStr = payload['branchId']?.toString() ??
              payload['branch_id']?.toString() ??
              'main';
          final isActiveBool =
              _parseIsActive(payload['isActive'] ?? payload['is_active']);

          debugPrint(
              '[USER TRACE] target_user_id=$uid business_id=$targetShopId username=$username active=$isActiveBool');

          final userData = {
            'uid': uid,
            'email': emailStr,
            'username': username,
            'fullName': payload['fullName']?.toString() ??
                payload['name']?.toString() ??
                '',
            'roles': rolesList,
            'shopId': targetShopId,
            'branchId': branchIdStr,
            'branchName': payload['branchName']?.toString() ??
                payload['branch_name']?.toString() ??
                'Main Branch',
            'permissions': (payload['permissions'] != null &&
                    payload['permissions'] is Map &&
                    (payload['permissions'] as Map).isNotEmpty)
                ? payload['permissions']
                : {for (var p in AppUser.allPermissions) p: true},
            'passwordHash': (payload['passwordHash']?.toString() ??
                        payload['password_hash']?.toString() ??
                        '')
                    .isNotEmpty
                ? (payload['passwordHash']?.toString() ??
                    payload['password_hash']?.toString())
                : oldLocalHash,
            'isActive': isActiveBool,
            'cloudUserId': payload['cloudUserId']?.toString() ??
                payload['id']?.toString() ??
                uid,
            'syncEnabled': true,
          };
          await DatabaseService().saveUserRecord(userData, isFromSync: true);
          debugPrint(
              '[USER SYNC UPSERT] cloud_user_id=$uid targetShopId=$targetShopId result=success');

          // Deactivation check only: if backend marks user inactive, force logout.
          // Password-change logout is handled authoritatively by the backend security_revision
          // mechanism (JWT sec_rev mismatch → 401), NOT by local hash comparison.
          // Local hash comparison caused false logouts during initial sync after login.
          final activeUser = AuthService().user;
          if (activeUser != null && activeUser.id == uid) {
            final isDeactivated =
                payload['isActive'] == false || payload['is_active'] == false;
            if (isDeactivated) {
              debugPrint(
                  '[SECURITY] Remote user deactivation detected for $uid! Forcing logout.');
              await AuthService().signOut();
            }
          }
        }
        break;
      case 'factory_reset':
      case 'shops':
      case 'shop':
      case 'businesses':
        final isFactoryReset = payload['action'] == 'FACTORY_RESET' ||
            payload['event_type'] == 'FACTORY_RESET' ||
            payload['operation'] == 'FACTORY_RESET';
        if (isFactoryReset) {
          final targetShopId = payload['shopId']?.toString() ?? recordId;
          debugPrint(
              '[FACTORY RESET SYNC] Remote factory reset event received for shop $targetShopId! Wiping local operational DB.');
          await DatabaseService().factoryReset(targetShopId, isFromSync: true);
          break;
        }
        final isDeactivated = payload['isActive'] == false ||
            payload['is_active'] == false ||
            payload['event_type'] == 'SHOP_DELETED';
        if (isDeactivated) {
          debugPrint(
              '[SHOP DELETE] Remote deletion detected for shop $recordId! Cleaning local DB and forcing logout.');
          await DatabaseService()
              .deleteShopAndAccount(recordId, isFromSync: true);
          final activeUser = AuthService().user;
          if (activeUser != null && activeUser.shopId == recordId) {
            await AuthService().signOut();
          }
        }
        break;
      default:
        break;
    }
  }
}

List<Map<String, dynamic>> _parseBatchAllocationsHelper(
    dynamic rawBatchId, dynamic rawAllocations, double saleQty) {
  if (rawAllocations is List && rawAllocations.isNotEmpty) {
    final res = <Map<String, dynamic>>[];
    for (final e in rawAllocations) {
      if (e is Map) {
        final bId = e['batchId']?.toString() ??
            e['batch_id']?.toString() ??
            e['b']?.toString() ??
            '';
        final q = (e['quantity'] as num?)?.toDouble() ??
            (e['q'] as num?)?.toDouble() ??
            0.0;
        if (bId.isNotEmpty && q > 0) {
          res.add({'batchId': bId, 'quantity': q});
        }
      }
    }
    if (res.isNotEmpty) return res;
  }

  final bStr = rawBatchId?.toString() ?? '';
  if (bStr.isEmpty) return [];

  if (bStr.startsWith('[') && bStr.endsWith(']')) {
    try {
      final parsed = jsonDecode(bStr);
      if (parsed is List) {
        final res = <Map<String, dynamic>>[];
        for (final e in parsed) {
          if (e is Map) {
            final bId = e['batchId']?.toString() ??
                e['batch_id']?.toString() ??
                e['b']?.toString() ??
                '';
            final q = (e['quantity'] as num?)?.toDouble() ??
                (e['q'] as num?)?.toDouble() ??
                0.0;
            if (bId.isNotEmpty && q > 0) {
              res.add({'batchId': bId, 'quantity': q});
            }
          }
        }
        if (res.isNotEmpty) return res;
      }
    } catch (_) {}
  }

  return [
    {'batchId': bStr, 'quantity': saleQty}
  ];
}


/// Safe double parser that handles String, int, and double JSON values.
/// Falls back to [fallback] (default 0.0) when the value is null or unparseable.
double _toDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  if (v is num) return v.toDouble();
  return fallback;
}
extension on AppDatabase {
  Future<String?> appSettingsDaoGet(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }
}
