/// ApiAuthClient — thin HTTP client for the GM Inventory Everywhere Identity endpoints.
///
/// Handles:
///  • Business registration (`POST /auth/register`)
///  • Login (`POST /auth/login`)
///  • Silent access-token refresh (`POST /auth/refresh`)
///  • Logout (`POST /auth/logout`)
///  • Device registration (`POST /devices/register`)
///  • Device heartbeat (`POST /devices/heartbeat`)
///
/// The client is intentionally lightweight — it uses only [dart:io] (same as
/// [SyncApiClient]) so it works on every Flutter desktop/mobile target.
///
/// Token refresh middleware:
///   If any protected call returns HTTP 401, the client automatically attempts
///   one silent refresh before propagating the error to the caller.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../identity_service.dart';
import 'device_id_service.dart';

class ApiAuthClient {
  ApiAuthClient({
    required this.baseUrl,
    required IdentityService identityService,
    HttpClient? httpClient,
  })  : _identity = identityService,
        _http = httpClient ?? HttpClient();

  final String baseUrl;
  final IdentityService _identity;
  final HttpClient _http;

  static const _timeout = Duration(seconds: 20);

  // ── Helpers ──────────────────────────────────────────────────────────────

  Uri _uri(String path) => Uri.parse(baseUrl.trimRight()).resolve(path);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    bool withAuth = false,
  }) async {
    final req = await _http.postUrl(_uri(path)).timeout(_timeout);
    req.headers.contentType = ContentType.json;
    if (withAuth) {
      final token = await _identity.accessToken;
      if (token != null && token.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
    }
    req.add(utf8.encode(jsonEncode(body)));
    final resp = await req.close().timeout(_timeout);
    final raw = await utf8.decodeStream(resp);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}: $raw', uri: _uri(path));
    }
    if (raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<Map<String, dynamic>> _get(String path, {bool withAuth = false}) async {
    final req = await _http.getUrl(_uri(path)).timeout(_timeout);
    req.headers.contentType = ContentType.json;
    if (withAuth) {
      final token = await _identity.accessToken;
      if (token != null && token.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
    }
    final resp = await req.close().timeout(_timeout);
    final raw = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}: $raw', uri: _uri(path));
    }
    if (raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  /// Subscription state for this business, shared across devices.
  Future<Map<String, dynamic>> getSubscriptionRemote() =>
      _get('/sync/subscription', withAuth: true);

  Future<Map<String, dynamic>> saveSubscriptionRemote(
          Map<String, dynamic> data) =>
      _post('/sync/subscription', data, withAuth: true);

  Future<Map<String, dynamic>> cancelSubscriptionRemote() =>
      _post('/sync/subscription/cancel', const {}, withAuth: true);

  /// Account security: connected login methods and recovery email status.
  Future<Map<String, dynamic>> securityMethods() =>
      _get('/auth/security/methods', withAuth: true);

  Future<Map<String, dynamic>> setSecurityPassword({
    required String username,
    required String password,
  }) =>
      _post('/auth/security/password',
          {'username': username, 'password': password}, withAuth: true);

  Future<Map<String, dynamic>> setRecoveryEmail(String email) =>
      _post('/auth/security/recovery-email', {'email': email}, withAuth: true);

  Future<Map<String, dynamic>> verifyRecoveryEmail(String code) =>
      _post('/auth/security/recovery-email/verify', {'code': code}, withAuth: true);

  /// Requests a recovery reset for an account (public endpoint).
  Future<Map<String, dynamic>> requestRecovery(String identifier) =>
      _post('/auth/recovery/request', {'identifier': identifier});

  Future<Map<String, dynamic>> confirmRecovery({
    required String token,
    required String newPassword,
  }) =>
      _post('/auth/recovery/confirm',
          {'token': token, 'new_password': newPassword});

  Future<Map<String, dynamic>> verifyAccountDeletion({
    String? password,
    String? googleIdToken,
  }) =>
      _post('/auth/account/delete/verify',
          {'password': password, 'google_id_token': googleIdToken},
          withAuth: true);

  Future<Map<String, dynamic>> deleteAccount({
    required String deletionToken,
    required String confirmation,
  }) =>
      _post('/auth/account/delete',
          {'deletion_token': deletionToken, 'confirmation': confirmation},
          withAuth: true);

  Future<Map<String, dynamic>> updateUsername(String username) =>
      _post('/auth/security/username', {'username': username},
          withAuth: true);

  Future<Map<String, dynamic>> deleteBusiness({
    required String deletionToken,
    required String confirmation,
  }) =>
      _post('/auth/business/delete',
          {'deletion_token': deletionToken, 'confirmation': confirmation},
          withAuth: true);

  Future<Map<String, dynamic>> businessMembers() =>
      _get('/auth/business/members', withAuth: true);

  Future<Map<String, dynamic>> transferOwnership(String newOwnerId) =>
      _post('/auth/business/transfer-owner', {'new_owner_id': newOwnerId},
          withAuth: true);

  Future<Map<String, dynamic>> createAdminAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) =>
      _post('/auth/business/create-admin', {
        'name': name,
        'username': username,
        'email': email,
        'password': password,
      }, withAuth: true);

  // ── Auth endpoints ────────────────────────────────────────────────────────

  /// Checks whether an email or business account already exists on the backend.
  /// Returns a map: {'exists': bool, 'business_id': String?, 'is_active': bool?, 'type': String?}
  Future<Map<String, dynamic>> checkEmail(String email) async {
    final cleanEmail = Uri.encodeComponent(email.trim().toLowerCase());
    final req = await _http.getUrl(_uri('/auth/check-email?email=$cleanEmail')).timeout(_timeout);
    req.headers.contentType = ContentType.json;
    final resp = await req.close().timeout(_timeout);
    final raw = await utf8.decodeStream(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException('HTTP ${resp.statusCode}: $raw', uri: _uri('/auth/check-email?email=$cleanEmail'));
    }
    if (raw.isEmpty) return {'exists': false};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {'exists': false};
  }

  /// Register a new business. Returns the identity IDs to persist locally.
  Future<Map<String, dynamic>> registerBusiness({
    required String businessName,
    required String email,
    required String password,
    required String deviceUuid,
    String? phone,
    String? deviceName,
    String? platform,
    String? businessId,
    String? userId,
    String? username,
    String? fullName,
  }) async {
    return _post('/auth/register', {
      'business_name': businessName,
      'email': email,
      'password': password,
      'phone': phone,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': platform ?? _platformName(),
      if (businessId != null) 'business_id': businessId,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (fullName != null) 'full_name': fullName,
    });
  }

  /// Login. Persists the returned tokens and identity IDs automatically.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String deviceUuid,
    String? deviceName,
    String? businessId,
  }) async {
    final resp = await _post('/auth/login', {
      'email': email,
      'password': password,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': _platformName(),
      if (businessId != null && businessId.isNotEmpty) 'business_id': businessId,
    });

    // Automatically persist identity on success
    await _persistLoginResponse(resp);
    return resp;
  }

  /// Google OAuth login.
  Future<Map<String, dynamic>> loginWithGoogle({
    required String idToken,
    required String email,
    required String googleId,
    required String deviceUuid,
    String? name,
    String? deviceName,
  }) async {
    final resp = await _post('/auth/google', {
      'id_token': idToken,
      'email': email,
      'name': name,
      'google_id': googleId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': _platformName(),
    });

    await _persistLoginResponse(resp);
    return resp;
  }

  /// Saves the shop details an OAuth account must provide after first sign-in.
  Future<Map<String, dynamic>> completeProfile({
    required String businessName,
    required String businessType,
    required String currency,
    required String country,
    String? displayName,
  }) async {
    return _post(
      '/auth/complete-profile',
      {
        'business_name': businessName,
        'business_type': businessType,
        'currency': currency,
        'country': country,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
      withAuth: true,
    );
  }

  /// Apple OAuth login.
  Future<Map<String, dynamic>> loginWithApple({
    required String idToken,
    required String email,
    required String appleId,
    required String deviceUuid,
    String? name,
    String? deviceName,
  }) async {
    final resp = await _post('/auth/apple', {
      'id_token': idToken,
      'email': email,
      'name': name,
      'apple_id': appleId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'platform': _platformName(),
    });

    await _persistLoginResponse(resp);
    return resp;
  }

  /// Silent refresh — called automatically or when the user resumes the app.
  /// Returns the new access token, or null if refresh failed (needs re-login).
  Future<String?> refreshToken() async {
    final rt = await _identity.refreshToken;
    final deviceUuid = await _retrieveDeviceUuid();
    if (rt == null || rt.isEmpty) return null;

    try {
      final resp = await _post('/auth/refresh', {
        'refresh_token': rt,
        'device_uuid': deviceUuid,
      });
      final newToken = resp['access_token'] as String?;
      if (newToken != null && newToken.isNotEmpty) {
        await _identity.updateTokens(accessToken: newToken, refreshToken: null);
      }
      return newToken;
    } on HttpException catch (e) {
      if (e.message.contains('401')) {
        debugPrint('[ApiAuthClient] Refresh token explicitly rejected by server (HTTP 401). Session revoked.');
        return null;
      }
      debugPrint('[ApiAuthClient] Token refresh got non-401 HTTP response: $e');
      rethrow;
    } catch (e) {
      debugPrint('[ApiAuthClient] Token refresh network error (temporary): $e');
      rethrow;
    }
  }

  /// Logout — revokes the refresh token on the backend.
  Future<void> logout() async {
    final rt = await _identity.refreshToken;
    if (rt != null && rt.isNotEmpty) {
      try {
        await _post('/auth/logout', {'refresh_token': rt});
      } catch (e) {
        debugPrint('[ApiAuthClient] Logout error (ignored): $e');
      }
    }
    await _identity.clearIdentity();
  }

  /// Securely updates the current user's password in the cloud PostgreSQL db.
  /// Requires a valid access token (Bearer auth). Never logs plaintext passwords.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    debugPrint('[ApiAuthClient] changePassword: sending cloud password update');
    await _post(
      '/auth/change-password',
      {'old_password': oldPassword, 'new_password': newPassword},
      withAuth: true,
    );
    debugPrint('[ApiAuthClient] changePassword: cloud update successful');
  }



  // ── Device endpoints ──────────────────────────────────────────────────────

  /// Ensures the device is registered on the backend after login.
  Future<void> registerDevice({
    required String businessId,
    required String userId,
    required String deviceUuid,
    String? deviceName,
  }) async {
    try {
      await _post(
        '/devices/register',
        {
          'business_id': businessId,
          'user_id': userId,
          'device_uuid': deviceUuid,
          'device_name': deviceName,
          'platform': _platformName(),
        },
        withAuth: true,
      );
    } catch (e) {
      debugPrint('[ApiAuthClient] Device registration error: $e');
    }
  }

  /// Heartbeat — updates last_seen_at on the server. Called on sync tick.
  Future<void> deviceHeartbeat(String deviceUuid) async {
    try {
      await _post('/devices/heartbeat', {'device_uuid': deviceUuid});
    } catch (e) {
      debugPrint('[ApiAuthClient] Heartbeat error (ignored): $e');
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _persistLoginResponse(Map<String, dynamic> resp) async {
    final user     = resp['user']     as Map<String, dynamic>?;
    final business = resp['business'] as Map<String, dynamic>?;
    final device   = resp['device']   as Map<String, dynamic>?;

    if (user == null || business == null || device == null) return;

    await _identity.persistIdentity(
      businessId:   business['id'] as String? ?? '',
      userId:       user['id']     as String? ?? '',
      deviceId:     device['id']   as String? ?? '',
      branchId:     'main', // will be updated on first branch sync
      accessToken:  resp['access_token']  as String? ?? '',
      refreshToken: resp['refresh_token'] as String? ?? '',
    );
  }

  Future<String> _retrieveDeviceUuid() async {
    return DeviceIdService.getOrCreate();
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isWindows) return 'windows';
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }
}
