import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_manager/core/models/subscription_models.dart';
import 'package:inventory_manager/core/utils/currency_formatter.dart';
import 'plan_colors.dart';
import '../../core/services/subscription_change.dart';

/// Brand detected from the card number.
enum CardBrand { none, visa, mastercard }

/// Three-step, interactive checkout used by Plans & Billing.
///
/// Step 1 reviews the plan and its add-ons, step 2 collects the payment
/// method, step 3 processes the activation through [onPay].
class CheckoutFlow extends StatefulWidget {
  const CheckoutFlow({
    super.key,
    required this.plan,
    required this.addOns,
    required this.total,
    required this.initialCardMethod,
    required this.onPay,
    this.amountDueToday,
    this.changeNote,
    this.billingCycle = BillingCycle.monthly,
  });

  final SubscriptionPlan plan;
  final List<SubscriptionAddOn> addOns;
  final double total;
  final bool initialCardMethod;
  final Future<void> Function() onPay;
  final double? amountDueToday;
  final String? changeNote;
  final BillingCycle billingCycle;

  double get dueToday => amountDueToday ?? total;
  bool get _yearly => billingCycle.isYearly;

  @override
  State<CheckoutFlow> createState() => _CheckoutFlowState();
}

class _CheckoutFlowState extends State<CheckoutFlow> {
  int _step = 0;
  bool _cardMethod = true;
  bool _processing = false;
  bool _done = false;
  String? _error;

  final _cardNumber = TextEditingController();
  final _cardName = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _phone = TextEditingController();

  CardBrand _brand = CardBrand.none;

  @override
  void initState() {
    super.initState();
    _cardMethod = widget.initialCardMethod;
    _cardNumber.addListener(_onCardChanged);
    _cardName.addListener(_onCardChanged);
    _expiry.addListener(_onCardChanged);
  }

