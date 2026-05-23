import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/services/database_service.dart';

void main() {
  testWidgets('Test DB', (WidgetTester tester) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = DatabaseService();
    try {
      final batches = await db.query('batches');
      for (var b in batches) {
        print('BATCH_DEBUG: itemId=${b['itemId']} branchId=${b['branchId']} qty=${b['quantity']}');
      }
    } catch(e) {
      print('ERROR: $e');
    }
  });
}
