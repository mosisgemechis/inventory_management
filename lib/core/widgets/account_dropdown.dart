import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/subscription_service.dart';
import '../services/theme_service.dart';
import '../l10n/l10n.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../models/subscription_models.dart';
import '../../features/subscription/subscription_screen.dart';
import 'dart:ui';

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
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Section
          Padding(
            padding: const EdgeInsets.all(20),
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isNotEmpty ? user.fullName : user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.email,
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

          // Billing & Subscription Section
          _buildCompactBillingSection(context, sub),
          const Divider(height: 1),

          // Menu Items
          _AccountMenuItem(
            icon: Icons.payment_outlined,
            label: "Billing",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()));
            },
          ),
          _AccountMenuItem(
            icon: Icons.language_outlined,
            label: "Language",
            trailing: Text(l10n.currentLanguage.toString().split('.').last.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.secondary, fontWeight: FontWeight.bold)),
            onTap: () => _showLanguageSelector(context, l10n),
          ),
          _AccountMenuItem(
            icon: theme.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
            label: "Appearance",
            trailing: Switch.adaptive(
              value: theme.themeMode == ThemeMode.dark,
              onChanged: (v) => theme.toggleTheme(v),
              activeColor: AppColors.secondary,
            ),
          ),
          _AccountMenuItem(
            icon: Icons.security_outlined,
            label: "Privacy & Security",
            onTap: () {
              Navigator.pop(context);
              // Navigation to dedicated security page would go here
            },
          ),
          _AccountMenuItem(
            icon: Icons.help_outline_rounded,
            label: "Help & Support",
            onTap: () {},
          ),
          
          const Divider(height: 1),
          _AccountMenuItem(
            icon: Icons.logout_rounded,
            label: "Logout",
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

  Widget _buildCompactBillingSection(BuildContext context, ActiveSubscription? sub) {
    if (sub == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("BILLING", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
              if (sub.isTrial)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text("TRIAL", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: AppColors.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      sub.isExpired ? "Expired" : "Renews: ${_formatDate(sub.expiryDate)}",
                      style: TextStyle(fontSize: 11, color: sub.isExpired ? Colors.red : Colors.grey),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SubscriptionScreen()));
                },
                child: Text(sub.isExpired ? "RENEW" : "UPGRADE", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ),
            ],
          ),
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

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year}";
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[600]),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: color != null ? FontWeight.bold : FontWeight.normal))),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
