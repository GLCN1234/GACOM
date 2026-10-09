import '../../core/services/supabase_service.dart';

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

/// Outcome of a house action (all writes are RPCs returning {success, error}).
class HouseResult {
  final bool success;
  final String? error;
  final String? houseId;
  final bool houseClosed;
  final double? balance;
  const HouseResult({required this.success, this.error, this.houseId, this.houseClosed = false, this.balance});

  /// join_house answers 'closed' for closed houses: the UI should offer a join request.
  bool get needsRequest => !success && error == 'closed';
  String get message => error ?? 'Something went wrong';
}

/// One row of the house leaderboard.
class HouseSummary {
  final String id;
  final String name;
  final String? colorHex;
  final String? motto;
  final bool isOpen;
  final String? emblem;
  final Map<String, dynamic>? banner;
  final int members;
  final int points;
  final int weekPoints;
  final int level;
  final int rank;
  const HouseSummary({
    required this.id, required this.name, this.colorHex, this.motto, required this.isOpen,
    this.emblem, this.banner, required this.members, required this.points,
    required this.weekPoints, required this.level, required this.rank,
  });
  factory HouseSummary.fromJson(Map<String, dynamic> j) => HouseSummary(
        id: j['house_id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        colorHex: j['banner_color']?.toString(),
        motto: j['motto']?.toString(),
        isOpen: j['is_open'] != false,
        emblem: j['emblem']?.toString(),
        banner: _map(j['banner']),
        members: _i(j['members']),
        points: _i(j['points']),
        weekPoints: _i(j['week_points']),
        level: _i(j['level']) < 1 ? 1 : _i(j['level']),
        rank: _i(j['rank']),
      );

  /// Member limit mirrors house_member_limit() in SQL.
  int get memberLimit => (20 + 10 * (level - 1)) > 100 ? 100 : (20 + 10 * (level - 1));
}

class HouseMember {
  final String userId;
  final String role;
  final String name;
  final String? username;
  final String? avatarUrl;
  final int points;
  const HouseMember({required this.userId, required this.role, required this.name, this.username, this.avatarUrl, required this.points});
  factory HouseMember.fromJson(Map<String, dynamic> j) {
    final display = j['display_name']?.toString();
    final user = j['username']?.toString();
    return HouseMember(
      userId: j['user_id']?.toString() ?? '',
      role: j['role']?.toString() ?? 'member',
      name: (display != null && display.isNotEmpty) ? display : (user ?? 'Player'),
      username: user,
      avatarUrl: j['avatar_url']?.toString(),
      points: _i(j['points']),
    );
  }
  bool get isCaptain => role == 'captain';
  bool get isOfficer => role == 'officer';
}

class HouseJoinRequest {
  final String id;
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? message;
  const HouseJoinRequest({required this.id, required this.userId, required this.name, this.avatarUrl, this.message});
  factory HouseJoinRequest.fromJson(Map<String, dynamic> j) {
    final display = j['display_name']?.toString();
    final user = j['username']?.toString();
    return HouseJoinRequest(
      id: j['id']?.toString() ?? '',
      userId: j['user_id']?.toString() ?? '',
      name: (display != null && display.isNotEmpty) ? display : (user ?? 'Player'),
      avatarUrl: j['avatar_url']?.toString(),
      message: j['message']?.toString(),
    );
  }
}

class HouseTrophy {
  final String weekStart;
  final int rank;
  final int points;
  const HouseTrophy({required this.weekStart, required this.rank, required this.points});
}

class HouseDetails {
  final String id;
  final String name;
  final String? colorHex;
  final String? motto;
  final String? description;
  final bool isOpen;
  final String captainId;
  final String? emblem;
  final String? emblemItemId;
  final String? bannerItemId;
  final Map<String, dynamic>? banner;
  final int points;
  final int weekPoints;
  final int level;
  final int nextLevelPoints;
  final int memberLimit;
  final int memberCount;
  final int rank;
  final int weekRank;
  final String? myRole;
  final bool myRequestPending;
  final List<HouseMember> members;
  final List<HouseJoinRequest> requests;
  final List<HouseTrophy> trophies;
  final Set<String> ownedItemIds;

