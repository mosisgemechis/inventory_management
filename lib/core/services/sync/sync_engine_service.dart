import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:inventory_manager/core/db/app_database.dart';

import 'device_id_service.dart';
import 'sync_api_client.dart';

enum SyncHealth { idle, syncing, offline, error }

/// Local-first rule: UI reads only from Drift.
/// This engine pushes local mutations (outbox) and pulls remote changes into Drift
/// without ever blocking UI interactions.
class SyncEngineService {
  SyncEngineService({
    required AppDatabase db,
    Connectivity? connectivity,
    Duration tickInterval = const Duration(seconds: 8),
  })  : _db = db,
        _connectivity = connectivity ?? Connectivity(),
        _tickInterval = tickInterval,
        _outbox = SyncOutboxDao(db);

  // Kept for future pull-merge logic.
  // ignore: unused_field
  final AppDatabase _db;
  final Connectivity _connectivity;
  final Duration _tickInterval;
  final SyncOutboxDao _outbox;

  final _healthC = StreamController<SyncHealth>.broadcast();
  Stream<SyncHealth> get healthStream => _healthC.stream;
  SyncHealth _health = SyncHealth.idle;

  final _pendingCountC = StreamController<int>.broadcast();
  Stream<int> get pendingCountStream => _pendingCountC.stream;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<int>? _pendingSub;
  Timer? _timer;
  bool _started = false;
  bool _isSyncing = false;

