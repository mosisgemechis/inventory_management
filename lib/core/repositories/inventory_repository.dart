import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../services/validation_service.dart';
import '../models/models.dart';
import 'package:drift/drift.dart';
class InventoryRepository {
  final DatabaseService _local = DatabaseService();
  final ValidationService _validator = ValidationService();
  final _uuid = Uuid();

  DateTime? _parseDate(dynamic val) => parseDT(val);
  double _parseAmount(dynamic val, {double fallback = 0.0}) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  Future<String> registerItem(AppUser user, Map<String, dynamic> data, {bool forceNew = false}) async {
    if (!user.hasPermission(AppUser.pAddEditProducts)) {
      throw Exception('Permission denied: cannot add products.');
    }
    final initialQty = _parseAmount(data['quantity']);
    final branchId = data['branchId'] ?? user.branchId;

    // If data comes with a pre-assigned ID this is NOT a brand-new product
    // (e.g. called from recordPurchase with forceNew:true for a freshly-minted UUID).
    // Pass that ID to the validator so it skips the barcode / batch-number duplicate
    // guards — those checks are only meaningful for truly new definitions.
    final existingId = (data['id'] ?? data['uniqueId'])?.toString();
    await _validator.validateProduct(
      user.shopId,
      data['name'] ?? '',
      data['barcode'] ?? '',
      batchNumber: data['batchNumber'],
      branchId: branchId,
      currentItemId: existingId, // null → new; non-null → skip dup checks
    );

    // ── Duplicate / merge check (only when not force-creating a new slot) ──
    if (!forceNew) {
      final name = data['name']?.toString() ?? '';
      final barcode = data['barcode']?.toString() ?? '';
      final cleanName = name.trim();
      final cleanBarcode = barcode.trim();

      String queryWhere = 'shop_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main")) AND sync_status <> ?';
      List<dynamic> queryArgs = [user.shopId, branchId, branchId, 'pendingDelete'];

      if (cleanBarcode.isNotEmpty) {
        queryWhere += ' AND (LOWER(barcode) = ? OR LOWER(name) = ?)';
        queryArgs.addAll([cleanBarcode.toLowerCase(), cleanName.toLowerCase()]);
      } else if (cleanName.isNotEmpty) {
        queryWhere += ' AND LOWER(name) = ?';
        queryArgs.add(cleanName.toLowerCase());
      }

      // Only run the merge-into-existing path when the caller hasn't provided
      // a specific item ID (i.e. truly new registration, not an edit).
      final incomingId = (data['id'] ?? data['uniqueId'])?.toString() ?? '';
      if (incomingId.isEmpty) {
        final existing = await _local.query('products',
            where: queryWhere, whereArgs: queryArgs);

        if (existing.isNotEmpty) {
          final existingItem = existing.first;
          final existingItemId = existingItem['id'];
          final incomingQty = _parseAmount(data['quantity']);

          if (incomingQty > 0) {
            await recordRestock(user, {
              'shopId': user.shopId,
              'itemId': existingItemId,
              'itemName': existingItem['name'],
              'addedQuantity': incomingQty,
              'buyingPrice': data['buyingPrice'] ?? existingItem['buyingPrice'],
              'sellingPrice': data['sellingPrice'] ?? existingItem['sellingPrice'],
              'expiry': data['expiry'] ?? data['expiryDate'] ?? data['exp'],
              'supplierName': data['supplierName'] ?? 'Unknown',
              'branchId': branchId,
            });
          }
          return existingItemId;
        }
      }
    }

    // ── Create new product definition ─────────────────────────────────────
    final id = data['uniqueId'] ?? data['id'] ?? _uuid.v4();
    final sellingPrice = _parseAmount(data['sellingPrice']);

    final finalData = {
      ...data,
      'id': id,
      'shopId': user.shopId,
      'quantity': initialQty,
      'syncStatus': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    await _local.saveProduct(finalData);

    if (sellingPrice <= 0.01 && !user.hasPermission(AppUser.pSetSellingPrice)) {
      await _local.addNotification({
        'id': _uuid.v4(),
        'shopId': user.shopId,
        'branchId': branchId,
        'title': 'Item requires pricing',
        'message': 'Item "${data['name']}" requires a selling price.',
        'type': 'pricing_alert',
        'priority': 'high',
        'targetRole': 'admin',
        'itemId': id,
        'relatedEntityId': id,
        'createdBy': user.username,
        'route': 'edit_product',
      });
    }

    if (initialQty > 0) {
      await recordRestock(user, {
        'shopId': user.shopId,
        'itemId': id,
        'itemName': data['name'],
        'addedQuantity': initialQty,
        'buyingPrice': data['buyingPrice'],
        'sellingPrice': sellingPrice,
        'expiryDate': _parseDate(data['expiryDate'])?.toUtc().toIso8601String(),
        'supplierName': data['supplierName'],
        'branchId': branchId,
        'type': 'initial',
      }, silent: true);
    } else {
      await _recalculateItemStock(user.shopId, id);
    }

    await recordAuditLog(user.shopId, user.username, 'ADD_PRODUCT',
        'Added Product: ${data['name']}',
        branchId: branchId);
    return id;
  }

  Future<void> _checkStockTriggers(AppUser user, Map<String, dynamic> product, {String? branchId}) async {
    final effectiveBranchId = branchId ?? product['branchId'] ?? 'main';
    final qty = await _getBranchStock(user.shopId, product['id'], effectiveBranchId);
    final lt = (product['lowStockThreshold'] ?? 5) as num;
    final name = product['name'];
    final id = product['id'];

    if (qty <= 0) {
      // Clear any stale low_stock first so we only have one active out_of_stock.
      await _local.clearProductNotifications(user.shopId, id, 'low_stock', branchId: effectiveBranchId);
      await _local.addNotification({
        'id': _uuid.v4(),
        'shopId': user.shopId,
        'branchId': effectiveBranchId,
        'title': 'OUT OF STOCK',
        'message': '$name is completely out of stock in $effectiveBranchId!',
        'type': 'out_of_stock',
        'targetRole': 'all',
        'itemId': id,
        'route': 'inventory',
      });
    } else if (qty <= lt) {
      // Clear out of stock as we now have some
      await _local.clearProductNotifications(user.shopId, id, 'out_of_stock', branchId: effectiveBranchId);
      await _local.addNotification({
        'id': _uuid.v4(),
        'shopId': user.shopId,
        'branchId': effectiveBranchId,
        'title': 'Low Stock Alert',
        'message': '$name is low on stock in $effectiveBranchId ($qty left).',
        'type': 'low_stock',
        'targetRole': 'all',
        'itemId': id,
        'route': 'inventory',
      });
    } else {
      // Healthy stock - clear both
      await _local.clearProductNotifications(user.shopId, id, 'out_of_stock', branchId: effectiveBranchId);
      await _local.clearProductNotifications(user.shopId, id, 'low_stock', branchId: effectiveBranchId);
    }

    final ed = product['expiryDate'];
    final exp = _parseDate(ed);
    if (exp != null) {
      final now = DateTime.now();
      if (exp.isBefore(now)) {
        await _local.addNotification({
          'id': _uuid.v4(),
          'shopId': user.shopId,
          'branchId': effectiveBranchId,
          'title': 'EXPIRED',
          'message': '$name has reached its expiration date.',
          'type': 'expired',
          'targetRole': 'all',
          'itemId': id,
          'route': 'inventory',
        });
      } else {
        // Not expired - clear expired notice
        await _local.clearProductNotifications(user.shopId, id, 'expired', branchId: effectiveBranchId);
        final days = exp.difference(now).inDays;
        if (days <= 30) {
          await _local.addNotification({
            'id': _uuid.v4(),
            'shopId': user.shopId,
            'branchId': effectiveBranchId,
            'title': 'EXPIRING SOON',
            'message': '$name will expire in $days days.',
            'type': 'expiring_soon',
            'targetRole': 'all',
            'itemId': id,
            'route': 'inventory',
          });
        } else {
          // Clear soon notice if we have plenty of time
          await _local.clearProductNotifications(user.shopId, id, 'expiring_soon', branchId: effectiveBranchId);
        }
      }
    } else {
       // No expiry at all - clear all related warnings
       await _local.clearProductNotifications(user.shopId, id, 'expired', branchId: effectiveBranchId);
       await _local.clearProductNotifications(user.shopId, id, 'expiring_soon', branchId: effectiveBranchId);
    }
  }

  Future<void> requestDeletion(AppUser user, String productId, String productName) async {
    await _local.addNotification({
      'id': _uuid.v4(),
      'shopId': user.shopId,
      'title': 'Deletion Request',
      'message': 'Request to delete "$productName" by ${user.username}.',
      'type': 'deletion_request',
      'targetRole': 'admin',
      'itemId': productId,
      'route': 'approve_deletion',
      'payloadJson': jsonEncode({'userId': user.id, 'productId': productId}),
    });
    await recordAuditLog(user.shopId, user.username, 'DELETE_REQUEST', 'Requested deletion for $productName');
  }

  Future<double> _getBranchStock(String shopId, String productId, String branchId) async {
    final rows = await _local.query(
      'product_stocks',
      where: 'shop_id = ? AND product_id = ? AND branch_id = ?',
      whereArgs: [shopId, productId, branchId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final q = rows.first['quantity'];
      if (q is num) return q.toDouble();
    }
    return 0.0;
  }

  Future<void> updateProduct(
    AppUser user,
    String productId, {
    required String branchId,
    required Map<String, dynamic> updates,
    double? newExactStockQty,
  }) async {
    if (!user.hasPermission(AppUser.pAddEditProducts)) {
      throw Exception('Permission denied: cannot edit products.');
    }

    final existing = await _local.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
    if (existing.isEmpty) throw Exception('Product not found.');
    final before = existing.first;

    // 1) Definition updates (Drift-first).
    final defUpdates = <String, dynamic>{
      ...updates,
      'shopId': user.shopId,
      'branchId': branchId,
      'lastUpdated': DateTime.now().toIso8601String(),
    }..remove('quantity'); // stock is handled via batches/product_stocks.

    if (defUpdates.containsKey('sellingPrice')) {
      final canPrice = user.hasPermission(AppUser.pSetSellingPrice);
      if (!canPrice) throw Exception('Permission denied: cannot set selling price.');
    }

    await _local.update('products', productId, defUpdates);

    // 2) Stock exact-set (if requested).
    if (newExactStockQty != null) {
      if (!user.hasPermission(AppUser.pEditInventory)) {
        throw Exception('Permission denied: cannot adjust stock.');
      }
      await setProductStockExact(
        user: user,
        productId: productId,
        branchId: branchId,
        newQuantity: newExactStockQty,
      );
    }

    // 3) Audit logging (structured JSON in details).
    final after = (await _local.query('products', where: 'id = ?', whereArgs: [productId], limit: 1)).first;
    final oldBarcode = (before['barcode'] ?? '').toString();
    final newBarcode = (after['barcode'] ?? '').toString();
    if (oldBarcode != newBarcode) {
      await recordAuditLog(
        user.shopId,
        user.username,
        'BARCODE_EDIT',
        jsonEncode({
          'productId': productId,
          'product': after['name'],
          'oldBarcode': oldBarcode,
          'newBarcode': newBarcode,
          'branch': branchId,
          'user': user.username,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        branchId: branchId,
      );
    }

    final oldSell = (before['sellingPrice'] ?? 0.0).toDouble();
    final newSell = (after['sellingPrice'] ?? 0.0).toDouble();
    if ((oldSell - newSell).abs() > 0.0001) {
      await recordAuditLog(
        user.shopId,
        user.username,
        'PRICE_CHANGE',
        jsonEncode({
          'productId': productId,
          'product': after['name'],
          'oldSellingPrice': oldSell,
          'newSellingPrice': newSell,
          'branch': branchId,
          'user': user.username,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        branchId: branchId,
      );
    }

    await recordAuditLog(
      user.shopId,
      user.username,
      'EDIT_PRODUCT',
      jsonEncode({
        'productId': productId,
        'product': after['name'],
        'branch': branchId,
        'user': user.username,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      }),
      branchId: branchId,
    );
  }

  Future<void> setProductStockExact({
    required AppUser user,
    required String productId,
    required String branchId,
    required double newQuantity,
  }) async {
    if (!user.hasPermission(AppUser.pEditInventory)) {
      throw Exception('Permission denied: cannot adjust stock.');
    }
    if (newQuantity < 0) throw Exception('Stock cannot be negative.');

    final productRaw =
        await _local.query('products', where: 'id = ?', whereArgs: [productId], limit: 1);
    if (productRaw.isEmpty) throw Exception('Product not found.');
    final product = productRaw.first;
    final name = product['name'] ?? '';

    // Use product_stocks as the current authoritative per-branch quantity cache.
    final oldQuantity = await _getBranchStock(user.shopId, productId, branchId);
    final delta = newQuantity - oldQuantity;
    if (delta.abs() < 0.0001) return;

    await _local.runTransaction(() async {
      if (delta > 0) {
        // Increase stock by adding an adjustment batch (traceable).
        await recordRestock(
          user,
          {
            'shopId': user.shopId,
            'itemId': productId,
            'itemName': name,
            'addedQuantity': delta,
            'buyingPrice': product['buyingPrice'] ?? 0.0,
            'sellingPrice': product['sellingPrice'] ?? 0.0,
            'expiryDate': null,
            'supplierName': 'Adjustment',
            'branchId': branchId,
          },
          silent: true,
        );
      } else {
        // Decrease stock by deducting from existing batches FEFO (no sale record).
        double remaining = (-delta);
        List<Map<String, dynamic>> batchesRaw = await _local.query(
          'batches',
          where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = \"main\")) AND quantity > 0',
          whereArgs: [user.shopId, productId, branchId, branchId],
        );
        if (batchesRaw.isEmpty && branchId != 'main') {
          batchesRaw = await _local.query(
            'batches',
            where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = \"main\")) AND quantity > 0',
            whereArgs: [user.shopId, productId, 'main', 'main'],
          );
        }
        if (batchesRaw.isEmpty) throw Exception('No stock available to deduct.');

        final mutable = batchesRaw.map((e) => Map<String, dynamic>.from(e)).toList();
        mutable.sort((a, b) {
          final tA = _parseDate(a['expiryDate']) ?? DateTime(2100);
          final tB = _parseDate(b['expiryDate']) ?? DateTime(2100);
          return tA.compareTo(tB);
        });

        for (final b in mutable) {
          if (remaining <= 0) break;
          final bQty = (b['quantity'] ?? 0.0).toDouble();
          if (bQty <= 0) continue;
          final deduct = bQty > remaining ? remaining : bQty;
          await _local.update('batches', b['id'], {'quantity': bQty - deduct});
          remaining -= deduct;
        }

        if (remaining > 0.0001) {
          throw Exception('Insufficient stock to set exact quantity.');
        }

        await _recalculateItemStock(user.shopId, productId, branchId: branchId);
      }

      await recordAuditLog(
        user.shopId,
        user.username,
        'QUANTITY_EDIT',
        jsonEncode({
          'productId': productId,
          'product': name,
          'oldQuantity': oldQuantity,
          'newQuantity': newQuantity,
          'delta': delta,
          'branch': branchId,
          'user': user.username,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
        branchId: branchId,
      );
    });
  }

  /// THE BATCH ENGINE: Direct/Global Restock Logic 
  /// Implements "Traceable Batch Inventory" Smart-Merge
  Future<void> recordRestock(AppUser user, Map<String, dynamic> restockData, {bool isPurchase = false, bool silent = false, String? customAction}) async {
    if (!user.hasPermission(AppUser.pRestockInventory) && !isPurchase) {
      throw Exception('Permission denied: cannot restock/adjust stock.');
    }
    // Requires: itemId, itemName, addedQuantity, buyingPrice, expiryDate
    // NO duplicate detector constraint here because it operates on existing items.
    
    final String? itemId = restockData['itemId'];
    if (itemId == null) throw Exception("System Error: Item Identity is missing for restock.");
    final double incomingQty = _parseAmount(restockData['addedQuantity']);
    if (incomingQty <= 0) throw Exception("Restock quantity must be greater than zero.");

    // UTC Midnight Formatting strictly enforced for database consistency
    String? incomingExpiryStr;
    final dr = _parseDate(restockData['expiry'] ?? restockData['expiryDate'] ?? restockData['exp']);

    if (dr != null) {
      // Standardize to UTC Midnight string for reliable comparison
      final utc = DateTime.utc(dr.year, dr.month, dr.day);
      incomingExpiryStr = utc.toIso8601String();
    }

    // 1. Fetch existing batches for smart-merge (limited to THIS branch)
    final branchId = restockData['branchId'] ?? user.branchId;
    var existingBatches = await _local.query('batches', 
      where: 'shop_id = ? AND item_id = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
      whereArgs: [user.shopId, itemId, branchId, branchId]);

    // 1. Prepare New Independent Batch Record (Master Fix Rule: NO REUSE)
    final String activeBatchId = _uuid.v4();
    final double newBatchTotal = incomingQty;
    bool merged = false;

    // Independent creation logic enforced: NO REUSE.

    // 3. Perform the Batch Local Insert/Update
    final batchData = {
      'id': activeBatchId,
      'shopId': user.shopId,
      'itemId': itemId,
      'quantity': newBatchTotal,
      'buyingPrice': _parseAmount(restockData['buyingPrice']),
      'sellingPrice': _parseAmount(restockData['sellingPrice']),
      'expiry': incomingExpiryStr,
      'batchNumber': restockData['batchNumber'] ?? '', // optional
      'timestamp': DateTime.now().toIso8601String(),
      'syncStatus': 0,
      'branchId': restockData['branchId'] ?? user.branchId,
      'type': restockData['type'] ?? (isPurchase ? 'purchase' : 'restock'),
    };

    if (merged) {
      await _local.update('batches', activeBatchId, batchData);
    } else {
      await _local.saveBatchRecord(batchData);
    }

    // ── Update Product Threshold if specified ─────────────────────────────
    if (restockData.containsKey('lowStockThreshold')) {
      final lt = int.tryParse(restockData['lowStockThreshold'].toString());
      if (lt != null) {
        await _local.update('products', itemId, {'low_stock_threshold': lt});
      }
    }

    await _recalculateItemStock(user.shopId, itemId, 
      branchId: branchId,
      overrideBuyingPrice: _parseAmount(restockData['buyingPrice']),
      overrideSellingPrice: _parseAmount(restockData['sellingPrice']));

    // 4. Background Sync Removed

    if (!silent) {
      final action = customAction ?? (isPurchase ? 'PURCHASE' : 'RESTOCK');
      final detailMsg = customAction != null
          ? 'Restoration ($customAction) ${restockData['itemName']}: +$incomingQty units'
          : isPurchase
              ? 'Purchased ${restockData['itemName']}: +$incomingQty units'
              : 'Inventory Restocked ${restockData['itemName']}: +$incomingQty units';
      await recordAuditLog(user.shopId, user.username, action, detailMsg, branchId: branchId);
      // No routine 'restock_completed' notification — only critical stock alerts raised by _checkStockTriggers.

      // Stock trigger check only on intentional restocks (never on silent product-creation calls)
      final updated = await _local.query('products', where: 'id = ?', whereArgs: [itemId]);
      if (updated.isNotEmpty) await _checkStockTriggers(user, updated.first, branchId: branchId);
    }

  }

  Future<void> forceRecalculate(String shopId, String itemId, {String? branchId}) async {
    await _recalculateItemStock(shopId, itemId, branchId: branchId);
  }

  /// Recalculates and writes the branch-scoped stock cache for [itemId].
  ///
  /// Pricing rule (source-of-truth):
  ///   1. Use the FIFO/FEFO price from active batch rows (highest priority).
  ///   2. Fall back to [overrideBuyingPrice]/[overrideSellingPrice] only when
  ///      no active batch provides a price (e.g. initial empty-stock registration).
  ///
  /// This guarantees that `products.buying_price` always matches the batch the
  /// system will draw stock from next, keeping every screen in sync.
  Future<Map<String, dynamic>> _recalculateItemStock(
    String shopId,
    String itemId, {
    double? overrideBuyingPrice,
    double? overrideSellingPrice,
    String? branchId,
  }) async {
    final effectiveBranchId = branchId ?? 'main';

    final List<Map<String, dynamic>> batches = await _local.query(
      'batches',
      where: 'shop_id = ? AND item_id = ? AND branch_id = ?',
      whereArgs: [shopId, itemId, effectiveBranchId],
    );

    // HYBRID SORTING — FEFO for expiry-carrying batches, FIFO for the rest.
    final mutableBatches =
        batches.map((e) => Map<String, dynamic>.from(e)).toList();
    mutableBatches.sort((a, b) {
      final tA = _parseDate(a['expiry'] ?? a['exp'] ?? a['expiryDate']);
      final tB = _parseDate(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
      if (tA != null && tB != null) return tA.compareTo(tB);
      if (tA != null) return -1;
      if (tB != null) return 1;
      final tsA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
      final tsB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
      return tsA.compareTo(tsB);
    });

    double activeStock = 0.0;
    double expiredStock = 0.0;   // tracked separately so UI shows real qty
    DateTime? closestActiveExpiry;
    // Prices derived from the FIRST (oldest/soonest-expiring) active batch.
    double? fifoeBuyPrice;
    double? fifoeSellingPrice;
    // Fallback prices from the most recent expired batch (used when ALL batches
    // are expired, to prevent price data from being zeroed out — Req #3).
    double? expiredFallbackBuyPrice;
    double? expiredFallbackSellPrice;

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    for (final b in mutableBatches) {
      final qty = (b['quantity'] ?? 0.0).toDouble();
      if (qty <= 0) continue;

      final exp = _parseDate(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
      bool isExpired = false;

      if (exp != null) {
        final expiryDay = DateTime(exp.year, exp.month, exp.day);
        if (expiryDay.isBefore(todayMidnight)) {
          isExpired = true;
          // Capture fallback pricing from the last expired batch we encounter.
          // mutableBatches is FEFO-sorted so the last expired entry will be
          // the most recently-expired batch — best guess for historical price.
          expiredFallbackBuyPrice = (b['buyingPrice'] ?? 0.0).toDouble();
          expiredFallbackSellPrice = (b['sellingPrice'] ?? 0.0).toDouble();
        } else {
          // Track closest non-expired expiry for the product-level expiry cache.
          if (closestActiveExpiry == null || exp.isBefore(closestActiveExpiry!)) {
            closestActiveExpiry = exp;
          }
        }
      }

      if (!isExpired) {
        activeStock += qty;
        // Capture pricing from the FIRST active batch only (FIFO/FEFO).
        if (fifoeBuyPrice == null) {
          fifoeBuyPrice = (b['buyingPrice'] ?? 0.0).toDouble();
          fifoeSellingPrice = (b['sellingPrice'] ?? 0.0).toDouble();
        }
      } else {
        // Accumulate expired stock so the inventory display shows the real
        // physical quantity. POS is unaffected — it draws from product_stocks
        // which only contains activeStock.
        expiredStock += qty;
      }
    }

    // Resolve final prices:
    //   1. Active FIFO/FEFO batch price (primary).
    //   2. Caller-supplied override (secondary, for new-stock operations).
    //   3. Expired batch fallback — preserves historical price when ALL stock
    //      has expired, so expired products never show 0 prices (Req #3).
    final finalBuyPrice = (fifoeBuyPrice != null && fifoeBuyPrice! > 0)
        ? fifoeBuyPrice!
        : (overrideBuyingPrice ?? expiredFallbackBuyPrice ?? 0.0);
    final finalSellPrice = (fifoeSellingPrice != null && fifoeSellingPrice! > 0)
        ? fifoeSellingPrice!
        : (overrideSellingPrice ?? expiredFallbackSellPrice ?? 0.0);

    final now2 = DateTime.now().toIso8601String();
    // Total physical quantity = active (sellable) + expired (unsellable but real).
    // • product_stocks → activeStock only  (used by POS & low-stock logic)
    // • products.quantity → totalStock      (used by Inventory UI display)
    final totalStock = activeStock + expiredStock;

    // 1. Write branch-scoped ACTIVE quantity into product_stocks (POS authoritative cache).
    await _local.saveProductStock(
      shopId: shopId,
      productId: itemId,
      branchId: effectiveBranchId,
      quantity: activeStock,
    );

    // 2. Write TOTAL quantity (active + expired) back to products row so
    //    the Inventory screen shows the real physical count, not zero.
    final productsUpdate = <String, dynamic>{
      'quantity': totalStock,
      'expiry': closestActiveExpiry?.toIso8601String(),
      'buyingPrice': finalBuyPrice,
      'sellingPrice': finalSellPrice,
      'shopId': shopId,
      'branchId': effectiveBranchId,
      'lastUpdated': now2,
    };
    await _local.update('products', itemId, productsUpdate);

    return {
      'quantity': totalStock,
      'expiry': closestActiveExpiry?.toIso8601String(),
      'buyingPrice': finalBuyPrice,
      'sellingPrice': finalSellPrice,
    };
  }


  /// Processes a refund for a sale, with configurable stock disposition.
  ///
  /// [returnToInventory] — if true, restores refunded quantity back to the
  /// original FEFO/FIFO batch. If false, the products are disposed (damaged /
  /// unsellable) and no stock is restored; only the financial refund is recorded.
  ///
  /// Batch restoration strategy (when [returnToInventory] is true):
  ///   1. PRIMARY: Use `saleData['batchId']` to restore directly to the exact
  ///      batch that was consumed during the sale (guaranteed FEFO/FIFO integrity).
  ///   2. FALLBACK: If batchId is absent (legacy sale records), sort remaining
  ///      batches using the same FEFO/FIFO comparator as `recordSale` — soonest
  ///      expiry first, then oldest timestamp — and restore to the first matching
  ///      batch(es) until the refund quantity is satisfied.
  ///   3. LAST-RESORT: If all batches were deleted post-sale, create a restoration
  ///      batch preserving the original expiry and pricing metadata.
  Future<void> processRefund(
    AppUser user,
    Map<String, dynamic> saleData,
    double refundQty, {
    bool returnToInventory = true,
  }) async {
    if (!user.hasPermission(AppUser.pRefundSales)) {
      throw Exception('Permission denied: cannot refund sales.');
    }
    
    if (refundQty <= 0) throw Exception("Refund quantity must be greater than zero.");
    
    final saleId = saleData['id']?.toString() ?? '';
    final shopId = saleData['shopId']?.toString() ?? user.shopId;
    final branchId = saleData['branchId']?.toString() ?? user.branchId ?? 'main';
    final saleQty = (saleData['quantity'] ?? 0.0).toDouble();
    final prevRefunded = (saleData['refundedQuantity'] ?? 0.0).toDouble();
    final itemId = saleData['itemId']?.toString() ?? '';
    final itemName = saleData['itemName']?.toString() ?? '';
    // The batch ID recorded at sale time (FEFO/FIFO primary batch).
    final saleBatchId = saleData['batchId']?.toString();
    
    if (prevRefunded + refundQty > saleQty + 0.001) {
      throw Exception("Cannot refund more than the sold quantity.");
    }

    await _local.runTransaction(() async {
      // ── Step 1: Mark the sale record as (partially/fully) refunded ──────────
      final newRefunded = prevRefunded + refundQty;
      await _local.update('sales', saleId, {'refundedQuantity': newRefunded});

      // ── Step 2: Stock restoration (skip entirely if product is being disposed) ─
      if (returnToInventory) {
        // Fetch all batches for this item+branch, regardless of current quantity
        // (the target batch may have been fully depleted by this or later sales).
        List<Map<String, dynamic>> allBatches = await _local.query(
          'batches',
          where: 'shop_id = ? AND item_id = ? AND branch_id = ?',
          whereArgs: [shopId, itemId, branchId],
        );

        // Legacy / cross-branch fallback
        if (allBatches.isEmpty && branchId != 'main') {
          allBatches = await _local.query(
            'batches',
            where: 'shop_id = ? AND item_id = ? AND branch_id = ?',
            whereArgs: [shopId, itemId, 'main'],
          );
        }

        if (allBatches.isEmpty) {
          // ── LAST-RESORT: all original batches deleted after sale ─────────────
          // Reconstruct a batch preserving all original metadata so that the
          // restored stock re-enters FEFO correctly.
          debugPrint('[REFUND] No batches found for $itemName — creating restoration batch.');
          await _local.saveBatchRecord({
            'id': _uuid.v4(),
            'shopId': shopId,
            'itemId': itemId,
            'quantity': refundQty,
            'buyingPrice': saleData['buyingPrice'] ?? 0.0,
            'sellingPrice': saleData['sellingPrice'] ?? 0.0,
            'expiryDate': saleData['expiryDate'],   // Preserve original expiry
            'supplierName': saleData['supplierName'] ?? 'Refund Restoration',
            'branchId': branchId,
            'type': 'refund_restore',
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else {
          final mutable = allBatches.map((e) => Map<String, dynamic>.from(e)).toList();

          double remaining = refundQty;

          // ── STRATEGY 1: Precise batch restoration via stored batchId ─────────
          if (saleBatchId != null && saleBatchId.isNotEmpty) {
            final exactBatch = mutable.where((b) => b['id']?.toString() == saleBatchId).toList();
            if (exactBatch.isNotEmpty) {
              final b = exactBatch.first;
              final currentQty = (b['quantity'] ?? 0.0).toDouble();
              debugPrint('[REFUND] Precise: restoring $remaining to batch $saleBatchId (was $currentQty). Expiry: ${b['expiry'] ?? b['expiryDate']}');
              await _local.update('batches', b['id'], {'quantity': currentQty + remaining});
              remaining = 0;
            } else {
              debugPrint('[REFUND] batchId $saleBatchId not found — falling back to FEFO/FIFO sort.');
            }
          }

          // ── STRATEGY 2: FEFO/FIFO fallback (legacy sales without batchId) ────
          // Mirrors the exact sort order from recordSale so the restored units
          // land on the batch that would have been consumed first.
          if (remaining > 0.001) {
            mutable.sort((a, b) {
              final tA = _parseDate(a['expiry'] ?? a['exp'] ?? a['expiryDate']);
              final tB = _parseDate(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
              if (tA != null && tB != null) return tA.compareTo(tB);
              if (tA != null) return -1;
              if (tB != null) return 1;
              final tsA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
              final tsB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
              return tsA.compareTo(tsB); // FIFO
            });

            for (final b in mutable) {
              if (remaining <= 0.001) break;
              final currentQty = (b['quantity'] ?? 0.0).toDouble();
              debugPrint('[REFUND] FEFO/FIFO fallback: restoring $remaining to batch ${b['id']} (was $currentQty). Expiry: ${b['expiry'] ?? b['expiryDate']}');
              await _local.update('batches', b['id'], {'quantity': currentQty + remaining});
              remaining = 0; // Single-batch restore — all units go to the FEFO head
            }
          }
        }

        // ── Step 3: Recalculate stock cache (FEFO/FIFO order is recomputed here) ─
        await _recalculateItemStock(shopId, itemId, branchId: branchId);
      }

      // ── Step 4: Audit Log ─────────────────────────────────────────────────────
      final disposition = returnToInventory ? 'returned to original batch' : 'disposed (not restocked)';
      await _local.recordAuditLog(
        shopId,
        user.username,
        'REFUND',
        'Refunded $refundQty units of $itemName ($disposition). Sale ID: $saleId',
        branchId: branchId,
      );
    });
  }

  Future<void> recordSale(AppUser user, Map<String, dynamic> saleData) async {
    if (!user.hasPermission(AppUser.pAccessPOS)) {
      throw Exception('Permission denied: cannot access POS.');
    }
    final double totalQuantity = _parseAmount(saleData['quantity']);
    if (totalQuantity <= 0) throw Exception('Quantity must be greater than zero.');
    
    final itemId = saleData['itemId'];
    final totalPrice = (saleData['totalPrice'] ?? 0.0).toDouble();

    await _local.runTransaction(() async {
      // 1. Fetch existing batches for the product IN THIS BRANCH
      final branchId = saleData['branchId']?.toString() ?? user.branchId;
      final queryBranchId = (branchId == 'all') ? user.branchId : branchId;
      
      List<Map<String, dynamic>> batchesRaw = await _local.query('batches', 
        where: 'shop_id = ? AND item_id = ? AND branch_id = ?', 
        whereArgs: [user.shopId, itemId, queryBranchId]
      );
      
      if (batchesRaw.isEmpty) {
         throw Exception("Out of stock: No batches found for this product in this branch. Please restock first.");
      }

      List<Map<String, dynamic>> mutableBatches = batchesRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      // 2. FEFO (First Expiry First Out) Sorting + EXPIRED FILTERING
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      mutableBatches.sort((a, b) {
        final tA = _parseDate(a['expiry'] ?? a['exp'] ?? a['expiryDate']);
        final tB = _parseDate(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
        
        // 1. If both have expiries -> FEFO
        if (tA != null && tB != null) return tA.compareTo(tB);
        
        // 2. Expiring batches always go BEFORE non-expiring batches
        if (tA != null) return -1;
        if (tB != null) return 1;
        
        // 3. Both have no expiry -> FIFO (By timestamp)
        final tsA = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime(2000);
        final tsB = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime(2000);
        return tsA.compareTo(tsB);
      });
      
      // Filter out explicitly expired batches (Strict local date comparison)
      final activeBatches = mutableBatches.where((b) {
        final exp = _parseDate(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
        if (exp == null) return true; // No expiry = never expires
        final expiryDay = DateTime(exp.year, exp.month, exp.day);
        return !expiryDay.isBefore(today);
      }).toList();

      if (activeBatches.isEmpty) {
        throw Exception("Out of stock: All available batches for this product have EXPIRED.");
      }

      double remainingToDeduct = totalQuantity;
      double totalSaleProfit = 0;
      double totalSaleAmount = 0;
      // Track the FEFO/FIFO primary batch for refund restoration.
      String? primaryBatchId;

      // 3. Atomically Deduct from Active Batches
      for (var b in activeBatches) {
        if (remainingToDeduct <= 0) break;
        
        final double batchQty = (b['quantity'] ?? 0.0).toDouble();
        if (batchQty <= 0) continue;

        final deduction = batchQty > remainingToDeduct ? remainingToDeduct : batchQty;
        final double batchBuyingPrice = (b['buyingPrice'] ?? 0.0).toDouble();
        final double batchSellingPrice = (b['sellingPrice'] ?? (saleData['sellingPrice'] as num?)?.toDouble()) ?? 0.0;
        
        // Record the first (FEFO/FIFO) batch consumed as the authoritative batch ID.
        primaryBatchId ??= b['id']?.toString();
        
        // Dynamic Pricing: Total amount is the sum of prices from batches consumed
        totalSaleAmount += batchSellingPrice * deduction;
        
        // Calculate profit based on the actual buying price of this specific batch
        totalSaleProfit += (batchSellingPrice - batchBuyingPrice) * deduction;
        
        // UPDATE BATCH QUANTITY correctly
        final newBatchQty = batchQty - deduction;
        await _local.update('batches', b['id'], {'quantity': newBatchQty});
        
        remainingToDeduct -= deduction;
      }

      if (remainingToDeduct > 0.001) {
        throw Exception("Insufficient UNEXPIRED stock to complete sale. Missing $remainingToDeduct units.");
      }

      // 4. Record the Sale Transaction record
      final saleId = _uuid.v4();
      final finalSale = {
        ...saleData,
        'id': saleId,
        'totalPrice': totalSaleAmount,
        'profit': totalSaleProfit,
        'sellingPrice': totalQuantity > 0 ? totalSaleAmount / totalQuantity : (saleData['sellingPrice'] ?? 0.0),
        'batchId': primaryBatchId, // FEFO/FIFO batch reference for future refund precision
        'syncStatus': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'branchId': saleData['branchId'] ?? user.branchId,
      };

      await _local.saveSale(finalSale);

      // 5. Trigger flat stock recalculation cache
      await _recalculateItemStock(user.shopId, itemId, branchId: branchId);

      // Check triggers for current branch
      final productRaw = await _local.query('products', where: 'id = ?', whereArgs: [itemId], limit: 1);
      if (productRaw.isNotEmpty) {
        await _checkStockTriggers(user, productRaw.first, branchId: branchId);
      }
      
      // 6. Audit Log
      final itemName = saleData['itemName'] ?? 'Unknown Item';
      final isDebtSale = saleData['isDebt'] == true || saleData['isDebt'] == 1;
      final actionType = isDebtSale ? 'DEBT_PAYMENT' : 'SALE';
      
      String detailsStr = 'Sold $totalQuantity units of $itemName. Total Price: ${totalSaleAmount.toStringAsFixed(2)}, Profit: ${totalSaleProfit.toStringAsFixed(2)}';
      
      if (isDebtSale) {
        final advanced = (saleData['advancedPaid'] ?? 0.0).toDouble();
        final remaining = (saleData['debtRemaining'] ?? 0.0).toDouble();
        final customerName = saleData['customerName'] ?? 'Unknown Customer';
        detailsStr = 'Debt Sale to $customerName: $totalQuantity units of $itemName. Adv: ${advanced.toStringAsFixed(2)}, Rem: ${remaining.toStringAsFixed(2)}. Total: ${totalSaleAmount.toStringAsFixed(2)}';
      }

      await recordAuditLog(
          user.shopId, 
          user.username, 
          actionType, 
          detailsStr, 
          branchId: branchId
      );
    });

    // No routine 'sale_completed' notification — sales are visible in the sales report/audit log.
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
    if (!user.hasPermission(AppUser.pManagePurchases)) {
      throw Exception('Permission denied: cannot edit purchases.');
    }
    // Only supplierName and price allowed for editing in logs as per request
    final cleanData = {
      if (data.containsKey('supplierName')) 'supplierName': data['supplierName'],
      if (data.containsKey('unitCost')) 'unitCost': data['unitCost'],
      if (data.containsKey('totalCost')) 'totalCost': data['totalCost'],
      'syncStatus': 0,
    };
    
    await _local.update('purchases', purchaseId, cleanData);
  }

  Future<void> recordPurchase(AppUser user, Map<String, dynamic> purchaseData, {bool forceNew = false}) async {
    if (!user.hasPermission(AppUser.pManagePurchases)) {
      throw Exception('Permission denied: cannot add purchases.');
    }
    final id = _uuid.v4();
    final finalPurchase = {
      ...purchaseData,
      'id': id,
      'syncStatus': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    // 1. Automated Inventory Integration & Precise Matching
    String? actualItemId = finalPurchase['itemId'];
    final barcode = finalPurchase['barcode']?.toString() ?? '';
    final itemName = finalPurchase['itemName']?.toString() ?? '';
    final branchId = purchaseData['branchId'] ?? user.branchId;

    if (!forceNew) {
      // Logic: Barcode check first (if available)
      if (barcode.isNotEmpty) {
        final barcodeMatches = await _local.query('products', 
          where: 'shop_id = ? AND barcode = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
          whereArgs: [user.shopId, barcode, branchId, branchId]
        );
        if (barcodeMatches.isNotEmpty) {
            final existing = barcodeMatches.first;
            if (existing['name'].toString().toLowerCase() != itemName.toLowerCase()) {
              throw Exception("Barcode Mismatch: Barcode '$barcode' is already assigned to '${existing['name']}'.");
            }
            actualItemId = existing['id'];
        }
      }

      // Name fallback ONLY if no ID found yet
      if (actualItemId == null || actualItemId!.isEmpty) {
        final nameMatches = await _local.query('products', 
          where: 'shop_id = ? AND name = ? AND (branch_id = ? OR (branch_id IS NULL AND ? = "main"))', 
          whereArgs: [user.shopId, itemName, branchId, branchId]
        );
        if (nameMatches.isNotEmpty) {
            actualItemId = nameMatches.first['id'];
        }
      }
    }
    
    await _local.runTransaction(() async {
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
          'expiry': finalPurchase['expiry'] ?? finalPurchase['expiryDate'] ?? finalPurchase['exp'],
          'supplierName': finalPurchase['supplierName'],
          'quantity': 0, 
        }, forceNew: true);
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
        // Carry the selling price entered by the user so the batch — and the
        // product cache written by _recalculateItemStock — stores a non-zero price.
        'sellingPrice': finalPurchase['sellingPrice'] ?? 0.0,
        'expiry': finalPurchase['expiry'] ?? finalPurchase['expiryDate'] ?? finalPurchase['exp'],
        'supplierName': finalPurchase['supplierName'],
        'batchNumber': finalPurchase['batchNumber'],
        'branchId': branchId,
      }, isPurchase: true);
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
    if (!user.hasPermission(AppUser.pAddEditProducts)) {
      throw Exception('Permission denied: cannot delete products.');
    }
    await _local.delete('products', productId);
    await recordAuditLog(user.shopId, user.username, 'DELETE_ITEM', 'Permanently deleted item $productId', branchId: user.branchId);
  }

  Future<void> deleteUser(AppUser admin, String userId) async {
    await recordAuditLog(admin.shopId, admin.username, 'DELETE_USER', 'Deleted user account $userId', branchId: admin.branchId);
  }

  Future<void> factoryReset(String shopId) async {
    await _local.factoryReset(shopId);
  }

  Future<void> transferStock({
    required AppUser admin,
    required String itemId,
    required String itemName,
    required String fromBranchId,
    required String toBranchId,
    required double quantity,
    String? batchId,
  }) async {
    if (!admin.hasPermission(AppUser.pTransferStock)) {
      throw Exception('Permission denied: cannot transfer stock.');
    }
    if (fromBranchId == toBranchId) throw Exception("Source and destination branches must be different.");
    if (quantity <= 0) throw Exception("Quantity must be greater than zero.");

    await _local.runTransaction(() async {
      // 1. Direct Branch Stock Adjustment (Primary Success Path)
      final sourceStockRow = await _local.query('product_stocks', 
        where: 'shopId = ? AND productId = ? AND branchId = ?', 
        whereArgs: [admin.shopId, itemId, fromBranchId]);
      final destStockRow = await _local.query('product_stocks', 
        where: 'shopId = ? AND productId = ? AND branchId = ?', 
        whereArgs: [admin.shopId, itemId, toBranchId]);
      
      final double prevSourceQty = sourceStockRow.isNotEmpty ? (sourceStockRow.first['quantity'] ?? 0.0).toDouble() : 0.0;
      final double prevDestQty = destStockRow.isNotEmpty ? (destStockRow.first['quantity'] ?? 0.0).toDouble() : 0.0;

      if (prevSourceQty < quantity) {
        throw Exception("Insufficient total stock in source branch. Available: $prevSourceQty, Requested: $quantity");
      }

      await _local.saveProductStock(
        shopId: admin.shopId,
        productId: itemId,
        branchId: fromBranchId,
        quantity: prevSourceQty - quantity,
      );
      
      await _local.saveProductStock(
        shopId: admin.shopId,
        productId: itemId,
        branchId: toBranchId,
        quantity: prevDestQty + quantity,
      );

      // 1.5 Ensure Product Definition exists in destination branch
      final destProductRow = await _local.query('products', 
        where: 'id = ? AND branch_id = ?', 
        whereArgs: [itemId, toBranchId]);
      
      if (destProductRow.isEmpty) {
        final sourceProduct = await _local.query('products', 
          where: 'id = ? AND branch_id = ?', 
          whereArgs: [itemId, fromBranchId]);
        
        if (sourceProduct.isNotEmpty) {
           final p = Map<String, dynamic>.from(sourceProduct.first);
           // Create a new entry for this branch with same itemId but branch-specific definition
           await _local.insert('products', {
             ...p,
             'branchId': toBranchId,
           });
        }
      }

      // 2. Automated Batch Adjustment (with fallback support)
      final sourceBatchesRaw = await _local.query('batches', 
        where: 'shop_id = ? AND item_id = ? AND branch_id = ? AND quantity > 0', 
        whereArgs: [admin.shopId, itemId, fromBranchId]
      );
      
      double remaining = quantity;
      List<Map<String, dynamic>> sourceBatches = sourceBatchesRaw.map((e) => Map<String, dynamic>.from(e)).toList();
      
      // Sort: Selected batch FIRST, then FEFO for the rest.
      sourceBatches.sort((a, b) {
        if (batchId != null) {
          if (a['id'] == batchId) return -1;
          if (b['id'] == batchId) return 1;
        }
        final expA = _parseDate(a['expiry'] ?? a['exp'] ?? a['expiryDate']);
        final expB = _parseDate(b['expiry'] ?? b['exp'] ?? b['expiryDate']);
        if (expA == null && expB == null) return 0;
        if (expA == null) return 1; 
        if (expB == null) return -1;
        return expA.compareTo(expB);
      });

      for (var b in sourceBatches) {
        if (remaining <= 0) break;
        final bQty = (b['quantity'] ?? 0.0).toDouble();
        final deduct = bQty > remaining ? remaining : bQty;
        
        // Update source batch
        await _local.update('batches', b['id'], {
          'quantity': bQty - deduct,
          'shopId': admin.shopId,
          'branchId': fromBranchId,
        });
        
        // Update destination batch — Smart Merging
        final expVal = b['expiry'] ?? b['exp'] ?? b['expiryDate'];
        final batchNum = b['batchNumber'];
        List<Map<String, dynamic>> destBatches;
        
        final buyP = (b['buyingPrice'] ?? 0.0).toDouble();
        final sellP = (b['sellingPrice'] ?? 0.0).toDouble();
        
        if (expVal != null) {
          destBatches = await _local.query('batches', 
            where: 'shop_id = ? AND item_id = ? AND branch_id = ? AND expiry_date = ? AND buying_price = ? AND selling_price = ? AND (batch_number = ? OR (batch_number IS NULL AND ? = ""))', 
            whereArgs: [admin.shopId, itemId, toBranchId, expVal, buyP, sellP, batchNum, batchNum ?? '']
          );
        } else {
          destBatches = await _local.query('batches', 
            where: 'shop_id = ? AND item_id = ? AND branch_id = ? AND expiry_date IS NULL AND buying_price = ? AND selling_price = ? AND (batch_number = ? OR (batch_number IS NULL AND ? = ""))', 
            whereArgs: [admin.shopId, itemId, toBranchId, buyP, sellP, batchNum, batchNum ?? '']
          );
        }
        
        if (destBatches.isNotEmpty) {
           final db = destBatches.first;
           await _local.update('batches', db['id'], {
              'quantity': (db['quantity'] ?? 0.0) + deduct,
              'shopId': admin.shopId,
              'branchId': toBranchId,
           });
        } else {
           await _local.saveBatchRecord({
             'id': _uuid.v4(),
             'shopId': admin.shopId,
             'branchId': toBranchId,
             'itemId': itemId,
             'itemName': itemName,
             'quantity': deduct,
             'buyingPrice': buyP,
             'sellingPrice': sellP,
             'expiryDate': expVal,
             'batchNumber': batchNum,
             'timestamp': DateTime.now().toIso8601String(),
           });
        }
        remaining -= deduct;
      }
      
      // If batches were exhausted but we still have remaining, create a catch-all batch in dest 
      // This ensures product_stocks and batches stay reconciled even after messy state.
      if (remaining > 0) {
         await _local.saveBatchRecord({
             'id': 'TF-BAL-${_uuid.v4()}',
             'shopId': admin.shopId,
             'branchId': toBranchId,
             'itemId': itemId,
             'itemName': itemName,
             'quantity': remaining,
             'buyingPrice': 0.0,
             'sellingPrice': 0.0,
             'expiryDate': null,
             'batchNumber': 'TF-BALANCE',
         });
      }

      // 3. Recalculation NOT needed: product_stocks are already authoritative
      //    as they were directly updated via saveProductStock above.
      //    Calling _recalculateItemStock here would re-read batches and
      //    potentially trigger the 'main' legacy fallback, overwriting the
      //    correct values we just set.
      //    We only need to update the flat products.quantity cache for display.
      await _local.update('products', itemId, {
        'quantity': prevSourceQty - quantity,
        'shopId': admin.shopId,
        'branchId': fromBranchId,
      });

      // 4. Force a recalculation for the destination branch to refresh its caches
      await _recalculateItemStock(admin.shopId, itemId, branchId: toBranchId);

      final double newSourceQty = prevSourceQty - quantity;
      final double newDestQty = prevDestQty + quantity;

      await recordAuditLog(admin.shopId, admin.username, 'BRANCH_TRANSFER', 
        'Transferred $quantity units of $itemName from $fromBranchId to $toBranchId. '
        'Source: ${prevSourceQty.toStringAsFixed(0)} -> ${newSourceQty.toStringAsFixed(0)}, '
        'Dest: ${prevDestQty.toStringAsFixed(0)} -> ${newDestQty.toStringAsFixed(0)}', 
        branchId: fromBranchId);
    });

    // No routine 'transfer_completed' notification — transfers appear in the audit log.
  }

  Future<void> updateDebtPayments(AppUser user, List<Map<String, dynamic>> items, double totalAmount) async {
    String customerName = 'Unknown Customer';
    if (items.isNotEmpty && items.first['customerName'] != null) {
      customerName = items.first['customerName'];
    }
    double totalRemainingBefore = items.fold(0.0, (sum, m) => sum + (m['debtRemaining'] ?? 0.0).toDouble());
    
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

    double remainingAfter = totalRemainingBefore - totalAmount;
    if (remainingAfter < 0) remainingAfter = 0;
    
    String detailsStr = 'Payment from $customerName of ${totalAmount.toStringAsFixed(2)}. Remainder: ${remainingAfter.toStringAsFixed(2)}';
    await recordAuditLog(user.shopId, user.username, 'DEBT_PAYMENT', detailsStr, branchId: user.branchId);
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

