import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/core/services/feature_gating_service.dart';
import 'package:inventory_manager/core/services/subscription_service.dart';

ActiveSubscription _subscription({
  required DateTime expiry,
  SubscriptionPlan plan = SubscriptionPlan.starter,
  List<SubscriptionAddOn> addOns = const [],
  int userLimit = 3,
  int branchLimit = 1,
}) {
  return ActiveSubscription(
    shopId: 'shop-1',
    plan: plan,
    activationDate: DateTime.now().subtract(const Duration(days: 1)),
    expiryDate: expiry,
    addOns: addOns,
    isTrial: false,
    userLimit: userLimit,
    branchLimit: branchLimit,
  );
}

void main() {
  final service = subscriptionService;

  tearDown(() {
    service.debugSetState(current: null, ready: false);
  });

  group('subscription still loading', () {
    setUp(() => service.debugSetState(current: null, ready: false));

    test('features and limits are not blocked while the plan is unknown', () {
      expect(service.isReady, isFalse, reason: 'initialize has not finished');
      expect(FeatureGatingService.isReadOnly(), isFalse);
      expect(FeatureGatingService.hasFeature(Feature.posBilling), isTrue);
      expect(FeatureGatingService.hasFeature(Feature.inventoryManagement), isTrue);
      expect(FeatureGatingService.canSell(), isTrue);
      expect(FeatureGatingService.canAddInventory(), isTrue);
      expect(FeatureGatingService.canAddPurchases(), isTrue);
      expect(FeatureGatingService.maxUsers(), 9999);
      expect(FeatureGatingService.maxBranches(), 9999);
    });
  });

  group('no plan after loading', () {
    setUp(() => service.debugSetState(current: null, ready: true));

    test('the app becomes read-only and write actions are blocked', () {
      expect(service.isReady, isTrue);
      expect(FeatureGatingService.isReadOnly(), isTrue);
      expect(FeatureGatingService.hasFeature(Feature.posBilling), isFalse);
      expect(FeatureGatingService.canSell(), isFalse);
      expect(FeatureGatingService.canAddInventory(), isFalse);
      expect(FeatureGatingService.canCollectDebt(), isFalse);
      expect(FeatureGatingService.maxUsers(), 3);
      expect(FeatureGatingService.maxBranches(), 1);
    });
  });

  group('expired plan', () {
    setUp(() {
      service.debugSetState(
        current: _subscription(
            expiry: DateTime.now().subtract(const Duration(days: 1))),
        ready: true,
      );
    });

    test('an expired Starter plan blocks selling and product writes', () {
      expect(FeatureGatingService.isReadOnly(), isTrue);
      expect(FeatureGatingService.hasFeature(Feature.posBilling), isFalse);
      expect(FeatureGatingService.canSell(), isFalse);
      expect(FeatureGatingService.canAddInventory(), isFalse);
      expect(FeatureGatingService.canEditProducts(), isFalse);
    });
  });

  group('active Starter plan', () {
    setUp(() {
      service.debugSetState(
        current: _subscription(
            expiry: DateTime.now().add(const Duration(days: 20))),
        ready: true,
      );
    });

    test('allows its own features and refuses the higher-tier ones', () {
      expect(FeatureGatingService.isReadOnly(), isFalse);
      expect(FeatureGatingService.canSell(), isTrue);
      expect(FeatureGatingService.canAddInventory(), isTrue);
      expect(FeatureGatingService.canAddUsers(), isTrue);
      expect(FeatureGatingService.canAddPurchases(), isFalse);
      expect(FeatureGatingService.canManageBranches(), isFalse);
      expect(FeatureGatingService.canTransferStock(), isFalse);
      expect(FeatureGatingService.maxUsers(), 3);
      expect(FeatureGatingService.maxBranches(), 1);
    });
  });

  group('active Business plan', () {
    setUp(() {
      service.debugSetState(
        current: _subscription(
          expiry: DateTime.now().add(const Duration(days: 20)),
          plan: SubscriptionPlan.business,
          userLimit: 10,
          branchLimit: 5,
        ),
        ready: true,
      );
    });

    test('unlocks purchases, branches and the plan limits', () {
      expect(FeatureGatingService.canAddPurchases(), isTrue);
      expect(FeatureGatingService.canManageBranches(), isTrue);
      expect(FeatureGatingService.canTransferStock(), isTrue);
      // Advanced reports are an add-on now; Business ships basic reports and
      // includes the audit history.
      expect(FeatureGatingService.canViewAdvancedReports(), isFalse);
      expect(FeatureGatingService.hasFeature(Feature.auditLogs), isTrue);
      expect(FeatureGatingService.maxUsers(), 10);
      expect(FeatureGatingService.maxBranches(), 5);
    });
  });

  group('active trial', () {
    setUp(() {
      service.debugSetState(
        current: ActiveSubscription(
          shopId: 'shop-1',
          plan: SubscriptionPlan.trial,
          activationDate: DateTime.now().subtract(const Duration(days: 1)),
          expiryDate: DateTime.now().add(const Duration(days: 5)),
          addOns: const [],
          isTrial: true,
          userLimit: 3,
          branchLimit: 1,
        ),
        ready: true,
      );
    });

    test('unlocks enterprise features but keeps trial seat and branch limits',
        () {
      expect(FeatureGatingService.hasFeature(Feature.centralDashboard), isTrue);
      expect(FeatureGatingService.hasFeature(Feature.auditLogs), isTrue);
      expect(FeatureGatingService.canManageBranches(), isTrue);
      expect(FeatureGatingService.maxUsers(), 3);
      expect(FeatureGatingService.maxBranches(), 1);
    });
  });
}
