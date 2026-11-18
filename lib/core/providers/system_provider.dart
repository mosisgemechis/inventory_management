import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/sync/sync_engine_service.dart';
import '../services/sync/connection_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/identity_service.dart';
import '../models/models.dart';
import '../utils/perf_logger.dart';

class SystemProvider with ChangeNotifier {
  bool _isDbReady = false;
  bool get isDbReady => _isDbReady;

  SyncEngineService? _syncEngine;
  SyncEngineService? get syncEngine => _syncEngine;

  ConnectionService? _connection;
  ConnectionService? get connection => _connection;

  NotificationService? _notifications;
  NotificationService? get notifications => _notifications;

  IdentityService? _identity;
  IdentityService? get identity => _identity;

  Future<void> initialize() async {
    final sw = Stopwatch()..start();
    _isDbReady = true;

    // 2. Identity Service (app_settings key/value)
    _identity = IdentityService(DatabaseService());

    // 3. Connection Service (monitors network + backend reachability)
    final connectionSw = Stopwatch()..start();
    _connection = ConnectionService();
    await _connection!.initialize();
    PerfLogger.logPerformance('SystemProvider connection init', connectionSw.elapsedMilliseconds);

    // 4. Background Sync Engine
    final syncSw = Stopwatch()..start();
    _syncEngine = SyncEngineService(
      db: DatabaseService().db,
      connectionService: _connection,
      identityService: _identity,
    )..start();
    PerfLogger.logPerformance('SystemProvider sync start', syncSw.elapsedMilliseconds);

    // 5. Startup flow: check connectivity & perform initial sync if online
    _connection!.checkBackendReachability().then((isOnline) async {
      if (isOnline && _identity != null) {
        final isAuthenticated = await _identity!.isAuthenticated;
        if (isAuthenticated) {
          debugPrint('[SystemProvider] Startup: Online & Authenticated. Running initial data pull...');
          await _syncEngine?.pullInitialData();
        }
      } else {
        debugPrint('[SystemProvider] Startup: Operating in Local Offline Mode.');
      }
    });

    // 6. OS Notifications driven by local Drift rows
    _notifications = NotificationService(DatabaseService());
    unawaited(() async {
      final notifSw = Stopwatch()..start();
      await _notifications!.initialize();
      PerfLogger.logPerformance('SystemProvider notification init', notifSw.elapsedMilliseconds);
    }());

    // Bind to shop once auth session is loaded
    final auth = AuthService();
    auth.initialization.then((_) {
      final user = auth.user;
      final shopId = user?.shopId;
      if (shopId != null && shopId.isNotEmpty) {
        if (user!.hasPermission(AppUser.pViewNotifications)) {
          // ignore: unawaited_futures
          _notifications?.startForShop(shopId);
        }
      }
    });

    notifyListeners();
    PerfLogger.logPerformance('SystemProvider initialize total', sw.elapsedMilliseconds);
  }

  @override
  void dispose() {
    _syncEngine?.dispose();
    _connection?.dispose();
    _notifications?.dispose();
    super.dispose();
  }

  /// Awaits any in-flight sync tick, then stops the engine.
  Future<void> pauseSync() async {
    debugPrint('[SYNC] SystemProvider.pauseSync() called');
    await _syncEngine?.stop();
  }

  /// Restarts the sync engine (e.g. after a new login/signup) and triggers initial pull + sync.
  void resumeSync() {
    debugPrint('[SYNC] SystemProvider.resumeSync() called');
    _syncEngine?.resetAuthFailed();
    _syncEngine?.start();
    unawaited(_syncEngine?.pullInitialData());
    _syncEngine?.syncNow();
  }
}
