import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../../features/edu/edu_subscription_service.dart';

class CosmeticsService {
  static Future<List<Map<String, dynamic>>> catalog(String category) async {
    try {
      final data = await SupabaseService.client.from('cosmetic_items').select().eq('category', category).order('requires_premium');
      return List<Map<String, dynamic>>.from(data);
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>?> equipped(String userId) async {
    try {
      final data = await SupabaseService.client.from('user_cosmetics')
          .select('*, name_color:cosmetic_items!equipped_name_color(value), badge:cosmetic_items!equipped_badge(value), avatar_frame:cosmetic_items!equipped_avatar_frame(value)')
          .eq('user_id', userId).maybeSingle();
      return data;
    } catch (_) { return null; }
  }

  /// Returns false (and doesn't equip) if the item requires premium and
  /// the user isn't subscribed — enforced here, not just in the UI.
  static Future<bool> equip({required String category, required String itemId}) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;
    try {
      final item = await SupabaseService.client.from('cosmetic_items').select().eq('id', itemId).single();
      if (item['requires_premium'] == true) {
        final isPro = await EduSubscriptionService.isPro();
        if (!isPro) return false;
      }
      final column = switch (category) { 'name_color' => 'equipped_name_color', 'badge' => 'equipped_badge', 'avatar_frame' => 'equipped_avatar_frame', _ => null };
      if (column == null) return false;
      await SupabaseService.client.from('user_cosmetics').upsert({'user_id': uid, column: itemId, 'updated_at': DateTime.now().toIso8601String()}, onConflict: 'user_id');
      return true;
    } catch (_) { return false; }
  }

  static Color? nameColorFor(Map<String, dynamic>? equipped) {
    final hex = equipped?['name_color']?['value'] as String?;
    if (hex == null || hex.isEmpty) return null;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); } catch (_) { return null; }
  }

  static IconData? badgeFor(Map<String, dynamic>? equipped) {
    final name = equipped?['badge']?['value'] as String?;
    return switch (name) {
      'star_rounded' => Icons.star_rounded,
      'workspace_premium_rounded' => Icons.workspace_premium_rounded,
      'emoji_events_rounded' => Icons.emoji_events_rounded,
      _ => null,
    };
  }
}
