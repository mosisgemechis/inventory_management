// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/core/services/subscription_change.dart';
import 'package:inventory_manager/core/services/subscription_service.dart';
import 'package:inventory_manager/core/services/auth_service.dart';
import 'package:inventory_manager/core/utils/currency_formatter.dart';
import '../../core/widgets/account_security_dialog.dart';
import 'checkout_flow.dart';
import 'plan_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum _PaymentMethod { telebirr, card }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey _plansSectionKey = GlobalKey();
  final Map<SubscriptionPlan, _PlanCustomization> _customizations = {};
  SubscriptionPlan? _selectedPlan;
  BillingCycle _cycle = BillingCycle.monthly;
  final _PaymentMethod _paymentMethod = _PaymentMethod.telebirr;

  late final AnimationController _sheetController;

  SubscriptionService get _subscriptionService =>
      Provider.of<SubscriptionService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    // Drives the add-ons sheet, so it glides up with the same easing as the
    // rest of the billing flow instead of the default linear slide.
    _sheetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shopId = context.read<AuthService>().user?.shopId;
      if (shopId != null) {
        subscriptionService.initialize(shopId).catchError((Object e) {
          debugPrint('[SUBSCRIPTION] init failed: $e');
        });
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final subscription = context.watch<SubscriptionService>().current;
    final pendingChange = context.watch<SubscriptionService>().pendingChange;
    final authUser = context.read<AuthService>().user;
    final activePlan = subscription?.plan;
    final selectedPlan = _selectedPlan ??
        (activePlan == null ||
                activePlan == SubscriptionPlan.trial ||
                activePlan == SubscriptionPlan.free ||
                activePlan == SubscriptionPlan.none
            ? SubscriptionPlan.business
            : activePlan);
    final isDesktop = MediaQuery.sizeOf(context).width > 1100;

    return Scaffold(
      backgroundColor: c.page,
      // No app bar: the controls sit directly on the page background.
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1280),
                padding: EdgeInsets.fromLTRB(
                    isDesktop ? 24 : 8, 8, isDesktop ? 24 : 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: "Back",
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: c.navy,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showBillingHelp(),
                      style: TextButton.styleFrom(
                        foregroundColor: c.navy,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 12),
                      ),
                      icon: Icon(Icons.help_outline_rounded,
                          size: 18, color: c.accent),
                      label: isDesktop
                          ? const Text(
                              "Need Help?",
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 8),
                    _ProfileBubble(
                      label:
                          authUser?.username ?? authUser?.fullName ?? "GM",
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => const AccountSecurityDialog(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 32 : 18,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                if (pendingChange != null) ...[
                  _PendingChangeBanner(
                    pending: pendingChange,
                    onCancel: () async {
                      await _subscriptionService
                          .cancelPendingChange(authUser?.shopId ?? '');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  "Scheduled plan change cancelled. Your current plan continues.")),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (_isPaidActive(subscription))
                  _SubscriptionActionBar(
                    subscription: subscription!,
                    onUpgrade: () => _handleUpgradePressed(activePlan),
                    onDowngrade: () => _handleDowngradePressed(activePlan),
                    onCancel: _confirmCancelSubscription,
                  )
                      .animate()
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOut)
                else
                  _TrialModeBanner(subscription: subscription)
                      .animate()
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.04, curve: Curves.easeOut),
                const SizedBox(height: 14),
                _SectionHeading(
                  eyebrow: "PLANS",
                  title: "Pick your plan",
                  subtitle:
                      "Start with the plan that fits your shop. Add-ons are optional and come next.",
                )
                    .animate()
                    .fadeIn(duration: 320.ms, delay: 60.ms)
                    .slideY(begin: 0.03, curve: Curves.easeOut),
                const SizedBox(height: 18),
                _BillingCycleToggle(
                  cycle: _cycle,
                  onChanged: (value) => setState(() => _cycle = value),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: _plansSectionKey,
                  child: _PlanGrid(
                    selectedPlan: selectedPlan,
                    currentPlan: subscription?.plan,
                    cycle: _cycle,
                    onSelectPlan: (plan) => setState(() => _selectedPlan = plan),
                    onContinue: _openAddOns,
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "You can change or cancel your subscription anytime.",
                    style: TextStyle(
                        color: c.muted.withOpacity(0.95), fontSize: 13),
                  ),
                ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBillingHelp() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Plans & billing help"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("• Yearly plans save 15% and are billed once for 12 months.",
                style: TextStyle(height: 1.5)),
            Text("• Add-ons are billed monthly or ×12 on yearly plans.",
                style: TextStyle(height: 1.5)),
            Text("• Upgrades apply immediately at the full new plan price.",
                style: TextStyle(height: 1.5)),
            Text("• Downgrades also apply immediately, at no extra charge.",
                style: TextStyle(height: 1.5)),
            Text("• Cancelling keeps your data and returns you to a trial.",
                style: TextStyle(height: 1.5)),
            SizedBox(height: 10),
            Text("Change a plan from this screen at any time.",
                style: TextStyle(height: 1.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  _PlanCustomization _customizationFor(SubscriptionPlan plan) {
    return _customizations.putIfAbsent(plan, _PlanCustomization.new);
  }

  List<SubscriptionAddOn> _buildSelectedAddOns(
      _PlanCustomization customization) {
    return customization.selections();
  }

  void _handleUpgradePressed(SubscriptionPlan? currentPlan) {
    final nextPlan = _nextHigherPlan(currentPlan);
    if (nextPlan == null) return;
    setState(() => _selectedPlan = nextPlan);
    _scrollToPlans();
  }

  void _scrollToPlans() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _plansSectionKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            alignment: 0.05);
      }
    });
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

  /// True only for a live paid plan; trials, expired plans and empty shops
  /// get the trial strip instead of the change actions.
  bool _isPaidActive(ActiveSubscription? subscription) {
    if (subscription == null) return false;
    if (subscription.isTrial || subscription.isExpired) return false;
    return subscription.plan == SubscriptionPlan.starter ||
        subscription.plan == SubscriptionPlan.business ||
        subscription.plan == SubscriptionPlan.enterprise;
  }

  /// Step 2: the optional add-ons sheet. It pops up from the bottom, and
  /// finishing it (with or without extras) goes straight to payment.
  Future<void> _openAddOns(SubscriptionPlan plan) async {
    final customization = _customizationFor(plan);
    setState(() => _selectedPlan = plan);

    final result = await showModalBottomSheet<_PlanCustomization>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.42),
      transitionAnimationController: _sheetController,
      builder: (sheetContext) => _AddOnsSheet(
        plan: plan,
        cycle: _cycle,
        customization: customization,
        onContinue: () => Navigator.pop(sheetContext, customization),
        onDismiss: () => Navigator.pop(sheetContext),
      ),
    );

    if (result == null || !mounted) return;
    await _handleCheckout(plan, result);
  }

  Future<void> _handleCheckout(
      SubscriptionPlan plan, _PlanCustomization customization) async {
    final user = context.read<AuthService>().user;
    if (user == null) return;

    final addOns = _buildSelectedAddOns(customization);
    final total = customization.termTotal(plan, _cycle);
    final quote = _subscriptionService.quoteChange(plan: plan, addOns: addOns);

    if (quote.kind == PlanChangeKind.downgrade) {
      await _applyDowngradeNow(plan, addOns, quote, user.shopId);
      return;
    }

    final note = _cycle.isYearly
        ? "Annual plan: one payment covers 12 months and saves 15% on the plan price. Add-ons are charged at their monthly rate × 12."
        : switch (quote.kind) {
            PlanChangeKind.upgrade =>
              "Upgrade applies immediately. You pay the full new plan price "
                  "today — never a prorated slice — and your renewal date "
                  "stays the same.",
            PlanChangeKind.newSubscription => "First month is billed today.",
            PlanChangeKind.lateral =>
              "Your plan is updated immediately. No extra charge for the rest "
                  "of this period.",
            PlanChangeKind.downgrade => null,
          };

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckoutFlow(
        plan: plan,
        addOns: addOns,
        total: total,
        billingCycle: _cycle,
        amountDueToday: _cycle.isYearly ? total : quote.amountDueToday,
        changeNote: note,
        initialCardMethod: _paymentMethod == _PaymentMethod.card,
        onPay: () async {
          await _subscriptionService.changePlan(
            shopId: user.shopId,
            plan: plan,
            addOns: addOns,
            cycle: _cycle,
          );
        },
      ),
    );

    if (paid == true && mounted) {
      _showSuccessDialog(plan, total);
    }
  }

  /// Downgrades are not scheduled any more: the shop moves to the smaller plan
  /// immediately and nothing extra is charged today.
  Future<void> _applyDowngradeNow(SubscriptionPlan plan,
      List<SubscriptionAddOn> addOns, PlanChangeQuote quote, String shopId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Switch to ${plan.name} now?"),
        content: Text(
          "Your plan changes immediately — no waiting for the renewal date, and "
          "nothing extra is charged today. From now on the shop has "
          "${quote.userLimit} user${quote.userLimit == 1 ? '' : 's'} and "
          "${quote.branchLimit} branch${quote.branchLimit == 1 ? '' : 'es'}. "
          "Your billing date stays the same.",
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Keep current plan"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Switch now",
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(dialogContext).colorScheme.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _subscriptionService
          .changePlan(shopId: shopId, plan: plan, addOns: addOns);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You're now on ${plan.name}.")),
      );
    } on PlanChangeException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text("Can't change plan yet"),
          content: Text(e.message, style: const TextStyle(height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("OK"),
            ),
          ],
        ),
      );
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
    if (!mounted) return;
    final shopId = context.read<AuthService>().user?.shopId;
    if (shopId != null) {
      await _subscriptionService.cancelPendingChange(shopId);
      await _subscriptionService.cancelSubscription(shopId);
    } else {
      _subscriptionService.clear();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Subscription cancelled.")),
    );
  }

  void _showSuccessDialog(SubscriptionPlan plan, double total) {
    final c = PlanColors.of(context);
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
              )
                  .animate()
                  .scale(
                      begin: const Offset(0.4, 0.4),
                      curve: Curves.elasticOut,
                      duration: 550.ms),
              const SizedBox(height: 24),
              Text(
                "Subscription Active",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: c.navy),
              ),
              const SizedBox(height: 12),
              Text(
                "Your ${plan.name} workspace is fully active at ${CurrencyFormatter.simple(total, 'USD')} per ${_cycle.perLabel}.",
                textAlign: TextAlign.center,
                style: TextStyle(color: c.muted, height: 1.5),
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
                    backgroundColor: c.button,
                    foregroundColor: c.onButton,
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

// ─────────────────────────────────────────────────────────────────────────────
// Billing-cycle switch
// ─────────────────────────────────────────────────────────────────────────────

class _BillingCycleToggle extends StatelessWidget {
  const _BillingCycleToggle({required this.cycle, required this.onChanged});

  final BillingCycle cycle;
  final ValueChanged<BillingCycle> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final yearly = cycle.isYearly;

    return Column(
      children: [
        Center(
          child: LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth.clamp(0.0, 340.0);
            return SizedBox(
              width: width,
              child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: c.subtle,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: c.border),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment:
                      yearly ? Alignment.centerRight : Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _cycleOption(
                        context,
                        c,
                        label: "Monthly",
                        selected: !yearly,
                        onTap: () => onChanged(BillingCycle.monthly),
                      ),
                    ),
                    Expanded(
                      child: _cycleOption(
                        context,
                        c,
                        label: "Yearly",
                        selected: yearly,
                        badge: "−15%",
                        onTap: () => onChanged(BillingCycle.yearly),
                      ),
                    ),
                  ],
                ),
              ],
            ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: yearly
              ? Row(
                  key: const ValueKey('yearly-note'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: c.accent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "Annual billing saves 15% on every plan — add-ons stay the same.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.accent),
                      ),
                    ),
                  ],
                )
              : Text(
                  key: const ValueKey('monthly-note'),
                  "Switch to yearly and pay for 10.2 months instead of 12.",
                  style: TextStyle(fontSize: 12.5, color: c.muted),
                ),
        ),
      ],
    );
  }

  Widget _cycleOption(
    BuildContext context,
    PlanColors c, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? c.navy : c.muted,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? c.accent.withOpacity(0.12)
                      : const Color(0xFF16A34A).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? c.accent : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plans
// ─────────────────────────────────────────────────────────────────────────────

class _PlanGrid extends StatelessWidget {
  const _PlanGrid({
    required this.selectedPlan,
    required this.currentPlan,
    required this.cycle,
    required this.onSelectPlan,
    required this.onContinue,
  });

  final SubscriptionPlan selectedPlan;
  final SubscriptionPlan? currentPlan;
  final BillingCycle cycle;
  final ValueChanged<SubscriptionPlan> onSelectPlan;
  final ValueChanged<SubscriptionPlan> onContinue;

  @override
  Widget build(BuildContext context) {
    const plans = [
      SubscriptionPlan.starter,
      SubscriptionPlan.business,
      SubscriptionPlan.enterprise,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1000;
        final cards = plans.map((plan) {
          return _PlanCard(
            plan: plan,
            cycle: cycle,
            isSelected: selectedPlan == plan,
            isCurrent: currentPlan == plan,
            onSelect: () => onSelectPlan(plan),
            onContinue: () => onContinue(plan),
          );
        }).toList();

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i < cards.length - 1) const SizedBox(width: 18),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (final card in cards) ...[
              card,
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.plan,
    required this.cycle,
    required this.isSelected,
    required this.isCurrent,
    required this.onSelect,
    required this.onContinue,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onSelect;
  final VoidCallback onContinue;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovering = false;
  bool _showAllFeatures = false;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final spec = _specFor(widget.plan);
    final yearly = widget.cycle.isYearly;
    final price = planPriceFor(widget.plan, widget.cycle);
    final monthlyEquivalent = annualMonthlyEquivalentFor(widget.plan);
    final savings = annualSavingsFor(widget.plan);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(
              0, (_hovering || widget.isSelected) ? -4 : 0, 0),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: widget.isSelected ? c.accent : c.border,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (_hovering || widget.isSelected)
                BoxShadow(
                  color: widget.isSelected
                      ? c.accent.withOpacity(0.12)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.plan == SubscriptionPlan.business)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_fire_department_rounded,
                            size: 14, color: c.onAccent),
                        const SizedBox(width: 6),
                        Text(
                          "MOST POPULAR",
                          style: TextStyle(
                              color: c.onAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2),
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c.accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(spec.icon, color: c.accent, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.plan.name,
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: c.navy),
                                ),
                                Text(
                                  spec.tagline,
                                  style: TextStyle(
                                      fontSize: 11.5, color: c.muted),
                                ),
                              ],
                            ),
                          ),
                          if (widget.isCurrent)
                            const _StatusPill(
                                label: "Current", color: Color(0xFF16A34A)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.15),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                          key: ValueKey(
                              '${widget.plan.name}-${widget.cycle.name}'),
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.simple(price, 'USD'),
                              style: TextStyle(
                                  fontSize: 38,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                  color: c.navy),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                " / ${widget.cycle.perLabel}",
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: c.muted),
                              ),
                            ),
                          ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 20,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: yearly
                              ? Wrap(
                                  key: const ValueKey('year-price'),
                                  spacing: 8,
                                  runSpacing: 3,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      "≈ ${CurrencyFormatter.simple(monthlyEquivalent, 'USD')}/mo",
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: c.accent),
                                    ),
                                    Text(
                                      CurrencyFormatter.simple(
                                              widget.plan.price, 'USD') +
                                          "/mo",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: c.muted,
                                        decoration:
                                            TextDecoration.lineThrough,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF16A34A)
                                            .withOpacity(0.10),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        "Save ${CurrencyFormatter.simple(savings, 'USD')}",
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF15803D)),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  key: const ValueKey('month-price'),
                                  "Billed monthly · cancel anytime",
                                  style: TextStyle(
                                      fontSize: 12.5, color: c.muted),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: c.border),
                      const SizedBox(height: 16),
                      ...spec.highlights.map((highlight) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: c.accent.withOpacity(0.09),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(highlight.icon,
                                      size: 12, color: c.accent),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    highlight.label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: c.heading,
                                        height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      InkWell(
                        onTap: () => setState(
                            () => _showAllFeatures = !_showAllFeatures),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _showAllFeatures
                                      ? "Hide full feature list"
                                      : "See everything included",
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: c.accent),
                                ),
                              ),
                              AnimatedRotation(
                                turns: _showAllFeatures ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 18, color: c.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _showAllFeatures
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: spec.everything
                                    .map((feature) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: c.muted,
                                              ),
                                              const SizedBox(width: 7),
                                              Expanded(
                                                child: Text(
                                                  feature,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: c.muted,
                                                      height: 1.4),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                widget.isSelected ? c.accent : c.button,
                            foregroundColor: widget.isSelected
                                ? c.onAccent
                                : c.onButton,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.isCurrent
                                      ? "Manage add-ons"
                                      : "Continue with ${widget.plan.name}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded,
                                    size: 17),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Slim strip shown while the workspace is on a trial: Enterprise features are
/// open, only seats and branches are capped. Deliberately not a card, so the
/// plans sit right below it.
class _TrialModeBanner extends StatelessWidget {
  const _TrialModeBanner({required this.subscription});

  final ActiveSubscription? subscription;

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final isTrial = sub != null && sub.isTrial && !sub.isExpired;
    final endsOn = isTrial
        ? MaterialLocalizations.of(context).formatMediumDate(sub.expiryDate)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 13, color: Color(0xFFD97706)),
          const SizedBox(width: 6),
          const Text(
            "TRIAL MODE",
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: Color(0xFFD97706)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              endsOn == null
                  ? "Enterprise features · 3 users · 1 branch"
                  : "Ends $endsOn · Enterprise features · 3 users · 1 branch",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact bar with the three subscription actions. Only shown once a paid
/// plan is active.
class _SubscriptionActionBar extends StatelessWidget {
  const _SubscriptionActionBar({
    required this.subscription,
    required this.onUpgrade,
    required this.onDowngrade,
    required this.onCancel,
  });

  final ActiveSubscription subscription;
  final VoidCallback onUpgrade;
  final VoidCallback onDowngrade;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final canUpgrade = subscription.plan != SubscriptionPlan.enterprise;
    final renews = MaterialLocalizations.of(context)
        .formatMediumDate(subscription.expiryDate);
    final compact = MediaQuery.sizeOf(context).width < 760;

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionChipButton(
          label: "Upgrade",
          icon: Icons.arrow_upward_rounded,
          filled: true,
          onPressed: canUpgrade ? onUpgrade : null,
        ),
        _ActionChipButton(
          label: "Downgrade",
          icon: Icons.arrow_downward_rounded,
          onPressed: onDowngrade,
        ),
        _ActionChipButton(
          label: "Cancel",
          icon: Icons.close_rounded,
          danger: true,
          onPressed: () => onCancel(),
        ),
      ],
    );

    final info = Row(
      children: [
        const _StatusPill(label: "Active", color: Color(0xFF16A34A)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "${subscription.plan.name} · renews $renews",
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: c.navy),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                info,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            )
          : Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 16),
                actions,
              ],
            ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final fg = danger
        ? const Color(0xFFDC2626)
        : (filled ? c.onAccent : c.accent);
    final radius = BorderRadius.circular(11);
    final style = TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5);

    return SizedBox(
      height: 40,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label, style: style),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: fg,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 16),
              label: Text(label, style: style),
              style: OutlinedButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                side: BorderSide(
                    color: danger
                        ? const Color(0xFFFCA5A5)
                        : c.border),
                shape: RoundedRectangleBorder(borderRadius: radius),
              ),
            ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Add-ons step