  void start() {
    if (_started) return;
    _started = true;

    _connSub = _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      _setHealth(online ? SyncHealth.idle : SyncHealth.offline);
      if (online) {
        // ignore: unawaited_futures
        _tick();
      }
    });

    _pendingSub = _outbox.watchPendingCount().listen((c) => _pendingCountC.add(c));

    _timer = Timer.periodic(_tickInterval, (_) {
      // ignore: unawaited_futures
      _tick();
    });
    // ignore: unawaited_futures
    _tick();
  }

  Future<void> stop() async {
    _started = false;
    await _connSub?.cancel();
    await _pendingSub?.cancel();
    _timer?.cancel();
    _connSub = null;
    _pendingSub = null;
    _timer = null;
    _setHealth(SyncHealth.idle);
  }

  void dispose() {
    // ignore: unawaited_futures
    stop();
    _healthC.close();
  }

  /// Placeholder contract:
  /// - Upload: read outbox rows, call FastAPI sync endpoints, then delete successful rows.
  /// - Download: ask backend for deltas since last sync cursor, merge into Drift.
  ///
  /// This implementation is fully offline-first: if base URL / auth are not configured,
  /// it remains local-only while still tracking pending work.
  Future<void> _tick() async {
    if (!_started) return;
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final connResults = await _connectivity.checkConnectivity();
      final online = connResults.any((r) => r != ConnectivityResult.none);
      if (!online) {
        _setHealth(SyncHealth.offline);
        return;
      }

      _setHealth(SyncHealth.syncing);

      final baseUrl = await _db.appSettingsDaoGet('api_base_url');
      if (baseUrl == null || baseUrl.trim().isEmpty) {
        _setHealth(SyncHealth.idle);
        return;
      }

      final accessToken = await _db.appSettingsDaoGet('access_token');
      final client = SyncApiClient(baseUrl: baseUrl.trim(), accessToken: accessToken);

      final deviceId = await DeviceIdService.getOrCreate();

      await _uploadOutbox(client: client, deviceId: deviceId);
      await _pullDeltas(client: client, deviceId: deviceId);

      _setHealth(SyncHealth.idle);
    } catch (_) {
      _setHealth(SyncHealth.error);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _uploadOutbox({
    required SyncApiClient client,
    required String deviceId,
  }) async {
    final batch = await _outbox.getBatch(limit: 50);
    if (batch.isEmpty) return;

    // Shop isolation: never mix shops in one request.
    final shopId = batch.first.shopId;
    if (batch.any((e) => e.shopId != shopId)) {
      for (final row in batch) {
        await _outbox.markAttempt(row.id, error: 'mixed_shop_batch_blocked');
      }
      return;
    }

    final payload = {
      'shopId': shopId,
      'deviceId': deviceId,
      'events': batch.map((e) {
        return {
          'id': e.id,
          'shopId': e.shopId,
          'branchId': e.branchId,
          'deviceId': e.deviceId,
          'userId': e.userId,
          'table': e.entityTable,
          'recordId': e.recordId,
          'op': e.operation,
          'updatedAt': e.updatedAt.toUtc().toIso8601String(),
          'payload': e.payloadJson == null ? null : jsonDecode(e.payloadJson!),
        };
      }).toList(),
    };

    try {
      final resp = await client.postJson('/sync/upload', payload);
      final acked = (resp['ackedEventIds'] as List?)?.whereType<String>().toSet() ?? <String>{};
      for (final row in batch) {
        if (acked.contains(row.id)) {
          await _outbox.deleteById(row.id);
          await _markEntitySynced(row.entityTable, row.recordId);
        } else {
          await _outbox.markAttempt(row.id, error: 'not_acked');
        }
      }
    } catch (e) {
      for (final row in batch) {
        await _outbox.markAttempt(row.id, error: e.toString());
      }
      rethrow;
    }
  }

  Future<void> _pullDeltas({
    required SyncApiClient client,
    required String deviceId,
  }) async {
    final shopId = await _db.appSettingsDaoGet('active_shop_id') ?? '';
    if (shopId.isEmpty) return;
    final cursorKey = 'sync_cursor_$shopId';
    final cursor = await _db.appSettingsDaoGet(cursorKey) ?? '0';

    final resp = await client.getJson(
      '/sync/pull',
      query: {
        'shopId': shopId,
        'deviceId': deviceId,
        'cursor': cursor,
      },
    );

    final newCursor = resp['cursor']?.toString();
    final changes = (resp['changes'] as List?)?.whereType<Map>().toList() ?? const [];

    await _db.transaction(() async {
      for (final raw in changes) {
        final m = Map<String, dynamic>.from(raw);
        final table = m['table']?.toString();
        final op = m['op']?.toString();
        final recordId = m['recordId']?.toString();
        final payload = m['payload'];
        if (table == null || op == null || recordId == null) continue;
        if (m['shopId']?.toString() != shopId) continue; // hard isolation

        if (op == 'delete') {
          await _applyRemoteDelete(table, recordId);
        } else if (payload is Map) {
          await _applyRemoteUpsert(table, recordId, Map<String, dynamic>.from(payload));
        }
      }
    });

    if (newCursor != null && newCursor.isNotEmpty) {
      await _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: cursorKey, value: newCursor),
      );
    }
  }

  Future<void> _markEntitySynced(String table, String recordId) async {
    // Best-effort: mark local record as synced after server ack.
    switch (table) {
      case 'products':
        await (_db.update(_db.products)..where((t) => t.id.equals(recordId))).write(
          ProductsCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'sales':
        await (_db.update(_db.sales)..where((t) => t.id.equals(recordId))).write(
          SalesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'suppliers':
        await (_db.update(_db.suppliers)..where((t) => t.id.equals(recordId))).write(
          SuppliersCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'purchases':
        await (_db.update(_db.purchases)..where((t) => t.id.equals(recordId))).write(
          PurchasesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'batches':
        await (_db.update(_db.batches)..where((t) => t.id.equals(recordId))).write(
          BatchesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'audit_logs':
        await (_db.update(_db.auditLogs)..where((t) => t.id.equals(recordId))).write(
          AuditLogsCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'branches':
        await (_db.update(_db.branches)..where((t) => t.id.equals(recordId))).write(
          BranchesCompanion(
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        break;
      case 'notifications':
        await (_db.update(_db.notifications)..where((t) => t.id.equals(recordId))).write(
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

  Future<void> _applyRemoteUpsert(String table, String recordId, Map<String, dynamic> payload) async {
    // Conflict rule: preserve local unsynced changes.
    // If local is pendingUpload/pendingDelete, skip remote overwrite.
    switch (table) {
      case 'products':
        final local = await (_db.select(_db.products)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (local != null && local.syncStatus != 'synced') return;
        await _db.into(_db.products).insertOnConflictUpdate(
          ProductsCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            branchId: payload['branchId']?.toString() ?? 'main',
            name: payload['name']?.toString() ?? '',
            barcode: Value(payload['barcode']?.toString() ?? ''),
            quantity: (payload['quantity'] as num?)?.toDouble() ?? 0.0,
            buyingPrice: (payload['buyingPrice'] as num?)?.toDouble() ?? 0.0,
            sellingPrice: (payload['sellingPrice'] as num?)?.toDouble() ?? 0.0,
            lowStockThreshold: Value((payload['lowStockThreshold'] as num?)?.toInt() ?? 5),
            expiryDate: Value(DateTime.tryParse(payload['expiryDate']?.toString() ?? '')?.toUtc()),
            batchNumber: Value(payload['batchNumber']?.toString()),
            imageUrl: Value(payload['imageUrl']?.toString()),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'sales':
        final localSale = await (_db.select(_db.sales)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localSale != null && localSale.syncStatus != 'synced') return;
        await _db.into(_db.sales).insertOnConflictUpdate(
          SalesCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            branchId: payload['branchId']?.toString() ?? 'main',
            itemId: payload['itemId']?.toString() ?? '',
            itemName: payload['itemName']?.toString() ?? '',
            quantity: (payload['quantity'] as num?)?.toDouble() ?? 0.0,
            totalPrice: (payload['totalPrice'] as num?)?.toDouble() ?? 0.0,
            profit: (payload['profit'] as num?)?.toDouble() ?? 0.0,
            userId: payload['userId']?.toString() ?? 'unknown',
            username: payload['username']?.toString() ?? 'unknown',
            timestamp: DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
            customerName: Value(payload['customerName']?.toString()),
            isDebt: Value(payload['isDebt'] == true || payload['isDebt'] == 1),
            amountPaid: Value((payload['amountPaid'] as num?)?.toDouble() ?? 0.0),
            debtRemaining: Value((payload['debtRemaining'] as num?)?.toDouble() ?? 0.0),
            saleGroupId: Value(payload['saleGroupId']?.toString()),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'suppliers':
        final localSupplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localSupplier != null && localSupplier.syncStatus != 'synced') return;
        await _db.into(_db.suppliers).insertOnConflictUpdate(
          SuppliersCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            name: payload['name']?.toString() ?? '',
            contact: Value(payload['contact']?.toString()),
            address: Value(payload['address']?.toString()),
            totalTaken: Value((payload['totalTaken'] as num?)?.toDouble() ?? 0.0),
            totalPaid: Value((payload['totalPaid'] as num?)?.toDouble() ?? 0.0),
            remaining: Value((payload['remaining'] as num?)?.toDouble() ?? 0.0),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'purchases':
        final localPurchase = await (_db.select(_db.purchases)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localPurchase != null && localPurchase.syncStatus != 'synced') return;
        await _db.into(_db.purchases).insertOnConflictUpdate(
          PurchasesCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            itemId: payload['itemId']?.toString() ?? '',
            itemName: payload['itemName']?.toString() ?? '',
            barcode: Value(payload['barcode']?.toString() ?? ''),
            quantity: (payload['quantity'] as num?)?.toDouble() ?? 0.0,
            unitCost: (payload['unitCost'] as num?)?.toDouble() ?? 0.0,
            totalCost: (payload['totalCost'] as num?)?.toDouble() ?? 0.0,
            supplierName: Value(payload['supplierName']?.toString()),
            batchNumber: Value(payload['batchNumber']?.toString()),
            expiryDate: Value(DateTime.tryParse(payload['expiryDate']?.toString() ?? '')?.toUtc()),
            timestamp: DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
            branchId: Value(payload['branchId']?.toString() ?? 'main'),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'batches':
        final localBatch = await (_db.select(_db.batches)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localBatch != null && localBatch.syncStatus != 'synced') return;
        await _db.into(_db.batches).insertOnConflictUpdate(
          BatchesCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            itemId: payload['itemId']?.toString() ?? '',
            quantity: (payload['quantity'] as num?)?.toDouble() ?? 0.0,
            buyingPrice: (payload['buyingPrice'] as num?)?.toDouble() ?? 0.0,
            expiryDate: Value(DateTime.tryParse(payload['expiryDate']?.toString() ?? '')?.toUtc()),
            batchNumber: Value(payload['batchNumber']?.toString()),
            timestamp: DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
            branchId: Value(payload['branchId']?.toString() ?? 'main'),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'branches':
        final localBranch = await (_db.select(_db.branches)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localBranch != null && localBranch.syncStatus != 'synced') return;
        await _db.into(_db.branches).insertOnConflictUpdate(
          BranchesCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            name: payload['name']?.toString() ?? '',
            createdAt: DateTime.tryParse(payload['createdAt']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'audit_logs':
        final localLog = await (_db.select(_db.auditLogs)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localLog != null && localLog.syncStatus != 'synced') return;
        await _db.into(_db.auditLogs).insertOnConflictUpdate(
          AuditLogsCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            username: payload['username']?.toString() ?? '',
            action: payload['action']?.toString() ?? '',
            details: payload['details']?.toString() ?? '',
            timestamp: DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc(),
            branchId: Value(payload['branchId']?.toString() ?? 'main'),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      case 'notifications':
        final localNotif = await (_db.select(_db.notifications)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localNotif != null && localNotif.syncStatus != 'synced') return;
        await _db.into(_db.notifications).insertOnConflictUpdate(
          NotificationsCompanion.insert(
            id: recordId,
            shopId: payload['shopId']?.toString() ?? '',
            title: payload['title']?.toString() ?? '',
            message: payload['message']?.toString() ?? '',
            type: payload['type']?.toString() ?? 'info',
            targetRole: Value(payload['targetRole']?.toString()),
            itemId: Value(payload['itemId']?.toString()),
            isRead: Value(payload['isRead'] == true || payload['isRead'] == 1),
            timestamp: Value(DateTime.tryParse(payload['timestamp']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            syncStatus: const Value('synced'),
            lastModified: Value(DateTime.tryParse(payload['lastModified']?.toString() ?? '')?.toUtc() ?? DateTime.now().toUtc()),
            remoteId: Value(payload['remoteId']?.toString()),
            version: Value((payload['version'] as num?)?.toInt() ?? 0),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _applyRemoteDelete(String table, String recordId) async {
    switch (table) {
      case 'products':
        final local = await (_db.select(_db.products)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (local != null && local.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.products)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'sales':
        final localSale = await (_db.select(_db.sales)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localSale != null && localSale.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.sales)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'suppliers':
        final localSupplier = await (_db.select(_db.suppliers)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localSupplier != null && localSupplier.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.suppliers)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'purchases':
        final localPurchase = await (_db.select(_db.purchases)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localPurchase != null && localPurchase.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.purchases)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'batches':
        final localBatch = await (_db.select(_db.batches)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localBatch != null && localBatch.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.batches)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'branches':
        final localBranch = await (_db.select(_db.branches)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localBranch != null && localBranch.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.branches)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'audit_logs':
        final localLog = await (_db.select(_db.auditLogs)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localLog != null && localLog.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.auditLogs)..where((t) => t.id.equals(recordId))).go();
        break;
      case 'notifications':
        final localNotif = await (_db.select(_db.notifications)..where((t) => t.id.equals(recordId))).getSingleOrNull();
        if (localNotif != null && localNotif.syncStatus == 'pendingUpload') return;
        await (_db.delete(_db.notifications)..where((t) => t.id.equals(recordId))).go();
        break;
      default:
        break;
    }
  }

  void _setHealth(SyncHealth next) {
    if (_health == next) return;
    _health = next;
    _healthC.add(next);
  }
}

extension on AppDatabase {
  Future<String?> appSettingsDaoGet(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
