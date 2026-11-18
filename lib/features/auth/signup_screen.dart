import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/privacy_dialog.dart';
import '../../core/services/auth_service.dart';
import 'auth_ui.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _shopNameController = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscure = true;
  bool _agreedToTerms = false;
  String _selectedCurrency = 'USD';
  String _selectedCountry = 'United States';

  static const int _stepCount = 3;
  int _step = 0;

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
    {'code': 'ZAR', 'name': 'South African Rand'},
    {'code': 'ETB', 'name': 'Ethiopian Birr'},
    {'code': 'NGN', 'name': 'Nigerian Naira'},
    {'code': 'KES', 'name': 'Kenyan Shilling'},
    {'code': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'BRL', 'name': 'Brazilian Real'},
    {'code': 'MXN', 'name': 'Mexican Peso'},
  ];
  final List<String> _countries = ['United States', 'Ethiopia', 'Kenya', 'Nigeria', 'South Africa', 'United Kingdom', 'Germany', 'France', 'Japan', 'Canada', 'Australia'];


  bool _hasUppercase = false;
  bool _hasDigits = false;
  bool _hasSpecialCharacters = false;
  bool _hasMinLength = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_refreshConfirmMatch);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _refreshConfirmMatch() {
    if (mounted) setState(() {});
  }

  void _validatePassword() {
    final p = _passwordController.text;
    setState(() {
      _hasUppercase = p.contains(RegExp(r'[A-Z]'));
      _hasDigits = p.contains(RegExp(r'[0-9]'));
      _hasSpecialCharacters = p.contains(RegExp(r'[!@#$%^&*(),.?\":{}|<>]'));
      _hasMinLength = p.length >= 8;
    });
  }

  void _goToStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step.clamp(0, _stepCount - 1);
      _error = null;
    });
  }

  String? _stepIssue(int step) {
    if (step == 0) {
      if (_fullNameController.text.trim().isEmpty ||
          _usernameController.text.trim().isEmpty ||
          _emailController.text.trim().isEmpty) {
        return 'Please fill in all fields';
      }
      if (!Provider.of<AuthService>(context, listen: false).isValidEmail(_emailController.text.trim())) {
        return 'Please enter a valid email address.';
      }
      if (_usernameController.text.trim().length < 3) {
        return 'Username must be at least 3 characters long';
      }
      return null;
    }
    if (step == 1) {
      if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
        return 'Please fill in all fields';
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        return 'Passwords do not match';
      }
      if (!_hasUppercase || !_hasDigits || !_hasSpecialCharacters || !_hasMinLength) {
        return 'Password does not meet requirements';
      }
      return null;
    }
    return null;
  }

  void _nextStep() {
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

  Future<void> _handleSignup() async {
    if (_usernameController.text.isEmpty || _fullNameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty || _shopNameController.text.isEmpty) {
      setState(() => _error = "Please fill in all fields");
      return;
    }

    if (_shopNameController.text.trim().length < 2) {
      setState(() => _error = "Business name must be at least 2 characters long");
      return;
    }

    if (_usernameController.text.length < 3) {
      setState(() => _error = "Username must be at least 3 characters long");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = "Passwords do not match");
      return;
    }

    if (!_hasUppercase || !_hasDigits || !_hasSpecialCharacters || !_hasMinLength) {
      setState(() => _error = "Password does not meet requirements");
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final email = _emailController.text.trim();
      final auth = Provider.of<AuthService>(context, listen: false);

      if (!auth.isValidEmail(email)) {
        setState(() { _loading = false; _error = "Please enter a valid email address."; });
        return;
      }

      if (!_agreedToTerms) {
        setState(() { _loading = false; _error = "Please agree to the Privacy Policy and Terms of Service."; });
        return;
      }

      await auth.signUp(
        email,
        _passwordController.text,
        _usernameController.text,
        _fullNameController.text,
        _shopNameController.text,
        currency: _selectedCurrency,
        country: _selectedCountry,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _stepTitle {
    switch (_step) {
      case 1:
        return 'Secure your account';
      case 2:
        return 'Set up your business';
      default:
        return 'Create your account';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 1:
        return 'Choose a strong password to protect your shop data.';
      case 2:
        return 'Tell us about the business you are managing.';
      default:
        return 'Start with your owner profile details.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);
    final isLastStep = _step == _stepCount - 1;

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
                    AuthIconButton(
                      icon: _step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded,
                      tooltip: _step == 0 ? 'Back to sign in' : 'Previous step',
                      onTap: () {
                        if (_step == 0) {
                          Navigator.of(context).pop();
                        } else {
                          _goToStep(_step - 1);
                        }
                      },
                    ),
                    const Spacer(),
                    const ThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: 6),
                const Center(
                  child: AuthBrandHeader(logoSize: 62, showTagline: false),
                ),
                const SizedBox(height: 22),
                AuthStepProgress(
                  step: _step,
                  total: _stepCount,
                  labels: const ['Account', 'Security', 'Business'],
                ),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: Column(
                    key: ValueKey<String>('heading_$_step'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stepTitle,
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: palette.title,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stepSubtitle,
                        style: TextStyle(fontSize: 13, height: 1.4, color: palette.body),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey<String>('step_$_step'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildStep(palette),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topCenter,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: AuthErrorBanner(message: _error!).animate().shake(),
                        ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: AuthSecondaryButton(
                          label: 'Back',
                          onTap: () => _goToStep(_step - 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _step > 0 ? 2 : 1,
                      child: AuthPrimaryButton(
                        label: isLastStep ? 'Create Account' : 'Continue',
                        loading: _loading,
                        onPressed: isLastStep ? _handleSignup : _nextStep,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(fontSize: 13, color: palette.body),
                      ),
                      const SizedBox(width: 5),
                      AuthLink(
                        label: 'Sign in',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const AuthFooterNote(text: 'Your data is secure with us'),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 450.ms)
              .slideY(begin: 0.035, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  List<Widget> _buildStep(AuthPalette palette) {
    switch (_step) {
      case 1:
        return [
          AuthTextField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 10),
          _buildStrengthMeter(palette),
          const SizedBox(height: 12),
          _buildPasswordRequirements(palette),
          const SizedBox(height: 16),
          AuthTextField(
            controller: _confirmPasswordController,
            hint: 'Confirm password',
            icon: Icons.lock_reset_rounded,
            obscure: _obscure,
            autofillHints: const [AutofillHints.newPassword],
          ),
          _buildConfirmMatch(palette),
        ];
      case 2:
        return [
          AuthTextField(
            controller: _shopNameController,
            hint: 'Shop / business name',
            icon: Icons.storefront_outlined,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 14),
          AuthDropdown<String>(
            value: _selectedCountry,
            icon: Icons.public_rounded,
            items: _countries
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedCountry = v);
            },
          ),
          const SizedBox(height: 14),
          AuthDropdown<String>(
            value: _selectedCurrency,
            icon: Icons.payments_outlined,
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
              if (v != null) setState(() => _selectedCurrency = v);
            },
          ),
          const SizedBox(height: 18),
          _buildTermsRow(palette),
        ];
      default:
        return [
          AuthTextField(
            controller: _fullNameController,
            hint: 'Full name',
            icon: Icons.badge_outlined,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _usernameController,
            hint: 'Username',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _emailController,
            hint: 'Email address',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
        ];
    }
  }

  Widget _buildStrengthMeter(AuthPalette palette) {
    final met = [_hasMinLength, _hasUppercase, _hasDigits, _hasSpecialCharacters]
        .where((m) => m)
        .length;
    final fraction = met / 4;
    final color = met <= 1
        ? palette.danger
        : met == 2
            ? palette.warning
            : met == 3
                ? palette.accent
                : palette.success;
    final label = met == 0
        ? 'Password strength'
        : met <= 1
            ? 'Weak password'
            : met == 2
                ? 'Fair password'
                : met == 3
                    ? 'Good password'
                    : 'Strong password';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 5, width: constraints.maxWidth, color: palette.divider),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: 5,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 7),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontFamily: authFontFamily(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: met == 0 ? palette.muted : color,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildPasswordRequirements(AuthPalette palette) {
    final items = <(String, bool)>[
      ('At least 8 characters', _hasMinLength),
      ('One uppercase letter', _hasUppercase),
      ('One number', _hasDigits),
      ('One special character', _hasSpecialCharacters),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final met = item.$2;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: met ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: met
                  ? palette.accent.withValues(alpha: 0.4)
                  : palette.fieldBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                met ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 13,
                color: met ? palette.accent : palette.muted,
              ),
              const SizedBox(width: 6),
              Text(
                item.$1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                  color: met ? palette.title : palette.muted,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildConfirmMatch(AuthPalette palette) {
    final text = _confirmPasswordController.text;
    final matches = text.isNotEmpty && text == _passwordController.text;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topLeft,
      child: text.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(
                    matches ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 13,
                    color: matches ? palette.success : palette.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    matches ? 'Passwords match' : 'Passwords do not match',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: matches ? palette.success : palette.danger,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTermsRow(AuthPalette palette) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _agreedToTerms
                  ? LinearGradient(colors: [palette.buttonStart, palette.buttonEnd])
                  : null,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreedToTerms ? palette.accent : palette.fieldBorder,
                width: 1.2,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _agreedToTerms
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey<String>('checked'),
                      size: 14,
                      color: Colors.white,
                    )
                  : const SizedBox.shrink(key: ValueKey<String>('unchecked')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'I agree to the ',
                  style: TextStyle(fontSize: 12, height: 1.4, color: palette.body),
                ),
                AuthLink(
                  label: 'Privacy Policy & Terms',
                  fontSize: 12,
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const PrivacyPolicyDialog(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
