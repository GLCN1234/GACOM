import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

int _ji(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
String _js(dynamic v, [String fallback = '']) => v is String ? v : fallback;
bool _jb(dynamic v) => v == true;

Map<String, dynamic> _jm(dynamic v) {
  if (v is Map) {
    return v.map((dynamic k, dynamic val) => MapEntry<String, dynamic>(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<dynamic> _jl(dynamic v) => v is List ? v : <dynamic>[];

/// Parses '#RRGGBB', 'RRGGBB' or '#AARRGGBB'. Falls back to cyan.
Color journeyColor(dynamic v, [Color fallback = const Color(0xFF2ED3E6)]) {
  if (v is! String) return fallback;
  String s = v.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
  if (s.length == 6) s = 'FF$s';
  if (s.length != 8) return fallback;
  final int? n = int.tryParse(s, radix: 16);
  return n == null ? fallback : Color(n);
}

/// One row of the worlds list.
class JourneyWorldSummary {
  final String realmId;
  final String name;
  final String subject;
  final String logline;
  final Color accent;
  final bool isNew;
  final int stars;
  final int maxStars;

  const JourneyWorldSummary({
    required this.realmId,
    required this.name,
    required this.subject,
    required this.logline,
    required this.accent,
    required this.isNew,
    required this.stars,
    required this.maxStars,
  });

  factory JourneyWorldSummary.fromJson(Map<String, dynamic> j) => JourneyWorldSummary(
        realmId: _js(j['realm_id']),
        name: _js(j['name']),
        subject: _js(j['subject']),
        logline: _js(j['logline']),
        accent: journeyColor(j['accent']),
        isNew: _jb(j['is_new']),
        stars: _ji(j['stars']),
        maxStars: _ji(j['max_stars']),
      );
}

/// Story and identity of a world. Existing games may have none.
class JourneyWorldInfo {
  final String realmId;
  final String name;
  final String subject;
  final String logline;
  final String story;
  final String ideology;
  final String boss;
  final Color accent;
  final bool isNew;

  const JourneyWorldInfo({
    required this.realmId,
    required this.name,
    required this.subject,
    required this.logline,
    required this.story,
    required this.ideology,
    required this.boss,
    required this.accent,
    required this.isNew,
  });

  bool get hasStory => story.isNotEmpty || ideology.isNotEmpty || boss.isNotEmpty;

  factory JourneyWorldInfo.fromJson(Map<String, dynamic> j) => JourneyWorldInfo(
        realmId: _js(j['realm_id']),
        name: _js(j['name']),
        subject: _js(j['subject']),
        logline: _js(j['logline']),
        story: _js(j['story']),
        ideology: _js(j['ideology']),
        boss: _js(j['boss']),
        accent: journeyColor(j['accent']),
        isNew: _jb(j['is_new']),
      );
}

class JourneyReward {
  final String id;
  final String name;
  final String category;
  final String rarity;
  const JourneyReward({required this.id, required this.name, required this.category, required this.rarity});

  factory JourneyReward.fromJson(Map<String, dynamic> j) =>
      JourneyReward(id: _js(j['id']), name: _js(j['name']), category: _js(j['category']), rarity: _js(j['rarity']));
}

class JourneyQuest {
  final String id;
  final String title;
  final String description;

  /// 'answer', 'streak', 'accuracy' or 'gate'.
  final String kind;

  /// 'correct_answers', 'best_streak' or 'accuracy'.
  final String metric;
  final int minAsked;
  final int t1;
  final int t2;
  final int t3;
  final bool isGate;
  final int stars;
  final int best;

  const JourneyQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.metric,
    required this.minAsked,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.isGate,
    required this.stars,
    required this.best,
  });

  factory JourneyQuest.fromJson(Map<String, dynamic> j) => JourneyQuest(
        id: _js(j['id']),
        title: _js(j['title']),
        description: _js(j['description']),
        kind: _js(j['kind'], 'answer'),
        metric: _js(j['metric'], 'correct_answers'),
        minAsked: _ji(j['min_asked']),
        t1: _ji(j['t1']),
        t2: _ji(j['t2']),
        t3: _ji(j['t3']),
        isGate: _jb(j['is_gate']),
        stars: _ji(j['stars']),
        best: _ji(j['best']),
      );

  /// Unit word for the thresholds, such as "correct", "streak" or "%".
  String get unit {
    switch (metric) {
      case 'best_streak':
        return 'in a row';
      case 'accuracy':
        return '%';
      default:
        return 'correct';
    }
  }

  /// "5 / 10 / 15 correct" style summary of the three star thresholds.
  String get thresholdText {
    if (metric == 'accuracy') {
      final String base = '$t1% / $t2% / $t3% accuracy';
      return minAsked > 0 ? '$base, at least $minAsked asked' : base;
    }
    return '$t1 / $t2 / $t3 $unit';
  }

  String get bestText {
    if (metric == 'accuracy') return '$best%';
    return '$best';
  }
}

class JourneyZone {
  final int zoneNo;
  final String name;
  final String story;
  final int gateStarsNeeded;
  final bool open;
  final int stars;
  final int maxStars;
  final bool gateCleared;
  final JourneyReward? reward;
  final List<JourneyQuest> quests;

  const JourneyZone({
    required this.zoneNo,
    required this.name,
    required this.story,
    required this.gateStarsNeeded,
    required this.open,
    required this.stars,
    required this.maxStars,
    required this.gateCleared,
    required this.reward,
    required this.quests,
  });

  JourneyQuest? get gate {
    for (final JourneyQuest q in quests) {
      if (q.isGate) return q;
    }
    return null;
  }

  /// Stars from the quests that are not the gate.
  int get nonGateStars {
    int n = 0;
    for (final JourneyQuest q in quests) {
      if (!q.isGate) n += q.stars;
    }
    return n;
  }

  /// The gate only counts once the zone's other quests have enough stars.
  bool get gateUnlocked => open && nonGateStars >= gateStarsNeeded;

  factory JourneyZone.fromJson(Map<String, dynamic> j) {
    final dynamic r = j['reward'];
    return JourneyZone(
      zoneNo: _ji(j['zone_no']),
      name: _js(j['name']),
      story: _js(j['story']),
      gateStarsNeeded: _ji(j['gate_stars_needed']),
      open: _jb(j['open']),
      stars: _ji(j['stars']),
      maxStars: _ji(j['max_stars']),
      gateCleared: _jb(j['gate_cleared']),
      reward: r is Map ? JourneyReward.fromJson(_jm(r)) : null,
      quests: _jl(j['quests']).map((dynamic q) => JourneyQuest.fromJson(_jm(q))).toList(),
    );
  }
}

class JourneyMap {
  final JourneyWorldInfo? world;
  final int totalStars;
  final int maxStars;
  final List<JourneyZone> zones;
  const JourneyMap({required this.world, required this.totalStars, required this.maxStars, required this.zones});

  factory JourneyMap.fromJson(Map<String, dynamic> j) {
    final dynamic w = j['world'];
    final List<JourneyZone> zs = _jl(j['zones']).map((dynamic z) => JourneyZone.fromJson(_jm(z))).toList();
    zs.sort((JourneyZone a, JourneyZone b) => a.zoneNo.compareTo(b.zoneNo));
    return JourneyMap(
      world: w is Map ? JourneyWorldInfo.fromJson(_jm(w)) : null,
      totalStars: _ji(j['total_stars']),
      maxStars: _ji(j['max_stars']),
      zones: zs,
    );
  }
}

/// One quest whose stars changed in a run.
class JourneyChange {
  final String id;
  final String title;
  final int zoneNo;
  final bool isGate;
  final int before;
  final int after;
  const JourneyChange({
    required this.id,
    required this.title,
    required this.zoneNo,
    required this.isGate,
    required this.before,
    required this.after,
  });

  factory JourneyChange.fromJson(Map<String, dynamic> j) => JourneyChange(
        id: _js(j['id']),
        title: _js(j['title']),
        zoneNo: _ji(j['zone_no']),
        isGate: _jb(j['is_gate']),
        before: _ji(j['before']),
        after: _ji(j['after']),
      );
}

/// What a finished run did to the journey.
class JourneyRunResult {
  final String realmId;
  final List<JourneyChange> changes;
  final List<int> cleared;
  final List<int> opened;
  final int gained;

  const JourneyRunResult({
    required this.realmId,
    required this.changes,
    required this.cleared,
    required this.opened,
    required this.gained,
  });

  bool get isEmpty => changes.isEmpty && cleared.isEmpty && opened.isEmpty && gained <= 0;

  factory JourneyRunResult.fromJson(String realmId, Map<String, dynamic> j) => JourneyRunResult(
        realmId: realmId,
        changes: _jl(j['changes']).map((dynamic c) => JourneyChange.fromJson(_jm(c))).toList(),
        cleared: _jl(j['cleared']).map((dynamic n) => _ji(n)).toList(),
        opened: _jl(j['opened']).map((dynamic n) => _ji(n)).toList(),
        gained: _ji(j['gained']),
      );
}

/// Journey progress: worlds, zone maps and run reports. Every call is
/// failure-safe and never throws.
class JourneyService {
  JourneyService._();

  static Future<List<JourneyWorldSummary>> worlds() async {
    try {
      if (SupabaseService.currentUserId == null) return <JourneyWorldSummary>[];
      final dynamic r = await SupabaseService.client.rpc('journey_worlds_list');
      return _jl(r).map((dynamic w) => JourneyWorldSummary.fromJson(_jm(w))).where((JourneyWorldSummary w) => w.realmId.isNotEmpty).toList();
    } catch (_) {
      return <JourneyWorldSummary>[];
    }
  }

  static Future<JourneyMap?> world(String realmId) async {
    try {
      if (SupabaseService.currentUserId == null) return null;
      final dynamic r = await SupabaseService.client.rpc('journey_get', params: <String, dynamic>{'p_realm': realmId});
      if (r is! Map) return null;
      return JourneyMap.fromJson(_jm(r));
    } catch (_) {
      return null;
    }
  }

  /// Reports one finished run. Returns null when nothing could be reported.
  static Future<JourneyRunResult?> reportRun(String realmId, {required int asked, required int correct, required int bestStreak}) async {
    try {
      if (SupabaseService.currentUserId == null || asked <= 0) return null;
      final dynamic r = await SupabaseService.client.rpc('journey_report_run', params: <String, dynamic>{
        'p_realm': realmId,
        'p_metrics': <String, dynamic>{'asked': asked, 'correct': correct, 'best_streak': bestStreak},
      });
      if (r is! Map) return null;
      final Map<String, dynamic> m = _jm(r);
      if (m['success'] == false) return null;
      return JourneyRunResult.fromJson(realmId, m);
    } catch (_) {
      return null;
    }
  }
}
