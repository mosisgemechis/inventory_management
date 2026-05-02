import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../repositories/inventory_repository.dart';
import '../models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;

class ImportResult {
  final int imported;
  final int updated;
  final List<String> errors;

  ImportResult({required this.imported, required this.updated, required this.errors});
}

class ImportService {
  final InventoryRepository _repo = InventoryRepository();

  /// Picks an Excel file and returns its bytes. Handles platform differences.
  Future<Uint8List?> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null) {
      final file = result.files.first;
      if (kIsWeb || file.bytes != null) {
        return file.bytes;
      } else if (file.path != null) {
        return await File(file.path!).readAsBytes();
      }
    }
    return null;
  }

  Future<ImportResult> importFromExcel(Uint8List bytes, AppUser user) async {
    int imported = 0;
    int updated = 0;
    final List<String> errors = [];

    try {
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty || sheet.maxRows < 2) continue;

        final headerRow = sheet.rows.first;
        Map<String, List<int>> colMap = _mapHeadersFlexible(headerRow);

        if (!_hasRequiredHeaders(colMap)) {
          throw 'Missing required columns. Please ensure "Product Name" exists in your Excel file.';
        }

        for (var i = 1; i < sheet.maxRows; i++) {
          if (i >= sheet.rows.length) break;
          final row = sheet.rows[i];
          
          if (row.every((cell) => cell == null || cell.value == null)) continue;

          try {
            final name = _getValueFlexible(row, colMap['name']);
            if (name == null || name.trim().isEmpty) {
              errors.add("Row ${i + 1}: Missing Product Name");
              continue;
            }

            final barcode = _getValueFlexible(row, colMap['barcode']) ?? "";
            final qtyStr = _getValueFlexible(row, colMap['quantity']) ?? "0";
            final qty = (double.tryParse(qtyStr) ?? 0).toDouble();
            
            final buyStr = _getValueFlexible(row, colMap['buyingPrice']) ?? "0";
            final buyPrice = double.tryParse(buyStr) ?? 0.0;
            
            final sellStr = _getValueFlexible(row, colMap['sellingPrice']);
            if (sellStr == null) {
               errors.add("Row ${i + 1}: Missing Selling Price for '$name'");
               continue;
            }
            final sellPrice = double.tryParse(sellStr);
            if (sellPrice == null) {
               errors.add("Row ${i + 1}: Invalid Selling Price format for '$name'");
               continue;
            }
            
            final batchNum = _getValueFlexible(row, colMap['batch']) ?? "IMPORT-${DateTime.now().millisecondsSinceEpoch}";
            final thresholdStr = _getValueFlexible(row, colMap['threshold']) ?? "5";
            final threshold = int.tryParse(thresholdStr) ?? 5;
            final category = _getValueFlexible(row, colMap['category']) ?? "General";

            // ── AUTOMATIC LOGIC: Use Repository direct ────────────────────
            // This handles matching, creating, restocking, and sync automatically.
            
            // First check if it exists to increment 'imported' vs 'updated'
            final existingId = await _repo.findItemByNameOrBarcode(user.shopId, name.trim(), barcode.trim());
            
            await _repo.recordPurchase(user, {
              'shopId': user.shopId,
              'branchId': user.branchId,
              'userId': user.id,
              'username': user.username,
              'supplierName': 'Bulk Import',
              'itemName': name.trim(),
              'barcode': barcode.trim(),
              'quantity': qty,
              'unitCost': buyPrice,
              'sellingPrice': sellPrice,
              'lowStockThreshold': threshold,
              'batchNumber': batchNum.trim(),
              'category': category.trim(),
              'totalCost': qty * buyPrice,
            });

            if (existingId != null) updated++; else imported++;

          } catch (e) {
            errors.add("Row ${i + 1}: Error - ${e.toString()}");
          }
        }
      }
    } catch (e) {
      print("Import Service Fatal Error: $e");
      rethrow;
    }

    return ImportResult(imported: imported, updated: updated, errors: errors);
  }

  Map<String, List<int>> _mapHeadersFlexible(List<Data?> headerRow) {
    Map<String, List<int>> map = {
      'name': [], 'barcode': [], 'quantity': [], 'buyingPrice': [], 
      'sellingPrice': [], 'batch': [], 'threshold': [], 'category': []
    };

    for (int i = 0; i < headerRow.length; i++) {
      final cell = headerRow[i];
      if (cell == null || cell.value == null) continue;
      final val = cell.value.toString().toLowerCase().trim();

      if (_match(val, ['name', 'product', 'item'])) map['name']?.add(i);
      else if (_match(val, ['barcode', 'code', 'sku'])) map['barcode']?.add(i);
      else if (_match(val, ['qty', 'quantity', 'stock', 'amount'])) map['quantity']?.add(i);
      else if (_match(val, ['buying', 'cost', 'buy', 'purchase'])) map['buyingPrice']?.add(i);
      else if (_match(val, ['selling', 'price', 'sell', 'sale'])) map['sellingPrice']?.add(i);
      else if (_match(val, ['batch', 'lot'])) map['batch']?.add(i);
      else if (_match(val, ['threshold', 'min', 'low'])) map['threshold']?.add(i);
      else if (_match(val, ['cat', 'category', 'type'])) map['category']?.add(i);
    }
    return map;
  }

  bool _match(String val, List<String> targets) {
    return targets.any((t) => val.contains(t));
  }

  bool _hasRequiredHeaders(Map<String, List<int>> colMap) {
    return (colMap['name']?.isNotEmpty ?? false);
  }

  String? _getValueFlexible(List<Data?> row, List<int>? indices) {
    if (indices == null || indices.isEmpty) return null;
    for (var index in indices) {
      if (index >= row.length) continue;
      final cell = row[index];
      if (cell == null || cell.value == null) continue;
      final val = cell.value.toString().trim();
      if (val.isNotEmpty) return val;
    }
    return null;
  }
}
