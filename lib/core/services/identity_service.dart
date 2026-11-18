/// IdentityService — local persistence of the sync identity envelope.
///
/// Stores all identity metadata in the existing Drift [AppSettings] table
/// (key/value) so no schema migrations are needed.
///
/// Identity envelope written after login/register:
/// {
///   business_id, user_id, device_id, branch_id,
///   access_token, refresh_token
/// }
///
/// These values are read by [OutboxService] so every sync event carries
/// the full identity context without coupling to AuthService.
library;

import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'sync/device_id_service.dart';

abstract final class IdentityKeys {
  static const businessId   = 'identity_business_id';
  static const userId       = 'identity_user_id';
  static const deviceId     = 'identity_device_id';   // backend DB id (not UUID)
  static const branchId     = 'identity_branch_id';
  static const accessToken  = 'identity_access_token';
  static const refreshToken = 'identity_refresh_token';
  /// Canonical alias used by the sync engine (already in use as 'access_token').
  static const accessTokenAlias = 'access_token';
}

class IdentityService {
  final DatabaseService _db;
  const IdentityService(this._db);

  // ── Write ────────────────────────────────────────────────────────────────

  /// Called after a successful login or registration response from the backend.
  Future<void> persistIdentity({
    required String businessId,
    required String userId,
    required String deviceId,
    required String branchId,
    required String accessToken,
    required String refreshToken,
  }) async {
    debugPrint('[AUTH TOKEN DEBUG] access token present=${accessToken.isNotEmpty}, length=${accessToken.length}');
    debugPrint('[AUTH TOKEN DEBUG] refresh token present=${refreshToken.isNotEmpty}, length=${refreshToken.length}');
    await Future.wait([
      _db.saveSetting(IdentityKeys.businessId,      businessId),
      _db.saveSetting('active_shop_id',             businessId),
      _db.saveSetting('cloud_business_id',          businessId),
      _db.saveSetting(IdentityKeys.userId,          userId),
      _db.saveSetting(IdentityKeys.deviceId,        deviceId),
      _db.saveSetting(IdentityKeys.branchId,        branchId),
      _db.saveSetting(IdentityKeys.accessToken,     accessToken),
      _db.saveSetting(IdentityKeys.refreshToken,    refreshToken),
      // Keep the legacy key the sync engine already reads:
      _db.saveSetting(IdentityKeys.accessTokenAlias, accessToken),
    ]);
    debugPrint('[BUSINESS ID TRACE] jwt_business_id=$businessId session_business_id=$businessId sync_business_id=$businessId event_business_id=$businessId database_business_id=$businessId');
  }

  /// Update tokens only (called after a token refresh).
  Future<void> updateTokens({
    required String accessToken,
    required String? refreshToken,
  }) async {
    debugPrint('[AUTH TOKEN DEBUG] Updating access token: present=${accessToken.isNotEmpty}, length=${accessToken.length}');
    if (refreshToken != null) {
      debugPrint('[AUTH TOKEN DEBUG] Updating refresh token: present=${refreshToken.isNotEmpty}, length=${refreshToken.length}');
    }
    await _db.saveSetting(IdentityKeys.accessToken,      accessToken);
    await _db.saveSetting(IdentityKeys.accessTokenAlias, accessToken);
    if (refreshToken != null) {
      await _db.saveSetting(IdentityKeys.refreshToken, refreshToken);
    }
  }

  /// Wipe all identity data on logout.
  Future<void> clearIdentity() async {
    debugPrint('[AUTH TOKEN DEBUG] Clearing identity and tokens');
    await Future.wait([
      _db.saveSetting(IdentityKeys.businessId,       ''),
      _db.saveSetting(IdentityKeys.userId,           ''),
      _db.saveSetting(IdentityKeys.deviceId,         ''),
      _db.saveSetting(IdentityKeys.branchId,         ''),
      _db.saveSetting(IdentityKeys.accessToken,      ''),
      _db.saveSetting(IdentityKeys.refreshToken,     ''),
      _db.saveSetting(IdentityKeys.accessTokenAlias, ''),
    ]);
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  Future<String?> get businessId   => _db.getSetting(IdentityKeys.businessId);
  Future<String?> get userId       => _db.getSetting(IdentityKeys.userId);
  Future<String?> get deviceId     => _db.getSetting(IdentityKeys.deviceId);
  Future<String?> get branchId     => _db.getSetting(IdentityKeys.branchId);
  Future<String?> get accessToken  => _db.getSetting(IdentityKeys.accessToken);
  Future<String?> get refreshToken => _db.getSetting(IdentityKeys.refreshToken);

  Future<bool> get isAuthenticated async {
    final token = await accessToken;
    return token != null && token.isNotEmpty;
  }

  /// Returns a fully populated identity envelope for embedding in sync events.
  /// Falls back to the local device UUID if no backend identity is stored yet.
  Future<SyncIdentityEnvelope> getEnvelope() async {
    final deviceUuid    = await DeviceIdService.getOrCreate();
    final results = await Future.wait([
      _db.getSetting(IdentityKeys.businessId),
      _db.getSetting(IdentityKeys.userId),
      _db.getSetting(IdentityKeys.deviceId),
      _db.getSetting(IdentityKeys.branchId),
    ]);
    return SyncIdentityEnvelope(
      businessId: results[0] ?? '',
      userId:     results[1] ?? '',
      deviceId:   results[2] ?? deviceUuid,   // fallback to local UUID
      branchId:   results[3] ?? 'main',
    );
  }
}

/// Immutable identity envelope attached to every outbox event.
///
/// ```json
/// {
///   "business_id": "...",
///   "device_id":   "...",
///   "user_id":     "...",
///   "branch_id":   "..."
/// }
/// ```
class SyncIdentityEnvelope {
  final String businessId;
  final String userId;
  final String deviceId;
  final String branchId;

  const SyncIdentityEnvelope({
    required this.businessId,
    required this.userId,
    required this.deviceId,
    required this.branchId,
  });

  Map<String, String> toMap() => {
    'business_id': businessId,
    'device_id':   deviceId,
    'user_id':     userId,
    'branch_id':   branchId,
  };

  bool get isPopulated =>
      businessId.isNotEmpty && userId.isNotEmpty && deviceId.isNotEmpty;
}
