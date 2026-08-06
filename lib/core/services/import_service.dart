import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'package:excel/excel.dart';
import 'database_service.dart';
import 'bulk_import/import_worker.dart';
import 'bulk_import/import_models.dart';
import '../models/models.dart' hide Product;
import '../db/app_database.dart';
import 'package:drift/drift.dart';
import '../repositories/inventory_repository.dart';

class ImportService {
  final DatabaseService _db = DatabaseService();
  final InventoryRepository _repo = InventoryRepository();

  String? _asTrimmedString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return 0.0;
    final cleaned = s.replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    DateTime? dt;
    if (v is DateTime) {
      dt = v;
    } else {
      dt = DateTime.tryParse(v.toString());
    }
    if (dt == null) return null;
    return DateTime.utc(dt.year, dt.month, dt.day);
  }

  /// Generates a clean Excel template file (.xlsx) with standard header fields and sample data.
  Uint8List generateTemplateExcel() {
    final excel = Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Inventory_Template');
    final Sheet sheet = excel['Inventory_Template'];

    final List<CellValue> headerRow = [
      TextCellValue('Product Name *'),
      TextCellValue('Selling Price *'),
      TextCellValue('Buying Price *'),
      TextCellValue('Quantity *'),
      TextCellValue('Low Stock Warning Qty *'),
      TextCellValue('Barcode'),
      TextCellValue('Expiry Date'),
      TextCellValue('Branch'),
    ];

    sheet.appendRow(headerRow);

    // Sample data rows
    sheet.appendRow([
      TextCellValue('Paracetamol 500mg'),
      DoubleCellValue(15.00),
      DoubleCellValue(10.00),
      DoubleCellValue(100.0),
      IntCellValue(10),
      TextCellValue('690123456789'),
      TextCellValue('2026-12-31'),
      TextCellValue('Main'),
    ]);

    sheet.appendRow([
      TextCellValue('Amoxicillin 250mg'),
      DoubleCellValue(45.50),
      DoubleCellValue(30.00),
      DoubleCellValue(50.0),
      IntCellValue(5),
      TextCellValue('690987654321'),
      TextCellValue('2025-08-15'),
      TextCellValue('Main'),
    ]);

    final bytes = excel.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Prompts user to save the generated template file to their disk.
  Future<String?> downloadTemplateFile() async {
    final bytes = generateTemplateExcel();
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Inventory Import Template',
      fileName: 'Inventory_Import_Template.xlsx',
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: bytes,
    );

    if (result != null && result.isNotEmpty) {
      final file = File(result);
      await file.writeAsBytes(bytes);
      return result;
    }
    return null;
  }

  Future<ImportResult> pickAndParse(AppUser user) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult(
        [], 
        [ImportErrorRow(rowNumber: 0, reason: "No file selected", originalData: {})], 
        totalRows: 0,
      );
    }

    final file = result.files.first;
    Uint8List? rawBytes = file.bytes;
    final path = file.path;
    if (rawBytes == null && path != null && path.trim().isNotEmpty) {
      rawBytes = await File(path).readAsBytes();
    }
    if (rawBytes == null || rawBytes.isEmpty) {
      return ImportResult(
        [], 
        [ImportErrorRow(rowNumber: 0, reason: "Could not read spreadsheet file. Please try again.", originalData: {})], 
        totalRows: 0,
      );
    }
    final List<int> bytes = rawBytes.toList();
    final String extension = file.extension?.toLowerCase() ?? 'xlsx';

    ImportResult parseResult;
    try {
      parseResult = await compute(
        _runWorker,
        _WorkerArgs(bytes: bytes, extension: extension, shopId: user.shopId),
      );
    } catch (e) {
      return ImportResult(
        [], 
        [ImportErrorRow(rowNumber: 0, reason: "Spreadsheet parser error: $e", originalData: {})], 
        totalRows: 0,
      );
    }

    if (parseResult.validCompanions.isEmpty && parseResult.errors.isNotEmpty) {
      return parseResult;
    }

    final branchId = user.branchId ?? 'main';
    // Fetch existing database products to detect database duplicates (Requirement 4A)
    final allProducts = await (_db.db.select(_db.db.products)
          ..where((t) => t.shopId.equals(user.shopId))
          ..where((t) => branchId == 'all' ? const Constant(true) : (t.branchId.equals(branchId) | t.branchId.isNull())))
        .get();

    final Map<String, Product> productBarcodeMap = {
      for (var p in allProducts) if (p.barcode.trim().isNotEmpty) p.barcode.trim().toLowerCase(): p
    };
    final Map<String, Product> productNameMap = {
      for (var p in allProducts) p.name.trim().toLowerCase(): p
    };

    final List<dynamic> valid = [];
    final List<ImportDuplicateRow> databaseDuplicates = [];

    for (final itemMap in parseResult.validCompanions) {
      final data = Map<String, dynamic>.from(itemMap);
      final barcode = (_asTrimmedString(data['barcode']) ?? '').toLowerCase();
      final name = (_asTrimmedString(data['name']) ?? '').toLowerCase();
      
      Product? existing = (barcode.isNotEmpty) ? productBarcodeMap[barcode] : productNameMap[name];

      if (existing != null) {
        databaseDuplicates.add(ImportDuplicateRow(
          newData: data,
          existingData: {
            'id': existing.id,
            'name': existing.name,
            'barcode': existing.barcode,
            'quantity': existing.quantity,
            'buyingPrice': existing.buyingPrice,
            'sellingPrice': existing.sellingPrice,
          },
          rowNumber: data['_sourceRow'] ?? -1,
        ));
      } else {
        valid.add(data);
      }
    }

    return ImportResult(
      valid, 
      parseResult.errors, 
      duplicates: databaseDuplicates, 
      totalRows: parseResult.totalRows,
      inFileDuplicatesMerged: parseResult.inFileDuplicatesMerged,
      missingRequiredColumns: parseResult.missingRequiredColumns,
      detectedHeaders: parseResult.detectedHeaders,
      detectedColumnLetters: parseResult.detectedColumnLetters,
      detectedHeaderRowNumber: parseResult.detectedHeaderRowNumber,
      missingAcceptedNames: parseResult.missingAcceptedNames,
    );
  }

  ImportValidationSummary getValidationSummary(ImportResult result) {
    final warningCount = result.inFileDuplicatesMerged;
    final errorCount = result.errors.length;
    final validRows = result.validCompanions.length + result.duplicates.length;

    return ImportValidationSummary(
      totalRows: result.totalRows,
      validRows: validRows,
      inFileDuplicatesMerged: result.inFileDuplicatesMerged,
      databaseDuplicatesCount: result.duplicates.length,
      warningCount: warningCount,
      errorCount: errorCount,
      missingRequiredColumns: result.missingRequiredColumns,
      detectedHeaders: result.detectedHeaders,
      detectedColumnLetters: result.detectedColumnLetters,
      detectedHeaderRowNumber: result.detectedHeaderRowNumber,
      missingAcceptedNames: result.missingAcceptedNames,
    );
  }

  Future<ImportFinalizeResult> finalizeImport(
    AppUser user,
    ImportResult parseResult,
    Map<String, ImportResolutionStrategy> resolutions, {
    Function(ImportProgressState state)? onProgress,
    ImportCancellationToken? cancellationToken,
  }) async {
    final shopId = user.shopId;
    final defaultBranchId = user.branchId ?? 'main';
    
    int importedCount = 0;
    int updatedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;
    int cancelledCount = 0;
    bool wasCancelled = false;
    final List<ImportErrorRow> finalErrors = List.from(parseResult.errors);

    final List<Map<String, dynamic>> finalProcessingList = [];
    for (var item in parseResult.validCompanions) {
      finalProcessingList.add({...item as Map<String, dynamic>, '_action': 'create'});
    }
    for (var duplicate in parseResult.duplicates) {
      final id = duplicate.existingData['id'];
      final strategy = resolutions[id] ?? ImportResolutionStrategy.skip;
      if (strategy == ImportResolutionStrategy.skip) {
        skippedCount++;
        continue;
      }
      finalProcessingList.add({
        ...duplicate.newData,
        '_action': strategy == ImportResolutionStrategy.replace ? 'replace' : 'restock',
        'existingId': id,
      });
    }

    final total = finalProcessingList.length;

    // Process row by row with per-row isolation
    for (int i = 0; i < total; i++) {
      final item = finalProcessingList[i];
      final sourceRow = item['_sourceRow'] ?? -1;
      final productName = item['name']?.toString() ?? 'Item ${i + 1}';
      
      // Update progress
      onProgress?.call(ImportProgressState(
        current: i + 1,
        total: total,
        currentProductName: productName,
        importedCount: importedCount,
        updatedCount: updatedCount,
        skippedCount: skippedCount,
        failedCount: failedCount,
      ));

      // Yield every 5 rows to keep UI thread fluid
      if (i % 5 == 0) {
        await Future.delayed(const Duration(milliseconds: 5));
      }

      // Check cancellation AFTER yielding so the current row-in-flight completes
      if (cancellationToken?.isCancelled == true) {
        cancelledCount = total - i;
        wasCancelled = true;
        break;
      }

      try {
        await _db.runTransaction(() async {
          final action = item['_action'] ?? 'create';
          final data = Map<String, dynamic>.from(item);
          data.remove('_action');
          data.remove('_sourceRow');

          String effectiveId = data['id'] ?? '';
          
          // Non-blocking branch resolution: fallback to default branch if branch doesn't exist
          final branchNameInput = data['branchName'];
          final branchId = (branchNameInput != null && branchNameInput.toString().trim().isNotEmpty) 
              ? (await _resolveBranchId(shopId, branchNameInput.toString().trim(), defaultBranchId: defaultBranchId)) 
              : defaultBranchId;

          if (action == 'restock' || action == 'replace') {
            final existingId = data['existingId'];
            if (existingId != null) {
              effectiveId = existingId;
            }
            if (action == 'replace') {
              final productData = {
                'id': effectiveId,
                'shopId': shopId,
                'branchId': branchId,
                'name': data['name'],
                'barcode': data['barcode'] ?? '',
                'quantity': _asDouble(data['quantity']),
                'buyingPrice': _asDouble(data['buyingPrice']),
                'sellingPrice': _asDouble(data['sellingPrice']),
                'expiryDate': _asDateTime(data['expiryDate'])?.toIso8601String(),
                'lowStockThreshold': data['lowStockThreshold'] is int ? data['lowStockThreshold'] : (int.tryParse(data['lowStockThreshold']?.toString() ?? '5') ?? 5),
              };
              await _db.saveProduct(productData);
            }
            updatedCount++;
          } else {
            final productData = {
              'id': effectiveId,
              'shopId': shopId,
              'branchId': branchId,
              'name': data['name'],
              'barcode': data['barcode'] ?? '',
              'quantity': _asDouble(data['quantity']),
              'buyingPrice': _asDouble(data['buyingPrice']),
              'sellingPrice': _asDouble(data['sellingPrice']),
              'expiryDate': _asDateTime(data['expiryDate'])?.toIso8601String(),
              'lowStockThreshold': data['lowStockThreshold'] is int ? data['lowStockThreshold'] : (int.tryParse(data['lowStockThreshold']?.toString() ?? '5') ?? 5),
            };
            
            await _db.saveProduct(productData);
            importedCount++;
          }

          final supplierName = _asTrimmedString(data['supplierName']);
          final qty = _asDouble(data['quantity']);
          
          if (qty > 0) {
            final batchId = 'BATCH-IMPORT-${DateTime.now().millisecondsSinceEpoch}-$i';
            final expiry = _asDateTime(data['expiryDate']);
            
            await _db.db.into(_db.db.batches).insert(
              BatchesCompanion.insert(
                id: batchId,
                shopId: shopId,
                itemId: effectiveId,
                quantity: qty,
                buyingPrice: _asDouble(data['buyingPrice']),
                sellingPrice: Value(_asDouble(data['sellingPrice'])),
                expiryDate: Value(expiry),
                batchNumber: Value(_asTrimmedString(data['batchNumber'])),
                timestamp: DateTime.now().toUtc(),
                branchId: Value(branchId),
                type: const Value('import'),
                syncStatus: const Value('pendingUpload'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
              mode: InsertMode.insertOrReplace,
            );
            
            await _db.enqueueOutboxManual(
              shopId: shopId,
              branchId: branchId,
              table: 'batches',
              recordId: batchId,
              operation: 'upsert',
              payload: {
                'id': batchId,
                'shopId': shopId,
                'itemId': effectiveId,
                'quantity': qty,
                'buyingPrice': _asDouble(data['buyingPrice']),
                'sellingPrice': _asDouble(data['sellingPrice']),
                'expiryDate': expiry?.toUtc().toIso8601String(),
                'batchNumber': _asTrimmedString(data['batchNumber']),
                'timestamp': DateTime.now().toUtc().toIso8601String(),
                'branchId': branchId,
                'type': 'import',
              },
            );
          }

          if (supplierName != null && supplierName.isNotEmpty) {
            await _db.db.into(_db.db.suppliers).insert(
              SuppliersCompanion.insert(
                id: supplierName,
                shopId: shopId,
                name: supplierName,
                syncStatus: const Value('pendingUpload'),
                lastModified: Value(DateTime.now().toUtc()),
              ),
              mode: InsertMode.insertOrReplace,
            );
            await _db.db.into(_db.db.purchases).insert(
              PurchasesCompanion.insert(
                id: "IMPORT-${DateTime.now().millisecondsSinceEpoch}-$i",
                shopId: shopId,
                itemId: effectiveId,
                itemName: data['name'],
                barcode: Value(data['barcode'] ?? ''),
                quantity: _asDouble(data['quantity']),
                unitCost: _asDouble(data['buyingPrice']),
                totalCost: _asDouble(data['quantity']) * _asDouble(data['buyingPrice']),
                supplierName: Value(supplierName),
                expiryDate: Value(_asDateTime(data['expiryDate'])),
                timestamp: DateTime.now(),
                syncStatus: const Value('pendingUpload'),
                lastModified: Value(DateTime.now().toUtc()),
                branchId: Value(branchId),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      } catch (e) {
        failedCount++;
        finalErrors.add(ImportErrorRow(
          rowNumber: sourceRow,
          productName: item['name']?.toString(),
          reason: "Row insertion error: $e",
          originalData: Map<String, dynamic>.from(item),
        ));
      }
    }

    // Recalculate stock cache for all affected items
    final uniqueIds = finalProcessingList.map((e) => e['existingId'] ?? e['id']).whereType<String>().toSet().toList();
    for (int j = 0; j < uniqueIds.length; j++) {
       if (j % 10 == 0) await Future.delayed(const Duration(milliseconds: 5));
       await _repo.forceRecalculate(shopId, uniqueIds[j]);
    }

    onProgress?.call(ImportProgressState(
      current: total,
      total: total,
      currentProductName: wasCancelled ? "Cancelled" : "Done",
      importedCount: importedCount,
      updatedCount: updatedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      isCancelled: wasCancelled,
    ));

    return ImportFinalizeResult(
      totalRows: parseResult.totalRows,
      importedCount: importedCount,
      updatedCount: updatedCount,
      skippedCount: skippedCount,
      failedCount: failedCount,
      cancelledCount: cancelledCount,
      wasCancelled: wasCancelled,
      errorDetails: finalErrors,
    );
  }

  Future<String> _resolveBranchId(String shopId, String branchName, {required String defaultBranchId}) async {
    final results = await _db.query('branches', where: 'shop_id = ? AND name = ?', whereArgs: [shopId, branchName]);
    if (results.isNotEmpty) return results.first['id'];
    return defaultBranchId;
  }
}

ImportResult _runWorker(_WorkerArgs args) {
  return ImportWorker.parseSpreadsheet(
    bytes: args.bytes,
    extension: args.extension,
    shopId: args.shopId,
  );
}

class _WorkerArgs {
  final List<int> bytes;
  final String extension;
  final String shopId;
  _WorkerArgs({required this.bytes, required this.extension, required this.shopId});
}
