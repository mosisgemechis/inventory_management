import 'package:cloud_firestore/cloud_firestore.dart';
import 'database_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../utils/thread_safe_stream.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _offline = DatabaseService();
  final _uuid = const Uuid();

  // --- SYNC LOGIC ---
  static const Map<String, List<String>> _tableSchemas = {
    'products': ['id', 'shopId', 'branchId', 'name', 'barcode', 'quantity', 'buyingPrice', 'sellingPrice', 'lowStockThreshold', 'batchNumber', 'expiryDate', 'lastUpdated', 'isSynced'],
    'sales': ['id', 'shopId', 'branchId', 'itemId', 'itemName', 'quantity', 'totalPrice', 'profit', 'customerName', 'timestamp', 'isSynced'],
    'purchases': ['id', 'shopId', 'itemId', 'itemName', 'quantity', 'unitCost', 'batchNumber', 'expiryDate', 'timestamp', 'isSynced'],
    'audit_logs': ['id', 'shopId', 'username', 'action', 'details', 'timestamp', 'isSynced'],
    'items': ['id', 'shopId', 'branchId', 'name', 'barcode', 'quantity', 'buyingPrice', 'sellingPrice', 'lowStockThreshold', 'batchNumber', 'expiryDate', 'lastUpdated', 'isSynced'],
    'suppliers': ['id', 'shopId', 'name', 'outstandingDebt', 'totalPaid', 'lastUpdated', 'isSynced'],
    'batches': ['id', 'shopId', 'itemId', 'quantity', 'buyingPrice', 'expiryDate', 'batchNumber', 'timestamp', 'isSynced'],
  };

  Map<String, dynamic> _sanitizeForSql(String table, Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    final schema = _tableSchemas[table] ?? [];
    
    data.forEach((key, value) {
      if (schema.isNotEmpty && !schema.contains(key)) return; 

      if (value is FieldValue) {
        sanitized[key] = DateTime.now().toIso8601String();
      } else if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      } else if (key == 'quantity' || key.contains('Price') || key.contains('Cost') || key.contains('Profit') || key.contains('Total')) {
        sanitized[key] = (value as num?)?.toDouble() ?? 0.0;
      } else if (value is Map) {
        // Skip
      } else if (value is List) {
        // Skip
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  Map<String, dynamic> _sanitizeForHive(Map<String, dynamic> data) {
     final s = Map<String, dynamic>.from(data);
     s.forEach((k, v) {
       if (v is Timestamp) s[k] = v.toDate().toIso8601String();
       else if (v is FieldValue) s[k] = DateTime.now().toIso8601String();
       else if (v is bool) s[k] = v;
     });
     return s;
  }

  Future<void> syncAll(String shopId) async {
    // 1. Push Local -> Firestore
    final tables = ['products', 'sales', 'suppliers', 'purchases', 'audit_logs', 'batches'];
    for (var table in tables) {
      final unsynced = await _offline.getUnsynced(table);
      for (var data in unsynced) {
        try {
          final id = data['id'];
          final firestoreData = Map<String, dynamic>.from(data);
          firestoreData.remove('isSynced');
          await _db.collection(table == 'products' ? 'items' : table).doc(id).set(firestoreData);
          await _offline.markSynced(table, id);
        } catch (e) {
          debugPrint("Push Sync Error for $table ($shopId): $e");
        }
      }
    }
    // 1. Push Local -> Firestore (Unsynced items)
    await pushChanges(shopId);
    
    // 2. Pull Firestore -> Local
    await pullChanges(shopId);
  }

  Future<void> pushChanges(String shopId) async {
    final tables = ['products', 'sales', 'purchases', 'audit_logs', 'batches'];
    for (var table in tables) {
      final unsynced = await _offline.getUnsynced(table);
      for (var row in unsynced) {
        try {
          final id = row['id'];
          final firestoreTable = table == 'products' ? 'items' : table;
          
          final syncData = Map<String, dynamic>.from(row);
          syncData.remove('isSynced');
          
          // Add network-only fields
          syncData['lastUpdated'] = FieldValue.serverTimestamp();
          
          await _db.collection(firestoreTable).doc(id).set(syncData, SetOptions(merge: true));
          await _offline.markSynced(table, id);
        } catch (e) {
          debugPrint("Push Sync Failed ($table): $e");
        }
      }
    }
  }

  Future<void> pullChanges(String shopId) async {
    final tables = ['items', 'sales', 'suppliers', 'purchases', 'batches'];
    for (var table in tables) {
      try {
        final snapshot = await _db.collection(table).where('shopId', isEqualTo: shopId).get();
        for (var doc in snapshot.docs) {
          final remoteData = doc.data();
          final id = remoteData['id'] ?? doc.id;
          
          // Check local timestamp
          final localTable = table == 'items' ? 'products' : table;
          final localData = await _offline.getById(localTable, id);
          
          bool shouldUpdate = false;
          if (localData == null) {
            shouldUpdate = true;
          } else {
            final remoteTs = _parseTimestamp(remoteData['lastUpdated'] ?? remoteData['timestamp'] ?? remoteData['createdAt']);
            final localTs = DateTime.tryParse(localData['lastUpdated'] ?? localData['timestamp'] ?? '');
            if (remoteTs != null && (localTs == null || remoteTs.isAfter(localTs))) {
              shouldUpdate = true;
            }
          }

          if (shouldUpdate) {
            final sqlData = _sanitizeForSql(table, remoteData);
            sqlData['id'] = id; // Ensure Document ID is mirrored in SQL
            sqlData['isSynced'] = 1; 
            if (table == 'items' || table == 'products') {
              await _offline.saveProduct(sqlData);
            } else if (table == 'sales') {
              await _offline.saveSale(sqlData);
            } else if (table == 'purchases') {
              await _offline.savePurchase(sqlData);
            } else if (table == 'suppliers') {
               await _offline.update('suppliers', sqlData, where: 'id = ?', whereArgs: [id]); 
            } else if (table == 'batches') {
               await _offline.insert('batches', sqlData);
            }
          }
        }
      } catch (e) {
        debugPrint("CRITICAL SYNC ERROR [$table]: $e");
      }
    }
  }

  DateTime? _parseTimestamp(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  // --- BRANCH ACTIONS ---
  Future<void> addBranch(Map<String, dynamic> data) async {
    await _db.collection('branches').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getBranches(String shopId) {
    return _db.collection('branches').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  Future<void> addUser(Map<String, dynamic> data) async {
    await _db.collection('users').add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // --- ITEM / PRODUCT ACTIONS ---
  Future<void> addItem(Map<String, dynamic> data, {String? addedBy}) async {
    final name = data['name']?.toString().toLowerCase().trim() ?? '';
    final barcode = data['barcode']?.toString().trim() ?? '';
    final shopId = data['shopId'];

    // 1. Strict Duplicate Check (Firebase)
    try {
      if (barcode.isNotEmpty) {
        var barcodeMatch = await _db.collection('items')
            .where('shopId', isEqualTo: shopId)
            .where('barcode', isEqualTo: barcode)
            .get()
            .timeout(const Duration(seconds: 10));
        if (barcodeMatch.docs.isNotEmpty) throw Exception('Item already exists in inventory (Barcode Match).');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('already exists')) rethrow;
      // If it's just a timeout, we log it and proceed using the local validator check to allow offline creation.
      print("Firebase checks took too long (offline?). Relying on local checks. $e");
    }

    // 2. Strict Duplicate Check (Cross-Platform Local)
    final res = await _offline.searchItems(shopId ?? '', data['name'] ?? '', barcode);
    if (res.isNotEmpty) throw Exception('Item already exists in inventory (Local Match).');

    final id = data['id'] ?? _uuid.v4();
    final productData = {
      ...data,
      'id': id,
      'name_lowercase': name, // Helpful for case-insensitive queries
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _offline.saveProduct(_sanitizeForSql('items', productData));
    
    // Use fire-and-forget for the remote part to ensure zero-latency UI
    _db.collection('items').doc(id).set(productData).then((_) {
      _offline.markSynced('products', id);
    }).catchError((e) {
      debugPrint("Background Item Sync Delay: $e");
    });

    if (addedBy != null && data.containsKey('shopId')) {
      await recordAuditLog(data['shopId'], addedBy, 'ADD_ITEM', 'Added ${data['name']}');
      
      final sellPrice = (data['sellingPrice'] as num? ?? 0).toDouble();
      if (sellPrice <= 0) {
        await addNotification(data['shopId'], 'Medicine "${data['name']}" added but needs selling price set before sell.', 'admin');
      }
    }
  }

  Stream<QuerySnapshot> getInventory(String shopId) {
    return _db.collection('items').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  Future<void> deleteItem(String productId) async {
    await _db.collection('items').doc(productId).delete();
  }

  Future<void> updateItem(String id, Map<String, dynamic> data, {String? updatedBy}) async {
    final updateData = {
      ...data,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _offline.saveProduct(_sanitizeForHive({...updateData, 'id': id}));

    _db.collection('items').doc(id).update(updateData).then((_) {
      _offline.markSynced('products', id);
    }).catchError((e) {
      debugPrint("Background Update Sync Delay: $e");
    });
  }

  Future<void> recordBatch(Map<String, dynamic> data, {Map<String, dynamic>? itemSummaryUpdate}) async {
    final batch = _db.batch();
    
    final batchData = Map<String, dynamic>.from(data);
    batchData.remove('isSynced');
    batchData['lastUpdated'] = FieldValue.serverTimestamp();
    batch.set(_db.collection('batches').doc(data['id']), batchData, SetOptions(merge: true));
    
    if (itemSummaryUpdate != null) {
      batch.update(_db.collection('items').doc(data['itemId']), {
        ...itemSummaryUpdate,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
    
    await batch.commit();
  }

  Future<void> recordSaleWithBatches(Map<String, dynamic> saleData, List<Map<String, dynamic>> updatedBatches, {Map<String, dynamic>? itemSummaryUpdate}) async {
    final itemId = saleData['itemId'];
    final soldQty = (saleData['quantity'] ?? 0).toDouble();
    final id = saleData['id'] ?? _uuid.v4();

    // Use a WriteBatch for atomicity
    final batch = _db.batch();
    
    final saleRef = _db.collection('sales').doc(id);
    final itemRef = _db.collection('items').doc(itemId);
    
    // 1. Log sale
    batch.set(saleRef, {
      ...saleData, 
      'id': id, 
      'timestamp': FieldValue.serverTimestamp()
    });
    
    // 2. Update item cache (Force absolute sync if available to avoid race conditions)
    if (itemSummaryUpdate != null) {
       batch.update(itemRef, {
         ...itemSummaryUpdate,
         'lastUpdated': FieldValue.serverTimestamp(),
       });
    } else {
       batch.update(itemRef, {
         'quantity': FieldValue.increment(-soldQty),
         'lastUpdated': FieldValue.serverTimestamp(),
       });
    }

    // 3. Update all affected batches
    for (var b in updatedBatches) {
      final batchRef = _db.collection('batches').doc(b['id']);
      // ensure we don't send isSynced 
      final mapped = Map<String, dynamic>.from(b);
      mapped.remove('isSynced');
      mapped['lastUpdated'] = FieldValue.serverTimestamp();
      batch.set(batchRef, mapped, SetOptions(merge: true));
    }

    await batch.commit();
    
    // Offline record keeping
    await recordAuditLog(saleData['shopId'], saleData['username'] ?? 'system', 'SALE', 'Sold $soldQty of ${saleData['itemName']}');
  }

  Future<void> updatePurchase(String purchaseId, Map<String, dynamic> data) async {
    final updateData = {
      ...data,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    updateData.remove('isSynced');
    await _db.collection('purchases').doc(purchaseId).update(updateData);
  }

  // --- SALES ACTIONS ---
  Future<void> recordSale(Map<String, dynamic> saleData) async {
    final itemId = saleData['itemId'];
    final soldQty = (saleData['quantity'] ?? 0).toDouble();
    final id = saleData['id'] ?? _uuid.v4();

    // Use a WriteBatch for atomicity without the thread-sensitive runTransaction loop
    final batch = _db.batch();
    
    final saleRef = _db.collection('sales').doc(id);
    final itemRef = _db.collection('items').doc(itemId);
    
    batch.set(saleRef, {
      ...saleData, 
      'id': id, 
      'timestamp': FieldValue.serverTimestamp()
    });
    
    batch.update(itemRef, {
      'quantity': FieldValue.increment(-soldQty),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    
    // Offline record keeping
    await recordAuditLog(saleData['shopId'], saleData['username'] ?? 'system', 'SALE', 'Sold $soldQty of ${saleData['itemName']}');
  }

  Future<void> processBulkCheckout(List<Map<String, dynamic>> items, Map<String, dynamic> metadata) async {
    final batch = _db.batch();
    
    for (var item in items) {
      final saleId = _uuid.v4();
      final itemId = item['itemId'];
      final qty = (item['quantity'] ?? 0).toDouble();
      final price = (item['price'] ?? 0).toDouble();
      
      final saleRef = _db.collection('sales').doc(saleId);
      final itemRef = _db.collection('items').doc(itemId);
      
      batch.set(saleRef, {
        ...metadata,
        'id': saleId,
        'itemId': itemId,
        'itemName': item['itemName'],
        'quantity': qty,
        'unitPrice': price,
        'totalPrice': qty * price,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      batch.update(itemRef, {
        'quantity': FieldValue.increment(-qty),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Stream<QuerySnapshot> getSales(String shopId) {
    return _db.collection('sales').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  // --- PURCHASE ACTIONS ---
  Future<void> recordPurchase(Map<String, dynamic> purchaseData) async {
    final id = purchaseData['id'] ?? _uuid.v4();
    final shopId = purchaseData['shopId'];

    // Deep-link sanitization for Firestore
    final firestoreData = Map<String, dynamic>.from(purchaseData);
    firestoreData.remove('isSynced');
    
    // Ensure timestamp is server-side if not explicitly provided as an ISO string
    if (firestoreData['timestamp'] == null) {
      firestoreData['timestamp'] = FieldValue.serverTimestamp();
    }

    await _db.collection('purchases').doc(id).set(firestoreData, SetOptions(merge: true));
    
    // Safety backfill
    await _offline.savePurchase(_sanitizeForSql('purchases', purchaseData));
    
    // Optional: Record audit log if user info is present
    if (purchaseData.containsKey('username')) {
       await recordAuditLog(shopId, purchaseData['username'], 'PURCHASE', 'In-bound log for ${purchaseData['itemName']}');
    }
  }

  Stream<QuerySnapshot> getPurchases(String shopId) {
    return _db.collection('purchases')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .toMainThread();
  }

  // --- SUPPLIER ACTIONS ---
  Future<void> addSupplier(Map<String, dynamic> data) async {
    final id = _uuid.v4();
    await _db.collection('suppliers').doc(id).set({
      ...data,
      'id': id,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getSuppliers(String shopId) {
    return _db.collection('suppliers').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    await _db.collection('users').doc(userId).update(updates);
  }

  Future<void> addSupplierPayment(String supplierId, double amountPaid) async {
    await _db.runTransaction((t) async {
      final docRef = _db.collection('suppliers').doc(supplierId);
      final doc = await t.get(docRef);
      if (doc.exists) {
        final currentDebt = (doc.data() as Map)['outstandingDebt'] ?? 0.0;
        final currentPaid = (doc.data() as Map)['totalPaid'] ?? 0.0;
        t.update(docRef, {
          'outstandingDebt': (currentDebt - amountPaid) < 0 ? 0.0 : (currentDebt - amountPaid),
          'totalPaid': currentPaid + amountPaid,
          'lastPaymentDate': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // --- OTHERS ---
  Future<void> recordAuditLog(String shopId, String username, String action, String details) async {
    final logData = {
      'id': _uuid.v4(),
      'shopId': shopId,
      'username': username,
      'action': action,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    };
    await _offline.saveAuditLog(_sanitizeForHive(logData));
    try {
      await _db.collection('audit_logs').doc(logData['id'] as String).set(logData);
      await _offline.markSynced('audit_logs', logData['id'] as String);
    } catch (_) {}
  }

  Future<void> clearAllData(String shopId) async {
    final collections = ['items', 'sales', 'suppliers', 'purchases', 'audit_logs', 'notifications'];
    for (var col in collections) {
      final snap = await _db.collection(col).where('shopId', isEqualTo: shopId).get();
      for (var doc in snap.docs) {
        await doc.reference.delete();
      }
    }
  }

  Future<void> addNotification(String shopId, String message, String type) async {
    await _db.collection('notifications').add({
      'shopId': shopId, 'message': message, 'type': type, 'isRead': false, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getNotifications(String shopId) {
    return _db.collection('notifications').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  Stream<QuerySnapshot> getDebtSales(String shopId, {String? branchId}) {
    var query = _db.collection('sales').where('shopId', isEqualTo: shopId).where('isDebt', isEqualTo: true);
    if (branchId != null) query = query.where('branchId', isEqualTo: branchId);
    return query.snapshots().toMainThread();
  }

  Stream<QuerySnapshot> getAuditLogs(String shopId) {
    return _db.collection('audit_logs').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  Stream<QuerySnapshot> getUsers(String shopId) {
    return _db.collection('users').where('shopId', isEqualTo: shopId).snapshots().toMainThread();
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('users').doc(userId).delete();
  }

  Future<void> fullFactoryReset(String shopId) async {
    final collections = ['items', 'sales', 'suppliers', 'purchases', 'audit_logs', 'notifications', 'deletion_requests'];
    final batch = _db.batch();
    for (var col in collections) {
      final snap = await _db.collection(col).where('shopId', isEqualTo: shopId).get();
      for (var doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
    await _offline.factoryReset();
  }
}
