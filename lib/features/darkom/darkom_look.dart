import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/cosmetic_avatar.dart' show cosmeticFrameColors, cosmeticFrameStyle, cosmeticTitleFor;
import '../edu/realms/realm_kit.dart' show HeroLook;
import 'darkom_armory.dart';

/// How a player looks to others: outfit, trail, title, frame and weapon skin.
/// It is sent with presence and in arena rooms, so it is kept small and every
/// field is optional when read back. Cosmetic only, never a stat.
class DarkomLook {
  final String userId;
  final String name;
  final int shirt;
  final int pants;
  final int skin;
  final int hair;
  final String hairStyle;
  final String trail;
  final int trailColor;
  final String? title;
  final List<int> frameColors;
  final String? frameStyle;
  final String weaponKind;
  final Map<String, dynamic> weaponAsset;

  const DarkomLook({
    required this.userId,
    required this.name,
    required this.shirt,
    required this.pants,
    required this.skin,
    required this.hair,
    required this.hairStyle,
    required this.trail,
    required this.trailColor,
    required this.title,
    required this.frameColors,
    required this.frameStyle,
    required this.weaponKind,
    required this.weaponAsset,
  });

  Color get shirtColor => Color(shirt);
  Color get pantsColor => Color(pants);
  Color get skinColor => Color(skin);
  Color get hairColor => Color(hair);
  Color get trailTint => Color(trailColor);

  static String _myName() {
    try {
      final user = SupabaseService.client.auth.currentUser;
      final meta = user?.userMetadata;
      final String? n = (meta?['username'] ?? meta?['full_name'] ?? meta?['name'])?.toString();
      if (n != null && n.trim().isNotEmpty) return n.trim();
      final String? mail = user?.email;
      if (mail != null && mail.contains('@')) return mail.split('@').first;
    } catch (_) {}
    return 'Player';
  }

  /// The local player's current look. Never throws.
  static Future<DarkomLook> mine({String weaponKind = 'sword'}) async {
    HeroLook h = HeroLook.classic;
    String? title;
    List<int> frame = <int>[];
    String? frameStyle;
    Map<String, dynamic> weapon = DarkomArmory.defaultAsset(weaponKind);
    try {
      await CosmeticsService.ensureLoaded();
      h = HeroLook.current;
      final Map<String, dynamic>? eq = CosmeticsService.myLoadout.value;
      title = cosmeticTitleFor(eq);
      final List<Color>? fc = cosmeticFrameColors(equipped: eq);
      if (fc != null) frame = fc.map((Color c) => c.value).toList();
      frameStyle = cosmeticFrameStyle(equipped: eq);
    } catch (_) {}
    try {
      final DarkomArmory a = await DarkomArmory.load();
      weapon = Map<String, dynamic>.from(a.assetFor(weaponKind));
    } catch (_) {}
    return DarkomLook(
      userId: SupabaseService.currentUserId ?? '',
      name: _myName(),
      shirt: h.shirt.value,
      pants: h.pants.value,
      skin: h.skin.value,
      hair: h.hair.value,
      hairStyle: h.hairStyle,
      trail: h.trail,
      trailColor: h.trailColor.value,
      title: title,
      frameColors: frame,
      frameStyle: frameStyle,
      weaponKind: weaponKind,
      weaponAsset: weapon,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'u': userId,
        'n': name,
        's': shirt,
        'p': pants,
        'k': skin,
        'h': hair,
        'hs': hairStyle,
        'tr': trail,
        'tc': trailColor,
        if (title != null) 't': title,
        if (frameColors.isNotEmpty) 'fc': frameColors,
        if (frameStyle != null) 'fs': frameStyle,
        'wk': weaponKind,
        'wa': weaponAsset,
      };

  static int _i(dynamic v, int d) => v is num ? v.toInt() : d;

  /// Reads a look sent by another player. Missing or odd values fall back to
  /// plain defaults, so a bad payload can never crash a screen.
  factory DarkomLook.fromJson(Map<dynamic, dynamic> j) {
    List<int> fc = <int>[];
    final dynamic f = j['fc'];
    if (f is List) fc = f.whereType<num>().map((num e) => e.toInt()).take(4).toList();
    Map<String, dynamic> wa = <String, dynamic>{};
    final dynamic w = j['wa'];
    if (w is Map) wa = Map<String, dynamic>.from(w);
    final String wk = (j['wk']?.toString() ?? 'sword');
    final String name = (j['n']?.toString() ?? 'Player');
    final String? t = j['t']?.toString();
    return DarkomLook(
      userId: j['u']?.toString() ?? '',
      name: name.length > 24 ? name.substring(0, 24) : name,
      shirt: _i(j['s'], HeroLook.classic.shirt.value),
      pants: _i(j['p'], HeroLook.classic.pants.value),
      skin: _i(j['k'], HeroLook.classic.skin.value),
      hair: _i(j['h'], HeroLook.classic.hair.value),
      hairStyle: j['hs']?.toString() ?? 'low',
      trail: j['tr']?.toString() ?? 'none',
      trailColor: _i(j['tc'], HeroLook.classic.trailColor.value),
      title: (t == null || t.isEmpty) ? null : (t.length > 28 ? t.substring(0, 28) : t),
      frameColors: fc,
      frameStyle: j['fs']?.toString(),
      weaponKind: wk,
      weaponAsset: wa.isEmpty ? DarkomArmory.defaultAsset(wk) : wa,
    );
  }
}
