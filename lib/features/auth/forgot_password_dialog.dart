import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';

/// Password reset for the account currently being signed in.
///
/// The identifier is taken from the sign-in form, so the user cannot reset an
/// arbitrary account from here.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key, required this.identifier});

  final String identifier;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _codeC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();

  int _step = 0; // 0 = confirm, 1 = code + new password, 2 = done
  bool _busy = false;
  String? _error;
  String? _sentTo;

  bool get _hasIdentifier => widget.identifier.trim().isNotEmpty;

  @override
  void dispose() {
    _codeC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await AuthService().requestPasswordReset(widget.identifier.trim());
      if (!mounted) return;
      final delivered = result['delivered'] == true;
      if (!delivered) {
        setState(() {
          _error = result['reason'] == 'domain_not_verified'
              ? 'The email service is not accepting this address yet. Email '
                  'delivery needs a verified sending domain.'
              : 'We could not send the email right now. Please try again.';
        });
        return;
      }
      setState(() {
        _step = 1;
        _sentTo = result['email']?.toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final code = _codeC.text.trim();
    final password = _passwordC.text;
    if (code.length < 6) {
      setState(() => _error = 'Enter the code from the email.');
      return;
    }
    if (password.length < 8 ||
        !password.contains(RegExp(r'[A-Z]')) ||
        !password.contains(RegExp(r'[0-9]')) ||
        !password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      setState(() => _error =
          'Use 8 or more characters, including an uppercase letter, a number and a symbol.');
      return;
    }
    if (password != _confirmC.text) {
      setState(() => _error = 'The two passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService().confirmPasswordReset(code: code, newPassword: password);
      if (!mounted) return;
      setState(() => _step = 2);
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _step == 2 ? 'Password updated' : 'Reset your password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded,
                        size: 20, color: scheme.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!_hasIdentifier)
                Text(
                  'Enter your email or username in the sign-in form first, then '
                  'choose Forgot password.',
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: scheme.onSurfaceVariant),
                )
              else if (_step == 0)
                _confirmStep(scheme)
              else if (_step == 1)
                _codeStep(scheme)
              else
                _doneStep(scheme),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                      style: TextStyle(
                          fontSize: 12, height: 1.4, color: scheme.error)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmStep(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We will send a reset code to the email address on file for '
          '${widget.identifier.trim()}.',
          style: TextStyle(
              fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _primaryButton(_busy ? 'Sending…' : 'Send reset code',
            _busy ? null : _send),
        const SizedBox(height: 8),
        Text(
          'The code expires in 15 minutes and works once.',
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _codeStep(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _sentTo != null && _sentTo!.isNotEmpty
              ? 'We sent a reset code to $_sentTo. It expires in 15 minutes.'
              : 'We sent a reset code to the email on file. It expires in 15 minutes.',
          style: TextStyle(
              fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _field(scheme, _codeC, 'Reset code', keyboardType: TextInputType.number),
        const SizedBox(height: 12),
        _field(scheme, _passwordC, 'New password', obscure: true),
        const SizedBox(height: 12),
        _field(scheme, _confirmC, 'Confirm new password', obscure: true),
        const SizedBox(height: 16),
        _primaryButton(
            _busy ? 'Updating…' : 'Set new password', _busy ? null : _confirm),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : _send,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Send a new code',
                style: TextStyle(fontSize: 12.5)),
          ),
        ),
      ],
    );
  }

  Widget _doneStep(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your password was changed. Google sign-in and your shop data are '
          'unchanged. Sign in with the new password.',
          style: TextStyle(
              fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        _primaryButton('Back to sign in', () => Navigator.of(context).pop()),
      ],
    );
  }

  Widget _field(
    ColorScheme scheme,
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
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
}
