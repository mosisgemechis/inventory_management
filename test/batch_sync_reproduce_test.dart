import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/db/app_database.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/repositories/inventory_repository.dart';
import 'package:inventory_manager/core/models/models.dart';
import 'package:inventory_manager/core/services/sync/sync_engine_service.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  AppDatabase.forceInMemory = true;

  test('Simulate Device A create product + batch -> Device B pull -> Device B sell', () async {
    final db = DatabaseService();
    await db.ensureInitialized();
    final repo = InventoryRepository();

    const shopId = 'test_shop_123';
    const branchId = 'main';

    final user = AppUser(
      id: 'user_1',
      email: 'admin@test.com',
      username: 'admin',
      fullName: 'Admin User',
      roles: [UserRole.admin],
      shopId: shopId,
      branchId: branchId,
      branchName: 'Main Branch',
      isActive: true,
    );

    // 1. Device A creates a new product with 100 units opening stock
    final prodId = await repo.registerItem(user, {
      'name': 'Loratadine 10mg',
      'barcode': 'LORA-10',
      'quantity': 100,
      'buyingPrice': 2.0,
      'sellingPrice': 5.0,
      'lowStockThreshold': 5,
      'expiryDate': DateTime.utc(2028, 1, 1).toIso8601String(),
      'shopId': shopId,
      'branchId': branchId,
    });

    print('Product created with ID: $prodId');

    // Inspect Device A database
    final prodsA = await db.db.select(db.db.products).get();
    final batchesA = await db.db.select(db.db.batches).get();
    print('Device A direct Drift: products: ${prodsA.length}, batches: ${batchesA.length}');
    if (batchesA.isNotEmpty) {
      print('Device A batch row: id=${batchesA.first.id}, itemId=${batchesA.first.itemId}, qty=${batchesA.first.quantity}, branchId=${batchesA.first.branchId}, shopId=${batchesA.first.shopId}');
    }
    expect(prodsA, isNotEmpty);
    expect(batchesA, isNotEmpty);

    // Inspect Device A outbox
    final outboxRows = await db.db.select(db.db.syncOutbox).get();
    print('Device A outbox rows: ${outboxRows.length}');
    for (final row in outboxRows) {
      print('  Outbox: table=${row.entityTable}, op=${row.operation}, recId=${row.recordId}');
    }

    // Now simulate what Device B pulls from server
    // Device B has a separate database. But here we can simulate Device B by clearing DB or checking what _applyRemoteUpsert does
    // Let's create an event payload exactly as the server would return to Device B:
    final prodOutbox = outboxRows.firstWhere((r) => r.entityTable == 'products');
    final batchOutbox = outboxRows.firstWhere((r) => r.entityTable == 'batches');

    final prodPayload = jsonDecode(prodOutbox.payloadJson!);
    final batchPayload = jsonDecode(batchOutbox.payloadJson!);

    print('Server prod payload: $prodPayload');
    print('Server batch payload: $batchPayload');

    // Clear Device A's DB to simulate clean Device B!
    await db.db.transaction(() async {
      await (db.db.delete(db.db.products)..where((t) => t.shopId.equals(shopId))).go();
      await (db.db.delete(db.db.batches)..where((t) => t.shopId.equals(shopId))).go();
      await (db.db.delete(db.db.productStocks)..where((t) => t.shopId.equals(shopId))).go();
      await (db.db.delete(db.db.syncOutbox)..where((t) => t.shopId.equals(shopId))).go();
    });

    // Device B applies the remote upserts
    final syncEngine = SyncEngineService(db: db.db);
    // Device B pulls product first, then batch
    await syncEngine.applyRemoteUpsertForTest('products', prodId, prodPayload);
    await syncEngine.applyRemoteUpsertForTest('batches', batchOutbox.recordId, batchPayload);

    // Now inspect Device B's DB
    final prodsB = await db.query('products', where: 'id = ?', whereArgs: [prodId]);
    final batchesB = await db.query('batches', where: 'item_id = ?', whereArgs: [prodId]);
    final stocksB = await db.query('product_stocks', where: 'product_id = ?', whereArgs: [prodId]);

    print('Device B products: ${prodsB.length}, batches: ${batchesB.length}, stocks: ${stocksB.length}');
    if (batchesB.isNotEmpty) {
      print('Device B batch: ${batchesB.first}');
    }

    // Now Device B attempts to sell 5 units
    await repo.recordSale(user, {
      'shopId': shopId,
      'branchId': branchId,
      'userId': user.id,
      'username': user.username,
      'itemId': prodId,
      'itemName': 'Loratadine 10mg',
      'quantity': 5,
      'totalPrice': 25.0,
      'isDebt': false,
    });

    print('Sale succeeded on Device B!');
  });
}
