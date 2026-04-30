import 'package:flutter/material.dart';

class AppColors {
  // Premium Design Identity
  static const Color primary = Color(0xFF0A0E14); // Deep Midnight
  static const Color secondary = Color(0xFF3B82F6); // Neon Blue Glow
  static const Color background = Color(0xFF0A0E14); // Ultra Dark
  static const Color surface = Color(0xFF111827); // Deep Slate
  static const Color card = Color(0xFF1F2937);
  
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  
  static const Color border = Color(0xFF1F2937);
  static const Color glassBorder = Color(0x1AFFFFFF);

  static const LinearGradient loginGradient = LinearGradient(
    colors: [Color(0xFF0A0E14), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxDecoration glassDecoration = BoxDecoration(
    color: Colors.white.withOpacity(0.04),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: glassBorder, width: 0.5),
  );
}
