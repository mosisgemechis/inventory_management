import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/db/app_database.dart';
import 'package:inventory_manager/core/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppDatabase.forceInMemory = true;

  group('Stock and expiry regressions', () {
    test('saveProduct preserves quantity and expiry date', () async {
      final db = DatabaseService();
      await db.ensureInitialized();

      const shopId = 'shop_stock_expiry';
      await db.db.transaction(() async {
        await (db.db.delete(db.db.productStocks)..where((t) => t.shopId.equals(shopId))).go();
        await (db.db.delete(db.db.products)..where((t) => t.shopId.equals(shopId))).go();
      });

      await db.saveProduct({
        'id': 'product_1',
        'shopId': shopId,
        'branchId': 'main',
        'name': 'Regression Product',
        'barcode': 'ABC123',
        'quantity': '500',
        'buyingPrice': '12.5',
        'sellingPrice': '15.0',
        'lowStockThreshold': 5,
        'expiryDate': DateTime.utc(2026, 7, 12),
      });

      final productRow = await db.query('products', where: 'id = ?', whereArgs: ['product_1']);
      expect(productRow, isNotEmpty);
      expect((productRow.first['quantity'] as num).toDouble(), 500);
      expect(productRow.first['expiryDate'], isNotNull);

      final branchRows = await db.query(
        'product_stocks',
        where: 'shop_id = ? AND product_id = ? AND branch_id = ?',
        whereArgs: [shopId, 'product_1', 'main'],
      );
      expect(branchRows, isNotEmpty);
      expect((branchRows.first['quantity'] as num).toDouble(), 500);

      Future<List<Map<String, dynamic>>> first(Stream<List<Map<String, dynamic>>> s) {
        final c = Completer<List<Map<String, dynamic>>>();
        late final StreamSubscription sub;
        sub = s.listen((v) {
          if (!c.isCompleted) c.complete(v);
          sub.cancel();
        });
        return c.future.timeout(const Duration(seconds: 3));
      }

      final watched = await first(db.watchProducts(shopId, branchId: 'main'));
      expect(watched.single['quantity'], 500);
      expect(watched.single['expiryDate'], isNotNull);
    });
  });
}

