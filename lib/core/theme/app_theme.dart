import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GacomColors {
  // ── Core Brand ──────────────────────────────────────────────────────────────
  static const deepOrange = Color(0xFFE84B00);
  static const burnOrange = Color(0xFFFF5A1F);
  static const darkOrange = Color(0xFFB83800);
  static const glowOrange = Color(0xFFFF7A3D);

  // ── Backgrounds ─────────────────────────────────────────────────────────────
  static const obsidian = Color(0xFF080808);
  static const darkVoid = Color(0xFF0C0C0C);
  static const surfaceDark = Color(0xFF111111);
  static const cardDark = Color(0xFF181818);
  static const elevatedCard = Color(0xFF1E1E1E);

  // ── Borders ─────────────────────────────────────────────────────────────────
  static const border = Color(0xFF222222);
  static const borderBright = Color(0xFF2E2E2E);
  static const borderOrange = Color(0x40E84B00); // deepOrange @ 25% opacity

  // ── Text ────────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF2F2F2);
  static const textSecondary = Color(0xFF8A8A8A);
  static const textMuted = Color(0xFF484848);

  // ── Status ──────────────────────────────────────────────────────────────────
  static const success = Color(0xFF00D68F);
  static const error = Color(0xFFFF3B3B);
  static const warning = Color(0xFFFFB020);
  static const info = Color(0xFF0095FF);

  // ── Gradients ───────────────────────────────────────────────────────────────
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [deepOrange, burnOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [obsidian, surfaceDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF111111)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient glowGradient = LinearGradient(
    colors: [deepOrange.withOpacity(0.15), Colors.transparent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Glass card decoration — replaces the missing GacomDecorations.glassCard()
class GacomDecorations {
  static BoxDecoration glassCard({
    double radius = 20,
    Color? borderColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: GacomColors.cardDark,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? GacomColors.border,
        width: borderColor != null ? 1.2 : 0.8,
      ),
      boxShadow: shadows,
    );
  }

  static BoxDecoration neonCard({double radius = 20}) {
    return BoxDecoration(
      color: GacomColors.cardDark,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: GacomColors.borderOrange, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: GacomColors.deepOrange.withOpacity(0.08),
          blurRadius: 24,
          spreadRadius: 0,
        ),
      ],
    );
  }
}

class GacomTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GacomColors.obsidian,
      colorScheme: const ColorScheme.dark(
        primary: GacomColors.deepOrange,
        secondary: GacomColors.burnOrange,
        surface: GacomColors.surfaceDark,
        error: GacomColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: GacomColors.textPrimary,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: -1.5),
          displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: GacomColors.textPrimary),
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: GacomColors.textPrimary),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: GacomColors.textPrimary),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: GacomColors.textPrimary),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GacomColors.textPrimary, letterSpacing: 0.15),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GacomColors.textPrimary, letterSpacing: 0.1),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: GacomColors.textSecondary),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: GacomColors.textSecondary),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: GacomColors.textMuted),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GacomColors.textPrimary, letterSpacing: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GacomColors.obsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: GacomColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: GacomColors.textPrimary,
          letterSpacing: 2,
        ),
      ),
      cardTheme: CardThemeData(
        color: GacomColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GacomColors.border, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GacomColors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GacomColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5),
        ),
        labelStyle: const TextStyle(color: GacomColors.textMuted),
        hintStyle: const TextStyle(color: GacomColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GacomColors.darkVoid,
        selectedItemColor: GacomColors.deepOrange,
        unselectedItemColor: GacomColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: GacomColors.border, thickness: 0.8),
      iconTheme: const IconThemeData(color: GacomColors.textSecondary),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: GacomColors.deepOrange,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: GacomColors.textPrimary,
        unselectedLabelColor: GacomColors.textMuted,
        labelStyle: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1),
        unselectedLabelStyle: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
