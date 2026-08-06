import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/db/app_database.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/repositories/inventory_repository.dart';
import 'package:inventory_manager/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppDatabase.forceInMemory = true;

  group('Purchase -> Restock -> Sell -> Refund E2E Workflow', () {
    test('Correct branch-scoping and batch recalculation across all stages', () async {
      final db = DatabaseService();
      await db.ensureInitialized();
      final repo = InventoryRepository();

      const shopId = 'e2e_shop_abc';

      // Use admin role so all permission checks pass in the repo
      final uStaffB1 = AppUser(
        id: 'user_staff_b1',
        email: 'b1@e2e.com',
        username: 'staff_b1',
        fullName: 'Staff B1',
        roles: [UserRole.admin],
        shopId: shopId,
        branchId: 'branch_1',
        branchName: 'Branch 1',
        isActive: true,
      );

      // Clean setup
      await db.db.transaction(() async {
        await (db.db.delete(db.db.products)..where((t) => t.shopId.equals(shopId))).go();
        await (db.db.delete(db.db.batches)..where((t) => t.shopId.equals(shopId))).go();
        await (db.db.delete(db.db.sales)..where((t) => t.shopId.equals(shopId))).go();
        await (db.db.delete(db.db.purchases)..where((t) => t.shopId.equals(shopId))).go();
        await (db.db.delete(db.db.productStocks)..where((t) => t.shopId.equals(shopId))).go();
      });

      // 1. REGISTER a product on branch_1
      await repo.registerItem(uStaffB1, {
        'id': 'prod_panadol',
        'name': 'Panadol 500mg',
        'barcode': 'PANA1234',
        'branchId': 'branch_1',
        'quantity': 100,
        'buyingPrice': 10.0,
        'sellingPrice': 15.0,
        'lowStockThreshold': 5,
        'expiryDate': DateTime.utc(2300, 1, 1).toIso8601String(),
      });

      // Verify product is in `products` & has stock in `product_stocks` for branch_1
      final pB1 = await db.query('products',
          where: 'id = ? AND branch_id = ?',
          whereArgs: ['prod_panadol', 'branch_1']);
      expect(pB1, isNotEmpty);
      expect((pB1.first['quantity'] as num).toDouble(), 100.0);

      final stockB1 = await db.query('product_stocks',
          where: 'product_id = ? AND branch_id = ?',
          whereArgs: ['prod_panadol', 'branch_1']);
      expect(stockB1, isNotEmpty);
      expect((stockB1.first['quantity'] as num).toDouble(), 100.0);

      // 2. PURCHASE (Restock) via recordPurchase → should create a batch and add 50 units
      await repo.recordPurchase(uStaffB1, {
        'itemId': 'prod_panadol',
        'itemName': 'Panadol 500mg',
        'barcode': 'PANA1234',
        'branchId': 'branch_1',
        'quantity': 50,
        'unitCost': 10.0,
        'totalCost': 500.0,
        'supplierName': 'Beta Pharma',
        'expiry': DateTime.utc(2300, 1, 1).toIso8601String(),
        'batchNumber': 'BATCH_002',
      });

      // Total product quantity should now be 150 (100 + 50)
      final pRestock = await db.query('products',
          where: 'id = ? AND branch_id = ?',
          whereArgs: ['prod_panadol', 'branch_1']);
      expect((pRestock.first['quantity'] as num).toDouble(), 150.0);

      // 3. RESTOCK (Direct batch restock) → adds 30 more
      await repo.recordRestock(uStaffB1, {
        'shopId': shopId,
        'itemId': 'prod_panadol',
        'itemName': 'Panadol 500mg',
        'addedQuantity': 30.0,
        'buyingPrice': 11.0,
        'sellingPrice': 16.0,
        'expiry': DateTime.utc(2300, 2, 2).toIso8601String(),
        'batchNumber': 'BATCH_003',
        'branchId': 'branch_1',
      });

      // Total quantity = 180 (150 + 30)
      final pRestockedDirect = await db.query('products',
          where: 'id = ? AND branch_id = ?',
          whereArgs: ['prod_panadol', 'branch_1']);
      expect((pRestockedDirect.first['quantity'] as num).toDouble(), 180.0);

      // 4. SELL 2 units via recordSale (flat map payload — no nested items list)
      await repo.recordSale(uStaffB1, {
        'itemId': 'prod_panadol',
        'itemName': 'Panadol 500mg',
        'customerId': 'guest',
        'customerName': 'Walk-in Customer',
        'isDebt': false,
        'amountPaid': 32.0,
        'totalPrice': 32.0,
        'sellingPrice': 16.0,
        'quantity': 2.0,
        'branchId': 'branch_1',
        'shopId': shopId,
      });

      // Quantity should drop to 178 (180 - 2)
      final pSold = await db.query('products',
          where: 'id = ? AND branch_id = ?',
          whereArgs: ['prod_panadol', 'branch_1']);
      expect((pSold.first['quantity'] as num).toDouble(), 178.0);

      // 5. REFUND: fetch the sale record using Drift directly
      final saleQuery = db.db.select(db.db.sales)
        ..where((t) => t.itemId.equals('prod_panadol'))
        ..where((t) => t.branchId.equals('branch_1'));
      final saleRows = await saleQuery.get();
      expect(saleRows, isNotEmpty, reason: 'Sale record must exist before refunding');

      final saleRecord = {
        'id': saleRows.first.id,
        'shopId': saleRows.first.shopId,
        'branchId': saleRows.first.branchId,
        'itemId': saleRows.first.itemId,
        'itemName': saleRows.first.itemName,
        'quantity': saleRows.first.quantity,
        'totalPrice': saleRows.first.totalPrice,
        'refundedQuantity': saleRows.first.refundedQuantity,
      };
      await repo.processRefund(uStaffB1, saleRecord, 2.0);

      // Quantity should restore to 180 (178 + 2)
      final pRefunded = await db.query('products',
          where: 'id = ? AND branch_id = ?',
          whereArgs: ['prod_panadol', 'branch_1']);
      expect((pRefunded.first['quantity'] as num).toDouble(), 180.0);
    });
  });
}
