import '../../core/services/supabase_service.dart';

int _dkInt(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

Map<String, dynamic> _dkMap(dynamic v) {
  if (v is Map) {
    return v.map((dynamic k, dynamic val) => MapEntry<String, dynamic>(k.toString(), val));
  }
  return <String, dynamic>{};
}

List<String> _dkStrings(dynamic v) {
  if (v is! List) return <String>[];
  return v.whereType<String>().toList();
}

/// A player's saved Darkom City progress.
class DarkomProgress {
  final int chapter; // 1..5 current chapter, 6 = story complete
  final int bestScore;
  final int totalKills;
  final int echoWins;
  final Set<String> contractsDone;
  final int runsToday; // runs that earned rewards today

  const DarkomProgress({
    required this.chapter,
    required this.bestScore,
    required this.totalKills,
    required this.echoWins,
    required this.contractsDone,
    required this.runsToday,
  });

  static const DarkomProgress empty = DarkomProgress(
    chapter: 1,
    bestScore: 0,
    totalKills: 0,
    echoWins: 0,
    contractsDone: <String>{},
    runsToday: 0,
  );

  factory DarkomProgress.fromJson(Map<String, dynamic> j) {
    final int ch = _dkInt(j['chapter'], 1);
    return DarkomProgress(
      chapter: ch < 1 ? 1 : (ch > 6 ? 6 : ch),
      bestScore: _dkInt(j['best_score']),
      totalKills: _dkInt(j['total_kills']),
      echoWins: _dkInt(j['echo_wins']),
      contractsDone: _dkStrings(j['contracts_done']).toSet(),
      runsToday: _dkInt(j['runs_today']),
    );
  }
}

/// What the server decided about one finished run.
class DarkomRunResult {
  final bool accepted; // false if the server rejected the run as implausible
  final int xp; // xp granted (the server decides)
  final int chapter; // chapter after this run
  final bool chapterAdvanced;
  final List<String> newContracts; // contract keys newly completed
  final List<String> unlocks; // human names of cosmetics granted

  const DarkomRunResult({
    required this.accepted,
    required this.xp,
    required this.chapter,
    required this.chapterAdvanced,
    required this.newContracts,
    required this.unlocks,
  });

  factory DarkomRunResult.fromJson(Map<String, dynamic> j) {
    return DarkomRunResult(
      accepted: j['accepted'] == true,
      xp: _dkInt(j['xp']),
      chapter: _dkInt(j['chapter'], 1),
      chapterAdvanced: j['chapter_advanced'] == true,
      newContracts: _dkStrings(j['new_contracts']),
      unlocks: _dkStrings(j['unlocks']),
    );
  }
}

class DarkomService {
  DarkomService._();

  /// Never throws. Returns [DarkomProgress.empty] offline or when signed out.
  static Future<DarkomProgress> loadProgress() async {
    try {
      if (SupabaseService.currentUserId == null) return DarkomProgress.empty;
      final dynamic r = await SupabaseService.client.rpc('darkom_get_progress');
      if (r is! Map) return DarkomProgress.empty;
      return DarkomProgress.fromJson(_dkMap(r));
    } catch (_) {
      return DarkomProgress.empty;
    }
  }

  /// Never throws. Null when the run could not be reported.
  static Future<DarkomRunResult?> reportRun({
    required String district,
    required int kills,
    required int score,
    required int durationSec,
    required List<String> contractsDone,
    required bool echoDefeated,
  }) async {
    try {
      if (SupabaseService.currentUserId == null) return null;
      final dynamic r = await SupabaseService.client.rpc('darkom_report_run', params: <String, dynamic>{
        'p_district': district,
        'p_kills': kills,
        'p_score': score,
        'p_duration_sec': durationSec,
        'p_contracts': contractsDone,
        'p_echo_defeated': echoDefeated,
      });
      if (r is! Map) return null;
      final Map<String, dynamic> j = _dkMap(r);
      if (j['success'] != true) return null;
      return DarkomRunResult.fromJson(j);
    } catch (_) {
      return null;
    }
  }
}