// ─────────────────────────────────────────────────────────────────────────────

class _AddOnsSheet extends StatefulWidget {
  const _AddOnsSheet({
    required this.plan,
    required this.cycle,
    required this.customization,
    required this.onContinue,
    required this.onDismiss,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final _PlanCustomization customization;
  final VoidCallback onContinue;
  final VoidCallback onDismiss;

  @override
  State<_AddOnsSheet> createState() => _AddOnsSheetState();
}

class _AddOnsSheetState extends State<_AddOnsSheet> {
  _PlanCustomization get _customization => widget.customization;

  void _update(VoidCallback change) => setState(change);

  void _skip() {
    setState(_customization.clear);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final plan = widget.plan;
    final cycle = widget.cycle;
    final addOns = _availableAddOnsFor(plan);
    final featureAddOns = addOns
        .where((a) =>
            a != SubscriptionAddOn.extraUser &&
            a != SubscriptionAddOn.extraBranch)
        .toList();
    final includedUsers = userLimitFor(plan, const []);
    final includedBranches = branchLimitFor(plan, const []);
    final anySelected = _customization.selections().isNotEmpty;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.sizeOf(context).height * 0.94,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: c.page,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.16),
                blurRadius: 40,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: c.accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                "STEP 2 OF 2 · OPTIONAL",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                    color: c.accent),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: widget.onDismiss,
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: c.muted,
                              tooltip: "Close",
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Make ${plan.name} yours",
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: c.navy),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Add only what your shop needs — everything here is "
                          "optional. Only extras your plan does not already "
                          "include are shown.",
                          style: TextStyle(
                              fontSize: 13, height: 1.5, color: c.muted),
                        ),
                        const SizedBox(height: 18),
                        _AddOnSectionLabel(
                          title: "Team & locations",
                          subtitle:
                              "$includedUsers users · $includedBranches "
                              "branch${includedBranches == 1 ? '' : 'es'} included",
                        ),
                        const SizedBox(height: 10),
                        _QuantityAddonRow(
                          icon: Icons.groups_2_rounded,
                          title: "Extra users",
                          description:
                              "Add more staff accounts with their own permissions.",
                          unitPriceLabel: CurrencyFormatter.simple(
                              addOnPriceFor(
                                  plan, SubscriptionAddOn.extraUser, cycle),
                              'USD'),
                          priceSuffix: cycle.perLabel,
                          quantity: _customization.extraUsers,
                          onDecrease: () => _update(() =>
                              _customization.extraUsers =
                                  (_customization.extraUsers - 1)
                                      .clamp(0, 99)
                                      .toInt()),
                          onIncrease: () => _update(() =>
                              _customization.extraUsers =
                                  (_customization.extraUsers + 1)
                                      .clamp(0, 99)
                                      .toInt()),
                          selected: _customization.extraUsers > 0,
                        ),
                        _QuantityAddonRow(
                          icon: Icons.store_mall_directory_rounded,
                          title: "Extra branches",
                          description:
                              "Run another location on the same workspace.",
                          unitPriceLabel: CurrencyFormatter.simple(
                              addOnPriceFor(
                                  plan, SubscriptionAddOn.extraBranch, cycle),
                              'USD'),
                          priceSuffix: cycle.perLabel,
                          quantity: _customization.extraBranches,
                          onDecrease: () => _update(() =>
                              _customization.extraBranches =
                                  (_customization.extraBranches - 1)
                                      .clamp(0, 99)
                                      .toInt()),
                          onIncrease: () => _update(() =>
                              _customization.extraBranches =
                                  (_customization.extraBranches + 1)
                                      .clamp(0, 99)
                                      .toInt()),
                          selected: _customization.extraBranches > 0,
                        ),
                        if (featureAddOns.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _AddOnSectionLabel(
                              title: "Power-ups",
                              subtitle:
                                  "Switch on only what your shop needs"),
                          const SizedBox(height: 10),
                          ...featureAddOns.map((addOn) => _FeatureAddOnTile(
                                addOn: addOn,
                                plan: plan,
                                cycle: cycle,
                                selected: _customization.isSelected(addOn),
                                onChanged: (value) => _update(
                                    () => _customization.toggle(addOn, value)),
                              )),
                        ],
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.subtle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  size: 15, color: c.muted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cycle.isYearly
                                      ? "Add-ons are charged for 12 months at their monthly rate — the 15% discount applies to the plan only."
                                      : "Add-ons renew monthly and can be removed anytime.",
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.muted,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SheetSummary(
                          plan: plan,
                          cycle: cycle,
                          customization: _customization,
                        ),
                      ],
                    ),
                  ),
                ),
                _SheetFooter(
                  plan: plan,
                  cycle: cycle,
                  total: _customization.termTotal(plan, cycle),
                  skipLabel: anySelected ? "Clear add-ons" : "Skip add-ons",
                  onContinue: widget.onContinue,
                  onSkip: _skip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetSummary extends StatelessWidget {
  const _SheetSummary({
    required this.plan,
    required this.cycle,
    required this.customization,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final _PlanCustomization customization;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final yearly = cycle.isYearly;
    final planPrice = planPriceFor(plan, cycle);
    final total = customization.termTotal(plan, cycle);
    final counts = <SubscriptionAddOn, int>{};
    for (final addOn in customization.selections()) {
      counts[addOn] = (counts[addOn] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_rounded, size: 17, color: c.accent),
              const SizedBox(width: 8),
              Text(
                "Your order",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.navy),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.subtle,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  cycle.label,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: c.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SummaryLine(
            label: "${plan.name} plan",
            amount: CurrencyFormatter.simple(planPrice, 'USD'),
          ),
          if (yearly)
            _SummaryLine(
              label: "Annual discount (15%)",
              amount: "− ${CurrencyFormatter.simple(annualSavingsFor(plan), 'USD')}",
              amountColor: const Color(0xFF16A34A),
            ),
          for (final entry in counts.entries)
            _SummaryLine(
              label: entry.value > 1
                  ? "${entry.key.name} × ${entry.value}"
                  : entry.key.name,
              amount: CurrencyFormatter.simple(
                  addOnPriceFor(plan, entry.key, cycle) * entry.value, 'USD'),
            ),
          Divider(height: 24, color: c.border),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  "Due today",
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: c.heading),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: total, end: total),
                duration: const Duration(milliseconds: 320),
                builder: (context, value, _) => Text(
                  CurrencyFormatter.simple(value, 'USD'),
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: c.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            yearly
                ? "One payment covers 12 months. Renews yearly."
                : "Billed monthly. Cancel anytime.",
            style: TextStyle(fontSize: 11.5, color: c.muted),
          ),
        ],
      ),
    );
  }
}

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.plan,
    required this.cycle,
    required this.total,
    required this.skipLabel,
    required this.onContinue,
    required this.onSkip,
  });

  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final double total;
  final String skipLabel;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.muted),
                ),
              ),
              Text(
                "${CurrencyFormatter.simple(total, 'USD')} / ${cycle.perLabel}",
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: c.navy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: c.muted,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: c.border),
                  ),
                ),
                child: Text(skipLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                    label: const Text("Continue to payment",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.button,
                      foregroundColor: c.onButton,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class _AddOnSectionLabel extends StatelessWidget {
  const _AddOnSectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: c.navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, color: c.muted),
          ),
        ),
      ],
    );
  }
}

