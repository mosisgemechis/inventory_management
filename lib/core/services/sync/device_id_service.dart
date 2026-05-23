import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const _prefsKey = 'gm_device_id';
  static String? _cached;

  static Future<String> getOrCreate() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.trim().isNotEmpty) {
      _cached = existing;
      return existing;
    }
    final created = const Uuid().v4();
    await prefs.setString(_prefsKey, created);
    _cached = created;
    return created;
  }
}

