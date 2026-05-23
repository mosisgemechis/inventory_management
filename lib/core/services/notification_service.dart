import 'package:flutter/foundation.dart';

class NotificationService {
  // OFFLINE MODE OVERRIDE:
  // Cloud messaging is disabled to prevent background network threads.
  
  static Future<void> initialize() async {
    debugPrint("OFFLINE MODE: NotificationService.initialize bypassed.");
  }

  static Future<void> saveTokenToFirestore() async {
    // No-op in offline mode
  }

  static void showLocalAlert(String title, String body) {
    // Optional: implement local-only notifications if needed, 
    // but for now we keep it minimal.
    debugPrint("LOCAL ALERT: $title - $body");
  }
}

