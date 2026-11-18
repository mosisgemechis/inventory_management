import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../../main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHANGE PASSWORD DIALOG (current signed-in user)
// ─────────────────────────────────────────────────────────────────────────────
class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({super.key});

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  bool _hasLength(String p) => p.trim().length >= 8;
  bool _hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p.trim());
  bool _hasDigit(String p) => RegExp(r'[0-9]').hasMatch(p.trim());
  bool _hasSpecial(String p) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p.trim());

  Future<void> _submitChange() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      await auth.changeCurrentPassword(
        currentPassword: _currentC.text,
        newPassword: _newC.text,
        confirmPassword: _confirmC.text,
      );

      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) {
        nav.pop();
      }

      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text("Password updated successfully. Please log in with your new password."),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final newPass = _newC.text;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Change Password", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          "Update your account security credentials",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Current Password
              TextFormField(
                controller: _currentC,
                obscureText: !_showCurrent,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showCurrent ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showCurrent = !_showCurrent),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Please enter your current password" : null,
              ),
              const SizedBox(height: 14),

              // New Password
              TextFormField(
                controller: _newC,
                obscureText: !_showNew,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: "New Password",
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_showNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
                validator: (v) => AuthService.validatePasswordRequirements(v ?? ''),
              ),
              const SizedBox(height: 14),

              // Confirm Password
              TextFormField(
                controller: _confirmC,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  prefixIcon: const Icon(Icons.lock_clock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Please confirm your new password";
                  if (v.trim() != _newC.text.trim()) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Real-time Requirements Checklist
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Password Requirements:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 6),
                    _reqItem("At least 8 characters", _hasLength(newPass)),
                    _reqItem("At least 1 uppercase letter (A-Z)", _hasUpper(newPass)),
                    _reqItem("At least 1 digit (0-9)", _hasDigit(newPass)),
                    _reqItem("At least 1 special character (!@#\$%^&*)", _hasSpecial(newPass)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit & Cancel
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _submitChange,
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Update Password"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _reqItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: met ? AppColors.success : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 11, color: met ? AppColors.success : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
