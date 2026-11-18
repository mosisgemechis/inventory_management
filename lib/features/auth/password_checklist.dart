import 'package:flutter/material.dart';

/// Live password checklist, styled like the sign-up screen's requirement chips.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.controller,
    required this.activeColor,
    required this.idleColor,
    required this.textColor,
    required this.activeBackground,
    required this.idleBorder,
  });

  final TextEditingController controller;
  final Color activeColor;
  final Color idleColor;
  final Color textColor;
  final Color activeBackground;
  final Color idleBorder;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.text;
        final items = <(String, bool)>[
          ('8+ characters', value.length >= 8),
          ('Uppercase letter', RegExp(r'[A-Z]').hasMatch(value)),
          ('Number', RegExp(r'[0-9]').hasMatch(value)),
          ('Symbol', RegExp(r'[^A-Za-z0-9]').hasMatch(value)),
        ];

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            final met = item.$2;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: met ? activeBackground : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: met ? activeColor : idleBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    met ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 13,
                    color: met ? activeColor : idleColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                      color: met ? textColor : idleColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
