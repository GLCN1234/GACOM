import 'package:flutter/foundation.dart';
import '../../../core/services/supabase_service.dart';
import '../duels/duel_registry.dart';

class DuelMatch {
  final String id;
  final String gameKey;
  final String gameName;
  final String creatorId;
  final String? opponentId;
  final int seed;
  final String status;
  final int? creatorScore;
  final int? creatorMs;
  final int? opponentScore;
  final int? opponentMs;
  final String? winnerId;
  final bool isDraw;
  final String? endReason;
  final DateTime? deadline;
  final DateTime? createdAt;

  const DuelMatch({
    required this.id,
    required this.gameKey,
    required this.gameName,
    required this.creatorId,
    required this.opponentId,
    required this.seed,
    required this.status,
    required this.creatorScore,
    required this.creatorMs,
    required this.opponentScore,
    required this.opponentMs,
    required this.winnerId,
    required this.isDraw,
    required this.endReason,
    required this.deadline,
    required this.createdAt,
  });

  static int? _int(dynamic v) => v == null ? null : (v as num).toInt();
  static DateTime? _time(dynamic v) => v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  factory DuelMatch.fromRow(Map<String, dynamic> r) => DuelMatch(
        id: r['id'] as String,
        gameKey: r['game_key'] as String,
        gameName: r['game_name'] as String,
        creatorId: r['creator_id'] as String,
        opponentId: r['opponent_id'] as String?,
        seed: _int(r['seed']) ?? 1,
        status: r['status'] as String,
        creatorScore: _int(r['creator_score']),
        creatorMs: _int(r['creator_ms']),
        opponentScore: _int(r['opponent_score']),
        opponentMs: _int(r['opponent_ms']),
        winnerId: r['winner_id'] as String?,
        isDraw: (r['is_draw'] as bool?) ?? false,
        endReason: r['end_reason'] as String?,
        deadline: _time(r['deadline']),
        createdAt: _time(r['created_at']),
      );

  bool isPlayer(String? uid) => uid != null && (uid == creatorId || uid == opponentId);
  String? otherId(String uid) => uid == creatorId ? opponentId : creatorId;
  int? scoreOf(String uid) => uid == creatorId ? creatorScore : (uid == opponentId ? opponentScore : null);
  int? msOf(String uid) => uid == creatorId ? creatorMs : (uid == opponentId ? opponentMs : null);
}

class DuelService {
  static dynamic get _db => SupabaseService.client;

  static DuelMatch _one(dynamic res) {
    dynamic row = res;
    if (row is List) row = row.first;
    return DuelMatch.fromRow(Map<String, dynamic>.from(row as Map));
  }

  static Future<DuelMatch> quick(DuelGame game) async {
    final dynamic res = await _db.rpc('duel_quick', params: <String, dynamic>{'p_key': game.key, 'p_name': game.name});
    return _one(res);
  }

  static Future<DuelMatch> join(String id) async {
    final dynamic res = await _db.rpc('duel_join', params: <String, dynamic>{'p_id': id});
    return _one(res);
  }

  static Future<DuelMatch> cancel(String id) async {
    final dynamic res = await _db.rpc('duel_cancel', params: <String, dynamic>{'p_id': id});
    return _one(res);
  }

  static Future<DuelMatch> submit(String id, int score, int ms) async {
    final dynamic res = await _db.rpc('duel_submit', params: <String, dynamic>{'p_id': id, 'p_score': score, 'p_ms': ms});
    return _one(res);
  }

  static Future<DuelMatch> forfeit(String id) async {
    final dynamic res = await _db.rpc('duel_forfeit', params: <String, dynamic>{'p_id': id});
    return _one(res);
  }

  static Future<DuelMatch> claim(String id) async {
    final dynamic res = await _db.rpc('duel_claim', params: <String, dynamic>{'p_id': id});
    return _one(res);
  }

  static Future<DuelMatch?> fetch(String id) async {
    try {
      final dynamic row = await _db.from('duel_matches').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return DuelMatch.fromRow(Map<String, dynamic>.from(row as Map));
    } catch (e) {
      debugPrint('duel fetch failed: $e');
      return null;
    }
  }

  /// Duels from other players that are waiting for an opponent right now.
  static Future<List<DuelMatch>> openDuels() async {
    try {
      final String uid = SupabaseService.currentUserId ?? '';
      final String since = DateTime.now().toUtc().subtract(const Duration(minutes: 10)).toIso8601String();
      final dynamic rows = await _db
          .from('duel_matches')
          .select()
          .eq('status', 'waiting')
          .neq('creator_id', uid)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List).map((r) => DuelMatch.fromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      debugPrint('open duels failed: $e');
      return <DuelMatch>[];
    }
  }

  /// My unfinished and finished duels, newest first.
  static Future<List<DuelMatch>> myDuels() async {
    try {
      final String uid = SupabaseService.currentUserId ?? '';
      final dynamic rows = await _db
          .from('duel_matches')
          .select()
          .or('creator_id.eq.$uid,opponent_id.eq.$uid')
          .neq('status', 'cancelled')
          .neq('status', 'waiting')
          .order('created_at', ascending: false)
          .limit(40);
      return (rows as List).map((r) => DuelMatch.fromRow(Map<String, dynamic>.from(r as Map))).toList();
    } catch (e) {
      debugPrint('my duels failed: $e');
      return <DuelMatch>[];
    }
  }

  static Future<List<Map<String, dynamic>>> standings({String? gameKey}) async {
    try {
      final dynamic rows = gameKey == null
          ? await _db.from('duel_standings').select().order('wins', ascending: false).limit(25)
          : await _db.from('duel_standings_by_game').select().eq('game_key', gameKey).order('wins', ascending: false).limit(25);
      return (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    } catch (e) {
      debugPrint('standings failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  /// id -> {username, display_name, avatar_url}
  static Future<Map<String, Map<String, dynamic>>> profiles(Iterable<String> ids) async {
    final List<String> list = ids.where((s) => s.isNotEmpty).toSet().toList();
    final Map<String, Map<String, dynamic>> out = <String, Map<String, dynamic>>{};
    if (list.isEmpty) return out;
    try {
      final String filter = list.map((s) => 'id.eq.$s').join(',');
      final dynamic rows = await _db.from('profiles').select('id, username, display_name, avatar_url').or(filter);
      for (final dynamic r in (rows as List)) {
        final Map<String, dynamic> m = Map<String, dynamic>.from(r as Map);
        out[m['id'] as String] = m;
      }
    } catch (e) {
      debugPrint('profiles failed: $e');
    }
    return out;
  }

  static String nameOf(Map<String, Map<String, dynamic>> profiles, String? id) {
    if (id == null) return 'Opponent';
    final Map<String, dynamic>? p = profiles[id];
    if (p == null) return 'Player';
    final dynamic u = p['username'];
    final dynamic d = p['display_name'];
    if (u is String && u.isNotEmpty) return u;
    if (d is String && d.isNotEmpty) return d;
    return 'Player';
  }
}
