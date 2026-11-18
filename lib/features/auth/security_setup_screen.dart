import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import 'auth_ui.dart';
import 'password_checklist.dart';

/// Shown once after Google onboarding: encourages (but never forces) the user
/// to add an independent GM Inventory Everywhere username/password.
class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = AuthService().user;
    if (user != null && user.username.isNotEmpty && !user.username.contains('-')) {
      _usernameController.text = user.username;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters long');
      return;
    }
    if (password.length < 8 ||
        !password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[0-9]')) ||
        !password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      setState(() => _error =
          'Use at least 8 characters with an uppercase letter, a number and a symbol.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Provider.of<AuthService>(context, listen: false)
          .addLoginPassword(username: username, password: password);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceFirst('Exception: ', '').trim());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    await Provider.of<AuthService>(context, listen: false).skipSecuritySetup();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AuthPalette.of(context);

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
                    const Spacer(),
                    const ThemeToggleButton(),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Protect your account',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: palette.title,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account currently signs in with Google only. Adding a '
                  'username and password gives you a second way to sign in if '
                  'Google is unavailable or you lose access to it.',
                  style:
                      TextStyle(fontSize: 13, height: 1.45, color: palette.body),
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: palette.warning.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 17, color: palette.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This is optional. Google sign-in keeps working, and '
                          'this password is separate from your Google password.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  controller: _usernameController,
                  hint: 'Choose a username',
                  icon: Icons.alternate_email_rounded,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  onToggleObscure: () => setState(() => _obscure = !_obscure),
                ),
                const SizedBox(height: 8),
                PasswordChecklist(
                  controller: _passwordController,
                  activeColor: palette.accent,
                  idleColor: palette.muted,
                  textColor: palette.title,
                  activeBackground: palette.accentSoft,
                  idleBorder: palette.fieldBorder,
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _confirmController,
                  hint: 'Confirm password',
                  icon: Icons.lock_reset_rounded,
                  obscure: _obscure,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBanner(message: _error!),
                ],
                const SizedBox(height: 22),
                AuthPrimaryButton(
                  label: 'Set up additional login',
                  loading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 12),
                AuthSecondaryButton(label: 'Skip for now', onTap: _skip),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    'You can add or change this later in Account Security.',
                    style: TextStyle(fontSize: 11.5, color: palette.muted),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.03, end: 0),
        ],
      ),
    );
  }
}
