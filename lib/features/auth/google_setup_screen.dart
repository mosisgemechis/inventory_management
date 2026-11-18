import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import 'auth_ui.dart';

/// Mandatory onboarding for accounts created through Google sign-in.
/// Google only proves the identity; country, currency and business details
/// must be chosen explicitly by the user.
class GoogleSetupScreen extends StatefulWidget {
  const GoogleSetupScreen({super.key});

  @override
  State<GoogleSetupScreen> createState() => _GoogleSetupScreenState();
}

class _GoogleSetupScreenState extends State<GoogleSetupScreen> {
  static const int _stepCount = 4;
  static const List<String> _stepLabels = [
    'You',
    'Country',
    'Business',
    'Review',
  ];

  static const List<Map<String, String>> _currencies = [
    {'code': 'USD', 'name': 'US Dollar'},
    {'code': 'EUR', 'name': 'Euro'},
    {'code': 'GBP', 'name': 'British Pound'},
    {'code': 'CAD', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'name': 'Australian Dollar'},
    {'code': 'NZD', 'name': 'New Zealand Dollar'},
    {'code': 'JPY', 'name': 'Japanese Yen'},
    {'code': 'CNY', 'name': 'Chinese Yuan'},
    {'code': 'INR', 'name': 'Indian Rupee'},
    {'code': 'SGD', 'name': 'Singapore Dollar'},
    {'code': 'HKD', 'name': 'Hong Kong Dollar'},
    {'code': 'AED', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'name': 'Saudi Riyal'},
    {'code': 'QAR', 'name': 'Qatari Riyal'},
    {'code': 'KWD', 'name': 'Kuwaiti Dinar'},
    {'code': 'ZAR', 'name': 'South African Rand'},
    {'code': 'ETB', 'name': 'Ethiopian Birr'},
    {'code': 'NGN', 'name': 'Nigerian Naira'},
    {'code': 'KES', 'name': 'Kenyan Shilling'},
    {'code': 'UGX', 'name': 'Ugandan Shilling'},
    {'code': 'TZS', 'name': 'Tanzanian Shilling'},
    {'code': 'GHS', 'name': 'Ghanaian Cedi'},
    {'code': 'EGP', 'name': 'Egyptian Pound'},
    {'code': 'MAD', 'name': 'Moroccan Dirham'},
    {'code': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'SEK', 'name': 'Swedish Krona'},
    {'code': 'NOK', 'name': 'Norwegian Krone'},
    {'code': 'DKK', 'name': 'Danish Krone'},
    {'code': 'PLN', 'name': 'Polish Zloty'},
    {'code': 'TRY', 'name': 'Turkish Lira'},
    {'code': 'RUB', 'name': 'Russian Ruble'},
    {'code': 'BRL', 'name': 'Brazilian Real'},
    {'code': 'MXN', 'name': 'Mexican Peso'},
    {'code': 'ARS', 'name': 'Argentine Peso'},
    {'code': 'CLP', 'name': 'Chilean Peso'},
    {'code': 'COP', 'name': 'Colombian Peso'},
    {'code': 'PKR', 'name': 'Pakistani Rupee'},
    {'code': 'BDT', 'name': 'Bangladeshi Taka'},
    {'code': 'IDR', 'name': 'Indonesian Rupiah'},
    {'code': 'MYR', 'name': 'Malaysian Ringgit'},
    {'code': 'PHP', 'name': 'Philippine Peso'},
    {'code': 'THB', 'name': 'Thai Baht'},
    {'code': 'VND', 'name': 'Vietnamese Dong'},
    {'code': 'KRW', 'name': 'South Korean Won'},
    {'code': 'ILS', 'name': 'Israeli Shekel'},
  ];

