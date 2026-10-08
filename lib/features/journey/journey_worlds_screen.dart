import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/rarity.dart';
import 'journey_service.dart';
import 'journey_widgets.dart';

/// Every world with the student's star progress. Tap a world for its map.
class JourneyWorldsScreen extends StatefulWidget {
  const JourneyWorldsScreen({super.key});

  @override
  State<JourneyWorldsScreen> createState() => _JourneyWorldsScreenState();
}

class _JourneyWorldsScreenState extends State<JourneyWorldsScreen> {
  List<JourneyWorldSummary> _worlds = <JourneyWorldSummary>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<JourneyWorldSummary> w = await JourneyService.worlds();
    if (!mounted) return;
    setState(() {
      _worlds = w;
      _loading = false;
    });
  }

  Future<void> _open(JourneyWorldSummary w) async {
    await context.push('/journey/${w.realmId}');
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    int stars = 0;
    int maxStars = 0;
    for (final JourneyWorldSummary w in _worlds) {
      stars += w.stars;
      maxStars += w.maxStars;
    }
    return Scaffold(
      backgroundColor: Tac.bg,
      appBar: AppBar(
        backgroundColor: Tac.bg,
        elevation: 0,
        title: Text('JOURNEY', style: Tac.display(size: 18, weight: FontWeight.w800, letter: 1.4)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Tac.gold,
          backgroundColor: Tac.panel,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: <Widget>[
              Text(
                'Every world has five zones. Earn stars on quests, clear the mastery gate, and travel on.',
                style: Tac.body(size: 14, weight: FontWeight.w600, color: Tac.textDim, height: 1.35),
              ),
              const SizedBox(height: 8),
              const JourneyFairNote(),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Tac.gold)))
              else if (_worlds.isEmpty)
                TacticalPanel(
                  child: Column(children: <Widget>[
                    Text('No worlds to show yet', style: Tac.display(size: 14)),
                    const SizedBox(height: 4),
                    Text('Check your connection and pull down to try again.', textAlign: TextAlign.center, style: Tac.body(size: 13, color: Tac.textDim)),
                  ]),
                )
              else ...<Widget>[
                _totalBar(stars, maxStars),
                const SizedBox(height: 12),
                for (final JourneyWorldSummary w in _worlds) _card(w),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalBar(int stars, int maxStars) {
    return TacticalPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: <Widget>[
        const Icon(Icons.star_rounded, color: Tac.gold, size: 22),
        const SizedBox(width: 8),
        Text('$stars', style: Tac.display(size: 22, weight: FontWeight.w800, color: Tac.gold)),
        Text(' / $maxStars STARS', style: Tac.display(size: 12, weight: FontWeight.w700, color: Tac.textDim)),
        const SizedBox(width: 14),
        Expanded(child: JourneyBar(value: maxStars == 0 ? 0 : stars / maxStars)),
      ]),
    );
  }

  Widget _card(JourneyWorldSummary w) {
    final double frac = w.maxStars == 0 ? 0 : w.stars / w.maxStars;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TacticalPanel(
        keyline: w.accent.withValues(alpha: 0.6),
        padding: const EdgeInsets.all(14),
        onTap: () => _open(w),
        child: Row(children: <Widget>[
          Container(width: 4, height: 64, color: w.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Flexible(child: Text(w.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 15, weight: FontWeight.w800))),
                if (w.isNew) ...<Widget>[const SizedBox(width: 8), const JourneyNewTag()],
              ]),
              const SizedBox(height: 2),
              Text(w.subject.toUpperCase(), style: Tac.display(size: 10, weight: FontWeight.w700, color: w.accent, letter: 1.1)),
              const SizedBox(height: 4),
              Text(w.logline, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tac.body(size: 13, color: Tac.textDim, height: 1.3)),
              const SizedBox(height: 8),
              Row(children: <Widget>[
                const Icon(Icons.star_rounded, size: 14, color: Tac.gold),
                const SizedBox(width: 4),
                Text('${w.stars} / ${w.maxStars}', style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.gold)),
                const SizedBox(width: 10),
                Expanded(child: JourneyBar(value: frac, color: w.accent)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Tac.textDim),
        ]),
      ),
    );
  }
}
