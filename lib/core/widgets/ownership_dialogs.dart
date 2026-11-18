import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Styled picker for choosing the new shop owner.
class MemberPickerDialog extends StatefulWidget {
  const MemberPickerDialog({super.key, required this.members});

  final List<Map<String, dynamic>> members;

  @override
  State<MemberPickerDialog> createState() => _MemberPickerDialogState();
}

class _MemberPickerDialogState extends State<MemberPickerDialog> {
  String? _selected;

  String _initials(Map<String, dynamic> m) {
    final source = (m['name'] ?? m['username'] ?? '?').toString().trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
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
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose the new owner',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
              const SizedBox(height: 4),
              Text('They will manage this shop after your account is removed.',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.members.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final member = widget.members[index];
                    final id = member['id']?.toString() ?? '';
                    final selected = _selected == id;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selected = id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: selected ? 1.6 : 1,
                          ),
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.06)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  scheme.primary.withValues(alpha: 0.12),
                              child: Text(_initials(member),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: scheme.primary)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (member['name'] ?? '').toString().isEmpty
                                        ? '@${member['username']}'
                                        : member['name'].toString(),
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('@${member['username']}',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.10),
                              ),
                              child: Text(
                                (member['role'] ?? 'staff').toString(),
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              selected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 18,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const Spacer(),
                  FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.pop(context, _selected),
                    child: const Text('Make owner'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates another admin in the same shop.
class CreateAdminDialog extends StatefulWidget {
  const CreateAdminDialog({super.key});

  @override
  State<CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<CreateAdminDialog> {
  final _nameC = TextEditingController();
  final _usernameC = TextEditingController();
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmC = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nameC.dispose();
    _usernameC.dispose();
    _emailC.dispose();
    _passwordC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameC.text.trim().isEmpty ||
        _usernameC.text.trim().length < 3 ||
        !_emailC.text.contains('@')) {
      setState(() => _error = 'Fill in a name, username and valid email.');
      return;
    }
    final password = _passwordC.text;
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
      await AuthService().createAdminAccount(
        name: _nameC.text.trim(),
        username: _usernameC.text.trim(),
        email: _emailC.text.trim(),
        password: password,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = e.toString().replaceFirst('Exception: ', '').trim());
      }
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
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add another admin',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
              const SizedBox(height: 4),
              Text('They join this shop as an admin and can take ownership.',
                  style: TextStyle(
                      fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              _field(_nameC, 'Full name'),
              const SizedBox(height: 10),
              _field(_usernameC, 'Username'),
              const SizedBox(height: 10),
              _field(_emailC, 'Email'),
              const SizedBox(height: 10),
              _field(_passwordC, 'Password', obscure: true),
              const SizedBox(height: 10),
              _field(_confirmC, 'Confirm password', obscure: true),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: TextStyle(fontSize: 12, color: scheme.error)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  const Spacer(),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Creating…' : 'Create admin'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool obscure = false}) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(fontSize: 13.5, color: scheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// Shared destructive confirmation card.
class ConfirmDeleteDialog extends StatefulWidget {
  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    required this.message,
    required this.consequences,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final List<String> consequences;
  final String confirmLabel;

  @override
  State<ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<ConfirmDeleteDialog> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444), size: 22),
              ),
              const SizedBox(height: 14),
              Text(widget.title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
              const SizedBox(height: 6),
              Text(widget.message,
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              for (final line in widget.consequences)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.remove_circle_outline_rounded,
                          size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(line,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: scheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text('Are you sure you want to continue?',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(widget.confirmLabel,
                      style: const TextStyle(fontSize: 13.5)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
