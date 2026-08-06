import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'database_service.dart';

/// Push notifications (Android/iOS) → Drift notifications → in-app + OS notifications.
///
/// Contract:
/// - Incoming push is persisted to Drift via [DatabaseService.addNotification].
/// - Drift is the source of truth; OS notifications are shown by [NotificationService]
///   listening to Drift unread rows.
/// - Device token is stored locally + queued to FastAPI via outbox for server-side pushes.
class PushNotificationService {
  PushNotificationService(this._db);

  final DatabaseService _db;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  bool _initialized = false;

  bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!supported) return;

    final messaging = FirebaseMessaging.instance;

    // iOS/macOS permission prompt; Android no-op.
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}

    // Token registration for server-side push fanout.
    try {
      final token = await messaging.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _db.queueDevicePushToken(token.trim());
      }
    } catch (_) {}

    // Token refresh.
    FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
      if (t.trim().isEmpty) return;
      await _db.queueDevicePushToken(t.trim());
    });

    // Foreground messages.
    _onMessageSub = FirebaseMessaging.onMessage.listen((msg) async {
      await _persistIncoming(msg);
    });

    // User taps notification (background/terminated).
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) async {
      await _persistIncoming(msg);
    });

    // App launched from terminated via notification.
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        await _persistIncoming(initial);
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedSub = null;
  }

  Future<void> _persistIncoming(RemoteMessage msg) async {
    final data = Map<String, dynamic>.from(msg.data);

    // Prefer notification title/body when present; fall back to data payload.
    final title = msg.notification?.title ?? data['title']?.toString() ?? 'GM Inventory';
    final body = msg.notification?.body ?? data['message']?.toString() ?? '';
    final type = data['type']?.toString() ?? 'push';
    final shopId = data['shopId']?.toString() ?? (await _db.getSetting('active_shop_id')) ?? '';

    if (shopId.trim().isEmpty) return;

    await _db.addNotification({
      'id': data['id']?.toString(),
      'shopId': shopId,
      'title': title,
      'message': body,
      'type': type,
      'priority': data['priority']?.toString() ?? 'normal',
      'targetRole': data['targetRole']?.toString(),
      'itemId': data['itemId']?.toString(),
      'relatedEntityId': data['relatedEntityId']?.toString(),
      'createdBy': data['createdBy']?.toString(),
      'route': data['route']?.toString(),
      'payloadJson': data.isEmpty ? null : jsonEncode(data),
      'branchId': data['branchId']?.toString() ?? 'main',
    });
  }
}

/// Background handler (Android/iOS) for data-only pushes.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await DatabaseService().ensureInitialized();
    final svc = PushNotificationService(DatabaseService());
    // Use private persist logic by re-parsing into addNotification directly.
    final data = Map<String, dynamic>.from(message.data);
    final title =
        message.notification?.title ?? data['title']?.toString() ?? 'GM Inventory';
    final body =
        message.notification?.body ?? data['message']?.toString() ?? '';
    final shopId = data['shopId']?.toString() ??
        (await DatabaseService().getSetting('active_shop_id')) ??
        '';
    if (shopId.trim().isEmpty) return;
    await DatabaseService().addNotification({
      'id': data['id']?.toString(),
      'shopId': shopId,
      'title': title,
      'message': body,
      'type': data['type']?.toString() ?? 'push',
      'priority': data['priority']?.toString() ?? 'normal',
      'targetRole': data['targetRole']?.toString(),
      'itemId': data['itemId']?.toString(),
      'relatedEntityId': data['relatedEntityId']?.toString(),
      'createdBy': data['createdBy']?.toString(),
      'route': data['route']?.toString(),
      'payloadJson': data.isEmpty ? null : jsonEncode(data),
      'branchId': data['branchId']?.toString() ?? 'main',
    });
    // ignore: unused_local_variable
    svc;
  } catch (_) {}
}

