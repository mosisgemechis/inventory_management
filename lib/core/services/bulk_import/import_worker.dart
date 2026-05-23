import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'import_models.dart';
import 'package:intl/intl.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ImportWorker {
  static const Map<String, List<String>> headerAliases = {
    'name': ['name', 'product', 'item', 'medicine name', 'description'],
    'quantity': ['qty', 'quantity', 'amount', 'stock', 'available', 'balance'],
    'buyingPrice': ['cost', 'buying price', 'purchase price', 'unit cost', 'bp'],
    'sellingPrice': ['selling price', 'price', 'sell price', 'retail price', 'sp', 'unit price'],
    'barcode': ['barcode', 'sku', 'code', 'upc', 'id'],
    'expiryDate': ['exp', 'expiry', 'expdate', 'expiry date'],
    'supplierName': ['supplier', 'vendor', 'supplier name'],
    'lowStockThreshold': ['low stock', 'threshold', 'alert at', 'minimum stock', 'min qty'],
    'branchId': ['branch', 'branch name', 'location', 'store'],
  };

  static final Map<String, Set<String>> _normalizedAliases = {
    for (final e in headerAliases.entries)
      e.key: e.value.map((v) => _normalize(v)).toSet(),
  };

  static ImportResult parseSpreadsheet({
    required List<int> bytes,
    required String extension,
    required String shopId,
  }) {
    try {
      List<List<dynamic>> rows = [];

      if (extension == 'csv') {
        final input = utf8.decode(bytes);
        rows = const CsvToListConverter().convert(input);
      } else if (extension == 'xlsx' || extension == 'xls') {
        // Primary parser: `excel` package.
        // Fallback parser: `spreadsheet_decoder` for files that crash `excel` decoding.
        try {
          final excel = Excel.decodeBytes(bytes);
          // Prefer first sheet for predictable UX; fall back to all sheets if needed.
          final sheetNames = excel.tables.keys.toList();
          if (sheetNames.isNotEmpty) {
            final first = sheetNames.first;
            final tableData = excel.tables[first];
            if (tableData != null) {
              for (var row in tableData.rows) {
                rows.add(row.map((cell) => cell?.value).toList());
              }
            }
          } else {
            for (var table in excel.tables.keys) {
              final tableData = excel.tables[table];
              if (tableData == null) continue;
              for (var row in tableData.rows) {
                rows.add(row.map((cell) => cell?.value).toList());
              }
            }
          }
        } catch (_) {
          final decoder = SpreadsheetDecoder.decodeBytes(bytes);
          final names = decoder.tables.keys.toList();
          if (names.isNotEmpty) {
            final first = names.first;
            final table = decoder.tables[first];
            if (table != null) {
              for (final r in table.rows) {
                rows.add(r);
              }
            }
          } else {
            for (final table in decoder.tables.values) {
              for (final r in table.rows) {
                rows.add(r);
              }
            }
          }
        }
      } else {
        return ImportResult([], [
          ImportErrorRow(
            rowNumber: 0,
            reason: "Unsupported file type: $extension",
            originalData: {},
          )
        ]);
      }

      if (rows.isEmpty) {
        return ImportResult([], [
          ImportErrorRow(rowNumber: 0, reason: "File is empty", originalData: {})
        ]);
      }

      // 1. Detect Header Row
      int headerIndex = -1;
      Map<String, int> columnMap = {};

      for (int i = 0; i < rows.length && i < 20; i++) {
        final row = rows[i];
        int matchCount = 0;
        Map<String, int> tempMap = {};

        for (int j = 0; j < row.length; j++) {
          final cell = _normalize(row[j]?.toString() ?? '');
          if (cell.isEmpty) continue;
          for (var entry in _normalizedAliases.entries) {
            if (entry.value.contains(cell)) {
              tempMap[entry.key] = j;
              matchCount++;
              break;
            }
          }
        }

        if (matchCount >= 2 && tempMap.containsKey('name')) {
          headerIndex = i;
          columnMap = tempMap;
          break;
        }
      }

      if (headerIndex == -1) {
        return ImportResult([], [
          ImportErrorRow(
            rowNumber: 0,
            reason:
                "Could not detect header row. Ensure columns like 'Name' and 'Price' exist.",
            originalData: {},
          )
        ]);
      }

      if (!columnMap.containsKey('sellingPrice')) {
        return ImportResult([], [
          ImportErrorRow(
            rowNumber: headerIndex + 1,
            reason: "Missing required column: Selling Price",
            originalData: {},
          )
        ]);
      }

      // 2. Process Data Rows
      List<Map<String, dynamic>> validItems = [];
      List<ImportErrorRow> errors = [];
      final Set<String> seenKeys = {};

      for (int i = headerIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty ||
            row.every((c) => c == null || c.toString().isEmpty)) continue;

        Map<String, dynamic> data = {};

        try {
          // Extract & Normalize
          final name = _getVal(row, columnMap['name']);
          final qtyVal = _getCell(row, columnMap['quantity']);
          final costVal = _getCell(row, columnMap['buyingPrice']);
          final priceVal = _getCell(row, columnMap['sellingPrice']);
          final barcode = _getBarcode(row, columnMap['barcode']);
          final expiryVal = _getCell(row, columnMap['expiryDate']);
          final supplier = _getVal(row, columnMap['supplierName']);
          final thresholdVal = _getCell(row, columnMap['lowStockThreshold']);
          final branchName = _getVal(row, columnMap['branchId']);

          // Cleaning
          final double qty = _parseNumDynamic(qtyVal);
          final double cost = _parseNumDynamic(costVal);
          final double price = _parseNumDynamic(priceVal);
          final int threshold = _parseNumDynamic(thresholdVal).toInt();
          final DateTime? expiry = _parseDateDynamic(expiryVal);

          // Map for original data snapshot in case of error
          data = {
            'name': name,
            'barcode': barcode,
            'quantity': qtyVal?.toString(),
            'buyingPrice': costVal?.toString(),
            'sellingPrice': priceVal?.toString(),
            'expiryDate': expiryVal?.toString(),
            'supplierName': supplier,
            'lowStockThreshold': thresholdVal?.toString(),
          };

          // Validation Rules
          if (name == null || name.isEmpty) throw "Product name is missing";
          if (price == 0) throw "Selling price is missing or invalid";
          if (price < 0) throw "Selling price cannot be negative";
          if (qty < 0) throw "Stock cannot be negative";
          if (cost < 0) throw "Buying price cannot be negative";

          final dedupeKey = (barcode != null && barcode.trim().isNotEmpty)
              ? 'barcode:${barcode.trim()}'
              : 'name:${_normalize(name)}';
          if (seenKeys.contains(dedupeKey)) {
            throw "Duplicate row in file (same ${barcode != null && barcode.trim().isNotEmpty ? 'barcode' : 'name'})";
          }
          seenKeys.add(dedupeKey);

          validItems.add({
            'id': _generateId(name, barcode),
            'shopId': shopId,
            'name': name,
            'barcode': barcode ?? '',
            'quantity': qty,
            'buyingPrice': cost,
            'sellingPrice': price,
            'expiryDate': expiry,
            'supplierName': supplier?.isEmpty == true ? null : supplier,
            'lowStockThreshold': threshold > 0 ? threshold : 5,
            'branchName': branchName,
            '_sourceRow': i + 1,
          });
        } catch (e) {
          errors.add(ImportErrorRow(
            rowNumber: i + 1,
            reason: e.toString(),
            originalData: data,
          ));
        }
      }

      return ImportResult(validItems, errors);
    } catch (e) {
      return ImportResult([], [
        ImportErrorRow(
          rowNumber: 0,
          reason: "Failed to parse spreadsheet: $e",
          originalData: {},
        )
      ]);
    }
  }

  static String _normalize(String input) {
    return input.toLowerCase().trim().replaceAll('_', '').replaceAll(' ', '');
  }

  static dynamic _getCell(List<dynamic> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return row[index];
  }

  static String? _getVal(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) return null;
    return row[index]?.toString().trim();
  }

  static String? _getBarcode(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) return null;
    final val = row[index];
    if (val == null) return null;
    
    // Prevent Scientific Notation and preserve Leading Zeros
    String s = val.toString().trim();
    if (s.contains('E+') || s.contains('e+')) {
      try {
        final numVal = double.parse(s);
        return numVal.toStringAsFixed(0);
      } catch (_) {}
    }
    return s;
  }

  static double _parseNumDynamic(dynamic input) {
    if (input == null) return 0.0;
    if (input is num) return input.toDouble();
    final s = input.toString().trim();
    if (s.isEmpty) return 0.0;
    // Remove currency symbols and spaces, keep digits/dot/minus.
    final cleaned = s.replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  static DateTime? _parseDateDynamic(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    if (input is num) {
      // Excel serial date (days since 1899-12-30). Ignore obviously small/invalid values.
      final serial = input.toDouble();
      if (serial <= 0) return null;
      final millis = ((serial - 25569) * 86400 * 1000).round();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    }

    final s = input.toString().trim();
    if (s.isEmpty) return null;
    
    final formats = [
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'MMM dd, yyyy',
    ];

    for (var f in formats) {
      try {
        return DateFormat(f).parse(s);
      } catch (_) {}
    }
    
    // Try ISO
    return DateTime.tryParse(s);
  }

  static String _generateId(String name, String? barcode) {
    if (barcode != null && barcode.isNotEmpty) return barcode;
    return "${name.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().microsecondsSinceEpoch}";
  }
}
