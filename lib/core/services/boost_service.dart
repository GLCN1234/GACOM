import 'supabase_service.dart';

/// One boost on sale: what it does, what it costs and how many the player holds.
class BoostItem {
  final String id;
  final String name;
  final String description;
  final String kind;
  final int pct;
  final int minutes;
  final int price;
  final int qty;
  const BoostItem({required this.id, required this.name, required this.description, required this.kind, required this.pct, required this.minutes, required this.price, required this.qty});

  factory BoostItem.fromJson(Map<String, dynamic> j) => BoostItem(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Boost').toString(),
        description: (j['description'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        pct: _i(j['pct']),
        minutes: _i(j['minutes']),
        price: _i(j['price']),
        qty: _i(j['qty']),
      );

  static int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
}

/// The boost that is switched on right now.
class ActiveBoost {
  final String name;
  final String kind;
  final int pct;
  final DateTime endsAt;
  const ActiveBoost({required this.name, required this.kind, required this.pct, required this.endsAt});

  Duration get left {
    final Duration d = endsAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  bool get live => left > Duration.zero;
}

class BoostState {
  final List<BoostItem> catalog;
  final ActiveBoost? active;
  final int usedToday;
  final int dailyCap;
  final int maxHeld;
  final double? balance;
  const BoostState({required this.catalog, required this.active, required this.usedToday, required this.dailyCap, required this.maxHeld, required this.balance});
}

class BoostResult {
  final bool success;
  final String? error;
  const BoostResult(this.success, [this.error]);
}

/// Casual boosts: small, timed boosts to Season Pass XP and skin evolution XP.
/// They are applied on the server, never in a duel, a stake match, a
/// competition or a ranked board, and never change a score.
class BoostService {
  /// What each kind boosts, in plain words.
  static String kindLabel(String kind) {
    switch (kind) {
      case 'pass_xp':
        return 'Season Pass XP';
      case 'skin_xp':
        return 'Skin evolution XP';
    }
    return kind;
  }

  static Future<BoostState?> load() async {
    try {
      final dynamic r = await SupabaseService.client.rpc('boost_state');
      if (r is! Map || r['success'] != true) return null;
      final List<BoostItem> cat = <BoostItem>[
        for (final dynamic b in (r['catalog'] is List ? r['catalog'] as List : const <dynamic>[]))
          if (b is Map) BoostItem.fromJson(Map<String, dynamic>.from(b)),
      ];
      ActiveBoost? act;
      final dynamic a = r['active'];
      if (a is Map) {
        final DateTime? e = DateTime.tryParse('${a['ends_at']}')?.toLocal();
        if (e != null) {
          act = ActiveBoost(name: (a['name'] ?? 'Boost').toString(), kind: (a['kind'] ?? '').toString(), pct: BoostItem._i(a['pct']), endsAt: e);
        }
      }
      return BoostState(
        catalog: cat,
        active: (act != null && act.live) ? act : null,
        usedToday: BoostItem._i(r['used_today']),
        dailyCap: BoostItem._i(r['daily_cap']) == 0 ? 3 : BoostItem._i(r['daily_cap']),
        maxHeld: BoostItem._i(r['max_held']) == 0 ? 10 : BoostItem._i(r['max_held']),
        balance: r['balance'] is num ? (r['balance'] as num).toDouble() : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<BoostResult> buy(String boostId) => _call('buy_boost', boostId);
  static Future<BoostResult> activate(String boostId) => _call('activate_boost', boostId);

  static Future<BoostResult> _call(String fn, String boostId) async {
    try {
      final dynamic r = await SupabaseService.client.rpc(fn, params: <String, dynamic>{'p_boost_id': boostId});
      if (r is Map && r['success'] == true) return const BoostResult(true);
      return BoostResult(false, r is Map ? (r['error']?.toString() ?? 'Something went wrong') : 'Something went wrong');
    } catch (_) {
      return const BoostResult(false, 'Could not reach the shop. Check your connection.');
    }
  }
}
