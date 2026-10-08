import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../arena/widgets/game_logo.dart';
import '../../../shared/widgets/rarity.dart' show Tac;
import '../../journey/journey_service.dart';
import '../odyssey/odyssey_questions.dart';
import 'realm_kit.dart';
import 'realm_registry.dart';

/// The home of all open-world learning games. Pick a subject (or all of
/// them), then pick a realm. Ryan suggests three for today, and every realm
/// is always available.
class RealmHubScreen extends StatefulWidget {
  final String? initialSubject;
  const RealmHubScreen({super.key, this.initialSubject});

  @override
  State<RealmHubScreen> createState() => _RealmHubScreenState();
}

class _RealmHubScreenState extends State<RealmHubScreen> {
  late String _subject;
  bool _useSchool = true;
  bool _loading = true;
  Map<String, int> _plays = <String, int>{};
  String? _last;
  Map<String, JourneyWorldSummary> _journey = <String, JourneyWorldSummary>{};

  @override
  void initState() {
    super.initState();
    final String? s = widget.initialSubject;
    _subject = (s == null || s.isEmpty) ? 'mix' : s;
    _load();
  }

  Future<void> _load() async {
    final Map<String, int> plays = await RealmRecs.loadPlays();
    final String? last = await RealmRecs.loadLast();
    if (!mounted) return;
    setState(() {
      _plays = plays;
      _last = last;
      _loading = false;
    });
    _loadJourney();
  }

  Future<void> _loadJourney() async {
    final List<JourneyWorldSummary> ws = await JourneyService.worlds();
    if (!mounted) return;
    setState(() => _journey = <String, JourneyWorldSummary>{for (final JourneyWorldSummary w in ws) w.realmId: w});
  }

  String get _subjectLabel => _subject == 'mix' ? 'every subject' : odySubjectById(_subject).label;

  Future<void> _open(RealmGameInfo g) async {
    await RealmRecs.recordPlay(g.id);
    if (!mounted) return;
    await context.push('/edu/realm/${g.id}', extra: RealmConfig(subjectId: _subject, useSchool: _useSchool));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final List<RealmPick> picks = RealmRecs.rank(subjectId: _subject, plays: _plays, last: _last, subjectLabel: _subjectLabel);
    final List<RealmPick> top = picks.take(3).toList();
    final List<RealmPick> rest = picks.skip(3).toList();
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('REALMS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: <Widget>[
            const Text('Open worlds, one for every way of learning. Pick a subject, then pick how you want to play it.',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 12),
            _journeyTile(),
            const SizedBox(height: 14),
            const _Label('SUBJECT'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
              _chip('mix', 'All subjects', const Color(0xFFFF6A00)),
              for (final OdySubject s in odySubjects) _chip(s.id, s.label, s.color),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
              child: Row(children: <Widget>[
                const Icon(Icons.school_rounded, color: GacomColors.accentCyan, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Use my school\'s curriculum when available', style: TextStyle(color: GacomColors.textPrimary, fontSize: 13)),
                ),
                Switch(value: _useSchool, onChanged: (bool v) => setState(() => _useSchool = v)),
              ]),
            ),
            const SizedBox(height: 20),
            const _Label('RYAN\'S PICKS FOR TODAY'),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)))
            else
              for (final RealmPick p in top) _card(p, big: true),
            const SizedBox(height: 14),
            const _Label('ALL REALMS'),
            const SizedBox(height: 8),
            for (final RealmPick p in rest) _card(p, big: false),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => context.push('/edu/more-games'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: const Row(children: <Widget>[
                  Icon(Icons.apps_rounded, color: GacomColors.textMuted),
                  SizedBox(width: 12),
                  Expanded(child: Text('More games', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary))),
                  Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _chip(String id, String label, Color color) {
    final bool on = _subject == id;
    return GestureDetector(
      onTap: () => setState(() => _subject = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: on ? 1.0 : 0.4)),
        ),
        child: Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: on ? Colors.white : GacomColors.textPrimary)),
      ),
    );
  }

  Widget _journeyTile() {
    int stars = 0;
    int maxStars = 0;
    for (final JourneyWorldSummary w in _journey.values) {
      stars += w.stars;
      maxStars += w.maxStars;
    }
    return GestureDetector(
      onTap: () async {
        await context.push('/journey');
        if (mounted) _loadJourney();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: Tac.gold.withValues(alpha: 0.5))),
        child: Row(children: <Widget>[
          const Icon(Icons.star_rounded, color: Tac.gold, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('Journey', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
              Text('Zones, quests and stars in every world', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12)),
            ]),
          ),
          if (maxStars > 0) Text('$stars / $maxStars', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Tac.gold)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
        ]),
      ),
    );
  }

  Widget _journeyChip(RealmGameInfo g) {
    final JourneyWorldSummary? w = _journey[g.id];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        await context.push('/journey/${g.id}');
        if (mounted) _loadJourney();
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.star_rounded, size: 14, color: Tac.gold),
          const SizedBox(width: 4),
          Text(w == null ? 'JOURNEY' : 'JOURNEY  ${w.stars} / ${w.maxStars}',
              style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Tac.gold, letterSpacing: 0.6)),
        ]),
      ),
    );
  }

  Widget _card(RealmPick p, {required bool big}) {
    final RealmGameInfo g = p.game;
    return GestureDetector(
      onTap: () => _open(g),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(big ? 14 : 12),
        decoration: BoxDecoration(
          gradient: big ? LinearGradient(colors: <Color>[g.color.withValues(alpha: 0.35), g.color.withValues(alpha: 0.10)]) : null,
          color: big ? null : GacomColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: g.color.withValues(alpha: big ? 0.7 : 0.3)),
        ),
        child: Row(children: <Widget>[
          SizedBox(
            width: big ? 56 : 44,
            height: big ? 56 : 44,
            child: GameLogo(name: g.name, radius: 14, fallback: Icon(g.icon, color: g.color, size: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Text(g.name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: big ? 18 : 15, color: GacomColors.textPrimary)),
                const SizedBox(width: 8),
                Text(g.verb, style: TextStyle(color: g.color, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 3),
              Text(g.tagline, maxLines: big ? 3 : 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, height: 1.35)),
              if (big) ...<Widget>[
                const SizedBox(height: 6),
                Text(p.reason, style: const TextStyle(color: GacomColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
              _journeyChip(g),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
        ]),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1));
}