class _FeatureAddOnTile extends StatelessWidget {
  const _FeatureAddOnTile({
    required this.addOn,
    required this.plan,
    required this.cycle,
    required this.selected,
    required this.onChanged,
  });

  final SubscriptionAddOn addOn;
  final SubscriptionPlan plan;
  final BillingCycle cycle;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final price =
        CurrencyFormatter.simple(addOnPriceFor(plan, addOn, cycle), 'USD');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? c.accent.withOpacity(0.06) : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? c.accent : c.border,
                width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? c.accent.withOpacity(0.14)
                      : c.subtle,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_addOnIcon(addOn),
                    color: selected ? c.accent : c.muted, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addOn.name,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: c.heading),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _addOnDescription(addOn),
                      style: TextStyle(
                          fontSize: 12, color: c.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "+$price/${cycle.perLabel}",
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: c.navy),
                  ),
                  const SizedBox(height: 4),
                  Switch.adaptive(
                    value: selected,
                    onChanged: onChanged,
                    activeColor: c.accent,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityAddonRow extends StatelessWidget {
  const _QuantityAddonRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.unitPriceLabel,
    required this.priceSuffix,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.selected,
  });

  final IconData icon;
  final String title;
  final String description;
  final String unitPriceLabel;
  final String priceSuffix;
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: selected ? c.accent.withOpacity(0.06) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? c.accent : c.border,
              width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? c.accent.withOpacity(0.14) : c.subtle,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon,
                  color: selected ? c.accent : c.muted, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: c.heading)),
                  const SizedBox(height: 3),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: c.muted, height: 1.35)),
                  const SizedBox(height: 5),
                  Text("$unitPriceLabel / $priceSuffix each",
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: c.accent)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: c.subtle,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: quantity > 0 ? onDecrease : null,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                  ),
                  SizedBox(
                    width: 22,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      transitionBuilder: (child, animation) => ScaleTransition(
                          scale: animation, child: child),
                      child: Text(
                        "$quantity",
                        key: ValueKey(quantity),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: c.navy),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onIncrease,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order summary
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.amount,
    this.amountColor,
  });

  final String label;
  final String amount;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: c.muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  height: 1.35),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(
                color: amountColor ?? c.navy,
                fontWeight: FontWeight.w600,
                fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Current subscription
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Plan content
// ─────────────────────────────────────────────────────────────────────────────

class _PlanHighlight {
  const _PlanHighlight(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _PlanSpec {
  const _PlanSpec({
    required this.tagline,
    required this.icon,
    required this.highlights,
    required this.everything,
  });

  final String tagline;
  final IconData icon;
  final List<_PlanHighlight> highlights;
  final List<String> everything;
}

_PlanSpec _specFor(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.starter:
      return const _PlanSpec(
        tagline: "For a single shop getting organised",
        icon: Icons.rocket_launch_rounded,
        highlights: [
          _PlanHighlight(Icons.groups_rounded, "3 staff accounts"),
          _PlanHighlight(Icons.storefront_rounded, "1 branch included"),
          _PlanHighlight(Icons.point_of_sale_rounded, "POS, inventory & sales"),
          _PlanHighlight(
              Icons.description_rounded, "Basic reports & profit tracking"),
          _PlanHighlight(Icons.wifi_off_rounded, "Offline sync"),
        ],
        everything: [
          "Bulk product import and barcode scanning",
          "Basic reports and profit tracking",
          "Debt management and low-stock alerts",
          "Multi-device sync and shop settings",
          "Custom roles for up to 3 users",
        ],
      );
    case SubscriptionPlan.business:
      return const _PlanSpec(
        tagline: "For growing shops with more than one location",
        icon: Icons.trending_up_rounded,
        highlights: [
          _PlanHighlight(Icons.groups_rounded, "10 staff accounts"),
          _PlanHighlight(Icons.storefront_rounded, "5 branches included"),
          _PlanHighlight(Icons.layers_rounded, "FEFO, batch & expiry tracking"),
          _PlanHighlight(Icons.insights_rounded, "Basic reports & analytics"),
          _PlanHighlight(Icons.admin_panel_settings_rounded,
              "Custom roles & permissions"),
        ],
        everything: [
          "Everything in Starter",
          "Purchase tracking and supplier records",
          "Multi-branch stock and transfers",
          "Basic reports and the analytics dashboard",
          "Audit history included",
        ],
      );
    case SubscriptionPlan.enterprise:
      return const _PlanSpec(
        tagline: "For multi-branch operations that need control",
        icon: Icons.domain_rounded,
        highlights: [
          _PlanHighlight(Icons.groups_rounded, "15 staff accounts"),
          _PlanHighlight(Icons.storefront_rounded, "10 branches included"),
          _PlanHighlight(Icons.space_dashboard_rounded, "Central dashboard"),
          _PlanHighlight(Icons.analytics_rounded, "Branch-level analytics"),
          _PlanHighlight(
              Icons.verified_user_rounded, "Audit history for every branch"),
        ],
        everything: [
          "Everything in Business",
          "Audit history across every branch",
          "Branch performance comparisons",
          "Dedicated onboarding support",
        ],
      );
    default:
      return const _PlanSpec(
        tagline: "",
        icon: Icons.workspace_premium_rounded,
        highlights: [],
        everything: [],
      );
  }
}

List<SubscriptionAddOn> _availableAddOnsFor(SubscriptionPlan plan) {
  final addOns = <SubscriptionAddOn>[
    SubscriptionAddOn.extraUser,
    SubscriptionAddOn.extraBranch,
  ];
  void addIfMissing(SubscriptionAddOn addOn, Feature feature) {
    if (!_planIncludesFeature(plan, feature)) addOns.add(addOn);
  }

  addIfMissing(SubscriptionAddOn.fefoBatchTracking, Feature.fefoTracking);
  addIfMissing(SubscriptionAddOn.expiryTracking, Feature.expiryTracking);
  addIfMissing(SubscriptionAddOn.advancedReports, Feature.advancedReports);
  addIfMissing(SubscriptionAddOn.auditLogs, Feature.auditLogs);
  return addOns.where((addOn) => addOn.getPrice(plan) > 0).toList();
}

bool _planIncludesFeature(SubscriptionPlan plan, Feature feature) {
  final now = DateTime.now();
  return ActiveSubscription(
    shopId: 'plan-preview',
    plan: plan,
    activationDate: now,
    expiryDate: now.add(const Duration(days: 1)),
    addOns: const [],
    isTrial: false,
    userLimit: 0,
    branchLimit: 0,
  ).hasFeature(feature);
}

String _addOnDescription(SubscriptionAddOn addOn) {
  switch (addOn) {
    case SubscriptionAddOn.fefoBatchTracking:
      return "Sell first-expired-first-out with batch tracking.";
    case SubscriptionAddOn.expiryTracking:
      return "Track expiry dates and get expiry alerts.";
    case SubscriptionAddOn.advancedReports:
      return "Deeper sales, profit and stock reporting.";
    case SubscriptionAddOn.analyticsDashboard:
      return "Interactive analytics dashboard.";
    case SubscriptionAddOn.auditLogs:
      return "Keep a full history of sensitive actions.";
    case SubscriptionAddOn.auditLogsPack:
      return "Extended audit logs and security tracking.";
    case SubscriptionAddOn.prioritySupport:
      return "Priority help when you need it.";
    default:
      return "";
  }
}

IconData _addOnIcon(SubscriptionAddOn addOn) {
  switch (addOn) {
    case SubscriptionAddOn.fefoBatchTracking:
      return Icons.layers_rounded;
    case SubscriptionAddOn.expiryTracking:
      return Icons.event_busy_rounded;
    case SubscriptionAddOn.advancedReports:
    case SubscriptionAddOn.analyticsDashboard:
      return Icons.insights_rounded;
    case SubscriptionAddOn.auditLogs:
    case SubscriptionAddOn.auditLogsPack:
      return Icons.verified_user_rounded;
    default:
      return Icons.add_circle_outline_rounded;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    return Column(
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: c.accent),
          ),
          const SizedBox(height: 7),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, color: c.navy),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.muted, height: 1.5),
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
    final c = PlanColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.subtle,
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
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: c.navy,
                    fontSize: 13)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: c.muted),
          ],
        ),
      ),
    );
  }
}

