import '../db/database_interface.dart';
import '../db/database_native.dart' if (dart.library.html) '../db/database_web.dart';

class DatabaseService {
  final LocalDatabase _db = getDatabase();

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _initialized = false;

  static const Map<String, List<String>> _tableSchemas = {
    'sales': ['id', 'shopId', 'branchId', 'itemId', 'itemName', 'quantity', 'totalPrice', 'profit', 'customerName', 'timestamp', 'isSynced'],
    'purchases': ['id', 'shopId', 'itemId', 'itemName', 'barcode', 'quantity', 'unitCost', 'totalCost', 'supplierName', 'batchNumber', 'expiryDate', 'timestamp', 'isSynced'],
    'audit_logs': ['id', 'shopId', 'username', 'action', 'details', 'timestamp', 'isSynced'],
    'products': ['id', 'shopId', 'branchId', 'name', 'barcode', 'quantity', 'buyingPrice', 'sellingPrice', 'lowStockThreshold', 'batchNumber', 'expiryDate', 'lastUpdated', 'isSynced'],
    'suppliers': ['id', 'shopId', 'name', 'outstandingDebt', 'totalPaid', 'lastUpdated', 'isSynced'],
    'batches': ['id', 'shopId', 'itemId', 'quantity', 'buyingPrice', 'expiryDate', 'batchNumber', 'timestamp', 'isSynced'],
  };

  Map<String, dynamic> sanitize(String table, Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};
    final schema = _tableSchemas[table] ?? [];
    
    data.forEach((key, value) {
      if (schema.isNotEmpty && !schema.contains(key)) return; 
      
      if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      } else if (key == 'quantity' || key.contains('Price') || key.contains('Cost') || key.contains('Profit') || key.contains('Total')) {
        sanitized[key] = (value as num?)?.toDouble() ?? 0.0;
      } else if (value is DateTime) {
        sanitized[key] = value.toIso8601String();
      } else if (value != null && value.runtimeType.toString().contains('Timestamp')) {
        // Safe Firestore Timestamp conversion without requiring direct import here
        try {
          sanitized[key] = (value as dynamic).toDate().toIso8601String();
        } catch (_) {
          sanitized[key] = value.toString();
        }
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await _db.initialize();
      _initialized = true;
    }
  }

  // Proxies to the platform-specific implementation
  Future<int> insert(String table, Map<String, dynamic> data) async {
    await ensureInitialized();
    final sanitized = sanitize(table, data);
    return await _db.insert(table, sanitized);
  }

  Future<int> saveProduct(Map<String, dynamic> data) async {
    return await insert('products', data);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    await ensureInitialized();
    return await _db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    await ensureInitialized();
    final sanitized = sanitize(table, data);
    return await _db.update(table, sanitized, where: where, whereArgs: whereArgs);
  }

  Future<void> markSynced(String table, String id) async {
    await ensureInitialized();
    await _db.update(table, {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    await ensureInitialized();
    await _db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> getUnsynced(String table) async {
    await ensureInitialized();
    return await _db.query(table, where: 'isSynced = 0');
  }

  Future<Map<String, dynamic>?> getById(String table, String id) async {
    await ensureInitialized();
    final res = await _db.query(table, where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  // Table-specific helpers to maintain existing API
  Future<void> saveSale(Map<String, dynamic> data) async { await _db.insert('sales', sanitize('sales', data)); }
  Future<void> savePurchase(Map<String, dynamic> data) async { await _db.insert('purchases', sanitize('purchases', data)); }
  Future<void> saveAuditLog(Map<String, dynamic> data) async { await _db.insert('audit_logs', sanitize('audit_logs', data)); }
  
  Future<List<Map<String, dynamic>>> getAllProducts(String shopId) async {
    await ensureInitialized();
    return await _db.query('products', where: 'shopId = ?', whereArgs: [shopId]);
  }

  Future<List<Map<String, dynamic>>> searchItems(String shopId, String name, String barcode) async {
    await ensureInitialized();
    final b = barcode.trim();
    final n = name.trim().toLowerCase();
    
    if (b.isNotEmpty) {
      final byBar = await _db.query('products', where: 'shopId = ? AND barcode = ?', whereArgs: [shopId, b]);
      if (byBar.isNotEmpty) return byBar;
    }
    
    if (n.isNotEmpty) {
       return await _db.query('products', where: 'shopId = ? AND LOWER(name) = ?', whereArgs: [shopId, n]);
    }
    return [];
  }

  Future<void> factoryReset() async {
    await ensureInitialized();
    for (var table in _tableSchemas.keys) {
      await _db.delete(table);
    }
  }
}
