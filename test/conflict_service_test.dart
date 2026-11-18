import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull, isEmpty;

import 'package:inventory_manager/core/db/app_database.dart';
import 'package:inventory_manager/core/services/conflict_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: open an in-memory Drift database for tests.
// ─────────────────────────────────────────────────────────────────────────────
AppDatabase _openTestDb() {
  AppDatabase.forceInMemory = true;
  return AppDatabase();
}

void main() {
  late AppDatabase db;
  late ConflictService conflicts;
  const kShop = 'test_shop_1';
  const kBranch = 'main';

  setUp(() {
    db = _openTestDb();
    conflicts = ConflictService()..init(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Every supported conflict type creates a persistent conflict record.
  // ──────────────────────────────────────────────────────────────────────────
  group('Conflict creation', () {
    test('product_dedup creates persistent SyncConflict row', () async {
      await conflicts.record(
        conflictId: 'product_dedup_aaa_bbb',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.productDedup,
        affectedEntityType: 'products',
        affectedEntityId: 'aaa',
        affectedEntityName: 'Paracetamol 500mg',
        title: 'Duplicate Product Merged',
        body: 'Product was merged into existing record.',
        requiresAction: true,
        severity: ConflictSeverity.high,
      );

      final rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows.length, 1);
      expect(rows.first.conflictId, 'product_dedup_aaa_bbb');
      expect(rows.first.conflictType, 'product_dedup');
      expect(rows.first.requiresAction, true);
      expect(rows.first.acknowledgedAt, isNull);
    });

    test('sale_oversell creates persistent SyncConflict row', () async {
      await conflicts.record(
        conflictId: 'sale_oversell_sale-001_prod-001',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.saleOversell,
        affectedEntityType: 'sales',
        affectedEntityId: 'sale-001',
        title: 'Stock Oversold',
        body: 'Sale exceeded available stock.',
        requiresAction: true,
        severity: ConflictSeverity.high,
      );

      final rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows.length, 1);
      expect(rows.first.conflictType, 'sale_oversell');
      expect(rows.first.severity, 'high');
    });

    test('outbox_rejected creates persistent SyncConflict row', () async {
      await conflicts.record(
        conflictId: 'outbox_rejected_evt-xyz',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.outboxRejected,
        affectedEntityType: 'sales',
        affectedEntityId: 'sale-002',
        title: 'Sale Rejected by Server',
        body: 'Server returned conflict_rejected.',
        requiresAction: true,
      );
      final rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows.any((r) => r.conflictId == 'outbox_rejected_evt-xyz'), true);
    });

    test('stock_snapshot_conflict creates persistent SyncConflict row', () async {
      await conflicts.record(
        conflictId: 'stock_snapshot_prod-001_main',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.stockSnapshotConflict,
        affectedEntityType: 'products',
        affectedEntityId: 'prod-001',
        title: 'Stock Level Conflict',
        body: 'Server snapshot skipped due to pending events.',
        requiresAction: false,
        severity: ConflictSeverity.low,
      );
      final rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows.any((r) => r.conflictId == 'stock_snapshot_prod-001_main'), true);
      expect(rows.first.requiresAction, false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Conflict remains visible after "app restart" (reimporting DB from disk).
  //    In the in-memory test we verify row survives a DAO re-query.
  // ──────────────────────────────────────────────────────────────────────────
  group('Persistence', () {
    test('conflict survives re-query (simulates app restart)', () async {
      await conflicts.record(
        conflictId: 'durable_conflict_1',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.saleRejected,
        affectedEntityType: 'sales',
        affectedEntityId: 'sale-003',
        title: 'Sale Rejected',
        body: 'Server rejected sale.',
        requiresAction: true,
      );

      // Re-query using a fresh DAO (same in-memory DB — simulates cold read)
      final freshDao = SyncConflictsDao(db);
      final rows = await freshDao.getUnacknowledged(kShop);
      expect(rows.length, 1);
      expect(rows.first.conflictId, 'durable_conflict_1');
      expect(rows.first.acknowledgedAt, isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Acknowledgement records the correct user + timestamp.
  // ──────────────────────────────────────────────────────────────────────────
  group('Acknowledgement', () {
    test('acknowledge records userId, username, and timestamp', () async {
      await conflicts.record(
        conflictId: 'ack_test_1',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.productDedup,
        affectedEntityType: 'products',
        affectedEntityId: 'prod-002',
        title: 'Dup Merged',
        body: 'Body',
      );

      final beforeAck = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
      await db.syncConflictsDao.acknowledge(
        'ack_test_1',
        userId: 'user-42',
        username: 'kali',
      );
      final afterAck = DateTime.now().toUtc().add(const Duration(seconds: 1));

      final row = await db.syncConflictsDao.getByConflictId('ack_test_1');
      expect(row, isNotNull);
      expect(row!.acknowledgedBy, 'user-42');
      expect(row.acknowledgedByUsername, 'kali');
      expect(row.acknowledgedAt, isNotNull);
      expect(row.acknowledgedAt!.isAfter(beforeAck), true);
      expect(row.acknowledgedAt!.isBefore(afterAck), true);
      expect(row.resolutionStatus, 'acknowledged');
    });

    test('acknowledged conflict no longer appears in watchUnacknowledged', () async {
      await conflicts.record(
        conflictId: 'ack_test_2',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.saleOversell,
        affectedEntityType: 'sales',
        affectedEntityId: 'sale-010',
        title: 'Oversell',
        body: 'Body',
      );

      // Confirm unacknowledged before ack
      var rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows.any((r) => r.conflictId == 'ack_test_2'), true);

      await db.syncConflictsDao.acknowledge('ack_test_2', userId: 'u1', username: 'admin');

      // Should not appear in unacknowledged after ack
      rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows.any((r) => r.conflictId == 'ack_test_2'), false);
    });

    test('acknowledged conflict row still exists with acknowledgedAt set', () async {
      await conflicts.record(
        conflictId: 'ack_persists_1',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.productEditConflict,
        affectedEntityType: 'products',
        affectedEntityId: 'prod-003',
        title: 'Edit Conflict',
        body: 'Body',
      );
      await db.syncConflictsDao.acknowledge('ack_persists_1', userId: 'u2', username: 'bob');

      final row = await db.syncConflictsDao.getByConflictId('ack_persists_1');
      expect(row, isNotNull);
      expect(row!.acknowledgedAt, isNotNull); // Record preserved after ack
      expect(row.resolutionStatus, 'acknowledged');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Idempotency — repeated record() calls with the same conflictId do NOT
  //    create duplicates, and do NOT clear an existing acknowledgement.
  // ──────────────────────────────────────────────────────────────────────────
  group('Idempotency', () {
    test('repeated record() for same conflictId does not create duplicate', () async {
      for (var i = 0; i < 3; i++) {
        await conflicts.record(
          conflictId: 'idem_1',
          shopId: kShop,
          branchId: kBranch,
          type: ConflictType.saleOversell,
          affectedEntityType: 'sales',
          affectedEntityId: 'sale-idem',
          title: 'Oversell',
          body: 'Body $i',
        );
      }
      final rows = await (db.select(db.syncConflicts)
          ..where((t) => t.conflictId.equals('idem_1'))).get();
      expect(rows.length, 1); // Only one row despite 3 calls
    });

    test('repeated record() after acknowledgement does NOT clear acknowledgedAt', () async {
      await conflicts.record(
        conflictId: 'idem_ack_1',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.productDedup,
        affectedEntityType: 'products',
        affectedEntityId: 'prod-idem',
        title: 'Dup',
        body: 'Body',
      );
      await db.syncConflictsDao.acknowledge('idem_ack_1', userId: 'u3', username: 'carol');

      // Call record() again (simulates sync retry / re-delivery of same conflict)
      await conflicts.record(
        conflictId: 'idem_ack_1',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.productDedup,
        affectedEntityType: 'products',
        affectedEntityId: 'prod-idem',
        title: 'Dup (retry)',
        body: 'Body (retry)',
      );

      final row = await db.syncConflictsDao.getByConflictId('idem_ack_1');
      // Acknowledgement must NOT be cleared
      expect(row!.acknowledgedAt, isNotNull);
      expect(row.acknowledgedBy, 'u3');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 5. Remote acknowledgement propagation via CONFLICT_ACKNOWLEDGED event.
  // ──────────────────────────────────────────────────────────────────────────
  group('Remote acknowledgement propagation', () {
    test('direct DAO acknowledge updates row read by another DAO', () async {
      await conflicts.record(
        conflictId: 'remote_ack_1',
        shopId: kShop,
        branchId: kBranch,
        type: ConflictType.saleRejected,
        affectedEntityType: 'sales',
        affectedEntityId: 'sale-remote',
        title: 'Remote Acked',
        body: 'Body',
      );

      // Simulate CONFLICT_ACKNOWLEDGED event handler writing acknowledgement
      final ackAt = DateTime.now().toUtc();
      await (db.update(db.syncConflicts)
              ..where((t) => t.conflictId.equals('remote_ack_1')))
          .write(SyncConflictsCompanion(
        acknowledgedBy: const Value('device-b-user'),
        acknowledgedByUsername: const Value('device-b'),
        acknowledgedAt: Value(ackAt),
        resolutionStatus: const Value('acknowledged'),
      ));

      final row = await db.syncConflictsDao.getByConflictId('remote_ack_1');
      expect(row!.acknowledgedBy, 'device-b-user');
      expect(row.resolutionStatus, 'acknowledged');

      // Must not appear unacknowledged
      final unacked = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(unacked.any((r) => r.conflictId == 'remote_ack_1'), false);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 6. Successful round-trip does NOT generate false conflict.
  // ──────────────────────────────────────────────────────────────────────────
  group('No false conflicts on clean sync', () {
    test('unacknowledged count is 0 when no conflicts recorded', () async {
      final count = await db.syncConflictsDao.countUnacknowledged(kShop);
      expect(count, 0);
    });

    test('conflict for shop A does not appear in shop B query', () async {
      await conflicts.record(
        conflictId: 'cross_shop_1',
        shopId: 'shop_A',
        branchId: kBranch,
        type: ConflictType.saleOversell,
        affectedEntityType: 'sales',
        affectedEntityId: 'sale-99',
        title: 'Oversell',
        body: 'Body',
      );
      final rowsForB = await db.syncConflictsDao.getUnacknowledged('shop_B');
      expect(rowsForB, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 7. Backend notification ingestion converts to SyncConflict row.
  // ──────────────────────────────────────────────────────────────────────────
  group('Backend notification ingestion', () {
    test('upsertFromBackendNotification creates a SyncConflict for sync_conflict type', () async {
      await conflicts.upsertFromBackendNotification({
        'id': 'notif-001',
        'shopId': kShop,
        'branchId': kBranch,
        'type': 'sync_conflict',
        'title': 'Duplicate Product Merged',
        'body': 'Product XYZ was merged.',
        'payloadJson': '{"conflict_id":"backend_product_dedup_aaa","conflict_type":"product_dedup","entity_type":"products","entity_id":"aaa","entity_name":"XYZ","requires_action":true,"severity":"high"}',
      });

      final row = await db.syncConflictsDao.getByConflictId('backend_product_dedup_aaa');
      expect(row, isNotNull);
      expect(row!.conflictType, 'product_dedup');
      expect(row.requiresAction, true);
      expect(row.acknowledgedAt, isNull);
    });

    test('non-sync_conflict notification type is ignored', () async {
      await conflicts.upsertFromBackendNotification({
        'id': 'notif-002',
        'shopId': kShop,
        'type': 'low_stock',
        'title': 'Low Stock',
        'body': 'Product is low.',
      });

      final rows = await db.syncConflictsDao.getUnacknowledged(kShop);
      expect(rows, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 8. ConflictType key round-trip.
  // ──────────────────────────────────────────────────────────────────────────
  group('ConflictType key round-trip', () {
    test('all ConflictType values have unique non-empty keys', () {
      final keys = ConflictType.values.map((e) => e.key).toList();
      expect(keys.toSet().length, ConflictType.values.length);
      expect(keys.every((k) => k.isNotEmpty), true);
    });

    test('fromKey round-trips all supported types', () {
      for (final type in ConflictType.values) {
        expect(ConflictTypeX.fromKey(type.key), type);
      }
    });

    test('fromKey returns other for unknown key', () {
      expect(ConflictTypeX.fromKey('totally_unknown_type'), ConflictType.other);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // 9. countUnacknowledged returns correct count.
  // ──────────────────────────────────────────────────────────────────────────
  group('countUnacknowledged', () {
    test('returns correct count before and after acknowledgements', () async {
      for (var i = 0; i < 3; i++) {
        await conflicts.record(
          conflictId: 'count_test_$i',
          shopId: kShop,
          branchId: kBranch,
          type: ConflictType.outboxRejected,
          affectedEntityType: 'sales',
          affectedEntityId: 'sale-cnt-$i',
          title: 'Conflict $i',
          body: 'Body',
        );
      }

      expect(await db.syncConflictsDao.countUnacknowledged(kShop), 3);

      await db.syncConflictsDao.acknowledge('count_test_0', userId: 'u', username: 'u');
      expect(await db.syncConflictsDao.countUnacknowledged(kShop), 2);

      await db.syncConflictsDao.acknowledge('count_test_1', userId: 'u', username: 'u');
      await db.syncConflictsDao.acknowledge('count_test_2', userId: 'u', username: 'u');
      expect(await db.syncConflictsDao.countUnacknowledged(kShop), 0);
    });
  });
}
