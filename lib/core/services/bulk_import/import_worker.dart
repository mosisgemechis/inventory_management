import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'import_models.dart';
import 'package:intl/intl.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ImportWorker {
  static const Map<String, List<String>> headerAliases = {
    'name': [
      'product name', 'product', 'item name', 'item', 'name', 
      'medicine name', 'description', 'title', 'item description', 'product description'
    ],
    'sellingPrice': [
      'selling price', 'sell price', 'retail price', 'price', 'unit price', 
      'sp', 'mrp', 'rate', 'sale price', 'selling rate', 'unit rate'
    ],
    'buyingPrice': [
      'buying price', 'buy price', 'cost', 'cost price', 'purchase price', 
      'unit cost', 'bp', 'purchase cost', 'cost per unit', 'c price'
    ],
    'quantity': [
      'quantity', 'qty', 'stock', 'amount', 'available', 'balance', 
      'units', 'qty in stock', 'initial qty', 'in hand', 'count', 'current stock'
    ],
    'lowStockThreshold': [
      'low stock warning qty', 'low stock threshold', 'low stock', 'threshold', 
      'alert at', 'minimum stock', 'min qty', 'safety stock', 'min stock', 
      'reorder level', 'alert qty', 'min'
    ],
    'barcode': [
      'barcode', 'bar code', 'code', 'sku', 'upc', 'id', 'item code', 'product code', 'ean', 'serial'
    ],
    'expiryDate': [
      'exp', 'expiry', 'expdate', 'expiry date', 'val', 'valid until', 
      'expiry date', 'expired', 'expiration', 'life', 'exp date', 'mfg date'
    ],
    'branchName': [
      'branch', 'branch name', 'location', 'store', 'outlet', 'shop', 'site'
    ],
    'supplierName': [
      'supplier', 'vendor', 'supplier name', 'brand', 'manufacturer'
    ],
  };

  static final Map<String, Set<String>> _normalizedAliases = {
    for (final e in headerAliases.entries)
      e.key: e.value.map((v) => _normalizeHeader(v)).toSet(),
  };

  static const List<String> requiredFields = [
    'name',
    'sellingPrice',
    'buyingPrice',
    'quantity',
    'lowStockThreshold',
  ];

  static const Map<String, String> fieldDisplayNames = {
    'name': 'Product Name',
    'sellingPrice': 'Selling Price',
    'buyingPrice': 'Buying Price',
    'quantity': 'Quantity',
    'lowStockThreshold': 'Low Stock Warning Qty',
    'barcode': 'Barcode',
    'expiryDate': 'Expiry Date',
    'branchName': 'Branch',
    'supplierName': 'Supplier / Brand',
  };

  static const Map<String, List<String>> userFriendlyAcceptedNames = {
    'name': ['Product Name', 'Product', 'Item Name', 'Item', 'Medicine Name', 'Description'],
    'sellingPrice': ['Selling Price', 'Sell Price', 'Retail Price', 'Price', 'Unit Price', 'SP'],
    'buyingPrice': ['Buying Price', 'Buy Price', 'Cost', 'Cost Price', 'Purchase Price', 'Unit Cost'],
    'quantity': ['Quantity', 'Qty', 'Stock', 'Amount', 'Available', 'Balance'],
    'lowStockThreshold': ['Low Stock Warning Qty', 'Low Stock', 'Threshold', 'Alert At', 'Min Qty'],
  };

  static String _normalizeHeader(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[\s_\-\.\,\:\;\/\\(\)\[\]\*\#\@\!\?]+'), '');
  }

  static String columnIndexToLetter(int index) {
    String letter = '';
    int temp = index;
    while (temp >= 0) {
      letter = String.fromCharCode((temp % 26) + 65) + letter;
      temp = (temp ~/ 26) - 1;
    }
    return 'Column $letter';
  }

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
        try {
          final excel = Excel.decodeBytes(bytes);
          final sheetNames = excel.tables.keys.toList();
          if (sheetNames.isNotEmpty) {
            final first = sheetNames.first;
            final tableData = excel.tables[first];
            if (tableData != null) {
              for (var row in tableData.rows) {
                rows.add(row.map((cell) {
                  if (cell == null) return null;
                  return cell.value;
                }).toList());
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
          }
        }
      } else {
        return ImportResult([], [
          ImportErrorRow(
            rowNumber: 0,
            reason: "Unsupported file type: $extension. Supported format: .xlsx",
            originalData: {},
          )
        ], totalRows: 0);
      }

      if (rows.isEmpty) {
        return ImportResult([], [
          ImportErrorRow(rowNumber: 0, reason: "The selected file is completely empty", originalData: {})
        ], totalRows: 0);
      }

      // 1. Intelligent Header Detection across first 50 rows
      int bestHeaderIndex = -1;
      int maxScore = 0;
      Map<String, int> bestColumnMap = {};
      Map<String, String> bestHeaders = {};
      Map<String, String> bestLetters = {};

      for (int i = 0; i < rows.length && i < 50; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        int rowScore = 0;
        Map<String, int> tempMap = {};
        Map<String, String> tempHeaders = {};
        Map<String, String> tempLetters = {};

        for (int j = 0; j < row.length; j++) {
          final rawCellStr = row[j]?.toString() ?? '';
          final cell = _normalizeHeader(rawCellStr);
          if (cell.isEmpty) continue;

          for (var entry in _normalizedAliases.entries) {
            if (entry.value.contains(cell)) {
              if (!tempMap.containsKey(entry.key)) {
                tempMap[entry.key] = j;
                tempHeaders[entry.key] = rawCellStr.trim();
                tempLetters[entry.key] = columnIndexToLetter(j);
                
                if (entry.key == 'name') {
                  rowScore += 10;
                } else if (entry.key == 'sellingPrice' || entry.key == 'buyingPrice' || entry.key == 'quantity') {
                  rowScore += 5;
                } else {
                  rowScore += 2;
                }
              }
              break;
            }
          }
        }

        if (rowScore > maxScore) {
          maxScore = rowScore;
          bestHeaderIndex = i;
          bestColumnMap = tempMap;
          bestHeaders = tempHeaders;
          bestLetters = tempLetters;
        }
      }

      // If no valid header row was identified (score < 5)
      if (bestHeaderIndex == -1 || maxScore < 5) {
        final Map<String, List<String>> missingAccepted = {
          'Product Name': userFriendlyAcceptedNames['name']!,
          'Selling Price': userFriendlyAcceptedNames['sellingPrice']!,
          'Buying Price': userFriendlyAcceptedNames['buyingPrice']!,
          'Quantity': userFriendlyAcceptedNames['quantity']!,
        };

        return ImportResult(
          [],
          [
            ImportErrorRow(
              rowNumber: 0,
              reason: "Could not detect header row in the first 50 rows of the spreadsheet.",
              originalData: {},
            )
          ],
          totalRows: rows.length,
          missingRequiredColumns: ['Product Name', 'Selling Price', 'Buying Price', 'Quantity'],
          missingAcceptedNames: missingAccepted,
        );
      }

      // Check missing required columns
      final List<String> missingRequiredColumns = [];
      final Map<String, List<String>> missingAcceptedNames = {};

      for (var field in requiredFields) {
        if (!bestColumnMap.containsKey(field)) {
          final displayName = fieldDisplayNames[field] ?? field;
          missingRequiredColumns.add(displayName);
          if (userFriendlyAcceptedNames.containsKey(field)) {
            missingAcceptedNames[displayName] = userFriendlyAcceptedNames[field]!;
          }
        }
      }

      if (missingRequiredColumns.isNotEmpty) {
        final missingStr = missingRequiredColumns.join(', ');
        return ImportResult(
          [],
          [
            ImportErrorRow(
              rowNumber: bestHeaderIndex + 1,
              reason: "Header row detected on Row ${bestHeaderIndex + 1}, but required field(s) missing: $missingStr.",
              originalData: {},
            )
          ],
          totalRows: rows.length - (bestHeaderIndex + 1),
          missingRequiredColumns: missingRequiredColumns,
          detectedHeaders: bestHeaders,
          detectedColumnLetters: bestLetters,
          detectedHeaderRowNumber: bestHeaderIndex + 1,
          missingAcceptedNames: missingAcceptedNames,
        );
      }

      // 2. Process Data Rows starting from bestHeaderIndex + 1
      List<ImportErrorRow> errors = [];
      final Map<String, Map<String, dynamic>> excelProductMap = {};
      final Map<String, int> excelProductRowMap = {};
      int totalDataRowsScanned = 0;
      int inFileDuplicatesMerged = 0;

      for (int i = bestHeaderIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
          continue;
        }

        totalDataRowsScanned++;
        final rowNum = i + 1;

        final rawName = _getVal(row, bestColumnMap['name']);
        final name = _cleanString(rawName);
        final qtyVal = _getCell(row, bestColumnMap['quantity']);
        final costVal = _getCell(row, bestColumnMap['buyingPrice']);
        final priceVal = _getCell(row, bestColumnMap['sellingPrice']);
        final barcode = _getBarcode(row, bestColumnMap['barcode']);
        final expiryVal = _getCell(row, bestColumnMap['expiryDate']);
        final supplier = _cleanString(_getVal(row, bestColumnMap['supplierName']));
        final thresholdVal = _getCell(row, bestColumnMap['lowStockThreshold']);
        final branchName = _cleanString(_getVal(row, bestColumnMap['branchName']));

        final dataSnapshot = {
          'name': rawName,
          'barcode': barcode,
          'quantity': qtyVal?.toString(),
          'buyingPrice': costVal?.toString(),
          'sellingPrice': priceVal?.toString(),
          'expiryDate': expiryVal?.toString(),
          'supplierName': supplier,
          'lowStockThreshold': thresholdVal?.toString(),
          'branchName': branchName,
        };

        // Row Validation
        if (name == null || name.isEmpty) {
          errors.add(ImportErrorRow(
            rowNumber: rowNum,
            productName: "Row $rowNum",
            reason: "Missing Product Name",
            originalData: dataSnapshot,
          ));
          continue;
        }

        if (priceVal == null || priceVal.toString().trim().isEmpty) {
          errors.add(ImportErrorRow(
            rowNumber: rowNum,
            productName: name,
            reason: "Missing Selling Price",
            originalData: dataSnapshot,
          ));
          continue;
        }

        final double price = _parseNumDynamic(priceVal);
        if (price <= 0) {
          errors.add(ImportErrorRow(
            rowNumber: rowNum,
            productName: name,
            reason: "Invalid Selling Price ($priceVal): price must be a positive number",
            originalData: dataSnapshot,
          ));
          continue;
        }

        final double qty = _parseNumDynamic(qtyVal);
        if (qty <= 0) {
          errors.add(ImportErrorRow(
            rowNumber: rowNum,
            productName: name,
            reason: qty == 0
                ? "Quantity is zero — product skipped (no stock to import)"
                : "Invalid Quantity ($qtyVal): quantity cannot be negative",
            originalData: dataSnapshot,
          ));
          continue;
        }

        final double cost = _parseNumDynamic(costVal);
        if (cost < 0) {
          errors.add(ImportErrorRow(
            rowNumber: rowNum,
            productName: name,
            reason: "Invalid Buying Price ($costVal): buying cost cannot be negative",
            originalData: dataSnapshot,
          ));
          continue;
        }

        int threshold = 5;
        if (thresholdVal != null && thresholdVal.toString().trim().isNotEmpty) {
          threshold = _parseNumDynamic(thresholdVal).toInt();
          if (threshold < 0) threshold = 5;
        }

        final DateTime? expiry = _parseDateDynamic(expiryVal);

        final dedupeKey = (barcode != null && barcode.trim().isNotEmpty)
            ? 'barcode:${barcode.trim().toLowerCase()}'
            : 'name:${_normalizeHeader(name)}';

        if (excelProductMap.containsKey(dedupeKey)) {
          final existing = excelProductMap[dedupeKey]!;
          existing['quantity'] = (existing['quantity'] as double) + qty;
          if (price > 0) existing['sellingPrice'] = price;
          if (cost > 0) existing['buyingPrice'] = cost;
          if (expiry != null) existing['expiryDate'] = expiry;
          if (supplier != null && supplier.isNotEmpty) existing['supplierName'] = supplier;
          if (branchName != null && branchName.isNotEmpty) existing['branchName'] = branchName;
          
          inFileDuplicatesMerged++;
        } else {
          final item = {
            'id': _generateId(name, barcode),
            'shopId': shopId,
            'name': name,
            'barcode': barcode ?? '',
            'quantity': qty,
            'buyingPrice': cost,
            'sellingPrice': price,
            'expiryDate': expiry,
            'supplierName': supplier?.isEmpty == true ? null : supplier,
            'lowStockThreshold': threshold,
            'branchName': branchName,
            '_sourceRow': rowNum,
          };
          excelProductMap[dedupeKey] = item;
          excelProductRowMap[dedupeKey] = rowNum;
        }
      }

      final List<Map<String, dynamic>> validItems = excelProductMap.values.toList();

      return ImportResult(
        validItems, 
        errors, 
        totalRows: totalDataRowsScanned,
        inFileDuplicatesMerged: inFileDuplicatesMerged,
        missingRequiredColumns: missingRequiredColumns,
        detectedHeaders: bestHeaders,
        detectedColumnLetters: bestLetters,
        detectedHeaderRowNumber: bestHeaderIndex + 1,
        missingAcceptedNames: missingAcceptedNames,
      );
    } catch (e) {
      return ImportResult([], [
        ImportErrorRow(
          rowNumber: 0,
          reason: "Failed to parse spreadsheet: $e",
          originalData: {},
        )
      ], totalRows: 0);
    }
  }

  static String? _cleanString(String? input) {
    if (input == null) return null;
    final s = input.trim();
    return s.isEmpty ? null : s;
  }

  static dynamic _getCell(List<dynamic> row, int? index) {
    if (index == null || index < 0 || index >= row.length) return null;
    return row[index];
  }

  static String? _getVal(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) return null;
    final val = row[index];
    if (val == null) return null;
    return val.toString();
  }

  static String? _getBarcode(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) return null;
    final val = row[index];
    if (val == null) return null;
    
    String s = val.toString().trim();
    if (s.isEmpty) return null;

    if (s.toLowerCase().contains('e+')) {
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
    
    String s = input.toString().trim();
    if (s.isEmpty) return 0.0;
    
    if (s.startsWith('=')) return 0.0; 

    s = s.replaceAll(',', '');
    
    final match = RegExp(r'[-+]?\d*\.?\d+').firstMatch(s);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 0.0;
    }
    
    return 0.0;
  }

  static DateTime? _parseDateDynamic(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    if (input is num) {
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
      'dd.MM.yyyy',
      'MM.dd.yyyy',
      'dd MM yyyy',
      'dd-MMM-yyyy',
      'dd-MM-yy',
      'MM/dd/yy',
      'dd/MM/yy',
    ];

    for (var f in formats) {
      try {
        return DateFormat(f).parseStrict(s);
      } catch (_) {}
    }
    for (var f in formats) {
      try {
        return DateFormat(f).parse(s);
      } catch (_) {}
    }
    
    return DateTime.tryParse(s);
  }

  static String _generateId(String name, String? barcode) {
    if (barcode != null && barcode.trim().isNotEmpty) return barcode.trim();
    return "${name.toLowerCase().trim().replaceAll(' ', '_')}_${DateTime.now().microsecondsSinceEpoch}";
  }
}
