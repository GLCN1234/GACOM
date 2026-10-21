import 'package:flutter/material.dart';
import '../realm_kits.dart';

/// The look of the river, the swimmer and the word tiles. Cosmetic only.
class CurrentSkin {
  final Color accent;
  final Color water;
  final Color deep;
  final Color bank;
  final Color tile;
  final Color swimmer;

  /// ripple | foam | lily
  final String surface;

  const CurrentSkin({
    this.accent = const Color(0xFF4FC3F7),
    this.water = const Color(0xFF0C3A4A),
    this.deep = const Color(0xFF06212B),
    this.bank = const Color(0xFF2E4A1F),
    this.tile = const Color(0xFF123B52),
    this.swimmer = const Color(0xFFFFD166),
    this.surface = 'ripple',
  });

  static const CurrentSkin standard = CurrentSkin();

  static CurrentSkin equipped() => GameKit.skin<CurrentSkin>(
        GameKit.current,
        (Map<String, dynamic> a) => CurrentSkin(
          accent: GameKit.color(a, 'accent', standard.accent),
          water: GameKit.color(a, 'water', standard.water),
          deep: GameKit.color(a, 'deep', standard.deep),
          bank: GameKit.color(a, 'bank', standard.bank),
          tile: GameKit.color(a, 'tile', standard.tile),
          swimmer: GameKit.color(a, 'swimmer', standard.swimmer),
          surface: GameKit.word(a, 'surface', standard.surface),
        ),
        standard,
      );
}
