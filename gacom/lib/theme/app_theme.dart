import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GacomColors {
  static const Color primary = Color(0xFFE85D04);
  static const Color primaryDark = Color(0xFFD00000);
  static const Color primaryGlow = Color(0xFFFF6B35);
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceVariant = Color(0xFF1A1A1A);
  static const Color card = Color(0xFF161616);
  static const Color cardBorder = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9A9A9A);
  static const Color textMuted = Color(0xFF555555);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFD600);
  static const Color error = Color(0xFFFF1744);
  static const Color gold = Color(0xFFFFD700);
  static const Color online = Color(0xFF00E676);
  static const Color offline = Color(0xFF555555);
}

class AppTheme {
  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GacomColors.background,
      colorScheme: const ColorScheme.dark(
        primary: GacomColors.primary,
        secondary: GacomColors.primaryGlow,
        surface: GacomColors.surface,
        error: GacomColors.error,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: 2),
        displayMedium: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        headlineLarge: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.outfit(color: GacomColors.textPrimary, fontSize: 16),
        bodyMedium: GoogleFonts.outfit(color: GacomColors.textSecondary, fontSize: 14),
        labelLarge: GoogleFonts.rajdhani(color: GacomColors.primary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: GacomColors.background,
        elevation: 0,
        titleTextStyle: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardTheme(
        color: GacomColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GacomColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GacomColors.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.cardBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: GacomColors.primary, width: 2)),
        hintStyle: GoogleFonts.outfit(color: GacomColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GacomColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: GacomColors.cardBorder, thickness: 1),
    );
  }
}
