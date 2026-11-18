import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../db/app_database.dart';
import 'auth_service.dart';
import 'sync/device_id_service.dart';

/// Severity levels for conflict records.
enum ConflictSeverity { high, medium, low }

/// Typed enumeration of every conflict kind supported by GM Inventory Everywhere.
enum ConflictType {
  productDedup,
  productEditConflict,
  deleteTombstone,
  saleOversell,
  saleRejected,
  stockSnapshotConflict,
  batchConflict,
  transferConflict,
  purchaseConflict,
  refundConflict,
  customerDebtConflict,
  outboxRejected,
  userConflict,
  settingsConflict,
  other,
}

extension ConflictTypeX on ConflictType {
  String get key {
    switch (this) {
      case ConflictType.productDedup: return 'product_dedup';
      case ConflictType.productEditConflict: return 'product_edit_conflict';
      case ConflictType.deleteTombstone: return 'delete_tombstone';
      case ConflictType.saleOversell: return 'sale_oversell';
      case ConflictType.saleRejected: return 'sale_rejected';
      case ConflictType.stockSnapshotConflict: return 'stock_snapshot_conflict';
      case ConflictType.batchConflict: return 'batch_conflict';
      case ConflictType.transferConflict: return 'transfer_conflict';
      case ConflictType.purchaseConflict: return 'purchase_conflict';
      case ConflictType.refundConflict: return 'refund_conflict';
      case ConflictType.customerDebtConflict: return 'customer_debt_conflict';
      case ConflictType.outboxRejected: return 'outbox_rejected';
      case ConflictType.userConflict: return 'user_conflict';
      case ConflictType.settingsConflict: return 'settings_conflict';
      case ConflictType.other: return 'other';
    }
  }

  static ConflictType fromKey(String key) {
    return ConflictType.values.firstWhere(
      (e) => e.key == key,
      orElse: () => ConflictType.other,
    );
  }
}

/// Central service for recording, querying, and acknowledging every sync conflict.
///
/// All conflict creation goes through [record()]; it is idempotent — calling it
/// twice with the same [conflictId] (same event replay) never creates a duplicate.
///
/// Acknowledgements are persisted locally and sync to the backend as a
/// CONFLICT_ACKNOWLEDGED outbox event so other devices can learn about them.
class ConflictService {
  static final ConflictService _instance = ConflictService._internal();
  factory ConflictService() => _instance;
  ConflictService._internal();

  AppDatabase? _db;

  void init(AppDatabase db) {
    _db = db;
  }

  AppDatabase get _database {
    assert(_db != null, 'ConflictService.init() must be called before use');
    return _db!;
  }

  // ── RECORD ──────────────────────────────────────────────────────────────────

  /// Record a conflict. Idempotent — safe to call on every sync retry.
  ///
  /// [conflictId] MUST be a stable, deterministic key derived from the
  /// entity/event IDs involved, so that replaying the same event never
  /// creates a duplicate conflict record.
  ///
  /// Example stable IDs:
  ///   - `"product_dedup_${canonicalId}_${duplicateId}"`
  ///   - `"sale_oversell_${saleId}"`
  ///   - `"outbox_rejected_${outboxEventId}"`
  Future<void> record({
    required String conflictId,
    required String shopId,
    required String branchId,
    required ConflictType type,
    required String affectedEntityType,
    required String affectedEntityId,
    String? affectedEntityName,
    required String title,
    required String body,
    String? whatHappened,
    String? whatSystemDid,
    String? requiredAction,
    bool requiresAction = false,
    ConflictSeverity severity = ConflictSeverity.medium,
    String? sourceEventId,
    Map<String, dynamic>? conflictData,
  }) async {
    try {
      final db = _database;
      // Idempotency: if a record already exists for this conflictId, only
      // update the body/title (server may send richer details on retry) but
      // never clear an existing acknowledgement.
      final existing = await db.syncConflictsDao.getByConflictId(conflictId);
      if (existing != null && existing.acknowledgedAt != null) {
        // Already acknowledged — do not overwrite.
        debugPrint('[CONFLICT] Skipping already-acknowledged conflict: $conflictId');
        return;
      }

      await db.syncConflictsDao.upsert(SyncConflictsCompanion.insert(
        conflictId: conflictId,
        shopId: shopId,
        branchId: Value(branchId),
        conflictType: type.key,
        affectedEntityType: affectedEntityType,
        affectedEntityId: affectedEntityId,
        affectedEntityName: Value(affectedEntityName),
        severity: Value(severity.name),
        title: title,
        body: body,
        whatHappened: Value(whatHappened),
        whatSystemDid: Value(whatSystemDid),
        requiredAction: Value(requiredAction),
        requiresAction: Value(requiresAction),
        resolutionStatus: const Value('unresolved'),
        acknowledgedBy: const Value(null),
        acknowledgedByUsername: const Value(null),
        acknowledgedAt: const Value(null),
        detectedAt: Value(existing?.detectedAt ?? DateTime.now().toUtc()),
        sourceEventId: Value(sourceEventId),
        conflictDataJson: Value(conflictData != null ? jsonEncode(conflictData) : null),
      ));
      debugPrint('[CONFLICT] Recorded conflictId=$conflictId type=${type.key} entity=$affectedEntityId');
    } catch (e) {
      debugPrint('[CONFLICT] Error recording conflict $conflictId: $e');
    }
  }

