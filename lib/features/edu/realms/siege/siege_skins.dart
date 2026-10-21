import 'package:flutter/material.dart';
import '../realm_kits.dart';

/// How the gate and the marchers look. Cosmetic only.
class SiegeSkin {
  final Color accent;
  final Color ground;
  final Color wall;
  final Color banner;
  final Color marcher;
  final Color marcherTrim;

  /// stone | brass | ember
  final String style;

  const SiegeSkin({
    this.accent = const Color(0xFFFFCA28),
    this.ground = const Color(0xFF1A1711),
    this.wall = const Color(0xFF5D4037),
    this.banner = const Color(0xFF8E24AA),
    this.marcher = const Color(0xFF78909C),
    this.marcherTrim = const Color(0xFFCFD8DC),
    this.style = 'stone',
  });

  static const SiegeSkin standard = SiegeSkin();

  static SiegeSkin equipped() => GameKit.skin<SiegeSkin>(
        GameKit.siege,
        (Map<String, dynamic> a) => SiegeSkin(
          accent: GameKit.color(a, 'accent', standard.accent),
          ground: GameKit.color(a, 'ground', standard.ground),
          wall: GameKit.color(a, 'wall', standard.wall),
          banner: GameKit.color(a, 'banner', standard.banner),
          marcher: GameKit.color(a, 'marcher', standard.marcher),
          marcherTrim: GameKit.color(a, 'marcher_trim', standard.marcherTrim),
          style: GameKit.word(a, 'style', standard.style),
        ),
        standard,
      );
}
