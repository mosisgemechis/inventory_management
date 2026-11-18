import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'sync/connection_service.dart';
import 'sync/api_auth_client.dart';
import 'identity_service.dart';
import 'sync/device_id_service.dart';
import 'sync/bootstrap_sync_service.dart';
import 'google_oauth.dart';
import 'subscription_service.dart';
import '../utils/perf_logger.dart';
import '../../main.dart';
import '../config/app_config.dart';
import '../config/navigation.dart';
import '../providers/system_provider.dart';

class AuthService with ChangeNotifier {
  // Singleton: every AuthService() call returns the same instance.
  // This ensures notifyListeners() always reaches the Provider-registered widget tree.
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Offline-first identity management uses the local SQLite 'users' table.

  AppUser? _user;
  AppUser? get user => _user;

  /// True while a brand-new Google account still has to provide its shop
  /// details (business name, country, currency) before using the app.
  bool _needsGoogleSetup = false;
  bool get needsGoogleSetup => _needsGoogleSetup;

  /// True after Google onboarding while the account still has no additional
  /// GM Inventory Everywhere login (the user is prompted once, and may skip).
  bool _needsSecuritySetup = false;
  bool get needsSecuritySetup => _needsSecuritySetup;
  bool _initialized = false;
  bool get initialized => _initialized;
  bool get isReady => true;

  Future<void> syncStaffIdentities(String shopId) async {} // Stubbed for offline operation

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialization => _initCompleter.future;

  StreamSubscription<Map<String, dynamic>?>? _userWatchSub;

  /// Set by main.dart / SystemProvider so signOut can pause sync before clearing DB.
  SystemProvider? systemProvider;

  bool _isLoggingOut = false;

