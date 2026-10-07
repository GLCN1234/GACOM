import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Result of a purchase or equip call.
class CosmeticResult {
  final bool success;
  final String? error;
  final double? balance;
  const CosmeticResult({required this.success, this.error, this.balance});
}

class CosmeticsService {
  static const List<String> categories = ['name_color', 'badge', 'avatar_frame', 'hero_outfit', 'trail', 'profile_banner'];

  static const String _equippedSelect = '*, '
      'name_color:cosmetic_items!equipped_name_color(id,name,value,asset), '
      'badge:cosmetic_items!equipped_badge(id,name,value,asset), '
      'avatar_frame:cosmetic_items!equipped_avatar_frame(id,name,value,asset), '
      'hero_outfit:cosmetic_items!equipped_hero_outfit(id,name,value,asset), '
      'trail:cosmetic_items!equipped_trail(id,name,value,asset), '
      'profile_banner:cosmetic_items!equipped_profile_banner(id,name,value,asset)';

  /// The signed-in player's equipped items, cached. Null until loaded.
  static final ValueNotifier<Map<String, dynamic>?> myLoadout = ValueNotifier<Map<String, dynamic>?>(null);
  static String? _loadedFor;
  static bool _loading = false;

  /// Loads the loadout once per signed-in user. Cheap and failure-safe.
  static Future<void> ensureLoaded() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) {
      if (myLoadout.value != null) myLoadout.value = null;
      _loadedFor = null;
      return;
    }
    if (_loadedFor == uid || _loading) return;
    await refreshLoadout();
  }

  /// Reloads the loadout from the server.
  static Future<void> refreshLoadout() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null || _loading) return;
    _loading = true;
    try {
      final data = await equipped(uid);
      myLoadout.value = data == null ? <String, dynamic>{} : Map<String, dynamic>.from(data);
      _loadedFor = uid;
    } catch (_) {
      // keep whatever we had
    } finally {
      _loading = false;
    }
  }

  /// Active items of one category (or all user-scope items when null).
  static Future<List<Map<String, dynamic>>> catalog([String? category]) async {
    try {
      var q = SupabaseService.client.from('cosmetic_items').select().eq('scope', 'user').eq('is_active', true);
      if (category != null) q = q.eq('category', category);
      final data = await q.order('sort_order').order('price');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) { return []; }
  }

  /// Ids of items bought (or granted) to the signed-in player.
  static Future<Set<String>> ownedIds() async {
    try {
      final data = await SupabaseService.client.rpc('my_cosmetic_ids');
      if (data is List) return data.map((e) => e.toString()).toSet();
      return <String>{};
    } catch (_) { return <String>{}; }
  }

  /// Equipped row for a user, with the item embeds (value + asset).
  static Future<Map<String, dynamic>?> equipped(String userId) async {
    try {
      final data = await SupabaseService.client.from('user_cosmetics').select(_equippedSelect).eq('user_id', userId).maybeSingle();
      return data;
    } catch (_) { return null; }
  }

  /// Wallet balance in naira, or null when it can not be read.
  static Future<double?> walletBalance() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return null;
    try {
      final row = await SupabaseService.client.from('profiles').select('wallet_balance').eq('id', uid).maybeSingle();
      return (row?['wallet_balance'] as num?)?.toDouble();
    } catch (_) { return null; }
  }

  static Future<CosmeticResult> purchase(String itemId) async {
    try {
      final r = await SupabaseService.client.rpc('purchase_cosmetic', params: {'p_item_id': itemId});
      return _parse(r);
    } catch (_) {
      return const CosmeticResult(success: false, error: 'Could not reach the shop. Check your connection.');
    }
  }

  /// Equips [itemId]. Pass a null [itemId] with a [category] to take the
  /// current item off.
  static Future<CosmeticResult> equip({String? itemId, String? category}) async {
    try {
      final r = await SupabaseService.client.rpc('equip_cosmetic', params: {'p_item_id': itemId, 'p_category': category});
      final res = _parse(r);
      if (res.success) {
        _loadedFor = null;
        await refreshLoadout();
      }
      return res;
    } catch (_) {
      return const CosmeticResult(success: false, error: 'Could not update your look. Try again.');
    }
  }

  static CosmeticResult _parse(dynamic r) {
    if (r is Map) {
      final ok = r['success'] == true;
      return CosmeticResult(
        success: ok,
        error: ok ? null : (r['error']?.toString() ?? 'Something went wrong'),
        balance: (r['balance'] as num?)?.toDouble(),
      );
    }
    return const CosmeticResult(success: false, error: 'Something went wrong');
  }

  // --- helpers used by profile, leaderboard, shop ---

  static Color? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      var h = hex.replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) { return null; }
  }

  static Map<String, dynamic> assetOf(Map<String, dynamic>? equipped, String key) {
    final a = equipped?[key]?['asset'];
    return a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
  }

  static Color? nameColorFor(Map<String, dynamic>? equipped) {
    final v = equipped?['name_color'];
    if (v is! Map) return null;
    return parseColor(v['value'] as String?);
  }

  static IconData? badgeFor(Map<String, dynamic>? equipped) {
    final v = equipped?['badge'];
    if (v is! Map) return null;
    return iconForBadge(v['value'] as String?);
  }

  static IconData? iconForBadge(String? name) {
    return switch (name) {
      'star_rounded' => Icons.star_rounded,
      'workspace_premium_rounded' => Icons.workspace_premium_rounded,
      'emoji_events_rounded' => Icons.emoji_events_rounded,
      'bolt_rounded' => Icons.bolt_rounded,
      'local_fire_department_rounded' => Icons.local_fire_department_rounded,
      'diamond_rounded' => Icons.diamond_rounded,
      'rocket_launch_rounded' => Icons.rocket_launch_rounded,
      'psychology_rounded' => Icons.psychology_rounded,
      'military_tech_rounded' => Icons.military_tech_rounded,
      'shield_rounded' => Icons.shield_rounded,
      'pets_rounded' => Icons.pets_rounded,
      'castle_rounded' => Icons.castle_rounded,
      _ => null,
    };
  }
}
