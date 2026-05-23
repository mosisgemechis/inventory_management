import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/repositories/inventory_repository.dart';
import 'package:inventory_manager/core/models/models.dart';

void main() {
  testWidgets('Test Flow', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = DatabaseService();
    final repo = InventoryRepository();
    
    AppUser tempUser = AppUser(
      id: 'test_admin',
      shopId: 'shop123',
      username: 'admin',
      roles: [UserRole.admin],
      branchId: 'Bole',
      permissions: {},
    );

    try {
      final pid = await repo.registerItem(tempUser, {
        'name': 'marti_test',
        'quantity': 300,
        'buyingPrice': 100,
        'sellingPrice': 200,
        'branchId': 'Bole'
      });
      print('Product registered with ID: $pid');
      
      final batchesRaw = await db.query('batches', 
        where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
        whereArgs: [tempUser.shopId, pid, 'Bole', 'Bole']
      );
      print('Found batches for product: \${batchesRaw.length}');
      
      for(var b in batchesRaw) {
         print(b);
      }
      
      await repo.recordSale(tempUser, {
        'shopId': tempUser.shopId,
        'branchId': 'Bole',
        'userId': tempUser.id,
        'username': tempUser.username,
        'itemId': pid,
        'itemName': 'marti_test',
        'quantity': 1,
        'totalPrice': 200
      });
      print('Sale matched successfully!');
    } catch(e, s) {
      print('ERROR: $e');
      print(s);
    }
  });
}
