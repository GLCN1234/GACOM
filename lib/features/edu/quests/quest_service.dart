import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import 'quest_content.dart';
import 'quest_models.dart';
import 'quest_runner.dart';

class QuestService {
  static List<Quest> builtIn() => builtInQuestJson.map(Quest.tryParse).whereType<Quest>().toList();

  /// Built-in quests plus any published in the life_quests table. A table
  /// row with the same id replaces the built-in version.
  static Future<List<Quest>> loadAll() async {
    final Map<String, Quest> byId = <String, Quest>{for (final Quest q in builtIn()) q.id: q};
    try {
      final dynamic rows = await SupabaseService.client.from('life_quests').select('id, data').eq('published', true);
      for (final dynamic r in (rows as List)) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
        final dynamic data = m['data'];
        final Map<String, dynamic> j = data is String ? Map<String, dynamic>.from(jsonDecode(data) as Map) : Map<String, dynamic>.from(data as Map);
        j['id'] = m['id'];
        final Quest? q = Quest.tryParse(jsonEncode(j));
        if (q != null) byId[q.id] = q;
      }
    } catch (e) {
      debugPrint('remote quests unavailable: $e');
    }
    return byId.values.toList();
  }

  static Future<Quest?> loadOne(String id) async {
    final List<Quest> all = await loadAll();
    for (final Quest q in all) {
      if (q.id == id) return q;
    }
    return null;
  }

  /// quest id -> best stars earned
  static Future<Map<String, int>> loadStars() async {
    final String? uid = SupabaseService.currentUserId;
    final Map<String, int> out = <String, int>{};
    if (uid == null) return out;
    try {
      final dynamic rows = await SupabaseService.client.from('life_quest_progress').select('quest_id, best_stars').eq('user_id', uid);
      for (final dynamic r in (rows as List)) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
        out[m['quest_id'] as String] = (m['best_stars'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('quest progress unavailable: $e');
    }
    return out;
  }

  static Future<void> saveResult(Quest q, QuestRunner r) async {
    final String? uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final dynamic old = await SupabaseService.client
          .from('life_quest_progress')
          .select('best_stars, plays')
          .eq('user_id', uid)
          .eq('quest_id', q.id)
          .maybeSingle();
      final int oldStars = old == null ? 0 : ((old as Map)['best_stars'] as num?)?.toInt() ?? 0;
      final int plays = old == null ? 0 : ((old as Map)['plays'] as num?)?.toInt() ?? 0;
      await SupabaseService.client.from('life_quest_progress').upsert(<String, dynamic>{
        'user_id': uid,
        'quest_id': q.id,
        'best_stars': r.stars > oldStars ? r.stars : oldStars,
        'plays': plays + 1,
        'last_played': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,quest_id');
    } catch (e) {
      debugPrint('could not save quest result: $e');
    }
  }
}
