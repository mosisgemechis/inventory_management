// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/core/services/subscription_service.dart';
import 'package:inventory_manager/core/services/auth_service.dart';
import 'package:inventory_manager/core/services/database_service.dart';
import 'package:inventory_manager/core/widgets/loading_overlay.dart';
import 'package:inventory_manager/core/utils/currency_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _navyPrimary = Color(0xFF0F172A);
const Color _accentBlue = Color(0xFF2563EB);
const Color _borderGray = Color(0xFFE2E8F0);
const Color _bgWhite = Color(0xFFFFFFFF);
const Color _textDark = Color(0xFF1E293B);
const Color _textLight = Color(0xFF64748B);

enum _PaymentMethod { telebirr, card }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final GlobalKey _plansSectionKey = GlobalKey();
  final Map<SubscriptionPlan, _PlanCustomization> _customizations = {};
  SubscriptionPlan? _selectedPlan;
  _PaymentMethod _paymentMethod = _PaymentMethod.telebirr;

  SubscriptionService get _subscriptionService =>
      Provider.of<SubscriptionService>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final subscription = context.watch<SubscriptionService>().current;
    final authUser = context.read<AuthService>().user;
    final activePlan = subscription?.plan ?? SubscriptionPlan.business;
    final selectedPlan = _selectedPlan ?? activePlan;
    final selectedCustomization = _customizationFor(selectedPlan);
    final selectedTotal = _planTotal(selectedPlan, selectedCustomization);
    final isDesktop = MediaQuery.sizeOf(context).width > 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _bgWhite,
        foregroundColor: _navyPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          "Plans & Billing",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: _navyPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _borderGray),
                ),
              ),
              icon: const Icon(Icons.help_outline_rounded,
                  size: 18, color: _accentBlue),
              label: const Text(
                "Need Help?",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: _ProfileBubble(
              label: authUser?.username ?? authUser?.fullName ?? "GM",
              onTap: () {},
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderGray, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1280),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 18,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CurrentSubscriptionCard(
                  subscription: subscription,
                  shopId: authUser?.shopId ?? subscription?.shopId ?? '',
                  onUpgrade: _handleUpgradePressed,
                  onDowngrade: _handleDowngradePressed,
                  onCancel: _confirmCancelSubscription,
                )
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.06, curve: Curves.easeOut),
                const SizedBox(height: 28),
                const _SectionHeading(
                  title: "Choose a Plan",
                  subtitle:
                      "Select a plan and customize it to fit your business needs",
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _plansSectionKey,
                  child: _PlanGrid(
                    selectedPlan: selectedPlan,
                    currentPlan: subscription?.plan,
                    customizations: _customizations,
                    onSelectPlan: (plan) {
                      setState(() => _selectedPlan = plan);
                    },
                    onChangeExtraUsers: (plan, delta) {
                      setState(() => _customizationFor(plan).extraUsers =
                          (_customizationFor(plan).extraUsers + delta)
                              .clamp(0, 99)
                              .toInt());
                    },
                    onChangeExtraBranches: (plan, delta) {
                      setState(() => _customizationFor(plan).extraBranches =
                          (_customizationFor(plan).extraBranches + delta)
                              .clamp(0, 99)
                              .toInt());
                    },
                    onToggleAnalytics: (plan, value) {
                      setState(() => _customizationFor(plan)
                          .advancedAnalyticsPack = value);
                    },
                    onToggleAudit: (plan, value) {
                      setState(
                          () => _customizationFor(plan).auditLogsPack = value);
                    },
                    onCheckout: _handleCheckout,
                  ),
                ),
                const SizedBox(height: 24),
                _BillingReviewSection(
                  selectedPlan: selectedPlan,
                  customization: selectedCustomization,
                  total: selectedTotal,
                  paymentMethod: _paymentMethod,
                  onPaymentMethodChanged: (method) =>
                      setState(() => _paymentMethod = method),
                  onConfirm: () =>
                      _handleCheckout(selectedPlan, selectedCustomization),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    "You can change or cancel your subscription anytime.",
                    style: TextStyle(
                        color: _textLight.withOpacity(0.95), fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _PlanCustomization _customizationFor(SubscriptionPlan plan) {
    return _customizations.putIfAbsent(plan, _PlanCustomization.new);
  }

  double _planTotal(SubscriptionPlan plan, _PlanCustomization customization) {
    double total = plan.price;
    total += customization.extraUsers *
        _addonUnitPrice(plan, SubscriptionAddOn.extraUser);
    total += customization.extraBranches *
        _addonUnitPrice(plan, SubscriptionAddOn.extraBranch);
    if (customization.advancedAnalyticsPack) {
      total += _addonUnitPrice(plan, SubscriptionAddOn.advancedAnalyticsPack);
    }
    if (customization.auditLogsPack) {
      total += _addonUnitPrice(plan, SubscriptionAddOn.auditLogsPack);
    }
    return total;
  }

  double _addonUnitPrice(SubscriptionPlan plan, SubscriptionAddOn addOn) {
    return addOn.getPrice(plan);
  }

  List<SubscriptionAddOn> _buildSelectedAddOns(
      _PlanCustomization customization) {
    final addOns = <SubscriptionAddOn>[];
    addOns.addAll(List<SubscriptionAddOn>.filled(
        customization.extraUsers, SubscriptionAddOn.extraUser));
    addOns.addAll(List<SubscriptionAddOn>.filled(
        customization.extraBranches, SubscriptionAddOn.extraBranch));
    if (customization.advancedAnalyticsPack) {
      addOns.add(SubscriptionAddOn.advancedAnalyticsPack);
    }
    if (customization.auditLogsPack) {
      addOns.add(SubscriptionAddOn.auditLogsPack);
    }
    return addOns;
  }

  void _handleUpgradePressed(SubscriptionPlan? currentPlan) {
    final nextPlan = _nextHigherPlan(currentPlan);
    if (nextPlan == null) return;
    setState(() => _selectedPlan = nextPlan);
    _scrollToPlans();
  }

  void _handleDowngradePressed(SubscriptionPlan? currentPlan) {
    final nextPlan = _nextLowerPlan(currentPlan);
    if (nextPlan == null) return;
    setState(() => _selectedPlan = nextPlan);
    _scrollToPlans();
  }

  SubscriptionPlan? _nextHigherPlan(SubscriptionPlan? currentPlan) {
    switch (currentPlan) {
      case SubscriptionPlan.starter:
        return SubscriptionPlan.business;
      case SubscriptionPlan.business:
        return SubscriptionPlan.enterprise;
      case SubscriptionPlan.enterprise:
        return null;
      case SubscriptionPlan.trial:
      case SubscriptionPlan.free:
      case SubscriptionPlan.none:
      case null:
        return SubscriptionPlan.business;
    }
  }

  SubscriptionPlan? _nextLowerPlan(SubscriptionPlan? currentPlan) {
    switch (currentPlan) {
      case SubscriptionPlan.enterprise:
        return SubscriptionPlan.business;
      case SubscriptionPlan.business:
        return SubscriptionPlan.starter;
      case SubscriptionPlan.starter:
      case SubscriptionPlan.trial:
      case SubscriptionPlan.free:
      case SubscriptionPlan.none:
      case null:
        return null;
    }
  }

  void _scrollToPlans() {
    final context = _plansSectionKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _handleCheckout(
      SubscriptionPlan plan, _PlanCustomization customization) async {
    final user = context.read<AuthService>().user;
    if (user == null) return;

    final addOns = _buildSelectedAddOns(customization);
    final total = _planTotal(plan, customization);
    final paymentLabel = _paymentMethod == _PaymentMethod.telebirr
        ? "Telebirr"
        : "Credit/Debit Card";

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Confirm subscription"),
        content: Text(
          "Continue with $paymentLabel for ${plan.name} at ${CurrencyFormatter.simple(total, 'USD')} per month?",
          style: const TextStyle(height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text("Continue"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    LoadingOverlay.show(context);
    try {
      await _subscriptionService.upgrade(
        shopId: user.shopId,
        plan: plan,
        addOns: addOns,
      );
      if (!mounted) return;
      LoadingOverlay.hide(context);
      _showSuccessDialog(plan, total);
    } catch (_) {
      if (mounted) LoadingOverlay.hide(context);
    }
  }

  Future<void> _confirmCancelSubscription() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Cancel subscription?"),
        content: const Text(
          "This will remove the active subscription from this workspace.",
          style: TextStyle(height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep Subscription"),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Cancel Subscription"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    _subscriptionService.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Subscription cancelled.")),
    );
  }

  void _showSuccessDialog(SubscriptionPlan plan, double total) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 48),
              ),
              const SizedBox(height: 24),
              const Text(
                "Subscription Active",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _navyPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                "Your ${plan.name} workspace is fully active at ${CurrencyFormatter.simple(total, 'USD')} per month.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textLight, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Go to Dashboard",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentSubscriptionCard extends StatelessWidget {
  final ActiveSubscription? subscription;
  final String shopId;
  final ValueChanged<SubscriptionPlan?> onUpgrade;
  final ValueChanged<SubscriptionPlan?> onDowngrade;
  final Future<void> Function() onCancel;

  const _CurrentSubscriptionCard({
    required this.subscription,
    required this.shopId,
    required this.onUpgrade,
    required this.onDowngrade,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final currentPlan = subscription?.plan;
    final planName = subscription == null
        ? "No active subscription"
        : subscription!.plan.name;
    final status = _statusFor(subscription);
    final statusColor = _statusColorFor(subscription);
    final nextBilling = subscription?.expiryDate;
    final userLimit = subscription?.userLimit ?? 3;
    final branchLimit = subscription?.branchLimit ?? 1;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 860;
          final body = isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CurrentPlanBadge(
                      planName: planName,
                      status: status,
                      statusColor: statusColor,
                      subscription: subscription,
                    ),
                    const SizedBox(width: 24),
                    Container(width: 1, height: 96, color: _borderGray),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _CurrentMetrics(
                        shopId: shopId,
                        userLimit: userLimit,
                        branchLimit: branchLimit,
                        nextBilling: nextBilling,
                      ),
                    ),
                    const SizedBox(width: 24),
                    _CurrentActions(
                      currentPlan: currentPlan,
                      onUpgrade: onUpgrade,
                      onDowngrade: onDowngrade,
                      onCancel: onCancel,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CurrentPlanBadge(
                      planName: planName,
                      status: status,
                      statusColor: statusColor,
                      subscription: subscription,
                    ),
                    const SizedBox(height: 20),
                    _CurrentMetrics(
                      shopId: shopId,
                      userLimit: userLimit,
                      branchLimit: branchLimit,
                      nextBilling: nextBilling,
                    ),
                    const SizedBox(height: 20),
                    _CurrentActions(
                      currentPlan: currentPlan,
                      onUpgrade: onUpgrade,
                      onDowngrade: onDowngrade,
                      onCancel: onCancel,
                    ),
                  ],
                );
          return body;
        },
      ),
    );
  }

  String _statusFor(ActiveSubscription? subscription) {
    if (subscription == null) return "Inactive";
    if (subscription.isExpired) return "Expired";
    if (subscription.isTrial) return "Trial";
    return "Active";
  }

  Color _statusColorFor(ActiveSubscription? subscription) {
    if (subscription == null) return const Color(0xFF64748B);
    if (subscription.isExpired) return const Color(0xFFDC2626);
    if (subscription.isTrial) return const Color(0xFFF59E0B);
    return const Color(0xFF16A34A);
  }
}

class _CurrentPlanBadge extends StatelessWidget {
  final String planName;
  final String status;
  final Color statusColor;
  final ActiveSubscription? subscription;

  const _CurrentPlanBadge({
    required this.planName,
    required this.status,
    required this.statusColor,
    required this.subscription,
  });

  @override
  Widget build(BuildContext context) {
    final price = subscription?.plan.price ?? SubscriptionPlan.business.price;
    final expiryLabel = subscription == null
        ? "Next billing date: —"
        : "Next billing date: ${MaterialLocalizations.of(context).formatMediumDate(subscription!.expiryDate)}";

    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _accentBlue,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.work_outline_rounded,
              color: Colors.white, size: 38),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Current Plan",
                style: TextStyle(
                    color: _textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(planName,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _navyPrimary)),
                const SizedBox(width: 10),
                _StatusPill(label: status, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: _navyPrimary),
                children: [
                  TextSpan(
                    text: CurrencyFormatter.simple(price, 'USD'),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(
                    text: " / month",
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _textLight),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(expiryLabel,
                style: const TextStyle(
                    color: _navyPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

class _CurrentMetrics extends StatelessWidget {
  final String shopId;
  final int userLimit;
  final int branchLimit;
  final DateTime? nextBilling;

  const _CurrentMetrics({
    required this.shopId,
    required this.userLimit,
    required this.branchLimit,
    required this.nextBilling,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: shopId.isEmpty ? null : DatabaseService().watchUsers(shopId),
      builder: (context, usersSnapshot) {
        final userCount = usersSnapshot.data?.length ?? 0;
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream:
              shopId.isEmpty ? null : DatabaseService().watchBranches(shopId),
          builder: (context, branchesSnapshot) {
            final branchCount = branchesSnapshot.data?.length ?? 0;
            return Wrap(
              spacing: 28,
              runSpacing: 18,
              children: [
                _MetricChip(
                  icon: Icons.groups_rounded,
                  label: "Total Users",
                  value: "$userCount / $userLimit",
                ),
                _MetricChip(
                  icon: Icons.apartment_rounded,
                  label: "Total Branches",
                  value: "$branchCount / $branchLimit",
                ),
                _MetricChip(
                  icon: Icons.calendar_month_rounded,
                  label: "Billing Cycle",
                  value: "Monthly",
                ),
                if (nextBilling != null)
                  _MetricChip(
                    icon: Icons.event_available_rounded,
                    label: "Next Billing",
                    value: MaterialLocalizations.of(context)
                        .formatMediumDate(nextBilling!),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CurrentActions extends StatelessWidget {
  final SubscriptionPlan? currentPlan;
  final ValueChanged<SubscriptionPlan?> onUpgrade;
  final ValueChanged<SubscriptionPlan?> onDowngrade;
  final Future<void> Function() onCancel;

  const _CurrentActions({
    required this.currentPlan,
    required this.onUpgrade,
    required this.onDowngrade,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canUpgrade = currentPlan == null ||
        currentPlan == SubscriptionPlan.starter ||
        currentPlan == SubscriptionPlan.business ||
        currentPlan == SubscriptionPlan.trial ||
        currentPlan == SubscriptionPlan.free ||
        currentPlan == SubscriptionPlan.none;
    final canDowngrade = currentPlan == SubscriptionPlan.enterprise ||
        currentPlan == SubscriptionPlan.business;

    return SizedBox(
      width: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: canUpgrade ? () => onUpgrade(currentPlan) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Upgrade Plan",
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: canDowngrade ? () => onDowngrade(currentPlan) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentBlue,
              side: const BorderSide(color: _accentBlue),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Downgrade Plan",
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onCancel(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFFCA5A5)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Cancel Subscription",
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _PlanGrid extends StatelessWidget {
  final SubscriptionPlan selectedPlan;
  final SubscriptionPlan? currentPlan;
  final Map<SubscriptionPlan, _PlanCustomization> customizations;
  final ValueChanged<SubscriptionPlan> onSelectPlan;
  final void Function(SubscriptionPlan plan, int delta) onChangeExtraUsers;
  final void Function(SubscriptionPlan plan, int delta) onChangeExtraBranches;
  final void Function(SubscriptionPlan plan, bool value) onToggleAnalytics;
  final void Function(SubscriptionPlan plan, bool value) onToggleAudit;
  final void Function(SubscriptionPlan plan, _PlanCustomization customization)
      onCheckout;

  const _PlanGrid({
    required this.selectedPlan,
    required this.currentPlan,
    required this.customizations,
    required this.onSelectPlan,
    required this.onChangeExtraUsers,
    required this.onChangeExtraBranches,
    required this.onToggleAnalytics,
    required this.onToggleAudit,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final plans = [
      SubscriptionPlan.starter,
      SubscriptionPlan.business,
      SubscriptionPlan.enterprise
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final children = plans.asMap().entries.map((entry) {
          final index = entry.key;
          final plan = entry.value;
          final customization = customizations[plan] ?? _PlanCustomization();
          final isSelected = selectedPlan == plan;
          final isCurrent = currentPlan == plan;
          final total = _planTotal(plan, customization);
          return Padding(
            padding: EdgeInsets.only(
              right: isDesktop && index < plans.length - 1 ? 20 : 0,
              bottom: isDesktop ? 0 : 18,
            ),
            child: _PlanCard(
              plan: plan,
              customization: customization,
              isSelected: isSelected,
              isCurrent: isCurrent,
              total: total,
              onSelect: () => onSelectPlan(plan),
              onChangeExtraUsers: (delta) => onChangeExtraUsers(plan, delta),
              onChangeExtraBranches: (delta) =>
                  onChangeExtraBranches(plan, delta),
              onToggleAnalytics: (value) => onToggleAnalytics(plan, value),
              onToggleAudit: (value) => onToggleAudit(plan, value),
              onCheckout: () => onCheckout(plan, customization),
            ),
          );
        }).toList();

        if (isDesktop) {
          return Row(
              children:
                  children.map((child) => Expanded(child: child)).toList());
        }
        return Column(children: children);
      },
    );
  }

  double _planTotal(SubscriptionPlan plan, _PlanCustomization customization) {
    double total = plan.price;
    total += customization.extraUsers *
        SubscriptionAddOn.extraUser.getPrice(plan);
    total += customization.extraBranches *
        SubscriptionAddOn.extraBranch.getPrice(plan);
    if (customization.advancedAnalyticsPack) {
      total += SubscriptionAddOn.advancedAnalyticsPack.getPrice(plan);
    }
    if (customization.auditLogsPack) {
      total += SubscriptionAddOn.auditLogsPack.getPrice(plan);
    }
    return total;
  }
}

class _PlanCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final _PlanCustomization customization;
  final bool isSelected;
  final bool isCurrent;
  final double total;
  final VoidCallback onSelect;
  final ValueChanged<int> onChangeExtraUsers;
  final ValueChanged<int> onChangeExtraBranches;
  final ValueChanged<bool> onToggleAnalytics;
  final ValueChanged<bool> onToggleAudit;
  final VoidCallback onCheckout;

  const _PlanCard({
    required this.plan,
    required this.customization,
    required this.isSelected,
    required this.isCurrent,
    required this.total,
    required this.onSelect,
    required this.onChangeExtraUsers,
    required this.onChangeExtraBranches,
    required this.onToggleAnalytics,
    required this.onToggleAudit,
    required this.onCheckout,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final availableAddOns = _availableAddOns(widget.plan);
    final totalLabel = CurrencyFormatter.simple(widget.total, 'USD');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(
            0, _isHovering || widget.isSelected ? -6 : 0, 0),
        decoration: BoxDecoration(
          color: _bgWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isSelected ? _accentBlue : _borderGray,
            width: widget.isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovering || widget.isSelected)
              BoxShadow(
                color: widget.isSelected
                    ? _accentBlue.withOpacity(0.10)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.plan == SubscriptionPlan.business)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: _accentBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: const Text(
                  "MOST POPULAR",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.plan.name,
                          style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: _navyPrimary),
                        ),
                      ),
                      if (widget.isCurrent)
                        const _StatusPill(
                            label: "Current", color: Color(0xFF16A34A)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: RichText(
                      key: ValueKey(totalLabel),
                      text: TextSpan(
                        style: const TextStyle(color: _navyPrimary),
                        children: [
                          TextSpan(
                            text: totalLabel,
                            style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                height: 1),
                          ),
                          const TextSpan(
                            text: " / month",
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ..._planFeatures(widget.plan).map((feature) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: _accentBlue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: _textLight,
                                  height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (widget.isSelected) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 32, color: _borderGray),
                    const Text(
                      "ADD-ONS",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 16),
                    ...availableAddOns
                        .map((addOn) => _buildAddonRow(context, addOn)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: widget.isCurrent
                          ? null
                          : (widget.isSelected
                              ? widget.onCheckout
                              : widget.onSelect),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isCurrent
                            ? _accentBlue
                            : widget.isSelected
                                ? _navyPrimary
                                : _bgWhite,
                        foregroundColor: widget.isCurrent || widget.isSelected
                            ? Colors.white
                            : _navyPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: widget.isCurrent || widget.isSelected
                            ? BorderSide.none
                            : const BorderSide(color: _accentBlue),
                      ),
                      child: Text(
                        widget.isCurrent
                            ? "Current Plan"
                            : widget.isSelected
                                ? "Continue with ${widget.plan.name}"
                                : "Choose Plan",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonRow(BuildContext context, SubscriptionAddOn addOn) {
    if (addOn == SubscriptionAddOn.extraUser) {
      return _QuantityAddonRow(
        title: "Extra Users",
        description: "Add more seats to your account.",
        unitPriceLabel: CurrencyFormatter.simple(
            _addonUnitPrice(widget.plan, addOn), 'USD'),
        quantity: widget.customization.extraUsers,
        onDecrease: () => widget.onChangeExtraUsers(-1),
        onIncrease: () => widget.onChangeExtraUsers(1),
      );
    }

    if (addOn == SubscriptionAddOn.extraBranch) {
      return _QuantityAddonRow(
        title: "Extra Branches",
        description: "Add more branch locations.",
        unitPriceLabel: CurrencyFormatter.simple(
            _addonUnitPrice(widget.plan, addOn), 'USD'),
        quantity: widget.customization.extraBranches,
        onDecrease: () => widget.onChangeExtraBranches(-1),
        onIncrease: () => widget.onChangeExtraBranches(1),
      );
    }

    final isAnalytics = addOn == SubscriptionAddOn.advancedAnalyticsPack;
    final isSelected = isAnalytics
        ? widget.customization.advancedAnalyticsPack
        : widget.customization.auditLogsPack;
    final title = isAnalytics ? "Advanced Analytics Pack" : "Audit Logs Pack";
    final description = isAnalytics
        ? "Unlock advanced analytics and insights."
        : "Extended audit logs and security tracking.";
    final unitPrice =
        CurrencyFormatter.simple(_addonUnitPrice(widget.plan, addOn), 'USD');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? _accentBlue.withOpacity(0.04)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isSelected ? _accentBlue.withOpacity(0.35) : _borderGray),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                  isAnalytics
                      ? Icons.analytics_rounded
                      : Icons.verified_user_rounded,
                  color: _accentBlue,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _navyPrimary,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: _textLight, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("+$unitPrice / month",
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _navyPrimary,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Switch.adaptive(
                  value: isSelected,
                  onChanged: isAnalytics
                      ? widget.onToggleAnalytics
                      : widget.onToggleAudit,
                  activeColor: _accentBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _planFeatures(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
        return [
          "Up to 3 Users",
          "1 Supported Branch",
          "Basic Inventory Tracking",
          "Core POS & Sales Billing",
        ];
      case SubscriptionPlan.business:
        return [
          "Up to 10 Users",
          "5 Supported Branches",
          "FEFO + Batch Tracking",
          "Expiry Tracking",
          "Advanced Reports & Analytics",
          "Full Audit Trail & Logs",
          "Custom Staff Roles & Permissions",
        ];
      case SubscriptionPlan.enterprise:
        return [
          "Up to 100 Users",
          "70 Supported Branches",
          "Everything in Business",
          "Advanced Analytics Pack",
          "Audit Logs Pack",
          "Advanced Monitoring",
        ];
      default:
        return [];
    }
  }

  List<SubscriptionAddOn> _availableAddOns(SubscriptionPlan plan) {
    return [
      SubscriptionAddOn.extraUser,
      SubscriptionAddOn.extraBranch,
      SubscriptionAddOn.advancedAnalyticsPack,
      SubscriptionAddOn.auditLogsPack,
    ].where((addOn) => _addonUnitPrice(plan, addOn) > 0).toList();
  }

  double _addonUnitPrice(SubscriptionPlan plan, SubscriptionAddOn addOn) {
    return addOn.getPrice(plan);
  }
}

class _QuantityAddonRow extends StatelessWidget {
  final String title;
  final String description;
  final String unitPriceLabel;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantityAddonRow({
    required this.title,
    required this.description,
    required this.unitPriceLabel,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderGray),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  color: _accentBlue, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _navyPrimary,
                          fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12, color: _textLight, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderGray),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: quantity > 0 ? onDecrease : null,
                        icon: const Icon(Icons.remove_rounded),
                        splashRadius: 18,
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: SizedBox(
                          width: 26,
                          key: ValueKey(quantity),
                          child: Text(
                            quantity.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _navyPrimary),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onIncrease,
                        icon: const Icon(Icons.add_rounded),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text("+$unitPriceLabel / user",
                    style: const TextStyle(fontSize: 12, color: _textLight)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingReviewSection extends StatelessWidget {
  final SubscriptionPlan selectedPlan;
  final _PlanCustomization customization;
  final double total;
  final _PaymentMethod paymentMethod;
  final ValueChanged<_PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onConfirm;

  const _BillingReviewSection({
    required this.selectedPlan,
    required this.customization,
    required this.total,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 980;
    final summaryCard = SizedBox(
      width: isWide ? 360 : double.infinity,
      child: _OrderSummaryCard(
        selectedPlan: selectedPlan,
        customization: customization,
        total: total,
      ),
    );

    final paymentCard = Expanded(
      child: _PaymentMethodsCard(
        paymentMethod: paymentMethod,
        total: total,
        onPaymentMethodChanged: onPaymentMethodChanged,
        onConfirm: onConfirm,
      ),
    );

    return isWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              paymentCard,
              const SizedBox(width: 22),
              summaryCard,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summaryCard,
              const SizedBox(height: 20),
              _PaymentMethodsCard(
                paymentMethod: paymentMethod,
                total: total,
                onPaymentMethodChanged: onPaymentMethodChanged,
                onConfirm: onConfirm,
              ),
            ],
          );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final SubscriptionPlan selectedPlan;
  final _PlanCustomization customization;
  final double total;

  const _OrderSummaryCard({
    required this.selectedPlan,
    required this.customization,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final totalLabel = CurrencyFormatter.simple(total, 'USD');
    final baseLabel = CurrencyFormatter.simple(selectedPlan.price, 'USD');
    return Container(
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Order Summary",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _navyPrimary)),
            const SizedBox(height: 18),
            _SummaryLine(label: "${selectedPlan.name} Plan", amount: baseLabel),
            if (customization.extraUsers > 0)
              _SummaryLine(
                label:
                    "Extra Users (${customization.extraUsers} × ${CurrencyFormatter.simple(SubscriptionAddOn.extraUser.getPrice(selectedPlan), 'USD')})",
                amount: CurrencyFormatter.simple(
                    customization.extraUsers *
                        SubscriptionAddOn.extraUser.getPrice(selectedPlan),
                    'USD'),
              ),
            if (customization.extraBranches > 0)
              _SummaryLine(
                label:
                    "Extra Branches (${customization.extraBranches} × ${CurrencyFormatter.simple(SubscriptionAddOn.extraBranch.getPrice(selectedPlan), 'USD')})",
                amount: CurrencyFormatter.simple(
                    customization.extraBranches *
                        SubscriptionAddOn.extraBranch.getPrice(selectedPlan),
                    'USD'),
              ),
            if (customization.advancedAnalyticsPack)
              _SummaryLine(
                label: "Advanced Analytics Pack",
                amount: CurrencyFormatter.simple(
                    SubscriptionAddOn.advancedAnalyticsPack
                        .getPrice(selectedPlan),
                    'USD'),
              ),
            if (customization.auditLogsPack)
              _SummaryLine(
                label: "Audit Logs Pack",
                amount: CurrencyFormatter.simple(
                    SubscriptionAddOn.auditLogsPack.getPrice(selectedPlan),
                    'USD'),
              ),
            const Divider(height: 30, color: _borderGray),
            _SummaryLine(
              label: "Total (per month)",
              amount: totalLabel,
              bold: true,
              amountColor: _accentBlue,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  final _PaymentMethod paymentMethod;
  final double total;
  final ValueChanged<_PaymentMethod> onPaymentMethodChanged;
  final VoidCallback onConfirm;

  const _PaymentMethodsCard({
    required this.paymentMethod,
    required this.total,
    required this.onPaymentMethodChanged,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final totalLabel = CurrencyFormatter.simple(total, 'USD');
    return Container(
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderGray),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Payment Method",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _navyPrimary)),
            const SizedBox(height: 8),
            const Text("Choose your preferred payment method",
                style: TextStyle(fontSize: 13, color: _textLight)),
            const SizedBox(height: 16),
            _PaymentChoiceTile(
              selected: paymentMethod == _PaymentMethod.telebirr,
              icon: Icons.account_balance_wallet_rounded,
              label: "Telebirr",
              onTap: () => onPaymentMethodChanged(_PaymentMethod.telebirr),
            ),
            const SizedBox(height: 10),
            _PaymentChoiceTile(
              selected: paymentMethod == _PaymentMethod.card,
              icon: Icons.credit_card_rounded,
              label: "Credit / Debit Card",
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("VISA",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _accentBlue)),
                  SizedBox(width: 10),
                  Text("MC",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.redAccent)),
                ],
              ),
              onTap: () => onPaymentMethodChanged(_PaymentMethod.card),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderGray),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _accentBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: _accentBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Secure Payment",
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _navyPrimary)),
                        SizedBox(height: 4),
                        Text(
                            "Your payment information is encrypted and secure.",
                            style: TextStyle(
                                fontSize: 12, color: _textLight, height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: total, end: total),
              duration: const Duration(milliseconds: 220),
              builder: (context, value, child) {
                return SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      "Confirm & Continue to Payment • $totalLabel",
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentChoiceTile extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PaymentChoiceTile({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _accentBlue.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? _accentBlue : _borderGray,
              width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
              activeColor: _accentBlue,
            ),
            const SizedBox(width: 6),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _accentBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _accentBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _navyPrimary)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String amount;
  final bool bold;
  final Color amountColor;

  const _SummaryLine({
    required this.label,
    required this.amount,
    this.bold = false,
    this.amountColor = _navyPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: bold ? _navyPrimary : _textLight,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: bold ? 15 : 13,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: textStyle)),
          const SizedBox(width: 12),
          Text(amount, style: textStyle.copyWith(color: amountColor)),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w800, color: _navyPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _textLight, height: 1.5),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _navyPrimary.withOpacity(0.7), size: 22),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: _textLight)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _navyPrimary)),
          ],
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileBubble extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ProfileBubble({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF94A3B8),
              child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : "G",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _navyPrimary,
                    fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: _textLight),
          ],
        ),
      ),
    );
  }
}

class _PlanCustomization {
  int extraUsers = 0;
  int extraBranches = 0;
  bool advancedAnalyticsPack = false;
  bool auditLogsPack = false;
}
