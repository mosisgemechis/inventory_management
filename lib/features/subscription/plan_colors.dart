import 'package:flutter/material.dart';

/// Palette for the Plans & Billing flow, resolved from the active theme.
@immutable
class PlanColors {
  const PlanColors({
    required this.navy,
    required this.accent,
    required this.border,
    required this.surface,
    required this.heading,
    required this.muted,
    required this.page,
    required this.subtle,
    required this.button,
    required this.onButton,
    required this.onAccent,
  });

  final Color navy;
  final Color accent;
  final Color border;
  final Color surface;
  final Color heading;
  final Color muted;
  final Color page;
  final Color subtle;
  final Color button;
  final Color onButton;
  final Color onAccent;

  static PlanColors of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (theme.brightness == Brightness.dark) {
      return PlanColors(
        navy: scheme.onSurface,
        accent: scheme.primary,
        border: scheme.outlineVariant,
        surface: scheme.surfaceContainerHigh,
        heading: scheme.onSurface,
        muted: scheme.onSurfaceVariant,
        page: scheme.surface,
        subtle: scheme.surfaceContainerHighest,
        button: scheme.primary,
        onButton: scheme.onPrimary,
        onAccent: scheme.onPrimary,
      );
    }
    return const PlanColors(
      navy: Color(0xFF0F172A),
      accent: Color(0xFF2563EB),
      border: Color(0xFFE2E8F0),
      surface: Color(0xFFFFFFFF),
      heading: Color(0xFF1E293B),
      muted: Color(0xFF64748B),
      page: Color(0xFFF8FAFC),
      subtle: Color(0xFFF8FAFC),
      button: Color(0xFF0F172A),
      onButton: Color(0xFFFFFFFF),
      onAccent: Color(0xFFFFFFFF),
    );
  }
}