  const HouseDetails({
    required this.id, required this.name, this.colorHex, this.motto, this.description, required this.isOpen,
    required this.captainId, this.emblem, this.emblemItemId, this.bannerItemId, this.banner,
    required this.points, required this.weekPoints, required this.level, required this.nextLevelPoints,
    required this.memberLimit, required this.memberCount, required this.rank, required this.weekRank,
    this.myRole, required this.myRequestPending, required this.members, required this.requests,
    required this.trophies, required this.ownedItemIds,
  });

  factory HouseDetails.fromJson(Map<String, dynamic> j) {
    final lvl = _i(j['level']) < 1 ? 1 : _i(j['level']);
    return HouseDetails(
      id: j['id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      colorHex: j['banner_color']?.toString(),
      motto: j['motto']?.toString(),
      description: j['description']?.toString(),
      isOpen: j['is_open'] != false,
      captainId: j['captain_id']?.toString() ?? '',
      emblem: j['emblem']?.toString(),
      emblemItemId: j['emblem_item_id']?.toString(),
      bannerItemId: j['banner_item_id']?.toString(),
      banner: _map(j['banner']),
      points: _i(j['points']),
      weekPoints: _i(j['week_points']),
      level: lvl,
      nextLevelPoints: _i(j['next_level_points']) > 0 ? _i(j['next_level_points']) : lvl * lvl * 1000,
      memberLimit: _i(j['member_limit']),
      memberCount: _i(j['member_count']),
      rank: _i(j['rank']),
      weekRank: _i(j['week_rank']),
      myRole: j['my_role']?.toString(),
      myRequestPending: j['my_request_pending'] == true,
      members: _list(j['members']).map(HouseMember.fromJson).toList(),
      requests: _list(j['requests']).map(HouseJoinRequest.fromJson).toList(),
      trophies: _list(j['trophies'])
          .map((t) => HouseTrophy(weekStart: t['week_start']?.toString() ?? '', rank: _i(t['rank']), points: _i(t['points'])))
          .toList(),
      ownedItemIds: (j['owned_item_ids'] is List) ? (j['owned_item_ids'] as List).map((e) => e.toString()).toSet() : <String>{},
    );
  }

  bool get isMember => myRole != null;
  bool get isCaptain => myRole == 'captain';
  bool get canManage => myRole == 'captain' || myRole == 'officer';
  bool get isFull => memberLimit > 0 && memberCount >= memberLimit;

  /// Points at which the current level began (inverse of house_level()).
  int get levelStartPoints => (level - 1) * (level - 1) * 1000;

  /// 0..1 progress towards the next level.
  double get levelProgress {
    final span = nextLevelPoints - levelStartPoints;
    if (span <= 0) return 0.0;
    final p = (points - levelStartPoints) / span;
    return p < 0 ? 0.0 : (p > 1 ? 1.0 : p.toDouble());
  }
}

/// Compact view of the house a user belongs to (get_user_house).
class UserHouse {
  final String houseId;
  final String name;
  final String? colorHex;
  final String role;
  final String? emblem;
  const UserHouse({required this.houseId, required this.name, this.colorHex, required this.role, this.emblem});
}

/// A house emblem or banner from the catalogue.
class HouseShopItem {
  final String id;
  final String category;
  final String name;
  final String value;
  final int price;
  final String rarity;
  final Map<String, dynamic>? asset;
  final String? description;
  const HouseShopItem({
    required this.id, required this.category, required this.name, required this.value,
    required this.price, required this.rarity, this.asset, this.description,
  });
  bool get isEmblem => category == 'house_emblem';
  bool get isBanner => category == 'house_banner';
}

/// This week's house goal and the Titan Aura fragment count (get_house_goal).
class HouseGoal {
  final bool active;
  final String title;
  final String metric;
  final int progress;
  final int target;
  final int rewardPoints;
  final bool achieved;
  final DateTime? endsAt;
  final int fragments;
  final int fragmentsNeeded;
  final bool unlocked;
  final String rewardName;
  const HouseGoal({
    required this.active, required this.title, required this.metric, required this.progress, required this.target,
    required this.rewardPoints, required this.achieved, this.endsAt, required this.fragments,
    required this.fragmentsNeeded, required this.unlocked, required this.rewardName,
  });
  factory HouseGoal.fromJson(Map<String, dynamic> j) => HouseGoal(
        active: j['active'] == true,
        title: j['title']?.toString() ?? '',
        metric: j['metric']?.toString() ?? '',
        progress: _i(j['progress']),
        target: _i(j['target']),
        rewardPoints: _i(j['reward_points']),
        achieved: j['achieved'] == true,
        endsAt: DateTime.tryParse(j['ends_at']?.toString() ?? '')?.toLocal(),
        fragments: _i(j['fragments']),
        fragmentsNeeded: _i(j['fragments_needed']) < 1 ? 4 : _i(j['fragments_needed']),
        unlocked: j['unlocked'] == true,
        rewardName: (j['reward_name']?.toString() ?? '').isEmpty ? 'Titan Aura' : j['reward_name'].toString(),
      );

