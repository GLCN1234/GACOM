import '../../core/services/supabase_service.dart';

int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;

class PassReward {
  final int level;
  final String track; // free | premium
  final String kind; // points | cosmetic
  final int amount;
  final String label;
  final bool claimed;
  final String? category;
  final String? rarity;

  const PassReward({
    required this.level,
    required this.track,
    required this.kind,
    required this.amount,
    required this.label,
    required this.claimed,
    this.category,
    this.rarity,
  });

  factory PassReward.fromJson(Map<String, dynamic> j) {
    final dynamic item = j['item'];
    return PassReward(
      level: _i(j['level']),
      track: (j['track'] ?? 'free').toString(),
      kind: (j['kind'] ?? 'points').toString(),
      amount: _i(j['amount']),
      label: (j['label'] ?? '').toString(),
      claimed: j['claimed'] == true,
      category: item is Map ? item['category']?.toString() : null,
      rarity: item is Map ? item['rarity']?.toString() : null,
    );
  }
}

/// The active season and this player's place in it.
class PassState {
  final String name;
  final String tagline;
  final DateTime? endsAt;
  final int price;
  final int xpPerLevel;
  final int maxLevel;
  final int dailyCap;
  final int xp;
  final int level;
  final bool premium;
  final int xpToday;
  final double balance;
  final List<PassReward> rewards;

  const PassState({
    required this.name,
    required this.tagline,
    required this.endsAt,
    required this.price,
    required this.xpPerLevel,
    required this.maxLevel,
    required this.dailyCap,
    required this.xp,
    required this.level,
    required this.premium,
    required this.xpToday,
    required this.balance,
    required this.rewards,
  });

  int get xpIntoLevel => level >= maxLevel ? xpPerLevel : xp - level * xpPerLevel;

  PassReward? rewardAt(int level, String track) {
    for (final PassReward r in rewards) {
      if (r.level == level && r.track == track) return r;
    }
    return null;
  }

  int get claimable {
    int n = 0;
    for (final PassReward r in rewards) {
      if (!r.claimed && r.level <= level && (r.track == 'free' || premium)) n++;
    }
    return n;
  }

  static PassState? fromJson(Map<String, dynamic> j) {
    final dynamic s = j['season'];
    if (s is! Map) return null;
    final List<PassReward> rw = <PassReward>[];
    final dynamic list = j['rewards'];
    if (list is List) {
      for (final dynamic e in list) {
        if (e is Map) rw.add(PassReward.fromJson(Map<String, dynamic>.from(e)));
      }
    }
    return PassState(
      name: (s['name'] ?? 'Season').toString(),
      tagline: (s['tagline'] ?? '').toString(),
      endsAt: DateTime.tryParse((s['ends_at'] ?? '').toString()),
      price: _i(s['premium_price']),
      xpPerLevel: _i(s['xp_per_level'], 150),
      maxLevel: _i(s['max_level'], 40),
      dailyCap: _i(s['daily_xp_cap'], 500),
      xp: _i(j['xp']),
      level: _i(j['level']),
      premium: j['premium'] == true,
      xpToday: _i(j['xp_today']),
      balance: j['balance'] is num ? (j['balance'] as num).toDouble() : 0,
      rewards: rw,
    );
  }
}

class PassResult {
  final bool ok;
  final String message;
  const PassResult(this.ok, this.message);
}

class PassService {
  PassService._();

  /// Null when signed out, offline, or no season is running.
  static Future<PassState?> load() async {
    try {
      if (SupabaseService.currentUserId == null) return null;
      final dynamic r = await SupabaseService.client.rpc('pass_state');
      if (r is! Map) return null;
      return PassState.fromJson(Map<String, dynamic>.from(r));
    } catch (_) {
      return null;
    }
  }

  static String _friendly(Object e) {
    final String s = e.toString().toLowerCase();
    if (s.contains('socketexception') || s.contains('failed host lookup') || s.contains('timeout')) {
      return 'No connection. Check your internet and try again.';
    }
    if (s.contains('could not find the function') || s.contains('pgrst202')) return 'The pass is being set up. Please try again shortly.';
    return 'Something went wrong. Please try again.';
  }

  static Future<PassResult> claim(int level, String track) async {
    try {
      final dynamic r = await SupabaseService.client.rpc('pass_claim', params: <String, dynamic>{'p_level': level, 'p_track': track});
      if (r is Map && r['success'] == true) return PassResult(true, (r['label'] ?? 'Reward').toString());
      return PassResult(false, r is Map ? (r['error'] ?? 'Could not claim').toString() : 'Could not claim');
    } catch (e) {
      return PassResult(false, _friendly(e));
    }
  }

  static Future<PassResult> buyPremium() async {
    try {
      final dynamic r = await SupabaseService.client.rpc('pass_buy_premium');
      if (r is Map && r['success'] == true) return const PassResult(true, 'Premium pass unlocked');
      return PassResult(false, r is Map ? (r['error'] ?? 'Could not unlock').toString() : 'Could not unlock');
    } catch (e) {
      return PassResult(false, _friendly(e));
    }
  }
}
