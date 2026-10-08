import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/cosmetics_service.dart';
import '../../../shared/widgets/cosmetic_avatar.dart';
import '../../../shared/widgets/rarity.dart';
import '../widgets/game_logo.dart';

/// A game-picker grid (real icons, pulled from the same game_listings
/// data the store uses) instead of a horizontal scroll of text chips,
/// and a real podium treatment for the top 3 instead of a flat list —
/// matches the app's own established visual language rather than
/// bolting on something disconnected from it. No Scaffold/AppBar of its
/// own — embedded directly as a tab on the profile page, which is where
/// every leaderboard now lives instead of scattered across the app.
class LeaderboardContent extends StatefulWidget {
  const LeaderboardContent({super.key});
  @override State<LeaderboardContent> createState() => _LeaderboardContentState();
}

class _LeaderboardContentState extends State<LeaderboardContent> {
  bool _loadingGames = true;
  bool _loadingScores = false;
  List<Map<String, dynamic>> _games = [];
  Map<String, dynamic>? _selectedGame;
  List<Map<String, dynamic>> _top = [];

  @override void initState() { super.initState(); _loadGames(); }

  Future<void> _loadGames() async {
    try {
      final data = await SupabaseService.client.from('game_listings')
          .select('name, icon_url, category')
          .eq('status', 'approved')
          .order('is_featured', ascending: false)
          .order('name');
      final games = List<Map<String, dynamic>>.from(data);
      if (mounted) setState(() { _games = games; _loadingGames = false; });
      if (games.isNotEmpty) _selectGame(games.first);
    } catch (_) { if (mounted) setState(() => _loadingGames = false); }
  }

  Future<void> _selectGame(Map<String, dynamic> game) async {
    setState(() { _selectedGame = game; _loadingScores = true; _top = []; });
    try {
      // Two separate fetches, not an embedded join — game_scores.user_id
      // references auth.users, not profiles, so PostgREST has no
      // declared relationship to embed profiles through here at all.
      // Fetches more rows than the final top-10 needs, since one
      // player can have many sessions for the same game — without
      // this, someone who's played 14 times could fill every single
      // slot with their own attempts instead of one entry per player.
      final scores = await SupabaseService.client.from('game_scores')
          .select('user_id, score, won, created_at')
          .eq('game_name', game['name'])
          .order('score', ascending: false)
          .limit(200);
      final allRows = List<Map<String, dynamic>>.from(scores);
      // One entry per player — their single best score for this game,
      // not every attempt they've ever made. Already sorted
      // highest-first, so the first row seen per user_id is their best.
      final seenUsers = <String>{};
      final scoreRows = <Map<String, dynamic>>[];
      for (final r in allRows) {
        final uid = r['user_id'] as String;
        if (seenUsers.add(uid)) {
          scoreRows.add(r);
          if (scoreRows.length >= 10) break;
        }
      }
      final userIds = scoreRows.map((r) => r['user_id'] as String).toSet().toList();
      Map<String, Map<String, dynamic>> profilesById = {};
      if (userIds.isNotEmpty) {
        final profs = await SupabaseService.client.from('profiles')
            .select('id, display_name, avatar_url')
            .filter('id', 'in', '(${userIds.join(',')})');
        profilesById = { for (final p in List<Map<String, dynamic>>.from(profs)) p['id'] as String: p };
      }
      final rows = scoreRows.map((r) => {
        'score': r['score'], 'won': r['won'], 'created_at': r['created_at'],
        'user': profilesById[r['user_id']] ?? {'id': r['user_id'], 'display_name': 'Player', 'avatar_url': null},
      }).toList();
      // Second, small query for equipped cosmetics — kept separate from
      // the main query rather than a complex nested embed, since this
      // is only ever 10 rows and it's safer to get right. Reuses the
      // same userIds already extracted above, not a second copy.
      if (userIds.isNotEmpty) {
        try {
          final cosmetics = await SupabaseService.client.from('user_cosmetics')
              .select('user_id, name_color:cosmetic_items!equipped_name_color(value), badge:cosmetic_items!equipped_badge(value), avatar_frame:cosmetic_items!equipped_avatar_frame(value,asset,rarity)')
              .filter('user_id', 'in', '(${userIds.join(',')})');
          final byUserId = { for (final c in List<Map<String, dynamic>>.from(cosmetics)) c['user_id'] as String: c };
          for (final row in rows) {
            final uid = (row['user'] as Map?)?['id'] as String?;
            if (uid != null && byUserId.containsKey(uid)) row['cosmetics'] = byUserId[uid];
          }
        } catch (_) {}
      }
      if (mounted) setState(() { _top = rows; _loadingScores = false; });
    } catch (_) { if (mounted) setState(() => _loadingScores = false); }
  }

  @override
  Widget build(BuildContext context) => _loadingGames
      ? const Center(child: CircularProgressIndicator())
      : _games.isEmpty
        ? const Center(child: Text('No games available yet.', style: TextStyle(color: GacomColors.textMuted)))
        : Column(children: [
            _gamePicker(),
            const Divider(color: GacomColors.border, height: 1),
            Expanded(child: _loadingScores
              ? const Center(child: CircularProgressIndicator())
              : _standings()),
          ]);

