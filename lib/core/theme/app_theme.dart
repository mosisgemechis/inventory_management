import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SafeScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class AppTheme {
  /// Auth-matching constants for const contexts (e.g. const TextStyle, BoxDecoration).
  // Dark mode
  static const Color darkScaffold = Color(0xFF0A0E14);
  static const Color darkSecondary = Color(0xFF3B82F6);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1F2937);
  static const Color darkField = Color(0xFF0D1A2D);
  static const Color darkFieldBorder = Color(0xFF1E3352);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9FB0C7);
  static const Color darkTextMuted = Color(0xFF6B7C95);
  static const Color darkBorder = Color(0xFF1F2937);
  static const Color darkButtonStart = Color(0xFF2563EB);
  static const Color darkButtonEnd = Color(0xFF3B82F6);
  static const Color darkButtonText = Color(0xFFFFFFFF);
  static const Color darkButtonShadow = Color(0x663B82F6);
  static const Color darkDanger = Color(0xFFF87171);
  static const Color darkSuccess = Color(0xFF34D399);
  static const Color darkWarning = Color(0xFFD97706);

  // Light mode
  static const Color lightScaffold = Color(0xFFF6F9FE);
  static const Color lightSecondary = Color(0xFF2563EB);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightField = Color(0xFFF8FAFE);
  static const Color lightFieldBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightButtonStart = Color(0xFF0B1B34);
  static const Color lightButtonEnd = Color(0xFF17304F);
  static const Color lightButtonText = Color(0xFFFFFFFF);
  static const Color lightButtonShadow = Color(0x33122A4A);
  static const Color lightDanger = Color(0xFFDC2626);
  static const Color lightSuccess = Color(0xFF059669);
  static const Color lightWarning = Color(0xFFD97706);

  static final ThemeData darkTheme = _buildDarkTheme();

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffold,
      colorScheme: ColorScheme.dark(
        primary: darkSecondary,
        secondary: darkSecondary,
        surface: darkSurface,
        error: darkDanger,
        onSurface: darkTextPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkTextPrimary, letterSpacing: -1),
        displayMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: darkTextPrimary, letterSpacing: -0.5),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: darkTextPrimary),
        labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: darkTextPrimary),
        bodyLarge: const TextStyle(fontSize: 16, color: darkTextPrimary),
        bodyMedium: const TextStyle(fontSize: 14, color: darkTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkButtonStart,
          foregroundColor: darkButtonText,
          minimumSize: const Size(88, 54),
          elevation: 0,
          shadowColor: darkButtonShadow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkCard.withOpacity(0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: darkBorder, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkField.withOpacity(0.9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkFieldBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkFieldBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: darkSecondary, width: 1.5)),
        labelStyle: const TextStyle(color: darkTextSecondary),
        hintStyle: const TextStyle(color: darkTextMuted),
      ),
    );
  }

  static final ThemeData lightTheme = _buildLightTheme();

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffold,
      colorScheme: ColorScheme.light(
        primary: lightSecondary,
        secondary: lightSecondary,
        surface: lightSurface,
        error: lightDanger,
        onSurface: lightTextPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme).copyWith(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: lightTextPrimary, letterSpacing: -1),
        displayMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: lightTextPrimary, letterSpacing: -0.5),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: const TextStyle(fontSize: 16, color: lightTextPrimary),
        bodyMedium: const TextStyle(fontSize: 14, color: lightTextSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightButtonStart,
          foregroundColor: lightButtonText,
          minimumSize: const Size(88, 54),
          elevation: 0,
          shadowColor: lightButtonShadow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: lightBorder, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightField,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightFieldBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightFieldBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lightSecondary, width: 1.5)),
      ),
    );
  }
}
