import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// A standard app-store style layout — featured carousel, search, category
/// filters, then a grid of listings. Pulls from game_listings so GACOM's
/// own built-in games and developer submissions render identically once
/// approved, rather than being two separate hardcoded/dynamic sources.
class GameStoreScreen extends StatefulWidget {
  const GameStoreScreen({super.key});
  @override
  State<GameStoreScreen> createState() => _GameStoreScreenState();
}

class _GameStoreScreenState extends State<GameStoreScreen> {
  static const _categories = ['All', 'Puzzle', 'Action', 'Strategy', 'Board', 'Arcade', 'Card', 'Educational'];
  static const _categoryIcons = {
    'All': Icons.apps_rounded,
    'Puzzle': Icons.extension_rounded,
    'Action': Icons.bolt_rounded,
    'Strategy': Icons.psychology_rounded,
    'Board': Icons.grid_on_rounded,
    'Arcade': Icons.sports_esports_rounded,
    'Card': Icons.style_rounded,
    'Educational': Icons.school_rounded,
  };
  String _selectedCategory = 'All';
  String _search = '';
  bool _loading = true;
  List<Map<String, dynamic>> _games = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.client.from('game_listings')
          .select('id, name, tagline, category, developer_name, play_route, play_url, icon_url, rating, rating_count, is_featured')
          .eq('status', 'approved')
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _games = List<Map<String, dynamic>>.from(data); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  List<Map<String, dynamic>> get _featured => _games.where((g) => g['is_featured'] == true).toList();
  List<Map<String, dynamic>> get _filtered => _games.where((g) {
    final matchesCategory = _selectedCategory == 'All' || g['category'] == _selectedCategory;
    final matchesSearch = _search.isEmpty || (g['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase());
    return matchesCategory && matchesSearch;
  }).toList();

  void _openGame(Map<String, dynamic> g) {
    final route = g['play_route'] as String?;
    if (route != null) { context.push(route); return; }
    context.push('/arena/store/game/${g['id']}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('GAME STORE'), actions: [
      IconButton(onPressed: () => context.push('/leaderboard'), icon: const Icon(Icons.leaderboard_rounded), tooltip: 'Leaderboard'),
    ]),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
            _searchBar(),
            if (_featured.isNotEmpty) _featuredCarousel(),
            _categoryChips(),
            const SizedBox(height: 8),
            _gameGrid(),
            _submitCta(),
          ]),
        ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: TextField(
      onChanged: (v) => setState(() => _search = v),
      style: const TextStyle(color: GacomColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search games',
        hintStyle: const TextStyle(color: GacomColors.textMuted),
        prefixIcon: const Icon(Icons.search_rounded, color: GacomColors.textMuted),
        filled: true,
        fillColor: GacomColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: BorderSide.none),
      ),
    ),
  );

  Widget _featuredCarousel() => SizedBox(
    height: 170,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: _featured.length,
      itemBuilder: (_, i) {
        final g = _featured[i];
        final iconUrl = g['icon_url'] as String?;
        return GestureDetector(
          onTap: () => _openGame(g),
          child: Container(
            width: 280, margin: const EdgeInsets.only(right: 12),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: GacomColors.cardDark),
            child: Stack(fit: StackFit.expand, children: [
              // Real image background — falls back to the gradient only
              // if this game has no image yet, never a broken/empty tile.
              if (iconUrl != null && iconUrl.isNotEmpty)
                Image.network(iconUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(decoration: BoxDecoration(gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [GacomColors.deepOrange.withOpacity(0.85), GacomColors.electricBlue.withOpacity(0.65)]))))
              else
                Container(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [GacomColors.deepOrange.withOpacity(0.85), GacomColors.electricBlue.withOpacity(0.65)]))),
              // Dark scrim so the title text stays legible over any photo.
              Container(decoration: const BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black87]))),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Text('FEATURED', style: TextStyle(color: Colors.white70, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(g['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(g['tagline'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ),
            ]),
          ),
        );
      },
    ),
  );

  Widget _categoryChips() => SizedBox(
    height: 46,
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      itemBuilder: (_, i) {
        final cat = _categories[i];
        final selected = cat == _selectedCategory;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            avatar: Icon(_categoryIcons[cat] ?? Icons.apps_rounded, size: 16, color: selected ? Colors.white : GacomColors.textMuted),
            label: Text(cat, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, color: selected ? Colors.white : GacomColors.textSecondary)),
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            selected: selected,
            onSelected: (_) => setState(() => _selectedCategory = cat),
            selectedColor: GacomColors.deepOrange,
            backgroundColor: GacomColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50), side: BorderSide(color: selected ? Colors.transparent : GacomColors.border)),
          ),
        );
      },
    ),
  );

  Widget _gameGrid() {
    final list = _filtered;
    if (list.isEmpty) {
      return const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No games found.', style: TextStyle(color: GacomColors.textMuted))));
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.68),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final g = list[i];
        final rating = (g['rating'] as num?)?.toDouble() ?? 0;
        return GestureDetector(
          onTap: () => _openGame(g),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: GacomDecorations.glassCard(context, radius: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AspectRatio(aspectRatio: 1, child: Container(
                decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
                child: g['icon_url'] != null && (g['icon_url'] as String).isNotEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(g['icon_url'], fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 32)))
                  : const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 32),
              )),
              const SizedBox(height: 10),
              Text(g['name'] as String? ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.textPrimary)),
              const SizedBox(height: 2),
              Text(g['developer_name'] as String? ?? 'GACOM', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 2),
                Text(rating > 0 ? rating.toStringAsFixed(1) : 'New', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _submitCta() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: GacomDecorations.glassCard(context, radius: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.rocket_launch_outlined, color: GacomColors.electricBlue, size: 28),
        const SizedBox(height: 12),
        const Text('Built a game? Get it on GACOM.', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Submit your game for review. Approved games appear in the store for our whole player base.',
          style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.electricBlue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
          onPressed: () => context.push('/arena/store/submit'),
          child: const Text('SUBMIT YOUR GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
        )),
      ]),
    ),
  );
}
