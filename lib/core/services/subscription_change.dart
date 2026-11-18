import 'dart:convert';

import '../models/subscription_models.dart';

/// How a plan change is applied.
///
/// Every plan change takes effect the moment it is confirmed: an increase is
/// charged at the full new price today, a decrease costs nothing today. Nothing
/// is prorated and nothing waits for the renewal date.
enum PlanChangeKind { newSubscription, upgrade, downgrade, lateral }

class PlanChangeException implements Exception {
  PlanChangeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A downgrade that will replace the current plan when it renews.
class PendingPlanChange {
  const PendingPlanChange({
    required this.plan,
    required this.addOns,
    required this.effectiveDate,
    required this.monthlyPrice,
  });

  final SubscriptionPlan plan;
  final List<SubscriptionAddOn> addOns;
  final DateTime effectiveDate;
  final double monthlyPrice;

  Map<String, dynamic> toJson() => {
        'plan': plan.name.toLowerCase(),
        'addOns': addOns.map((a) => a.name).toList(),
        'effectiveDate': effectiveDate.toIso8601String(),
        'monthlyPrice': monthlyPrice,
      };

  static PendingPlanChange? fromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final plan = SubscriptionPlan.values.firstWhere(
        (p) => p.name.toLowerCase() == map['plan'].toString().toLowerCase(),
        orElse: () => SubscriptionPlan.none,
      );
      final effective = DateTime.tryParse(map['effectiveDate']?.toString() ?? '');
      if (plan == SubscriptionPlan.none || effective == null) return null;
      final addOns = <SubscriptionAddOn>[];
      for (final raw in (map['addOns'] as List? ?? const [])) {
        for (final candidate in SubscriptionAddOn.values) {
          if (candidate.name == raw) addOns.add(candidate);
        }
      }
      return PendingPlanChange(
        plan: plan,
        addOns: addOns,
        effectiveDate: effective,
        monthlyPrice: (map['monthlyPrice'] as num?)?.toDouble() ??
            monthlyPriceFor(plan, addOns),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Everything the UI needs to explain and charge a plan change.
class PlanChangeQuote {
  const PlanChangeQuote({
    required this.kind,
    required this.targetPlan,
    required this.addOns,
    required this.currentMonthly,
    required this.targetMonthly,
    required this.amountDueToday,
    required this.effectiveDate,
    required this.remainingDays,
    required this.userLimit,
    required this.branchLimit,
  });

  final PlanChangeKind kind;
  final SubscriptionPlan targetPlan;
  final List<SubscriptionAddOn> addOns;
  final double currentMonthly;
  final double targetMonthly;
  final double amountDueToday;
  final DateTime effectiveDate;
  final int remainingDays;
  final int userLimit;
  final int branchLimit;

  bool get isUpgrade => kind == PlanChangeKind.upgrade;
  double get difference => targetMonthly - currentMonthly;
}

double monthlyPriceFor(
    SubscriptionPlan plan, List<SubscriptionAddOn> addOns) {
  return plan.price +
      addOns.fold<double>(0, (sum, addOn) => sum + addOn.getPrice(plan));
}

/// Yearly plans are 15% off the 12-month price.
const double annualDiscountRate = 0.15;

/// Price of the plan itself for one billing term.
double planPriceFor(SubscriptionPlan plan, BillingCycle cycle) {
  if (!cycle.isYearly) return plan.price;
  return _roundMoney(plan.price * 12 * (1 - annualDiscountRate));
}

/// Add-ons keep their monthly rate for the whole year — no annual discount.
double addOnPriceFor(
    SubscriptionPlan plan, SubscriptionAddOn addOn, BillingCycle cycle) {
  final base = addOn.getPrice(plan);
  return cycle.isYearly ? _roundMoney(base * 12) : base;
}

/// Full amount charged for one term: discounted plan + full-price add-ons.
double termPriceFor(SubscriptionPlan plan, List<SubscriptionAddOn> addOns,
    BillingCycle cycle) {
  return _roundMoney(planPriceFor(plan, cycle) +
      addOns.fold<double>(
          0, (sum, addOn) => sum + addOnPriceFor(plan, addOn, cycle)));
}

/// What a customer saves by paying yearly instead of 12 monthly plan payments.
double annualSavingsFor(SubscriptionPlan plan) => _roundMoney(
    plan.price * 12 - planPriceFor(plan, BillingCycle.yearly));

/// The effective monthly cost when billed yearly.
double annualMonthlyEquivalentFor(SubscriptionPlan plan) =>
    _roundMoney(planPriceFor(plan, BillingCycle.yearly) / 12);

int userLimitFor(SubscriptionPlan plan, List<SubscriptionAddOn> addOns) {
  var limit = 3;
  if (plan == SubscriptionPlan.business) limit = 10;
  if (plan == SubscriptionPlan.enterprise) limit = 15;
  limit += addOns.where((a) => a == SubscriptionAddOn.extraUser).length;
  return limit;
}

int branchLimitFor(SubscriptionPlan plan, List<SubscriptionAddOn> addOns) {
  var limit = 1;
  if (plan == SubscriptionPlan.business) limit = 5;
  if (plan == SubscriptionPlan.enterprise) limit = 10;
  limit += addOns.where((a) => a == SubscriptionAddOn.extraBranch).length;
  return limit;
}

double _roundMoney(double value) => (value * 100).round() / 100;

/// Quotes a plan change for the current subscription.
///
/// - No subscription → new subscription, full first month due today.
/// - Higher monthly price → upgrade now, the full new price is due today and
///   the renewal date does not move.
/// - Lower monthly price → takes effect immediately, nothing due today.
///
/// Plan changes are never prorated or deferred: they apply the moment the
/// customer confirms, which keeps the price they see the price they pay.
PlanChangeQuote quotePlanChange({
  required ActiveSubscription? current,
  required SubscriptionPlan targetPlan,
  required List<SubscriptionAddOn> targetAddOns,
  DateTime? now,
}) {
  final moment = now ?? DateTime.now();
  final targetMonthly = monthlyPriceFor(targetPlan, targetAddOns);
  final userLimit = userLimitFor(targetPlan, targetAddOns);
  final branchLimit = branchLimitFor(targetPlan, targetAddOns);

  if (current == null) {
    return PlanChangeQuote(
      kind: PlanChangeKind.newSubscription,
      targetPlan: targetPlan,
      addOns: targetAddOns,
      currentMonthly: 0,
      targetMonthly: targetMonthly,
      amountDueToday: _roundMoney(targetMonthly),
      effectiveDate: moment,
      remainingDays: 0,
      userLimit: userLimit,
      branchLimit: branchLimit,
    );
  }

  final currentMonthly = monthlyPriceFor(current.plan, current.addOns);
  final remaining = current.expiryDate.difference(moment);
  final remainingDays = remaining.isNegative ? 0 : remaining.inHours ~/ 24;

  if (targetMonthly > currentMonthly + 0.001) {
    return PlanChangeQuote(
      kind: PlanChangeKind.upgrade,
      targetPlan: targetPlan,
      addOns: targetAddOns,
      currentMonthly: currentMonthly,
      targetMonthly: targetMonthly,
      // Charged like a fresh purchase of the plan, never prorated.
      amountDueToday: _roundMoney(targetMonthly),
      effectiveDate: moment,
      remainingDays: remainingDays,
      userLimit: userLimit,
      branchLimit: branchLimit,
    );
  }

  if (targetMonthly < currentMonthly - 0.001) {
    return PlanChangeQuote(
      kind: PlanChangeKind.downgrade,
      targetPlan: targetPlan,
      addOns: targetAddOns,
      currentMonthly: currentMonthly,
      targetMonthly: targetMonthly,
      amountDueToday: 0,
      effectiveDate: moment,
      remainingDays: remainingDays,
      userLimit: userLimit,
      branchLimit: branchLimit,
    );
  }

  return PlanChangeQuote(
    kind: PlanChangeKind.lateral,
    targetPlan: targetPlan,
    addOns: targetAddOns,
    currentMonthly: currentMonthly,
    targetMonthly: targetMonthly,
    amountDueToday: 0,
    effectiveDate: moment,
    remainingDays: remainingDays,
    userLimit: userLimit,
    branchLimit: branchLimit,
  );
}