  @override
  void dispose() {
    _cardNumber.removeListener(_onCardChanged);
    _cardName.removeListener(_onCardChanged);
    _expiry.removeListener(_onCardChanged);
    _cardNumber.dispose();
    _cardName.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _onCardChanged() {
    final digits = _digits(_cardNumber.text);
    setState(() => _brand = _detectBrand(digits));
  }

  String get _maskedNumber {
    final digits = _digits(_cardNumber.text);
    if (digits.isEmpty) return "•••• •••• •••• ••••";
    final groups = <String>[];
    for (var i = 0; i < digits.length; i += 4) {
      groups.add(digits.substring(
          i, i + 4 > digits.length ? digits.length : i + 4));
    }
    return groups.join(' ').padRight(19, '•');
  }

  String _digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  CardBrand _detectBrand(String digits) {
    if (digits.isEmpty) return CardBrand.none;
    if (digits.startsWith('4')) return CardBrand.visa;
    final two = int.tryParse(digits.length >= 2 ? digits.substring(0, 2) : '');
    if (two != null && two >= 51 && two <= 55) return CardBrand.mastercard;
    final four =
        int.tryParse(digits.length >= 4 ? digits.substring(0, 4) : '');
    if (four != null && four >= 2221 && four <= 2720) {
      return CardBrand.mastercard;
    }
    return CardBrand.none;
  }

  bool get _cardValid {
    final digits = _digits(_cardNumber.text);
    final expiry = _expiry.text.trim();
    final parts = expiry.split('/');
    final month = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final cvv = _digits(_cvv.text);
    return digits.length >= 15 &&
        _cardName.text.trim().length >= 3 &&
        parts.length == 2 &&
        month >= 1 &&
        month <= 12 &&
        (parts[1].trim().length == 2) &&
        (cvv.length == 3 || cvv.length == 4);
  }

  bool get _phoneValid => _digits(_phone.text).length >= 9;

  bool get _canPay => _cardMethod ? _cardValid : _phoneValid;

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = 2;
      _processing = true;
      _error = null;
    });

    // Short, visible processing state so the step reads as a real flow.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    try {
      await widget.onPay();
      if (!mounted) return;
      setState(() {
        _processing = false;
        _done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processing = false;
        _step = 1;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = PlanColors.of(context);
    final media = MediaQuery.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      decoration: BoxDecoration(
        color: c.page,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 2),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [c.accent, c.navy],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Secure checkout",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: c.heading),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 12, color: c.muted),
                            const SizedBox(width: 4),
                            Text(
                              widget._yearly
                                  ? "Annual plan · 15% off · encrypted"
                                  : "Encrypted payment · cancel anytime",
                              style:
                                  TextStyle(fontSize: 11.5, color: c.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: c.muted),
                  ),
                ],
              ),
            ),
            _StepBar(step: _step, done: _done, colors: c),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _step == 0
                      ? _reviewStep(c)
                      : _step == 1
                          ? _paymentStep(c)
                          : _processingStep(c),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1: review ────────────────────────────────────────────────────────
  Widget _reviewStep(PlanColors c) {
    final totalLabel = CurrencyFormatter.simple(widget.dueToday, 'USD');
    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.workspace_premium_rounded,
                        color: c.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${widget.plan.name} plan",
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: c.heading)),
                        const SizedBox(height: 2),
                        Text(
                            widget._yearly
                                ? "Billed yearly · 15% plan discount"
                                : "Billed monthly · cancel anytime",
                            style: TextStyle(fontSize: 12, color: c.muted)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.simple(
                            planPriceFor(widget.plan, widget.billingCycle),
                            'USD'),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: c.heading),
                      ),
                      Text(
                        widget._yearly ? "/ year" : "/ month",
                        style: TextStyle(fontSize: 10.5, color: c.muted),
                      ),
                    ],
                  ),
                ],
              ),
              if (widget.addOns.isNotEmpty) ...[
                Divider(height: 28, color: c.border),
                ...widget.addOns.map((addOn) {
                  final price = addOnPriceFor(
                      widget.plan, addOn, widget.billingCycle);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded,
                            size: 16, color: c.muted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(addOn.name,
                              style: TextStyle(fontSize: 13, color: c.muted)),
                        ),
                        Text(CurrencyFormatter.simple(price, 'USD'),
                            style: TextStyle(fontSize: 13, color: c.muted)),
                      ],
                    ),
                  );
                }),
              ],
              if (widget._yearly) ...[
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 14, color: const Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Annual plan discount (15%)",
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF16A34A)),
                      ),
                    ),
                    Text(
                      "− ${CurrencyFormatter.simple(annualSavingsFor(widget.plan), 'USD')}",
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Divider(height: 26, color: c.border),
              Row(
                children: [
                  Expanded(
                    child: Text("Total due today",
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: c.heading)),
                  ),
                  Text(totalLabel,
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: c.accent)),
                ],
              ),
              if (widget.changeNote != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.changeNote!,
                  style: TextStyle(fontSize: 11.5, height: 1.4, color: c.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _primaryButton(
          c,
          label: "Continue to payment",
          icon: Icons.arrow_forward_rounded,
          onPressed: () => setState(() => _step = 1),
        ),
      ],
    );
  }

  // ── Step 2: payment method ────────────────────────────────────────────────
  Widget _paymentStep(PlanColors c) {
    final totalLabel = CurrencyFormatter.simple(widget.dueToday, 'USD');
    return Column(
      key: const ValueKey('payment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _methodTile(
                c,
                selected: !_cardMethod,
                title: "Telebirr",
                subtitle: "Pay with your mobile wallet",
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A651).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone_iphone_rounded,
                      color: Color(0xFF00A651), size: 20),
                ),
                onTap: () => setState(() => _cardMethod = false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _methodTile(
                c,
                selected: _cardMethod,
                title: "Card",
                subtitle: "Visa or Mastercard",
                leading: const _CardLogos(),
                onTap: () => setState(() => _cardMethod = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _cardMethod ? _cardForm(c) : _walletForm(c),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: Color(0xFFDC2626), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFDC2626), fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _primaryButton(
          c,
          label: "Pay $totalLabel",
          icon: Icons.lock_rounded,
          onPressed: _canPay ? _pay : null,
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _step = 0),
          child: Text("Back to review",
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _cardForm(PlanColors c) {
    return Column(
      key: const ValueKey('card-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CardPreview(
          colors: c,
          number: _maskedNumber,
          name: _cardName.text.trim().isEmpty
              ? "YOUR NAME"
              : _cardName.text.trim().toUpperCase(),
          expiry: _expiry.text.trim().isEmpty ? "MM/YY" : _expiry.text.trim(),
          brand: _brand,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cardNumber,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(19),
            _CardNumberFormatter(),
          ],
          decoration: InputDecoration(
            labelText: "Card number",
            hintText: "1234 5678 9012 3456",
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _BrandBadge(brand: _brand),
            ),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 48, minHeight: 24),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cardName,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: "Name on card"),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiry,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                  _ExpiryFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: "Expiry", hintText: "MM/YY"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cvv,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    labelText: "CVV", hintText: "123"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _walletForm(PlanColors c) {
    return Column(
      key: const ValueKey('wallet-form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: "Telebirr number",
            hintText: "09xxxxxxxx",
            prefixIcon: Icon(Icons.phone_iphone_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "A payment request will be sent to your Telebirr wallet.",
          style: TextStyle(fontSize: 12, color: c.muted),
        ),
      ],
    );
  }

  // ── Step 3: processing / done ─────────────────────────────────────────────
  Widget _processingStep(PlanColors c) {
    return Padding(
      key: const ValueKey('processing'),
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                  parent: animation, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _done
                ? Container(
                    key: const ValueKey('done'),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF16A34A).withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 44),
                  )
                : Stack(
                    key: const ValueKey('spinner'),
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                            strokeWidth: 5,
                            color: c.accent.withValues(alpha: 0.25)),
                      ),
                      SizedBox(
                        width: 74,
                        height: 74,
                        child: CircularProgressIndicator(
                            strokeWidth: 5, color: c.accent),
                      ),
                      Icon(Icons.credit_card_rounded,
                          color: c.accent, size: 24),
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          Text(
            _done ? "You're all set!" : "Processing payment…",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: c.heading),
          ),
          const SizedBox(height: 8),
          Text(
            _done
                ? "${widget.plan.name} is now active — billed ${widget._yearly ? 'yearly' : 'monthly'}."
                : "Please keep this screen open.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.muted),
          ),
          if (_processing) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              color: c.accent,
              backgroundColor: c.border,
              minHeight: 4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _methodTile(
    PlanColors c, {
    required bool selected,
    required String title,
    required String subtitle,
    required Widget leading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.08) : c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? c.accent : c.border, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                leading,
                const Spacer(),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 18,
                  color: selected ? c.accent : c.muted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: c.heading)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: c.muted)),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(
    PlanColors c, {
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: c.button,
          foregroundColor: c.onButton,
          disabledBackgroundColor: c.border,
          disabledForegroundColor: c.muted,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  const _CardPreview({
    required this.colors,
    required this.number,
    required this.name,
    required this.expiry,
    required this.brand,
  });

  final PlanColors colors;
  final String number;
  final String name;
  final String expiry;
  final CardBrand brand;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 168,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.button, colors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.accent.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contactless_rounded,
                  color: Colors.white70, size: 22),
              const Spacer(),
              if (brand == CardBrand.visa)
                const _VisaMark()
              else if (brand == CardBrand.mastercard)
                const _MastercardMark()
              else
                const Icon(Icons.credit_card_rounded,
                    color: Colors.white70, size: 22),
            ],
          ),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              number,
              key: ValueKey(number),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("CARDHOLDER",
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 8.5,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 3),
                    Text(
                      name.isEmpty ? "YOUR NAME" : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("EXPIRES",
                      style: TextStyle(
                          color: Colors.white60,
                          fontSize: 8.5,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 3),
                  Text(
                    expiry,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({
    required this.step,
    required this.done,
    required this.colors,
  });

  final int step;
  final bool done;
  final PlanColors colors;

  @override
  Widget build(BuildContext context) {
    const labels = ["Review", "Payment", "Done"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == step;
          final complete = i < step || (i == step && done);
          return Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active || complete
                        ? colors.accent
                        : colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: active || complete
                            ? colors.accent
                            : colors.border),
                  ),
                  child: complete
                      ? Icon(Icons.check_rounded,
                          size: 14, color: colors.onAccent)
                      : Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? colors.onAccent
                                  : colors.muted)),
                ),
                const SizedBox(width: 6),
                Text(labels[i],
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? colors.heading : colors.muted)),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: i < step ? colors.accent : colors.border,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Visa + Mastercard marks shown on the card payment option.
class _CardLogos extends StatelessWidget {
  const _CardLogos();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _VisaMark(),
        SizedBox(width: 6),
        _MastercardMark(),
      ],
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.brand});

  final CardBrand brand;

  @override
  Widget build(BuildContext context) {
    if (brand == CardBrand.visa) return const _VisaMark();
    if (brand == CardBrand.mastercard) return const _MastercardMark();
    return const Icon(Icons.credit_card_rounded,
        size: 20, color: Color(0xFF94A3B8));
  }
}

class _VisaMark extends StatelessWidget {
  const _VisaMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 0.6),
      ),
      child: const Text(
        "VISA",
        style: TextStyle(
          color: Color(0xFF1A1F71),
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          fontSize: 11,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

class _MastercardMark extends StatelessWidget {
  const _MastercardMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFFEB001B),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFF79E1B).withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final text = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}/${digits.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
