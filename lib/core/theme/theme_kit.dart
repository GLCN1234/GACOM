import 'package:flutter/material.dart';

/// One reskin of the collect-and-fill mechanic. Values come straight
/// from the Claude Design theme kit spec sheet — exact hex, no eyeballing.
/// Only 4 of the 15 world themes have a designed kit so far; anything
/// else falls back to GacomColors so it never looks broken, just plain.
class ThemeKit {
  final String worldTheme;
  final Color background, primary, secondary, accent;
  final IconData collectibleIcon;
  final String collectibleLabel;

  const ThemeKit({
    required this.worldTheme, required this.background, required this.primary,
    required this.secondary, required this.accent,
    required this.collectibleIcon, required this.collectibleLabel,
  });

  static const fallback = ThemeKit(
    worldTheme: 'Adventure', background: Color(0xFF1A1A22),
    primary: Color(0xFFFF6A00), secondary: Color(0xFF00E5FF), accent: Color(0xFFFF8A33),
    collectibleIcon: Icons.star_rounded, collectibleLabel: 'star',
  );
}

const Map<String, ThemeKit> gacomThemeKits = {
  'Pizza Shop Adventure': ThemeKit(worldTheme: 'Pizza Shop Adventure',
    background: Color(0xFF241209), primary: Color(0xFFE15241),
    secondary: Color(0xFFF4B942), accent: Color(0xFFC97B3D),
    collectibleIcon: Icons.local_pizza_rounded, collectibleLabel: 'pizza topping'),
  'Dragon Kingdom': ThemeKit(worldTheme: 'Dragon Kingdom',
    background: Color(0xFF1A1025), primary: Color(0xFF8C52C2),
    secondary: Color(0xFFD4AF37), accent: Color(0xFF3D2159),
    collectibleIcon: Icons.egg_rounded, collectibleLabel: 'dragon egg'),
  'Space Mission': ThemeKit(worldTheme: 'Space Mission',
    background: Color(0xFF0B1B2E), primary: Color(0xFF1B4F72),
    secondary: Color(0xFF3FC1D6), accent: Color(0xFFE8F1F5),
    collectibleIcon: Icons.star_rounded, collectibleLabel: 'fuel star'),
  'Treasure Hunt': ThemeKit(worldTheme: 'Treasure Hunt',
    background: Color(0xFF1F2A1F), primary: Color(0xFFC9974F),
    secondary: Color(0xFF2A9D8F), accent: Color(0xFF8B5E34),
    collectibleIcon: Icons.monetization_on_rounded, collectibleLabel: 'gold coin'),
};

ThemeKit themeKitFor(String worldTheme) => gacomThemeKits[worldTheme] ?? ThemeKit.fallback;