  static const List<String> _countries = [
    'Afghanistan', 'Albania', 'Algeria', 'Argentina', 'Australia', 'Austria',
    'Bahrain', 'Bangladesh', 'Belgium', 'Brazil', 'Bulgaria', 'Cameroon',
    'Canada', 'Chile', 'China', 'Colombia', 'Croatia', 'Cyprus',
    'Czech Republic', 'Denmark', 'Ecuador', 'Egypt', 'Estonia', 'Ethiopia',
    'Finland', 'France', 'Germany', 'Ghana', 'Greece', 'Hungary',
    'India', 'Indonesia', 'Iraq', 'Ireland', 'Israel', 'Italy',
    'Ivory Coast', 'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kuwait',
    'Latvia', 'Lebanon', 'Libya', 'Lithuania', 'Malaysia', 'Mexico',
    'Morocco', 'Mozambique', 'Netherlands', 'New Zealand', 'Nigeria', 'Norway',
    'Oman', 'Pakistan', 'Palestine', 'Peru', 'Philippines', 'Poland',
    'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda', 'Saudi Arabia',
    'Senegal', 'Serbia', 'Singapore', 'Slovakia', 'Slovenia', 'Somalia',
    'South Africa', 'South Korea', 'Spain', 'Sri Lanka', 'Sudan', 'Sweden',
    'Switzerland', 'Tanzania', 'Thailand', 'Tunisia', 'Turkey', 'Uganda',
    'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States',
    'Uruguay', 'Uzbekistan', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
  ];

  static const List<String> _businessTypes = [
    'Pharmacy',
    'Retail shop',
    'Supermarket',
    'Electronics store',
    'Clothing store',
    'General store',
    'Other',
  ];

  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();