  double get ratio {
    if (target <= 0) return 0.0;
    final r = progress / target;
    return r < 0 ? 0.0 : (r > 1 ? 1.0 : r.toDouble());
  }

  String get metricLabel {
    switch (metric) {
      case 'duels_played': return 'duels played';
      case 'duels_won': return 'duels won';
      case 'games_played': return 'games played';
      default: return 'progress';
    }
  }
}

class HouseService {
  HouseService._();

  static const int foundingFee = 500;

  static String friendlyError(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('could not find the function') || s.contains('does not exist') || s.contains('pgrst202')) {
      return 'Houses are being updated. Please try again shortly.';
    }
    if (s.contains('socketexception') || s.contains('failed host lookup') || s.contains('clientexception') || s.contains('timeout')) {
      return 'No connection. Check your internet and try again.';
    }
    if (s.contains('jwt') || s.contains('not authenticated')) return 'Please sign in again.';
    return 'Something went wrong. Please try again.';
  }

  static Future<HouseResult> _call(String fn, Map<String, dynamic> params) async {
    try {
      final res = await SupabaseService.client.rpc(fn, params: params);
      if (res is Map) {
        final ok = res['success'] == true;
        return HouseResult(
          success: ok,
          error: ok ? null : (res['error']?.toString() ?? 'Something went wrong'),
          houseId: res['house_id']?.toString(),
          houseClosed: res['closed'] == true,
          balance: (res['balance'] as num?)?.toDouble(),
        );
      }
      return const HouseResult(success: false, error: 'Unexpected response from the server');
    } catch (e) {
      return HouseResult(success: false, error: friendlyError(e));
    }
  }

  // ---- writes ----
  static Future<HouseResult> foundHouse({required String name, required String colorHex, String? motto}) =>
      _call('found_house', {'p_name': name, 'p_color': colorHex, 'p_motto': (motto == null || motto.trim().isEmpty) ? null : motto.trim()});

  static Future<HouseResult> joinHouse(String houseId) => _call('join_house', {'p_house_id': houseId});

  static Future<HouseResult> requestJoin(String houseId, {String? message}) =>
      _call('request_join_house', {'p_house_id': houseId, 'p_message': (message == null || message.trim().isEmpty) ? null : message.trim()});

  static Future<HouseResult> reviewRequest(String requestId, bool accept) =>
      _call('review_join_request', {'p_request_id': requestId, 'p_accept': accept});

  static Future<HouseResult> leaveHouse(String houseId) => _call('leave_house', {'p_house_id': houseId});

  static Future<HouseResult> kickMember(String houseId, String userId) =>
      _call('kick_house_member', {'p_house_id': houseId, 'p_user_id': userId});

  static Future<HouseResult> setRole(String houseId, String userId, String role) =>
      _call('set_house_role', {'p_house_id': houseId, 'p_user_id': userId, 'p_role': role});

