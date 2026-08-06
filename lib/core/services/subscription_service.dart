import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/subscription_models.dart';
import 'database_service.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final _db = DatabaseService();
  ActiveSubscription? _current;
  Timer? _expirationTimer;

  ActiveSubscription? get current => _current;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  bool _testMode = true; // Set to false for 7-day production mode
  void setTestMode(bool val) {
    _testMode = val;
    notifyListeners();
  }

  Future<void> initialize(String shopId) async {
    _isInitializing = true;
    notifyListeners();
    await _loadSubscription(shopId);

    // If no subscription exists, create a trial
    if (_current == null) {
      await startTrial(shopId);
    } else {
      _startExpirationTimer();
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<void> _loadSubscription(String shopId) async {
    final results = await _db.query('subscriptions',
        where: 'shopId = ?',
        orderBy: 'activationDate DESC',
        limit: 1,
        whereArgs: [shopId]);
    if (results.isNotEmpty) {
      _current = ActiveSubscription.fromMap(results.first);
      notifyListeners();
    }
  }

  Future<void> startTrial(String shopId) async {
    final now = DateTime.now();
    // 5 minutes in test mode, 7 days in production
    final expiry = now
        .add(_testMode ? const Duration(minutes: 5) : const Duration(days: 7));

    final data = {
      'shopId': shopId,
      'plan': SubscriptionPlan.trial.name.toLowerCase(),
      'activationDate': now.toIso8601String(),
      'expiryDate': expiry.toIso8601String(),
      'addOns': '[]',
      'isTrial': 1,
      'userLimit': 3,
      'branchLimit': 1,
    };

    await _db.saveSubscription(data);
    _current = ActiveSubscription.fromMap(data);
    _startExpirationTimer();
    notifyListeners();
  }

  Future<void> activateSubscription(String shopId, SubscriptionPlan plan,
      {List<SubscriptionAddOn> addOns = const []}) async {
    final now = DateTime.now();
    // 5 minutes for payment testing, 30 days for production
    final expiry = now
        .add(_testMode ? const Duration(minutes: 5) : const Duration(days: 30));

    int uLimit = 3;
    int bLimit = 1;
    if (plan == SubscriptionPlan.business) {
      uLimit = 10;
      bLimit = 5;
    } else if (plan == SubscriptionPlan.enterprise) {
      uLimit = 100;
      bLimit = 70;
    }

    final extraUserCount =
        addOns.where((addon) => addon == SubscriptionAddOn.extraUser).length;
    final extraBranchCount =
        addOns.where((addon) => addon == SubscriptionAddOn.extraBranch).length;

    uLimit += extraUserCount;
    bLimit += extraBranchCount;

    final data = {
      'shopId': shopId,
      'plan': plan.name.toLowerCase(),
      'activationDate': now.toIso8601String(),
      'expiryDate': expiry.toIso8601String(),
      'addOns': jsonEncode(
          addOns.map((e) => e.name).toList()), // Using extension name
      'isTrial': 0,
      'userLimit': uLimit,
      'branchLimit': bLimit,
    };

    await _db.saveSubscription(data);
    _current = ActiveSubscription.fromMap(data);
    _startExpirationTimer();
    notifyListeners();
  }

  Future<void> upgrade(
      {required String shopId,
      required SubscriptionPlan plan,
      List<SubscriptionAddOn> addOns = const []}) async {
    await activateSubscription(shopId, plan, addOns: addOns);
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    if (_current == null || _current!.isExpired) return;

    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_current!.isExpired) {
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void clear() {
    _current = null;
    _expirationTimer?.cancel();
    _expirationTimer = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    super.dispose();
  }
}

// Global instance for easier access in UI
final subscriptionService = SubscriptionService();
