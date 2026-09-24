import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _games = ['Signal Run', 'Drone Breach', 'Signal Match', 'Vault Break', 'Chess', '2048', 'Snake', 'Whot', 'Speed Math', 'Word Scramble'];
  String _selectedGame = 'Signal Run';
  bool _loading = true;
  List<Map<String, dynamic>> _top = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client.from('game_scores')
          .select('score, won, created_at, user:profiles!user_id(display_name, avatar_url)')
          .eq('game_name', _selectedGame)
          .order('score', ascending: false)
          .limit(10);
      if (mounted) setState(() { _top = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('LEADERBOARD')),
    body: Column(children: [
      SizedBox(height: 46, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _games.length,
        itemBuilder: (_, i) {
          final g = _games[i];
          final selected = g == _selectedGame;
          return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
            label: Text(g, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: selected ? Colors.white : GacomColors.textSecondary)),
            selected: selected,
            onSelected: (_) { setState(() => _selectedGame = g); _load(); },
            selectedColor: GacomColors.deepOrange,
            backgroundColor: GacomColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50), side: BorderSide(color: selected ? Colors.transparent : GacomColors.border)),
          ));
        },
      )),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _top.isEmpty
          ? const Center(child: Text('No scores yet for this game — be the first!', style: TextStyle(color: GacomColors.textMuted)))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _top.length, itemBuilder: (_, i) {
              final row = _top[i];
              final user = row['user'] as Map<String, dynamic>? ?? {};
              final rank = i + 1;
              final medalColor = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : rank == 3 ? const Color(0xFFCD7F32) : GacomColors.textMuted;
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: rank <= 3 ? Border.all(color: medalColor.withOpacity(0.4)) : null),
                child: Row(children: [
                  SizedBox(width: 32, child: Text('$rank', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 18, color: medalColor))),
                  CircleAvatar(radius: 16, backgroundColor: GacomColors.border,
                    backgroundImage: (user['avatar_url'] != null && (user['avatar_url'] as String).isNotEmpty) ? NetworkImage(user['avatar_url']) : null,
                    onBackgroundImageError: (user['avatar_url'] != null && (user['avatar_url'] as String).isNotEmpty) ? (exception, stackTrace) {} : null,
                    child: (user['avatar_url'] == null || (user['avatar_url'] as String).isEmpty) ? const Icon(Icons.person, size: 16, color: Colors.white) : null),
                  const SizedBox(width: 12),
                  Expanded(child: Text(user['display_name'] as String? ?? 'Player', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.textPrimary))),
                  Text('${row['score']}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 16, color: GacomColors.deepOrange)),
                ]));
            })),
    ]),
  );
}
