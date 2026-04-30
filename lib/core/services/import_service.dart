import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../repositories/inventory_repository.dart';
import '../models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ImportService {
  final InventoryRepository _repo = InventoryRepository();

  Future<Map<String, int>> importFromExcel(Uint8List bytes, AppUser user) async {
    int imported = 0;
    int updated = 0;
    int skipped = 0;

    try {
      var excel = Excel.decodeBytes(bytes);
      final batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.maxRows < 2) continue;

        // 1. Identify Headers
        final headerRow = sheet.rows.first;
        Map<String, int> colMap = _mapHeaders(headerRow);

        // Required Check: Minimum Name and Price
        if (!colMap.containsKey('name')) {
          throw 'Required column "Product Name" missing in Excel.';
        }

        for (var i = 1; i < sheet.maxRows; i++) {
          if (i >= sheet.rows.length) break;
          final row = sheet.rows[i];
          if (row == null || row.isEmpty) continue;

          try {
            final name = _getColVal(row, colMap['name']).trim();
            if (name.isEmpty) continue;

            final barcode = _getColVal(row, colMap['barcode']).trim();
            final qtyStr = _getColVal(row, colMap['quantity']);
            final qty = (double.tryParse(qtyStr) ?? 0).toInt();
            
            final buyStr = _getColVal(row, colMap['buyingPrice']);
            final buyPrice = double.tryParse(buyStr) ?? 0.0;
            
            final sellStr = _getColVal(row, colMap['sellingPrice']);
            final sellPrice = double.tryParse(sellStr) ?? 0.0;
            
            final batchNum = _getColVal(row, colMap['batch']);
            final thresholdStr = _getColVal(row, colMap['threshold']);
            final threshold = int.tryParse(thresholdStr) ?? 5;
            final category = _getColVal(row, colMap['category']);

            // 2. Matching Logic
            String? existingId;
            final query = await FirebaseFirestore.instance.collection('items')
                .where('shopId', isEqualTo: user.shopId)
                .where('name', isEqualTo: name)
                .get();
            if (query.docs.isNotEmpty) {
              existingId = query.docs.first.id;
            } else if (barcode.isNotEmpty) {
              final barcodeQuery = await FirebaseFirestore.instance.collection('items')
                  .where('shopId', isEqualTo: user.shopId)
                  .where('barcode', isEqualTo: barcode)
                  .get();
              if (barcodeQuery.docs.isNotEmpty) {
                existingId = barcodeQuery.docs.first.id;
              }
            }

            final Map<String, dynamic> data = {
              'shopId': user.shopId,
              'branchId': user.branchId ?? 'main',
              'name': name,
              'barcode': barcode,
              'quantity': qty,
              'buyingPrice': buyPrice,
              'sellingPrice': sellPrice,
              'category': category.isEmpty ? 'General' : category,
              'batchNumber': batchNum.isEmpty ? 'IMP-${DateTime.now().millisecondsSinceEpoch}' : batchNum,
              'lowStockThreshold': threshold,
              'lastUpdated': DateTime.now().toIso8601String(),
            };

            if (existingId != null) {
              final docRef = FirebaseFirestore.instance.collection('items').doc(existingId);
              batch.update(docRef, data);
              updated++;
            } else {
              final docRef = FirebaseFirestore.instance.collection('items').doc();
              batch.set(docRef, data);
              imported++;
            }
            
            batchCount++;
            if (batchCount >= 450) { // Firestore limit is 500
              await batch.commit();
              batchCount = 0;
            }
          } catch (e) {
            skipped++;
          }
        }
      }

      if (batchCount > 0) await batch.commit();

    } catch (e) {
      print("Bulk Import Error: $e");
      rethrow;
    }

    return {'imported': imported, 'updated': updated, 'skipped': skipped};
  }

  Map<String, int> _mapHeaders(List<Data?> row) {
    Map<String, int> map = {};
    for (int i = 0; i < row.length; i++) {
      final cell = row[i];
      if (cell == null || cell.value == null) continue;
      final val = cell.value.toString().toLowerCase().trim().replaceAll(' ', '_');

      if (val.contains('name') || val.contains('product')) map['name'] = i;
      else if (val.contains('barcode') || val.contains('sku')) map['barcode'] = i;
      else if (val.contains('qty') || val.contains('quantity') || val.contains('stock')) map['quantity'] = i;
      else if (val.contains('buying') || val.contains('cost')) map['buyingPrice'] = i;
      else if (val.contains('selling') || val.contains('price') || val.contains('sell')) map['sellingPrice'] = i;
      else if (val.contains('batch')) map['batch'] = i;
      else if (val.contains('threshold') || val.contains('min')) map['threshold'] = i;
      else if (val.contains('cat')) map['category'] = i;
    }
    return map;
  }

  String _getColVal(List<Data?> row, int? index) {
    if (index == null || index >= row.length) return "";
    final cell = row[index];
    if (cell == null || cell.value == null) return "";
    
    final val = cell.value;
    if (val is TextCellValue) return val.value.toString();
    if (val is IntCellValue) return val.value.toString();
    if (val is DoubleCellValue) return val.value.toString();
    return val.toString();
  }
}
