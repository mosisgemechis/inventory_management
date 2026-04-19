import 'dart:async';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class SyncService {
  static Timer? _syncTimer;
  static bool _isSyncing = false;
  
  static void start(FirestoreService dbService, String shopId) {
    if (_syncTimer != null) return;

    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_isSyncing) return;
      _isSyncing = true;
      try {
        await dbService.syncAll(shopId);
      } catch (e) {
        debugPrint("Background Sync Failed ($shopId): $e");
      } finally {
        _isSyncing = false;
      }
    });
  }

  static void stop() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
