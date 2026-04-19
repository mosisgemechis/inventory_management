import 'package:flutter/material.dart';

class AppColors {
  // SaaS Design System 2026
  static const Color primary = Color(0xFF0F172A); // Deep Navy
  static const Color secondary = Color(0xFF3B82F6); // Blue Accent
  static const Color success = Color(0xFF22C55E); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Red
  static const Color background = Color(0xFFF8FAFC); // Clean Light
  static const Color surface = Colors.white;
  
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  static const LinearGradient premiumGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
