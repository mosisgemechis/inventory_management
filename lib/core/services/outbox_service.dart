import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../db/app_database.dart';
import 'sync/device_id_service.dart';
import 'identity_service.dart';

enum OutboxStatus { PENDING, UPLOADING, SYNCED, FAILED, CONFLICT }

enum SyncEventType {
  PRODUCT_CREATED,
  PRODUCT_UPDATED,
  PRODUCT_DELETED,
  PURCHASE_CREATED,
  SALE_CREATED,
  REFUND_CREATED,
  TRANSFER_CREATED,
  INVENTORY_ADJUSTED,
  CUSTOMER_CREATED,
  CUSTOMER_UPDATED,
  SUPPLIER_CREATED,
  SUPPLIER_UPDATED,
  BRANCH_CREATED,
  BRANCH_UPDATED,
  BRANCH_DELETED,
  USER_CREATED,
  USER_UPDATED,
  USER_DELETED,
  SHOP_UPDATED,
  SHOP_DELETED,
  BULK_IMPORT_COMPLETED,
}

class OutboxService {
  final AppDatabase _db;
  final _uuid = const Uuid();

  OutboxService(this._db);

  /// 1. Adds a business event to the local Outbox queue.
  /// Used inside database transactions for atomic consistency.
  ///
  /// The identity envelope (business_id, device_id, user_id, branch_id) is
  /// automatically merged into the event payload so every sync event is
  /// self-describing and the backend can reconstruct the full context.
  Future<String> addEvent({
    required String shopId,
    required String branchId,
    required String userId,
    required SyncEventType eventType,
    required String entityType,
    required String entityId,
    Map<String, dynamic>? payload,
    String? deviceId,
    /// Supply an [IdentityService] to attach the full identity envelope.
    IdentityService? identityService,
  }) async {
    final devId = deviceId ?? await DeviceIdService.getOrCreate();
    final eventId = _uuid.v4();

    final envelope = identityService != null
        ? await identityService.getEnvelope()
        : SyncIdentityEnvelope(
            businessId: shopId,
            userId: userId,
            deviceId: devId,
            branchId: branchId,
          );

    final storedShopRow = await (_db.select(_db.appSettings)..where((t) => t.key.equals('identity_business_id'))).getSingleOrNull();
    final storedActiveRow = await (_db.select(_db.appSettings)..where((t) => t.key.equals('active_shop_id'))).getSingleOrNull();
    final storedShopId = storedShopRow?.value;
    final storedActiveId = storedActiveRow?.value;
    final fallbackShopId = (storedShopId != null && storedShopId.isNotEmpty && storedShopId != 'default_shop')
        ? storedShopId
        : (storedActiveId != null && storedActiveId.isNotEmpty && storedActiveId != 'default_shop')
            ? storedActiveId
            : 'default_shop';

    // Priority: envelope.businessId -> caller shopId -> persistent identity -> 'default_shop'
    final effectiveShopId = (envelope.businessId.isNotEmpty && envelope.businessId != 'default_shop')
        ? envelope.businessId
        : (shopId.isNotEmpty && shopId != 'default_shop' ? shopId : fallbackShopId);
    final effectiveBranchId = envelope.branchId.isNotEmpty
        ? envelope.branchId
        : (branchId.isNotEmpty ? branchId : 'main');

    final actorUserId = envelope.userId.isNotEmpty ? envelope.userId : userId;
    final isUserEntity = entityType.toLowerCase() == 'users' || entityType.toLowerCase() == 'user';
    final eventUserId = isUserEntity ? userId : actorUserId;


    // Merge identity metadata into every event payload so it is self-describing.
    final enrichedPayload = <String, dynamic>{
      'business_id': effectiveShopId,
      'device_id': envelope.deviceId.isNotEmpty ? envelope.deviceId : devId,
      'user_id': eventUserId,
      'actor_user_id': actorUserId,
      'branch_id': effectiveBranchId,
      'event_id': eventId,
      'event_type': eventType.name,
      'entity_type': entityType,
      'entity_id': entityId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      if (payload != null) ...payload,
    };

    await _db.into(_db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            id: eventId,
            shopId: effectiveShopId,
            branchId: Value(effectiveBranchId),
            deviceId: envelope.deviceId.isNotEmpty ? envelope.deviceId : devId,
            userId: eventUserId,
            entityTable: entityType,
            recordId: entityId,
            operation: eventType.name,
            payloadJson: Value(jsonEncode(enrichedPayload)),
            createdAt: Value(DateTime.now().toUtc()),
            updatedAt: Value(DateTime.now().toUtc()),
            attemptCount: const Value(0),
            status: Value(OutboxStatus.PENDING.name),
            schemaVersion: const Value(1),
          ),
          mode: InsertMode.insertOrReplace,
        );

