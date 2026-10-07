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
  final int stake;
  final int? payout;

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
    this.stake = 0,
    this.payout,
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
        stake: _int(r['stake_amount']) ?? 0,
        payout: _int(r['payout']),
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

  /// Stakes a duel can be played for, in naira. 0 is a free duel.
  static const List<int> stakes = <int>[0, 200, 500, 1000, 2000, 5000];

  static Future<DuelMatch> quick(DuelGame game, {int stake = 0}) async {
    final dynamic res = await _db.rpc('duel_quick', params: <String, dynamic>{'p_key': game.key, 'p_name': game.name, 'p_stake': stake});
    return _one(res);
  }

  /// Pays out or refunds any of my finished duels that were not settled yet.
  static Future<void> settleMine() async {
    try {
      await _db.rpc('duel_settle_mine');
    } catch (e) {
      debugPrint('duel settle retry failed: $e');
    }
  }

  /// Turns a server error into something a player can read.
  static String friendlyError(Object e) {
    final String t = e.toString().toLowerCase();
    if (t.contains('balance') || t.contains('insufficient')) {
      return 'Not enough balance for this stake. Top up your arena wallet or pick a smaller stake.';
    }
    if (t.contains('taken')) return 'That duel was just taken.';
    if (t.contains('pgrst202') || t.contains('404') || t.contains('could not find the function') || t.contains('42883')) {
      return 'Duels are not switched on yet on the server. Ask an admin to run the duel database setup.';
    }
    if (t.contains('socket') || t.contains('failed host lookup') || t.contains('clientexception') || t.contains('timeout')) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return 'Could not start a duel. Please try again in a moment.';
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
