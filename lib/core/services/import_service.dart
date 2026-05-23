import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:file_picker/file_picker.dart';
import 'dart:io' show File;
import 'database_service.dart';
import 'bulk_import/import_worker.dart';
import 'bulk_import/import_models.dart';
import '../models/models.dart' hide Product;
import '../db/app_database.dart';
import 'package:drift/drift.dart';

class ImportService {
  final DatabaseService _db = DatabaseService();

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
    if (v is DateTime) return v.toUtc();
    return DateTime.tryParse(v.toString())?.toUtc();
  }

  Future<ImportResult> pickAndParse(AppUser user) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return ImportResult([], [ImportErrorRow(rowNumber: 0, reason: "No file selected", originalData: {})]);
    }

    final file = result.files.first;
    Uint8List? rawBytes = file.bytes;
    final path = file.path;
    if (rawBytes == null && path != null && path.trim().isNotEmpty) {
      rawBytes = await File(path).readAsBytes();
    }
    if (rawBytes == null || rawBytes.isEmpty) {
      return ImportResult([], [ImportErrorRow(rowNumber: 0, reason: "Could not read file. Please try again.", originalData: {})]);
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
      return ImportResult([], [
        ImportErrorRow(
          rowNumber: 0,
          reason: "Import parser crashed: $e",
          originalData: {},
        )
      ]);
    }

    if (parseResult.validCompanions.isEmpty) {
      return parseResult;
    }

    // Identify duplicates
    final List<dynamic> valid = [];
    final List<ImportDuplicateRow> duplicates = [];
    final branchId = user.branchId ?? 'main';

    for (final itemMap in parseResult.validCompanions) {
      final data = Map<String, dynamic>.from(itemMap);
      final barcode = _asTrimmedString(data['barcode']) ?? '';
      final name = _asTrimmedString(data['name']) ?? '';
      
      Product? existing;
      if (barcode.isNotEmpty) {
        existing = await (_db.db.select(_db.db.products)
              ..where((t) => t.shopId.equals(user.shopId) & t.barcode.equals(barcode))
              ..where((t) => branchId == 'all' ? const Constant(true) : (t.branchId.equals(branchId) | t.branchId.isNull()))
              ..limit(1))
            .getSingleOrNull();
      } else {
        existing = await (_db.db.select(_db.db.products)
              ..where((t) => t.shopId.equals(user.shopId) & t.name.equals(name))
              ..where((t) => branchId == 'all' ? const Constant(true) : (t.branchId.equals(branchId) | t.branchId.isNull()))
              ..limit(1))
            .getSingleOrNull();
      }

      if (existing != null) {
        duplicates.add(ImportDuplicateRow(
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

    return ImportResult(valid, parseResult.errors, duplicates: duplicates);
  }

    Future<ImportFinalizeResult> finalizeImport(AppUser user, ImportResult parseResult, Map<String, ImportResolutionStrategy> resolutions) async {
    final shopId = user.shopId;
    final defaultBranchId = user.branchId ?? 'main';
    int importedCount = 0;

    final List<Map<String, dynamic>> finalProcessingList = [];
    for (var item in parseResult.validCompanions) {
      finalProcessingList.add({...item as Map<String, dynamic>, '_action': 'create'});
    }
    for (var duplicate in parseResult.duplicates) {
      final id = duplicate.existingData['id'];
      final strategy = resolutions[id] ?? ImportResolutionStrategy.skip;
      if (strategy == ImportResolutionStrategy.skip) continue;
      finalProcessingList.add({
        ...duplicate.newData,
        '_action': strategy == ImportResolutionStrategy.replace ? 'replace' : 'restock',
        'existingId': id,
      });
    }

    await _db.runTransaction(() async {
      for (var item in finalProcessingList) {
        importedCount++;
        final action = item['_action'] ?? 'create';
        final data = Map<String, dynamic>.from(item);
        final sourceRow = data['_sourceRow'] ?? -1;
        data.remove('_action');
        data.remove('_sourceRow');

        String effectiveId = data['id'] ?? '';
        final branchId = data['branchName'] != null ? (await _resolveBranchId(shopId, data['branchName']!)) : defaultBranchId;

        if (action == 'restock') {
          final existingId = data['existingId'];
          if (existingId != null) {
            final row = await (_db.db.select(_db.db.products)..where((t) => t.id.equals(existingId))).getSingleOrNull();
            if (row != null) {
              effectiveId = row.id;
              final newQty = row.quantity + _asDouble(data['quantity']);
              await (_db.db.update(_db.db.products)..where((t) => t.id.equals(row.id))).write(
                ProductsCompanion(
                  quantity: Value(newQty),
                  lastModified: Value(DateTime.now().toUtc()),
                  syncStatus: const Value('pendingUpload'),
                )
              );
            }
          }
        } else {
          await _db.productsDao.upsert(ProductsCompanion.insert(
            id: effectiveId,
            shopId: shopId,
            branchId: branchId,
            name: data['name'],
            barcode: Value(data['barcode'] ?? ''),
            quantity: _asDouble(data['quantity']),
            buyingPrice: _asDouble(data['buyingPrice']),
            sellingPrice: _asDouble(data['sellingPrice']),
            expiryDate: Value(_asDateTime(data['expiryDate'])),
            lowStockThreshold: Value(data['lowStockThreshold'] is int ? data['lowStockThreshold'] : (int.tryParse(data['lowStockThreshold']?.toString() ?? '5') ?? 5)),
            syncStatus: const Value('pendingUpload'),
            lastModified: Value(DateTime.now().toUtc()),
          ));
        }

        final supplierName = _asTrimmedString(data['supplierName']);

        // ── Always ensure a batch record exists so the sale engine can deduct stock ──
        if (action == 'create' || action == 'replace') {
          final qty = _asDouble(data['quantity']);
          if (qty > 0) {
            await _db.db.into(_db.db.batches).insert(
              BatchesCompanion.insert(
                id: 'IMPORT-BATCH-${DateTime.now().millisecondsSinceEpoch}-$sourceRow',
                shopId: shopId,
                itemId: effectiveId,
                quantity: qty,
                buyingPrice: _asDouble(data['buyingPrice']),
                expiryDate: Value(_asDateTime(data['expiryDate'])),
                batchNumber: Value(_asTrimmedString(data['batchNumber'])),
                timestamp: DateTime.now().toUtc(),
                branchId: Value(branchId),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        } else if (action == 'restock') {
          final existingId = data['existingId'];
          final qty = _asDouble(data['quantity']);
          if (existingId != null && qty > 0) {
            await _db.db.into(_db.db.batches).insert(
              BatchesCompanion.insert(
                id: 'IMPORT-BATCH-RESTOCK-${DateTime.now().millisecondsSinceEpoch}-$sourceRow',
                shopId: shopId,
                itemId: existingId,
                quantity: qty,
                buyingPrice: _asDouble(data['buyingPrice']),
                expiryDate: Value(_asDateTime(data['expiryDate'])),
                batchNumber: Value(_asTrimmedString(data['batchNumber'])),
                timestamp: DateTime.now().toUtc(),
                branchId: Value(branchId),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
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
              id: "IMPORT-${DateTime.now().millisecondsSinceEpoch}-$sourceRow",
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
      }
    });
    return ImportFinalizeResult(importedCount);
  }

  Future<String> _resolveBranchId(String shopId, String branchName) async {
    final results = await _db.query('branches', where: 'shop_id = ? AND name = ?', whereArgs: [shopId, branchName]);
    if (results.isNotEmpty) return results.first['id'];
    return 'main';
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
