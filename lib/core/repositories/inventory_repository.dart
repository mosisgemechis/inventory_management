import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../services/validation_service.dart';
import '../models/models.dart';

class InventoryRepository {
  final DatabaseService _local = DatabaseService();
  final ValidationService _validator = ValidationService();
  final _uuid = Uuid();

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is int) {
       // DRIFT / SQLite stores as integer (Unix timestamp)
       // Robust check for seconds vs milliseconds:
       // Anything before year 2000 in milliseconds (946684800000) is likely seconds.
       if (val < 10000000000) {
         return DateTime.fromMillisecondsSinceEpoch(val * 1000); 
       }
       return DateTime.fromMillisecondsSinceEpoch(val); 
    }
    return DateTime.tryParse(val.toString());
  }

  Future<String> registerItem(AppUser user, Map<String, dynamic> data) async {
    // 1. Validation
    final branchId = data['branchId'] ?? user.branchId;
    await _validator.validateProduct(
      user.shopId, 
      data['name'] ?? '', 
      data['barcode'] ?? '',
      batchNumber: data['batchNumber'],
      branchId: branchId
    );

    // 2. Duplicate Check (Branch Specific)
    final existing = await _local.query('products', 
      where: 'shop_id = ? AND (name = ? OR barcode = ?) AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
      whereArgs: [user.shopId, data['name'] ?? '', data['barcode'] ?? '', branchId, branchId]
    );
    if (existing.isNotEmpty && data['id'] == null) {
       final existingItem = existing.first;
       final existingId = existingItem['id'];
       final incomingQty = (data['quantity'] ?? 0).toDouble();
       
       if (incomingQty > 0) {
         await recordRestock(user, {
           'shopId': user.shopId,
           'itemId': existingId,
           'itemName': existingItem['name'],
           'addedQuantity': incomingQty,
           'buyingPrice': data['buyingPrice'] ?? existingItem['buyingPrice'],
           'expiryDate': data['expiryDate'],
           'supplierName': data['supplierName'] ?? 'Unknown',
           'branchId': branchId,
         });
       }
       return existingId;
    }

    // 3. Prepare data
    final id = data['uniqueId'] ?? data['id'] ?? _uuid.v4(); 
    final initialQty = (data['quantity'] ?? 0.0).toDouble();
    final sellingPrice = (data['sellingPrice'] ?? 0.0).toDouble();
    
    final finalData = {
      ...data,
      'id': id,
      'shopId': user.shopId,
      'quantity': initialQty, // FIX BUG #1: Direct initialization
      'syncStatus': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    // 4. Save Product Definition
    await _local.saveProduct(finalData);

    // 5. Check if Admin Pricing Alert is needed
    if (sellingPrice <= 0.01) {
       await _local.addNotification({
         'id': _uuid.v4(),
         'shopId': user.shopId,
         'title': 'Pricing Required',
         'message': 'New product "${data['name']}" added. Please set a selling price to enable sales.',
         'type': 'pricing_alert',
         'targetRole': 'admin',
         'itemId': id,
       });
    }

    // 6. Register initial stock batch if exists
    if (initialQty > 0) {
      await recordRestock(user, {
        'shopId': user.shopId,
        'itemId': id,
        'itemName': data['name'],
        'addedQuantity': initialQty,
        'buyingPrice': data['buyingPrice'],
        'sellingPrice': sellingPrice,
        'expiryDate': _parseDate(data['expiryDate'])?.toIso8601String(),
        'supplierName': data['supplierName'],
        'branchId': branchId,
      }, silent: true);
    } else {
       // Force a recal because saveProduct might have set slightly different data
       await _recalculateItemStock(user.shopId, id);
    }

    await recordAuditLog(user.shopId, user.username, 'ADD_PRODUCT', 'Added: ${data['name']} (Stock: $initialQty)', branchId: branchId);
    return id;
  }

  /// THE BATCH ENGINE: Direct/Global Restock Logic 
  /// Implements "Traceable Batch Inventory" Smart-Merge
  Future<void> recordRestock(AppUser user, Map<String, dynamic> restockData, {bool isPurchase = false, bool silent = false}) async {
    // Requires: itemId, itemName, addedQuantity, buyingPrice, expiryDate
    // NO duplicate detector constraint here because it operates on existing items.
    
    final String? itemId = restockData['itemId'];
    if (itemId == null) throw Exception("System Error: Item Identity is missing for restock.");
    final double incomingQty = (restockData['addedQuantity'] ?? 0).toDouble();
    if (incomingQty <= 0) throw Exception("Restock quantity must be greater than zero.");

    // ISO 8601 Formatting strictly enforced
    // Handle all possible input types: Timestamp, DateTime, int, String, null
    String? incomingExpiryStr;
    final rawExpiry = restockData['expiryDate'];
    if (rawExpiry is DateTime) {
      incomingExpiryStr = rawExpiry.toIso8601String();
    } else if (rawExpiry is int) {
      incomingExpiryStr = _parseDate(rawExpiry)?.toIso8601String();
    } else if (rawExpiry is String && rawExpiry.isNotEmpty) {
      final dt = DateTime.tryParse(rawExpiry);
      if (dt != null) incomingExpiryStr = dt.toIso8601String();
    }

    // 1. Fetch existing batches for smart-merge (limited to THIS branch)
    final branchId = restockData['branchId'] ?? user.branchId;
    final existingBatches = await _local.query('batches', 
      where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
      whereArgs: [user.shopId, itemId, branchId, branchId]);

    String activeBatchId = _uuid.v4();
    bool merged = false;
    double newBatchTotal = incomingQty;

    // 2. The Smart-Merge (using null-safe comparison)
    for (var b in existingBatches) {
      final oldExp = _parseDate(b['expiryDate']);
      final oldExpStr = oldExp?.toIso8601String();
      if (oldExpStr == incomingExpiryStr) {
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
      'syncStatus': 0,
      'branchId': restockData['branchId'] ?? user.branchId, // Use provided branch or user's branch
    };

    if (merged) {
      await _local.update('batches', activeBatchId, batchData);
    } else {
      await _local.saveBatchRecord(batchData); // Standardized name
    }

    // 4. Update the Product's flat quantity cache temporarily to ensure UI compatibility
    await _recalculateItemStock(user.shopId, itemId, 
      branchId: branchId,
      overrideBuyingPrice: (restockData['buyingPrice'] as num?)?.toDouble(),
      overrideSellingPrice: (restockData['sellingPrice'] as num?)?.toDouble());

    // 4. Background Sync Removed

    if (!silent) {
      await recordAuditLog(user.shopId, user.username, isPurchase ? 'PURCHASE' : 'RESTOCK', 'Restocked ${restockData['itemName']}: +$incomingQty units', branchId: branchId);
    }

    // 5. If this is a formal Purchase, create the purchase record
    if (isPurchase) {
      final purchaseId = "PURCHASE-${DateTime.now().millisecondsSinceEpoch}";
      final purchaseData = {
        'id': purchaseId,
        'shopId': user.shopId,
        'itemId': itemId,
        'itemName': restockData['itemName'],
        'barcode': restockData['barcode'] ?? '',
        'quantity': incomingQty,
        'unitCost': (restockData['buyingPrice'] ?? 0).toDouble(),
        'totalCost': (restockData['buyingPrice'] ?? 0).toDouble() * incomingQty,
        'supplierName': restockData['supplierName'],
        'expiryDate': incomingExpiryStr,
        'timestamp': DateTime.now().toIso8601String(),
        'syncStatus': 0,
        'branchId': branchId,
      };
      await _local.insert('purchases', purchaseData);
    }
  }

  /// Sums all active unexpired batches for this product and returns the item cached `quantity` and `expiryDate`
  Future<Map<String, dynamic>> _recalculateItemStock(String shopId, String itemId, {double? overrideBuyingPrice, double? overrideSellingPrice, String? branchId}) async {
    // If branchId is null, we might need to find the product's assigned branch
    final productRaw = await _local.query('products', where: 'id = ?', whereArgs: [itemId]);
    final effectiveBranchId = branchId ?? (productRaw.isNotEmpty ? productRaw.first['branchId'] : 'main');

    final batchesQuery = _local.query('batches', 
      where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
      whereArgs: [shopId, itemId, effectiveBranchId, effectiveBranchId] 
    );
    List<Map<String, dynamic>> batches = await batchesQuery;
    
    // LEGACY FALLBACK: If no batches for this branch, try main (pre-migration data)
    if (batches.isEmpty && effectiveBranchId != 'main') {
      batches = await _local.query('batches', 
        where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))',
        whereArgs: [shopId, itemId, 'main', 'main']
      );
    }

    double activeStock = 0.0;
    DateTime? closestActiveExpiry;
    
    for (var b in batches) {
       final qty = (b['quantity'] ?? 0.0).toDouble();
       final exp = _parseDate(b['expiryDate']);
       
       if (qty > 0) {
          bool isExpired = false;
          if (exp != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final expiryDate = DateTime(exp.year, exp.month, exp.day);
            if (expiryDate.isBefore(today)) {
              isExpired = true;
            } else {
              if (closestActiveExpiry == null || exp.isBefore(closestActiveExpiry)) {
                 closestActiveExpiry = exp;
              }
            }
          }

          if (!isExpired) {
             activeStock += qty;
          } else if (qty > 0) {
            // BACKWARD COMPATIBILITY: If we find a batch with a 1970 date (seconds instead of ms),
            // and it has quantity, we might want to count it if it's "obviously" not meant to be expired.
            // But with the fix above it shouldn't happen for new data.
          }
       }
    }

    final updateData = {
      'quantity': activeStock,
      'expiryDate': closestActiveExpiry?.toIso8601String(),
      if (overrideBuyingPrice != null) 'buyingPrice': overrideBuyingPrice,
      if (overrideSellingPrice != null) 'sellingPrice': overrideSellingPrice,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    // Update local immediately
    await _local.update('products', itemId, {...updateData, 'syncStatus': 0});
    return updateData;
  }


  Future<void> recordSale(AppUser user, Map<String, dynamic> saleData) async {
    final double totalQuantity = (saleData['quantity'] ?? 0.0).toDouble();
    if (totalQuantity <= 0) throw Exception('Quantity must be greater than zero.');
    
    final itemId = saleData['itemId'];
    final totalPrice = (saleData['totalPrice'] ?? 0.0).toDouble();

    await _local.runTransaction(() async {
      // 1. Fetch existing batches for the product IN THIS BRANCH
      final branchId = saleData['branchId'] ?? user.branchId;
      List<Map<String, dynamic>> batchesRaw = await _local.query('batches', 
        where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
        whereArgs: [user.shopId, itemId, branchId, branchId]
      );
      
      // LEGACY FALLBACK: Products added before multi-branch was enabled
      // have batches stored with branchId='main'. If we find none for the
      // requested branch, check 'main' as a fallback for migrated data.
      if (batchesRaw.isEmpty && branchId != 'main') {
        batchesRaw = await _local.query('batches',
          where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))',
          whereArgs: [user.shopId, itemId, 'main', 'main']
        );
      }
      
      if (batchesRaw.isEmpty) {
         throw Exception("Out of stock: No batches found for this product. Please restock first.");
      }

      List<Map<String, dynamic>> mutableBatches = batchesRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      // 2. FEFO (First Expiry First Out) Sorting
      mutableBatches.sort((a, b) {
        final tA = _parseDate(a['expiryDate']) ?? DateTime(2100);
        final tB = _parseDate(b['expiryDate']) ?? DateTime(2100);
        return tA.compareTo(tB);
      });

      double remainingToDeduct = totalQuantity;
      double totalSaleProfit = 0;
      final unitSellingPrice = totalPrice / totalQuantity;

      // 3. Atomically Deduct from Batches
      for (var b in mutableBatches) {
        if (remainingToDeduct <= 0) break;
        
        final double batchQty = (b['quantity'] ?? 0.0).toDouble();
        if (batchQty <= 0) continue;

        final deduction = batchQty > remainingToDeduct ? remainingToDeduct : batchQty;
        final double batchBuyingPrice = (b['buyingPrice'] ?? 0.0).toDouble();
        
        // Calculate profit based on the actual buying price of this specific batch
        totalSaleProfit += (unitSellingPrice - batchBuyingPrice) * deduction;
        
        // UPDATE BATCH QUANTITY correctly (FIX BUG #2)
        final newBatchQty = batchQty - deduction;
        await _local.update('batches', b['id'], {'quantity': newBatchQty});
        
        remainingToDeduct -= deduction;
      }

      if (remainingToDeduct > 0.001) {
        throw Exception("Insufficient stock to complete sale. Missing $remainingToDeduct units.");
      }

      // 4. Record the Sale Transaction record
      final saleId = _uuid.v4();
      final finalSale = {
        ...saleData,
        'id': saleId,
        'profit': totalSaleProfit,
        'syncStatus': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'branchId': saleData['branchId'] ?? user.branchId,
      };

      await _local.saveSale(finalSale);

      // 5. Trigger flat stock recalculation cache
      await _recalculateItemStock(user.shopId, itemId, branchId: branchId);
      
      // 6. Audit Log
      final itemName = saleData['itemName'] ?? 'Unknown Item';
      await recordAuditLog(user.shopId, user.username, 'SALE', 'Sold $totalQuantity units of $itemName (Total: $totalPrice)', branchId: branchId);
    });
  }

  Future<void> processBulkCheckoutSync(List<Map<String, dynamic>> items) async {
    // Standard validation
    for (var i in items) {
       final qty = (i['quantity'] ?? 0).toDouble();
       if (qty <= 0) throw Exception("Quantity must be greater than zero.");
    }
    
    // Process each locally (which inherently handles background syncing)
    final user = AppUser(
      id: items.first['userId'],
      username: items.first['username'],
      email: '',
      roles: [],
      shopId: items.first['shopId'],
    );
    
    for (var i in items) {
       await recordSale(user, i);
    }
  }


  Future<void> updatePurchase(AppUser user, String purchaseId, Map<String, dynamic> data) async {
    // Only supplierName and price allowed for editing in logs as per request
    final cleanData = {
      if (data.containsKey('supplierName')) 'supplierName': data['supplierName'],
      if (data.containsKey('unitCost')) 'unitCost': data['unitCost'],
      if (data.containsKey('totalCost')) 'totalCost': data['totalCost'],
      'syncStatus': 0,
    };
    
    await _local.update('purchases', purchaseId, cleanData);
  }

  Future<void> recordPurchase(AppUser user, Map<String, dynamic> purchaseData) async {
    final id = _uuid.v4();
    final finalPurchase = {
      ...purchaseData,
      'id': id,
      'syncStatus': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Automated Inventory Integration & Strict Barcode Matching
    String? actualItemId = finalPurchase['itemId'];
    final barcode = finalPurchase['barcode']?.toString() ?? '';
    final itemName = finalPurchase['itemName']?.toString() ?? '';

    final branchId = purchaseData['branchId'] ?? user.branchId;
    // Search for existing product by barcode IN THIS BRANCH
    if (barcode.isNotEmpty) {
       final barcodeMatches = await _local.query('products', 
         where: 'shop_id = ? AND barcode = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
         whereArgs: [user.shopId, barcode, branchId, branchId]
       );
       if (barcodeMatches.isNotEmpty) {
          final existing = barcodeMatches.first;
          // Rule: If barcode exists, Name MUST match exactly (case-insensitive check handled by DB or app)
          if (existing['name'].toString().toLowerCase() != itemName.toLowerCase()) {
             throw Exception("Barcode Mismatch: Barcode '$barcode' is already assigned to '${existing['name']}'. Please use the correct name or a different barcode.");
          }
          actualItemId = existing['id'];
       }
    }

    // Fallback: If no barcode match, try name-only match IN THIS BRANCH
    if (actualItemId == null || actualItemId!.isEmpty) {
       final nameMatches = await _local.query('products', 
         where: 'shop_id = ? AND name = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
         whereArgs: [user.shopId, itemName, branchId, branchId]
       );
       if (nameMatches.isNotEmpty) {
          actualItemId = nameMatches.first['id'];
       }
    }
    
    await _local.runTransaction(() async {
      // Logic: If still no match, this is a brand new product definition
      if (actualItemId == null || actualItemId!.isEmpty) {
        final newItemId = _uuid.v4();
        actualItemId = newItemId;
        
        await registerItem(user, {
          'id': newItemId,
          'name': itemName,
          'barcode': barcode,
          'branchId': branchId,
          'sellingPrice': finalPurchase['sellingPrice'] ?? (finalPurchase['unitCost'] ?? 0.0) * 1.25,
          'buyingPrice': finalPurchase['unitCost'],
          'lowStockThreshold': finalPurchase['lowStockThreshold'] ?? 5,
          'quantity': 0, 
        });
      }

      finalPurchase['itemId'] = actualItemId;

      // 2. Instant Local Save
      await _local.savePurchase(finalPurchase);

      // 2b. Register stock as a traceable batch movement
      await recordRestock(user, {
        'shopId': user.shopId,
        'itemId': actualItemId,
        'itemName': finalPurchase['itemName'],
        'addedQuantity': finalPurchase['quantity'],
        'buyingPrice': finalPurchase['unitCost'],
        'expiryDate': finalPurchase['expiryDate']?.toString(),
        'supplierName': finalPurchase['supplierName'],
        'batchNumber': finalPurchase['batchNumber'],
        'branchId': branchId,
      });
    });

    // 3. Sync Removed
  }

  Future<String?> findItemByNameOrBarcode(String shopId, String name, String barcode, {String? branchId}) async {
     final results = await _local.searchItems(shopId, name, barcode, branchId: branchId);
     if (results.isNotEmpty) {
       return results.first['id'];
     }
     return null;
  }

  Future<void> deleteItem(AppUser user, String productId) async {
    await _local.delete('products', productId);
    await recordAuditLog(user.shopId, user.username, 'DELETE_ITEM', 'Permanently deleted item $productId', branchId: user.branchId);
  }

  Future<void> deleteUser(AppUser admin, String userId) async {
    await recordAuditLog(admin.shopId, admin.username, 'DELETE_USER', 'Deleted user account $userId', branchId: admin.branchId);
  }

  Future<void> factoryReset(String shopId) async {
    await _local.factoryReset();
  }

  Future<void> transferStock({
    required AppUser admin,
    required String itemId,
    required String itemName,
    required String fromBranchId,
    required String toBranchId,
    required double quantity,
  }) async {
    if (fromBranchId == toBranchId) throw Exception("Source and destination branches must be different.");
    if (quantity <= 0) throw Exception("Quantity must be greater than zero.");

    await _local.runTransaction(() async {
      // 1. Deduct from Source
      final sourceBatchesRaw = await _local.query('batches', 
        where: 'shop_id = ? AND item_id = ? AND branch_id = ? AND quantity > 0', 
        whereArgs: [admin.shopId, itemId, fromBranchId]
      );
      
      if (sourceBatchesRaw.isEmpty) throw Exception("No stock available in source branch.");
      
      double remaining = quantity;
      List<Map<String, dynamic>> sourceBatches = sourceBatchesRaw.map((e) => Map<String, dynamic>.from(e)).toList();
      sourceBatches.sort((a,b) => (a['expiryDate'] ?? '').compareTo(b['expiryDate'] ?? ''));

      for (var b in sourceBatches) {
        if (remaining <= 0) break;
        final bQty = (b['quantity'] ?? 0.0).toDouble();
        final deduct = bQty > remaining ? remaining : bQty;
        
        await _local.update('batches', b['id'], {'quantity': bQty - deduct});
        
        // 2. Add to Destination (preserving batch details like expiry)
        await recordRestock(admin, {
          'itemId': itemId,
          'itemName': itemName,
          'addedQuantity': deduct,
          'buyingPrice': b['buyingPrice'],
          'expiryDate': b['expiryDate'],
          'batchNumber': b['batchNumber'],
          'branchId': toBranchId,
        });
        
        remaining -= deduct;
      }

      if (remaining > 0.001) throw Exception("Insufficient stock in source branch. Missing $remaining units.");

      await _recalculateItemStock(admin.shopId, itemId, branchId: fromBranchId);
      await _recalculateItemStock(admin.shopId, itemId, branchId: toBranchId);
      
      await recordAuditLog(admin.shopId, admin.username, 'STOCK_TRANSFER', 
        'Transferred $quantity units of $itemName from $fromBranchId to $toBranchId', 
        branchId: fromBranchId);
    });
  }

  Future<void> updateDebtPayments(AppUser user, List<Map<String, dynamic>> items, double totalAmount) async {
    await _local.runTransaction(() async {
      double paymentLeft = totalAmount;
      for (var m in items) {
        if (paymentLeft <= 0) break;
        final docRemaining = (m['debtRemaining'] ?? 0.0).toDouble();
        if (docRemaining <= 0) continue;

        final payToDoc = docRemaining > paymentLeft ? paymentLeft : docRemaining;
        final newRem = docRemaining - payToDoc;
        final currentPaid = (m['amountPaid'] ?? 0.0).toDouble();

        await _local.update('sales', m['id'], {
          'debtRemaining': newRem < 0 ? 0 : newRem,
          'isDebt': newRem > 0.1 ? 1 : 0,
          'amountPaid': currentPaid + payToDoc,
          'syncStatus': 0,
        });
        
        paymentLeft -= payToDoc;
      }
    });

    await recordAuditLog(user.shopId, user.username, 'DEBT_PAYMENT', 'Paid debt of $totalAmount', branchId: user.branchId);
  }

  Future<void> recordAuditLog(String shopId, String username, String action, String details, {String branchId = 'main'}) async {
    final logId = _uuid.v4();
    final log = {
      'id': logId,
      'shopId': shopId,
      'username': username,
      'action': action,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
      'syncStatus': 0,
      'branchId': branchId,
    };
    
    try {
      await _local.insert('audit_logs', log);
    } catch(e) {
      debugPrint("Local Audit Log Error: $e");
    }
  }
}
