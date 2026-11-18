import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/subscription_models.dart';
import 'database_service.dart';
import 'identity_service.dart';
import 'sync/api_auth_client.dart';
import 'sync/connection_service.dart';
import 'subscription_change.dart';

class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final _db = DatabaseService();
  ActiveSubscription? _current;
  Timer? _expirationTimer;

  ActiveSubscription? get current => _current;
  String? _shopId;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  PendingPlanChange? _pendingChange;
  PendingPlanChange? get pendingChange => _pendingChange;

  String _pendingKey(String shopId) => 'subscription_pending_$shopId';

  /// True once [initialize] has finished, so callers can tell "no plan" apart
  /// from "the plan has not loaded yet".
  bool _isReady = false;
  bool get isReady => _isReady;

  /// Short durations are useful for exercising expiry, but production-length
  /// plans are the default so a plan bought for testing stays active.
  bool _testMode = false;
  void setTestMode(bool val) {
    _testMode = val;
    notifyListeners();
  }

  bool get testMode => _testMode;

  /// Test-only hook to control the loaded plan without touching the database.
  @visibleForTesting
  void debugSetState({ActiveSubscription? current, bool ready = true}) {
    _current = current;
    _isReady = ready;
    _isInitializing = false;
    notifyListeners();
  }

  /// Loads the local subscription, starts a trial when there is none, and
  /// reconciles with the backend. Safe to call more than once.
  Future<void> initialize(String shopId) async {
    if (_isInitializing) return;
    if (_current != null && _shopId == shopId) {
      _isReady = true;
      _startExpirationTimer();
      return;
    }

    _isInitializing = true;
    _shopId = shopId;
    notifyListeners();
    try {
      await _loadSubscription(shopId);

      if (_current == null) {
        await startTrial(shopId);
      } else {
        _startExpirationTimer();
      }
      await _loadPendingChange(shopId);
      await _applyDuePendingChange(shopId);
      await _syncWithServer(shopId);
    } finally {
      _isInitializing = false;
      _isReady = true;
      notifyListeners();
    }
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
    // 5 minutes in test mode, 7 days otherwise.
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
    _shopId = shopId;
    _isReady = true;
    _startExpirationTimer();
    notifyListeners();
  }

  Future<void> activateSubscription(String shopId, SubscriptionPlan plan,
      {List<SubscriptionAddOn> addOns = const [],
      BillingCycle cycle = BillingCycle.monthly}) async {
    final now = DateTime.now();
    // 5 minutes for payment testing, otherwise the purchased term.
    final termDays = cycle.isYearly ? 365 : 30;
    final expiry = now.add(_testMode
        ? const Duration(minutes: 5)
        : Duration(days: termDays));

    final uLimit = userLimitFor(plan, addOns);
    final bLimit = branchLimitFor(plan, addOns);

    final data = {
      'shopId': shopId,
      'plan': plan.name.toLowerCase(),
      'activationDate': now.toIso8601String(),
      'expiryDate': expiry.toIso8601String(),
      'addOns': jsonEncode(addOns.map((e) => e.name).toList()),
      'isTrial': 0,
      'userLimit': uLimit,
      'branchLimit': bLimit,
    };

    await _db.saveSubscription(data);
    _current = ActiveSubscription.fromMap(data);
    _shopId = shopId;
    _isReady = true;
    _startExpirationTimer();
    notifyListeners();

    // Share the new plan with the backend/other devices without making the
    // checkout wait on the network.
    unawaited(_syncWithServer(shopId));
  }

  /// Quotes a change without applying it.
  PlanChangeQuote quoteChange({
    required SubscriptionPlan plan,
    List<SubscriptionAddOn> addOns = const [],
  }) {
    return quotePlanChange(
      current: _current,
      targetPlan: plan,
      targetAddOns: addOns,
    );
  }

  /// Applies a plan change.
  ///
  /// Every change takes effect immediately: upgrades charge the full new price
  /// today, downgrades cost nothing today. A downgrade is blocked when the shop
  /// already has more users or branches than the lower plan allows. The renewal
  /// date never moves.
  Future<PlanChangeQuote> changePlan({
    required String shopId,
    required SubscriptionPlan plan,
    List<SubscriptionAddOn> addOns = const [],
    BillingCycle cycle = BillingCycle.monthly,
  }) async {
    final quote = quoteChange(plan: plan, addOns: addOns);

    // Downgrades apply right away too, as long as the shop already fits the
    // smaller plan's seat and branch limits.
    if (quote.kind == PlanChangeKind.downgrade) {
      await _assertUsageFits(shopId, quote);
    }

    final now = DateTime.now();
    final current = _current;
    final keepExpiry = current != null && current.expiryDate.isAfter(now);
    final termStart = keepExpiry ? current.expiryDate : now;
    await _persistPlan(
      shopId: shopId,
      plan: plan,
      addOns: addOns,
      expiry: cycle.isYearly
          ? termStart.add(const Duration(days: 365))
          : (keepExpiry ? current.expiryDate : now.add(const Duration(days: 30))),
    );
    return quote;
  }

  /// Kept for callers that only ever buy or raise a plan.
  Future<void> upgrade(
      {required String shopId,
      required SubscriptionPlan plan,
      List<SubscriptionAddOn> addOns = const []}) async {
    await changePlan(shopId: shopId, plan: plan, addOns: addOns);
  }

  Future<void> cancelPendingChange(String shopId) async {
    _pendingChange = null;
    await _savePending(shopId);
    notifyListeners();
  }

  Future<void> _savePending(String shopId) async {
    final pending = _pendingChange;
    await _db.saveSetting(
        _pendingKey(shopId), pending == null ? '' : jsonEncode(pending.toJson()));
  }

  Future<void> _loadPendingChange(String shopId) async {
    try {
      final rows = await _db.query('settings',
          where: 'key = ?', whereArgs: [_pendingKey(shopId)], limit: 1);
      if (rows.isNotEmpty) {
        _pendingChange =
            PendingPlanChange.fromJson(rows.first['value']?.toString());
        notifyListeners();
      }
    } catch (_) {
      // A missing settings row simply means there is no scheduled change.
    }
  }

  Future<void> _applyDuePendingChange(String shopId) async {
    final pending = _pendingChange;
    if (pending == null) return;
    final now = DateTime.now();
    if (pending.effectiveDate.isAfter(now)) return;
    await _persistPlan(
      shopId: shopId,
      plan: pending.plan,
      addOns: pending.addOns,
      expiry: now.add(const Duration(days: 30)),
    );
  }

  Future<void> _persistPlan({
    required String shopId,
    required SubscriptionPlan plan,
    required List<SubscriptionAddOn> addOns,
    required DateTime expiry,
  }) async {
    final now = DateTime.now();
    final data = {
      'shopId': shopId,
      'plan': plan.name.toLowerCase(),
      'activationDate': now.toIso8601String(),
      'expiryDate': expiry.toIso8601String(),
      'addOns': jsonEncode(addOns.map((e) => e.name).toList()),
      'isTrial': 0,
      'userLimit': userLimitFor(plan, addOns),
      'branchLimit': branchLimitFor(plan, addOns),
    };
    await _db.saveSubscription(data);
    _current = ActiveSubscription.fromMap(data);
    _shopId = shopId;
    _isReady = true;
    _pendingChange = null;
    await _savePending(shopId);
    _startExpirationTimer();
    notifyListeners();
    unawaited(_syncWithServer(shopId));
  }

  Future<void> _assertUsageFits(String shopId, PlanChangeQuote quote) async {
    try {
      final users =
          await _db.query('users', where: 'shopId = ?', whereArgs: [shopId]);
      final branches =
          await _db.query('branches', where: 'shopId = ?', whereArgs: [shopId]);
      if (users.length > quote.userLimit) {
        throw PlanChangeException(
            'This shop has ${users.length} users but the '
            '${quote.targetPlan.name} plan allows ${quote.userLimit}. '
            'Remove users before downgrading.');
      }
      if (branches.length > quote.branchLimit) {
        throw PlanChangeException(
            'This shop has ${branches.length} branches but the '
            '${quote.targetPlan.name} plan allows ${quote.branchLimit}. '
            'Remove branches before downgrading.');
      }
    } on PlanChangeException {
      rethrow;
    } catch (_) {
      // If usage cannot be counted, do not block the change.
    }
  }

  /// Pulls the backend copy and keeps whichever side expires later.
  Future<void> refresh() async {
    final shopId = _shopId;
    if (shopId == null) return;
    await _applyDuePendingChange(shopId);
    await _syncWithServer(shopId);
  }

  ApiAuthClient _client() => ApiAuthClient(
        baseUrl: ConnectionService().baseUrl,
        identityService: IdentityService(_db),
      );

  Future<void> _syncWithServer(String shopId) async {
    if (_isSyncing) return;
    _isSyncing = true;
    notifyListeners();
    try {
      final client = _client();
      Map<String, dynamic> response;
      try {
        response = await client.getSubscriptionRemote();
      } catch (e) {
        debugPrint('[SUBSCRIPTION SYNC] pull failed: $e');
        return;
      }

      final remote = response['subscription'];
      final remoteExpiry = remote is Map
          ? DateTime.tryParse(remote['expiryDate']?.toString() ?? '')
          : null;
      final local = _current;

      if (remote is Map && (local == null || (remoteExpiry != null && remoteExpiry.isAfter(local.expiryDate)))) {
        final data = _localRowFromRemote(shopId, Map<String, dynamic>.from(remote));
        await _db.saveSubscription(data);
        await _loadSubscription(shopId);
        _startExpirationTimer();
        notifyListeners();
        return;
      }

      final remotePending = _pendingFromRemote(remote);
      if (remotePending != null &&
          (_pendingChange == null ||
              remotePending.effectiveDate
                  .isAfter(_pendingChange!.effectiveDate))) {
        _pendingChange = remotePending;
        await _savePending(shopId);
        notifyListeners();
      }

      final localPendingMissingOnServer =
          _pendingChange != null && remotePending == null;
      if (local != null &&
          (remoteExpiry == null ||
              local.expiryDate.isAfter(remoteExpiry) ||
              localPendingMissingOnServer)) {
        try {
          await client.saveSubscriptionRemote(_remotePayload(local));
        } catch (e) {
          debugPrint('[SUBSCRIPTION SYNC] push failed: $e');
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _remotePayload(ActiveSubscription sub) => {
        'plan': sub.plan.name.toLowerCase(),
        'activationDate': sub.activationDate.toUtc().toIso8601String(),
        'expiryDate': sub.expiryDate.toUtc().toIso8601String(),
        'addOns': jsonEncode(sub.addOns.map((e) => e.name).toList()),
        'isTrial': sub.isTrial,
        'userLimit': sub.userLimit,
        'branchLimit': sub.branchLimit,
        'pendingPlan': _pendingChange?.plan.name.toLowerCase(),
        'pendingAddOns': _pendingChange == null
            ? null
            : jsonEncode(
                _pendingChange!.addOns.map((a) => a.name).toList()),
        'pendingEffectiveDate':
            _pendingChange?.effectiveDate.toUtc().toIso8601String(),
        'pendingPrice': _pendingChange?.monthlyPrice,
      };

  PendingPlanChange? _pendingFromRemote(Object? remote) {
    if (remote is! Map) return null;
    final planName = remote['pendingPlan']?.toString();
    final effective =
        DateTime.tryParse(remote['pendingEffectiveDate']?.toString() ?? '');
    if (planName == null || planName.isEmpty || effective == null) return null;
    final plan = SubscriptionPlan.values.firstWhere(
      (p) => p.name.toLowerCase() == planName.toLowerCase(),
      orElse: () => SubscriptionPlan.none,
    );
    if (plan == SubscriptionPlan.none) return null;
    final addOns = <SubscriptionAddOn>[];
    final rawAddOns = remote['pendingAddOns'];
    Iterable<dynamic> names = const [];
    if (rawAddOns is String && rawAddOns.trim().isNotEmpty) {
      try {
        names = (jsonDecode(rawAddOns) as List?) ?? const [];
      } catch (_) {
        names = const [];
      }
    } else if (rawAddOns is List) {
      names = rawAddOns;
    }
    for (final name in names) {
      for (final candidate in SubscriptionAddOn.values) {
        if (candidate.name == name) addOns.add(candidate);
      }
    }
    return PendingPlanChange(
      plan: plan,
      addOns: addOns,
      effectiveDate: effective,
      monthlyPrice: (remote['pendingPrice'] as num?)?.toDouble() ??
          monthlyPriceFor(plan, addOns),
    );
  }

  Map<String, dynamic> _localRowFromRemote(
      String shopId, Map<String, dynamic> remote) {
    final rawAddOns = remote['addOns'] ?? '[]';
    final addOns = rawAddOns is List ? jsonEncode(rawAddOns) : rawAddOns.toString();
    final activation =
        DateTime.tryParse(remote['activationDate']?.toString() ?? '') ??
            DateTime.now();
    return {
      'shopId': shopId,
      'plan': (remote['plan'] ?? 'trial').toString().toLowerCase(),
      'activationDate': activation.toIso8601String(),
      'expiryDate': remote['expiryDate'].toString(),
      'addOns': addOns,
      'isTrial': remote['isTrial'] == true || remote['isTrial'] == 1,
      'userLimit': remote['userLimit'] ?? 3,
      'branchLimit': remote['branchLimit'] ?? 1,
    };
  }

  String _lastRemainingSignature = '';

  /// Countdown ticker.
  ///
  /// This used to call notifyListeners() every second for the whole app
  /// lifetime, waking every subscription listener once per second. It now only
  /// notifies when the value a user can actually see changes (seconds while
  /// under five minutes, minutes otherwise) and only while something listens.
  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    _lastRemainingSignature = '';
    if (_current == null || _current!.isExpired) return;

    _expirationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final sub = _current;
      if (sub == null) {
        timer.cancel();
        return;
      }

      final remaining = sub.remainingTime;
      final signature = remaining.inMinutes < 5
          ? 's${remaining.inSeconds}'
          : 'm${remaining.inMinutes}';

      if (signature != _lastRemainingSignature) {
        _lastRemainingSignature = signature;
        if (hasListeners) notifyListeners();
      }

      if (sub.isExpired) timer.cancel();
    });
  }

  /// Cancels the plan locally and on the backend so it does not come back
  /// on the next sync.
  Future<void> cancelSubscription(String shopId) async {
    clear();
    try {
      await _client().cancelSubscriptionRemote();
    } catch (e) {
      debugPrint('[SUBSCRIPTION SYNC] cancel failed: $e');
    }
    await startTrial(shopId);
    unawaited(_syncWithServer(shopId));
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
