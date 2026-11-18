import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../services/auth_service.dart';
import 'ownership_dialogs.dart';
import 'ownership_choice_dialog.dart';

/// Delete account: verify identity, confirm, then deactivate.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.passwordConfigured,
    required this.googleConnected,
  });

  final bool passwordConfigured;
  final bool googleConnected;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordC = TextEditingController();

  bool _busy = false;
  bool _verified = false;
  String? _error;
  String? _deletionToken;

  @override
  void dispose() {
    _passwordC.dispose();
    super.dispose();
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();

  Future<void> _verifyWithGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idToken = await AuthService().freshGoogleIdToken();
      final token =
          await AuthService().verifyAccountDeletion(googleIdToken: idToken);
      if (!mounted) return;
      setState(() {
        _deletionToken = token;
        _verified = true;
      });
      await _confirmAndDelete();
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyWithPassword() async {
    if (_passwordC.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token =
          await AuthService().verifyAccountDeletion(password: _passwordC.text);
      if (!mounted) return;
      setState(() {
        _deletionToken = token;
        _verified = true;
      });
      await _confirmAndDelete();
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const ConfirmDeleteDialog(
        title: 'Delete your account',
        message:
            'Your sign-in account will be permanently deactivated. You will not '
            'be able to sign in again with Google or your password.',
        consequences: [
          'Your shop records stay with the business',
          'Any changes that have not synced will not be uploaded',
          'If you own the business, you will be asked to hand it over first',
        ],
        confirmLabel: 'Delete my account',
      ),
    );
    if (confirmed != true || !mounted) return;
    await _delete();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthService().deleteAccount(
        deletionToken: _deletionToken ?? '',
        confirmation: 'DELETE',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      final message = _clean(e);
      if (mounted) setState(() => _error = message);
      if (message.toLowerCase().contains('transfer ownership')) {
        await _showOwnershipChoice();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Owner with other members: hand over the shop, add an admin, or delete it.
  Future<void> _showOwnershipChoice() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => const OwnershipChoiceDialog(),
    );
    if (!mounted || choice == null) return;

    if (choice == 'keep') return;

    if (choice == 'shop') {
      await _deleteShopNow();
      return;
    }

    if (choice == 'add') {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => const CreateAdminDialog(),
      );
      if (created != true || !mounted) return;
      await _chooseOwner();
      return;
    }

    await _chooseOwner();
  }

  Future<void> _chooseOwner() async {
    List<Map<String, dynamic>> members;
    try {
      members = await AuthService().businessMembers();
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
      return;
    }
    if (!mounted) return;

    if (members.isEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (_) => const OwnershipChoiceDialog(noMembers: true),
      );
      if (!mounted || action == null || action == 'keep') return;
      if (action == 'shop') {
        await _deleteShopNow();
        return;
      }
      if (action == 'add') {
        final created = await showDialog<bool>(
          context: context,
          builder: (_) => const CreateAdminDialog(),
        );
        if (created == true && mounted) await _chooseOwner();
      }
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (_) => MemberPickerDialog(members: members),
    );
    if (selected == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await AuthService().transferOwnership(selected);
      await _delete();
    } catch (e) {
      if (mounted) setState(() => _error = _clean(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteShopNow() async {
    setState(() => _busy = true);
    try {
      await AuthService().deleteBusiness(deletionToken: _deletionToken ?? '');
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_remove_rounded,
                        color: AppColors.danger, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Delete account',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                        const SizedBox(height: 2),
                        Text('Step 1 of 2 · confirm it is you',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                      ],
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
              const SizedBox(height: 16),
              Text(
                'Deleting your account signs you out everywhere and blocks future '
                'sign-in. Your shop data is not erased.',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              if (widget.googleConnected)
                _googleTile(scheme),
              if (widget.googleConnected && widget.passwordConfigured)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                    ],
                  ),
                ),
              if (widget.passwordConfigured) _passwordBlock(scheme),
              if (!widget.googleConnected && !widget.passwordConfigured)
                Text('No verification method is available for this account.',
                    style: TextStyle(fontSize: 12.5, color: scheme.error)),
              if (_error != null) ...[
                const SizedBox(height: 14),
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

  Widget _googleTile(ColorScheme scheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busy ? null : _verifyWithGoogle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Continue with Google',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text('Use the Google account linked to this shop',
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordBlock(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your password',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordC,
          obscureText: true,
          style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Enter your GM Inventory Everywhere password',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _busy ? null : _verifyWithPassword(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy ? null : _verifyWithPassword,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_busy ? 'Checking…' : 'Verify with password',
                style: const TextStyle(fontSize: 13.5)),
          ),
        ),
        if (_verified) const SizedBox.shrink(),
      ],
    );
  }
}

/// Card-style choice when the owner still has a shop to deal with.