  static Future<HouseResult> transferCaptain(String houseId, String newCaptainId) =>
      _call('transfer_house_captain', {'p_house_id': houseId, 'p_new_captain': newCaptainId});

  /// Always pass every current value; null motto/description clears them.
  static Future<HouseResult> updateHouse({
    required String houseId,
    required String? motto,
    required String? description,
    required String colorHex,
    required bool isOpen,
  }) =>
      _call('update_house', {
        'p_house_id': houseId,
        'p_motto': (motto == null || motto.trim().isEmpty) ? null : motto.trim(),
        'p_description': (description == null || description.trim().isEmpty) ? null : description.trim(),
        'p_color': colorHex,
        'p_is_open': isOpen,
      });

  /// Buys (if needed) and equips an emblem or banner. Captain only.
  static Future<HouseResult> purchaseItem(String houseId, String itemId) =>
      _call('purchase_house_item', {'p_house_id': houseId, 'p_item_id': itemId});

  // ---- reads ----
  static Future<List<HouseSummary>> leaderboard({bool week = false}) async {
    final res = await SupabaseService.client.rpc('house_leaderboard', params: {'p_scope': week ? 'week' : 'all'});
    return _list(res).map(HouseSummary.fromJson).toList();
  }

  /// This week's goal for a house. Null when the call fails, so the card simply stays hidden.
  static Future<HouseGoal?> goal(String houseId) async {
    try {
      final res = await SupabaseService.client.rpc('get_house_goal', params: {'p_house_id': houseId});
      final m = _map(res);
      if (m == null) return null;
      return HouseGoal.fromJson(m);
    } catch (_) {
      return null;
    }
  }

  /// Top ten members by points, for this week or all time. Empty when the call fails.
  static Future<List<HouseMember>> topMembers(String houseId, {bool week = true}) async {
    try {
      final res = await SupabaseService.client.rpc('get_house_top_members', params: {'p_house_id': houseId, 'p_scope': week ? 'week' : 'all'});
      return _list(res).map(HouseMember.fromJson).toList();
    } catch (_) {
      return <HouseMember>[];
    }
  }

  static Future<HouseDetails?> details(String houseId) async {
    final res = await SupabaseService.client.rpc('get_house_details', params: {'p_house_id': houseId});
    final m = _map(res);
    if (m == null) return null;
    return HouseDetails.fromJson(m);
  }

  static Future<UserHouse?> userHouse(String userId) async {
    final res = await SupabaseService.client.rpc('get_user_house', params: {'p_user_id': userId});
    final m = _map(res);
    if (m == null) return null;
    return UserHouse(
      houseId: m['house_id']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      colorHex: m['banner_color']?.toString(),
      role: m['role']?.toString() ?? 'member',
      emblem: m['emblem']?.toString(),
    );
  }

  /// Emblems and banners on sale for houses.
  static Future<List<HouseShopItem>> shopItems() async {
    final res = await SupabaseService.client
        .from('cosmetic_items')
        .select('id, category, name, value, price, rarity, asset, description, sort_order, available_until')
        .eq('scope', 'house')
        .eq('is_active', true)
        .order('sort_order');
    final now = DateTime.now().toUtc();
    final out = <HouseShopItem>[];
    for (final r in _list(res)) {
      final until = DateTime.tryParse(r['available_until']?.toString() ?? '');
      if (until != null && until.isBefore(now)) continue;
      out.add(HouseShopItem(
        id: r['id']?.toString() ?? '',
        category: r['category']?.toString() ?? '',
        name: r['name']?.toString() ?? '',
        value: r['value']?.toString() ?? '',
        price: _i(r['price']),
        rarity: r['rarity']?.toString() ?? 'common',
        asset: _map(r['asset']),
        description: r['description']?.toString(),
      ));
    }
    return out;
  }

  static Future<double> walletBalance() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return 0.0;
    final w = await SupabaseService.client.rpc('my_wallet') as Map;
    return (w['wallet_balance'] as num?)?.toDouble() ?? 0.0;
  }
}