  void _safeNotify() {
    // Prefer synchronous notify; fall back to post-frame if we're mid-build.
    try {
      notifyListeners();
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void _bindLiveUserUpdates() {
    _userWatchSub?.cancel();
    final uid = _user?.id;
    if (uid == null || uid.isEmpty) return;
    _userWatchSub = DatabaseService().watchUserById(uid).listen((m) async {
      if (m == null) return;
      final next = AppUser.fromMap(m, m['uid']?.toString() ?? uid);
      if (!next.isActive) {
        // Auto-signout if account is disabled.
        await signOut();
        return;
      }
      _user = next;
      // Keep app settings aligned for branch-scoped streams and guards.
      await DatabaseService().saveSetting('active_shop_id', next.shopId);
      await DatabaseService().saveSetting('active_branch_id', next.branchId);
      _safeNotify();
    });
  }


  Future<void> loadSession() async {
    debugPrint("OFFLINE MODE: Loading local enterprise session...");
    final sw = Stopwatch()..start();

    // 1. Load the last active session from the users table first.
    try {
      final cachedSw = Stopwatch()..start();
      final userMap = await DatabaseService().getCachedUser();
      PerfLogger.logPerformance('Auth cached user lookup', cachedSw.elapsedMilliseconds);
      if (userMap != null) {
        _user = AppUser.fromMap(userMap, userMap['uid']);
        _bindLiveUserUpdates();
      } else {
        // 2. Seed the database with a default Admin only when no cached session exists.
        final seedSw = Stopwatch()..start();
        await _seedDefaultAdmin();
        PerfLogger.logPerformance('Auth seed default admin', seedSw.elapsedMilliseconds);

        final refreshSw = Stopwatch()..start();
        final seededUserMap = await DatabaseService().getCachedUser();
        PerfLogger.logPerformance('Auth seeded session lookup', refreshSw.elapsedMilliseconds);
        if (seededUserMap != null) {
          _user = AppUser.fromMap(seededUserMap, seededUserMap['uid']);
          _bindLiveUserUpdates();
        }
      }
    } catch (e) {
      debugPrint("Error loading local session: $e");
    }

    try {
      _needsGoogleSetup =
          await DatabaseService().getSetting('needs_google_setup') == 'true';
      _needsSecuritySetup =
          await DatabaseService().getSetting('needs_security_setup') == 'true';
    } catch (_) {
      _needsGoogleSetup = false;
    }

    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    debugPrint('[AUTH] Session loaded');
    _safeNotify();
    PerfLogger.logPerformance('Auth loadSession total', sw.elapsedMilliseconds);
  }

  Future<void> _seedDefaultAdmin() async {
    try {
      final db = DatabaseService();
      final users = await db.query('users', limit: 1);
      if (users.isEmpty) {
        debugPrint("OFFLINE MODE: No users found. Seeding enterprise administrator...");
        final adminData = {
          'uid': 'admin-uuid-001',
          'email': 'admin@pos.erp',
          'username': 'admin',
          'fullName': 'System Administrator',
          'currency': 'USD',
          'roles': [UserRole.admin.name],
          'shopId': 'shop-main-001',
          'branchId': 'main',
          'branchName': 'Headquarters',
          'permissions': {for (var p in AppUser.allPermissions) p: true},
          'passwordHash': _hashPassword('admin123'),
          'isActive': true,
        };
        await db.saveUserRecord(adminData);
        await db.saveSetting('shopName', 'Enterprise POS System');
      }
    } catch (e) {
      debugPrint("OFFLINE MODE: Seeding error: $e");
    }
  }

  Future<void> signIn(String identifier, String password, {ConnectionService? connectionService, ApiAuthClient? authClient, String? businessId}) async {
    await initialization;

    final inputLower = identifier.trim().toLowerCase();
    final passwordTrimmed = password.trim();
    final hashedInput = _hashPassword(passwordTrimmed);

    debugPrint('[AUTH] Login started for "$inputLower"');
    debugPrint('[STAFF LOGIN TRACE]');
    debugPrint('username=$inputLower');
    debugPrint('business_context=${businessId ?? "auto"}');
    debugPrint('stage=LOGIN_REQUEST');

    debugPrint('[AUTH TRACE] Online login started');

    final connection = connectionService ?? ConnectionService();
    final isOnline = await connection.checkBackendReachability(force: true);
    final hasNet = await connection.hasNetworkInterface();
    debugPrint('[AUTH TRACE] Backend reachable = $isOnline, networkInterface = $hasNet');
    final tryCloud = isOnline;
    debugPrint('[AUTH] Network status: ${tryCloud ? "ONLINE" : "OFFLINE"}');

    if (tryCloud) {
      try {
        // Use connection.baseUrl — this is the URL that checkBackendReachability
        // already verified with a /health probe. Calling AppConfig.apiBaseUrl here
        // can return a stale cached loopback (127.0.0.1) even after ConnectionService
        // has resolved the real backend IP. Sync AppConfig so the rest of the app
        // also uses the correct URL.
        final resolvedUrl = connection.baseUrl;
        AppConfig.setApiBaseUrl(resolvedUrl);
        debugPrint('[AUTH] Attempting cloud login via $resolvedUrl');
        final client = authClient ?? ApiAuthClient(
          baseUrl: resolvedUrl,
          identityService: IdentityService(DatabaseService()),
        );
        final deviceUuid = await DeviceIdService.getOrCreate();
        final cloudResp = await client.login(
          email: inputLower,
          password: passwordTrimmed,
          deviceUuid: deviceUuid,
          businessId: businessId,
        );

        connection.reportSuccess();
        final token = cloudResp['access_token']?.toString();
        debugPrint('[AUTH TRACE] Login response status = 200');
        debugPrint('[AUTH TRACE] Cloud authentication success = true');
        debugPrint('[AUTH TRACE] Token received = ${token != null && token.isNotEmpty}');

        final cloudUser = cloudResp['user'] as Map<String, dynamic>?;
        final cloudUserId = cloudUser?['id']?.toString();
        final cloudShopId = cloudResp['business']?['id']?.toString() ?? cloudUser?['shopId']?.toString() ?? 'shop-cloud-001';

        debugPrint('[AUTH TRACE] Authenticated user id = ${cloudUserId ?? "unknown"}');
        debugPrint('[AUTH TRACE] Business id = $cloudShopId');

        debugPrint('[STAFF LOGIN TRACE]');
        debugPrint('stage=LOGIN_SUCCESS');
        debugPrint('[STAFF IDENTITY TRACE]');
        debugPrint('login_user_id=${cloudUserId ?? "unknown"}');
        debugPrint('[STAFF BUSINESS TRACE]');
        debugPrint('login_business_id=$cloudShopId');

        // 1. Check if local matching user exists
        debugPrint('[AUTH] Checking local database for existing user');
        final localUsers = await DatabaseService().query('users',
            where: 'username = ? OR email = ? OR cloud_user_id = ?',
            whereArgs: [inputLower, inputLower, cloudUserId ?? '']);

        debugPrint('[AUTH] Local user ${localUsers.isNotEmpty ? "found" : "not found"} — upserting');

        final targetUid = (cloudUserId != null && cloudUserId.isNotEmpty)
            ? cloudUserId
            : (localUsers.isNotEmpty ? localUsers.first['uid']?.toString() ?? const Uuid().v4() : const Uuid().v4());

        final rolesList = cloudUser?['roles'] is List
            ? (cloudUser!['roles'] as List).map((e) => e.toString()).toList()
            : [(cloudUser?['role']?.toString() ?? 'inventoryStaff')];

        final Map<String, dynamic> userData = {
          'uid': targetUid,
          'email': cloudUser?['email']?.toString() ?? inputLower,
          'username': cloudUser?['username']?.toString() ?? inputLower.split('@')[0],
          'fullName': cloudUser?['name']?.toString() ?? '',
          'roles': rolesList,
          'shopId': cloudShopId,
          'branchId': cloudUser?['branch_id']?.toString() ?? cloudUser?['branchId']?.toString() ?? 'main',
          'branchName': cloudUser?['branch_name']?.toString() ?? cloudUser?['branchName']?.toString() ?? 'Main Branch',
          'permissions': cloudUser?['permissions'] ?? jsonEncode({for (var p in AppUser.allPermissions) p: true}),
          'passwordHash': hashedInput,
          'isActive': true,
          'cloudUserId': cloudUserId ?? targetUid,
          'syncEnabled': true,
          'lastOnlineLogin': DateTime.now().toUtc().toIso8601String(),
        };
        await DatabaseService().saveUserRecord(userData);

        final currency = await DatabaseService().getSetting('currency') ?? 'USD';
        final Map<String, dynamic> userWithCurrency = <String, dynamic>{...userData, 'currency': currency};
        final newUser = AppUser.fromMap(userWithCurrency, userData['uid'].toString());

        _user = newUser;
        _bindLiveUserUpdates();
        await DatabaseService().cacheUser(userWithCurrency);


        // Immediately run authenticated bootstrap sync & resume sync engine after online login
        systemProvider?.resumeSync();
        unawaited(BootstrapSyncService(connectionService: connection).runBootstrapSync());

        _safeNotify();
        debugPrint("[AUTH] ONLINE AUTH: Login successful & cloud user linked for $identifier");
        return;
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        // 401/403 = authoritative backend rejection (wrong password, deleted, deactivated).
        // These MUST NOT fall through to local auth — that would allow deleted accounts to log in.
        final isAuthoritativeRejection = errStr.contains('401') ||
            errStr.contains('403') ||
            errStr.contains('deactivated') ||
            errStr.contains('deleted') ||
            errStr.contains('invalid email or password') ||
            errStr.contains('invalid credentials') ||
            errStr.contains('account is deactivated') ||
            errStr.contains('shop account is deactivated');

        if (isAuthoritativeRejection) {
          debugPrint('[AUTH] [SECURITY] Cloud returned authoritative rejection — NOT falling back to local auth. reason=${e.toString().replaceAll('\n', ' ')}');
          debugPrint('[STAFF LOGIN TRACE]\nstage=LOGIN_FAILURE\nreason=authoritative_cloud_rejection');
          rethrow;
        }
        if (errStr.contains('socketexception') || errStr.contains('connection refused') || errStr.contains('timeout')) {
          debugPrint('[AUTH] Network connection failed — re-discovering backend...');
          // Force a fresh discovery. This clears stale cache AND the scan cooldown
          // so the subnet probe can find the backend at the Wi-Fi IP.
          final rediscovered = await connection.checkBackendReachability(force: true);
          final freshUrl = connection.baseUrl;
          AppConfig.setApiBaseUrl(freshUrl);
          debugPrint('[AUTH] Retrying cloud login with re-discovered URL = $freshUrl (reachable=$rediscovered)');
          try {
            final retryClient = authClient ?? ApiAuthClient(
              baseUrl: freshUrl,
              identityService: IdentityService(DatabaseService()),
            );
            final deviceUuid = await DeviceIdService.getOrCreate();
            final cloudResp = await retryClient.login(
              email: inputLower,
              password: passwordTrimmed,
              deviceUuid: deviceUuid,
              businessId: businessId,
            );

            connection.reportSuccess();
            debugPrint('[AUTH TRACE] Login response status = 200 (on discovery retry)');
            final cloudUser = cloudResp['user'] as Map<String, dynamic>?;
            final cloudUserId = cloudUser?['id']?.toString();
            final cloudShopId = cloudResp['business']?['id']?.toString() ?? cloudUser?['shopId']?.toString() ?? 'shop-cloud-001';

            final localUsers = await DatabaseService().query('users',
                where: 'username = ? OR email = ? OR cloud_user_id = ?',
                whereArgs: [inputLower, inputLower, cloudUserId ?? '']);

            final targetUid = (cloudUserId != null && cloudUserId.isNotEmpty)
                ? cloudUserId
                : (localUsers.isNotEmpty ? localUsers.first['uid']?.toString() ?? const Uuid().v4() : const Uuid().v4());

            final rolesList = cloudUser?['roles'] is List
                ? (cloudUser!['roles'] as List).map((e) => e.toString()).toList()
                : [(cloudUser?['role']?.toString() ?? 'inventoryStaff')];

            final Map<String, dynamic> userData = {
              'uid': targetUid,
              'email': cloudUser?['email']?.toString() ?? inputLower,
              'username': cloudUser?['username']?.toString() ?? inputLower.split('@')[0],
              'fullName': cloudUser?['name']?.toString() ?? '',
              'roles': rolesList,
              'shopId': cloudShopId,
              'branchId': cloudUser?['branch_id']?.toString() ?? cloudUser?['branchId']?.toString() ?? 'main',
              'branchName': cloudUser?['branch_name']?.toString() ?? cloudUser?['branchName']?.toString() ?? 'Main Branch',
              'permissions': cloudUser?['permissions'] ?? jsonEncode({for (var p in AppUser.allPermissions) p: true}),
              'passwordHash': hashedInput,
              'isActive': true,
              'cloudUserId': cloudUserId ?? targetUid,
              'syncEnabled': true,
              'lastOnlineLogin': DateTime.now().toUtc().toIso8601String(),
            };
            await DatabaseService().saveUserRecord(userData);

            final currency = await DatabaseService().getSetting('currency') ?? 'USD';
            final Map<String, dynamic> userWithCurrency = <String, dynamic>{...userData, 'currency': currency};
            final newUser = AppUser.fromMap(userWithCurrency, userData['uid'].toString());

            _user = newUser;
            _bindLiveUserUpdates();
            await DatabaseService().cacheUser(userWithCurrency);

            systemProvider?.resumeSync();
            unawaited(BootstrapSyncService(connectionService: connection).runBootstrapSync());

            _safeNotify();
            debugPrint("[AUTH] ONLINE AUTH (retry): Login successful for $identifier");
            return;
          } catch (retryErr) {
            debugPrint('[AUTH] Retry after discovery failed: $retryErr');
          }
        }

        // Network/timeout/unknown error — safe to fall back to local offline auth.
        debugPrint('[AUTH] Online auth attempt failed (network/unknown): $e. Falling back to local Drift auth...');
        debugPrint('[AUTH] Cloud auth error detail: ${e.toString().replaceAll('\n', ' ')}');
      }
    }

    // OFFLINE FALLBACK / LOCAL AUTH
    // Only reached when backend is unreachable (network error). Never reached on 401/403.
    try {
      debugPrint('[AUTH] Offline login attempt: identifier="$inputLower"');
      final localUsers = await DatabaseService().query('users',
        where: 'username = ? OR email = ?',
        whereArgs: [inputLower, inputLower]
      );

      debugPrint('[AUTH] User lookup result: ${localUsers.length} user(s) found for "$inputLower"');

      if (localUsers.isEmpty) {
        debugPrint('[AUTH] LOGIN FAIL: No matching user found for identifier="$inputLower"');
        throw Exception("Invalid username or password.");
      }

      final userData = localUsers.first;
      debugPrint('[AUTH] Found user: uid=${userData['uid']}, username=${userData['username']}, email=${userData['email']}, isActive=${userData['isActive']}');

      final storedHash = userData['passwordHash'] as String?;
      final hasPasswordHash = storedHash != null && storedHash.isNotEmpty;
      debugPrint('[AUTH] Password hash present: $hasPasswordHash');

      if (!hasPasswordHash) {
        debugPrint('[AUTH] LOGIN FAIL: No password hash stored for user ${userData['username']}');
        throw Exception("First login for staff account '${userData['username']}' requires an active internet connection to authenticate.");
      }

      final hashMatch = storedHash == hashedInput;
      debugPrint('[AUTH] Password hash match: $hashMatch');

      if (hashMatch) {
        final currency = await DatabaseService().getSetting('currency') ?? 'USD';
        final userWithCurrency = {...userData, 'currency': currency};

        final newUser = AppUser.fromMap(userWithCurrency, userData['uid'].toString());

        if (!newUser.isActive) {
          debugPrint('[AUTH] LOGIN FAIL: Account is disabled for user ${newUser.username}');
          throw Exception("This account has been disabled by the administrator.");
        }

        _user = newUser;
        _bindLiveUserUpdates();

        await DatabaseService().cacheUser(userWithCurrency);

        DatabaseService().recordAuditLog(
          newUser.shopId,
          newUser.username,
          'LOGIN',
          '${newUser.username} logged in from ${newUser.branchName ?? newUser.branchId}',
          branchId: newUser.branchId,
        ).catchError((_) {});

        _safeNotify();
        debugPrint('[AUTH] Login successful for identifier="$inputLower" (shopId=${newUser.shopId})');
      } else {
        debugPrint('[AUTH] LOGIN FAIL: Password mismatch for user ${userData['username']}');
        throw Exception("Invalid username or password.");
      }
    } catch (e) {
      debugPrint('[AUTH] Login Error: $e');
      rethrow;
    }
  }

  /// Connects an existing local account to a backend cloud identity.
  Future<void> connectLocalAccountToCloud({
    required String email,
    required String password,
    required ApiAuthClient authClient,
    ConnectionService? connectionService,
  }) async {
    await initialization;

    final currentUser = _user;
    if (currentUser == null) {
      throw Exception("No active local user to connect.");
    }

    final connection = connectionService ?? ConnectionService();
    final isOnline = await connection.checkBackendReachability();

    if (!isOnline) {
      throw Exception("No internet connection available. Please check your network connection and try again.");
    }

    try {
      final deviceUuid = await DeviceIdService.getOrCreate();
      
      // Attempt login or registration on backend
      Map<String, dynamic> cloudResp;
      try {
        cloudResp = await authClient.login(
          email: email.trim().toLowerCase(),
          password: password.trim(),
          deviceUuid: deviceUuid,
        );
      } catch (loginErr) {
        // Fall back to registering business if account doesn't exist yet
        cloudResp = await authClient.registerBusiness(
          businessName: currentUser.shopId.isNotEmpty ? currentUser.shopId : 'GM Shop',
          email: email.trim().toLowerCase(),
          password: password.trim(),
          deviceUuid: deviceUuid,
        );
      }

      final cloudUser = cloudResp['user'] as Map<String, dynamic>?;
      final cloudUserId = cloudUser?['id']?.toString() ?? cloudResp['user_id']?.toString();

      // Update local Drift user table record
      final updatedUserData = {
        'uid': currentUser.id,
        'email': email.trim().toLowerCase(),
        'cloudUserId': cloudUserId,
        'syncEnabled': true,
        'lastOnlineLogin': DateTime.now().toUtc().toIso8601String(),
        'passwordHash': _hashPassword(password.trim()),
      };

      await DatabaseService().saveUserRecord(updatedUserData);

      // Refresh current user session
      final refreshedUserMap = await DatabaseService().getCachedUser();
      if (refreshedUserMap != null) {
        final currency = await DatabaseService().getSetting('currency') ?? 'USD';
        final userWithCurrency = {...refreshedUserMap, 'currency': currency};
        _user = AppUser.fromMap(userWithCurrency, currentUser.id);
        _bindLiveUserUpdates();
        await DatabaseService().cacheUser(userWithCurrency);
        _safeNotify();
      }

      debugPrint("Account connected successfully: Local User ${currentUser.id} linked with Cloud ID $cloudUserId");
    } catch (e) {
      debugPrint("Failed to connect account to cloud: $e");
      rethrow;
    }
  }

  String parseHttpErrorDetailForTesting(String rawMsg) => _parseHttpErrorDetail(rawMsg);

  String _parseHttpErrorDetail(String rawMsg) {
    if (rawMsg.isEmpty) return "An unexpected error occurred.";
    try {
      final colonIdx = rawMsg.indexOf('{');
      if (colonIdx != -1) {
        final jsonStr = rawMsg.substring(colonIdx);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map && decoded.containsKey('detail')) {
          final detail = decoded['detail'];
          if (detail is List && detail.isNotEmpty) {
            final firstErr = detail.first;
            if (firstErr is Map) {
              final loc = firstErr['loc'] as List?;
              final msg = firstErr['msg']?.toString() ?? '';
              final type = firstErr['type']?.toString() ?? '';
              final field = loc != null && loc.isNotEmpty ? loc.last.toString() : '';

              if (field == 'business_name' && (type == 'string_too_short' || msg.contains('at least 2'))) {
                return 'Business name must be at least 2 characters.';
              }
              if (field == 'password' && (type == 'string_too_short' || msg.contains('at least 8'))) {
                return 'Password must be at least 8 characters.';
              }
              if (field == 'email') {
                return 'Please enter a valid email address.';
              }
              if (field == 'username' && (type == 'string_too_short' || msg.contains('at least 3'))) {
                return 'Username must be at least 3 characters.';
              }
              if (msg.isNotEmpty) {
                if (field.isNotEmpty) {
                  final fieldTitle = field.replaceAll('_', ' ');
                  final fieldCapitalized = fieldTitle[0].toUpperCase() + fieldTitle.substring(1);
                  return '$fieldCapitalized: $msg';
                }
                return msg;
              }
            }
          } else if (detail is String) {
            return detail;
          }
        }
      }
    } catch (_) {}

    if (rawMsg.contains('422')) {
      if (rawMsg.contains('business_name')) {
        return 'Business name must be at least 2 characters.';
      }
      return 'Registration validation failed. Please check input fields.';
    }
    if (rawMsg.contains('409')) {
      return 'An account with this email address or username already exists.';
    }
    if (rawMsg.contains('401')) {
      return 'Invalid credentials provided.';
    }
    return rawMsg.replaceFirst(RegExp(r'^HTTP \d+:\s*'), '');
  }

  int _extractStatusCode(String rawMsg) {
    final match = RegExp(r'HTTP (\d+)').firstMatch(rawMsg);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 400;
    }
    return 400;
  }

