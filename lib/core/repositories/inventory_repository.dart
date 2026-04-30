import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/validation_service.dart';
import '../models/models.dart';

class InventoryRepository {
  final DatabaseService _local = DatabaseService();
  final FirestoreService _remote = FirestoreService();
  final ValidationService _validator = ValidationService();
  final _uuid = const Uuid();

  Future<void> registerItem(AppUser user, Map<String, dynamic> data) async {
    // 1. Validation (Quick local check)
    await _validator.validateProduct(
      user.shopId, 
      data['name'] ?? '', 
      data['barcode'] ?? '',
      data['batchNumber']
    );

    // 1b. Duplicate Check (Name-based)
    final existing = await _local.searchItems(user.shopId, data['name'] ?? '', '');
    if (existing.isNotEmpty && data['id'] == null) {
       throw Exception('A product with this name already exists in your inventory.');
    }

    // 2. Prep data
    final id = data['id'] ?? data['uniqueId'] ?? _uuid.v4(); 
    final finalData = {
      ...data,
      'id': id,
      'shopId': user.shopId,
      'isSynced': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    // 3. Instant Local Save (Set quantity to 0 initially, batches will populate it)
    final initialQty = (finalData['quantity'] ?? 0).toDouble();
    finalData['quantity'] = 0.0;
    await _local.saveProduct(finalData);

    // 4. Fire-and-forget Background Sync for Item Identity
    _remote.addItem(finalData, addedBy: user.username).then((_) {
      _local.markSynced('products', id);
    }).catchError((e) {
      debugPrint("Background Sync Delay (Products): $e");
    });

    // 5. If initial stock exists, trigger batch engine immediately
    if (initialQty > 0) {
      await recordRestock(user, {
        'shopId': user.shopId,
        'itemId': id,
        'itemName': finalData['name'],
        'addedQuantity': initialQty,
        'buyingPrice': finalData['buyingPrice'],
        'expiryDate': finalData['expiryDate'] is Timestamp 
            ? (finalData['expiryDate'] as Timestamp).toDate().toIso8601String()
            : finalData['expiryDate']?.toString(),
        'supplierName': finalData['supplierName'],
      });
    }
  }

  /// THE BATCH ENGINE: Direct/Global Restock Logic 
  /// Implements "Traceable Batch Inventory" Smart-Merge
  Future<void> recordRestock(AppUser user, Map<String, dynamic> restockData) async {
    // Requires: itemId, itemName, addedQuantity, buyingPrice, expiryDate
    // NO duplicate detector constraint here because it operates on existing items.
    
    final String itemId = restockData['itemId'];
    final double incomingQty = (restockData['addedQuantity'] ?? 0).toDouble();
    if (incomingQty <= 0) throw Exception("Restock quantity must be greater than zero.");

    // ISO 8601 Formatting strictly enforced
    String? incomingExpiryStr = restockData['expiryDate'];
    if (incomingExpiryStr != null && incomingExpiryStr.isNotEmpty) {
      // Ensure ISO formatting 
      final dt = DateTime.tryParse(incomingExpiryStr);
      if (dt != null) incomingExpiryStr = dt.toIso8601String();
    } else {
      incomingExpiryStr = null; // Correctly handle non-expiring stock
    }

    // 1. Fetch existing batches for smart-merge (local first)
    final existingBatches = await _local.query('batches', 
      where: 'shopId = ? AND itemId = ?', 
      whereArgs: [user.shopId, itemId]);

    String activeBatchId = _uuid.v4();
    bool merged = false;
    double newBatchTotal = incomingQty;

    // 2. The Smart-Merge (using null-safe comparison)
    for (var b in existingBatches) {
      final oldExp = b['expiryDate']?.toString();
      if (oldExp == incomingExpiryStr) {
        // MATCH: Same expiry. Add to existing batch.
        activeBatchId = b['id'];
        newBatchTotal = (b['quantity'] ?? 0.0) + incomingQty;
        merged = true;
        break;
      }
    }

    // 3. Perform the Batch Local Insert/Update
    final batchData = {
      'id': activeBatchId,
      'shopId': user.shopId,
      'itemId': itemId,
      'quantity': newBatchTotal,
      'buyingPrice': (restockData['buyingPrice'] ?? 0).toDouble(),
      'expiryDate': incomingExpiryStr,
      'batchNumber': restockData['batchNumber'] ?? '', // optional
      'timestamp': DateTime.now().toIso8601String(),
      'isSynced': 0,
    };

    if (merged) {
      await _local.update('batches', batchData, where: 'id = ?', whereArgs: [activeBatchId]);
    } else {
      await _local.insert('batches', batchData);
    }

    // 4. Update the Product's flat quantity cache temporarily to ensure UI compatibility
    final summary = await _recalculateItemStock(user.shopId, itemId);

    // 5. Fire-and-forget sync for Batch and absolute product summary
    _remote.recordBatch(batchData, itemSummaryUpdate: summary).then((_) {
      _local.markSynced('batches', activeBatchId);
    }).catchError((e) {
      debugPrint("Batch Sync Error: $e");
    });
  }

  /// Sums all active unexpired batches for this product and returns the item cached `quantity` and `expiryDate`
  Future<Map<String, dynamic>> _recalculateItemStock(String shopId, String itemId) async {
    final batches = await _local.query('batches', where: 'shopId = ? AND itemId = ?', whereArgs: [shopId, itemId]);
    double activeStock = 0.0;
    DateTime? closestActiveExpiry;
    
    for (var b in batches) {
       final qty = (b['quantity'] ?? 0.0).toDouble();
       final exp = DateTime.tryParse(b['expiryDate']?.toString() ?? '');
       
       if (qty > 0) {
          if (exp != null) {
              if (closestActiveExpiry == null || exp.isBefore(closestActiveExpiry)) {
                 closestActiveExpiry = exp;
              }
          }
          
          // Fix: Ensure items expiring TODAY are still counted as active stock.
          // DateTime.now() has time component, so we check against start of tomorrow or just date match.
          bool isExpired = false;
          if (exp != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final expiryDate = DateTime(exp.year, exp.month, exp.day);
            if (expiryDate.isBefore(today)) {
              isExpired = true;
            }
          }

          if (!isExpired) {
             activeStock += qty;
          }
       }
    }

    final updateData = {
      'quantity': activeStock, 
      if (closestActiveExpiry != null) 'expiryDate': closestActiveExpiry.toIso8601String()
      else 'expiryDate': null,
    };

    // Update local immediately
    await _local.update('products', {...updateData, 'isSynced': 0}, where: 'id = ?', whereArgs: [itemId]);
    return updateData;
  }


  Future<void> recordSale(AppUser user, Map<String, dynamic> saleData) async {
    final totalPrice = (saleData['totalPrice'] ?? 0.0).toDouble();
    if (totalPrice <= 0) throw Exception('Total price must be greater than zero.');

    final itemId = saleData['itemId'];
    double qtyToDeduct = (saleData['quantity'] ?? 0).toDouble();

    // --- 1. LOCAL FEFO DEDUCTION (First-Expiry, First-Out) ---
    // Fetch and sort batches by expiryDate ascending
    final existingBatches = await _local.query('batches', 
      where: 'shopId = ? AND itemId = ?', 
      whereArgs: [user.shopId, itemId]);

    // We can't mutate the db result list directly, make a mutable list of maps
    List<Map<String, dynamic>> mutableBatches = existingBatches.map((e) => Map<String, dynamic>.from(e)).toList();

    // Sort by Expiry Date
    mutableBatches.sort((a, b) {
      final tA = DateTime.tryParse(a['expiryDate']?.toString() ?? '') ?? DateTime(2100);
      final tB = DateTime.tryParse(b['expiryDate']?.toString() ?? '') ?? DateTime(2100);
      return tA.compareTo(tB);
    });

    List<Map<String, dynamic>> updatedBatchesToSync = [];
    double totalRecalculatedProfit = 0;
    final sellPrice = (saleData['sellingPrice'] ?? (totalPrice / ((saleData['quantity'] == 0 ? 1 : saleData['quantity'])))).toDouble();

    for (var i = 0; i < mutableBatches.length; i++) {
        if (qtyToDeduct <= 0) break;

        var b = mutableBatches[i];
        double bQty = (b['quantity'] ?? 0).toDouble();
        
        if (bQty <= 0) continue; // Skip empty batches

        double qtyTaken = 0;
        if (bQty <= qtyToDeduct) {
           qtyTaken = bQty;
           qtyToDeduct -= bQty;
           b['quantity'] = 0.0;
        } else {
           qtyTaken = qtyToDeduct;
           b['quantity'] = bQty - qtyToDeduct;
           qtyToDeduct = 0;
        }

        final bBuyingPrice = (b['buyingPrice'] ?? 0).toDouble();
        totalRecalculatedProfit += (sellPrice - bBuyingPrice) * qtyTaken;

        b['isSynced'] = 0;
        updatedBatchesToSync.add(b);
        await _local.update('batches', b, where: 'id = ?', whereArgs: [b['id']]);
    }

    if (qtyToDeduct > 0) {
      final defaultProfitPerUnit = (saleData['profit'] ?? 0) / (saleData['quantity'] == 0 ? 1 : saleData['quantity']);
      totalRecalculatedProfit += (defaultProfitPerUnit * qtyToDeduct);
    }

    // --- 2. RECORD SALE ---
    final id = _uuid.v4();
    final finalSale = {
      ...saleData,
      'profit': totalRecalculatedProfit, // OVERRIDE WITH EXACT TRACEABLE BATCH PROFIT
      'id': id,
      'isSynced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _local.saveSale(finalSale);
    final summaryUpdate = await _recalculateItemStock(user.shopId, itemId);
    
    // --- 3. SYNC TO CLOUD ---
    // We send BOTH the sale AND the batch deduction updates + absolute item summary in one atomic push!
    _remote.recordSaleWithBatches(finalSale, updatedBatchesToSync, itemSummaryUpdate: summaryUpdate).then((_) {
       _local.markSynced('sales', id);
       for (var b in updatedBatchesToSync) {
          _local.markSynced('batches', b['id']);
       }
    }).catchError((e) {
       debugPrint("Background Sync Delay (Sales/Batches): $e");
    });
  }

  Future<void> updatePurchase(AppUser user, String purchaseId, Map<String, dynamic> data) async {
    // Only supplierName and price allowed for editing in logs as per request
    final cleanData = {
      if (data.containsKey('supplierName')) 'supplierName': data['supplierName'],
      if (data.containsKey('unitCost')) 'unitCost': data['unitCost'],
      if (data.containsKey('totalCost')) 'totalCost': data['totalCost'],
      'isSynced': 0,
    };
    
    await _local.update('purchases', cleanData, where: 'id = ?', whereArgs: [purchaseId]);
    _remote.updatePurchase(purchaseId, cleanData).then((_) {
       _local.markSynced('purchases', purchaseId);
    });
  }

  Future<void> recordPurchase(AppUser user, Map<String, dynamic> purchaseData) async {
    final id = _uuid.v4();
    final finalPurchase = {
      ...purchaseData,
      'id': id,
      'isSynced': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Automated Inventory Integration & Strict Barcode Matching
    String? actualItemId = finalPurchase['itemId'];
    final barcode = finalPurchase['barcode']?.toString() ?? '';
    final itemName = finalPurchase['itemName']?.toString() ?? '';

    // Search for existing product by barcode (Cross-check)
    if (barcode.isNotEmpty) {
       final barcodeMatches = await _local.searchItems(user.shopId, '', barcode);
       if (barcodeMatches.isNotEmpty) {
          final existing = barcodeMatches.first;
          // Rule: If barcode exists, Name MUST match exactly (case-insensitive check handled by DB or app)
          if (existing['name'].toString().toLowerCase() != itemName.toLowerCase()) {
             throw Exception("Barcode Mismatch: Barcode '$barcode' is already assigned to '${existing['name']}'. Please use the correct name or a different barcode.");
          }
          actualItemId = existing['id'];
       }
    }

    // Fallback: If no barcode match, try name-only match
    if (actualItemId == null || actualItemId.isEmpty) {
       final nameMatches = await _local.searchItems(user.shopId, itemName, '');
       if (nameMatches.isNotEmpty) {
          actualItemId = nameMatches.first['id'];
       }
    }
    
    // Logic: If still no match, this is a brand new product definition
    if (actualItemId == null || actualItemId.isEmpty) {
       final newItemId = _uuid.v4();
       actualItemId = newItemId;
       
       await registerItem(user, {
         'id': newItemId,
         'name': itemName,
         'barcode': barcode,
         'sellingPrice': finalPurchase['sellingPrice'] ?? (finalPurchase['unitCost'] ?? 0.0) * 1.25,
         'buyingPrice': finalPurchase['unitCost'],
         'lowStockThreshold': finalPurchase['lowStockThreshold'] ?? 5,
         'quantity': 0, // recordRestock will add the actual quantity
       });
    }

    // SUCCESS: We have an ID. Set it BEFORE saving the log entry!
    finalPurchase['itemId'] = actualItemId;

    // 2. Instant Local Save (Now with guaranteed itemId)
    await _local.savePurchase(finalPurchase);

    // 2b. Register stock as a traceable batch movement
    await recordRestock(user, {
      'shopId': user.shopId,
      'itemId': actualItemId,
      'itemName': finalPurchase['itemName'],
      'addedQuantity': finalPurchase['quantity'],
      'buyingPrice': finalPurchase['unitCost'],
      'expiryDate': finalPurchase['expiryDate'] is Timestamp 
          ? (finalPurchase['expiryDate'] as Timestamp).toDate().toIso8601String()
          : finalPurchase['expiryDate']?.toString(),
      'supplierName': finalPurchase['supplierName'],
    });

    // 3. Fire-and-forget Background Sync for the log entry itself
    _remote.recordPurchase(finalPurchase).then((_) {
      _local.markSynced('purchases', id);
    }).catchError((e) {
      debugPrint("Background Sync Delay (Purchases): $e");
    });
  }

  Future<String?> findItemByNameOrBarcode(String shopId, String name, String barcode) async {
     final results = await _local.searchItems(shopId, name, barcode);
     if (results.isNotEmpty) {
       return results.first['id'];
     }
     return null;
  }

  Future<void> deleteItem(AppUser user, String productId) async {
    await _local.delete('products', where: 'id = ?', whereArgs: [productId]);
    await _remote.deleteItem(productId);
    await recordAuditLog(user.shopId, user.username, 'DELETE_ITEM', 'Permanently deleted item $productId');
  }

  Future<void> deleteUser(AppUser admin, String userId) async {
    await _remote.deleteUser(userId);
    await recordAuditLog(admin.shopId, admin.username, 'DELETE_USER', 'Deleted user account $userId');
  }

  Future<void> factoryReset(String shopId) async {
    await _remote.fullFactoryReset(shopId);
  }

  Future<void> recordAuditLog(String shopId, String username, String action, String details) async {
    await _remote.recordAuditLog(shopId, username, action, details);
  }
}