    return eventId;
  }


  /// 2. Retrieves pending/failed events in deterministic order (oldest first).
  /// Excludes events already marked syncing or resolved.
  /// Incorporates intelligent retry backoff checks (exponential retry delays).
  Future<List<SyncOutboxData>> getPendingEvents({int limit = 50}) async {
    final allEligible = await (_db.select(_db.syncOutbox)
          ..where((t) => t.status.equals(OutboxStatus.PENDING.name) | t.status.equals(OutboxStatus.FAILED.name))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();

    final now = DateTime.now().toUtc();
    final List<SyncOutboxData> filtered = [];

    for (final event in allEligible) {
      if (event.status == OutboxStatus.PENDING.name) {
        filtered.add(event);
      } else if (event.status == OutboxStatus.FAILED.name) {
        // Exponential backoff retry delay logic: 2 ^ attemptCount seconds, capped at 1 hour (3600 seconds)
        final attempts = event.attemptCount;
        final delaySeconds = min(pow(2, attempts).toInt(), 3600);
        final lastAttempt = event.lastAttemptAt;
        if (lastAttempt == null || now.difference(lastAttempt).inSeconds >= delaySeconds) {
          filtered.add(event);
        }
      }
      if (filtered.length >= limit) break;
    }
    return filtered;
  }

  /// 3. Mark events as currently uploading/syncing (locks state).
  Future<void> markUploading(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await (_db.update(_db.syncOutbox)..where((t) => t.id.isIn(eventIds))).write(
      SyncOutboxCompanion(
        status: Value(OutboxStatus.UPLOADING.name),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// 4. Confirm events successfully synced with cloud backend acknowledgements.
  Future<void> markSynced(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await (_db.update(_db.syncOutbox)..where((t) => t.id.isIn(eventIds))).write(
      SyncOutboxCompanion(
        status: Value(OutboxStatus.SYNCED.name),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// 5. Record sync failure (triggers intelligent retry loop).
  Future<void> recordFailure(String eventId, String errorMessage) async {
    final row = await (_db.select(_db.syncOutbox)..where((t) => t.id.equals(eventId))).getSingleOrNull();
    final newCount = (row?.attemptCount ?? 0) + 1;

    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(eventId))).write(
      SyncOutboxCompanion(
        status: Value(OutboxStatus.FAILED.name),
        attemptCount: Value(newCount),
        lastError: Value(errorMessage),
        lastAttemptAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// 6. Mark sync conflict (business validation exception detected on cloud backend).
  /// Conflict events are preserved permanently in the Outbox database list.
  Future<void> recordConflict(String eventId, String conflictDetails) async {
    await (_db.update(_db.syncOutbox)..where((t) => t.id.equals(eventId))).write(
      SyncOutboxCompanion(
        status: Value(OutboxStatus.CONFLICT.name),
        lastError: Value(conflictDetails),
        lastAttemptAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// 7. Force status reset on failed/conflict items for manually re-triggering synchronization.
  Future<int> resetFailedForSync() async {
    return (_db.update(_db.syncOutbox)
          ..where((t) => t.status.isIn([OutboxStatus.FAILED.name, OutboxStatus.CONFLICT.name])))
        .write(
      SyncOutboxCompanion(
        status: Value(OutboxStatus.PENDING.name),
        attemptCount: const Value(0),
        lastError: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
