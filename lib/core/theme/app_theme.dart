import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GacomColors {
  // Primary Brand
  static const deepOrange = Color(0xFFE84B00);
  static const burnOrange = Color(0xFFFF5A1F);
  static const darkOrange = Color(0xFFB83800);
  static const glowOrange = Color(0xFFFF7A3D);

  // Backgrounds
  static const obsidian = Color(0xFF090909);
  static const darkVoid = Color(0xFF0D0D0D);
  static const surfaceDark = Color(0xFF141414);
  static const cardDark = Color(0xFF1A1A1A);
  static const elevatedCard = Color(0xFF1F1F1F);
  static const border = Color(0xFF2A2A2A);
  static const borderBright = Color(0xFF333333);

  // Text
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF9A9A9A);
  static const textMuted = Color(0xFF5A5A5A);

  // Status
  static const success = Color(0xFF00D68F);
  static const error = Color(0xFFFF3B3B);
  static const warning = Color(0xFFFFB020);
  static const info = Color(0xFF0095FF);

  // Gradients
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
    colors: [Color(0xFF1A1A1A), Color(0xFF141414)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
          displayLarge: TextStyle(
            fontSize: 57,
            fontWeight: FontWeight.w700,
            color: GacomColors.textPrimary,
            letterSpacing: -1.5,
          ),
          displayMedium: TextStyle(
            fontSize: 45,
            fontWeight: FontWeight.w700,
            color: GacomColors.textPrimary,
            letterSpacing: -0.5,
          ),
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: GacomColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: GacomColors.textPrimary,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: GacomColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: GacomColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: GacomColors.textPrimary,
            letterSpacing: 0.15,
          ),
          titleSmall: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: GacomColors.textPrimary,
            letterSpacing: 0.1,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: GacomColors.textSecondary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: GacomColors.textSecondary,
          ),
          bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: GacomColors.textMuted,
          ),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: GacomColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GacomColors.obsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: GacomColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: GacomColors.textPrimary,
          letterSpacing: 1,
        ),
      ),
      cardTheme: CardThemeData(
        color: GacomColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GacomColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GacomColors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
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
          borderSide: const BorderSide(color: GacomColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.deepOrange, width: 2),
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
      dividerTheme: const DividerThemeData(
        color: GacomColors.border,
        thickness: 1,
      ),
      iconTheme: const IconThemeData(
        color: GacomColors.textSecondary,
      ),
    );
  }
}
