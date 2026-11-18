import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/services/outbox_service.dart';
import 'package:inventory_manager/core/db/app_database.dart';
import 'package:inventory_manager/core/models/models.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppDatabase.forceInMemory = true;

  group('Account Sync & Identity Mapping Tests', () {
    late DatabaseService db;
    late OutboxService outbox;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      AppDatabase.forceInMemory = true;
      db = DatabaseService();
      db.resetForTest();
      await db.ensureInitialized();
      outbox = OutboxService(db.db);
    });

    test('USER_CREATED event contains target user ID and full authorization state', () async {
      const targetUid = 'target-user-uuid-123';
      const shopId = 'shop_test_999';
      const branchId = 'branch_north';

      final userData = {
        'uid': targetUid,
        'username': 'shemsu_staff',
        'email': 'shemsu@shop.com',
        'fullName': 'Shemsu Staff',
        'roles': ['staff', 'cashier'],
        'shopId': shopId,
        'branchId': branchId,
        'branchName': 'North Branch',
        'permissions': {'canViewInventory': true, 'canProcessSales': true},
        'passwordHash': 'dummy_hash',
        'isActive': true,
      };

      await db.saveUserRecord(userData, isFromSync: false);

      final events = await outbox.getPendingEvents();
      print("Pending events count: ${events.length}");
      for (final e in events) {
        print("Event: id=${e.id}, table=${e.entityTable}, op=${e.operation}, recId=${e.recordId}, payload=${e.payloadJson}");
      }
      expect(events, isNotEmpty);

      final userEvent = events.firstWhere((e) => e.recordId == targetUid);
      expect(userEvent.entityTable, 'users');
      expect(userEvent.operation, SyncEventType.USER_CREATED.name);
      expect(userEvent.userId, targetUid);

      final payload = jsonDecode(userEvent.payloadJson!);
      print("Decoded payload: $payload");
      expect(payload['user_id'], targetUid);
      expect(payload['uid'], targetUid);
      expect(payload['username'], 'shemsu_staff');
      expect(payload['email'], 'shemsu@shop.com');
      expect(payload['fullName'], 'Shemsu Staff');
      expect(payload['roles'], ['staff', 'cashier']);
      expect(payload['branchId'], branchId);
      expect(payload['branchName'], 'North Branch');
      expect(payload['permissions']['canViewInventory'], true);
      expect(payload['isActive'], true);
      expect(payload.containsKey('passwordHash'), false);
    });

    test('USER_DELETED event is enqueued when an account is deleted', () async {
      const targetUid = 'delete-user-uuid-456';
      const shopId = 'shop_test_999';

      final userData = {
        'uid': targetUid,
        'username': 'user_to_delete',
        'email': 'delete@shop.com',
        'roles': ['staff'],
        'shopId': shopId,
        'branchId': 'main',
        'isActive': true,
      };

      await db.saveUserRecord(userData, isFromSync: false);

      // Perform deletion
      await db.delete('users', targetUid);

      final events = await outbox.getPendingEvents();
      final deleteEvent = events.firstWhere((e) => e.operation == SyncEventType.USER_DELETED.name && e.recordId == targetUid);

      expect(deleteEvent.entityTable, 'users');
      expect(deleteEvent.userId, targetUid);

      final payload = jsonDecode(deleteEvent.payloadJson!);
      expect(payload['uid'], targetUid);
      expect(payload['username'], 'user_to_delete');
    });

    test('Password update updates local DB and does not enqueue password hashes', () async {
      const targetUid = 'pwd-user-uuid-789';
      const shopId = 'shop_test_999';

      final userData = {
        'uid': targetUid,
        'username': 'pwd_user',
        'email': 'pwd@shop.com',
        'roles': ['staff'],
        'shopId': shopId,
        'branchId': 'main',
        'passwordHash': 'old_hash',
        'isActive': true,
      };

      await db.saveUserRecord(userData, isFromSync: false);

      const newHash = 'new_sha256_hash_value';
      await db.updateUserPassword(targetUid, newHash);

      // Verify updated in SQLite
      final userRow = await (db.db.select(db.db.users)..where((t) => t.uid.equals(targetUid))).getSingleOrNull();
      expect(userRow?.passwordHash, newHash);

      final events = await outbox.getPendingEvents();
      final userEvents = events.where((e) => e.recordId == targetUid);
      for (final e in userEvents) {
        final payload = jsonDecode(e.payloadJson!);
        expect(payload.containsKey('password_hash'), false);
        expect(payload.containsKey('passwordHash'), false);
      }
    });


    test('deleteShopAndAccount enqueues SHOP_DELETED outbox event with shopId', () async {
      const shopId = 'delete_shop_uuid_101';
      await db.deleteShopAndAccount(shopId, isFromSync: false);

      final events = await outbox.getPendingEvents();
      final shopEvent = events.lastWhere((e) => e.recordId == shopId);
      expect(shopEvent.recordId, shopId);
      final payload = jsonDecode(shopEvent.payloadJson!);
      expect(payload['shopId'], shopId);
      expect(payload['isActive'], false);
    });
  });
}
