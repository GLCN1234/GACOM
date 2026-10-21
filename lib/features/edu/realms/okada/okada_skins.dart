import 'package:flutter/material.dart';
import '../realm_kits.dart';

/// What the bike and the road look like. Everything here is cosmetic: a skin
/// bought in the shop changes colours and the exhaust, never the handling.
class OkadaSkin {
  final Color accent;
  final Color road;
  final Color kerb;
  final Color bike;
  final Color helmet;
  final Color sign;

  /// none | smoke | sparks | flame
  final String exhaust;

  const OkadaSkin({
    this.accent = const Color(0xFFFFC233),
    this.road = const Color(0xFF23242B),
    this.kerb = const Color(0xFF3A3D47),
    this.bike = const Color(0xFFE53935),
    this.helmet = const Color(0xFFFFF3D0),
    this.sign = const Color(0xFF1B6B3A),
    this.exhaust = 'smoke',
  });

  static const OkadaSkin standard = OkadaSkin();

  /// The skin the player has equipped in the shop, falling back field by field
  /// so a half-filled asset still looks right.
  static OkadaSkin equipped() => GameKit.skin<OkadaSkin>(
        GameKit.okada,
        (Map<String, dynamic> a) => OkadaSkin(
          accent: GameKit.color(a, 'accent', standard.accent),
          road: GameKit.color(a, 'road', standard.road),
          kerb: GameKit.color(a, 'kerb', standard.kerb),
          bike: GameKit.color(a, 'bike', standard.bike),
          helmet: GameKit.color(a, 'helmet', standard.helmet),
          sign: GameKit.color(a, 'sign', standard.sign),
          exhaust: GameKit.word(a, 'exhaust', standard.exhaust),
        ),
        standard,
      );
}
