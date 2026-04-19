import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DatabaseService _offline = DatabaseService();
  final _uuid = const Uuid();

  // --- SYNC LOGIC ---
  Future<void> syncAll(String shopId) async {
    // 1. Push Local -> Firestore
    final tables = ['products', 'sales', 'suppliers', 'purchases', 'audit_logs'];
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
    // 2. Pull Firestore -> Local
    await pullChanges(shopId);
  }

  Future<void> pullChanges(String shopId) async {
    final tables = ['items', 'sales', 'suppliers', 'purchases'];
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
            final sqlData = Map<String, dynamic>.from(remoteData);
            sqlData['isSynced'] = 1; 
            if (table == 'items') {
              await _offline.saveProduct(sqlData);
            } else if (table == 'sales') {
              await _offline.saveSale(sqlData);
            } else if (table == 'purchases') {
              await _offline.savePurchase(sqlData);
            }
          }
        }
      } catch (e) {
        debugPrint("Pull Sync Error for $table: $e");
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
    return _db.collection('branches').where('shopId', isEqualTo: shopId).snapshots();
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
    var nameMatch = await _db.collection('items')
        .where('shopId', isEqualTo: shopId)
        .where('name', isEqualTo: data['name'])
        .get();
    if (nameMatch.docs.isNotEmpty) throw Exception('Item already exists in inventory (Name Match).');

    if (barcode.isNotEmpty) {
      var barcodeMatch = await _db.collection('items')
          .where('shopId', isEqualTo: shopId)
          .where('barcode', isEqualTo: barcode)
          .get();
      if (barcodeMatch.docs.isNotEmpty) throw Exception('Item already exists in inventory (Barcode Match).');
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

    await _offline.saveProduct(productData);
    
    try {
      await _db.collection('items').doc(id).set(productData);
      await _offline.markSynced('products', id);
    } catch (e) {
      print("Firestore Add Item Error (cached locally): $e");
    }

    if (addedBy != null && data.containsKey('shopId')) {
      await recordAuditLog(data['shopId'], addedBy, 'ADD_ITEM', 'Added ${data['name']}');
    }
  }

  Stream<QuerySnapshot> getInventory(String shopId) {
    return _db.collection('items').where('shopId', isEqualTo: shopId).snapshots();
  }

  Future<void> updateItem(String id, Map<String, dynamic> data, {String? updatedBy}) async {
    final updateData = {
      ...data,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await _offline.saveProduct({...updateData, 'id': id});

    try {
      await _db.collection('items').doc(id).update(updateData);
      await _offline.markSynced('products', id);
    } catch (e) {
      print("Firestore Update Item Error: $e");
    }
  }

  // --- SALES ACTIONS ---
  Future<void> recordSale(Map<String, dynamic> saleData) async {
    final id = saleData['id'] ?? _uuid.v4();
    final finalSaleData = {
      ...saleData,
      'id': id,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _offline.saveSale(finalSaleData);

    try {
      await _db.collection('sales').doc(id).set(finalSaleData);
      await _offline.markSynced('sales', id);
    } catch (_) {}

    final itemId = saleData['itemId'];
    final soldQtyRaw = saleData['quantity'] ?? 0;
    if (itemId != null) {
      final doc = await _db.collection('items').doc(itemId).get();
      if (doc.exists) {
        final currentQty = (doc.data() as Map)['quantity'] ?? 0;
        await updateItem(itemId, {'quantity': currentQty - soldQtyRaw});
      }
    }
    await recordAuditLog(saleData['shopId'], saleData['username'] ?? 'system', 'SALE', 'Sold $soldQtyRaw of ${saleData['itemName']}');
  }

  Stream<QuerySnapshot> getSales(String shopId) {
    return _db.collection('sales').where('shopId', isEqualTo: shopId).snapshots();
  }

  // --- PURCHASE ACTIONS ---
  Future<void> recordPurchase(Map<String, dynamic> purchaseData) async {
    final id = purchaseData['id'] ?? _uuid.v4();
    final finalPurchaseData = {
      ...purchaseData,
      'id': id,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _offline.savePurchase(finalPurchaseData);

    try {
      await _db.collection('purchases').doc(id).set(finalPurchaseData);
      await _offline.markSynced('purchases', id);
    } catch (_) {}

    final itemId = purchaseData['itemId'];
    if (itemId != null) {
      final doc = await _db.collection('items').doc(itemId).get();
      if (doc.exists) {
        final currentQty = (doc.data() as Map)['quantity'] ?? 0;
        final addQty = purchaseData['quantity'] ?? 0;
        final updateMap = {
          'quantity': currentQty + addQty,
          'buyingPrice': purchaseData['unitCost'],
          'batchNumber': purchaseData['batchNumber'],
        };
        if (purchaseData['expiryDate'] != null) updateMap['expiryDate'] = purchaseData['expiryDate'];
        await updateItem(itemId, updateMap);
      }
    }
    await recordAuditLog(purchaseData['shopId'], purchaseData['username'] ?? 'system', 'PURCHASE', 'Inventory Intake: ${purchaseData['quantity']} units');
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
    return _db.collection('suppliers').where('shopId', isEqualTo: shopId).snapshots();
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
    await _offline.saveAuditLog(logData);
    try {
      await _db.collection('audit_logs').doc(logData['id'] as String).set(logData);
      await _offline.markSynced('audit_logs', logData['id'] as String);
    } catch (_) {}
  }

  Future<void> clearAllData(String shopId) async {
    final collections = ['items', 'sales', 'suppliers', 'purchases', 'audit_logs', 'notifications'];
    for (var col in collections) {
      final snap = await _db.collection(col).where('shopId', isEqualTo: shopId).get();
      for (var doc in snap.docs) await doc.reference.delete();
    }
  }

  Future<void> addNotification(String shopId, String message, String type) async {
    await _db.collection('notifications').add({
      'shopId': shopId, 'message': message, 'type': type, 'isRead': false, 'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
