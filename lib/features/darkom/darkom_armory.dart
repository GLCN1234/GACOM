import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../../shared/widgets/rarity.dart';
import '../../shared/widgets/weapon_art.dart';
import 'darkom_story.dart';

/// Picks the weapon skin to show for each of the six weapon kinds.
///
/// Rules: the equipped skin applies to its own kind; every other kind uses
/// the highest rarity skin the player owns for it, then the free common one,
/// then a plain built-in steel look. Never throws and works offline.
class DarkomArmory {
  final Map<String, Map<String, dynamic>> assets;
  final Map<String, String> skinNames;
  final Map<String, Rarity> rarities;
  final Map<String, WeaponPainter> _painters = <String, WeaponPainter>{};

  DarkomArmory(this.assets, this.skinNames, this.rarities);

  static DarkomArmory? _cached;
  static DateTime? _cachedAt;

  /// Art rotation baked into each silhouette, in degrees (see weapon_art.dart).
  static const Map<String, double> _rot = <String, double>{
    'sword': 20,
    'dagger': 0,
    'hammer': 30,
    'axe': 20,
    'staff': 15,
    'shield': 0,
  };

  static double rotRad(String kind) => (_rot[kind] ?? 0) * pi / 180.0;

  static Map<String, dynamic> defaultAsset(String kind) => <String, dynamic>{
        'weapon': kind,
        'metal': '#98A4B8',
        'hi': '#B8C4D8',
        'ex': '#6B7790',
        'w': '#7A4A2B',
      };

  /// A plain armory with only the built-in looks.
  static DarkomArmory plain() {
    final Map<String, Map<String, dynamic>> a = <String, Map<String, dynamic>>{};
    final Map<String, String> n = <String, String>{};
    final Map<String, Rarity> r = <String, Rarity>{};
    for (final String k in darkomWeaponKinds) {
      a[k] = defaultAsset(k);
      n[k] = 'Standard issue';
      r[k] = Rarity.common;
    }
    return DarkomArmory(a, n, r);
  }

  Map<String, dynamic> assetFor(String kind) => assets[kind] ?? defaultAsset(kind);
  String skinNameFor(String kind) => skinNames[kind] ?? 'Standard issue';
  Rarity rarityFor(String kind) => rarities[kind] ?? Rarity.common;

  /// The glow colour of a skin, if it has one.
  Color? glowFor(String kind) => CosmeticsService.parseColor(assetFor(kind)['glow']?.toString());
  Color metalFor(String kind) => CosmeticsService.parseColor(assetFor(kind)['metal']?.toString()) ?? const Color(0xFF98A4B8);

  /// A cached painter for drawing the weapon on a game canvas.
  WeaponPainter painterFor(String kind) {
    final WeaponPainter? p = _painters[kind];
    if (p != null) return p;
    final WeaponPainter np = WeaponPainter(asset: assetFor(kind));
    _painters[kind] = np;
    return np;
  }

  /// Draws [kind] with its handle near (x, y) pointing along [angle].
  /// [len] is the size of the art box in world units.
  void draw(Canvas canvas, String kind, double x, double y, double angle, double len, {double alpha = 1.0}) {
    final double fwd = kind == 'shield' ? len * 0.2 : len * 0.28;
    final double cx = x + cos(angle) * fwd;
    final double cy = y + sin(angle) * fwd;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle + pi / 2 - rotRad(kind));
    canvas.translate(-len / 2, -len / 2);
    if (alpha < 0.98) {
      canvas.saveLayer(Rect.fromLTWH(-len * 0.3, -len * 0.3, len * 1.6, len * 1.6), Paint()..color = Color.fromRGBO(255, 255, 255, alpha < 0 ? 0 : alpha));
      painterFor(kind).paint(canvas, Size(len, len));
      canvas.restore();
    } else {
      painterFor(kind).paint(canvas, Size(len, len));
    }
    canvas.restore();
  }

  static Future<DarkomArmory> load({bool force = false}) async {
    final DarkomArmory? c = _cached;
    final DateTime? at = _cachedAt;
    if (!force && c != null && at != null && DateTime.now().difference(at).inSeconds < 90) return c;
    DarkomArmory result;
    try {
      result = await _build();
    } catch (_) {
      result = c ?? plain();
    }
    _cached = result;
    _cachedAt = DateTime.now();
    return result;
  }

  static Future<DarkomArmory> _build() async {
    final DarkomArmory base = plain();
    List<Map<String, dynamic>> catalog = <Map<String, dynamic>>[];
    Set<String> owned = <String>{};
    try {
      await CosmeticsService.ensureLoaded();
    } catch (_) {}
    try {
      catalog = await CosmeticsService.catalog('weapon_skin');
    } catch (_) {}
    try {
      owned = await CosmeticsService.ownedIds();
    } catch (_) {}
    final Map<String, int> bestRank = <String, int>{};
    for (final Map<String, dynamic> item in catalog) {
      try {
        final dynamic a = item['asset'];
        if (a is! Map) continue;
        final Map<String, dynamic> asset = Map<String, dynamic>.from(a);
        final String kind = asset['weapon']?.toString() ?? '';
        if (!darkomWeaponKinds.contains(kind)) continue;
        if (!CosmeticsService.isOwned(item, owned, false)) continue;
        final Rarity r = Rarity.parse(item['rarity']?.toString());
        final int rank = r.index;
        final int? prev = bestRank[kind];
        if (prev == null || rank > prev) {
          bestRank[kind] = rank;
          base.assets[kind] = asset;
          base.skinNames[kind] = item['name']?.toString() ?? 'Skin';
          base.rarities[kind] = r;
        }
      } catch (_) {}
    }
    // The equipped skin always wins for its own kind.
    try {
      final Map<String, dynamic>? loadout = CosmeticsService.myLoadout.value;
      final dynamic eq = loadout?[CosmeticsService.slotOf('weapon_skin')];
      if (eq is Map) {
        final dynamic a = eq['asset'];
        if (a is Map) {
          final Map<String, dynamic> asset = Map<String, dynamic>.from(a);
          final String kind = asset['weapon']?.toString() ?? '';
          if (darkomWeaponKinds.contains(kind)) {
            base.assets[kind] = asset;
            base.skinNames[kind] = eq['name']?.toString() ?? 'Equipped skin';
            base.rarities[kind] = Rarity.parse(eq['rarity']?.toString());
          }
        }
      }
    } catch (_) {}
    return base;
  }
}
