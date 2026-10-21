import 'package:flutter/material.dart';
import '../realm_kits.dart';

/// The look of the pitch, the kit and the ball. Cosmetic only.
class PitchSkin {
  final Color accent;
  final Color grass;
  final Color grassAlt;
  final Color kit;
  final Color kitTrim;
  final Color ball;
  final Color keeper;

  /// classic | stripes | sash
  final String pattern;

  const PitchSkin({
    this.accent = const Color(0xFF7CFFA0),
    this.grass = const Color(0xFF1B5E20),
    this.grassAlt = const Color(0xFF225E26),
    this.kit = const Color(0xFF00897B),
    this.kitTrim = const Color(0xFFFFFFFF),
    this.ball = const Color(0xFFFFFFFF),
    this.keeper = const Color(0xFFFFB300),
    this.pattern = 'classic',
  });

  static const PitchSkin standard = PitchSkin();

  static PitchSkin equipped() => GameKit.skin<PitchSkin>(
        GameKit.pitch,
        (Map<String, dynamic> a) => PitchSkin(
          accent: GameKit.color(a, 'accent', standard.accent),
          grass: GameKit.color(a, 'grass', standard.grass),
          grassAlt: GameKit.color(a, 'grass_alt', standard.grassAlt),
          kit: GameKit.color(a, 'kit', standard.kit),
          kitTrim: GameKit.color(a, 'kit_trim', standard.kitTrim),
          ball: GameKit.color(a, 'ball', standard.ball),
          keeper: GameKit.color(a, 'keeper', standard.keeper),
          pattern: GameKit.word(a, 'pattern', standard.pattern),
        ),
        standard,
      );
}
