import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/core/services/subscription_service.dart';
import 'package:inventory_manager/core/services/auth_service.dart';
import 'package:inventory_manager/core/widgets/loading_overlay.dart';
import 'package:inventory_manager/core/utils/currency_formatter.dart';
import 'package:flutter_animate/flutter_animate.dart';

const Color _navyPrimary = Color(0xFF0F172A);
const Color _accentBlue = Color(0xFF2563EB);
const Color _borderGray = Color(0xFFE2E8F0);
const Color _bgWhite = Color(0xFFFFFFFF);
const Color _textDark = Color(0xFF1E293B);
const Color _textLight = Color(0xFF64748B);

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionService get _subService => Provider.of<SubscriptionService>(context, listen: false);

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.sizeOf(context).width > 1100;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Plans & Billing", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        elevation: 0,
        backgroundColor: _bgWhite,
        foregroundColor: _navyPrimary,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _borderGray, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1200),
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 40 : 24,
              vertical: 64,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Simple, transparent pricing",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: _navyPrimary,
                    letterSpacing: -1.2,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, curve: Curves.easeOut),
                const SizedBox(height: 16),
                const Text(
                  "Choose the plan that best fits your business needs.\nUpgrade or downgrade at any time.",
                  style: TextStyle(fontSize: 18, color: _textLight, height: 1.5),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 64),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildTierCards(context, isDesktop: true),
                  )
                else
                  Column(
                    children: _buildTierCards(context, isDesktop: false),
                  ),
                const SizedBox(height: 80),
                _buildEnterpriseBanner(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTierCards(BuildContext context, {required bool isDesktop}) {
    final plans = [SubscriptionPlan.starter, SubscriptionPlan.business, SubscriptionPlan.enterprise];
    return plans.asMap().entries.map((entry) {
      final index = entry.key;
      final plan = entry.value;
      final isPopular = plan == SubscriptionPlan.business;

      final card = _PricingCard(
        plan: plan,
        isPopular: isPopular,
        onCheckout: (plan, addOns) => _handlePayment(plan, addOns),
      ).animate().fadeIn(delay: (200 + (index * 100)).ms).slideY(begin: 0.1);

      if (isDesktop) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < plans.length - 1 ? 24 : 0,
              top: isPopular ? 0 : 24, // Pop out the popular card slightly
            ),
            child: card,
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: card,
        );
      }
    }).toList();
  }

  Widget _buildEnterpriseBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: _bgWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderGray),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Need a custom solution?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navyPrimary)),
                const SizedBox(height: 8),
                const Text("Contact our sales team for custom limits, dedicated support, and bespoke integrations.", style: TextStyle(color: _textLight)),
              ],
            ),
          ),
          const SizedBox(width: 24),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: _navyPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: const BorderSide(color: _borderGray),
            ),
            child: const Text("Contact Sales", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  void _handlePayment(SubscriptionPlan plan, List<SubscriptionAddOn> addOns) async {
    final user = Provider.of<AuthService>(context, listen: false).user;
    if (user == null) return;

    double total = plan.price;
    for (var a in addOns) {
      total += a.getPrice(plan);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ChapaCheckoutSimulator(
        amount: total,
        email: user.email,
        onSuccess: () async {
          Navigator.pop(ctx);
          LoadingOverlay.show(context);
          await _subService.upgrade(
            shopId: user.shopId,
            plan: plan,
            addOns: addOns,
          );
          if (mounted) {
            LoadingOverlay.hide(context);
            _showSuccessDialog(plan);
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  void _showSuccessDialog(SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 48),
              ),
              const SizedBox(height: 24),
              const Text("Subscription Active", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navyPrimary)),
              const SizedBox(height: 12),
              Text(
                "Your ${plan.name} workspace is fully active. Selected features have been unlocked instantly.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textLight, height: 1.5),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navyPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("Go to Dashboard", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final bool isPopular;
  final void Function(SubscriptionPlan plan, List<SubscriptionAddOn> addOns) onCheckout;

  const _PricingCard({
    required this.plan,
    required this.isPopular,
    required this.onCheckout,
  });

  @override
  State<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<_PricingCard> {
  final Set<SubscriptionAddOn> _selectedAddOns = {};
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final availableAddOns = SubscriptionAddOn.values.where((a) => a.getPrice(widget.plan) > 0).toList();
    double total = widget.plan.price;
    for (var a in _selectedAddOns) {
      total += a.getPrice(widget.plan);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovering ? -8 : 0, 0),
        decoration: BoxDecoration(
          color: _bgWhite,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: widget.isPopular ? _accentBlue : (_isHovering ? _borderGray.withOpacity(0.8) : _borderGray),
            width: widget.isPopular ? 2 : 1,
          ),
          boxShadow: [
            if (_isHovering || widget.isPopular)
              BoxShadow(
                color: widget.isPopular ? _accentBlue.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isPopular)
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  color: _accentBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: const Text("MOST POPULAR", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.plan.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _navyPrimary)),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("\$", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _navyPrimary)),
                      Text(widget.plan.price.toStringAsFixed(0), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: _navyPrimary, height: 1)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 6, left: 4),
                        child: Text("/month", style: TextStyle(fontSize: 16, color: _textLight)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Checkout Button inside card
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => widget.onCheckout(widget.plan, _selectedAddOns.toList()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isPopular ? _navyPrimary : _bgWhite,
                        foregroundColor: widget.isPopular ? Colors.white : _navyPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: widget.isPopular ? BorderSide.none : const BorderSide(color: _borderGray),
                      ),
                      child: Text("Subscribe Output: \$${total.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text("WHAT'S INCLUDED", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textDark, letterSpacing: 1)),
                  const SizedBox(height: 16),
                  
                  ..._getFeatures(widget.plan).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle, color: _navyPrimary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 14, color: _textLight, height: 1.4))),
                      ],
                    ),
                  )),

                  if (availableAddOns.isNotEmpty) ...[
                    const Divider(height: 48, color: _borderGray),
                    const Text("OPTIONAL ADD-ONS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _textDark, letterSpacing: 1)),
                    const SizedBox(height: 16),
                    ...availableAddOns.map((addon) {
                      final isSelected = _selectedAddOns.contains(addon);
                      return InkWell(
                        onTap: () => setState(() => isSelected ? _selectedAddOns.remove(addon) : _selectedAddOns.add(addon)),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? _accentBlue : Colors.transparent),
                            color: isSelected ? _accentBlue.withOpacity(0.03) : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (v) => setState(() => v == true ? _selectedAddOns.add(addon) : _selectedAddOns.remove(addon)),
                                  activeColor: _accentBlue,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(addon.name, style: TextStyle(fontWeight: FontWeight.w600, color: isSelected ? _navyPrimary : _textDark, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text("+\$${addon.getPrice(widget.plan)}/mo", style: const TextStyle(fontSize: 12, color: _textLight)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getFeatures(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.starter:
        return [
          "Up to 3 Users",
          "1 Supported Branch",
          "Basic Inventory Tracking",
          "Core POS & Sales Billing"
        ];
      case SubscriptionPlan.business:
        return [
          "Up to 10 Users",
          "5 Supported Branches",
          "Full Audit Trail & Security Logs",
          "Supplier & Purchase Tracking",
          "Advanced Analytics & Exports",
          "Custom Staff Roles & Permissions"
        ];
      case SubscriptionPlan.enterprise:
        return [
          "Up to 100 Users",
          "70 Supported Branches",
          "API Access & Webhooks",
          "SAML/SSO Authentication",
          "Dedicated Success Manager",
          "99.99% Uptime SLA"
        ];
      default: return [];
    }
  }
}

class _ChapaCheckoutSimulator extends StatelessWidget {
  final double amount;
  final String email;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const _ChapaCheckoutSimulator({
    required this.amount,
    required this.email,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
       backgroundColor: Colors.transparent,
       insetPadding: const EdgeInsets.all(24),
       child: Container(
         width: 400,
         padding: const EdgeInsets.all(40),
         decoration: BoxDecoration(
           color: _bgWhite,
           borderRadius: BorderRadius.circular(24),
           boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
           ]
         ),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               decoration: BoxDecoration(
                 color: const Color(0xFF1B8A5A).withOpacity(0.1),
                 borderRadius: BorderRadius.circular(100),
               ),
               child: const Text("CHAPA TEST MODE", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1B8A5A), fontSize: 13, letterSpacing: 1.5)),
             ),
             const SizedBox(height: 32),
             Text(CurrencyFormatter.simple(amount, 'USD'), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: _navyPrimary)),
             const Text("Total Amount Due", style: TextStyle(color: _textLight, fontSize: 15)),
             const SizedBox(height: 48),
             SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onSuccess,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B8A5A), 
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("SIMULATE PAYMENT", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
             ),
             const SizedBox(height: 16),
             TextButton(
               onPressed: onCancel, 
               style: TextButton.styleFrom(foregroundColor: _textLight),
               child: const Text("Cancel"),
             ),
           ],
         ),
       ),
    );
  }
}
