import 'package:flutter/material.dart';
import '../realm_kits.dart';

/// The look of the market: ground, stall canopies and your own counter.
/// Cosmetic only.
class MarketSkin {
  final Color accent;
  final Color ground;
  final Color groundAlt;
  final Color canopy;
  final Color canopyAlt;
  final Color counter;

  /// stripe | plain | ankara
  final String cloth;

  const MarketSkin({
    this.accent = const Color(0xFFFFD166),
    this.ground = const Color(0xFF2A2119),
    this.groundAlt = const Color(0xFF332A20),
    this.canopy = const Color(0xFFEF6C00),
    this.canopyAlt = const Color(0xFFFFF3E0),
    this.counter = const Color(0xFF00695C),
    this.cloth = 'stripe',
  });

  static const MarketSkin standard = MarketSkin();

  static MarketSkin equipped() => GameKit.skin<MarketSkin>(
        GameKit.market,
        (Map<String, dynamic> a) => MarketSkin(
          accent: GameKit.color(a, 'accent', standard.accent),
          ground: GameKit.color(a, 'ground', standard.ground),
          groundAlt: GameKit.color(a, 'ground_alt', standard.groundAlt),
          canopy: GameKit.color(a, 'canopy', standard.canopy),
          canopyAlt: GameKit.color(a, 'canopy_alt', standard.canopyAlt),
          counter: GameKit.color(a, 'counter', standard.counter),
          cloth: GameKit.word(a, 'cloth', standard.cloth),
        ),
        standard,
      );
}
