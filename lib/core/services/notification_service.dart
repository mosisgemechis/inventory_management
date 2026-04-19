import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'dart:io' show Platform;

class NotificationService {
  static FirebaseMessaging? _messaging;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    _messaging ??= FirebaseMessaging.instance;

    try {
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (!kIsWeb) {
          const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
          const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
          const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
          
          await _localNotifications.initialize(initSettings);

          FirebaseMessaging.onMessage.listen((RemoteMessage message) {
            _showLocalNotification(message);
          });
        }

        saveTokenToFirestore();
      }
    } catch (e) {
      debugPrint('FCM Initialization Skipped: $e');
    }
  }

  static Future<void> saveTokenToFirestore() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    try {
      String? token = await _messaging?.getToken();
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      if (token != null && uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmToken': token,
            'lastActive': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint("FCM Token save suppressed: $e");
        }
      }
    } catch (e) {
      debugPrint('FCM Token generation failed: $e');
    }
  }
  static void _showLocalNotification(RemoteMessage message) {
    if (kIsWeb) return; 

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'inventory_alerts',
      'Inventory Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final String title = message.notification?.title ?? 'Inventory Alert';
    final String body = message.notification?.body ?? 'Update in HQ';
    final int id = message.notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch % 100000;

    _localNotifications.show(id, title, body, details);
  }
}