  // ── ACKNOWLEDGE ─────────────────────────────────────────────────────────────

  /// Mark a conflict as acknowledged by the current authenticated user.
  ///
  /// The acknowledgement is persisted locally immediately. Then a
  /// CONFLICT_ACKNOWLEDGED outbox event is enqueued so other devices
  /// (e.g. the owner viewing on another phone) learn about it on next sync.
  Future<void> acknowledge(String conflictId, {String? shopId}) async {
    try {
      final db = _database;
      final user = AuthService().user;
      final userId = user?.id ?? 'unknown';
      final username = user?.username ?? 'unknown';

      await db.syncConflictsDao.acknowledge(
        conflictId,
        userId: userId,
        username: username,
      );
      debugPrint('[CONFLICT] Acknowledged conflictId=$conflictId userId=$userId');

      // Enqueue sync event so acknowledgement propagates to other devices.
      final effectiveShopId = shopId ?? user?.shopId ?? '';
      if (effectiveShopId.isNotEmpty) {
        try {
          final deviceId = await DeviceIdService.getOrCreate();
          await db.into(db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              id: 'ack_${conflictId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}',
              shopId: effectiveShopId,
              branchId: const Value('main'),
              deviceId: deviceId,
              userId: userId,
              entityTable: 'sync_conflicts',
              recordId: conflictId,
              operation: 'CONFLICT_ACKNOWLEDGED',
              payloadJson: Value(jsonEncode({
                'conflict_id': conflictId,
                'acknowledged_by': userId,
                'acknowledged_by_username': username,
                'acknowledged_at': DateTime.now().toUtc().toIso8601String(),
                'shopId': effectiveShopId,
              })),
              status: const Value('PENDING'),
              schemaVersion: const Value(1),
            ),
            mode: InsertMode.insertOrReplace,
          );
        } catch (e) {
          debugPrint('[CONFLICT] Could not enqueue acknowledgement outbox event: $e');
        }
      }
    } catch (e) {
      debugPrint('[CONFLICT] Error acknowledging conflict $conflictId: $e');
    }
  }

  // ── QUERY ───────────────────────────────────────────────────────────────────

  Stream<List<SyncConflict>> watchUnacknowledged(String shopId) =>
      _database.syncConflictsDao.watchUnacknowledged(shopId);

  Future<List<SyncConflict>> getUnacknowledged(String shopId) =>
      _database.syncConflictsDao.getUnacknowledged(shopId);

  Future<int> unacknowledgedCount(String shopId) =>
      _database.syncConflictsDao.countUnacknowledged(shopId);

  // ── INGEST FROM BACKEND NOTIFICATION ────────────────────────────────────────

  /// Convert a server-delivered notification of type 'sync_conflict' into a
  /// local [SyncConflict] record. Called from _applyRemoteUpsert('notifications').
  ///
  /// The server encodes a stable [conflict_id] in [payload_json]; if absent,
  /// a fallback is derived from the notification id so it's still idempotent.
  Future<void> upsertFromBackendNotification(Map<String, dynamic> payload) async {
    try {
      final type = payload['type']?.toString() ?? '';
      if (type != 'sync_conflict') return;

      Map<String, dynamic> extra = {};
      final raw = payload['payloadJson'] ?? payload['payload_json'];
      if (raw is String && raw.isNotEmpty) {
        try { extra = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {}
      } else if (raw is Map) {
        extra = Map<String, dynamic>.from(raw);
      }

      final conflictId = extra['conflict_id']?.toString() ??
          payload['relatedEntityId']?.toString() ??
          'backend_notif_${payload['id'] ?? DateTime.now().millisecondsSinceEpoch}';

      final shopId = payload['shopId']?.toString() ?? payload['businessId']?.toString() ?? '';
      final branchId = payload['branchId']?.toString() ?? 'main';
      final conflictTypeStr = extra['conflict_type']?.toString() ?? 'other';
      final entityType = extra['entity_type']?.toString() ?? payload['itemId']?.toString() ?? '';
      final entityId = extra['entity_id']?.toString() ?? payload['relatedEntityId']?.toString() ?? '';
      final entityName = extra['entity_name']?.toString() ?? payload['itemId']?.toString();
      final requiresAction = extra['requires_action'] == true || extra['requires_action'] == 'true';
      final requiredActionStr = extra['required_action']?.toString();
      final whatHappened = extra['what_happened']?.toString();
      final whatSystemDid = extra['what_system_did']?.toString();
      final severityStr = extra['severity']?.toString() ?? 'medium';

      if (shopId.isEmpty) return;

      await record(
        conflictId: conflictId,
        shopId: shopId,
        branchId: branchId,
        type: ConflictTypeX.fromKey(conflictTypeStr),
        affectedEntityType: entityType,
        affectedEntityId: entityId,
        affectedEntityName: entityName,
        title: payload['title']?.toString() ?? 'Sync Conflict',
        body: payload['body']?.toString() ?? payload['message']?.toString() ?? '',
        whatHappened: whatHappened,
        whatSystemDid: whatSystemDid,
        requiredAction: requiredActionStr,
        requiresAction: requiresAction,
        severity: severityStr == 'high'
            ? ConflictSeverity.high
            : severityStr == 'low'
                ? ConflictSeverity.low
                : ConflictSeverity.medium,
        conflictData: extra,
      );
    } catch (e) {
      debugPrint('[CONFLICT] Error ingesting backend notification: $e');
    }
  }
}
