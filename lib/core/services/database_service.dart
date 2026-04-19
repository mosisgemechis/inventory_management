import '../db/database_interface.dart';
import '../db/database_native.dart' if (dart.library.html) '../db/database_web.dart';

class DatabaseService {
  final LocalDatabase _db = getDatabase();

  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _initialized = false;

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await _db.initialize();
      _initialized = true;
    }
  }

  // Proxies to the platform-specific implementation
  Future<int> saveProduct(Map<String, dynamic> data) async {
    await ensureInitialized();
    return await _db.insert('products', data);
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    await ensureInitialized();
    return await _db.query(table, where: where, whereArgs: whereArgs);
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    await ensureInitialized();
    return await _db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<void> markSynced(String table, String id) async {
    await ensureInitialized();
    await _db.update(table, {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
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
  Future<void> saveSale(Map<String, dynamic> data) async { await _db.insert('sales', data); }
  Future<void> savePurchase(Map<String, dynamic> data) async { await _db.insert('purchases', data); }
  Future<void> saveAuditLog(Map<String, dynamic> data) async { await _db.insert('audit_logs', data); }
  
  // Expose the raw database only if absolutely necessary (try to avoid for cross-platform)
  // For validation_service, let's add a search helper
  Future<List<Map<String, dynamic>>> searchItems(String shopId, String name, String barcode) async {
    await ensureInitialized();
    return await _db.query(
      'products',
      where: 'shopId = ? AND (name = ? OR (barcode != "" AND barcode = ?))',
      whereArgs: [shopId, name, barcode],
    );
  }
}