class _PlanCustomization {
  int extraUsers = 0;
  int extraBranches = 0;
  bool fefoBatchTracking = false;
  bool expiryTracking = false;
  bool advancedReports = false;
  bool auditLogs = false;

  bool isSelected(SubscriptionAddOn addOn) {
    switch (addOn) {
      case SubscriptionAddOn.fefoBatchTracking:
        return fefoBatchTracking;
      case SubscriptionAddOn.expiryTracking:
        return expiryTracking;
      case SubscriptionAddOn.advancedReports:
        return advancedReports;
      case SubscriptionAddOn.auditLogs:
        return auditLogs;
      default:
        return false;
    }
  }

  void toggle(SubscriptionAddOn addOn, bool value) {
    switch (addOn) {
      case SubscriptionAddOn.fefoBatchTracking:
        fefoBatchTracking = value;
        break;
      case SubscriptionAddOn.expiryTracking:
        expiryTracking = value;
        break;
      case SubscriptionAddOn.advancedReports:
        advancedReports = value;
        break;
      case SubscriptionAddOn.auditLogs:
        auditLogs = value;
        break;
      default:
        break;
    }
  }

  void clear() {
    extraUsers = 0;
    extraBranches = 0;
    fefoBatchTracking = false;
    expiryTracking = false;
    advancedReports = false;
    auditLogs = false;
  }

