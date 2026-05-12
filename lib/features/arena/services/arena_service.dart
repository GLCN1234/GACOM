import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class ArenaService {
  static SupabaseClient get _db => SupabaseService.client;
  static String? get _uid => SupabaseService.currentUserId;

  // ── Settings ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getSettings() async {
    try {
      final data = await _db.from('arena_settings').select('*').single();
      return data;
    } catch (_) {
      return {'arena_enabled': true, 'voice_enabled': true, 'platform_fee_percent': 15, 'min_stake': 200, 'max_stake': 50000};
    }
  }

  static Future<void> updateSettings(Map<String, dynamic> updates) async {
    await _db.from('arena_settings').update({...updates, 'updated_by': _uid, 'updated_at': DateTime.now().toIso8601String()}).eq('id', '00000000-0000-0000-0000-000000000001');
  }

  // ── Wallet ─────────────────────────────────────────────────────────────────
  static Future<double> getWalletBalance() async {
    try {
      final w = await _db.from('wallets').select('balance').eq('user_id', _uid!).single();
      return (w['balance'] as num).toDouble();
    } catch (_) { return 0; }
  }

  static Future<bool> deductStake(int amount) async {
    try {
      final w = await _db.from('wallets').select('balance').eq('user_id', _uid!).single();
      final bal = (w['balance'] as num).toDouble();
      if (bal < amount) return false;
      await _db.from('wallets').update({'balance': bal - amount}).eq('user_id', _uid!);
      await _db.from('wallet_transactions').insert({'user_id': _uid, 'type': 'arena_entry', 'amount': -amount, 'reference': 'ARENA_ENTRY_${DateTime.now().millisecondsSinceEpoch}', 'status': 'completed', 'description': 'Arena match entry stake'});
      return true;
    } catch (_) { return false; }
  }

  static Future<void> refundStake(String userId, int amount) async {
    try {
      final w = await _db.from('wallets').select('balance').eq('user_id', userId).single();
      final bal = (w['balance'] as num).toDouble();
      await _db.from('wallets').update({'balance': bal + amount}).eq('user_id', userId);
      await _db.from('wallet_transactions').insert({'user_id': userId, 'type': 'arena_refund', 'amount': amount, 'reference': 'ARENA_REFUND_${DateTime.now().millisecondsSinceEpoch}', 'status': 'completed', 'description': 'Arena match stake refund'});
    } catch (_) {}
  }

  // ── Match CRUD ─────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> createMatch({required String gameType, required int stakeAmount}) async {
    final deducted = await deductStake(stakeAmount);
    if (!deducted) return null;
    try {
      final channelId = 'arena_${DateTime.now().millisecondsSinceEpoch}';
      final data = await _db.from('arena_matches').insert({
        'game_type': gameType,
        'creator_id': _uid,
        'stake_amount': stakeAmount,
        'voice_channel': channelId,
        'status': 'waiting',
        'current_turn': _uid,
      }).select().single();
      return data;
    } catch (e) {
      await refundStake(_uid!, stakeAmount);
      return null;
    }
  }

  static Future<Map<String, dynamic>?> joinMatch(String matchId) async {
    try {
      final match = await _db.from('arena_matches').select('*').eq('id', matchId).single();
      final stakeAmount = match['stake_amount'] as int;
      final deducted = await deductStake(stakeAmount);
      if (!deducted) return null;
      final updated = await _db.from('arena_matches').update({
        'opponent_id': _uid,
        'status': 'active',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('id', matchId).eq('status', 'waiting').select().single();
      return updated;
    } catch (_) { return null; }
  }

  static Future<void> cancelMatch(String matchId) async {
    try {
      final match = await _db.from('arena_matches').select('*').eq('id', matchId).single();
      await _db.from('arena_matches').update({'status': 'cancelled'}).eq('id', matchId);
      await refundStake(match['creator_id'] as String, match['stake_amount'] as int);
      if (match['opponent_id'] != null) {
        await refundStake(match['opponent_id'] as String, match['stake_amount'] as int);
      }
    } catch (_) {}
  }

  static Future<void> submitMove(String matchId, Map<String, dynamic> moveData, int moveNumber) async {
    await _db.from('arena_moves').insert({'match_id': matchId, 'player_id': _uid, 'move_data': moveData, 'move_number': moveNumber});
  }

  static Future<void> updateGameState(String matchId, Map<String, dynamic> state, {String? nextTurn}) async {
    final update = {'game_state': state};
    if (nextTurn != null) update['current_turn'] = nextTurn;
    await _db.from('arena_matches').update(update).eq('id', matchId);
  }

  static Future<bool> declareWinner(String matchId, String winnerId) async {
    try {
      final resp = await SupabaseService.client.functions.invoke('arena-payout', body: {'match_id': matchId, 'winner_id': winnerId});
      return resp.status == 200;
    } catch (_) { return false; }
  }

  static Future<void> raiseDispute(String matchId, String reason) async {
    await _db.from('arena_disputes').insert({'match_id': matchId, 'raised_by': _uid, 'reason': reason});
    await _db.from('arena_matches').update({'status': 'disputed'}).eq('id', matchId);
  }

  // ── Trivia ─────────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchTriviaQuestions({int count = 10}) async {
    final data = await _db.from('trivia_questions').select('*').eq('is_active', true).limit(count * 3);
    final list = List<Map<String, dynamic>>.from(data);
    list.shuffle();
    return list.take(count).toList();
  }

  // ── Leaderboard ────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 20}) async {
    try {
      final data = await _db.rpc('arena_leaderboard', params: {'lim': limit});
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      final wins = await _db.from('arena_matches').select('winner_id, winner_payout, profiles!winner_id(username, display_name, avatar_url)').eq('status', 'completed').not('winner_id', 'is', null).order('created_at', ascending: false).limit(100);
      final Map<String, Map<String, dynamic>> agg = {};
      for (final m in wins as List) {
        final uid = m['winner_id'] as String;
        if (!agg.containsKey(uid)) {
          agg[uid] = {'user_id': uid, 'wins': 0, 'total_earnings': 0, 'profile': m['profiles']};
        }
        agg[uid]!['wins'] = (agg[uid]!['wins'] as int) + 1;
        agg[uid]!['total_earnings'] = (agg[uid]!['total_earnings'] as int) + (m['winner_payout'] as int? ?? 0);
      }
      final sorted = agg.values.toList()..sort((a, b) => (b['total_earnings'] as int).compareTo(a['total_earnings'] as int));
      return sorted.take(limit).toList();
    }
  }

  // ── Admin ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getAdminStats() async {
    try {
      final today = DateTime.now().toUtc().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
      final results = await Future.wait([
        _db.from('arena_matches').select('id').eq('status', 'active'),
        _db.from('arena_matches').select('platform_fee').eq('status', 'completed').gte('ended_at', today.toIso8601String()),
        _db.from('arena_matches').select('id').eq('status', 'completed'),
        _db.from('arena_disputes').select('id').eq('status', 'open'),
        _db.from('arena_matches').select('id'),
      ]);
      final todayFees = (results[1] as List).fold<int>(0, (sum, m) => sum + ((m['platform_fee'] as int?) ?? 0));
      return {'active': (results[0] as List).length, 'today_fees': todayFees, 'total_completed': (results[2] as List).length, 'open_disputes': (results[3] as List).length, 'total_matches': (results[4] as List).length};
    } catch (_) { return {'active': 0, 'today_fees': 0, 'total_completed': 0, 'open_disputes': 0, 'total_matches': 0}; }
  }

  static Future<List<Map<String, dynamic>>> getOpenDisputes() async {
    final data = await _db.from('arena_disputes').select('*, match:arena_matches(*), raiser:profiles!raised_by(username, display_name)').eq('status', 'open').order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> resolveDispute(String disputeId, String matchId, String? winnerId) async {
    final uid = _uid;
    await _db.from('arena_disputes').update({'status': winnerId != null ? 'resolved' : 'refunded', 'resolved_by': uid, 'resolved_at': DateTime.now().toIso8601String()}).eq('id', disputeId);
    if (winnerId != null) {
      await declareWinner(matchId, winnerId);
    } else {
      final match = await _db.from('arena_matches').select('*').eq('id', matchId).single();
      await _db.from('arena_matches').update({'status': 'cancelled'}).eq('id', matchId);
      await refundStake(match['creator_id'] as String, match['stake_amount'] as int);
      if (match['opponent_id'] != null) await refundStake(match['opponent_id'] as String, match['stake_amount'] as int);
    }
  }

  static Future<void> banUser(String userId, String reason, {DateTime? expiresAt}) async {
    await _db.from('arena_bans').insert({'user_id': userId, 'reason': reason, 'banned_by': _uid, if (expiresAt != null) 'expires_at': expiresAt.toIso8601String()});
  }

  static Future<bool> isUserBanned(String userId) async {
    try {
      final bans = await _db.from('arena_bans').select('id, expires_at').eq('user_id', userId);
      for (final ban in bans as List) {
        final exp = ban['expires_at'];
        if (exp == null) return true;
        if (DateTime.parse(exp).isAfter(DateTime.now())) return true;
      }
      return false;
    } catch (_) { return false; }
  }

  // ── Voice signaling via Supabase Realtime ─────────────────────────────────
  static RealtimeChannel voiceChannel(String channelId) {
    return _db.channel('voice:$channelId');
  }

 static const turnServers = [
  {'urls': 'stun:stun.relay.metered.ca:80'},

  {
    'urls': 'turn:global.relay.metered.ca:80',
    'username': '8eb42567eff8fc7803016827',
    'credential': '0lZj0uVDReuXdE6l',
  },

  {
    'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
    'username': '8eb42567eff8fc7803016827',
    'credential': '0lZj0uVDReuXdE6l',
  },

  {
    'urls': 'turn:global.relay.metered.ca:443',
    'username': '8eb42567eff8fc7803016827',
    'credential': '0lZj0uVDReuXdE6l',
  },

  {
    'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
    'username': '8eb42567eff8fc7803016827',
    'credential': '0lZj0uVDReuXdE6l',
  },
];
}
