import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GACOM Color System
// ─────────────────────────────────────────────────────────────────────────────
class GacomColors {
  // ── Brand (same in both themes) ───────────────────────────────────────────
  static const deepOrange   = Color(0xFFE84B00);
  static const burnOrange   = Color(0xFFFF5A1F);
  static const darkOrange   = Color(0xFFB83800);
  static const glowOrange   = Color(0xFFFF7A3D);
  static const softOrange   = Color(0xFFFF6B35);

  // ── Dark palette ──────────────────────────────────────────────────────────
  static const obsidian     = Color(0xFF080808);
  static const darkVoid     = Color(0xFF0C0C0C);
  static const surfaceDark  = Color(0xFF111111);
  static const cardDark     = Color(0xFF161616);
  static const elevatedCard = Color(0xFF1C1C1C);
  static const border       = Color(0xFF242424);
  static const borderBright = Color(0xFF2E2E2E);
  static const borderOrange = Color(0x40E84B00);

  static const textPrimary   = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFF888888);
  static const textMuted     = Color(0xFF444444);

  // ── Light palette ─────────────────────────────────────────────────────────
  static const lightBg        = Color(0xFFF2F4F7);   // main scaffold
  static const lightSurface   = Color(0xFFFFFFFF);   // cards / sheet bg
  static const lightCard      = Color(0xFFFFFFFF);   // card interiors
  static const lightElevated  = Color(0xFFF7F8FA);   // slightly raised
  static const lightBorder    = Color(0xFFE2E5EA);   // dividers / strokes
  static const lightBorderBt  = Color(0xFFCDD2DA);   // stronger border
  static const lightTextPrim  = Color(0xFF0F1117);   // headings
  static const lightTextSec   = Color(0xFF4A5568);   // body
  static const lightTextMuted = Color(0xFF94A3B8);   // hints / labels

  // ── Semantic status (same both) ────────────────────────────────────────────
  static const success = Color(0xFF00D68F);
  static const error   = Color(0xFFFF3B3B);
  static const warning = Color(0xFFFFB020);
  static const info    = Color(0xFF0095FF);
  static const gold    = Color(0xFFFFD700);

  // ── Gradients ─────────────────────────────────────────────────────────────
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
    colors: [Color(0xFF1C1C1C), Color(0xFF111111)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static LinearGradient headerGradient = LinearGradient(
    colors: [darkOrange.withOpacity(0.35), obsidian],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SEMANTIC CONTEXT HELPERS
  // Use these everywhere instead of the raw dark constants.
  // They automatically return the right value for dark OR light mode.
  // ─────────────────────────────────────────────────────────────────────────

  /// Main scaffold/page background
  static Color bg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? obsidian : lightBg;
  }

  /// NavBar / bottom bar background
  static Color navBg(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? darkVoid : lightSurface;
  }

  /// Default surface (app bar, sheet background, panels)
  static Color surface(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? surfaceDark : lightSurface;
  }

  /// Card interior background
  static Color card(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? cardDark : lightCard;
  }

  /// Slightly elevated card / input fill
  static Color elevated(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? elevatedCard : lightElevated;
  }

  /// Divider / stroke / border colour
  static Color borderColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? border : lightBorder;
  }

  /// Strong border (selected state, focused input)
  static Color borderStrong(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? borderBright : lightBorderBt;
  }

  /// Primary text (headings, bold labels)
  static Color txtPrimary(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? textPrimary : lightTextPrim;
  }

  /// Secondary text (body copy)
  static Color txtSecondary(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? textSecondary : lightTextSec;
  }

  /// Muted / placeholder text
  static Color txtMuted(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? textMuted : lightTextMuted;
  }

  /// Icon default colour
  static Color icon(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? textSecondary : lightTextSec;
  }

  /// Input fill
  static Color inputFill(BuildContext context) => card(context);

  /// Subtle orange tint for selected items / badges
  static Color orangeTint(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? deepOrange.withOpacity(0.13)
        : deepOrange.withOpacity(0.08);
  }

  // Quick brightness check
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

// ─────────────────────────────────────────────────────────────────────────────
// DECORATION HELPERS  (context-aware)
// ─────────────────────────────────────────────────────────────────────────────
class GacomDecorations {
  static BoxDecoration glassCard(
    BuildContext context, {
    double radius = 20,
    Color? borderColor,
    List<BoxShadow>? shadows,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? GacomColors.card(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? GacomColors.borderColor(context),
          width: borderColor != null ? 1.2 : 0.7,
        ),
        boxShadow: shadows,
      );

  static BoxDecoration neonCard(BuildContext context, {double radius = 20}) =>
      BoxDecoration(
        color: GacomColors.card(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: GacomColors.borderOrange, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: GacomColors.deepOrange.withOpacity(0.08),
            blurRadius: 24,
          ),
        ],
      );