  int _step = 0;
  String? _country;
  String? _currency;
  String? _businessType;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService().user;
    if (user != null && user.fullName.trim().isNotEmpty) {
      _nameController.text = user.fullName.trim();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  String? _stepIssue(int step) {
    switch (step) {
      case 0:
        if (_nameController.text.trim().length < 2) {
          return 'Please enter your name';
        }
        return null;
      case 1:
        if (_country == null) return 'Please select your country';
        if (_currency == null) return 'Please select your business currency';
        return null;
      case 2:
        if (_shopNameController.text.trim().length < 2) {
          return 'Business name must be at least 2 characters long';
        }
        if (_businessType == null) return 'Please select your business type';
        return null;
      default:
        return null;
    }
  }

  void _next() {
    FocusScope.of(context).unfocus();
    final issue = _stepIssue(_step);
    if (issue != null) {
      setState(() => _error = issue);
      return;
    }
    setState(() {
      _error = null;
      _step++;
    });
  }

  void _back() {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _step = (_step - 1).clamp(0, _stepCount - 1);
    });
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = AuthPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'Cancel sign-in?',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.title),
          ),
          content: Text(
            'Your shop setup is not finished. You can finish it the next time you '
            'sign in with Google.',
            style: TextStyle(fontSize: 13, height: 1.4, color: palette.body),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Keep setting up',
                  style: TextStyle(color: palette.body)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Cancel sign-in',
                  style: TextStyle(
                      color: palette.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await AuthService().signOut();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finish() async {
    for (var i = 0; i < _stepCount - 1; i++) {
      final issue = _stepIssue(i);
      if (issue != null) {
        setState(() {
          _error = issue;
          _step = i;
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Provider.of<AuthService>(context, listen: false).completeGoogleSetup(
        shopName: _shopNameController.text.trim(),
        businessType: _businessType!,
        currency: _currency!,
        country: _country!,
        displayName: _nameController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', '').trim());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _title {
    switch (_step) {
      case 1:
        return 'Where do you operate?';
      case 2:
        return 'Your business';
      case 3:
        return 'Confirm your details';
      default:
        return 'Welcome to GM Inventory Everywhere';
    }
  }

  String get _subtitle {
    switch (_step) {
      case 1:
        return 'Choose your country and the currency your business uses. '
            'This becomes your base currency.';
      case 2:
        return 'Name your business and pick the type that fits best.';
      case 3:
        return 'Check everything before creating your shop.';
      default:
        return 'This information comes from Google. Confirm it to continue.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final isLast = _step == _stepCount - 1;
    final email = AuthService().user?.email ?? '';

    return AuthShell(
      maxWidth: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_step > 0)
                      AuthIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Previous step',
                        onTap: _back,
                      )
                    else
                      AuthIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Cancel sign-in',
                        onTap: _cancel,
                      ),
                    const Spacer(),
                    const ThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: 18),
                AuthStepProgress(
                  step: _step,
                  total: _stepCount,
                  labels: _stepLabels,
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Column(
                    key: ValueKey<String>('setup_heading_$_step'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: palette.title,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle,
                        style: TextStyle(
                            fontSize: 13, height: 1.4, color: palette.body),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: Column(
                      key: ValueKey<String>('setup_step_$_step'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildStep(palette, email),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: _error!).animate().shake(),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: AuthSecondaryButton(label: 'Back', onTap: _back),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _step > 0 ? 2 : 1,
                      child: AuthPrimaryButton(
                        label: isLast ? 'Create my shop' : 'Continue',
                        loading: _saving,
                        onPressed: isLast ? _finish : _next,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: AuthLink(
                    label: 'Cancel and sign out',
                    onTap: _saving ? () {} : _cancel,
                  ),
                ),
                const SizedBox(height: 16),
                const AuthFooterNote(text: 'Your data is secure with us'),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.03, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  List<Widget> _buildStep(AuthPalette palette, String email) {
    switch (_step) {
      case 1:
        return [
          _selectionTile(
            palette: palette,
            icon: Icons.public_rounded,
            label: 'Country',
            value: _country,
            hint: 'Select country',
            onTap: _pickCountry,
          ),
          const SizedBox(height: 14),
          AuthDropdown<String>(
            value: _currency,
            icon: Icons.payments_outlined,
            hint: 'Select business currency',
            items: _currencies
                .map((c) => DropdownMenuItem(
                      value: c['code'],
                      child: Text(
                        '${c['code']} – ${c['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _currency = v);
            },
          ),
          if (_currency != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: palette.accent.withValues(alpha: 0.35)),
              ),
              child: Text(
                'All prices and reports will use $_currency.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
            ),
          ],
        ];
      case 2:
        return [
          AuthTextField(
            controller: _shopNameController,
            hint: 'Business / shop name',
            icon: Icons.storefront_outlined,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AuthDropdown<String>(
            value: _businessType,
            icon: Icons.category_outlined,
            hint: 'Select business type',
            items: _businessTypes
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _businessType = v);
            },
          ),
        ];
      case 3:
        return [
          _reviewRow(palette, 'Name', _nameController.text.trim()),
          _reviewRow(palette, 'Email', email),
          _reviewRow(palette, 'Country', _country ?? '—'),
          _reviewRow(palette, 'Currency', _currency ?? '—'),
          _reviewRow(palette, 'Business', _shopNameController.text.trim()),
          _reviewRow(palette, 'Business type', _businessType ?? '—'),
        ];
      default:
        return [
          AuthTextField(
            controller: _nameController,
            hint: 'Full name',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: palette.field,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.fieldBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_outlined,
                    size: 17, color: palette.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: palette.body),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  Widget _selectionTile({
    required AuthPalette palette,
    required IconData icon,
    required String label,
    required String? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: palette.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.fieldBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: palette.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value ?? hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w500,
                  color: value == null ? palette.muted : palette.title,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: palette.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCountry() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => _SearchPickerDialog(
        title: 'Select country',
        options: _countries,
        selected: _country,
      ),
    );
    if (selected != null) setState(() => _country = selected);
  }

  Widget _reviewRow(AuthPalette palette, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: palette.body)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: palette.title,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchPickerDialog extends StatefulWidget {
  const _SearchPickerDialog({
    required this.title,
    required this.options,
    this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  State<_SearchPickerDialog> createState() => _SearchPickerDialogState();
}

class _SearchPickerDialogState extends State<_SearchPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final matches = widget.options
        .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Dialog(
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.title,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 14, color: palette.title),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: TextStyle(fontSize: 14, color: palette.muted),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: palette.muted),
                  filled: true,
                  fillColor: palette.field,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: palette.fieldBorder),
                  ),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  itemBuilder: (ctx, i) {
                    final option = matches[i];
                    final isSelected = option == widget.selected;
                    return ListTile(
                      dense: true,
                      title: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w400,
                          color: palette.title,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded,
                              size: 18, color: palette.accent)
                          : null,
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
