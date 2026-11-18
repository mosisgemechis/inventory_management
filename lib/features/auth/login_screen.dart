import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/l10n.dart';
import '../../core/services/auth_service.dart';
import 'auth_ui.dart';
import 'signup_screen.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_identifierController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) setState(() => _error = 'Please fill in all fields');
      return;
    }

    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await Provider.of<AuthService>(context, listen: false).signIn(
        _identifierController.text,
        _passwordController.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().contains(']') ? e.toString().split(']').last.trim() : e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  void _showForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (_) => ForgotPasswordDialog(
        identifier: _identifierController.text.trim(),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    if (_googleLoading || _loading) return;
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await Provider.of<AuthService>(context, listen: false).signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('Exception', '')
            .trim());
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

    return AuthShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    const ThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: 4),
                const Center(
                  child: AuthBrandHeader(logoSize: 88),
                ),
                const SizedBox(height: 28),
                Text(
                  'welcome_back'.tr(context),
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: palette.title,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'signin_continue'.tr(context),
                  style: TextStyle(fontSize: 13, color: palette.body),
                ),
                const SizedBox(height: 24),
                AuthTextField(
                  controller: _identifierController,
                  hint: 'Username or Email',
                  icon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleLogin(),
                  autofillHints: const [AutofillHints.password],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: AuthLink(
                      label: 'forgot_password'.tr(context),
                      onTap: _showForgotPassword,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  AuthErrorBanner(message: _error!).animate().shake(),
                ] else
                  const SizedBox(height: 8),
                AuthPrimaryButton(
                  label: 'Sign In',
                  loading: _loading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 22),
                const AuthDividerLabel(text: 'or continue with'),
                const SizedBox(height: 18),
                AuthSocialButton(
                  icon: FontAwesomeIcons.google,
                  iconColor: const Color(0xFF4285F4),
                  label: _googleLoading
                      ? 'Connecting to Google…'
                      : 'Sign in with Google',
                  onTap: _handleGoogleSignIn,
                ),
                const SizedBox(height: 26),
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'new_user'.tr(context),
                        style: TextStyle(fontSize: 13, color: palette.body),
                      ),
                      const SizedBox(width: 5),
                      AuthLink(
                        label: 'create_account'.tr(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        onTap: _openSignup,
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
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 20),
          Text(
            '© 2026 GM Inventory Everywhere. All rights reserved.',
            style: TextStyle(fontSize: 11, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
