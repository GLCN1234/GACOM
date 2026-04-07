import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class GacomColors {
  // Primary Brand — Electric Orange
  static const deepOrange = Color(0xFFE84B00);
  static const burnOrange = Color(0xFFFF5A1F);
  static const darkOrange = Color(0xFFB83800);
  static const glowOrange = Color(0xFFFF7A3D);
  static const neonOrange = Color(0xFFFF6B1A);

  // Backgrounds — True Black layers
  static const obsidian = Color(0xFF080808);
  static const darkVoid = Color(0xFF0C0C0C);
  static const surfaceDark = Color(0xFF111111);
  static const cardDark = Color(0xFF161616);
  static const elevatedCard = Color(0xFF1C1C1C);
  static const glassCard = Color(0xFF1A1A1A);

  // Borders
  static const border = Color(0xFF242424);
  static const borderBright = Color(0xFF303030);
  static const borderOrange = Color(0x33E84B00);

  // Text
  static const textPrimary = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF484848);
  static const textOrange = Color(0xFFE84B00);

  // Status
  static const success = Color(0xFF00C97A);
  static const error = Color(0xFFFF3B3B);
  static const warning = Color(0xFFFFB020);
  static const info = Color(0xFF007AFF);

  // Special FX
  static const scanline = Color(0x08FFFFFF);
  static const glowLayer = Color(0x1AE84B00);
  static const glassWhite = Color(0x0DFFFFFF);
  static const glassBorder = Color(0x1AFFFFFF);

  // Gradients
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFE84B00), Color(0xFFFF6B1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient orangeVertical = LinearGradient(
    colors: [Color(0xFFFF5A1F), Color(0xFFB83800)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF080808), Color(0xFF111111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1C1C1C), Color(0xFF131313)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glowGradient = LinearGradient(
    colors: [Color(0x26E84B00), Color(0x00E84B00)],
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
          displayLarge: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: -1.5),
          displayMedium: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: 0.5),
          headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: GacomColors.textPrimary),
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: GacomColors.textPrimary),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: 0.3),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GacomColors.textPrimary, letterSpacing: 0.15),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GacomColors.textPrimary, letterSpacing: 0.5),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: GacomColors.textSecondary, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: GacomColors.textSecondary, height: 1.5),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: GacomColors.textMuted),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: 1.5),
          labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GacomColors.textMuted, letterSpacing: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GacomColors.obsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        iconTheme: IconThemeData(color: GacomColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GacomColors.deepOrange,
          side: const BorderSide(color: GacomColors.deepOrange, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GacomColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.border, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.border, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GacomColors.error, width: 1.5),
        ),
        labelStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 14),
        hintStyle: const TextStyle(color: GacomColors.textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: GacomColors.deepOrange,
        unselectedItemColor: GacomColors.textMuted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: GacomColors.border, thickness: 0.5),
      iconTheme: const IconThemeData(color: GacomColors.textSecondary, size: 22),
      tabBarTheme: TabBarThemeData(
        indicatorColor: GacomColors.deepOrange,
        labelColor: GacomColors.textPrimary,
        unselectedLabelColor: GacomColors.textMuted,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 1),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 1),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: GacomColors.cardDark,
        selectedColor: GacomColors.deepOrange.withOpacity(0.2),
        labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 12, color: GacomColors.textPrimary),
        side: const BorderSide(color: GacomColors.border, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

// ─── Reusable Decoration Helpers ────────────────────────────────────────────

class GacomDecorations {
  static BoxDecoration glassCard({
    double radius = 20,
    Color? borderColor,
    double borderWidth = 0.8,
    List<BoxShadow>? shadows,
  }) =>
      BoxDecoration(
        color: GacomColors.glassCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? GacomColors.border,
          width: borderWidth,
        ),
        boxShadow: shadows,
      );

  static BoxDecoration orangeGlow({double radius = 20, double opacity = 0.3}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: GacomColors.deepOrange.withOpacity(opacity),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: GacomColors.orangeGradient,
      );

  static BoxDecoration orangeBorder({double radius = 20}) => BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: GacomColors.borderOrange, width: 1),
        boxShadow: [
          BoxShadow(
            color: GacomColors.deepOrange.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      );
}
