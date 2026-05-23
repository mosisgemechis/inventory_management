import 'dart:convert';
import '../db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'sync/device_id_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  
  late final AppDatabase _db;
  AppDatabase get db => _db;
  final _uuid = const Uuid();

  // --- DAOs ---
  late final ProductsDao productsDao;
  late final SalesDao salesDao;
  late final DebtsDao debtsDao;
  late final UsersDao usersDao;
  late final MovementsDao movementsDao;
  late final SyncOutboxDao syncOutboxDao;
  
  DatabaseService._internal() {
    _db = AppDatabase();
    productsDao = ProductsDao(_db);
    salesDao = SalesDao(_db);
    debtsDao = DebtsDao(_db);
    usersDao = UsersDao(_db);
    movementsDao = MovementsDao(_db);
    syncOutboxDao = SyncOutboxDao(_db);
  }

  // --- GENERIC METHODS ---

  Future<void> runTransaction(Future<void> Function() action) async {
    await _db.transaction(action);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs, String? orderBy, int? limit}) async {
    // Basic dynamic query wrapper for legacy support
    // In production we should use DAOs, but for fixing logic fast:
    if (table == 'users') {
      var query = _db.select(_db.users);
      if (where != null && whereArgs != null && whereArgs.length >= 2) {
        final val1 = whereArgs[0].toString();
        final val2 = whereArgs[1].toString();
        query..where((t) => t.username.lower().equals(val1.toLowerCase()) | t.email.lower().equals(val2.toLowerCase()));
      }
      final res = await query.get();
      return res.map((r) => {
        'uid': r.uid,
        'email': r.email,
        'username': r.username,
        'roles': r.roles.split(';'),
        'shopId': r.shopId,
        'branchId': r.branchId,
        'branchName': r.branchName,
        'fullName': r.fullName,
        'currency': r.currency,
        'permissions': r.permissions,
        'passwordHash': r.passwordHash,
        'isActive': r.isActive,
      }).toList();
    } 
    
    if (table == 'products' || table == 'items') {
      var query = _db.select(_db.products);
      if (where != null && (where.contains('id = ?') || where.contains('id='))) {
        query.where((t) => t.id.equals(whereArgs![0].toString()));
      } else if (whereArgs != null && whereArgs.isNotEmpty) {
        query.where((t) {
          var expression = t.shopId.equals(whereArgs[0].toString());
          
          // Enhanced dynamic parsing for different query patterns
          if (whereArgs.length >= 2) {
            final arg1 = whereArgs[1].toString();
            if (where != null && (where.contains('name = ? OR barcode = ?') || where.contains('name = ? AND barcode = ?'))) {
               // Use lower() for name matching to prevent duplicates due to case mismatch
               expression = expression & (t.name.lower().equals(arg1.toLowerCase()) | t.barcode.equals(whereArgs[2].toString()));
            } else if (where != null && where.contains('barcode = ?')) {
               expression = expression & t.barcode.equals(arg1);
            } else {
               expression = expression & t.name.lower().equals(arg1.toLowerCase());
            }
          }

          // Branch filtering
          String? bVal;
          if (where != null && where.contains('branch_id = ?')) {
             // Try to find branch_id in whereArgs by matching its position in where string
             // This is brittle but works for current Repo patterns
             if (whereArgs.length >= 4) bVal = whereArgs[3].toString();
             else if (whereArgs.length >= 3) bVal = whereArgs[2].toString();
          }

          if (bVal != null) {
            if (bVal == 'all') {
               // No branch filter
            } else if (bVal == 'main') {
               expression = expression & (t.branchId.equals('main') | t.branchId.isNull());
            } else {
               expression = expression & t.branchId.equals(bVal);
            }
          }
          
          return expression;
        });
      }
      final res = await query.get();
      return res.map((r) => _productToMap(r)).toList();
    }

    if (table == 'batches') {
      var query = _db.select(_db.batches);
      if (where != null && (where.contains('branch_id = ?') || where.contains('branch_id IS NULL'))) {
         query.where((t) {
            final shopMatch = t.shopId.equals(whereArgs![0].toString());
            final itemMatch = t.itemId.equals(whereArgs[1].toString());
            
            Expression<bool> branchMatch;
            final String branchVal = whereArgs[2]?.toString() ?? 'main';
            if (whereArgs.length >= 4 && branchVal == 'main') {
                branchMatch = t.branchId.equals('main') | t.branchId.isNull();
            } else {
                branchMatch = t.branchId.equals(branchVal);
            }
            return shopMatch & itemMatch & branchMatch;
         });
      } else if (whereArgs != null && whereArgs.length >= 2) {
        query.where((t) => t.shopId.equals(whereArgs[0].toString()) & t.itemId.equals(whereArgs[1].toString()));
      }
      final res = await query.get();
      return res.map((r) => {
        'id': r.id,
        'shopId': r.shopId,
        'itemId': r.itemId,
        'quantity': r.quantity,
        'buyingPrice': r.buyingPrice,
        'expiryDate': r.expiryDate?.toIso8601String(),
        'batchNumber': r.batchNumber,
        'timestamp': r.timestamp.toIso8601String(),
        'branchId': r.branchId,
      }).toList();
    }

    if (table == 'subscriptions') {
      var q = _db.select(_db.subscriptions);
      if (whereArgs != null && whereArgs.isNotEmpty) {
        q.where((t) => t.shopId.equals(whereArgs[0].toString()));
      }
      if (where != null && where.contains('activationDate DESC')) {
        q.orderBy([(t) => OrderingTerm(expression: t.activationDate, mode: OrderingMode.desc)]);
      }
      final res = await q.get();
      return res.map((r) => {
        'shopId': r.shopId,
        'plan': r.plan,
        'activationDate': r.activationDate.toIso8601String(),
        'expiryDate': r.expiryDate.toIso8601String(),
        'addOns': r.addOns,
        'isTrial': r.isTrial,
        'userLimit': r.userLimit,
        'branchLimit': r.branchLimit,
      }).toList();
    }

    if (table == 'sales') {
      var q = _db.select(_db.sales);
      if (whereArgs != null && whereArgs.isNotEmpty) {
        q.where((t) => t.shopId.equals(whereArgs[0].toString()));
      }
      final res = await q.get();
      return res.map((r) => _saleToMap(r)).toList();
    }

    return [];
  }
  
  Future<void> ensureInitialized() async {
    // Drift initializes lazily on first access, so we just trigger a simple query
    try {
      await _db.customSelect('SELECT 1').getSingle();
    } catch (e) {
      debugPrint("DB Init Error: $e");
    }
  }

  Future<String> _activeUserId() async =>
      (await getSetting('active_user_id'))?.trim().isNotEmpty == true
          ? (await getSetting('active_user_id'))!.trim()
          : 'unknown';

  Future<void> _enqueueOutbox({
    required String shopId,
    required String branchId,
    required String table,
    required String recordId,
    required String operation,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final deviceId = await DeviceIdService.getOrCreate();
      final userId = await _activeUserId();
      await syncOutboxDao.enqueue(
        id: _uuid.v4(),
        shopId: shopId,
        branchId: branchId,
        deviceId: deviceId,
        userId: userId,
        tableName: table,
        recordId: recordId,
        operation: operation,
        payloadJson: payload == null ? null : jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('Outbox enqueue failed: $e');
    }
  }

  // --- BULK OPERATIONS ---

  Future<void> bulkInsertProducts(List<Product> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db.into(_db.products).insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // Legacy wrappers for backward compatibility with UI
  // --- PRODUCT METHODS ---

  DateTime? _toDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is int) {
      if (val < 10000000000) return DateTime.fromMillisecondsSinceEpoch(val * 1000);
      return DateTime.fromMillisecondsSinceEpoch(val);
    }
    if (val is String && val.isNotEmpty) return DateTime.tryParse(val);
    return null;
  }

  Future<void> saveProduct(Map<String, dynamic> data) async {
    final shopId = data['shopId']?.toString() ?? '';
    final branchId = data['branchId']?.toString() ?? 'main';
    final entry = ProductsCompanion.insert(
      id: data['id'] ?? data['name'], // Fallback if missing
      shopId: shopId,
      branchId: branchId,
      name: data['name'],
      barcode: Value(data['barcode'] ?? ''),
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      buyingPrice: (data['buyingPrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: Value((data['lowStockThreshold'] as num?)?.toInt() ?? 5),
      expiryDate: Value(_toDateTime(data['expiryDate'])),
      batchNumber: Value(data['batchNumber']?.toString()),
      imageUrl: Value(data['imageUrl']?.toString()),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
    );
    await _db.into(_db.products).insertOnConflictUpdate(entry);

    final recordId = (data['id'] ?? data['name']).toString();
    await _enqueueOutbox(
      shopId: shopId,
      branchId: branchId,
      table: 'products',
      recordId: recordId,
      operation: 'upsert',
      payload: {...data, 'id': recordId, 'shopId': shopId, 'branchId': branchId},
    );
  }

  Future<List<Map<String, dynamic>>> getAllProducts(String shopId) async {
    final res = await (_db.select(_db.products)..where((t) => t.shopId.equals(shopId))).get();
    return res.map((row) => _productToMap(row)).toList();
  }

  Future<List<Map<String, dynamic>>> searchItems(String shopId, String name, String barcode, {String? branchId}) async {
    final query = _db.select(_db.products)..where((t) {
      final nameMatch = t.name.equals(name.trim());
      final barcodeMatch = barcode.trim().isNotEmpty ? t.barcode.equals(barcode.trim()) : const Constant(false);
      final shopMatch = t.shopId.equals(shopId);
      
      Expression<bool> branchMatch;
      if (branchId != null) {
        if (branchId == 'main') {
           branchMatch = t.branchId.equals('main') | t.branchId.isNull();
        } else {
           branchMatch = t.branchId.equals(branchId);
        }
      } else {
        branchMatch = const Constant(true);
      }
      
      return shopMatch & branchMatch & (nameMatch | barcodeMatch);
    });
    
    final res = await query.get();
    return res.map((row) => _productToMap(row)).toList();
  }

  // --- SALE METHODS ---

  Future<void> saveSale(Map<String, dynamic> data) async {
    final shopId = data['shopId']?.toString() ?? '';
    final branchId = data['branchId']?.toString() ?? 'main';
    final recordId = (data['id']?.toString().trim().isNotEmpty == true)
        ? data['id'].toString()
        : _uuid.v4();
    final entry = SalesCompanion.insert(
      id: recordId,
      shopId: shopId,
      branchId: branchId,
      itemId: data['itemId'],
      itemName: data['itemName'],
      quantity: (data['quantity'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      profit: (data['profit'] as num?)?.toDouble() ?? 0.0,
      userId: data['userId'] ?? 'unknown',
      username: data['username'] ?? 'unknown',
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ?? DateTime.now(),
      customerName: Value(data['customerName']?.toString()),
      isDebt: Value(data['isDebt'] == true || data['isDebt'] == 1),
      amountPaid: Value((data['amountPaid'] as num?)?.toDouble() ?? 0.0),
      debtRemaining: Value((data['debtRemaining'] as num?)?.toDouble() ?? 0.0),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
    );
    await _db.into(_db.sales).insertOnConflictUpdate(entry);

    await _enqueueOutbox(
      shopId: shopId,
      branchId: branchId,
      table: 'sales',
      recordId: recordId,
      operation: 'upsert',
      payload: {...data, 'id': recordId, 'shopId': shopId, 'branchId': branchId},
    );
  }

  // --- AUTH METHODS ---


  Future<void> cacheUser(Map<String, dynamic> data) async {
    await saveUserRecord(data);
    await saveSetting('active_user_id', data['uid'] ?? data['id'] ?? '');
    final shopId = (data['shopId'] ?? '').toString();
    if (shopId.isNotEmpty) {
      await saveSetting('active_shop_id', shopId);
    }
    final branchId = (data['branchId'] ?? '').toString();
    if (branchId.isNotEmpty) {
      await saveSetting('active_branch_id', branchId);
    }
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final activeId = await getSetting('active_user_id');
    if (activeId == null || activeId.isEmpty) return null;

    final res = await (_db.select(_db.users)..where((t) => t.uid.equals(activeId))).get();
    if (res.isEmpty) return null;
    final row = res.first;
    // Load currency from settings as well to be sure
    final currency = await getSetting('currency') ?? 'USD';
    
    return {
      'uid': row.uid,
      'email': row.email,
      'roles': row.roles.split(';'),
      'shopId': row.shopId,
      'username': row.username,
      'branchId': row.branchId,
      'branchName': row.branchName,
      'permissions': row.permissions,
      'passwordHash': row.passwordHash,
      'currency': currency,
      'isActive': row.isActive,
    };
  }

  Future<void> clearCachedUser() async {
    await saveSetting('active_user_id', '');
  }

  // --- APP SETTINGS METHODS ---

  Future<void> saveSetting(String key, String value) async {
    final entry = AppSettingsCompanion.insert(key: key, value: value);
    await _db.into(_db.appSettings).insertOnConflictUpdate(entry);
  }

  Future<String?> getSetting(String key) async {
    final res = await (_db.select(_db.appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return res?.value;
  }

  // --- BRANCH METHODS ---
  Future<void> saveBranch(Map<String, dynamic> data) async {
    final shopId = data['shopId']?.toString() ?? '';
    final recordId = data['id']?.toString().trim().isNotEmpty == true
        ? data['id'].toString()
        : _uuid.v4();
    final entry = BranchesCompanion.insert(
      id: recordId,
      shopId: shopId,
      name: data['name'],
      createdAt: DateTime.now(),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
    );
    await _db.into(_db.branches).insertOnConflictUpdate(entry);

    await _enqueueOutbox(
      shopId: shopId,
      branchId: 'main',
      table: 'branches',
      recordId: recordId,
      operation: 'upsert',
      payload: {...data, 'id': recordId, 'shopId': shopId},
    );
  }

  Future<List<Map<String, dynamic>>> getBranches(String shopId) async {
    final res = await (_db.select(_db.branches)..where((t) => t.shopId.equals(shopId))).get();
    final mapped = res.map<Map<String, dynamic>>((r) => {'id': r.id, 'name': r.name, 'shopId': r.shopId}).toList();
    if (!mapped.any((m) => m['id'] == 'main')) {
      mapped.insert(0, {'id': 'main', 'name': 'Main Branch', 'shopId': shopId});
    }
    return mapped;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    final entry = UsersCompanion(
      uid: Value(uid),
      username: data['username'] != null ? Value(data['username'] as String) : const Value.absent(),
      roles: data['roles'] != null ? Value((data['roles'] as List).join(';')) : const Value.absent(),
      permissions: data['permissions'] != null 
          ? Value(data['permissions'] is String ? data['permissions'] : jsonEncode(data['permissions'])) 
          : const Value.absent(),
      branchId: data['branchId'] != null ? Value(data['branchId'] as String) : const Value.absent(),
      branchName: data['branchName'] != null ? Value(data['branchName'] as String) : const Value.absent(),
      isActive: data['isActive'] != null ? Value(data['isActive'] == true) : const Value.absent(),
    );
    await (_db.update(_db.users)..where((t) => t.uid.equals(uid))).write(entry);
  }

  // --- MAPPING HELPERS ---

  Map<String, dynamic> _productToMap(Product row) {
    return {
      'id': row.id,
      'shopId': row.shopId,
      'branchId': row.branchId,
      'name': row.name,
      'barcode': row.barcode,
      'quantity': row.quantity,
      'buyingPrice': row.buyingPrice,
      'sellingPrice': row.sellingPrice,
      'lowStockThreshold': row.lowStockThreshold,
      'expiryDate': row.expiryDate?.toIso8601String(),
      'batchNumber': row.batchNumber,
      'imageUrl': row.imageUrl,
      'syncStatus': row.syncStatus,
      'lastModified': row.lastModified.toIso8601String(),
    };
  }

  Map<String, dynamic> _saleToMap(Sale row) {
    return {
      'id': row.id,
      'shopId': row.shopId,
      'branchId': row.branchId,
      'itemId': row.itemId,
      'itemName': row.itemName,
      'quantity': row.quantity,
      'totalPrice': row.totalPrice,
      'profit': row.profit,
      'userId': row.userId,
      'username': row.username,
      'timestamp': row.timestamp.toIso8601String(),
      'customerName': row.customerName,
      'isDebt': row.isDebt,
      'amountPaid': row.amountPaid,
      'debtRemaining': row.debtRemaining,
    };
  }


  Map<String, dynamic> _purchaseToMap(Purchase row) {
    return {
      'id': row.id,
      'shopId': row.shopId,
      'itemId': row.itemId,
      'itemName': row.itemName,
      'barcode': row.barcode,
      'quantity': row.quantity,
      'unitCost': row.unitCost,
      'totalCost': row.totalCost,
      'supplierName': row.supplierName,
      'batchNumber': row.batchNumber,
      'branchId': row.branchId,
      'expiryDate': row.expiryDate?.toIso8601String(),
      'timestamp': row.timestamp.toIso8601String(),
    };
  }


  // --- WATCH METHODS (LOCAL-FIRST REACTIVITY) ---

  Stream<List<Map<String, dynamic>>> watchProducts(String shopId, {String? branchId}) {
    final query = _db.select(_db.products)
      ..where((t) => t.shopId.equals(shopId) & t.syncStatus.isNotIn(const ['pendingDelete']));
    if (branchId != null && branchId != "all" && branchId.isNotEmpty) {
       if (branchId == 'main') {
         query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
       } else {
         query.where((t) => t.branchId.equals(branchId));
       }
    }
    return query.watch().map((rows) => rows.map<Map<String, dynamic>>((r) => _productToMap(r)).toList());
  }


  Stream<List<Map<String, dynamic>>> watchSales(String shopId, {String? branchId}) {
    final query = _db.select(_db.sales)
      ..where((t) => t.shopId.equals(shopId) & t.syncStatus.isNotIn(const ['pendingDelete']));
    if (branchId != null && branchId != "all" && branchId.isNotEmpty) {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    return query.watch().map((rows) => rows.map<Map<String, dynamic>>((r) => _saleToMap(r)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchPurchases(String shopId, {String? branchId}) {
     final query = _db.select(_db.purchases)
       ..where((t) => t.shopId.equals(shopId) & t.syncStatus.isNotIn(const ['pendingDelete']));
     if (branchId != null && branchId != 'all' && branchId.isNotEmpty) {
       if (branchId == 'main') {
         query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
       } else {
         query.where((t) => t.branchId.equals(branchId));
       }
     }
     return query.watch().map((rows) => rows.map<Map<String, dynamic>>((r) => _purchaseToMap(r)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchBranches(String shopId) {
    return (_db.select(_db.branches)
          ..where((t) => t.shopId.equals(shopId) & t.syncStatus.isNotIn(const ['pendingDelete'])))
        .watch()
        .map((rows) {
          final mapped = rows.map<Map<String, dynamic>>((r) => {'id': r.id, 'name': r.name, 'shopId': r.shopId}).toList();
          if (!mapped.any((m) => m['id'] == 'main')) {
            mapped.insert(0, {'id': 'main', 'name': 'Main Branch', 'shopId': shopId});
          }
          return mapped;
        });
  }

  Future<bool> isUsernameTaken(String username) async {
    final res = await (_db.select(_db.users)..where((t) => t.username.equals(username.toLowerCase().trim()))).get();
    return res.isNotEmpty;
  }

  Stream<List<Map<String, dynamic>>> watchUsers(String shopId) {
    return (_db.select(_db.users)..where((t) => t.shopId.equals(shopId)))
        .watch()
        .map((rows) => rows.map((r) => {
          'uid': r.uid,
          'username': r.username,
          'email': r.email,
          'roles': r.roles.split(';'),
          'permissions': r.permissions,
          'branchId': r.branchId,
          'isActive': r.isActive ?? true,
        }).toList());
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs(String shopId, {String? branchId}) {
    final query = _db.select(_db.auditLogs)..where((t) => t.shopId.equals(shopId));
    if (branchId != null && branchId != 'all') {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    query.orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]);
    
    return query.watch().map((rows) => rows.map((r) => {
        'id': r.id,
        'action': r.action,
        'details': r.details,
        'username': r.username,
        'timestamp': r.timestamp.toIso8601String(),
        'branchId': r.branchId,
      }).toList());
  }

  Future<void> recordAuditLog(String shopId, String username, String action, String details, {String branchId = 'main'}) async {
    final entry = AuditLogsCompanion.insert(
      id: _uuid.v4(),
      shopId: shopId,
      username: username,
      action: action,
      details: details,
      timestamp: DateTime.now(),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
      branchId: Value(branchId),
    );
    await _db.into(_db.auditLogs).insert(entry);

    await _enqueueOutbox(
      shopId: shopId,
      branchId: branchId,
      table: 'audit_logs',
      recordId: entry.id.value,
      operation: 'upsert',
      payload: {
        'id': entry.id.value,
        'shopId': shopId,
        'branchId': branchId,
        'username': username,
        'action': action,
        'details': details,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> addNotification(Map<String, dynamic> data) async {
    final entry = NotificationsCompanion.insert(
      id: data['id'] ?? _uuid.v4(),
      shopId: data['shopId'],
      title: data['title'] ?? 'System Alert',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      targetRole: Value(data['targetRole']?.toString()),
      itemId: Value(data['itemId']?.toString()),
      timestamp: Value(DateTime.now()),
    );
    await _db.into(_db.notifications).insert(entry, mode: InsertMode.insertOrReplace);
    debugPrint('[DRIFT NOTIFICATION] ${data['title']}: ${data['message']}');
  }

  Stream<List<Map<String, dynamic>>> watchNotifications(String shopId) {
    return (_db.select(_db.notifications)..where((t) => t.shopId.equals(shopId))
      ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)]))
      .watch()
      .map((rows) => rows.map((r) => {
        'id': r.id,
        'title': r.title,
        'message': r.message,
        'type': r.type,
        'itemId': r.itemId,
        'isRead': r.isRead,
        'timestamp': r.timestamp.toIso8601String(),
      }).toList());
  }

  Future<void> markNotificationAsRead(String id) async {
    await (_db.update(_db.notifications)..where((t) => t.id.equals(id)))
        .write(const NotificationsCompanion(isRead: Value(true)));
  }

  Future<void> notify(String shopId, String message, String type) async {
     await addNotification({
       'shopId': shopId,
       'title': 'System Notification',
       'message': message,
       'type': type,
     });
  }

  Future<void> update(String table, String id, Map<String, dynamic> data) async {
    if (table == 'products' || table == 'items') {
      final entry = ProductsCompanion(
        quantity: data['quantity'] != null ? Value((data['quantity'] as num).toDouble()) : const Value.absent(),
        name: data['name'] != null ? Value(data['name'] as String) : const Value.absent(),
        buyingPrice: data['buyingPrice'] != null ? Value((data['buyingPrice'] as num).toDouble()) : const Value.absent(),
        sellingPrice: data['sellingPrice'] != null ? Value((data['sellingPrice'] as num).toDouble()) : const Value.absent(),
        expiryDate: data['expiryDate'] != null ? Value(DateTime.tryParse(data['expiryDate'].toString())) : const Value.absent(),
        lastModified: Value(DateTime.now()),
      );
      await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(entry);
    } else if (table == 'batches') {
      final entry = BatchesCompanion(
        quantity: data['quantity'] != null ? Value((data['quantity'] as num).toDouble()) : const Value.absent(),
        buyingPrice: data['buyingPrice'] != null ? Value((data['buyingPrice'] as num).toDouble()) : const Value.absent(),
        expiryDate: data['expiryDate'] != null ? Value(DateTime.tryParse(data['expiryDate'].toString())) : const Value.absent(),
        lastModified: Value(DateTime.now()),
      );
      await (_db.update(_db.batches)..where((t) => t.id.equals(id))).write(entry);
    } else if (table == 'sales') {
      final entry = SalesCompanion(
        debtRemaining: data['debtRemaining'] != null ? Value((data['debtRemaining'] as num).toDouble()) : const Value.absent(),
        amountPaid: data['amountPaid'] != null ? Value((data['amountPaid'] as num).toDouble()) : const Value.absent(),
        isDebt: data['isDebt'] != null ? Value(data['isDebt'] == true || data['isDebt'] == 1) : const Value.absent(),
        lastModified: Value(DateTime.now()),
      );
      await (_db.update(_db.sales)..where((t) => t.id.equals(id))).write(entry);
    } else if (table == 'purchases') {
       final entry = PurchasesCompanion(
         supplierName: data['supplierName'] != null ? Value(data['supplierName'] as String) : const Value.absent(),
         unitCost: data['unitCost'] != null ? Value((data['unitCost'] as num).toDouble()) : const Value.absent(),
         totalCost: data['totalCost'] != null ? Value((data['totalCost'] as num).toDouble()) : const Value.absent(),
       );
       await (_db.update(_db.purchases)..where((t) => t.id.equals(id))).write(entry);
    }
  }

  Future<void> saveUserRecord(Map<String, dynamic> data) async {
    final String? uid = data['uid']?.toString() ?? data['id']?.toString();
    if (uid == null) return;

    final String roles = data['roles'] is List
        ? (data['roles'] as List).join(';')
        : (data['roles']?.toString() ?? 'staff');

    final entry = UsersCompanion.insert(
      uid: uid,
      email: data['email']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      fullName: Value(data['fullName']?.toString() ?? ''),
      roles: roles,
      shopId: data['shopId']?.toString() ?? 'default_shop',
      branchId: Value(data['branchId']?.toString() ?? 'main'),
      branchName: Value(data['branchName']?.toString() ?? 'Main Branch'),
      currency: Value(data['currency']?.toString() ?? 'USD'),
      permissions: Value(data['permissions'] is Map
          ? jsonEncode(data['permissions'])
          : data['permissions']?.toString()),
      passwordHash: Value(data['passwordHash']?.toString()),
      isActive: Value(data['isActive'] == true || data['isActive'] == 1),
    );
    await _db.into(_db.users).insertOnConflictUpdate(entry);
  }

  // --- CRUD HELPERS ---

  Future<void> deleteShopAndAccount(String shopId) async {
    await (_db.delete(_db.products)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.sales)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.suppliers)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.purchases)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.batches)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.auditLogs)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.users)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.branches)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.notifications)..where((t) => t.shopId.equals(shopId))).go();
    await (_db.delete(_db.subscriptions)..where((t) => t.shopId.equals(shopId))).go();
  }

  Future<void> saveSubscription(Map<String, dynamic> data) async {
    final entry = SubscriptionsCompanion.insert(
      shopId: data['shopId'],
      plan: data['plan'],
      activationDate: DateTime.parse(data['activationDate']),
      expiryDate: DateTime.parse(data['expiryDate']),
      addOns: Value(data['addOns']?.toString()),
      isTrial: Value(data['isTrial'] == true || data['isTrial'] == 1),
      userLimit: Value(data['userLimit'] ?? 3),
      branchLimit: Value(data['branchLimit'] ?? 1),
    );
    await _db.into(_db.subscriptions).insertOnConflictUpdate(entry);
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (table == 'subscriptions') {
      await saveSubscription(data);
      return 1;
    }
    if (table == 'products' || table == 'items') {
      await saveProduct(data);
      return 1;
    } else if (table == 'sales') {
      await saveSale(data);
      return 1;
    } else if (table == 'users') {
      await saveUserRecord(data);
      return 1;
    } else if (table == 'batches') {
      await saveBatchRecord(data);
      return 1;
    } else if (table == 'purchases') {
      await savePurchase(data);
      return 1;
    } else if (table == 'audit_logs') {
      await recordAuditLog(
        data['shopId'], 
        data['username'], 
        data['action'], 
        data['details'], 
        branchId: data['branchId'] ?? 'main'
      );
      return 1;
    }
    return 0;
  }

  Future<void> saveBatchRecord(Map<String, dynamic> data) async {
      final shopId = data['shopId']?.toString() ?? '';
      final branchId = data['branchId']?.toString() ?? 'main';
      final recordId = data['id']?.toString().trim().isNotEmpty == true
          ? data['id'].toString()
          : _uuid.v4();
      final rawExp = data['expiryDate'];
      DateTime? expiry;
      if (rawExp is DateTime) expiry = rawExp;
      else if (rawExp is String) expiry = DateTime.tryParse(rawExp);
      
      final entry = BatchesCompanion.insert(
        id: recordId,
        shopId: shopId,
        itemId: data['itemId'],
        quantity: (data['quantity'] as num).toDouble(),
        buyingPrice: (data['buyingPrice'] as num).toDouble(),
        expiryDate: Value(expiry),
        batchNumber: Value(data['batchNumber']?.toString()),
        timestamp: DateTime.now(),
         syncStatus: const Value('pendingUpload'),
         lastModified: Value(DateTime.now().toUtc()),
        branchId: Value(branchId),
      );
      await _db.into(_db.batches).insert(entry, mode: InsertMode.insertOrReplace);

      await _enqueueOutbox(
        shopId: shopId,
        branchId: branchId,
        table: 'batches',
        recordId: recordId,
        operation: 'upsert',
        payload: {
          ...data,
          'id': recordId,
          'shopId': shopId,
          'branchId': branchId,
          'expiryDate': expiry?.toUtc().toIso8601String(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
  }

  Future<void> savePurchase(Map<String, dynamic> data) async {
      final shopId = data['shopId']?.toString() ?? '';
      final branchId = data['branchId']?.toString() ?? 'main';
      final recordId = data['id']?.toString().trim().isNotEmpty == true
          ? data['id'].toString()
          : _uuid.v4();
      final rawExp = data['expiryDate'];
      DateTime? expiry;
      if (rawExp is DateTime) expiry = rawExp;
      else if (rawExp is String) expiry = DateTime.tryParse(rawExp);

      final entry = PurchasesCompanion.insert(
        id: recordId,
        shopId: shopId,
        itemId: data['itemId'],
        itemName: data['itemName'] ?? '',
        barcode: Value(data['barcode']?.toString() ?? ''),
        quantity: (data['quantity'] as num).toDouble(),
        unitCost: (data['unitCost'] as num).toDouble(),
        totalCost: (data['totalCost'] as num).toDouble(),
        supplierName: Value(data['supplierName']?.toString()),
        expiryDate: Value(expiry),
        timestamp: DateTime.now(),
         syncStatus: const Value('pendingUpload'),
         lastModified: Value(DateTime.now().toUtc()),
        branchId: Value(branchId),
      );
      await _db.into(_db.purchases).insert(entry, mode: InsertMode.insertOrReplace);

      await _enqueueOutbox(
        shopId: shopId,
        branchId: branchId,
        table: 'purchases',
        recordId: recordId,
        operation: 'upsert',
        payload: {
          ...data,
          'id': recordId,
          'shopId': shopId,
          'branchId': branchId,
          'expiryDate': expiry?.toUtc().toIso8601String(),
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
  }

  Future<void> delete(String table, String id) async {
    if (table == 'products' || table == 'items') {
      final row = await (_db.select(_db.products)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
        ProductsCompanion(
          syncStatus: const Value('pendingDelete'),
          lastModified: Value(DateTime.now().toUtc()),
        ),
      );
      await _enqueueOutbox(
        shopId: row.shopId,
        branchId: row.branchId,
        table: 'products',
        recordId: id,
        operation: 'delete',
        payload: {'id': id, 'shopId': row.shopId, 'branchId': row.branchId},
      );
    } else if (table == 'users') {
      await (_db.delete(_db.users)..where((t) => t.uid.equals(id))).go();
    } else if (table == 'branches') {
      final row = await (_db.select(_db.branches)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.branches)..where((t) => t.id.equals(id))).write(
        BranchesCompanion(
          syncStatus: const Value('pendingDelete'),
          lastModified: Value(DateTime.now().toUtc()),
        ),
      );
      await _enqueueOutbox(
        shopId: row.shopId,
        branchId: 'main',
        table: 'branches',
        recordId: id,
        operation: 'delete',
        payload: {'id': id, 'shopId': row.shopId},
      );
    }
  }

  Future<void> deleteMultiple(String table, List<String> ids) async {
    if (table == 'products' || table == 'items') {
      final rows = await (_db.select(_db.products)..where((t) => t.id.isIn(ids))).get();
      for (final r in rows) {
        await (_db.update(_db.products)..where((t) => t.id.equals(r.id))).write(
          ProductsCompanion(
            syncStatus: const Value('pendingDelete'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        await _enqueueOutbox(
          shopId: r.shopId,
          branchId: r.branchId,
          table: 'products',
          recordId: r.id,
          operation: 'delete',
          payload: {'id': r.id, 'shopId': r.shopId, 'branchId': r.branchId},
        );
      }
    }
  }

  Future<void> clearAllAuditLogs(String shopId) async {
    await (_db.delete(_db.auditLogs)..where((t) => t.shopId.equals(shopId))).go();
  }

  Future<void> factoryReset() async {
    await _db.transaction(() async {
      await _db.delete(_db.products).go();
      await _db.delete(_db.sales).go();
      await _db.delete(_db.suppliers).go();
      await _db.delete(_db.purchases).go();
      await _db.delete(_db.batches).go();
      await _db.delete(_db.auditLogs).go();
      await _db.delete(_db.branches).go();
      await _db.delete(_db.users).go();
    });
  }
}