  Future<void> signUp(
    String email,
    String password,
    String username,
    String fullName,
    String shopName, {
    String? currency,
    String? country,
  }) async {
    final opId = const Uuid().v4();
    final usernameKey = username.toLowerCase().trim();
    final emailLower = email.trim().toLowerCase();
    final passwordTrimmed = password.trim();
    final shopNameTrimmed = shopName.trim();

    debugPrint('[AUTH] signUp started: username=$usernameKey email=$emailLower shopName=$shopNameTrimmed');

    // 0. Pre-validate business name locally before any cloud/DB calls
    final isBizNameValid = shopNameTrimmed.length >= 2;
    debugPrint('[REG TRACE]');
    debugPrint('operation_id=$opId');
    debugPrint('stage=INITIALIZATION');
    debugPrint('business_name_valid=$isBizNameValid');

    if (!isBizNameValid) {
      debugPrint('[REG ERROR] status=422 type=string_too_short field=business_name message=String should have at least 2 characters');
      debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_FAILED error_type=REGISTRATION_VALIDATION_ERROR error_code=string_too_short error_message=Business name must be at least 2 characters. business_created=false user_created=false session_created=false local_persisted=false');
      throw Exception("Business name must be at least 2 characters.");
    }

    // 0b. Enforce username/email uniqueness against the local user table before
    // any cloud call. The cloud lookup only knows emails, so an online sign-up
    // previously slipped past local duplicate checks entirely.
    final localConflicts = await DatabaseService().query(
      'users',
      where: 'username = ? OR email = ?',
      whereArgs: [usernameKey, emailLower],
    );
    if (localConflicts.isNotEmpty) {
      final clashUsername =
          localConflicts.first['username']?.toString().trim().toLowerCase() ?? '';
      debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_CONFLICT reason=local_duplicate');
      throw Exception(clashUsername == usernameKey
          ? "Username \"$usernameKey\" is already taken. Please choose another."
          : "An account with this email address already exists. Please log in instead.");
    }

    final connection = ConnectionService();
    final isOnline = await connection.checkBackendReachability();

    String effectiveUid = const Uuid().v4();
    String effectiveShopId = const Uuid().v4();

    if (isOnline) {
      final deviceUuid = await DeviceIdService.getOrCreate();
      final client = ApiAuthClient(
        baseUrl: connection.baseUrl,
        identityService: IdentityService(DatabaseService()),
      );

      // 1. Check if email/account exists on cloud
      Map<String, dynamic> checkResp;
      try {
        checkResp = await client.checkEmail(emailLower);
      } catch (checkErr) {
        debugPrint('[REG TRACE] operation_id=$opId stage=LOOKUP_FAILED lookup_status=error error_message=$checkErr');
        throw Exception("Failed to connect to authentication server: $checkErr");
      }

      final bool accountFound = checkResp['exists'] == true;
      debugPrint('[AUTH TRACE] lookup_status=200 lookup_response=${checkResp.toString()} account_found=$accountFound');
      debugPrint('[REG TRACE] operation_id=$opId stage=LOOKUP_COMPLETED lookup_status=200 account_found=$accountFound');

      if (accountFound) {
        debugPrint('[AUTH TRACE] registration_decision=CONFLICT reason=email_already_exists_on_backend');
        debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_CONFLICT error_type=REGISTRATION_VALIDATION_ERROR error_message=An account with this email address already exists.');
        throw Exception("An account with this email address already exists. Please log in instead.");
      }

      debugPrint('[AUTH TRACE] registration_decision=REGISTER_NEW_BUSINESS reason=account_not_found');
      debugPrint('[REG TRACE] operation_id=$opId stage=ACCOUNT_NOT_FOUND registration_decision=REGISTER_NEW_BUSINESS');
      debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_STARTED');

      // 2. Perform synchronous cloud business registration
      Map<String, dynamic> regResult;
      try {
        regResult = await client.registerBusiness(
          businessName: shopNameTrimmed,
          email: emailLower,
          password: passwordTrimmed,
          deviceUuid: deviceUuid,
          deviceName: 'Primary Device',
          businessId: effectiveShopId,
          userId: effectiveUid,
          username: usernameKey,
          fullName: fullName.trim(),
        );
        debugPrint('[AUTH TRACE] Cloud registration succeeded: $regResult');
        debugPrint('[REG TRACE] operation_id=$opId stage=BUSINESS_INSERT_COMMITTED registration_http_status=200 business_created=true user_created=true');
      } on HttpException catch (regHttpErr) {
        final parsedMsg = _parseHttpErrorDetail(regHttpErr.message);
        final statusCode = _extractStatusCode(regHttpErr.message);
        debugPrint('[REG ERROR] status=$statusCode message=$parsedMsg raw=${regHttpErr.message}');
        debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_FAILED registration_http_status=$statusCode error_type=REGISTRATION_VALIDATION_ERROR error_message=$parsedMsg business_created=false user_created=false session_created=false local_persisted=false');
        throw Exception(parsedMsg);
      } catch (regErr) {
        debugPrint('[REG ERROR] status=500 message=$regErr');
        debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_FAILED error_type=SERVER_ERROR error_message=$regErr business_created=false user_created=false session_created=false local_persisted=false');
        throw Exception("Registration failed: $regErr");
      }

      // 3. Immediately log in on cloud to retrieve JWT & verified identity IDs
      Map<String, dynamic> cloudResp;
      try {
        cloudResp = await client.login(
          email: emailLower,
          password: passwordTrimmed,
          deviceUuid: deviceUuid,
        );
        debugPrint('[REG TRACE] operation_id=$opId stage=SESSION_CREATED session_created=true');
      } catch (loginErr) {
        debugPrint('[REG ERROR] status=500 message=login_after_registration_failed ($loginErr)');
        throw Exception("Registration completed, but cloud session creation failed: $loginErr");
      }

      final cloudUserId = (cloudResp['user'] as Map?)?['id']?.toString() ?? regResult['user_id']?.toString() ?? effectiveUid;
      final cloudBizId = (cloudResp['business'] as Map?)?['id']?.toString() ?? regResult['business_id']?.toString() ?? effectiveShopId;

      effectiveUid = cloudUserId;
      effectiveShopId = cloudBizId;
    } else {
      // Offline fallback: uniqueness was already checked against the local DB.
      await DatabaseService().saveSetting('pending_cloud_registration', 'true');
      await DatabaseService().saveSetting('pending_cloud_email', emailLower);
    }

    // 4. Save to local Drift DB ONLY AFTER cloud registration has succeeded (or in offline mode)
    final userData = {
      'uid': effectiveUid,
      'fullName': fullName.trim(),
      'email': emailLower,
      'username': usernameKey,
      'roles': ['admin'],
      'shopId': effectiveShopId,
      'branchId': 'main',
      'branchName': 'Main Branch',
      'currency': currency ?? 'USD',
      'country': country,
      'permissions': jsonEncode({for (var p in AppUser.allPermissions) p: true}),
      'passwordHash': _hashPassword(passwordTrimmed),
      'isActive': true,
      'cloudUserId': effectiveUid,
      'syncEnabled': isOnline,
      'lastOnlineLogin': isOnline ? DateTime.now().toUtc().toIso8601String() : null,
    };

    await DatabaseService().saveUserRecord(userData);
    await DatabaseService().saveSetting('shopName', shopNameTrimmed);
    await DatabaseService().saveSetting('active_shop_id', effectiveShopId);
    await DatabaseService().saveSetting('identity_business_id', effectiveShopId);
    await DatabaseService().saveSetting('cloud_business_id', effectiveShopId);
    if (currency != null) {
      await DatabaseService().saveSetting('currency', currency);
    }

    final authenticatedUser = {...userData, 'currency': currency ?? 'USD'};
    _user = AppUser.fromMap(authenticatedUser, effectiveUid);
    _bindLiveUserUpdates();
    await DatabaseService().cacheUser(authenticatedUser);
    systemProvider?.resumeSync();
    _safeNotify();

    debugPrint('[REG TRACE] operation_id=$opId stage=REGISTRATION_COMPLETED business_created=true user_created=true session_created=true local_persisted=true final_auth_state=authenticated');
  }

