import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'firestore_service.dart';
import 'validation_service.dart';

class ImportService {
  final FirestoreService _firestore = FirestoreService();
  final ValidationService _validator = ValidationService();

  Future<Map<String, int>> importFromCSV(Uint8List bytes, String shopId, String username) async {
    final csvString = utf8.decode(bytes);
    final fields = const CsvToListConverter().convert(csvString);

    int imported = 0;
    int skipped = 0;

    // Skip header row
    for (var i = 1; i < fields.length; i++) {
      final row = fields[i];
      if (row.length < 2) continue;

      final name = row[0].toString();
      final barcode = row[1].toString();
      final buyPrice = double.tryParse(row[2].toString()) ?? 0.0;
      final sellPrice = double.tryParse(row[3].toString()) ?? 0.0;
      final qty = int.tryParse(row[4].toString()) ?? 0;

      try {
        await _validator.validateProduct(shopId, name, barcode);
        await _firestore.addItem({
          'shopId': shopId,
          'branchId': 'main',
          'name': name,
          'barcode': barcode,
          'buyingPrice': buyPrice,
          'sellingPrice': sellPrice,
          'quantity': qty,
          'branchName': 'Imported',
        }, addedBy: username);
        imported++;
      } catch (e) {
        skipped++;
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }

  Future<Map<String, int>> importFromExcel(Uint8List bytes, String shopId, String username) async {
    var excel = Excel.decodeBytes(bytes);

    int imported = 0;
    int skipped = 0;

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null) continue;

      for (var i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.length < 2) continue;

        final name = row[0]?.value.toString() ?? '';
        final barcode = row[1]?.value.toString() ?? '';
        final buyPrice = double.tryParse(row[2]?.value.toString() ?? '') ?? 0.0;
        final sellPrice = double.tryParse(row[3]?.value.toString() ?? '') ?? 0.0;
        final qty = int.tryParse(row[4]?.value.toString() ?? '') ?? 0;

        try {
          await _validator.validateProduct(shopId, name, barcode);
          await _firestore.addItem({
            'shopId': shopId,
            'branchId': 'main',
            'name': name,
            'barcode': barcode,
            'buyingPrice': buyPrice,
            'sellingPrice': sellPrice,
            'quantity': qty,
            'branchName': 'Imported',
          }, addedBy: username);
          imported++;
        } catch (e) {
          skipped++;
        }
      }
    }
    return {'imported': imported, 'skipped': skipped};
  }
}
