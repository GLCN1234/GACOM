import 'package:flutter/material.dart';
import 'colors.dart';

/// Layered shadow presets. "soft" = wide ambient ("floating"), "tight" =
/// close-edge definition. Real glass surfaces use both together (see
/// GlassCard) rather than a single flat shadow.
class GShadows {
  static List<BoxShadow> get soft => [
    BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 28, offset: const Offset(0, 12)),
  ];

  static List<BoxShadow> get tight => [
    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> get glass => [...soft, ...tight];

  static List<BoxShadow> glow(Color color, {double blur = 32}) => [
    BoxShadow(color: color.withOpacity(0.22), blurRadius: blur, spreadRadius: -4),
  ];

  static List<BoxShadow> get accentGlow => glow(GColors.primary);
}