  Future<void> createStaffAccount({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String shopId,
    required String branchId,
    required String branchName,
    required String role, // Now literal string of UserRole
    required Map<String, bool> permissions,
  }) async {
    final uid = const Uuid().v4();
    final usernameKey = username.toLowerCase().trim();

    debugPrint('[STAFF CREATE TRACE]');
    debugPrint('username=$usernameKey');
    debugPrint('role=$role');
    debugPrint('branch_id=$branchId');
    debugPrint('business_id=$shopId');
    debugPrint('stage=UI_CONFIRMED');

    final conn = ConnectionService();
    final isOnline = await conn.checkBackendReachability();
    if (isOnline) {
      debugPrint('[SYNC MODE] ONLINE');
      debugPrint('[CLOUD FIRST] operation=create_staff');
    } else {
      debugPrint('[SYNC MODE] OFFLINE');
    }

    final userData = {
      'uid': uid,
      'fullName': fullName.trim(),
      'email': email.trim().toLowerCase(),
      'username': usernameKey,
      'roles': [role], // Use provided role
      'shopId': shopId,
      'branchId': branchId,
      'branchName': branchName,
      'permissions': permissions,
      'password': password.trim(),
      'passwordHash': _hashPassword(password.trim()),
      'isActive': true,
    };

    debugPrint('[STAFF CREATE TRACE]');
    debugPrint('target_user_id=$uid');
    debugPrint('stage=LOCAL_USER_CREATED');
    debugPrint('stage=CREDENTIAL_CREATED');
    debugPrint('credential_exists=true');
    debugPrint('[STAFF IDENTITY TRACE]');
    debugPrint('local_user_id=$uid');
    debugPrint('[STAFF BUSINESS TRACE]');
    debugPrint('business_id=$shopId');

    try {
      await DatabaseService().saveUserRecord(userData);
      debugPrint('[USER SYNC] user_id=$uid');
      debugPrint('[USER SYNC] event_type=USER_CREATED');
      debugPrint('[USER SYNC] local upsert result=success');

      if (isOnline) {
        debugPrint('[STAFF CREATE TRACE]');
        debugPrint('stage=BACKEND_REQUEST_STARTED');
        systemProvider?.resumeSync();
        debugPrint('[CLOUD FIRST] backend result=success');
      }
    } catch (e) {
      debugPrint('[CLOUD FIRST] backend result=failure ($e)');
      throw Exception("Failed to create user account: $e");
    }
  }


