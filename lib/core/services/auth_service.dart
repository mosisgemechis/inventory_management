import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'package:flutter/foundation.dart';
import 'subscription_service.dart';

class AuthService with ChangeNotifier {
  // OFFLINE MODE OVERRIDE:
  // All Firebase Auth features are disabled. 
  // Identity management is provided exclusively via the local SQLite 'users' table.

  AppUser? _user;
  AppUser? get user => _user;
  bool _initialized = false;
  bool get initialized => _initialized;
  bool get firebaseReady => true; // Bypassed for offline operation

  Future<void> syncStaffIdentities(String shopId) async {} // Stubbed for offline operation

  int _loginAttempts = 0;
  DateTime? _lockoutUntil;
  static const int maxAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 5);

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initialization => _initCompleter.future;

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  AuthService() {
    // Session is loaded explicitly via ..loadSession() in main.dart
  }

  Future<void> loadSession() async {
    debugPrint("OFFLINE MODE: Loading local enterprise session...");
    
    // 1. Seed the database with a default Admin if empty
    await _seedDefaultAdmin();
    
    // 2. Load the last active session from the users table
    try {
      final userMap = await DatabaseService().getCachedUser();
      if (userMap != null) {
        _user = AppUser.fromMap(userMap, userMap['uid']);
      }
    } catch (e) {
      debugPrint("Error loading local session: $e");
    }
    
    _initialized = true;
    if (!_initCompleter.isCompleted) _initCompleter.complete();
    _safeNotify();
  }

  Future<void> _seedDefaultAdmin() async {
    try {
      final db = DatabaseService();
      final users = await db.query('users');
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

  Future<void> signIn(String identifier, String password) async {
    await initialization;
    
    final inputLower = identifier.trim().toLowerCase();
    final passwordTrimmed = password.trim();
    final hashedInput = _hashPassword(passwordTrimmed);

    try {
      // Query local users table
      final localUsers = await DatabaseService().query('users', 
        where: 'username = ? OR email = ?', 
        whereArgs: [inputLower, inputLower]
      );

      if (localUsers.isEmpty) {
        throw Exception("Invalid username or password.");
      }

      final userData = localUsers.first;
      final storedHash = userData['passwordHash'] as String?;

      if (storedHash != null && storedHash == hashedInput) {
        final currency = await DatabaseService().getSetting('currency') ?? 'USD';
        final userWithCurrency = {...userData, 'currency': currency};
        
        final newUser = AppUser.fromMap(userWithCurrency, userData['uid'].toString());
        
        if (!newUser.isActive) {
          throw Exception("This account has been disabled by the administrator.");
        }

        _user = newUser;

        _loginAttempts = 0;
        _lockoutUntil = null;
        
        await DatabaseService().cacheUser(userWithCurrency);
        _safeNotify();
        debugPrint("OFFLINE MODE: Login successful for $identifier");
      } else {
        throw Exception("Invalid username or password.");
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String username, String fullName, String shopName, {String? currency, String? country}) async {
    final uid = const Uuid().v4();
    final shopId = const Uuid().v4();
    final usernameKey = username.toLowerCase().trim();
    final emailLower = email.trim().toLowerCase();
    final passwordTrimmed = password.trim();

    final userData = {
      'uid': uid,
      'fullName': fullName.trim(),
      'email': emailLower,
      'username': usernameKey,
      'roles': ['admin'],
      'shopId': shopId,
      'branchId': 'main',
      'branchName': 'Main Branch',
      'currency': currency ?? 'USD',
      'country': country,
      'permissions': jsonEncode({for (var p in AppUser.allPermissions) p: true}),
      'passwordHash': _hashPassword(passwordTrimmed),
      'isActive': true,
    };

    try {
      // 1. Check if username or email already exists locally
      final existing = await DatabaseService().query('users', 
        where: 'username = ? OR email = ?', 
        whereArgs: [usernameKey, email.trim().toLowerCase()]
      );

      if (existing.isNotEmpty) {
        throw Exception("Username or email already in use.");
      }

      // 2. Save locally
      await DatabaseService().saveUserRecord(userData);
      
      // 3. Save shop settings
      await DatabaseService().saveSetting('shopName', shopName);
      if (currency != null) {
        await DatabaseService().saveSetting('currency', currency);
      }

      final authenticatedUser = {...userData, 'currency': currency ?? 'USD'};
      _user = AppUser.fromMap(authenticatedUser, uid);
      await DatabaseService().cacheUser(authenticatedUser);
      _safeNotify();
    } catch (e) {
      throw Exception("Registration failed: $e");
    }
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
      'passwordHash': _hashPassword(password.trim()),
      'isActive': true,
    };

    try {
      await DatabaseService().saveUserRecord(userData);
    } catch (e) {
      throw Exception("Failed to create user account locally: $e");
    }
  }

  Future<void> signOut() async {
    SubscriptionService().clear();
    await DatabaseService().clearCachedUser();
    _user = null;
    notifyListeners();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  // --- STUBS FOR TRANSITION ---
  Future<void> resetPassword(String email) async {
    throw Exception("Password reset is not available in standalone offline mode. Please contact your system administrator.");
  }

  Future<void> signInWithGoogle() async {
    throw Exception("Cloud authentication is disabled in standalone offline mode.");
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

