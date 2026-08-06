import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/db/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppDatabase.forceInMemory = true;

  group('Phase 1 stabilization', () {
    test('watchProducts is branch-scoped and uses product_stocks', () async {
      final db = DatabaseService();
      await db.ensureInitialized();

      const shopId = 'shop_test_001';

      // Clean slate for this shop.
      await db.db.transaction(() async {
        await (db.db.delete(db.db.productStocks)..where((t) => t.shopId.equals(shopId))).go();
        await (db.db.delete(db.db.products)..where((t) => t.shopId.equals(shopId))).go();
      });

      // Two products in different branches.
      await db.db.into(db.db.products).insert(
        ProductsCompanion.insert(
          id: 'p_main',
          shopId: shopId,
          branchId: 'main',
          name: 'Main Product',
          quantity: 0,
          buyingPrice: 1,
          sellingPrice: 2,
        ),
      );
      await db.db.into(db.db.products).insert(
        ProductsCompanion.insert(
          id: 'p_b1',
          shopId: shopId,
          branchId: 'b1',
          name: 'Branch1 Product',
          quantity: 0,
          buyingPrice: 1,
          sellingPrice: 2,
        ),
      );

      // Branch stock cache.
      await db.saveProductStock(shopId: shopId, productId: 'p_main', branchId: 'main', quantity: 7);
      await db.saveProductStock(shopId: shopId, productId: 'p_b1', branchId: 'b1', quantity: 3);

      Future<List<Map<String, dynamic>>> first(Stream<List<Map<String, dynamic>>> s) {
        final c = Completer<List<Map<String, dynamic>>>();
        late final StreamSubscription sub;
        sub = s.listen((v) {
          if (!c.isCompleted) c.complete(v);
          sub.cancel();
        });
        return c.future.timeout(const Duration(seconds: 3));
      }

      final b1 = await first(db.watchProducts(shopId, branchId: 'b1'));
      expect(b1.length, 1);
      expect(b1.single['id'], 'p_b1');
      expect((b1.single['quantity'] as num).toDouble(), 3);

      final main = await first(db.watchProducts(shopId, branchId: 'main'));
      expect(main.length, 1);
      expect(main.single['id'], 'p_main');
      expect((main.single['quantity'] as num).toDouble(), 7);

      final all = await first(db.watchProducts(shopId, branchId: 'all'));
      expect(all.length, 2);
      final ids = all.map((e) => e['id']).toSet();
      expect(ids, containsAll(<String>{'p_main', 'p_b1'}));
    });
  });
}
