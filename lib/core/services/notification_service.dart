import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:local_notifier/local_notifier.dart';

/// End-to-end local-first notifications:
/// - Drift is source of truth (notifications table).
/// - This service shows OS notifications (Windows/Android) based on unread Drift rows.
/// - Sync to backend is handled by the outbox queue (DatabaseService.addNotification enqueues).
class NotificationService {
  NotificationService(this._db);

  final DatabaseService _db;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  final Set<String> _shownIds = <String>{};
  Timer? _persistTimer;
  String? _shopId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) async {
        // Route handling is UI-level; we store route/entityId in Drift and let UI
        // respond when user opens the in-app notification panel.
        debugPrint('Notification tapped: ${resp.payload}');
      },
    );

    // Android 13+ runtime permission
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    // Windows desktop notifications.
    if (!kIsWeb && Platform.isWindows) {
      try {
        await localNotifier.setup(appName: 'GM Inventory');
      } catch (_) {}
    }
  }

  /// Starts watching Drift notifications and emits OS toasts for new unread ones.
  /// Call once after login when `shopId` is known.
  Future<void> startForShop(String shopId) async {
    _shopId = shopId;
    await _loadShownIds(shopId);
    _sub?.cancel();
    _sub = _db.watchNotifications(shopId).listen((rows) async {
      for (final n in rows) {
        final id = n['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final isRead = (n['isRead'] ?? false) == true;
        if (isRead) continue;
        if (_shownIds.contains(id)) continue;
        _shownIds.add(id);
        _schedulePersistShownIds();
        await _showOsNotification(n);
      }
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _persistTimer?.cancel();
    _persistTimer = null;
  }

  Future<void> _loadShownIds(String shopId) async {
    try {
      final raw = await _db.getSetting('shown_notification_ids_$shopId');
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _shownIds
          ..clear()
          ..addAll(decoded.whereType<String>().where((s) => s.trim().isNotEmpty));
      }
    } catch (_) {}
  }

  void _schedulePersistShownIds() {
    final shopId = _shopId;
    if (shopId == null || shopId.isEmpty) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        final capped = _shownIds.toList(growable: false);
        // Cap persistence to avoid unbounded growth.
        final keep = capped.length > 250 ? capped.sublist(capped.length - 250) : capped;
        await _db.saveSetting('shown_notification_ids_$shopId', jsonEncode(keep));
      } catch (_) {}
    });
  }

  Future<void> _showOsNotification(Map<String, dynamic> n) async {
    final title = n['title']?.toString() ?? 'GM Inventory';
    final body = n['message']?.toString() ?? '';
    final type = n['type']?.toString() ?? 'info';

    // Restrict OS notifications to only essential feedback
    const criticalTypes = [
      'low_stock', 'stock_transfer', 'urgent_alert', 'system_error',
      'expiry_warning', 'expired_product',
    ];
    if (!criticalTypes.contains(type)) {
      debugPrint('Skipping system notification for routine type: $type');
      return;
    }

    if (!kIsWeb && Platform.isWindows) {
      try {
        await localNotifier.notify(
          LocalNotification(
            identifier: n['id']?.toString() ?? '${title.hashCode ^ body.hashCode}',
            title: title,
            body: body,
          ),
        );
        return;
      } catch (_) {}
    }

    final android = AndroidNotificationDetails(
      'gm_inventory_channel',
      'GM Inventory',
      channelDescription: 'GM Inventory notifications',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
    );

    await _plugin.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      NotificationDetails(android: android),
      payload: '$type:${n['relatedEntityId'] ?? n['itemId'] ?? ''}',
    );
  }
}
