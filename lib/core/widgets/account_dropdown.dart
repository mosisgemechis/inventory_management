import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';
import '../services/theme_service.dart';
import '../l10n/l10n.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../models/subscription_models.dart';
import '../../features/subscription/subscription_screen.dart';

class AccountDropdown extends StatelessWidget {
  const AccountDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.secondary, width: 2),
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.secondary.withOpacity(0.1),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : user.username[0].toUpperCase(),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
        ),
      ),
      onPressed: () => _showAccountPanel(context, user),
    );
  }

  void _showAccountPanel(BuildContext context, AppUser user) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Account Panel',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 60, right: 20),
            child: Material(
              color: Colors.transparent,
              child: _AccountPanelContent(user: user),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(anim1),
            child: child,
          ),
        );
      },
    );
  }
}

class _AccountPanelContent extends StatelessWidget {
  final AppUser user;
  const _AccountPanelContent({required this.user});

  @override
  Widget build(BuildContext context) {
    final subService = Provider.of<SubscriptionService>(context);
    final sub = subService.current;
    final theme = Provider.of<ThemeService>(context);
    final l10n = Provider.of<LocalizationService>(context);

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : user.username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isNotEmpty ? user.fullName : user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email.isNotEmpty ? user.email : '@${user.username}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          user.role.name.toUpperCase(),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Primary Account Actions
          _AccountMenuItem(
            icon: Icons.person_outline_rounded,
            label: "My Profile",
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (ctx) => ProfileDialog(user: user),
              );
            },
          ),
          _AccountMenuItem(
            icon: Icons.notifications_none_rounded,
            label: "Notifications",
            onTap: () {
              Navigator.pop(context);
              _showNotificationsSummary(context);
            },
          ),
          const Divider(height: 1),
          // Links
          _AccountMenuItem(
            icon: Icons.security_rounded,
            label: "Privacy Policy",
            onTap: () {
              Navigator.pop(context);
              _showInfoDialog(context, "Privacy Policy", "This application stores data locally on your device. We do not transmit your local inventory or sales data to external servers without explicit action or synchronization enabled.");
            },
          ),
          _AccountMenuItem(
            icon: Icons.description_outlined,
            label: "Terms of Use",
            onTap: () {
              Navigator.pop(context);
              _showInfoDialog(context, "Terms of Use", "By using this application, you agree to maintain the confidentiality of your account credentials. GM Inventory ERP is provided 'as-is' without warranties of any kind.");
            },
          ),

          const Divider(height: 1),

          // Subscription & Preferences
          if (user.hasPermission(AppUser.pManageBilling))
            _AccountMenuItem(
              icon: Icons.payment_outlined,
              label: "Billing & Subscription",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()));
              },
            ),
          _AccountMenuItem(
            icon: theme.themeMode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            label: "Appearance",
            trailing: Switch.adaptive(
              value: theme.themeMode == ThemeMode.dark,
              onChanged: (v) => theme.toggleTheme(v),
              activeColor: AppColors.secondary,
            ),
          ),
          _AccountMenuItem(
            icon: Icons.language_outlined,
            label: "Language",
            trailing: Text(
              l10n.currentLanguage.toString().split('.').last.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.bold),
            ),
            onTap: () => _showLanguageSelector(context, l10n),
          ),

          const Divider(height: 1),
          _AccountMenuItem(
            icon: Icons.logout_rounded,
            label: "Log Out",
            color: Colors.redAccent,
            onTap: () async {
              Navigator.pop(context);
              await Provider.of<AuthService>(context, listen: false).signOut();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showNotificationsSummary(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text("System Notifications"),
          ],
        ),
        content: const Text(
          "Notifications are monitored automatically. Stock alerts and system events appear directly on your dashboard header.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, LocalizationService l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Select Language"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((lang) {
            return ListTile(
              title: Text(lang.toString().split('.').last.toUpperCase()),
              trailing: l10n.currentLanguage == lang ? const Icon(Icons.check, color: AppColors.success) : null,
              onTap: () {
                l10n.setLanguage(lang);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AccountMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;

  const _AccountMenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[600]),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY PROFILE DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class ProfileDialog extends StatefulWidget {
  final AppUser user;
  const ProfileDialog({super.key, required this.user});

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  AppUser get user => widget.user;

  @override
  Widget build(BuildContext context) {
    final roleName = user.role.name.toUpperCase();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Profile Card
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : user.username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isNotEmpty ? user.fullName : user.username,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text('@${user.username}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Profile Info Fields
            _buildProfileRow(Icons.email_outlined, "Email", user.email.isNotEmpty ? user.email : "Not specified"),
            const SizedBox(height: 12),
            _buildProfileRow(Icons.phone_outlined, "Phone Number", "N/A"),
            const SizedBox(height: 12),
            _buildBranchRowStreamed(context),
            const SizedBox(height: 12),
            _buildProfileRow(Icons.access_time_rounded, "Last Login", DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_reset_rounded, size: 18),
                  label: const Text("Change Password"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => const ChangePasswordDialog(),
                    );
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Streams live branch data to determine correct branch display
  Widget _buildBranchRowStreamed(BuildContext context) {
    DatabaseService db;
    try {
      db = Provider.of<DatabaseService>(context, listen: false);
    } catch (_) {
      db = DatabaseService();
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: db.watchBranches(user.shopId),
      builder: (ctx, snap) {
        final branches = snap.data ?? [];
        return _buildBranchRowFromData(context, branches);
      },
    );
  }

  Widget _buildBranchRowFromData(BuildContext context, List<Map<String, dynamic>> allBranches) {
    final isAdmin = user.hasRole(UserRole.admin);
    final branchCount = allBranches.length;

    // Admin with more than 1 branch always gets "All Branches"
    if (isAdmin && branchCount > 1) {
      return _buildProfileRow(Icons.store_outlined, "Branch Access", "All Branches");
    }

    // Explicit all-branch marker
    if (user.branchId == 'all' || user.branchName?.toLowerCase() == 'all') {
      return _buildProfileRow(Icons.store_outlined, "Branch Access", "All Branches");
    }

    // Multi-branch non-admin (comma-separated)
    if (user.branchId.contains(',')) {
      final parts = user.branchId.split(',');
      final branchNames = user.branchName?.split(',') ?? parts;
      return _buildMultiBranchRow(context, parts.length, branchNames);
    }

    // Single branch
    final displayName = (user.branchId == 'main' || user.branchId.isEmpty)
        ? (user.branchName ?? 'Main Branch')
        : (user.branchName ?? user.branchId);
    return _buildProfileRow(Icons.store_outlined, "Assigned Branch", displayName);
  }

  Widget _buildMultiBranchRow(BuildContext context, int count, List<String> branchNames) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.store_outlined, size: 18, color: Colors.grey[600]),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text("Assigned Branches", style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ),
            Text("$count Branches", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            minimumSize: const Size(50, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: () {
            showDialog(context: context, builder: (c) => AlertDialog(
              title: const Text("Assigned Branches"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: branchNames.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: AppColors.success, size: 18),
                      const SizedBox(width: 12),
                      Text(b.trim(), style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                )).toList(),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Close"))],
            ));
          },
          child: const Text("View"),
        ),
      ],
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

}


// ─────────────────────────────────────────────────────────────────────────────
// CHANGE PASSWORD DIALOG (Current User)
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

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
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
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Change Password", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Update your account security credentials", style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
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
    );
  }

  Widget _reqItem(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined, size: 14, color: met ? AppColors.success : Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 11, color: met ? AppColors.success : Colors.grey)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN RESET PASSWORD DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class AdminResetPasswordDialog extends StatefulWidget {
  final String targetUserId;
  final String targetUsername;

  const AdminResetPasswordDialog({
    super.key,
    required this.targetUserId,
    required this.targetUsername,
  });

  @override
  State<AdminResetPasswordDialog> createState() => _AdminResetPasswordDialogState();
}

class _AdminResetPasswordDialogState extends State<AdminResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _showNew = false;
  bool _showConfirm = false;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  bool _hasLength(String p) => p.trim().length >= 8;
  bool _hasUpper(String p) => RegExp(r'[A-Z]').hasMatch(p.trim());
  bool _hasDigit(String p) => RegExp(r'[0-9]').hasMatch(p.trim());
  bool _hasSpecial(String p) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(p.trim());

  Future<void> _submitReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      await auth.adminResetUserPassword(
        targetUserId: widget.targetUserId,
        targetUsername: widget.targetUsername,
        newPassword: _newC.text,
        confirmPassword: _confirmC.text,
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Password for '${widget.targetUsername}' reset successfully."),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
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
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_rounded, color: AppColors.warning, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Reset Staff Password", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("Reset credentials for @${widget.targetUsername}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
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

              // New Password
              TextFormField(
                controller: _newC,
                obscureText: !_showNew,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: "New Temporary Password",
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
                  if (v == null || v.trim().isEmpty) return "Please confirm new password";
                  if (v.trim() != _newC.text.trim()) return "Passwords do not match";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Requirements Checklist
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
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _submitReset,
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Reset Password"),
                  ),
                ],
              ),
            ],
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
          Text(text, style: TextStyle(fontSize: 11, color: met ? AppColors.success : Colors.grey)),
        ],
      ),
    );
  }
}
