import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/sync/sync_engine_service.dart';

class SystemProvider with ChangeNotifier {
  bool _isDbReady = false;
  bool get isDbReady => _isDbReady;

  SyncEngineService? _syncEngine;
  SyncEngineService? get syncEngine => _syncEngine;

  Future<void> initialize() async {
    // 1. Initialize Drift Database
    await DatabaseService().ensureInitialized();
    _isDbReady = true;

    // 2. Start background sync orchestration (never blocks UI; no direct UI→API calls).
    _syncEngine = SyncEngineService(db: DatabaseService().db)..start();

    notifyListeners();
  }

  @override
  void dispose() {
    _syncEngine?.dispose();
    super.dispose();
  }
}
