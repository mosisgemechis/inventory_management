import 'dart:async';
import 'package:flutter/foundation.dart';

class SyncService {
  // OFFLINE MODE OVERRIDE: 
  // All connectivity and sync services are disabled to support 100% standalone operation.
  
  static void start(dynamic remote, String shopId) {
    debugPrint("OFFLINE MODE: SyncService.start bypassed.");
  }

  static void stop() {
    debugPrint("OFFLINE MODE: SyncService.stop bypassed.");
  }

  static Future<void> triggerSilentSync(String shopId) async {
    return; // Immediate local-only return
  }

  // Stub for any background push routines
  static void runBackgroundSync() {}
}