  static BoxDecoration heroCard({double radius = 24}) => BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: GacomColors.orangeGradient,
        boxShadow: [
          BoxShadow(
            color: GacomColors.deepOrange.withOpacity(0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// THEME DATA
// ─────────────────────────────────────────────────────────────────────────────
class GacomTheme {
  // ── DARK ──────────────────────────────────────────────────────────────────
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
      textTheme: GoogleFonts.rajdhaniTextTheme(const TextTheme(
        displayLarge:  TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: GacomColors.textPrimary, letterSpacing: -1),
        headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: GacomColors.textPrimary),
        headlineMedium:TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: GacomColors.textPrimary),
        titleLarge:    TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.textPrimary),
        titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GacomColors.textPrimary),
        bodyLarge:     TextStyle(fontSize: 15, color: GacomColors.textSecondary),
        bodyMedium:    TextStyle(fontSize: 13, color: GacomColors.textSecondary),
        bodySmall:     TextStyle(fontSize: 11, color: GacomColors.textMuted),
        labelLarge:    TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.textPrimary, letterSpacing: 1.2),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: GacomColors.obsidian,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: const IconThemeData(color: GacomColors.textPrimary),
        titleTextStyle: const TextStyle(
          fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800,
          color: GacomColors.textPrimary, letterSpacing: 2,
        ),
      ),
      cardTheme: CardThemeData(
        color: GacomColors.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GacomColors.border, width: 0.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GacomColors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GacomColors.cardDark,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.border, width: 0.7)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
        labelStyle: const TextStyle(color: GacomColors.textMuted),
        hintStyle: const TextStyle(color: GacomColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: GacomColors.deepOrange,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: GacomColors.textPrimary,
        unselectedLabelColor: GacomColors.textMuted,
        labelStyle: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1),
        unselectedLabelStyle: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(color: GacomColors.border, thickness: 0.7),
      iconTheme: const IconThemeData(color: GacomColors.textSecondary),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GacomColors.darkVoid,
        selectedItemColor: GacomColors.deepOrange,
        unselectedItemColor: GacomColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  // ── LIGHT ─────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: GacomColors.lightBg,
      colorScheme: ColorScheme.light(
        primary: GacomColors.deepOrange,
        secondary: GacomColors.burnOrange,
        surface: GacomColors.lightSurface,
        error: GacomColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: GacomColors.lightTextPrim,
        // Subtle orange tint for selected chips
        primaryContainer: GacomColors.deepOrange.withOpacity(0.08),
        onPrimaryContainer: GacomColors.deepOrange,
        surfaceContainerHighest: GacomColors.lightElevated,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(TextTheme(
        displayLarge:  const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: GacomColors.lightTextPrim, letterSpacing: -1),
        headlineLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: GacomColors.lightTextPrim),
        headlineMedium:const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: GacomColors.lightTextPrim),
        titleLarge:    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: GacomColors.lightTextPrim),
        titleMedium:   const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: GacomColors.lightTextPrim),
        bodyLarge:     const TextStyle(fontSize: 15, color: GacomColors.lightTextSec),
        bodyMedium:    const TextStyle(fontSize: 13, color: GacomColors.lightTextSec),
        bodySmall:     const TextStyle(fontSize: 11, color: GacomColors.lightTextMuted),
        labelLarge:    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GacomColors.lightTextPrim, letterSpacing: 1.2),
      )),
      appBarTheme: AppBarTheme(
        backgroundColor: GacomColors.lightSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: const IconThemeData(color: GacomColors.lightTextPrim),
        titleTextStyle: const TextStyle(
          fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.w800,
          color: GacomColors.lightTextPrim, letterSpacing: 2,
        ),
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x12000000),
        // Bottom border line for AppBar in light mode
        shape: const Border(bottom: BorderSide(color: GacomColors.lightBorder, width: 0.8)),
      ),
      cardTheme: CardThemeData(
        color: GacomColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: GacomColors.lightBorder, width: 0.8),
        ),
        shadowColor: const Color(0x10000000),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GacomColors.deepOrange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GacomColors.deepOrange,
          side: const BorderSide(color: GacomColors.deepOrange, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GacomColors.lightSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.lightBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.lightBorder, width: 0.8)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: GacomColors.error, width: 1.2)),
        labelStyle: const TextStyle(color: GacomColors.lightTextMuted),
        hintStyle: const TextStyle(color: GacomColors.lightTextMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: GacomColors.deepOrange,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: GacomColors.lightTextPrim,
        unselectedLabelColor: GacomColors.lightTextMuted,
        labelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 1),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w500, fontSize: 13),
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(GacomColors.deepOrange.withOpacity(0.06)),
      ),
      dividerTheme: const DividerThemeData(color: GacomColors.lightBorder, thickness: 0.8),
      iconTheme: const IconThemeData(color: GacomColors.lightTextSec),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GacomColors.lightSurface,
        selectedItemColor: GacomColors.deepOrange,
        unselectedItemColor: GacomColors.lightTextMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: GacomColors.lightTextSec,
        textColor: GacomColors.lightTextPrim,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? GacomColors.deepOrange : GacomColors.lightTextMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? GacomColors.deepOrange.withOpacity(0.3) : GacomColors.lightBorder),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? GacomColors.deepOrange : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: GacomColors.lightSurface,
        modalBackgroundColor: GacomColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: GacomColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.lightTextPrim),
        contentTextStyle: const TextStyle(color: GacomColors.lightTextSec, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GacomColors.lightTextPrim,
        contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GacomColors.deepOrange,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GacomColors.deepOrange,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}
