import 'package:hive_flutter/hive_flutter.dart';
import 'database_interface.dart';

class LocalDatabaseImpl implements LocalDatabase {
  @override
  Future<void> initialize() async {
    await Hive.initFlutter();
  }

  Future<Box> _getBox(String table) async {
    return await Hive.openBox(table);
  }

  @override
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final box = await _getBox(table);
    final id = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(id, data);
    return 1;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    final box = await _getBox(table);
    var list = box.values.map((e) => Map<String, dynamic>.from(e)).toList();
    
    // Simple mock filter for 'where' clauses (for sync logic)
    if (where != null && where.contains('isSynced = 0')) {
      return list.where((e) => e['isSynced'] == 0).toList();
    }
    if (where != null && where.contains('id = ?') && whereArgs != null) {
      return list.where((e) => e['id'] == whereArgs[0]).toList();
    }
    
    return list;
  }

  @override
  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    final box = await _getBox(table);
    final id = data['id'];
    if (id != null) {
      await box.put(id, data);
      return 1;
    }
    return 0;
  }

  @override
  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final box = await _getBox(table);
    if (where != null && where.contains('id = ?') && whereArgs != null) {
      await box.delete(whereArgs[0]);
      return 1;
    }
    return 0;
  }

  @override
  Future<void> clear(String table) async {
    final box = await _getBox(table);
    await box.clear();
  }
}

LocalDatabase getDatabase() => LocalDatabaseImpl();