  Widget _gamePicker() => SizedBox(
    height: 96,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _games.length,
      itemBuilder: (_, i) {
        final g = _games[i];
        final selected = g['name'] == _selectedGame?['name'];
        return GestureDetector(
          onTap: () => _selectGame(g),
          child: Container(
            width: 68, margin: const EdgeInsets.only(right: 10),
            child: Column(children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? GacomColors.deepOrange : GacomColors.border, width: selected ? 2.5 : 1),
                  color: GacomColors.cardDark,
                ),
                child: GameLogo(
                  name: g['name'] as String?,
                  circle: true,
                  fallback: ClipOval(child: (g['icon_url'] != null && (g['icon_url'] as String).isNotEmpty)
                    ? Image.network(g['icon_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.sports_esports_rounded, color: GacomColors.textMuted, size: 22))
                    : const Icon(Icons.sports_esports_rounded, color: GacomColors.textMuted, size: 22)),
                ),
              ),
              const SizedBox(height: 4),
              Text(g['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? GacomColors.deepOrange : GacomColors.textMuted)),
            ]),
          ),
        );
      },
    ),
  );

  Widget _standings() {
    if (_top.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(
        'No scores yet for ${_selectedGame?['name'] ?? 'this game'} — be the first!',
        textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted))));
    }
    final podium = _top.take(3).toList();
    final rest = _top.skip(3).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      if (podium.isNotEmpty) _podium(podium),
      const SizedBox(height: 24),
      ...rest.asMap().entries.map((e) => _rankRow(e.key + 4, e.value)),
    ]);
  }

  Widget _podium(List<Map<String, dynamic>> top3) {
    // Visual order: 2nd, 1st, 3rd — classic podium arrangement, 1st
    // tallest and centered.
    final ordered = [
      if (top3.length > 1) (top3[1], 2) else (null, 2),
      (top3[0], 1),
      if (top3.length > 2) (top3[2], 3) else (null, 3),
    ];
    return SizedBox(height: 276, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: ordered.map((entry) {
      final (row, rank) = entry;
      if (row == null) return const Expanded(child: SizedBox());
      final user = row['user'] as Map<String, dynamic>? ?? {};
      final height = rank == 1 ? 150.0 : rank == 2 ? 120.0 : 100.0;
      final color = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32);
      return Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        CosmeticAvatar(
          radius: rank == 1 ? 26 : 22,
          avatarUrl: user['avatar_url'] as String?,
          name: user['display_name'] as String? ?? 'Player',
          equipped: row['cosmetics'] as Map<String, dynamic>?),
        const SizedBox(height: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (CosmeticsService.badgeFor(row['cosmetics'] as Map<String, dynamic>?) != null)
            Padding(padding: const EdgeInsets.only(right: 4), child: Icon(CosmeticsService.badgeFor(row['cosmetics'] as Map<String, dynamic>?), size: 12, color: GacomColors.deepOrange)),
          Flexible(child: Text(user['display_name'] as String? ?? 'Player', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: CosmeticsService.nameColorFor(row['cosmetics'] as Map<String, dynamic>?) ?? GacomColors.textPrimary))),
        ]),
        Text('${row['score']}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        const SizedBox(height: 8),
        Container(width: double.infinity, height: height, margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), border: Border.all(color: color.withOpacity(0.5))),
          child: Center(child: Text('$rank', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 28, color: color)))),
      ]));
    }).toList()));
  }

  Widget _rankRow(int rank, Map<String, dynamic> row) {
    final user = row['user'] as Map<String, dynamic>? ?? {};
    // Row keyline follows the rarity of the equipped frame (already fetched above).
    final frameRarity = cosmeticFrameRarity(equipped: row['cosmetics'] as Map<String, dynamic>?);
    final keyColor = (frameRarity != null && frameRarity != Rarity.common) ? frameRarity.color : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: keyColor == null ? null : Border.all(color: keyColor.withValues(alpha: 0.6)),
        boxShadow: (frameRarity != null && frameRarity.glows) ? [BoxShadow(color: frameRarity.color.withValues(alpha: 0.18), blurRadius: 10)] : null,
      ),
      child: Row(children: [
        SizedBox(width: 28, child: Text('$rank', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textMuted))),
        CosmeticAvatar(
          radius: 16,
          avatarUrl: user['avatar_url'] as String?,
          name: user['display_name'] as String? ?? 'Player',
          equipped: row['cosmetics'] as Map<String, dynamic>?),
        const SizedBox(width: 14),
        Expanded(child: Row(children: [
          if (CosmeticsService.badgeFor(row['cosmetics'] as Map<String, dynamic>?) != null)
            Padding(padding: const EdgeInsets.only(right: 6), child: Icon(CosmeticsService.badgeFor(row['cosmetics'] as Map<String, dynamic>?), size: 14, color: GacomColors.deepOrange)),
          Flexible(child: Text(user['display_name'] as String? ?? 'Player', overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: CosmeticsService.nameColorFor(row['cosmetics'] as Map<String, dynamic>?) ?? GacomColors.textPrimary))),
        ])),
        Text('${row['score']}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 15, color: GacomColors.deepOrange)),
      ]),
    );
  }
}

/// Thin standalone wrapper for the existing /leaderboard route — the
/// real content lives in LeaderboardContent above, embedded directly on
/// the profile page. Kept only so a direct link to this route still works.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('LEADERBOARD')),
    body: const LeaderboardContent(),
  );
}
