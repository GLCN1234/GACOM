import 'package:flutter/material.dart';
import '../../../core/services/cosmetics_service.dart';

/// Reads the skin a player has equipped for one game, from the cosmetic shop.
///
/// Each new game has its own equip slot, so a player can own a bike for Okada
/// Run and a banner for Gate Siege at the same time. The asset of a shop item
/// is plain json, so a skin is only colours and a few words: nothing here can
/// change how a game plays, only how it looks.
///
/// Every read falls back to the game's own default, so a game looks right
/// before the loadout has loaded, for a signed-out player, and if the shop
/// call failed. [skin] caches the built skin against the loadout it came from,
/// so a painter may ask for it on every frame.
class GameKit {
  const GameKit._();

  /// Slot names, which match the `equipped_<slot>` columns on user_cosmetics.
  static const String okada = 'okada';
  static const String siege = 'siege';
  static const String current = 'current';
  static const String pitch = 'pitch';
  static const String market = 'market';

  /// Starts loading the loadout if it is not loaded. Safe to call often.
  static void ensureLoaded() {
    try {
      CosmeticsService.ensureLoaded();
    } catch (_) {}
  }

  static Map<String, dynamic> asset(String slot) {
    try {
      return CosmeticsService.assetOf(CosmeticsService.myLoadout.value, slot);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static final Map<String, Object?> _from = <String, Object?>{};
  static final Map<String, Object?> _cache = <String, Object?>{};

  /// The equipped skin for [slot], built by [build] from the item's asset json,
  /// or [fallback] when nothing is equipped. Rebuilt only when the loadout
  /// itself changes, so this is cheap enough to call every frame.
  static T skin<T>(String slot, T Function(Map<String, dynamic> asset) build, T fallback) {
    Object? src;
    try {
      src = CosmeticsService.myLoadout.value;
    } catch (_) {
      return fallback;
    }
    if (_from.containsKey(slot) && identical(_from[slot], src)) {
      final Object? hit = _cache[slot];
      if (hit is T) return hit;
    }
    _from[slot] = src;
    T built;
    try {
      final Map<String, dynamic> a = asset(slot);
      built = a.isEmpty ? fallback : build(a);
    } catch (_) {
      built = fallback;
    }
    _cache[slot] = built;
    return built;
  }

  /// A colour from the equipped skin, or [fallback].
  static Color color(Map<String, dynamic> a, String key, Color fallback) {
    try {
      return CosmeticsService.parseColor(a[key]?.toString()) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// A short word from the equipped skin, such as a shape or trail name.
  static String word(Map<String, dynamic> a, String key, String fallback) {
    final String v = a[key]?.toString() ?? '';
    return v.isEmpty ? fallback : v;
  }
}