  Future<void> signOut() async {
    // --- idempotency guard: only one logout at a time ---
    if (_isLoggingOut) {
      debugPrint('[AUTH] Logout already in progress — ignoring duplicate call');
      return;
    }
    _isLoggingOut = true;

    try {
      debugPrint('[AUTH] Logout started');
      _needsGoogleSetup = false;
      _needsSecuritySetup = false;
      try {
        await DatabaseService().saveSetting('needs_google_setup', 'false');
        await DatabaseService().saveSetting('needs_security_setup', 'false');
      } catch (_) {}

      // 1. Stop subscriptions that can trigger user-state changes
      await _userWatchSub?.cancel();
      _userWatchSub = null;

      // 2. Pause sync BEFORE touching the database so we don't race
      debugPrint('[AUTH] Stopping sync');
      await systemProvider?.pauseSync();
      debugPrint('[AUTH] Sync stopped');

      // 3. Clear subscription state
      SubscriptionService().clear();

      // 4. Clear ALL session data from DB & identity tokens (single batch, no concurrent writes)
      await DatabaseService().clearCachedUser();
      await IdentityService(DatabaseService()).clearIdentity();
      debugPrint('[AUTH] Session cleared');

      // 5. Reset in-memory user and IMMEDIATELY notify (synchronous)
      _user = null;
      debugPrint('[AUTH] User state reset');

      // 6. Notify listeners FIRST so Consumer rebuilds to LoginScreen
      notifyListeners();
      debugPrint('[AUTH] Returned to login');

      // 7. Pop any lingering dialogs/modals after the rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (rootNavigatorKey.currentState != null &&
              rootNavigatorKey.currentState!.canPop()) {
            rootNavigatorKey.currentState!.popUntil((route) => route.isFirst);
          }
        } catch (e) {
          debugPrint('[AUTH] Error popping navigator routes on logout: $e');
        }
      });
    } finally {
      _isLoggingOut = false;
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Validates standard enterprise password complexity rules.
  static String? validatePasswordRequirements(String password) {
    final p = password.trim();
    if (p.length < 8) return 'Password must be at least 8 characters long.';
    if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Password must contain at least 1 uppercase letter.';
    if (!RegExp(r'[0-9]').hasMatch(p)) return 'Password must contain at least 1 digit.';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p)) return 'Password must contain at least 1 special character.';
    return null;
  }

  /// Changes the currently logged in user's password after verifying their current password.
  /// Syncs to cloud when online; queues a pending flag for the next connection when offline.
  Future<void> changeCurrentPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    debugPrint('[PASSWORD CHANGE TRACE]');
    debugPrint('stage=request_started');

    final currentUser = _user;
    if (currentUser == null) throw Exception("User is not logged in.");

    final currentTrimmed = currentPassword.trim();
    final newTrimmed = newPassword.trim();
    final confirmTrimmed = confirmPassword.trim();

    if (currentTrimmed.isEmpty || newTrimmed.isEmpty || confirmTrimmed.isEmpty) {
      throw Exception("All password fields are required.");
    }

    final userRows = await DatabaseService().query('users', where: 'uid = ?', whereArgs: [currentUser.id]);
    if (userRows.isEmpty) throw Exception("User record not found.");

    final storedHash = userRows.first['passwordHash']?.toString();
    if (storedHash != null && storedHash.isNotEmpty && !storedHash.startsWith(RegExp(r'^\$2[aby]\$'))) {
      if (storedHash.toLowerCase() != _hashPassword(currentTrimmed).toLowerCase()) {
        debugPrint('[PASSWORD CHANGE TRACE]');
        debugPrint('stage=client_result_mapping');
        debugPrint('result=current_password_incorrect');
        throw Exception("Current password is incorrect.");
      }
    }

    if (newTrimmed == currentTrimmed) {
      throw Exception("New password cannot be identical to current password.");
    }

    if (newTrimmed != confirmTrimmed) {
      throw Exception("New password confirmation does not match.");
    }

    final valError = validatePasswordRequirements(newTrimmed);
    if (valError != null) throw Exception(valError);

    // 1. Send password change request to cloud backend FIRST to prevent outbox race condition
    final connection = ConnectionService();
    final isOnline = await connection.checkBackendReachability();
    if (isOnline) {
      debugPrint('[SYNC MODE] ONLINE');
      debugPrint('[CLOUD FIRST] operation=change_password');
      final baseUrl = (await DatabaseService().getSetting('api_base_url')) ?? connection.baseUrl;
      final identity = IdentityService(DatabaseService());
      final client = ApiAuthClient(baseUrl: baseUrl, identityService: identity);

      try {
        await client.changePassword(oldPassword: currentTrimmed, newPassword: newTrimmed);
        await DatabaseService().deleteSetting('pending_pwd_change');
        await DatabaseService().deleteSetting('pending_pwd_plain');
        debugPrint('[PASSWORD CHANGE TRACE]');
        debugPrint('stage=backend_response');
        debugPrint('status=200_SUCCESS');
        debugPrint('[ACCOUNT SYNC] Cloud password change: success for target_user_id=${currentUser.id}');
      } on HttpException catch (e) {
        debugPrint('[PASSWORD CHANGE TRACE]');
        debugPrint('stage=backend_response');
        debugPrint('status=HTTP_ERROR');
        if (e.message.contains('400') || e.message.contains('incorrect')) {
          debugPrint('[PASSWORD CHANGE TRACE]');
          debugPrint('stage=client_result_mapping');
          debugPrint('result=current_password_incorrect');
          throw Exception("Current password is incorrect.");
        }
        await DatabaseService().saveSetting('pending_pwd_change', 'true');
        await DatabaseService().saveSetting('pending_pwd_plain', '$currentTrimmed\x00$newTrimmed');
        debugPrint('[CLOUD FIRST] backend result=failure ($e)');
      } catch (e) {
        await DatabaseService().saveSetting('pending_pwd_change', 'true');
        await DatabaseService().saveSetting('pending_pwd_plain', '$currentTrimmed\x00$newTrimmed');
        debugPrint('[CLOUD FIRST] backend result=failure ($e)');
      }
    } else {
      debugPrint('[SYNC MODE] OFFLINE');
      await DatabaseService().saveSetting('pending_pwd_change', 'true');
      await DatabaseService().saveSetting('pending_pwd_plain', '$currentTrimmed\x00$newTrimmed');
    }

    // 2. Update local Drift hash ONLY AFTER cloud call completes (isFromSync: true avoids duplicate outbox event)
    final newHash = _hashPassword(newTrimmed);
    await DatabaseService().updateUserPassword(currentUser.id, newHash, isFromSync: true);
    debugPrint('[PASSWORD CHANGE TRACE]');
    debugPrint('stage=password_update');
    debugPrint('success=true');
    debugPrint('[PASSWORD CHANGE TRACE]');
    debugPrint('stage=session_invalidation');
    debugPrint('success=true');
    debugPrint('[PASSWORD CHANGE TRACE]');
    debugPrint('stage=client_result_mapping');
    debugPrint('result=password_changed_successfully');

    await DatabaseService().recordAuditLog(
      currentUser.shopId,
      currentUser.username,
      'PASSWORD_CHANGED',
      'User ${currentUser.username} changed their password.',
      branchId: currentUser.branchId,
    );

    debugPrint('[PASSWORD CHANGE TRACE]');
    debugPrint('stage=logout');
    debugPrint('started=true');
    await signOut();
  }


  /// Forced security logout triggered by server 401 rejection, token revocation, remote password change, or account deletion.
  Future<void> handleForcedSecurityLogout({String reason = 'session_invalidated'}) async {
    final activeShopId = _user?.shopId ?? await DatabaseService().getCachedShopId();
    debugPrint('[SHOP SESSION DEBUG]');
    debugPrint('businessId=$activeShopId');
    debugPrint('[SHOP SESSION DEBUG]');
    debugPrint('currentSessionRevoked=true');
    debugPrint('[SHOP SESSION DEBUG]');
    debugPrint('operation=$reason');
    debugPrint('[SECURITY] Session validation failed. Reason: $reason');

    debugPrint('[SECURITY LOGOUT] Wiping local shop & account data for ${activeShopId ?? "all"} (reason=$reason)');
    await DatabaseService().deleteShopAndAccount(activeShopId ?? '', isFromSync: true);
    await IdentityService(DatabaseService()).clearIdentity();

    debugPrint('[SESSION] session revoked=true');
    debugPrint('[SECURITY] Local session invalidated');
    debugPrint('[AUTH] Forced logout');
    debugPrint('[AUTH] Returned to login');
    await signOut();
  }



  /// Resets another user's password (requires Manage Users permission).
  Future<void> adminResetUserPassword({
    required String targetUserId,
    required String targetUsername,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final adminUser = _user;
    if (adminUser == null || !adminUser.hasPermission(AppUser.pManageUsers)) {
      throw Exception("Permission denied: You do not have permission to reset user passwords.");
    }

    final newTrimmed = newPassword.trim();
    final confirmTrimmed = confirmPassword.trim();

    if (newTrimmed.isEmpty || confirmTrimmed.isEmpty) {
      throw Exception("Password fields cannot be empty.");
    }

    if (newTrimmed != confirmTrimmed) {
      throw Exception("Password confirmation does not match.");
    }

    final valError = validatePasswordRequirements(newTrimmed);
    if (valError != null) throw Exception(valError);

    final newHash = _hashPassword(newTrimmed);
    await DatabaseService().updateUserPassword(targetUserId, newHash);
    systemProvider?.syncEngine?.syncNow();

    await DatabaseService().recordAuditLog(
      adminUser.shopId,
      adminUser.username,
      'PASSWORD_RESET',
      'Admin ${adminUser.username} reset password for user $targetUsername.',
      branchId: adminUser.branchId,
    );
  }

  // --- STUBS FOR TRANSITION ---
  Future<void> resetPassword(String email) async {
    throw Exception("Password reset is not available in standalone offline mode. Please contact your system administrator.");
  }

  /// Signs in with Google using the system browser (OAuth 2.0 + PKCE with a
  /// loopback redirect) and links/creates the cloud account.
  ///
  /// Works on Windows, macOS, Linux and Android. Configure the Desktop app
  /// OAuth client in `.env`:
  ///   GOOGLE_CLIENT_ID=<desktop client id>
  ///   GOOGLE_CLIENT_SECRET=<desktop client secret>
  Future<void> signInWithGoogle() async {
    await initialization;

    if (kIsWeb) {
      throw Exception(
          'Google sign-in is not available in the browser build. Use email and password.');
    }

    final connection = ConnectionService();
    final isOnline = await connection.checkBackendReachability(force: true);
    if (!isOnline) {
      throw Exception(
          'Google sign-in needs an internet connection to the GM Inventory Everywhere servers.');
    }

    String idToken;
    String email;
    String googleId;
    String? displayName;

    if (Platform.isAndroid) {
      // Native Android Google sign-in: no browser, no Play Store detour.
      final serverClientId = _googleEnv([
        'GOOGLE_SERVER_CLIENT_ID',
        'GOOGLE_WEB_CLIENT_ID',
        'GOOGLE_CLIENT_ID',
      ]);
      if (serverClientId == null) {
        throw Exception(
            'Google sign-in is not configured for Android yet. Add the Web OAuth '
            'client ID as GOOGLE_SERVER_CLIENT_ID in .env, and register package '
            'com.gminventory.app with this build\'s SHA-1 on an Android OAuth client.');
      }

      GoogleSignInAccount? account;
      try {
        account = await GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: serverClientId,
        ).signIn();
      } on PlatformException catch (e) {
        throw Exception(_androidGoogleError(e));
      }
      if (account == null) {
        throw Exception('Google sign-in cancelled.');
      }

      final authentication = await account.authentication;
      final token = authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception(
            'Google did not return an ID token. Register this build\'s SHA-1 '
            '(35:41:32:E8:09:44:F5:9E:6D:46:D9:7D:2E:BD:8B:08:7A:35:7E:6B) for '
            'package com.gminventory.app in Google Cloud Console.');
      }
      idToken = token;
      email = account.email;
      googleId = account.id;
      displayName = account.displayName;
    } else {
      final clientId = _googleEnv([
        'GOOGLE_CLIENT_ID',
        'GOOGLE_DESKTOP_CLIENT_ID',
        'GOOGLE_SERVER_CLIENT_ID',
      ]);
      if (clientId == null) {
        throw Exception(
            'Google sign-in is not configured. Add GOOGLE_CLIENT_ID to your .env file.');
      }
      final clientSecret = _googleEnv([
        'GOOGLE_CLIENT_SECRET',
        'GOOGLE_DESKTOP_CLIENT_SECRET',
      ]);
      final result = await GoogleOAuthFlow.signIn(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      idToken = result.idToken;
      email = result.email;
      googleId = result.googleId;
      displayName = result.name;
    }

    final resolvedUrl = connection.baseUrl;
    AppConfig.setApiBaseUrl(resolvedUrl);
    final client = ApiAuthClient(
      baseUrl: resolvedUrl,
      identityService: IdentityService(DatabaseService()),
    );
    final deviceUuid = await DeviceIdService.getOrCreate();
    final deviceName = await _deviceDisplayName();

    debugPrint('[AUTH] Google sign-in started for $email');
    Map<String, dynamic> cloudResp;
    try {
      cloudResp = await client.loginWithGoogle(
        idToken: idToken,
        email: email,
        googleId: googleId,
        deviceUuid: deviceUuid,
        name: displayName,
        deviceName: deviceName,
      );
    } catch (e) {
      debugPrint('[AUTH] Google backend sign-in failed: $e');
      throw Exception(_googleServerMessage(e));
    }
    connection.reportSuccess();

    final googleBusinessName =
        (cloudResp['business']?['name'] ?? '').toString().trim();
    _needsGoogleSetup = cloudResp['onboarding_completed'] == false ||
        cloudResp['is_new_account'] == true ||
        googleBusinessName.isEmpty;
    await DatabaseService()
        .saveSetting('needs_google_setup', _needsGoogleSetup ? 'true' : 'false');

    final cloudUser = cloudResp['user'] as Map<String, dynamic>?;
    final cloudUserId = cloudUser?['id']?.toString();
    final cloudShopId = cloudResp['business']?['id']?.toString() ??
        cloudUser?['shopId']?.toString() ??
        'shop-cloud-001';

    final localUsers = await DatabaseService().query('users',
        where: 'username = ? OR email = ? OR cloud_user_id = ?',
        whereArgs: [email, email, cloudUserId ?? '']);

    final targetUid = (cloudUserId != null && cloudUserId.isNotEmpty)
        ? cloudUserId
        : (localUsers.isNotEmpty
            ? localUsers.first['uid']?.toString() ?? const Uuid().v4()
            : const Uuid().v4());

    final rolesList = cloudUser?['roles'] is List
        ? (cloudUser!['roles'] as List).map((e) => e.toString()).toList()
        : [(cloudUser?['role']?.toString() ?? 'admin')];

    final Map<String, dynamic> userData = {
      'uid': targetUid,
      'email': cloudUser?['email']?.toString() ?? email,
      'username':
          cloudUser?['username']?.toString() ?? email.split('@')[0],
      'fullName':
          cloudUser?['name']?.toString() ?? displayName ?? '',
      'roles': rolesList,
      'shopId': cloudShopId,
      'branchId': cloudUser?['branch_id']?.toString() ??
          cloudUser?['branchId']?.toString() ??
          'main',
      'branchName': cloudUser?['branch_name']?.toString() ??
          cloudUser?['branchName']?.toString() ??
          'Main Branch',
      'permissions': cloudUser?['permissions'] ??
          jsonEncode({for (var p in AppUser.allPermissions) p: true}),
      'passwordHash': _hashPassword(const Uuid().v4()),
      'isActive': true,
      'cloudUserId': cloudUserId ?? targetUid,
      'syncEnabled': true,
      'lastOnlineLogin': DateTime.now().toUtc().toIso8601String(),
    };
    await DatabaseService().saveUserRecord(userData);

    final currency = await DatabaseService().getSetting('currency') ?? 'USD';
    final Map<String, dynamic> userWithCurrency = <String, dynamic>{
      ...userData,
      'currency': currency,
    };
    _user = AppUser.fromMap(userWithCurrency, userData['uid'].toString());
    _bindLiveUserUpdates();
    await DatabaseService().cacheUser(userWithCurrency);

    systemProvider?.resumeSync();
    unawaited(
        BootstrapSyncService(connectionService: connection).runBootstrapSync());

    _safeNotify();
    debugPrint('[AUTH] Google sign-in successful for $email');
  }

  /// Saves the shop details for a new Google account, then lets the app open.
  Future<void> completeGoogleSetup({
    required String shopName,
    required String businessType,
    required String currency,
    required String country,
    String? displayName,
  }) async {
    final user = _user;
    if (user == null) {
      throw Exception('Your session expired. Please sign in with Google again.');
    }

    final shopNameTrimmed = shopName.trim();
    if (shopNameTrimmed.length < 2) {
      throw Exception('Business name must be at least 2 characters long');
    }
    if (businessType.trim().isEmpty) {
      throw Exception('Please choose your business type');
    }
    if (currency.trim().isEmpty) {
      throw Exception('Please choose your business currency');
    }
    if (country.trim().isEmpty) {
      throw Exception('Please choose your country');
    }

    final connection = ConnectionService();
    if (!await connection.checkBackendReachability(force: true)) {
      throw Exception(
          'Setup needs an internet connection. Check your connection and try again.');
    }

    final baseUrl = connection.baseUrl;
    AppConfig.setApiBaseUrl(baseUrl);
    final client = ApiAuthClient(
      baseUrl: baseUrl,
      identityService: IdentityService(DatabaseService()),
    );
    try {
      await client.completeProfile(
        businessName: shopNameTrimmed,
        businessType: businessType.trim(),
        currency: currency,
        country: country,
        displayName: displayName,
      );
    } catch (e) {
      debugPrint('[AUTH] Google profile completion failed: $e');
      throw Exception(_googleServerMessage(e));
    }

    await DatabaseService().saveSetting('shopName', shopNameTrimmed);
    await DatabaseService().saveSetting('businessType', businessType.trim());
    await DatabaseService().saveSetting('currency', currency);
    await DatabaseService().saveSetting('country', country);
    await DatabaseService().updateUser(user.id, {
      'currency': currency,
      'country': country,
      if (displayName != null && displayName.trim().isNotEmpty)
        'fullName': displayName.trim(),
    });

    final refreshed = await DatabaseService()
        .query('users', where: 'uid = ?', whereArgs: [user.id], limit: 1);
    if (refreshed.isNotEmpty) {
      final updated = <String, dynamic>{
        ...refreshed.first,
        'currency': currency,
        'country': country,
      };
      _user = AppUser.fromMap(updated, user.id);
      _bindLiveUserUpdates();
      await DatabaseService().cacheUser(updated);
    }

    _needsGoogleSetup = false;
    await DatabaseService().saveSetting('needs_google_setup', 'false');
    _needsSecuritySetup = true;
    await DatabaseService().saveSetting('needs_security_setup', 'true');
    _safeNotify();
  }

  ApiAuthClient _securityClient(String baseUrl) => ApiAuthClient(
        baseUrl: baseUrl,
        identityService: IdentityService(DatabaseService()),
      );

  Future<ApiAuthClient> _onlineSecurityClient() async {
    final connection = ConnectionService();
    if (!await connection.checkBackendReachability(force: true)) {
      throw Exception('This needs an internet connection. Check your connection and try again.');
    }
    AppConfig.setApiBaseUrl(connection.baseUrl);
    return _securityClient(connection.baseUrl);
  }

  /// Local truth about the signed-in user's credential (works offline).
  Future<Map<String, dynamic>> _localSecurityFacts() async {
    final user = _user;
    if (user == null) return <String, dynamic>{};
    final rows = await DatabaseService()
        .query('users', where: 'uid = ?', whereArgs: [user.id]);
    final localHash = rows.isNotEmpty
        ? (rows.first['passwordHash'] as String? ?? '')
        : '';
    return {
      'username': user.username,
      'password_configured': localHash.isNotEmpty,
    };
  }

  Future<Map<String, dynamic>> securityMethods() async {
    final local = await _localSecurityFacts();
    try {
      final client = await _onlineSecurityClient();
      final methods = await client.securityMethods();
      // A Google account's local row carries a generated placeholder hash;
      // only trust the backend for those accounts.
      final googleAccount = methods['google_connected'] == true;
      if (!googleAccount && local['password_configured'] == true) {
        methods['password_configured'] = true;
      }
      if (!googleAccount &&
          (methods['username'] as String?)?.isNotEmpty != true) {
        methods['username'] = local['username'];
      }
      methods['offline'] = false;
      return methods;
    } catch (e) {
      if (local.isEmpty) rethrow;
      return {
        'google_connected': false,
        'username': local['username'],
        'password_configured': local['password_configured'],
        'recovery_email': null,
        'recovery_email_verified': false,
        'offline': true,
        'message': 'Connect to the internet to check your recovery email.',
      };
    }
  }

  /// Emails a single-use password reset code to the account's address.
  /// Fresh Google ID token for sensitive actions (account deletion).
  /// Does not sign in or change the current session.
  Future<String> freshGoogleIdToken() async {
    if (kIsWeb) {
      throw Exception('Google verification is not available in the browser build.');
    }
    if (Platform.isAndroid) {
      final serverClientId = _googleEnv([
        'GOOGLE_SERVER_CLIENT_ID',
        'GOOGLE_WEB_CLIENT_ID',
        'GOOGLE_CLIENT_ID',
      ]);
      if (serverClientId == null) {
        throw Exception('Google sign-in is not configured for Android yet.');
      }
      GoogleSignInAccount? account;
      try {
        account = await GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: serverClientId,
        ).signIn();
      } on PlatformException catch (e) {
        throw Exception(_androidGoogleError(e));
      }
      if (account == null) throw Exception('Google verification cancelled.');
      final auth = await account.authentication;
      final token = auth.idToken;
      if (token == null || token.isEmpty) {
        throw Exception('Google did not return an ID token for this build.');
      }
      return token;
    }
    final clientId = _googleEnv([
      'GOOGLE_CLIENT_ID',
      'GOOGLE_DESKTOP_CLIENT_ID',
      'GOOGLE_SERVER_CLIENT_ID',
    ]);
    if (clientId == null) throw Exception('Google sign-in is not configured.');
    final clientSecret =
        _googleEnv(['GOOGLE_CLIENT_SECRET', 'GOOGLE_DESKTOP_CLIENT_SECRET']);
    final result =
        await GoogleOAuthFlow.signIn(clientId: clientId, clientSecret: clientSecret);
    return result.idToken;
  }

  /// Verifies the user for deletion; returns a short-lived deletion token.
  Future<String> verifyAccountDeletion({
    String? password,
    String? googleIdToken,
  }) async {
    final client = await _onlineSecurityClient();
    try {
      final result = await client.verifyAccountDeletion(
        password: password,
        googleIdToken: googleIdToken,
      );
      return (result['deletion_token'] ?? '').toString();
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  /// Changes the signed-in user's username (must be unique among active users).
  Future<void> updateUsername(String username) async {
    final user = _user;
    if (user == null) throw Exception('Your session expired. Please sign in again.');
    final client = await _onlineSecurityClient();
    try {
      await client.updateUsername(username.trim().toLowerCase());
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
    await DatabaseService()
        .updateUser(user.id, {'username': username.trim().toLowerCase()});
    _safeNotify();
  }

  Future<List<Map<String, dynamic>>> businessMembers() async {
    final client = await _onlineSecurityClient();
    try {
      final result = await client.businessMembers();
      final list = result['members'];
      return list is List ? list.cast<Map<String, dynamic>>() : const [];
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  Future<void> createAdminAccount({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    final client = await _onlineSecurityClient();
    try {
      await client.createAdminAccount(
          name: name, username: username, email: email, password: password);
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  Future<void> transferOwnership(String newOwnerId) async {
    final client = await _onlineSecurityClient();
    try {
      await client.transferOwnership(newOwnerId);
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  /// Deletes the shop for every member; all their accounts are deactivated.
  Future<Map<String, dynamic>> deleteBusiness({
    required String deletionToken,
  }) async {
    final client = await _onlineSecurityClient();
    try {
      return await client.deleteBusiness(
          deletionToken: deletionToken, confirmation: 'DELETE');
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  Future<Map<String, dynamic>> deleteAccount({
    required String deletionToken,
    required String confirmation,
  }) async {
    final client = await _onlineSecurityClient();
    try {
      return await client.deleteAccount(
        deletionToken: deletionToken,
        confirmation: confirmation,
      );
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    final client = await _onlineSecurityClient();
    try {
      return await client.requestRecovery(identifier.trim().toLowerCase());
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    final client = await _onlineSecurityClient();
    try {
      return await client.confirmRecovery(token: code.trim(), newPassword: newPassword);
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  /// Adds an optional username/password login without disabling Google.
  Future<void> addLoginPassword({
    required String username,
    required String password,
  }) async {
    final user = _user;
    if (user == null) throw Exception('Your session expired. Please sign in again.');
    final client = await _onlineSecurityClient();
    try {
      await client.setSecurityPassword(username: username, password: password);
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
    // Keep the local credential in step so offline sign-in accepts the new
    // username and password too.
    await DatabaseService().updateUser(user.id, {
      'username': username.trim().toLowerCase(),
    });
    await DatabaseService()
        .updateLocalPasswordHash(user.id, _hashPassword(password.trim()));
    _needsSecuritySetup = false;
    await DatabaseService().saveSetting('needs_security_setup', 'false');
    _safeNotify();
  }

  Future<void> skipSecuritySetup() async {
    _needsSecuritySetup = false;
    await DatabaseService().saveSetting('needs_security_setup', 'false');
    _safeNotify();
  }

  Future<Map<String, dynamic>> sendRecoveryEmail(String email) async {
    final client = await _onlineSecurityClient();
    try {
      return await client.setRecoveryEmail(email);
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  Future<Map<String, dynamic>> confirmRecoveryEmail(String code) async {
    final client = await _onlineSecurityClient();
    try {
      return await client.verifyRecoveryEmail(code);
    } catch (e) {
      throw Exception(_googleServerMessage(e));
    }
  }

  /// Turns native Android Google sign-in failures into actionable messages.
  String _androidGoogleError(PlatformException e) {
    final raw = '${e.code} ${e.message ?? ''}';
    if (raw.contains('ApiException: 10') ||
        raw.toLowerCase().contains('developer_error')) {
      return 'Google sign-in was rejected by Android (Developer Error 10). '
          'Register package com.gminventory.app with SHA-1 '
          '35:41:32:E8:09:44:F5:9E:6D:46:D9:7D:2E:BD:8B:08:7A:35:7E:6B on an '
          'Android OAuth client in Google Cloud Console.';
    }
    if (raw.contains('ApiException: 12501') ||
        raw.toLowerCase().contains('cancel')) {
      return 'Google sign-in cancelled.';
    }
    if (raw.contains('ApiException: 7') ||
        raw.toLowerCase().contains('network')) {
      return 'Google sign-in needs a working internet connection. Please try again.';
    }
    return 'Google sign-in failed: ${e.message ?? e.code}';
  }

  /// Turns backend OAuth failures into messages safe to show the user.
  String _googleServerMessage(Object error) {
    final raw = error.toString().replaceAll('\n', ' ');
    final detail =
        RegExp(r'"detail"\s*:\s*"([^"]+)"').firstMatch(raw)?.group(1);
    if (detail != null) {
      return detail.replaceAll(r'\"', '"');
    }
    final code = RegExp(r'HTTP (\d{3})').firstMatch(raw)?.group(1);
    if (code == '401' || raw.contains('401')) {
      return 'Google sign-in could not be verified. Please try again.';
    }
    if (code == '409' || raw.contains('409')) {
      return 'An account with this email already exists. Sign in with your '
          'password, then connect Google from Account Security.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('Connection refused') ||
        raw.contains('timed out') ||
        raw.contains('TimeoutException')) {
      return 'Could not reach the GM Inventory Everywhere server. Check your connection and try again.';
    }
    return 'Google sign-in could not be completed. Please try again.';
  }

  String? _googleEnv(List<String> keys) {
    for (final key in keys) {
      try {
        final value = dotenv.env[key];
        if (value != null && value.trim().isNotEmpty) return value.trim();
      } catch (_) {
        // dotenv not initialised (e.g. tests) — no value configured.
      }
    }
    return null;
  }

  Future<String> _deviceDisplayName() async {
    try {
      final name = Platform.localHostname.trim();
      if (name.isNotEmpty) return name;
    } catch (_) {}
    return 'GM Inventory Everywhere Device';
  }

  Stream<Map<String, dynamic>> get shopStream async* {
    if (_user == null) return;
    final name = await DatabaseService().getSetting('shopName');
    yield {
      'id': _user?.shopId ?? '',
      'name': name ?? 'Local ERP',
    };
  }

  Future<void> updateShop(String name, String phone) async {
    await DatabaseService().saveSetting('shopName', name);
    await DatabaseService().saveSetting('shopPhone', phone);
    _safeNotify();
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
