import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/sync/sync_engine_service.dart';
import '../services/notification_service.dart';
import '../services/push_notification_service.dart';
import '../services/auth_service.dart';
import '../models/models.dart';

class SystemProvider with ChangeNotifier {
  bool _isDbReady = false;
  bool get isDbReady => _isDbReady;

  SyncEngineService? _syncEngine;
  SyncEngineService? get syncEngine => _syncEngine;

  NotificationService? _notifications;
  NotificationService? get notifications => _notifications;

  PushNotificationService? _push;
  PushNotificationService? get push => _push;

  Future<void> initialize() async {
    // 1. Initialize Drift Database
    await DatabaseService().ensureInitialized();
    _isDbReady = true;

    // 2. Start background sync orchestration (never blocks UI; no direct UI→API calls).
    _syncEngine = SyncEngineService(db: DatabaseService().db)..start();

    // 3. OS notifications driven by Drift rows (persisted across restart).
    _notifications = NotificationService(DatabaseService());
    await _notifications!.initialize();

    // 4. Remote push (Android/iOS) persisted into Drift.
    _push = PushNotificationService(DatabaseService());
    await _push!.initialize();

    // Bind to shop once auth session is loaded.
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
  }

  @override
  void dispose() {
    _syncEngine?.dispose();
    _notifications?.dispose();
    _push?.dispose();
    super.dispose();
  }
}
