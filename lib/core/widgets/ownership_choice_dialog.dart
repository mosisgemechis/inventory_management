import 'package:flutter/material.dart';

import '../constants/colors.dart';

/// Interactive choice when an owner's account still has a shop to deal with.
class OwnershipChoiceDialog extends StatefulWidget {
  const OwnershipChoiceDialog({super.key, this.noMembers = false});

  final bool noMembers;

  @override
  State<OwnershipChoiceDialog> createState() => _OwnershipChoiceDialogState();
}

class _OwnershipChoiceDialogState extends State<OwnershipChoiceDialog> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget option({
      required IconData icon,
      required String title,
      required String subtitle,
      required String value,
      bool danger = false,
    }) {
      final active = _selected == value;
      final color = danger ? AppColors.danger : scheme.primary;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _selected = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color:
                    active ? color.withValues(alpha: 0.06) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? color : scheme.outlineVariant,
                  width: active ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color:
                                danger ? AppColors.danger : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    active
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: active ? color : scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.storefront_rounded,
                        size: 22, color: scheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This shop still needs an owner',
                            style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                        const SizedBox(height: 2),
                        Text('Choose what happens next',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.noMembers
                    ? 'Nobody else is in this shop yet. Add another admin, or delete '
                        'the shop and every account in it.'
                    : 'Other people use this shop, so your account cannot be removed '
                        'on its own. Hand the shop over to a member, add a new admin, '
                        'or delete the shop entirely.',
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (!widget.noMembers)
                option(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Transfer ownership',
                  subtitle: 'Choose a member to become the new owner',
                  value: 'transfer',
                ),
              option(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Add another admin',
                subtitle: 'Create an admin in this shop, then hand it over',
                value: 'add',
              ),
              option(
                icon: Icons.delete_forever_rounded,
                title: 'Delete whole shop',
                subtitle: 'Remove the shop and every member account',
                value: 'shop',
                danger: true,
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected == null
                      ? null
                      : () => Navigator.pop(context, _selected),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _selected == 'shop' ? AppColors.danger : null,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _selected == 'shop' ? 'Delete shop' : 'Continue',
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, 'keep'),
                  child: const Text('Keep my account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