  List<SubscriptionAddOn> selections() {
    return [
      ...List<SubscriptionAddOn>.filled(extraUsers, SubscriptionAddOn.extraUser),
      ...List<SubscriptionAddOn>.filled(
          extraBranches, SubscriptionAddOn.extraBranch),
      if (fefoBatchTracking) SubscriptionAddOn.fefoBatchTracking,
      if (expiryTracking) SubscriptionAddOn.expiryTracking,
      if (advancedReports) SubscriptionAddOn.advancedReports,
      if (auditLogs) SubscriptionAddOn.auditLogs,
    ];
  }

  double termTotal(SubscriptionPlan plan, BillingCycle cycle) {
    return termPriceFor(plan, selections(), cycle);
  }
}

class _PendingChangeBanner extends StatelessWidget {
  const _PendingChangeBanner({required this.pending, required this.onCancel});

  final PendingPlanChange pending;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final date =
        '${pending.effectiveDate.day}/${pending.effectiveDate.month}/${pending.effectiveDate.year}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: c.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Scheduled change to ${pending.plan.name}",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: c.heading),
                ),
                const SizedBox(height: 3),
                Text(
                  "Takes effect on $date. Current features stay active until then.",
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text("Cancel",
                style: TextStyle(fontWeight: FontWeight.w700, color: c.accent)),
          ),
        ],
      ),
    );
  }
}
