import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'change_password_dialog.dart';
import '../../features/auth/password_checklist.dart';

/// Account security: how the user signs in and how they can recover access.
///
/// Password changes are handled by the app's existing Change Password dialog,
/// opens the change-password form itself.
class AccountSecurityDialog extends StatefulWidget {
  const AccountSecurityDialog({super.key, this.methodsLoader});

  /// Overrides the backend lookup; used by widget tests.
  final Future<Map<String, dynamic>> Function()? methodsLoader;

  @override
  State<AccountSecurityDialog> createState() => _AccountSecurityDialogState();
}

enum _Mode { overview, addLogin, recovery }

class _AccountSecurityDialogState extends State<AccountSecurityDialog> {
  final _usernameC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();
  final _emailC = TextEditingController();
  final _codeC = TextEditingController();

  Map<String, dynamic>? _methods;
  bool _loading = true;
  bool _busy = false;
  bool _codeSent = false;
  _Mode _mode = _Mode.overview;
  String? _error;
  String? _notice;

  bool get _hasPassword => _methods?['password_configured'] == true;
  bool get _hasGoogle => _methods?['google_connected'] == true;
  bool get _recoveryVerified => _methods?['recovery_email_verified'] == true;
  String get _recoveryEmail => (_methods?['recovery_email'] ?? '').toString();
  String get _username => (_methods?['username'] ?? '').toString();
  bool get _offline => _methods?['offline'] == true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usernameC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    _emailC.dispose();
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final methods =
          await (widget.methodsLoader?.call() ?? AuthService().securityMethods());
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loading = false;
        _emailC.text = _recoveryEmail;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _clean(e);
      });
    }
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  void _startAddLogin() {
    // Never pre-fill a generated placeholder username.
    final name = _username;
    _usernameC.text = (name.isEmpty || name.contains('-')) ? '' : name;
    _passwordC.clear();
    _confirmC.clear();
    setState(() {
      _mode = _Mode.addLogin;
      _error = null;
      _notice = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLogin() async {
    final username = _usernameC.text.trim();
    final password = _passwordC.text;
    if (username.length < 3) {
      setState(() => _error = 'Choose a username with at least 3 characters.');
      return;
    }
    if (password.length < 8 ||
        !password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[0-9]')) ||
        !password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      setState(() => _error =
          'Use 8 or more characters, including an uppercase letter, a number '
          'and a symbol.');
      return;
    }
    if (password != _confirmC.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    await _run(() async {
      await AuthService().addLoginPassword(username: username, password: password);
      await _load();
      _passwordC.clear();
      _confirmC.clear();
      if (mounted) {
        setState(() {
          _mode = _Mode.overview;
          _notice = 'Username and password saved. Google sign-in still works.';
        });
      }
    });
  }

  Future<void> _openChangePassword() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
    if (mounted) await _load();
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _username);
    final value = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change username'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Username',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().length < 3) return;
    await _run(() async {
      await AuthService().updateUsername(value.trim());
      await _load();
      if (mounted) setState(() => _notice = 'Username updated.');
    });
  }

  Future<void> _sendCode() async {
    final email = _emailC.text.trim().toLowerCase();
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    final accountEmail =
        (_methods?['account_email'] ?? _methods?['google_email'] ?? '')
            .toString()
            .toLowerCase();
    if (accountEmail.isNotEmpty && email == accountEmail) {
      setState(() => _error =
          'Use a different address from the email you sign in with.');
      return;
    }
    await _run(() async {
      final result = await AuthService().sendRecoveryEmail(email);
      if (!mounted) return;
      final delivered = result['delivered'] == true;
      setState(() {
        if (delivered) {
          _codeSent = true;
          _notice = 'We sent a verification code to $email.';
        } else if (result['reason'] == 'domain_not_verified') {
          _error = 'The email service is not accepting this address yet. Email '
              'delivery needs a verified sending domain.';
        } else {
          _error = 'We could not send the email right now. Please try again.';
        }
      });
    });
  }

  Future<void> _verifyCode() async {
    final code = _codeC.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the full code from the email.');
      return;
    }
    await _run(() async {
      await AuthService().confirmRecoveryEmail(code);
      await _load();
      if (!mounted) return;
      setState(() {
        _mode = _Mode.overview;
        _codeSent = false;
        _notice = 'Recovery email verified.';
        _codeC.clear();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 660),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child:
                      Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(scheme),
                    const SizedBox(height: 16),
                    if (_mode == _Mode.overview) _overview(scheme, isDark),
                    if (_mode == _Mode.addLogin) _addLoginForm(scheme),
                    if (_mode == _Mode.recovery) _recoveryForm(scheme),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _message(_error!, scheme.error),
                    ],
                    if (_notice != null) ...[
                      const SizedBox(height: 12),
                      _message(_notice!, scheme.onSurfaceVariant),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account security',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'How you sign in and how you can recover access.',
                style:
                    TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 20, color: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _overview(ColorScheme scheme, bool isDark) {
    final protected = _hasPassword && _recoveryVerified;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: protected
                ? AppColors.success.withValues(alpha: isDark ? 0.12 : 0.08)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : scheme.onSurface.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            protected
                ? 'This account has a backup login and a verified recovery email.'
                : _hasPassword
                    ? 'You can sign in without Google. Add a verified recovery '
                        'email to reset your password if you forget it.'
                    : 'You currently sign in with Google. Adding a username and '
                        'password gives you a second way to sign in.',
            style: TextStyle(
                fontSize: 12.5, height: 1.45, color: scheme.onSurface),
          ),
        ),
        const SizedBox(height: 6),
        if (_hasGoogle)
          _row(
            scheme,
            'Google',
            (_methods?['google_email'] ?? '').toString(),
            status: 'Connected',
          ),
        _row(
          scheme,
          'Username and password',
          _hasPassword
              ? (_username.isEmpty ? 'Set up' : _username)
              : 'Not set up',
          status: _hasPassword ? 'Active' : null,
          actionLabel: _hasPassword ? 'Change password' : 'Add',
          actionIcon: _hasPassword ? null : Icons.add_rounded,
          onAction: _hasPassword ? _openChangePassword : _startAddLogin,
        ),
        if (_hasPassword)
          _row(
            scheme,
            'Username',
            _username.isEmpty ? 'Not set' : _username,
            actionLabel: 'Change',
            onAction: _editUsername,
          ),
        _row(
          scheme,
          'Recovery email',
          _recoveryEmail.isEmpty ? 'Not set up' : _recoveryEmail,
          status: _recoveryVerified
              ? 'Verified'
              : (_recoveryEmail.isEmpty ? null : 'Unverified'),
          statusColor: _recoveryVerified
              ? AppColors.success
              : (_recoveryEmail.isEmpty ? null : AppColors.warning),
          note: _offline ? 'Needs an internet connection to check.' : null,
          actionLabel: _recoveryVerified
              ? 'Change'
              : (_recoveryEmail.isEmpty ? 'Add' : 'Verify'),
          actionIcon: _recoveryVerified || !_recoveryEmail.isEmpty
              ? null
              : Icons.add_rounded,
          onAction: () => setState(() {
            _mode = _Mode.recovery;
            _codeSent = false;
            _notice = null;
            _error = null;
          }),
        ),
      ],
    );
  }

  Widget _addLoginForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a username and password',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'This is a second way to sign in, separate from your Google password '
          'and safe to use on any device.',
          style: TextStyle(
              fontSize: 12.5, height: 1.4, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _field(
          scheme,
          controller: _usernameC,
          label: 'Username',
          hint: 'Choose your username',
          autofocus: true,
        ),
        const SizedBox(height: 12),
        _field(
          scheme,
          controller: _passwordC,
          label: 'Password',
          obscure: true,
        ),
        const SizedBox(height: 8),
        PasswordChecklist(
          controller: _passwordC,
          activeColor: AppColors.success,
          idleColor: scheme.onSurfaceVariant,
          textColor: scheme.onSurface,
          activeBackground: AppColors.success.withValues(alpha: 0.10),
          idleBorder: scheme.outlineVariant,
        ),
        const SizedBox(height: 12),
        _field(
          scheme,
          controller: _confirmC,
          label: 'Confirm password',
          obscure: true,
        ),
        const SizedBox(height: 16),
        _primaryButton('Save', _busy ? null : _saveLogin),
        const SizedBox(height: 4),
        _linkButton('Cancel', () => setState(() => _mode = _Mode.overview)),
      ],
    );
  }

  Widget _recoveryForm(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recovery email',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          'We only use this address to confirm the email and to send password '
          'reset codes. It is never shown to customers or staff.',
          style: TextStyle(
              fontSize: 12.5, height: 1.4, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _field(
          scheme,
          controller: _emailC,
          label: 'Email address',
          keyboardType: TextInputType.emailAddress,
          enabled: !_codeSent,
        ),
        if (!_codeSent) ...[
          const SizedBox(height: 14),
          _primaryButton(_busy ? 'Sending…' : 'Send code', _busy ? null : _sendCode),
        ] else ...[
          const SizedBox(height: 12),
          _field(
            scheme,
            controller: _codeC,
            label: 'Verification code',
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 14),
          _primaryButton(_busy ? 'Verifying…' : 'Verify', _busy ? null : _verifyCode),
          const SizedBox(height: 4),
          Row(
            children: [
              _linkButton('Change email', () => setState(() => _codeSent = false)),
              const SizedBox(width: 6),
              _linkButton('Resend', _busy ? null : _sendCode),
            ],
          ),
        ],
        const SizedBox(height: 4),
        _linkButton('Back', () => setState(() {
              _mode = _Mode.overview;
              _codeSent = false;
            })),
      ],
    );
  }

  Widget _row(
    ColorScheme scheme,
    String title,
    String detail, {
    String? status,
    Color? statusColor,
    String? note,
    String? actionLabel,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor ?? AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  detail.isEmpty ? 'Not set up' : detail,
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                if (note != null)
                  Text(note,
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton.icon(
              onPressed: onAction,
              icon: actionIcon != null
                  ? Icon(actionIcon, size: 16)
                  : const SizedBox.shrink(),
              label: Text(actionLabel,
                  style: const TextStyle(fontSize: 12.5)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(
    ColorScheme scheme, {
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    bool enabled = true,
    bool autofocus = false,
    TextInputType? keyboardType,
    String? hint,
    String? helper,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13.5)),
      ),
    );
  }

  Widget _linkButton(String label, VoidCallback? onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12.5)),
    );
  }

  Widget _message(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12, height: 1.4, color: color)),
    );
  }
}
