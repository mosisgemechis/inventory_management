import sys
import os
import re

path = r'c:\projects\inventory_management\lib\core\services\import_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Normalize
content_norm = content.replace('\r\n', '\n')

# Find finalizeImport
start_match = re.search(r'Future<void> finalizeImport\(AppUser user, List<Map<String, dynamic>> itemsToProcess\) async \{', content_norm)
if not start_match:
    print("FAILURE: finalizeImport not found")
    sys.exit(1)

# Find end
bracket_count = 0
found_end = -1
for i in range(start_match.start(), len(content_norm)):
    char = content_norm[i]
    if char == '{':
        bracket_count += 1
    elif char == '}':
        bracket_count -= 1
        if bracket_count == 0:
            found_end = i + 1
            break

if found_end == -1:
    print("FAILURE: finalizeImport end not found")
    sys.exit(1)

new_code = r'''  Future<ImportFinalizeResult> finalizeImport(AppUser user, ImportResult parseResult, Map<String, ImportResolutionStrategy> resolutions) async {
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
  }'''

updated = content_norm[:start_match.start()] + new_code + content_norm[found_end:]

with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(updated)
print("SUCCESS: finalizeImport updated")
