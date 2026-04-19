import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'sync_service.dart';
import 'firestore_service.dart';
import '../utils/thread_safe_stream.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _user;
  AppUser? get user => _user;
  bool _initialized = false;
  bool get initialized => _initialized;

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  AuthService() {
    _auth.authStateChanges().toMainThread().listen((user) async {
      if (user != null) {
        _user = await _fetchUserDetails(user);
        if (_user != null) {
           SyncService.start(FirestoreService(), _user!.shopId);
        }
        await NotificationService.saveTokenToFirestore();
      } else {
        _user = null;
        SyncService.stop();
      }
      _initialized = true;
      _safeNotify();
    });
  }

  Future<AppUser?> _fetchUserDetails(User firebaseUser) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data() as Map<String, dynamic>, firebaseUser.uid);
    } catch (e) {
      print("AuthService: Error fetching user details: $e");
      return null;
    }
  }

  Future<void> signIn(String identifier, String password) async {
    String email = identifier.trim();
    if (!email.contains('@')) {
      final query = await _db.collection('users').where('username', isEqualTo: email.toLowerCase()).get();
      if (query.docs.isEmpty) throw Exception("User with username '$identifier' not found.");
      email = query.docs.first.get('email');
    }

    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (result.user != null) {
      final details = await _fetchUserDetails(result.user!);
      if (details == null) {
        await _auth.signOut();
        throw Exception("Profile not found in Database.");
      }
      _user = details;
      _safeNotify();
    }
  }

  Future<void> updateUsername(String newUsername) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Not logged in");
    await _db.collection('users').doc(currentUser.uid).update({'username': newUsername});
    if (_user != null) {
      _user = AppUser(
        id: _user!.id,
        email: _user!.email,
        username: newUsername,
        roles: _user!.roles,
        shopId: _user!.shopId,
        branchId: _user!.branchId,
        branchName: _user!.branchName,
      );
    }
    _safeNotify();
  }

  Future<void> updateEmail(String newEmail) async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception("Not logged in");
    await currentUser.updateEmail(newEmail);
    await _db.collection('users').doc(currentUser.uid).update({'email': newEmail});
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
