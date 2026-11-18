import 'dart:convert';
import 'dart:io' show Platform;
import '../db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'sync/device_id_service.dart';
import '../models/models.dart' show parseDT;
import '../utils/perf_logger.dart';
import 'outbox_service.dart';
import 'identity_service.dart';
import '../repositories/inventory_repository.dart';
import 'conflict_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;

  late AppDatabase _db;
  AppDatabase get db => _db;
  final _uuid = const Uuid();
  final Map<String, String> _settingCache = <String, String>{};

  // --- DAOs ---
  late ProductsDao productsDao;
  late SalesDao salesDao;
  late DebtsDao debtsDao;
  late UsersDao usersDao;
  late MovementsDao movementsDao;
  late SyncOutboxDao syncOutboxDao;
  late ProductStocksDao productStocksDao;
  late SyncConflictsDao syncConflictsDao;

  DatabaseService._internal() {
    resetForTest();
  }

  @visibleForTesting
  void resetForTest() {
    _db = AppDatabase();
    productsDao = ProductsDao(_db);
    salesDao = SalesDao(_db);
    debtsDao = DebtsDao(_db);
    usersDao = UsersDao(_db);
    movementsDao = MovementsDao(_db);
    syncOutboxDao = SyncOutboxDao(_db);
    productStocksDao = ProductStocksDao(_db);
    syncConflictsDao = SyncConflictsDao(_db);
    ConflictService().init(_db);
  }

  // --- GENERIC METHODS ---

  Future<void> runTransaction(Future<void> Function() action) async {
    await _db.transaction(action);
  }

  /// Ensures atomic local operation + Outbox event consistency
  Future<T> recordEventWithTransaction<T>({
    required Future<T> Function() localOperation,
    required String shopId,
    required String branchId,
    required String userId,
    required String
        eventType, // SALE | PURCHASE | REFUND | TRANSFER | ADJUSTMENT
    required String entityType,
    required String entityId,
    Map<String, dynamic>? payload,
  }) async {
    T? result;
    final devId = await DeviceIdService.getOrCreate();
    final eventId = _uuid.v4();

    await _db.transaction(() async {
      result = await localOperation();

      await _db.into(_db.syncOutbox).insert(
            SyncOutboxCompanion.insert(
              id: eventId,
              shopId: shopId,
              branchId: Value(branchId),
              deviceId: devId,
              userId: userId,
              entityTable: entityType,
              recordId: entityId,
              operation: eventType.toUpperCase(),
              payloadJson: Value(payload == null ? null : jsonEncode(payload)),
              createdAt: Value(DateTime.now().toUtc()),
              updatedAt: Value(DateTime.now().toUtc()),
              attemptCount: const Value(0),
              status: Value(OutboxStatus.PENDING.name),
              schemaVersion: const Value(1),
            ),
            mode: InsertMode.insertOrReplace,
          );
    });

    return result!;
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {String? where,
      List<dynamic>? whereArgs,
      String? orderBy,
      int? limit}) async {
    // Basic dynamic query wrapper for legacy support
    // In production we should use DAOs, but for fixing logic fast:
    if (table == 'users') {
      var query = _db.select(_db.users);
      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        if (where.contains('shop_id = ?') || where.contains('shopId = ?')) {
          final shopVal = whereArgs[0].toString();
          query.where((t) => t.shopId.equals(shopVal));
        } else if (where.contains('cloud_user_id') ||
            where.contains('cloudUserId')) {
          final val1 = whereArgs[0].toString().toLowerCase();
          final val2 = whereArgs.length > 1
              ? whereArgs[1].toString().toLowerCase()
              : val1;
          final val3 =
              whereArgs.length > 2 ? whereArgs[2].toString().toLowerCase() : '';
          query.where((t) =>
              t.username.lower().equals(val1) |
              t.email.lower().equals(val2) |
              (t.cloudUserId.isNotNull() & t.cloudUserId.lower().equals(val3)));
        } else if (where.contains('username = ? OR email = ?') &&
            whereArgs.length >= 2) {
          final val1 = whereArgs[0].toString().toLowerCase();
          final val2 = whereArgs[1].toString().toLowerCase();
          query.where((t) =>
              t.username.lower().equals(val1) | t.email.lower().equals(val2));
        } else if (where.contains('uid = ?') && whereArgs.isNotEmpty) {
          final val = whereArgs[0].toString();
          query.where((t) => t.uid.equals(val));
        }
      }
      if (limit != null) {
        query.limit(limit);
      }
      final sw = Stopwatch()..start();
      final res = await query.get();
      PerfLogger.logSlowQuery('Users query', sw.elapsedMilliseconds);
      debugPrint(
          '[AUTH DEBUG] DatabaseService query users: where="$where", args=$whereArgs, found=${res.length} rows.');
      return res
          .map((r) => {
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
                'cloudUserId': r.cloudUserId,
                'syncEnabled': r.syncEnabled,
                'lastOnlineLogin': r.lastOnlineLogin?.toIso8601String(),
              })
          .toList();
    }

    if (table == 'products' || table == 'items') {
      var query = _db.select(_db.products)
        ..where((t) => t.syncStatus.equals('pendingDelete').not());
      if (where != null &&
          (RegExp(r'\bid\s*=\s*\?').hasMatch(where) &&
              !where.contains('shop_id'))) {
        query.where((t) => t.id.equals(whereArgs![0].toString()));
      } else if (whereArgs != null && whereArgs.isNotEmpty) {
        query.where((t) {
          var expression = t.shopId.equals(whereArgs[0].toString());

          // DYNAMIC ARGUMENT MAPPING (Handles arbitrary WHERE combinations)
          // DYNAMIC ARGUMENT MAPPING (Handles arbitrary WHERE combinations)
          if (where != null) {
            final bool isOrPattern = where.contains('OR');
            Expression<bool>? identityExpr;

            // Find 'name' or 'LOWER(name)'
            if (where.contains('name = ?') ||
                where.contains('LOWER(name) = ?')) {
              final idx = where.lastIndexOf('name');
              final qPos = where.substring(0, idx).split('?').length - 1;
              if (qPos < whereArgs.length) {
                final e = t.name
                    .lower()
                    .equals(whereArgs[qPos].toString().toLowerCase());
                identityExpr = identityExpr == null
                    ? e
                    : (isOrPattern ? identityExpr | e : identityExpr & e);
              }
            }

            // Find 'barcode' or 'LOWER(barcode)'
            if (where.contains('barcode = ?') ||
                where.contains('LOWER(barcode) = ?')) {
              final idx = where.lastIndexOf('barcode');
              final qPos = where.substring(0, idx).split('?').length - 1;
              if (qPos < whereArgs.length) {
                final e = t.barcode
                    .lower()
                    .equals(whereArgs[qPos].toString().toLowerCase());
                identityExpr = identityExpr == null
                    ? e
                    : (isOrPattern ? identityExpr | e : identityExpr & e);
              }
            }

            if (identityExpr != null) {
              expression = expression & identityExpr;
            }

            // Find 'branch_id'
            if (where.contains('branch_id = ?')) {
              final idx = where.indexOf('branch_id');
              final qPos = where.substring(0, idx).split('?').length - 1;
              if (qPos < whereArgs.length) {
                final bVal = whereArgs[qPos].toString();
                if (bVal == 'all') {
                  // No filter
                } else if (bVal == 'main') {
                  expression = expression &
                      (t.branchId.equals('main') | t.branchId.isNull());
                } else {
                  expression = expression & t.branchId.equals(bVal);
                }
              }
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
      if (whereArgs != null && whereArgs.isNotEmpty) {
        query.where((t) {
          var expr = t.shopId.equals(whereArgs[0].toString());
          if (whereArgs.length >= 2) {
            expr = expr & t.itemId.equals(whereArgs[1].toString());
          }

          // Dynamic Branch filtering
          String? bVal;
          if (where != null && where.contains('branch_id = ?')) {
            final branchIdx = where.indexOf('branch_id');
            final qCountBefore =
                where.substring(0, branchIdx).split('?').length - 1;
            if (qCountBefore < whereArgs.length) {
              bVal = whereArgs[qCountBefore].toString();
            }
          } else if (whereArgs.length >= 3) {
            // Fallback for simple [shop, item, branch]
            bVal = whereArgs[2].toString();
          }

          if (bVal != null) {
            if (bVal == 'main') {
              expr = expr & (t.branchId.equals('main') | t.branchId.isNull());
            } else {
              expr = expr & t.branchId.equals(bVal);
            }
          }

          // Dynamic Expiry filtering (matches both 'exp' and 'expiry_date')
          if (where != null &&
              (where.contains('exp = ?') ||
                  where.contains('expiry_date = ?'))) {
            final expIdx = where.contains('expiry_date')
                ? where.indexOf('expiry_date')
                : where.indexOf('exp');
            final qCountBefore =
                where.substring(0, expIdx).split('?').length - 1;
            if (qCountBefore < whereArgs.length) {
              final expVal = whereArgs[qCountBefore]?.toString();
              if (expVal != null) {
                final dt = DateTime.tryParse(expVal);
                if (dt != null) {
                  expr = expr &
                      t.expiryDate
                          .equals(DateTime.utc(dt.year, dt.month, dt.day));
                }
              }
            }
          }

          if (where != null && where.contains('expiry_date IS NULL')) {
            expr = expr & t.expiryDate.isNull();
          }

          // Pricing filtering (CRITICAL for transfer splitting)
          if (where != null && where.contains('buying_price = ?')) {
            final idx = where.indexOf('buying_price');
            final qVal =
                whereArgs[where.substring(0, idx).split('?').length - 1];
            expr = expr & t.buyingPrice.equals(_toDouble(qVal));
          }
          if (where != null && where.contains('selling_price = ?')) {
            final idx = where.indexOf('selling_price');
            final qVal =
                whereArgs[where.substring(0, idx).split('?').length - 1];
            expr = expr & t.sellingPrice.equals(_toDouble(qVal));
          }

          // Batch number filtering
          if (where != null && where.contains('batch_number = ?')) {
            final idx = where.indexOf('batch_number');
            final qVal =
                whereArgs[where.substring(0, idx).split('?').length - 1];
            expr = expr & t.batchNumber.equals(qVal.toString());
          }

          if (where != null && where.contains('quantity > 0')) {
            expr = expr & t.quantity.isBiggerThanValue(0);
          }

          // Strict ID detection using word boundary to avoid matching shop_id, item_id, or branch_id
          if (where != null && RegExp(r'\bid\s*=\s*\?').hasMatch(where)) {
            final idIdx = where.indexOf(RegExp(r'\bid\s*=\s*'));
            final qCountBefore =
                where.substring(0, idIdx).split('?').length - 1;
            if (qCountBefore < whereArgs.length) {
              expr = expr & t.id.equals(whereArgs[qCountBefore].toString());
            }
          }

          return expr;
        });
      }
      final res = await query.get();
      return res.map((r) => _batchToMap(r)).toList();
    }

    if (table == 'subscriptions') {
      var q = _db.select(_db.subscriptions);
      if (whereArgs != null && whereArgs.isNotEmpty) {
        q.where((t) => t.shopId.equals(whereArgs[0].toString()));
      }
      if (where != null && where.contains('activationDate DESC')) {
        q.orderBy([
          (t) => OrderingTerm(
              expression: t.activationDate, mode: OrderingMode.desc)
        ]);
      }
      final res = await q.get();
      return res
          .map((r) => {
                'shopId': r.shopId,
                'plan': r.plan,
                'activationDate': r.activationDate.toIso8601String(),
                'expiryDate': r.expiryDate.toIso8601String(),
                'addOns': r.addOns,
                'isTrial': r.isTrial,
                'userLimit': r.userLimit,
                'branchLimit': r.branchLimit,
              })
          .toList();
    }

    if (table == 'purchases') {
      var query = _db.select(_db.purchases);
      if (whereArgs != null && whereArgs.isNotEmpty) {
        query.where((t) => t.shopId.equals(whereArgs[0].toString()));
      }
      final res = await query.get();
      return res
          .map((r) => {
                'id': r.id,
                'shopId': r.shopId,
                'itemId': r.itemId,
                'itemName': r.itemName,
                'barcode': r.barcode,
                'quantity': r.quantity,
                'unitCost': r.unitCost,
                'totalCost': r.totalCost,
                'supplierName': r.supplierName,
                'expiryDate': r.expiryDate?.toIso8601String(),
                'timestamp': r.timestamp.toIso8601String(),
                'syncStatus': r.syncStatus,
                'branchId': r.branchId,
              })
          .toList();
    }

    if (table == 'product_stocks') {
      var query = _db.select(_db.productStocks);
      if (whereArgs != null && whereArgs.isNotEmpty) {
        if (whereArgs.length >= 3) {
          query.where((t) =>
              t.shopId.equals(whereArgs[0].toString()) &
              t.productId.equals(whereArgs[1].toString()) &
              t.branchId.equals(whereArgs[2].toString()));
        } else if (whereArgs.length == 2 &&
            where != null &&
            where.contains('productId')) {
          query.where((t) =>
              t.productId.equals(whereArgs[0].toString()) &
              t.branchId.equals(whereArgs[1].toString()));
        }
      }
      final res = await query.get();
      return res
          .map((r) => {
                'shopId': r.shopId,
                'productId': r.productId,
                'branchId': r.branchId,
                'quantity': r.quantity,
              })
          .toList();
    }

    if (table == 'sales') {
      var q = _db.select(_db.sales);
      if (whereArgs != null && whereArgs.isNotEmpty) {
        q.where((t) => t.shopId.equals(whereArgs[0].toString()));
      }
      q.where((t) => t.syncStatus.isNotIn(const ['pendingDelete', 'rejected', 'conflict']));
      final res = await q.get();
      return res.map((r) => _saleToMap(r)).toList();
    }

    return [];
  }

  Future<void> ensureInitialized() async {
    try {
      // Just open the connection with a lightweight ping.
      // WAL + busy_timeout are already set once in the NativeDatabase.setup callback.
      await _db.customSelect('SELECT 1').getSingle();
      debugPrint('[DB] Database initialized');
      debugPrint('[DB] WAL enabled');
    } catch (e) {
      debugPrint('[DB] DB Init Error: $e');
    }
  }

  Future<String> _activeUserId() async =>
      (await getSetting('active_user_id'))?.trim().isNotEmpty == true
          ? (await getSetting('active_user_id'))!.trim()
          : 'unknown';

  Future<void> enqueueOutboxManual({
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
        payloadJson: payload == null ? null : jsonEncode(_jsonSafe(payload)),
      );
    } catch (e) {
      debugPrint('Outbox enqueue failed: $e');
    }
  }

  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _jsonSafe(val)));
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList();
    }
    return value.toString();
  }

  // --- BULK OPERATIONS ---

  Future<void> bulkInsertProducts(List<Product> items) async {
    await _db.transaction(() async {
      for (final item in items) {
        await _db
            .into(_db.products)
            .insert(item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  // Legacy wrappers for backward compatibility with UI
  // --- PRODUCT METHODS ---

  DateTime? _toDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    if (val is int) {
      if (val < 10000000000)
        return DateTime.fromMillisecondsSinceEpoch(val * 1000);
      return DateTime.fromMillisecondsSinceEpoch(val);
    }
    if (val is String && val.isNotEmpty) {
      final dt = DateTime.tryParse(val);
      if (dt != null) {
        // Bug #5: Reject any date before year 2000
        if (dt.year < 2000) return null;
        return dt;
      }
      final numVal = int.tryParse(val);
      if (numVal != null) {
        DateTime? dtNum;
        if (numVal < 10000000000)
          dtNum = DateTime.fromMillisecondsSinceEpoch(numVal * 1000);
        else
          dtNum = DateTime.fromMillisecondsSinceEpoch(numVal);

        if (dtNum != null && dtNum.year < 2000) return null;
        return dtNum;
      }
    }

    // Final check for all paths
    if (val is DateTime && val.year < 2000) return null;
    if (val is int) {
      DateTime dtInt;
      if (val < 10000000000)
        dtInt = DateTime.fromMillisecondsSinceEpoch(val * 1000);
      else
        dtInt = DateTime.fromMillisecondsSinceEpoch(val);
      if (dtInt.year < 2000) return null;
      return dtInt;
    }

    return null;
  }

  double _toDouble(dynamic val, {double fallback = 0.0}) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString().trim()) ?? fallback;
  }

  Future<void> saveProduct(Map<String, dynamic> data) async {
    final shopId = data['shopId']?.toString() ?? '';
    final branchId = data['branchId']?.toString() ?? 'main';
    final recordId =
        (data['id'] ?? data['uniqueId'] ?? data['name'] ?? _uuid.v4())
            .toString();
    final entry = ProductsCompanion.insert(
      id: recordId,
      shopId: shopId,
      branchId: branchId,
      name: data['name'],
      barcode: Value(data['barcode'] ?? ''),
      quantity: _toDouble(data['quantity']),
      buyingPrice: _toDouble(data['buyingPrice']),
      sellingPrice: _toDouble(data['sellingPrice']),
      lowStockThreshold:
          Value((data['lowStockThreshold'] as num?)?.toInt() ?? 5),
      expiryDate:
          Value(parseDT(data['expiry'] ?? data['expiryDate'] ?? data['exp'])),
      batchNumber: Value(data['batchNumber']?.toString()),
      imageUrl: Value(data['imageUrl']?.toString()),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
    );
    await _db.into(_db.products).insertOnConflictUpdate(entry);

    // Ensure per-branch stock cache exists for correct multi-branch behavior.
    await saveProductStock(
      shopId: shopId,
      productId: recordId,
      branchId: branchId,
      quantity: _toDouble(data['quantity']),
    );

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'products',
      recordId: recordId,
      operation: 'upsert',
      payload: {
        ...data,
        'id': recordId,
        'shopId': shopId,
        'branchId': branchId
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllProducts(String shopId) async {
    final res = await (_db.select(_db.products)
          ..where((t) => t.shopId.equals(shopId)))
        .get();
    return res.map((row) => _productToMap(row)).toList();
  }

  Future<List<Map<String, dynamic>>> searchItems(
      String shopId, String name, String barcode,
      {String? branchId}) async {
    final query = _db.select(_db.products)
      ..where((t) {
        final nameMatch = t.name.equals(name.trim());
        final barcodeMatch = barcode.trim().isNotEmpty
            ? t.barcode.equals(barcode.trim())
            : const Constant(false);
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

    // Serialise batch allocations into batchId so they survive DB round-trips.
    // batchId schema: single batch → UUID string; multi-batch → JSON array of
    // [{"batchId":"...","quantity":N}, ...].  parseBatchAllocations() knows how
    // to handle both forms when the refund reads the sale back from the DB.
    final rawAllocations =
        data['batchAllocations'] ?? data['batch_allocations'];
    String? persistedBatchId;
    if (rawAllocations is List && rawAllocations.isNotEmpty) {
      // Always store the full allocation list so partial/multi-batch refunds work.
      persistedBatchId =
          jsonEncode(rawAllocations.map((e) => _jsonSafe(e)).toList());
    } else {
      persistedBatchId = data['batchId']?.toString();
    }

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
      timestamp: DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      customerName: Value(data['customerName']?.toString()),
      isDebt: Value(data['isDebt'] == true || data['isDebt'] == 1),
      amountPaid: Value((data['amountPaid'] as num?)?.toDouble() ?? 0.0),
      debtRemaining: Value((data['debtRemaining'] as num?)?.toDouble() ?? 0.0),
      refundedQuantity:
          Value((data['refundedQuantity'] as num?)?.toDouble() ?? 0.0),
      batchId: Value(persistedBatchId),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
    );
    await _db.into(_db.sales).insertOnConflictUpdate(entry);

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'sales',
      recordId: recordId,
      operation: 'upsert',
      // Always include full allocation data in the outbox payload.
      payload: {
        ...data,
        'id': recordId,
        'shopId': shopId,
        'branchId': branchId,
        'batchId': persistedBatchId,
        if (rawAllocations != null) 'batchAllocations': rawAllocations,
        if (rawAllocations != null) 'batch_allocations': rawAllocations,
      },
    );
  }

  // --- AUTH METHODS ---

  Future<void> cacheUser(Map<String, dynamic> data) async {
    await saveUserRecord(data);
    await saveSetting('active_user_id', data['uid'] ?? data['id'] ?? '');
    await saveSetting(
        'cached_user_json',
        jsonEncode(_jsonSafe({
          'uid': data['uid'] ?? data['id'] ?? '',
          'email': data['email'],
          'roles': data['roles'],
          'shopId': data['shopId'],
          'username': data['username'],
          'branchId': data['branchId'],
          'branchName': data['branchName'],
          'permissions': data['permissions'],
          'passwordHash': data['passwordHash'],
          'currency': data['currency'],
          'isActive': data['isActive'],
        })));
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
    final cachedJson = await getSetting('cached_user_json');
    if (cachedJson != null && cachedJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(cachedJson);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map['uid'] == null && map['id'] != null) {
            map['uid'] = map['id'];
          }
          if (map['currency'] == null) {
            map['currency'] = await getSetting('currency') ?? 'USD';
          }
          return map;
        }
      } catch (_) {}
    }

    final activeId = await getSetting('active_user_id');
    if (activeId == null || activeId.isEmpty) return null;

    final row = await (_db.select(_db.users)
          ..where((t) => t.uid.equals(activeId)))
        .getSingleOrNull();
    if (row == null) return null;
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
    _settingCache.remove('active_user_id');
    _settingCache.remove('cached_user_json');
    _settingCache.remove('active_shop_id');
    _settingCache.remove('active_branch_id');
    await saveSetting('active_user_id', '');
    await saveSetting('cached_user_json', '');
    await saveSetting('active_shop_id', '');
    await saveSetting('active_branch_id', '');
  }

  /// Returns the business/shop ID that is currently active on this device,
  /// reading from the cached user JSON or the standalone active_shop_id setting.
  Future<String?> getCachedShopId() async {
    final user = await getCachedUser();
    if (user != null && (user['shopId'] as String?)?.isNotEmpty == true) {
      return user['shopId'] as String?;
    }
    final id = await getSetting('active_shop_id');
    return (id?.isEmpty == true) ? null : id;
  }

  static bool isLocalOnlySetting(String key) {
    final k = key.trim();
    if (k == 'active_user_id' ||
        k == 'cached_user_json' ||
        k == 'active_shop_id' ||
        k == 'active_branch_id' ||
        k == 'api_base_url' ||
        k == 'pending_pwd_change' ||
        k == 'pending_pwd_plain' ||
        k == 'pending_cloud_registration' ||
        k == 'pending_cloud_email') {
      return true;
    }
    if (k.startsWith('identity_') ||
        k == 'access_token' ||
        k == 'refresh_token' ||
        k == 'cloud_business_id' ||
        k.startsWith('shown_notification_ids_') ||
        k.startsWith('push_token_') ||
        k.startsWith('sync_cursor_')) {
      return true;
    }
    return false;
  }

  Future<void> saveSetting(String key, String value,
      {bool isFromSync = false}) async {
    _settingCache[key] = value;
    final entry = AppSettingsCompanion.insert(key: key, value: value);
    await _db.into(_db.appSettings).insertOnConflictUpdate(entry);

    if (key == 'currency' || key == 'app_currency_symbol') {
      final code = value.trim();
      if (code.isNotEmpty) {
        final activeUid = await getSetting('active_user_id');
        if (activeUid != null && activeUid.isNotEmpty) {
          await (_db.update(_db.users)..where((t) => t.uid.equals(activeUid)))
              .write(UsersCompanion(currency: Value(code)));
        }
      }
    }

    if (!isFromSync && !isLocalOnlySetting(key)) {
      final activeShopId = (await getSetting('active_shop_id')) ??
          (await getSetting('identity_business_id')) ??
          '';
      final activeBranchId = (await getSetting('active_branch_id')) ?? 'main';
      if (activeShopId.isNotEmpty) {
        await enqueueOutboxManual(
          shopId: activeShopId,
          branchId: activeBranchId,
          table: 'app_settings',
          recordId: key,
          operation: 'upsert',
          payload: {
            'key': key,
            'value': value,
            'shopId': activeShopId,
            'branchId': activeBranchId
          },
        );
        debugPrint(
            '[SETTINGS SYNC] Outbox event enqueued for setting key=$key');
      }
    }
  }

  /// Updates only the on-device password hash (used after the cloud account
  /// password is set, so offline sign-in accepts the same password).
  Future<void> updateLocalPasswordHash(String uid, String hash) async {
    if (uid.isEmpty || hash.isEmpty) return;
    await (_db.update(_db.users)..where((t) => t.uid.equals(uid)))
        .write(UsersCompanion(passwordHash: Value(hash)));
  }

  Future<void> updateUserCurrency(String uid, String newCurrency,
      {bool isFromSync = false}) async {
    final clean = newCurrency.trim().toUpperCase();
    if (uid.isNotEmpty) {
      await (_db.update(_db.users)..where((t) => t.uid.equals(uid)))
          .write(UsersCompanion(currency: Value(clean)));
    }
    await saveSetting('currency', clean, isFromSync: isFromSync);
    await saveSetting('app_currency_symbol', '$clean ', isFromSync: isFromSync);
  }

  Future<String?> getSetting(String key) async {
    if (_settingCache.containsKey(key)) {
      return _settingCache[key];
    }
    final res = await (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    final value = res?.value;
    if (value != null) {
      _settingCache[key] = value;
    }
    return value;
  }

  Future<void> deleteSetting(String key, {bool isFromSync = false}) async {
    _settingCache.remove(key);
    await (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
    if (!isFromSync && !isLocalOnlySetting(key)) {
      final activeShopId = (await getSetting('active_shop_id')) ??
          (await getSetting('identity_business_id')) ??
          '';
      final activeBranchId = (await getSetting('active_branch_id')) ?? 'main';
      if (activeShopId.isNotEmpty) {
        await enqueueOutboxManual(
          shopId: activeShopId,
          branchId: activeBranchId,
          table: 'app_settings',
          recordId: key,
          operation: 'delete',
          payload: {
            'key': key,
            'shopId': activeShopId,
            'branchId': activeBranchId
          },
        );
      }
    }
  }

  /// Stores the current device push token locally and queues it for FastAPI.
  /// Backend can use it to deliver remote push notifications to this device.
  Future<void> queueDevicePushToken(String token) async {
    final shopId = (await getSetting('active_shop_id')) ?? '';
    if (shopId.trim().isEmpty) return;
    final branchId = (await getSetting('active_branch_id')) ?? 'main';
    final platform = kIsWeb
        ? 'web'
        : (Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'));

    await saveSetting('push_token_$shopId', token);

    // Push token registration is modeled as an outbox event.
    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'device_tokens',
      recordId: token,
      operation: 'upsert',
      payload: {
        'shopId': shopId,
        'branchId': branchId,
        'token': token,
        'platform': platform,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
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

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: 'main',
      table: 'branches',
      recordId: recordId,
      operation: 'upsert',
      payload: {...data, 'id': recordId, 'shopId': shopId},
    );
  }

  Future<List<Map<String, dynamic>>> getBranches(String shopId) async {
    final res = await (_db.select(_db.branches)
          ..where((t) => t.shopId.equals(shopId)))
        .get();
    final mapped = res
        .map<Map<String, dynamic>>(
            (r) => {'id': r.id, 'name': r.name, 'shopId': r.shopId})
        .toList();
    if (!mapped.any((m) => m['id'] == 'main')) {
      mapped.insert(0, {'id': 'main', 'name': 'Main Branch', 'shopId': shopId});
    }
    return mapped;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    // Fetch existing row so we can merge and enqueue a full outbox payload.
    final existing = await (_db.select(_db.users)
          ..where((t) => t.uid.equals(uid)))
        .getSingleOrNull();
    if (existing == null) return;

    final merged = <String, dynamic>{
      'uid': uid,
      'email': existing.email,
      'username': data['username']?.toString() ?? existing.username,
      'fullName': data['fullName']?.toString() ?? existing.fullName ?? '',
      'roles':
          data['roles'] is List ? data['roles'] : existing.roles.split(';'),
      'shopId': data['shopId']?.toString() ?? existing.shopId,
      'branchId': data['branchId']?.toString() ?? existing.branchId ?? 'main',
      'branchName': data['branchName']?.toString() ??
          existing.branchName ??
          'Main Branch',
      'permissions': data['permissions'] ?? existing.permissions,
      'isActive': data['isActive'] ?? existing.isActive,
      // Never put passwordHash into merged payload — saveUserRecord will preserve it automatically.
    };

    // Delegate to saveUserRecord: handles insertOnConflictUpdate + outbox enqueueing.
    await saveUserRecord(merged, isFromSync: false);
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
      'expiry': row.expiryDate?.toIso8601String(),
      'expiryDate':
          row.expiryDate?.toIso8601String(), // alias for compatibility
      'batchNumber': row.batchNumber,
      'imageUrl': row.imageUrl,
      'syncStatus': row.syncStatus,
      'lastModified': row.lastModified.toIso8601String(),
    };
  }

  Map<String, dynamic> _saleToMap(Sale row) {
    // Parse the persisted batchId back into batchAllocations so processRefund
    // always has the full allocation list regardless of how many batches the
    // original sale consumed.  Format:
    //   single batch  → batchId = UUID string
    //   multi-batch   → batchId = JSON array [{"batchId":"...","quantity":N},...]
    final rawBatchId = row.batchId;
    List<Map<String, dynamic>>? parsedAllocations;
    if (rawBatchId != null &&
        rawBatchId.trimLeft().startsWith('[') &&
        rawBatchId.trimRight().endsWith(']')) {
      try {
        final decoded = jsonDecode(rawBatchId);
        if (decoded is List) {
          final allocs = <Map<String, dynamic>>[];
          for (final e in decoded) {
            if (e is Map) {
              final bId =
                  e['batchId']?.toString() ?? e['batch_id']?.toString() ?? '';
              final q = (e['quantity'] as num?)?.toDouble() ?? 0.0;
              if (bId.isNotEmpty && q > 0)
                allocs.add({'batchId': bId, 'quantity': q});
            }
          }
          if (allocs.isNotEmpty) parsedAllocations = allocs;
        }
      } catch (_) {}
    }

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
      'refundedQuantity': row.refundedQuantity,
      'batchId': rawBatchId,
      'syncStatus': row.syncStatus,
      'remoteId': row.remoteId,
      if (parsedAllocations != null) 'batchAllocations': parsedAllocations,
      if (parsedAllocations != null) 'batch_allocations': parsedAllocations,
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
      'expiry': row.expiryDate?.toIso8601String(),
      'timestamp': row.timestamp.toIso8601String(),
    };
  }

  Map<String, dynamic> _batchToMap(Batche row) {
    final expiryIso = row.expiryDate?.toIso8601String();
    return {
      'id': row.id,
      'shopId': row.shopId,
      'itemId': row.itemId,
      'quantity': row.quantity,
      'buyingPrice': row.buyingPrice,
      'sellingPrice': row.sellingPrice,
      'expiry': expiryIso,
      'exp': expiryIso,
      'batchNumber': row.batchNumber,
      'timestamp': row.timestamp.toIso8601String(),
      'branchId': row.branchId,
    };
  }

  // --- WATCH METHODS (LOCAL-FIRST REACTIVITY) ---

  Stream<List<Map<String, dynamic>>> watchProducts(String shopId,
      {String? branchId}) {
    final effectiveBranch =
        (branchId == null || branchId.trim().isEmpty) ? 'all' : branchId.trim();

    // Local-first + multi-branch correctness:
    // - Products is the definition, scoped to a branch.
    // - ProductStocks is the branch-scoped quantity cache.
    // - When effectiveBranch == 'all', show each product per branch separately.
    // - When a specific branch is requested, the branchId in the returned row is
    //   ALWAYS the requested branch (not p.branch_id), so that transferred products
    //   correctly report the destination branch for POS stock deduction.
    final sql = (effectiveBranch == 'all')
        ? '''
      SELECT p.*, ps.quantity AS branch_quantity, ps.branch_id AS stock_branch_id,
        (SELECT MIN(b.expiry_date) FROM batches b 
          WHERE b.shop_id = p.shop_id AND b.item_id = p.id 
          AND b.branch_id = ps.branch_id
          AND b.quantity > 0) AS branch_expiry
      FROM product_stocks ps
      JOIN products p ON ps.product_id = p.id AND ps.shop_id = p.shop_id
        AND (p.branch_id = ps.branch_id OR (p.branch_id IS NULL AND ps.branch_id = 'main'))
      WHERE ps.shop_id = ? AND p.sync_status <> 'pendingDelete'
      ORDER BY p.name COLLATE NOCASE, ps.branch_id
    '''
        : '''
      SELECT p.*, COALESCE(ps.quantity, 0) AS branch_quantity,
        ? AS effective_branch_id,
        (SELECT MIN(b.expiry_date) FROM batches b 
          WHERE b.shop_id = p.shop_id AND b.item_id = p.id 
          AND (b.branch_id = ? OR (b.branch_id IS NULL AND ? = 'main'))
          AND b.quantity > 0) AS branch_expiry
      FROM products p
      LEFT JOIN product_stocks ps 
        ON ps.shop_id = p.shop_id 
       AND ps.product_id = p.id 
       AND ps.branch_id = ?
      WHERE p.shop_id = ?
        AND p.sync_status <> 'pendingDelete'
        AND (p.branch_id = ? OR (p.branch_id IS NULL AND ? = 'main'))
      ORDER BY p.name COLLATE NOCASE
    ''';

    final variables = (effectiveBranch == 'all')
        ? [Variable.withString(shopId)]
        : [
            Variable.withString(effectiveBranch), // effective_branch_id alias
            Variable.withString(effectiveBranch), // b.branch_id = ?
            Variable.withString(effectiveBranch), // ? = 'main' check
            Variable.withString(effectiveBranch), // ps.branch_id = ?
            Variable.withString(shopId),
            Variable.withString(effectiveBranch), // p.branch_id = ?
            Variable.withString(effectiveBranch), // ? = 'main' check
          ];

    return _db
        .customSelect(
          sql,
          variables: variables,
          readsFrom: {_db.products, _db.productStocks, _db.batches},
        )
        .watch()
        .map((rows) {
          return rows.map((r) {
            try {
              final m = r.data;
              final rawExp = m['branch_expiry'] ??
                  m['exp'] ??
                  m['expiry_date'] ??
                  m['expiryDate'];
              final expVal = parseDT(rawExp)?.toIso8601String();
              // Use effective_branch_id for single-branch, stock_branch_id for all-branches.
              // This ensures transferred products always show the DESTINATION branch as their branchId.
              final displayBranch = (effectiveBranch == 'all')
                  ? m['stock_branch_id']?.toString()
                  : (m['effective_branch_id']?.toString() ?? effectiveBranch);

              return <String, dynamic>{
                'id': (m['id'] ?? '').toString(),
                'shopId': (m['shop_id'] ?? '').toString(),
                'branchId': displayBranch,
                'name': (m['name'] ?? '').toString(),
                'barcode': (m['barcode'] ?? '').toString(),
                'quantity': _toDouble(m['branch_quantity']),
                'buyingPrice': _toDouble(m['buying_price']),
                'sellingPrice': _toDouble(m['selling_price']),
                'lowStockThreshold': (m['low_stock_threshold'] ?? 5) as int,
                'expiry': expVal,
                'exp': expVal,
                'expiryDate': expVal,
                'batchNumber': m['batch_number']?.toString(),
                'imageUrl': m['image_url']?.toString(),
              };
            } catch (e) {
              rethrow;
            }
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> watchSales(String shopId,
      {String? branchId, bool includeRejected = false}) {
    final query = _db.select(_db.sales)
      ..where((t) =>
          t.shopId.equals(shopId) &
          t.syncStatus.isNotIn(includeRejected
              ? const ['pendingDelete']
              : const ['pendingDelete', 'rejected', 'conflict']));
    if (branchId != null && branchId != "all" && branchId.isNotEmpty) {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    return query.watch().map((rows) =>
        rows.map<Map<String, dynamic>>((r) => _saleToMap(r)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchBatches(String shopId,
      {String? branchId}) {
    final query = _db.select(_db.batches)
      ..where((t) =>
          t.shopId.equals(shopId) &
          t.syncStatus.isNotIn(const ['pendingDelete']));
    if (branchId != null && branchId != "all" && branchId.isNotEmpty) {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    return query
        .watch()
        .map((rows) => rows.map((r) => _batchToMap(r)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchPurchases(String shopId,
      {String? branchId}) {
    final query = _db.select(_db.purchases)
      ..where((t) =>
          t.shopId.equals(shopId) &
          t.syncStatus.isNotIn(const ['pendingDelete']));
    if (branchId != null && branchId != 'all' && branchId.isNotEmpty) {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    return query
        .watch()
        .map((rows) => rows.map((r) => _purchaseToMap(r)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchBatchesByItem(
      String shopId, String itemId,
      {String? branchId}) {
    final query = _db.select(_db.batches)
      ..where((t) => t.shopId.equals(shopId) & t.itemId.equals(itemId));
    if (branchId != null && branchId != 'all' && branchId.isNotEmpty) {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    return query
        .watch()
        .map((rows) => rows.map((r) => _batchToMap(r)).toList());
  }

  Stream<List<Map<String, dynamic>>> watchBranches(String shopId) {
    return (_db.select(_db.branches)
          ..where((t) =>
              t.shopId.equals(shopId) &
              t.syncStatus.isNotIn(const ['pendingDelete'])))
        .watch()
        .map((rows) {
      final mapped = rows
          .map<Map<String, dynamic>>(
              (r) => {'id': r.id, 'name': r.name, 'shopId': r.shopId})
          .toList();
      if (!mapped.any((m) => m['id'] == 'main')) {
        mapped
            .insert(0, {'id': 'main', 'name': 'Main Branch', 'shopId': shopId});
      }
      return mapped;
    });
  }

  Future<bool> isUsernameTaken(String username) async {
    final res = await (_db.select(_db.users)
          ..where((t) =>
              t.username.lower().equals(username.toLowerCase().trim())))
        .get();
    return res.isNotEmpty;
  }

  Stream<List<Map<String, dynamic>>> watchUsers(String shopId) {
    return (_db.select(_db.users)..where((t) => t.shopId.equals(shopId)))
        .watch()
        .map((rows) => rows
            .map((r) => {
                  'uid': r.uid,
                  'username': r.username,
                  'email': r.email,
                  'roles': r.roles.split(';'),
                  'permissions': r.permissions,
                  'branchId': r.branchId,
                  'isActive': r.isActive ?? true,
                })
            .toList());
  }

  Stream<Map<String, dynamic>?> watchUserById(String uid) {
    return (_db.select(_db.users)..where((t) => t.uid.equals(uid)))
        .watchSingleOrNull()
        .map((r) {
      if (r == null) return null;
      return {
        'uid': r.uid,
        'email': r.email,
        'roles': r.roles.split(';'),
        'shopId': r.shopId,
        'username': r.username,
        'branchId': r.branchId,
        'branchName': r.branchName,
        'permissions': r.permissions,
        'passwordHash': r.passwordHash,
        'currency': r.currency,
        'isActive': r.isActive,
        'fullName': r.fullName,
      };
    });
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs(String shopId,
      {String? branchId}) {
    final query = _db.select(_db.auditLogs)
      ..where((t) => t.shopId.equals(shopId));
    if (branchId != null && branchId != 'all') {
      if (branchId == 'main') {
        query.where((t) => t.branchId.equals('main') | t.branchId.isNull());
      } else {
        query.where((t) => t.branchId.equals(branchId));
      }
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
    ]);

    return query.watch().map((rows) => rows
        .map((r) => {
              'id': r.id,
              'action': r.action,
              'details': r.details,
              'username': r.username,
              'timestamp': r.timestamp.toIso8601String(),
              'branchId': r.branchId,
            })
        .toList());
  }

  Future<void> recordAuditLog(
      String shopId, String username, String action, String details,
      {String branchId = 'main', String? id}) async {
    final logId = id ?? _uuid.v4();
    final entry = AuditLogsCompanion.insert(
      id: logId,
      shopId: shopId,
      username: username,
      action: action,
      details: details,
      timestamp: DateTime.now(),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
      branchId: Value(branchId),
    );
    await _db.into(_db.auditLogs).insertOnConflictUpdate(entry);

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'audit_logs',
      recordId: logId,
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
    final shopId = data['shopId']?.toString() ?? '';
    if (shopId.isEmpty) return;

    final type = data['type']?.toString() ?? 'info';
    final itemId = data['itemId']?.toString();
    final branchId = data['branchId']?.toString();

    // ── Stock-level alerts: UPSERT instead of duplicating ──────────────────
    // For recurring stock alerts (low_stock, out_of_stock, expired, expiring_soon),
    // update the existing active record rather than creating a new one.
    // This guarantees at most ONE active alert per product per branch per type.
    const _stockAlertTypes = {
      'low_stock',
      'out_of_stock',
      'expired',
      'expiring_soon'
    };
    if (_stockAlertTypes.contains(type) && itemId != null) {
      try {
        final q = _db.select(_db.notifications)
          ..where((t) {
            Expression<bool> branchMatch;
            if (branchId == null || branchId.isEmpty) {
              branchMatch = t.branchId.isNull();
            } else {
              branchMatch = t.branchId.equals(branchId);
            }
            return t.shopId.equals(shopId) &
                t.type.equals(type) &
                t.itemId.equals(itemId) &
                t.isRead.equals(false) &
                branchMatch;
          });
        final existing = await q.get();
        if (existing.isNotEmpty) {
          // Update body and timestamp so the UI reflects the latest stock state.
          await (_db.update(_db.notifications)
                ..where((t) => t.id.equals(existing.first.id)))
              .write(NotificationsCompanion(
            body: Value(data['message']?.toString() ?? ''),
            timestamp: Value(DateTime.now()),
            lastModified: Value(DateTime.now().toUtc()),
            syncStatus: const Value('pendingUpload'),
          ));
          debugPrint(
              '[DRIFT NOTIFICATION] Updated $type alert for $itemId in $branchId');
          return;
        }
      } catch (_) {}
    } else {
      // For non-stock alerts, guard against duplicates within 6 hours.
      try {
        final targetRole = data['targetRole']?.toString();
        final route = data['route']?.toString();
        final since = DateTime.now().toUtc().subtract(const Duration(hours: 6));
        final q = _db.select(_db.notifications)
          ..where((t) {
            final targetMatch = targetRole == null
                ? const Constant<bool>(true)
                : t.targetRole.equals(targetRole);
            final itemMatch = itemId == null
                ? const Constant<bool>(true)
                : t.itemId.equals(itemId);
            final routeMatch = route == null
                ? const Constant<bool>(true)
                : t.route.equals(route);
            return t.shopId.equals(shopId) &
                t.type.equals(type) &
                t.isRead.equals(false) &
                t.timestamp.isBiggerOrEqualValue(since) &
                targetMatch &
                itemMatch &
                routeMatch;
          });
        final existing = await q.get();
        if (existing.isNotEmpty) return;
      } catch (_) {}
    }

    final entry = NotificationsCompanion.insert(
      id: data['id'] ?? _uuid.v4(),
      shopId: shopId,
      title: data['title'] ?? 'System Alert',
      body: data['message'] ?? '',
      type: type,
      priority: Value(data['priority']?.toString() ?? 'normal'),
      targetRole: Value(data['targetRole']?.toString()),
      itemId: Value(itemId),
      branchId: Value(branchId),
      relatedEntityId: Value(data['relatedEntityId']?.toString()),
      createdBy: Value(data['createdBy']?.toString()),
      route: Value(data['route']?.toString()),
      payloadJson: Value(data['payloadJson']?.toString()),
      timestamp: Value(DateTime.now()),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
    );
    await _db
        .into(_db.notifications)
        .insert(entry, mode: InsertMode.insertOrReplace);
    debugPrint(
        '[DRIFT NOTIFICATION] ${data['title']}: ${data['message'] ?? ''}');

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId ?? 'main',
      table: 'notifications',
      recordId: entry.id.value,
      operation: 'upsert',
      payload: {
        ...data,
        'id': entry.id.value,
        'shopId': shopId,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> saveProductStock({
    required String shopId,
    required String productId,
    required String branchId,
    required double quantity,
    bool queueSync = true,
  }) async {
    await _db.into(_db.productStocks).insertOnConflictUpdate(
          ProductStocksCompanion.insert(
            shopId: shopId,
            productId: productId,
            branchId: branchId,
            quantity: Value(quantity),
            syncStatus: queueSync
                ? const Value('pendingUpload')
                : const Value('synced'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
    if (!queueSync) return;
    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'product_stocks',
      recordId: '$productId@$branchId',
      operation: 'upsert',
      payload: {
        'shopId': shopId,
        'productId': productId,
        'branchId': branchId,
        'quantity': quantity,
      },
    );
  }

  Stream<List<Map<String, dynamic>>> watchNotifications(String shopId,
      {String? branchId}) {
    final query = _db.select(_db.notifications)
      ..where((t) => t.shopId.equals(shopId) & t.isRead.equals(false))
      ..orderBy([
        (t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.desc)
      ]);
    return query.watch().map((rows) => rows
        .map((r) => {
              'id': r.id,
              'title': r.title,
              'message': r.body,
              'type': r.type,
              'priority': r.priority,
              'relatedEntityId': r.relatedEntityId,
              'createdBy': r.createdBy,
              'itemId': r.itemId,
              'branchId': r.branchId,
              'isRead': r.isRead,
              'route': r.route,
              'payloadJson': r.payloadJson,
              'timestamp': r.timestamp.toIso8601String(),
            })
        .toList());
  }

  Future<void> markNotificationAsRead(String id) async {
    await (_db.update(_db.notifications)..where((t) => t.id.equals(id)))
        .write(const NotificationsCompanion(isRead: Value(true)));
  }

  Future<void> clearProductNotifications(
      String shopId, String productId, String type,
      {String? branchId}) async {
    final query = _db.update(_db.notifications)
      ..where((t) {
        Expression<bool> branchFilter = const Constant(true);
        if (branchId != null && branchId.isNotEmpty) {
          branchFilter = branchId == 'main'
              ? (t.branchId.equals('main') | t.branchId.isNull())
              : t.branchId.equals(branchId);
        }
        return t.shopId.equals(shopId) &
            t.itemId.equals(productId) &
            t.type.equals(type) &
            branchFilter;
      });
    await query.write(const NotificationsCompanion(isRead: Value(true)));
  }

  Future<void> markAllNotificationsAsRead(String shopId) async {
    await (_db.update(_db.notifications)..where((t) => t.shopId.equals(shopId)))
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

  /// Scans all products for a shop and emits deduplicated expiry notifications:
  /// - "expiry_warning"  → product expiring within 7 days (not yet expired)
  /// - "expired_product" → product already past its expiry date
  ///
  /// Deduplication is handled inside addNotification() (24 h window per type+itemId).
  Future<void> checkAndNotifyExpiry(String shopId) async {
    final sw = Stopwatch()..start();
    try {
      final now = DateTime.now();
      final products = await (_db.select(_db.products)
            ..where((t) => t.shopId.equals(shopId))
            ..where((t) => t.expiryDate.isNotNull()))
          .get();

      var processed = 0;
      for (final p in products) {
        final exp = p.expiryDate;
        if (exp == null) continue;
        final days = exp.difference(now).inDays;
        final name = p.name;
        final pid = p.id;

        if (days < 0) {
          await addNotification({
            'shopId': shopId,
            'title': '⚠️ Expired Product',
            'message':
                '"$name" expired ${days.abs()} day(s) ago. Remove from stock immediately.',
            'type': 'expired_product',
            'priority': 'high',
            'itemId': pid,
            'route': '/inventory',
          });
        } else if (days <= 7) {
          await addNotification({
            'shopId': shopId,
            'title': '🕐 Expiring Soon',
            'message':
                '"$name" expires in $days day(s). Take action before it\'s too late.',
            'type': 'expiry_warning',
            'priority': days <= 2 ? 'high' : 'normal',
            'itemId': pid,
            'route': '/inventory',
          });
        }
        processed++;
        if (processed % 20 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      PerfLogger.logPerformance('Expiry scan for $shopId ($processed products)',
          sw.elapsedMilliseconds);
    } catch (e) {
      debugPrint('[EXPIRY CHECK] Error: \$e');
    }
  }

  Future<void> update(
    String table,
    String id,
    Map<String, dynamic> data, {
    bool queueSync = true,
  }) async {
    final String shopId = data['shopId']?.toString() ?? 'default_shop';
    final String branchId = data['branchId']?.toString() ?? 'main';

    if (table == 'products' || table == 'items') {
      final expiryVal =
          parseDT(data['expiry'] ?? data['expiryDate'] ?? data['exp']);
      final entry = ProductsCompanion(
        quantity: data['quantity'] != null
            ? Value(_toDouble(data['quantity']))
            : const Value.absent(),
        name: data['name'] != null
            ? Value(data['name'] as String)
            : const Value.absent(),
        barcode: data['barcode'] != null
            ? Value(data['barcode'] as String)
            : const Value.absent(),
        branchId: data['branchId'] != null
            ? Value(data['branchId'] as String)
            : const Value.absent(),
        batchNumber: data['batchNumber'] != null
            ? Value(data['batchNumber'] as String)
            : const Value.absent(),
        lowStockThreshold: data['lowStockThreshold'] != null
            ? Value(data['lowStockThreshold'] as int)
            : const Value.absent(),
        buyingPrice: data['buyingPrice'] != null
            ? Value(_toDouble(data['buyingPrice']))
            : const Value.absent(),
        sellingPrice: data['sellingPrice'] != null
            ? Value(_toDouble(data['sellingPrice']))
            : const Value.absent(),
        expiryDate: (data.containsKey('expiry') ||
                data.containsKey('expiryDate') ||
                data.containsKey('exp'))
            ? Value(expiryVal)
            : const Value.absent(),
        lastModified: Value(DateTime.now()),
        syncStatus:
            queueSync ? const Value('pendingUpload') : const Value('synced'),
      );
      await (_db.update(_db.products)
            ..where((t) => t.id.equals(id) & t.branchId.equals(branchId)))
          .write(entry);

      // Bug #1 (Legacy): Ensure product_stocks remains synced with products table during flat updates
      if (data['quantity'] != null) {
        await saveProductStock(
          shopId: shopId,
          productId: id,
          branchId: branchId,
          quantity: _toDouble(data['quantity']),
          queueSync: queueSync,
        );
      }

      if (queueSync) {
        await enqueueOutboxManual(
            shopId: shopId,
            branchId: branchId,
            table: 'products',
            recordId: id,
            operation: 'update',
            payload: data);
      }
    } else if (table == 'batches') {
      final expiryVal =
          parseDT(data['expiry'] ?? data['expiryDate'] ?? data['exp']);
      final entry = BatchesCompanion(
        quantity: data['quantity'] != null
            ? Value(_toDouble(data['quantity']))
            : const Value.absent(),
        buyingPrice: data['buyingPrice'] != null
            ? Value(_toDouble(data['buyingPrice']))
            : const Value.absent(),
        sellingPrice: data['sellingPrice'] != null
            ? Value(_toDouble(data['sellingPrice']))
            : const Value.absent(),
        expiryDate: (data.containsKey('expiry') ||
                data.containsKey('expiryDate') ||
                data.containsKey('exp'))
            ? Value(expiryVal)
            : const Value.absent(),
        lastModified: Value(DateTime.now()),
        syncStatus:
            queueSync ? const Value('pendingUpload') : const Value('synced'),
      );
      await (_db.update(_db.batches)..where((t) => t.id.equals(id)))
          .write(entry);
      if (queueSync) {
        await enqueueOutboxManual(
            shopId: shopId,
            branchId: branchId,
            table: 'batches',
            recordId: id,
            operation: 'update',
            payload: data);
      }
    } else if (table == 'sales') {
      // Fetch the full current sale record so we can include batchId & batchAllocations
      // in the outbox payload — secondary devices NEED these to restore the right batch on refund.
      final currentSale = await (_db.select(_db.sales)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      final entry = SalesCompanion(
        debtRemaining: data['debtRemaining'] != null
            ? Value((data['debtRemaining'] as num).toDouble())
            : const Value.absent(),
        amountPaid: data['amountPaid'] != null
            ? Value((data['amountPaid'] as num).toDouble())
            : const Value.absent(),
        isDebt: data['isDebt'] != null
            ? Value(data['isDebt'] == true || data['isDebt'] == 1)
            : const Value.absent(),
        refundedQuantity: data['refundedQuantity'] != null
            ? Value((data['refundedQuantity'] as num).toDouble())
            : const Value.absent(),
        lastModified: Value(DateTime.now()),
        syncStatus: const Value('pendingUpload'),
      );
      await (_db.update(_db.sales)..where((t) => t.id.equals(id))).write(entry);
      // Build a complete payload that always carries batchId + batchAllocations
      final outboxPayload = <String, dynamic>{
        ...data,
        'shopId': shopId,
        'branchId': branchId,
        'id': id,
        if (currentSale != null &&
            (data['batchId'] == null || data['batchId'].toString().isEmpty))
          'batchId': currentSale.batchId,
        if (currentSale != null) 'itemId': currentSale.itemId,
        if (currentSale != null) 'quantity': currentSale.quantity,
        if (currentSale != null) 'itemName': currentSale.itemName,
        if (data['batchAllocations'] != null)
          'batchAllocations': data['batchAllocations'],
        if (data['batch_allocations'] != null)
          'batch_allocations': data['batch_allocations'],
      };
      await enqueueOutboxManual(
          shopId: shopId,
          branchId: branchId,
          table: 'sales',
          recordId: id,
          operation: 'update',
          payload: outboxPayload);
    } else if (table == 'purchases') {
      final entry = PurchasesCompanion(
        supplierName: data['supplierName'] != null
            ? Value(data['supplierName'] as String)
            : const Value.absent(),
        unitCost: data['unitCost'] != null
            ? Value(_toDouble(data['unitCost']))
            : const Value.absent(),
        totalCost: data['totalCost'] != null
            ? Value(_toDouble(data['totalCost']))
            : const Value.absent(),
        syncStatus: const Value('pendingUpload'),
      );
      await (_db.update(_db.purchases)..where((t) => t.id.equals(id)))
          .write(entry);
      await enqueueOutboxManual(
          shopId: shopId,
          branchId: branchId,
          table: 'purchases',
          recordId: id,
          operation: 'update',
          payload: data);
    }
  }

  static bool _parseIsActive(dynamic val) {
    if (val == null) return true;
    if (val == true || val == 1) return true;
    if (val == false || val == 0) return false;
    final s = val.toString().trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return true;
  }

  Future<void> saveUserRecord(
    Map<String, dynamic> data, {
    bool isFromSync = false,
  }) async {
    final String? uid = data['uid']?.toString() ?? data['id']?.toString();
    if (uid == null || uid.isEmpty) return;

    final email = data['email']?.toString().trim().toLowerCase() ?? '';
    final username = data['username']?.toString().trim().toLowerCase() ?? '';

    var shopId =
        data['shopId']?.toString() ?? data['businessId']?.toString() ?? '';
    final activeShopId = (await getSetting('active_shop_id')) ??
        (await getSetting('identity_business_id')) ??
        '';

    // BUSINESS ISOLATION GUARD: Never save synced user records originating from another business
    if (isFromSync &&
        shopId.isNotEmpty &&
        activeShopId.isNotEmpty &&
        shopId != activeShopId) {
      debugPrint(
          '[SECURITY] saveUserRecord rejected sync for user $uid: shopId ($shopId) != activeShopId ($activeShopId)');
      return;
    }

    if (shopId.isEmpty || shopId == 'default_shop') {
      shopId = activeShopId.isNotEmpty ? activeShopId : 'default_shop';
    }

    // Lookup existing user by uid first, then by email/username WITHIN THE SAME SHOP to avoid duplicate rows
    var existing = await (_db.select(_db.users)
          ..where((t) => t.uid.equals(uid)))
        .getSingleOrNull();

    if (existing == null &&
        shopId.isNotEmpty &&
        (email.isNotEmpty || username.isNotEmpty)) {
      final candidates = await (_db.select(_db.users)
            ..where((t) => t.shopId.equals(shopId)))
          .get();
      for (final u in candidates) {
        if ((email.isNotEmpty && u.email.trim().toLowerCase() == email) ||
            (username.isNotEmpty &&
                u.username.trim().toLowerCase() == username)) {
          existing = u;
          if (u.uid != uid) {
            await (_db.delete(_db.users)..where((t) => t.uid.equals(u.uid)))
                .go();
          }
          break;
        }
      }
    }

    // Preserve existing local SHA-256 passwordHash when no hash is provided or when sync brings a cloud bcrypt hash.
    // This prevents cloud sync from overwriting local SHA-256 hashes used for offline password verification.
    String? finalPasswordHash =
        data['passwordHash']?.toString() ?? data['password_hash']?.toString();
    if (existing != null &&
        existing.passwordHash != null &&
        existing.passwordHash!.isNotEmpty) {
      final existingLocalIsSha256 =
          !existing.passwordHash!.startsWith(RegExp(r'^\$2[aby]\$'));
      final incomingIsBcrypt = finalPasswordHash != null &&
          finalPasswordHash.startsWith(RegExp(r'^\$2[aby]\$'));
      if (finalPasswordHash == null ||
          finalPasswordHash.isEmpty ||
          (isFromSync && existingLocalIsSha256 && incomingIsBcrypt)) {
        finalPasswordHash = existing.passwordHash;
      }
    }

    final String roles = data['roles'] is List
        ? (data['roles'] as List).join(';')
        : (data['roles']?.toString() ?? 'inventoryStaff');

    final String branchId =
        data['branchId']?.toString() ?? data['branch_id']?.toString() ?? 'main';

    final bool isNew = existing == null;

    final entry = UsersCompanion.insert(
      uid: uid,
      email: data['email']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      fullName:
          Value(data['fullName']?.toString() ?? data['name']?.toString() ?? ''),
      roles: roles,
      shopId: shopId,
      branchId: Value(branchId),
      branchName: Value(data['branchName']?.toString() ??
          data['branch_name']?.toString() ??
          'Main Branch'),
      currency: Value(data['currency']?.toString() ?? 'USD'),
      permissions: Value(data['permissions'] is Map
          ? jsonEncode(data['permissions'])
          : data['permissions']?.toString()),
      passwordHash: Value(finalPasswordHash),
      isActive: Value(_parseIsActive(data['isActive'] ?? data['is_active'])),
    );
    await _db.into(_db.users).insertOnConflictUpdate(entry);

    // Only enqueue outbox events for locally-originated changes, not sync downloads.
    if (!isFromSync) {
      final List<String> parsedRoles = data['roles'] is List
          ? (data['roles'] as List).map((e) => e.toString()).toList()
          : [data['roles']?.toString() ?? 'inventoryStaff'];

      dynamic parsedPerms = data['permissions'];
      if (parsedPerms is String) {
        try {
          parsedPerms = jsonDecode(parsedPerms);
        } catch (_) {}
      }

      final activeUser = await getCachedUser();
      final actorUserId = activeUser?['uid'] ?? data['actor_user_id'] ?? shopId;

      final payload = <String, dynamic>{
        'uid': uid,
        'id': uid,
        'username': data['username']?.toString() ?? '',
        'email': data['email']?.toString() ?? '',
        'fullName':
            data['fullName']?.toString() ?? data['name']?.toString() ?? '',
        'roles': parsedRoles,
        'role': parsedRoles.isNotEmpty ? parsedRoles.first : 'inventoryStaff',
        'shopId': shopId,
        'branchId': branchId,
        'branchName': data['branchName']?.toString() ?? 'Main Branch',
        'actor_user_id': actorUserId,
        if (data['password'] != null) 'password': data['password'].toString(),
        'permissions': parsedPerms ??
            {
              'canManageInventory': true,
              'canManageSales': true,
              'canManagePurchases': true,
              'canManageCustomers': true,
              'canManageStockTransfers': true,
              'canViewReports': true,
              'canViewFinancialData': true,
              'canManageUsers': true,
              'canManageSettings': true,
              'canManageBilling': true,
              'canManageBranches': true,
              'canViewNotifications': true,
            },
        'isActive': _parseIsActive(data['isActive'] ?? data['is_active']),
      };

      final outbox = OutboxService(_db);
      final eventType =
          isNew ? SyncEventType.USER_CREATED : SyncEventType.USER_UPDATED;
      final outboxEventId = await outbox.addEvent(
        shopId: shopId,
        branchId: branchId,
        userId: uid,
        eventType: eventType,
        entityType: 'users',
        entityId: uid,
        payload: payload,
      );

      final insertedOutboxRow = await (_db.select(_db.syncOutbox)
            ..where((t) => t.id.equals(outboxEventId)))
          .getSingleOrNull();
      debugPrint(
          '[OUTBOX CHECK] event_id=$outboxEventId status=${insertedOutboxRow?.status} created_at=${insertedOutboxRow?.createdAt} business_id=$shopId actor_user_id=$actorUserId target_user_id=$uid');

      debugPrint('[STAFF CREATE TRACE]');
      debugPrint('event_id=$outboxEventId');
      debugPrint('business_id=$shopId');
      debugPrint('target_user_id=$uid');
      debugPrint('stage=OUTBOX_CREATED');
      debugPrint(
          'credential_exists=${data['password'] != null || finalPasswordHash != null}');
      debugPrint('[STAFF IDENTITY TRACE]');
      debugPrint('local_user_id=$uid');
      debugPrint('event_target_user_id=$uid');
      debugPrint('[STAFF BUSINESS TRACE]');
      debugPrint('business_id=$shopId');

      debugPrint('[SYNC TRACE]');
      debugPrint('event_id=$outboxEventId');
      debugPrint('stage=LOCAL_CREATED');
      debugPrint('success=true');
      debugPrint('[SYNC TRACE]');
      debugPrint('event_id=$outboxEventId');
      debugPrint('stage=OUTBOX_INSERTED');
      debugPrint('success=true');

      debugPrint('[USER TRACE]');
      debugPrint('event_id=$outboxEventId');
      debugPrint('business_id=$shopId');
      debugPrint('actor_user_id=$actorUserId');
      debugPrint('target_user_id=$uid');
      debugPrint('username=${payload['username']}');
      debugPrint('email=${payload['email']}');
      debugPrint('event_type=${eventType.name}');
      debugPrint('[USER TRACE]\nlocal_created=true');
      debugPrint('[USER TRACE]\noutbox_inserted=true');
      debugPrint(
          '[ACCOUNT SYNC] Event enqueued: type=${eventType.name}, target_user_id=$uid, target_username=${payload['username']}, target_email=${payload['email']}, roles=$parsedRoles, branch_id=$branchId, sync_status=pendingUpload');
    } else {
      debugPrint('[USER TRACE]');
      debugPrint('target_user_id=$uid');
      debugPrint('username=${data['username']}');
      debugPrint('email=${data['email']}');
      debugPrint('event_type=USER_CREATED');
      debugPrint('[USER TRACE]\nreceiving_device_applied=true');
      debugPrint('[USER TRACE]\nreceiving_device_persisted=true');
    }
  }

  Future<void> updateUserPassword(String uid, String newPasswordHash,
      {bool isFromSync = false}) async {
    final userRow = await (_db.select(_db.users)
          ..where((t) => t.uid.equals(uid)))
        .getSingleOrNull();
    await (_db.update(_db.users)..where((t) => t.uid.equals(uid)))
        .write(UsersCompanion(passwordHash: Value(newPasswordHash)));
    debugPrint('[SECURITY] Local password updated for uid=$uid');

    if (!isFromSync && userRow != null) {
      final outbox = OutboxService(_db);
      final activeUser = await getCachedUser();
      final actorUserId = activeUser?['uid'] ?? userRow.shopId;
      await outbox.addEvent(
        shopId: userRow.shopId,
        branchId: userRow.branchId ?? 'main',
        userId: actorUserId,
        eventType: SyncEventType.USER_UPDATED,
        entityType: 'users',
        entityId: uid,
        payload: {
          'id': uid,
          'uid': uid,
          'shopId': userRow.shopId,
          'branchId': userRow.branchId ?? 'main',
          'username': userRow.username,
          'email': userRow.email,
          if (userRow.roles.isNotEmpty) 'role': userRow.roles.split(';').first,
          if (userRow.roles.isNotEmpty) 'roles': userRow.roles.split(';'),
          if (newPasswordHash.isNotEmpty) 'isPasswordChange': true,
          'actor_user_id': actorUserId,
        },
      );
      debugPrint(
          '[ACCOUNT SYNC] Password change event enqueued: type=USER_UPDATED, target_user_id=$uid');
    }
  }

  // --- CRUD HELPERS ---

  Future<void> deleteShopAndAccount(String shopId,
      {bool isFromSync = false}) async {
    final activeUser = await getCachedUser();
    if (shopId.isNotEmpty) {
      await (_db.delete(_db.products)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.productStocks)
            ..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.sales)..where((t) => t.shopId.equals(shopId))).go();
      await (_db.delete(_db.suppliers)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.purchases)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.batches)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.auditLogs)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.users)..where((t) => t.shopId.equals(shopId))).go();
      await (_db.delete(_db.branches)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.notifications)
            ..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.subscriptions)
            ..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.syncOutbox)..where((t) => t.shopId.equals(shopId)))
          .go();
      await (_db.delete(_db.appSettings)
            ..where((t) => t.key.equals('sync_cursor_$shopId')))
          .go();
      await (_db.delete(_db.appSettings)
            ..where((t) => t.key.equals('active_shop_id')))
          .go();
    }
    // Always wipe all local users, cached session, and identity tokens on shop/account deletion
    await _db.delete(_db.users).go();
    await clearCachedUser();
    await IdentityService(this).clearIdentity();

    if (!isFromSync && shopId.isNotEmpty) {
      final outbox = OutboxService(_db);
      await outbox.addEvent(
        shopId: shopId,
        branchId: activeUser?['branchId'] ?? 'main',
        userId: activeUser?['uid'] ?? shopId,
        eventType: SyncEventType.SHOP_DELETED,
        entityType: 'shops',
        entityId: shopId,
        payload: {
          'shopId': shopId,
          'businessId': shopId,
          'business_id': shopId,
          'isActive': false,
          'is_active': false,
          'event_type': 'SHOP_DELETED',
        },
      );
      debugPrint(
          '[ACCOUNT SYNC] Event enqueued: type=SHOP_DELETED, shopId=$shopId, sync_status=pendingUpload');
    }
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
          data['shopId'], data['username'], data['action'], data['details'],
          branchId: data['branchId'] ?? 'main');
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
    final rawExp = data['expiry'] ?? data['exp'] ?? data['expiryDate'];
    DateTime? expiry;
    if (rawExp is DateTime)
      expiry = rawExp;
    else if (rawExp != null) expiry = parseDT(rawExp);

    if (expiry != null) {
      expiry = DateTime.utc(expiry.year, expiry.month, expiry.day);
    }

    final entry = BatchesCompanion.insert(
      id: recordId,
      shopId: shopId,
      itemId: data['itemId'] ?? '',
      quantity: _toDouble(data['quantity']),
      buyingPrice: _toDouble(data['buyingPrice']),
      sellingPrice: Value(_toDouble(data['sellingPrice'])),
      expiryDate: Value(expiry),
      batchNumber: Value(data['batchNumber']?.toString()),
      timestamp: DateTime.now().toUtc(),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
      branchId: Value(branchId),
      type: Value(data['type']?.toString()),
    );

    await _db.into(_db.batches).insert(entry, mode: InsertMode.insertOrReplace);

    await enqueueOutboxManual(
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
    if (rawExp is DateTime)
      expiry = rawExp;
    else if (rawExp is String) expiry = DateTime.tryParse(rawExp);

    final entry = PurchasesCompanion.insert(
      id: recordId,
      shopId: shopId,
      itemId: data['itemId'],
      itemName: data['itemName'] ?? '',
      barcode: Value(data['barcode']?.toString() ?? ''),
      quantity: _toDouble(data['quantity']),
      unitCost: _toDouble(data['unitCost']),
      totalCost: _toDouble(data['totalCost']),
      supplierName: Value(data['supplierName']?.toString()),
      expiryDate: Value(expiry),
      timestamp: DateTime.now().toUtc(),
      syncStatus: const Value('pendingUpload'),
      lastModified: Value(DateTime.now().toUtc()),
      branchId: Value(branchId),
    );
    await _db
        .into(_db.purchases)
        .insert(entry, mode: InsertMode.insertOrReplace);

    await enqueueOutboxManual(
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
      final rows =
          await (_db.select(_db.products)..where((t) => t.id.equals(id))).get();
      if (rows.isEmpty) return;

      for (final row in rows) {
        await (_db.update(_db.products)
              ..where((t) => t.id.equals(id) & t.branchId.equals(row.branchId)))
            .write(ProductsCompanion(
          syncStatus: const Value('pendingDelete'),
          lastModified: Value(DateTime.now().toUtc()),
        ));

        await enqueueOutboxManual(
          shopId: row.shopId,
          branchId: row.branchId,
          table: 'products',
          recordId: id,
          operation: 'delete',
          payload: {'id': id, 'shopId': row.shopId, 'branchId': row.branchId},
        );
      }
    } else if (table == 'users') {
      final userRow = await (_db.select(_db.users)
            ..where((t) => t.uid.equals(id)))
          .getSingleOrNull();
      await (_db.delete(_db.users)..where((t) => t.uid.equals(id))).go();
      if (userRow != null) {
        final outbox = OutboxService(_db);
        await outbox.addEvent(
          shopId: userRow.shopId,
          branchId: userRow.branchId ?? 'main',
          userId: id,
          eventType: SyncEventType.USER_DELETED,
          entityType: 'users',
          entityId: id,
          payload: {
            'uid': id,
            'id': id,
            'username': userRow.username,
            'email': userRow.email,
            'shopId': userRow.shopId,
            'branchId': userRow.branchId ?? 'main',
          },
        );
        debugPrint(
            '[ACCOUNT SYNC] Event enqueued: type=USER_DELETED, target_user_id=$id, target_username=${userRow.username}, target_email=${userRow.email}, roles=${userRow.roles}, branch_id=${userRow.branchId}, sync_status=pendingUpload');
      }
    } else if (table == 'branches') {
      final row = await (_db.select(_db.branches)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.branches)..where((t) => t.id.equals(id))).write(
        BranchesCompanion(
          syncStatus: const Value('pendingDelete'),
          lastModified: Value(DateTime.now().toUtc()),
        ),
      );
      await enqueueOutboxManual(
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
      final rows =
          await (_db.select(_db.products)..where((t) => t.id.isIn(ids))).get();
      for (final r in rows) {
        await (_db.update(_db.products)
              ..where((t) => t.id.equals(r.id) & t.branchId.equals(r.branchId)))
            .write(
          ProductsCompanion(
            syncStatus: const Value('pendingDelete'),
            lastModified: Value(DateTime.now().toUtc()),
          ),
        );
        await enqueueOutboxManual(
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
    await (_db.delete(_db.auditLogs)..where((t) => t.shopId.equals(shopId)))
        .go();
  }

  Future<void> deleteProductFromBranch(
      String shopId, String id, String branchId) async {
    await (_db.update(_db.products)
          ..where((t) =>
              t.id.equals(id) &
              t.branchId.equals(branchId) &
              t.shopId.equals(shopId)))
        .write(ProductsCompanion(
      syncStatus: const Value('pendingDelete'),
      lastModified: Value(DateTime.now().toUtc()),
    ));

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'products',
      recordId: id,
      operation: 'delete',
      payload: {'id': id, 'shopId': shopId, 'branchId': branchId},
    );
  }

  Future<void> updateProductPriceAndQuantity(
      String shopId, String id, String branchId,
      {double? price, double? quantity}) async {
    final companion = ProductsCompanion(
      sellingPrice: price != null ? Value(price) : const Value.absent(),
      quantity: quantity != null ? Value(quantity) : const Value.absent(),
      lastModified: Value(DateTime.now().toUtc()),
      syncStatus: const Value('pendingUpload'),
    );

    await (_db.update(_db.products)
          ..where((t) =>
              t.id.equals(id) &
              t.branchId.equals(branchId) &
              t.shopId.equals(shopId)))
        .write(companion);

    await enqueueOutboxManual(
      shopId: shopId,
      branchId: branchId,
      table: 'products',
      recordId: id,
      operation: 'upsert',
      payload: {
        'id': id,
        'shopId': shopId,
        'branchId': branchId,
        if (price != null) 'sellingPrice': price,
        if (quantity != null) 'quantity': quantity,
      },
    );
  }

  Future<void> factoryReset(String shopId, {bool isFromSync = false}) async {
    // IMPORTANT: if this is the originating device (not a sync-driven reset),
    // enqueue the FACTORY_RESET cloud event BEFORE wiping the outbox table.
    // If we delete the outbox first and then enqueue, the record goes into a freshly
    // cleared table — but the sync push may have already run and the event is lost.
    if (!isFromSync && shopId.isNotEmpty) {
      await enqueueOutboxManual(
        shopId: shopId,
        branchId: 'main',
        table: 'factory_reset',
        recordId: shopId,
        operation: 'FACTORY_RESET',
        payload: {
          'shopId': shopId,
          'action': 'FACTORY_RESET',
          'event_type': 'FACTORY_RESET',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      debugPrint(
          '[FACTORY RESET] FACTORY_RESET sync event enqueued BEFORE local wipe for shop $shopId');
    }

    // Now wipe all operational data in a transaction.
    await _db.transaction(() async {
      // Delete operational data only — NEVER delete user accounts or shared/identity app_settings
      if (shopId.isNotEmpty) {
        await (_db.delete(_db.products)..where((t) => t.shopId.equals(shopId)))
            .go();
        await (_db.delete(_db.sales)..where((t) => t.shopId.equals(shopId)))
            .go();
        await (_db.delete(_db.purchases)..where((t) => t.shopId.equals(shopId)))
            .go();
        await (_db.delete(_db.batches)..where((t) => t.shopId.equals(shopId)))
            .go();
        await (_db.delete(_db.auditLogs)..where((t) => t.shopId.equals(shopId)))
            .go();
        await (_db.delete(_db.branches)..where((t) => t.shopId.equals(shopId)))
            .go();
        await (_db.delete(_db.productStocks)
              ..where((t) => t.shopId.equals(shopId)))
            .go();
        // Delete all outbox items EXCEPT the FACTORY_RESET event we just enqueued.
        // We identify it by operation='FACTORY_RESET' and shopId matching.
        await (_db.delete(_db.syncOutbox)
              ..where((t) =>
                  t.shopId.equals(shopId) &
                  t.operation.isNotValue('FACTORY_RESET')))
            .go();
      } else {
        await _db.delete(_db.products).go();
        await _db.delete(_db.sales).go();
        await _db.delete(_db.purchases).go();
        await _db.delete(_db.batches).go();
        await _db.delete(_db.auditLogs).go();
        await _db.delete(_db.branches).go();
        await _db.delete(_db.productStocks).go();
        await _db.delete(_db.syncOutbox).go();
      }
      if (shopId.isNotEmpty) {
        // IMPORTANT: Do NOT delete the cursor. Resetting cursor to '0' causes the next
        // pull to download ALL historical outbox events (products, batches, sales) from
        // the backend, which immediately repopulates the DB we just cleared.
        // Instead, advance the cursor to NOW so only events AFTER this reset are pulled.
        final resetCursor = DateTime.now().toUtc().toIso8601String();
        await _db.into(_db.appSettings).insertOnConflictUpdate(
              AppSettingsCompanion.insert(
                  key: 'sync_cursor_$shopId', value: resetCursor),
            );
        debugPrint(
            '[FACTORY RESET] Cursor advanced to $resetCursor for shop $shopId — old history will not be re-pulled.');
      }
      // NOTE: users table and app_settings identity rows are intentionally NOT cleared — staff accounts & identity settings are preserved
    });

    debugPrint(
        '[FACTORY RESET] Local factory reset complete for shop $shopId (isFromSync=$isFromSync)');
  }

  Future<void> forceRecalculate(String shopId, String itemId,
      {String? branchId}) async {
    await InventoryRepository()
        .forceRecalculate(shopId, itemId, branchId: branchId);
  }
}
