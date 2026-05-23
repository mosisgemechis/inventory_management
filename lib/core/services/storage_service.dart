import 'package:flutter/foundation.dart';

class StorageService {
  // OFFLINE MODE OVERRIDE:
  // Cloud storage is disabled.

  Future<String?> uploadProductImage(String shopId, String productId, dynamic fileData) async {
    // In standalone mode, we could implement local file system storage,
    // but for now we simply return null to avoid Firebase errors.
    debugPrint("OFFLINE MODE: StorageService.uploadProductImage bypassed.");
    return null;
  }
}

