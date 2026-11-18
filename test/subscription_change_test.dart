import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/core/services/subscription_change.dart';

ActiveSubscription _current({
  required SubscriptionPlan plan,
  required DateTime expiry,
  List<SubscriptionAddOn> addOns = const [],
  int userLimit = 3,
  int branchLimit = 1,
}) {
  return ActiveSubscription(
    shopId: 'shop-1',
    plan: plan,
    activationDate: expiry.subtract(const Duration(days: 30)),
    expiryDate: expiry,
    addOns: addOns,
    isTrial: false,
    userLimit: userLimit,
    branchLimit: branchLimit,
  );
}

void main() {
  final now = DateTime(2026, 5, 1, 12);
  final midCycle = now.add(const Duration(days: 15));

  group('new subscription', () {
    test('charges the full first month today', () {
      final quote = quotePlanChange(
        current: null,
        targetPlan: SubscriptionPlan.business,
        targetAddOns: const [],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.newSubscription);
      expect(quote.amountDueToday, 25);
    });
  });

  group('upgrade', () {
    test('applies immediately and charges the full new price', () {
      final quote = quotePlanChange(
        current: _current(plan: SubscriptionPlan.starter, expiry: midCycle),
        targetPlan: SubscriptionPlan.business,
        targetAddOns: const [],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.upgrade);
      expect(quote.amountDueToday, 25);
      expect(quote.effectiveDate, now);
      expect(quote.remainingDays, 15);
    });

    test('adding an add-on to the same plan is an immediate upgrade', () {
      final quote = quotePlanChange(
        current: _current(plan: SubscriptionPlan.starter, expiry: midCycle),
        targetPlan: SubscriptionPlan.starter,
        targetAddOns: const [SubscriptionAddOn.fefoBatchTracking],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.upgrade);
      expect(quote.amountDueToday, 20);
      expect(quote.targetMonthly, 20);
    });

    test('keeps the renewal date and carries the new limits', () {
      final quote = quotePlanChange(
        current: _current(plan: SubscriptionPlan.business, expiry: midCycle),
        targetPlan: SubscriptionPlan.enterprise,
        targetAddOns: const [SubscriptionAddOn.extraUser],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.upgrade);
      expect(quote.userLimit, 16);
      expect(quote.branchLimit, 10);
      expect(quote.effectiveDate, now);
    });
  });

  group('downgrade', () {
    test('applies immediately with nothing due today', () {
      final quote = quotePlanChange(
        current: _current(plan: SubscriptionPlan.business, expiry: midCycle),
        targetPlan: SubscriptionPlan.starter,
        targetAddOns: const [],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.downgrade);
      expect(quote.amountDueToday, 0);
      expect(quote.effectiveDate, now);
      expect(quote.userLimit, 3);
      expect(quote.branchLimit, 1);
    });

    test('removing an add-on applies immediately and is not charged', () {
      final quote = quotePlanChange(
        current: _current(
          plan: SubscriptionPlan.starter,
          expiry: midCycle,
          addOns: const [SubscriptionAddOn.extraBranch],
        ),
        targetPlan: SubscriptionPlan.starter,
        targetAddOns: const [],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.downgrade);
      expect(quote.amountDueToday, 0);
    });
  });

  group('lateral change', () {
    test('same price is applied immediately for free', () {
      final quote = quotePlanChange(
        current: _current(plan: SubscriptionPlan.business, expiry: midCycle),
        targetPlan: SubscriptionPlan.business,
        targetAddOns: const [],
        now: now,
      );
      expect(quote.kind, PlanChangeKind.lateral);
      expect(quote.amountDueToday, 0);
      expect(quote.effectiveDate, now);
    });
  });

  group('pending change persistence', () {
    test('round-trips through JSON', () {
      final restored = PendingPlanChange.fromJson(
          '{"plan":"starter","addOns":["Extra User"],'
          '"effectiveDate":"${midCycle.toIso8601String()}","monthlyPrice":17}');
      expect(restored, isNotNull);
      expect(restored!.plan, SubscriptionPlan.starter);
      expect(restored.addOns, [SubscriptionAddOn.extraUser]);
      expect(restored.effectiveDate, midCycle);
      expect(restored.monthlyPrice, 17);
    });

    test('ignores empty or malformed settings values', () {
      expect(PendingPlanChange.fromJson(''), isNull);
      expect(PendingPlanChange.fromJson(null), isNull);
      expect(PendingPlanChange.fromJson('{not json'), isNull);
    });
  });

    test('yearly plans take 15% off the plan and nothing off add-ons', () {
      expect(planPriceFor(SubscriptionPlan.starter, BillingCycle.yearly), 153);
      expect(annualSavingsFor(SubscriptionPlan.business), 45);
      expect(
        termPriceFor(SubscriptionPlan.business,
            const [SubscriptionAddOn.extraUser], BillingCycle.yearly),
        267,
      );
      expect(
        termPriceFor(SubscriptionPlan.business, const [], BillingCycle.monthly),
        25,
      );
    });
}
