import 'package:flutter/material.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../../core/services/supabase_service.dart';

int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;

class CardBadge {
  final String name;
  final String rarity;
  final IconData icon;
  const CardBadge(this.name, this.rarity, this.icon);
}

/// Everything the shareable player card shows, from the player_card RPC.
class PlayerCardData {
  final String id;
  final String name;
  final String tag;
  final String? avatarUrl;
  final int joinedYear;
  final int followers;
  final int points;
  final int games;
  final int wins;
  final int compWon;
  final String rank;
  final int rankIndex;
  final String? rankNext;
  final int rankFloor;
  final int rankNextFloor;
  final String? houseName;
  final Color? houseColor;
  final String? title;
  final Color? nameColor;
  final List<CardBadge> badges;
  final int missionsCleared;
  final int missionPoints;
  final int chapter;
  final String? passName;
  final int passLevel;
  final bool passPremium;

  const PlayerCardData({
    required this.id,
    required this.name,
    required this.tag,
    required this.avatarUrl,
    required this.joinedYear,
    required this.followers,
    required this.points,
    required this.games,
    required this.wins,
    required this.compWon,
    required this.rank,
    required this.rankIndex,
    required this.rankNext,
    required this.rankFloor,
    required this.rankNextFloor,
    required this.houseName,
    required this.houseColor,
    required this.title,
    required this.nameColor,
    required this.badges,
    required this.missionsCleared,
    required this.missionPoints,
    required this.chapter,
    required this.passName,
    required this.passLevel,
    required this.passPremium,
  });

  int get winRate => games <= 0 ? 0 : ((wins * 100) / games).round();

  /// 0..1 progress toward the next rank.
  double get rankProgress {
    if (rankNext == null || rankNextFloor <= rankFloor) return 1;
    return ((points - rankFloor) / (rankNextFloor - rankFloor)).clamp(0.0, 1.0).toDouble();
  }

  static PlayerCardData? fromJson(Map<String, dynamic> j) {
    final String username = (j['username'] ?? '').toString();
    final String display = (j['display_name'] ?? '').toString();
    final String gt = (j['gamer_tag'] ?? '').toString();
    final dynamic h = j['house'];
    final dynamic dk = j['darkom'];
    final dynamic ps = j['pass'];
    final List<CardBadge> bs = <CardBadge>[];
    final dynamic bl = j['badges'];
    if (bl is List) {
      for (final dynamic b in bl) {
        if (b is Map) {
          bs.add(CardBadge(
            (b['name'] ?? '').toString(),
            (b['rarity'] ?? 'common').toString(),
            CosmeticsService.iconForBadge(b['icon']?.toString()) ?? Icons.emoji_events_rounded,
          ));
        }
      }
    }
    return PlayerCardData(
      id: (j['id'] ?? '').toString(),
      name: display.isNotEmpty ? display : (username.isNotEmpty ? username : 'Player'),
      tag: gt.isNotEmpty ? gt : (username.isNotEmpty ? '@$username' : ''),
      avatarUrl: j['avatar_url']?.toString(),
      joinedYear: DateTime.tryParse((j['joined'] ?? '').toString())?.year ?? DateTime.now().year,
      followers: _i(j['followers']),
      points: _i(j['points']),
      games: _i(j['games']),
      wins: _i(j['wins']),
      compWon: _i(j['comp_won']),
      rank: (j['rank'] ?? 'Rookie').toString(),
      rankIndex: _i(j['rank_index']),
      rankNext: j['rank_next']?.toString(),
      rankFloor: _i(j['rank_floor']),
      rankNextFloor: _i(j['rank_next_floor']),
      houseName: h is Map ? h['name']?.toString() : null,
      houseColor: h is Map ? CosmeticsService.parseColor(h['color']?.toString()) : null,
      title: (j['title'] ?? '').toString().trim().isEmpty ? null : j['title'].toString(),
      nameColor: CosmeticsService.parseColor(j['name_color']?.toString()),
      badges: bs,
      missionsCleared: dk is Map ? _i(dk['missions_cleared']) : 0,
      missionPoints: dk is Map ? _i(dk['mission_points']) : 0,
      chapter: dk is Map ? _i(dk['chapter'], 1) : 1,
      passName: ps is Map ? ps['name']?.toString() : null,
      passLevel: ps is Map ? _i(ps['level']) : 0,
      passPremium: ps is Map && ps['premium'] == true,
    );
  }
}

class PlayerCardService {
  PlayerCardService._();

  /// Null when signed out, offline, or the account is private.
  static Future<PlayerCardData?> load(String userId) async {
    try {
      if (SupabaseService.currentUserId == null) return null;
      final dynamic r = await SupabaseService.client.rpc('player_card', params: <String, dynamic>{'p_user': userId});
      if (r is! Map) return null;
      return PlayerCardData.fromJson(Map<String, dynamic>.from(r));
    } catch (_) {
      return null;
    }
  }
}
