import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class GameDetailScreen extends StatefulWidget {
  final String gameId;
  const GameDetailScreen({super.key, required this.gameId});
  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  Map<String, dynamic>? _game;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client.from('game_listings').select().eq('id', widget.gameId).single();
      if (mounted) setState(() { _game = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator()));
    if (_game == null) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Text('Game not found.', style: TextStyle(color: GacomColors.textMuted))));

    final g = _game!;
    final rating = (g['rating'] as num?)?.toDouble() ?? 0;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text(g['name'] as String? ?? '')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(18)),
            child: g['icon_url'] != null && (g['icon_url'] as String).isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(18), child: Image.network(g['icon_url'], fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 36)))
              : const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 36)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g['name'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 20, color: GacomColors.textPrimary)),
            const SizedBox(height: 4),
            Text('by ${g['developer_name'] ?? 'GACOM'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(rating > 0 ? '${rating.toStringAsFixed(1)} (${g['rating_count'] ?? 0})' : 'No ratings yet', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
            ]),
          ])),
        ]),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () async {
            final url = g['play_url'] as String?;
            if (url == null) return;
            final uri = Uri.tryParse(url);
            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
          child: const Text('PLAY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
        )),
        const SizedBox(height: 24),
        const Text('ABOUT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        Text(g['description'] as String? ?? g['tagline'] as String? ?? 'No description provided.',
          style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.6)),
      ]),
    );
  }
}
