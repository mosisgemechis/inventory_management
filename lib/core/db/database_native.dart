import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'database_interface.dart';

class LocalDatabaseImpl implements LocalDatabase {
  Database? _db;

  @override
  Future<void> initialize() async {
    if (_db != null) return;
    
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final docs = await getApplicationDocumentsDirectory();
    final path = join(docs.path, 'smart_inventory_v5.db');

    _db = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE products (id TEXT PRIMARY KEY, shopId TEXT, branchId TEXT, name TEXT, barcode TEXT, quantity INTEGER, buyingPrice REAL, sellingPrice REAL, lowStockThreshold INTEGER, batchNumber TEXT, expiryDate TEXT, lastUpdated TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE sales (id TEXT PRIMARY KEY, shopId TEXT, branchId TEXT, itemId TEXT, itemName TEXT, quantity INTEGER, totalPrice REAL, profit REAL, customerName TEXT, timestamp TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE suppliers (id TEXT PRIMARY KEY, shopId TEXT, name TEXT, outstandingDebt REAL, totalPaid REAL, lastUpdated TEXT, isSynced INTEGER DEFAULT 1)');
        await db.execute('CREATE TABLE purchases (id TEXT PRIMARY KEY, shopId TEXT, itemId TEXT, itemName TEXT, quantity INTEGER, unitCost REAL, batchNumber TEXT, expiryDate TEXT, timestamp TEXT, isSynced INTEGER DEFAULT 0)');
        await db.execute('CREATE TABLE audit_logs (id TEXT PRIMARY KEY, shopId TEXT, username TEXT, action TEXT, details TEXT, timestamp TEXT, isSynced INTEGER DEFAULT 0)');
      },
      onUpgrade: (db, oldV, newV) async {
        // Handle migrations
        if (oldV < 5) {
           // Ensure all columns exist
           var tables = ['products', 'sales', 'suppliers', 'purchases', 'audit_logs'];
           for(var t in tables) {
             try { await db.execute('ALTER TABLE $t ADD COLUMN isSynced INTEGER DEFAULT 0'); } catch(_) {}
           }
        }
      }
    );
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> data) async {
    return await _db!.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    return await _db!.query(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    return await _db!.update(table, data, where: where, whereArgs: whereArgs);
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    return await _db!.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Future<void> clear(String table) async {
    await _db!.delete(table);
  }
}

LocalDatabase getDatabase() => LocalDatabaseImpl();
