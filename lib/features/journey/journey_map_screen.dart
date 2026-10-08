import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/rarity.dart';
import '../edu/realms/realm_kit.dart' show RealmConfig;
import '../edu/realms/realm_registry.dart';
import 'journey_service.dart';
import 'journey_widgets.dart';

/// The zone map of one world: five zones on a vertical path, the quests in
/// each zone with their star thresholds, the mastery gate, and a PLAY button.
class JourneyMapScreen extends StatefulWidget {
  final String realmId;
  const JourneyMapScreen({super.key, required this.realmId});

  @override
  State<JourneyMapScreen> createState() => _JourneyMapScreenState();
}

class _JourneyMapScreenState extends State<JourneyMapScreen> {
  JourneyMap? _map;
  bool _loading = true;
  int? _expanded;
  bool _expandedSet = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final JourneyMap? m = await JourneyService.world(widget.realmId);
    if (!mounted) return;
    setState(() {
      _map = m;
      _loading = false;
      if (m != null && !_expandedSet && m.zones.isNotEmpty) {
        _expandedSet = true;
        _expanded = _currentZone(m.zones).zoneNo;
      }
    });
  }

  /// The first open zone whose gate is not cleared, else the last zone.
  JourneyZone _currentZone(List<JourneyZone> zones) {
    for (final JourneyZone z in zones) {
      if (z.open && !z.gateCleared) return z;
    }
    return zones.last;
  }

  RealmGameInfo? get _game => RealmRegistry.byId(widget.realmId);

  Color get _accent => _map?.world?.accent ?? _game?.color ?? Tac.cyan;

  String get _title => _map?.world?.name ?? _game?.name ?? 'Journey';

  Future<void> _play() async {
    if (_game == null) return;
    await context.push('/edu/realm/${widget.realmId}', extra: const RealmConfig());
    if (mounted) _load();
  }

  void _showHints() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Tac.panel,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(0))),
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('HOW RYAN HELPS', style: Tac.display(size: 15, weight: FontWeight.w800, letter: 1.2)),
            const SizedBox(height: 6),
            Text('Stuck on a question? Ryan gives help in three levels, one at a time.', style: Tac.body(size: 13, color: Tac.textDim, height: 1.35)),
            const SizedBox(height: 12),
            _hintLine('1', 'A nudge', 'A short pointer toward the idea you need, without the answer.'),
            _hintLine('2', 'An example', 'A similar problem solved from start to finish, so you can copy the method.'),
            _hintLine('3', 'A worked step', 'The next step of your own problem, shown in full.'),
            const SizedBox(height: 6),
            Text('Stars, not lives: any quest can be replayed to earn more stars.', style: Tac.body(size: 12, color: Tac.textDim)),
          ]),
        ),
      ),
    );
  }

  Widget _hintLine(String n, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: Tac.cyan.withValues(alpha: 0.14),
            shape: ChamferedBorder(cut: 6, side: const BorderSide(color: Tac.cyan, width: 1)),
          ),
          child: Text(n, style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.cyan)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(title, style: Tac.display(size: 13, weight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(body, style: Tac.body(size: 13, color: Tac.textDim, height: 1.3)),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final JourneyMap? m = _map;
    return Scaffold(
      backgroundColor: Tac.bg,
      appBar: AppBar(
        backgroundColor: Tac.bg,
        elevation: 0,
        title: Text(_title.toUpperCase(), style: Tac.display(size: 17, weight: FontWeight.w800, letter: 1.2)),
        actions: <Widget>[
          IconButton(tooltip: 'How Ryan helps', icon: const Icon(Icons.info_outline_rounded, color: Tac.textDim), onPressed: _showHints),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TacButton(
            label: 'PLAY',
            icon: Icons.play_arrow_rounded,
            color: Tac.gold,
            height: 52,
            onPressed: _game == null ? null : _play,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: Tac.gold,
          backgroundColor: Tac.panel,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              if (_loading)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: Tac.gold)))
              else if (m == null)
                TacticalPanel(
                  child: Column(children: <Widget>[
                    Text('This map could not be loaded', style: Tac.display(size: 14)),
                    const SizedBox(height: 4),
                    Text('Check your connection and pull down to try again.', textAlign: TextAlign.center, style: Tac.body(size: 13, color: Tac.textDim)),
                  ]),
                )
              else ...<Widget>[
                _header(m),
                const SizedBox(height: 10),
                const JourneyFairNote(),
                const SizedBox(height: 12),
                if (m.world != null && m.world!.hasStory) ...<Widget>[_tabs(), const SizedBox(height: 12)],
                if (_tab == 1 && m.world != null && m.world!.hasStory)
                  _storyTab(m.world!)
                else if (m.zones.isEmpty)
                  TacticalPanel(child: Text('No zones are set up for this world yet.', style: Tac.body(size: 13, color: Tac.textDim)))
                else
                  _zoneMap(m),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(JourneyMap m) {
    final JourneyWorldInfo? w = m.world;
    final double frac = m.maxStars == 0 ? 0 : m.totalStars / m.maxStars;
    return TacticalPanel(
      keyline: _accent.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          if (w != null && w.subject.isNotEmpty) Text(w.subject.toUpperCase(), style: Tac.display(size: 10, weight: FontWeight.w700, color: _accent, letter: 1.2)),
          if (w != null && w.isNew) ...<Widget>[const SizedBox(width: 8), const JourneyNewTag()],
        ]),
        const SizedBox(height: 4),
        Text(_title, style: Tac.display(size: 20, weight: FontWeight.w800)),
        if (w != null && w.logline.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          Text(w.logline, style: Tac.body(size: 14, color: Tac.textDim, height: 1.3)),
        ],
        const SizedBox(height: 12),
        Row(children: <Widget>[
          const Icon(Icons.star_rounded, color: Tac.gold, size: 20),
          const SizedBox(width: 6),
          Text('${m.totalStars}', style: Tac.display(size: 20, weight: FontWeight.w800, color: Tac.gold)),
          Text(' / ${m.maxStars} STARS', style: Tac.display(size: 11, weight: FontWeight.w700, color: Tac.textDim)),
          const SizedBox(width: 12),
          Expanded(child: JourneyBar(value: frac, color: Tac.gold, height: 6)),
        ]),
        const SizedBox(height: 10),
        const _EngineNote(),
      ]),
    );
  }

  Widget _tabs() {
    return Row(children: <Widget>[
      _tabButton('MAP', 0),
      const SizedBox(width: 8),
      _tabButton('STORY', 1),
    ]);
  }

  Widget _tabButton(String label, int i) {
    final bool on = _tab == i;
    final ChamferedBorder shape = ChamferedBorder(cut: 8, side: BorderSide(color: on ? Tac.gold : Tac.keyline, width: 1.1));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: DecoratedBox(
        decoration: ShapeDecoration(color: on ? Tac.gold.withValues(alpha: 0.14) : Tac.panel2, shape: shape),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Text(label, style: Tac.display(size: 12, weight: FontWeight.w800, color: on ? Tac.gold : Tac.textDim, letter: 1)),
        ),
      ),
    );
  }

  Widget _storyTab(JourneyWorldInfo w) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (w.story.isNotEmpty) _storyBlock('STORY', w.story, _accent),
      if (w.ideology.isNotEmpty) _storyBlock('WHAT THIS WORLD BELIEVES', w.ideology, Tac.cyan),
      if (w.boss.isNotEmpty) _storyBlock('THE FINAL GATE', w.boss, Tac.gold),
    ]);
  }

  Widget _storyBlock(String label, String body, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TacticalPanel(
        keyline: color.withValues(alpha: 0.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(label, style: Tac.display(size: 11, weight: FontWeight.w800, color: color, letter: 1.2)),
          const SizedBox(height: 6),
          Text(body, style: Tac.body(size: 14, color: Tac.text, height: 1.45)),
        ]),
      ),
    );
  }

  // ---- zone map -----------------------------------------------------------

  Widget _zoneMap(JourneyMap m) {
    final List<JourneyZone> zs = m.zones;
    final int currentNo = _currentZone(zs).zoneNo;
    return Column(children: <Widget>[
      for (int i = 0; i < zs.length; i++) _zoneRow(zs, i, currentNo),
    ]);
  }

  Widget _zoneRow(List<JourneyZone> zs, int i, int currentNo) {
    final JourneyZone z = zs[i];
    final bool done = z.gateCleared;
    final bool locked = !z.open;
    final bool current = !done && !locked && z.zoneNo == currentNo;
    final Color above = i > 0 && zs[i - 1].gateCleared ? Tac.gold : Tac.keyline;
    final Color below = done ? Tac.gold : Tac.keyline;
    final bool isOpen = _expanded == z.zoneNo;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        SizedBox(
          width: 52,
          child: Stack(children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _ZonePathPainter(
                  first: i == 0,
                  last: i == zs.length - 1,
                  above: above,
                  below: below,
                  done: done,
                  locked: locked,
                  current: current,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _ZonePathPainter.nodeY - 11,
              child: Center(child: _nodeGlyph(z, done, locked)),
            ),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _zoneCard(z, done: done, locked: locked, current: current, isOpen: isOpen),
          ),
        ),
      ]),
    );
  }

  Widget _nodeGlyph(JourneyZone z, bool done, bool locked) {
    if (done) return const SizedBox(height: 22, child: Center(child: Icon(Icons.check_rounded, size: 22, color: Tac.gold)));
    if (locked) return const SizedBox(height: 22, child: Center(child: Icon(Icons.lock_rounded, size: 18, color: Tac.textDim)));
    return SizedBox(height: 22, child: Center(child: Text('${z.zoneNo}', style: Tac.display(size: 15, weight: FontWeight.w800, color: Tac.cyan))));
  }

  Widget _zoneCard(JourneyZone z, {required bool done, required bool locked, required bool current, required bool isOpen}) {
    final Color edge = done ? Tac.gold : (locked ? Tac.keyline : Tac.cyan);
    final String status = done ? 'CLEARED' : (locked ? 'LOCKED' : (current ? 'CURRENT' : 'OPEN'));
    return Opacity(
      opacity: locked ? 0.72 : 1.0,
      child: TacticalPanel(
        color: isOpen ? Tac.panel : Tac.panel2,
        keyline: isOpen ? edge : edge.withValues(alpha: 0.55),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = isOpen ? null : z.zoneNo),
            child: Row(children: <Widget>[
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text('ZONE ${z.zoneNo}  ·  $status', style: Tac.display(size: 10, weight: FontWeight.w800, color: edge, letter: 1.1)),
                  const SizedBox(height: 2),
                  Text(z.name, style: Tac.display(size: 16, weight: FontWeight.w800, color: locked ? Tac.textDim : Tac.text)),
                ]),
              ),
              const Icon(Icons.star_rounded, size: 14, color: Tac.gold),
              const SizedBox(width: 3),
              Text('${z.stars} / ${z.maxStars}', style: Tac.display(size: 12, weight: FontWeight.w800, color: Tac.gold)),
              const SizedBox(width: 4),
              Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Tac.textDim),
            ]),
          ),
          if (isOpen) ..._zoneDetail(z, locked),
        ]),
      ),
    );
  }

  List<Widget> _zoneDetail(JourneyZone z, bool locked) {
    final List<JourneyQuest> normal = z.quests.where((JourneyQuest q) => !q.isGate).toList();
    final JourneyQuest? gate = z.gate;
    return <Widget>[
      const SizedBox(height: 8),
      if (z.story.isNotEmpty) Text(z.story, style: Tac.body(size: 13, color: Tac.textDim, height: 1.4)),
      if (locked) ...<Widget>[
        const SizedBox(height: 8),
        Row(children: <Widget>[
          const Icon(Icons.lock_rounded, size: 14, color: Tac.textDim),
          const SizedBox(width: 6),
          Expanded(child: Text('Earn at least 1 star on the previous zone\'s mastery gate to open this zone.', style: Tac.body(size: 12, color: Tac.textDim))),
        ]),
      ],
      const SizedBox(height: 10),
      for (final JourneyQuest q in normal) _questRow(q, locked),
      if (gate != null) _gateRow(z, gate),
      if (z.reward != null) _reward(z.reward!),
    ];
  }

  Widget _questRow(JourneyQuest q, bool dim) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: dim ? 0.6 : 1.0,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(q.title, style: Tac.display(size: 13, weight: FontWeight.w800)),
              if (q.description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(q.description, style: Tac.body(size: 12, color: Tac.textDim, height: 1.3)),
              ],
              const SizedBox(height: 3),
              Text(q.thresholdText, style: Tac.body(size: 12, weight: FontWeight.w700, color: Tac.cyan)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
            JourneyStarRow(stars: q.stars),
            const SizedBox(height: 3),
            Text('Best ${q.bestText}', style: Tac.body(size: 11, color: Tac.textDim)),
          ]),
        ]),
      ),
    );
  }

  Widget _gateRow(JourneyZone z, JourneyQuest g) {
    final bool unlocked = z.gateUnlocked;
    final String head = unlocked ? 'Mastery gate: timed run' : 'Mastery gate: timed run, needs ${z.gateStarsNeeded} stars';
    final ChamferedBorder shape = ChamferedBorder(cut: 9, side: BorderSide(color: unlocked ? Tac.gold : Tac.keyline, width: 1.2));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: ShapeDecoration(color: Tac.gold.withValues(alpha: unlocked ? 0.08 : 0.0), shape: shape),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Opacity(
            opacity: unlocked ? 1.0 : 0.7,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Icon(unlocked ? Icons.flag_rounded : Icons.lock_rounded, size: 16, color: unlocked ? Tac.gold : Tac.textDim),
                const SizedBox(width: 6),
                Expanded(child: Text(head, style: Tac.display(size: 12, weight: FontWeight.w800, color: unlocked ? Tac.gold : Tac.textDim, letter: 0.4))),
              ]),
              if (!unlocked && z.open) ...<Widget>[
                const SizedBox(height: 3),
                Text('${z.nonGateStars} / ${z.gateStarsNeeded} stars earned from this zone\'s quests.', style: Tac.body(size: 12, color: Tac.textDim)),
              ],
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(g.title, style: Tac.display(size: 13, weight: FontWeight.w800)),
                    if (g.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(g.description, style: Tac.body(size: 12, color: Tac.textDim, height: 1.3)),
                    ],
                    const SizedBox(height: 3),
                    Text(g.thresholdText, style: Tac.body(size: 12, weight: FontWeight.w700, color: Tac.gold)),
                  ]),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                  JourneyStarRow(stars: g.stars),
                  const SizedBox(height: 3),
                  Text('Best ${g.bestText}', style: Tac.body(size: 11, color: Tac.textDim)),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _reward(JourneyReward r) {
    final Rarity rar = Rarity.parse(r.rarity);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: <Widget>[
        Icon(Icons.emoji_events_rounded, size: 16, color: rar.color),
        const SizedBox(width: 6),
        Text('REWARD', style: Tac.display(size: 10, weight: FontWeight.w800, color: Tac.textDim, letter: 1.1)),
        const SizedBox(width: 8),
        Flexible(child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 13, weight: FontWeight.w800, color: rar.color))),
        const SizedBox(width: 8),
        RarityChip(rar, compact: true),
      ]),
    );
  }
}

/// Plain statement of what the new worlds are built on.
class _EngineNote extends StatelessWidget {
  const _EngineNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Quests count the questions you answer while you play this world.',
      style: Tac.body(size: 12, color: Tac.textDim),
    );
  }
}

/// Draws the vertical path through one zone row and the zone node.
class _ZonePathPainter extends CustomPainter {
  static const double nodeY = 30;
  static const double nodeSize = 32;

  final bool first;
  final bool last;
  final Color above;
  final Color below;
  final bool done;
  final bool locked;
  final bool current;

  const _ZonePathPainter({
    required this.first,
    required this.last,
    required this.above,
    required this.below,
    required this.done,
    required this.locked,
    required this.current,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final Paint line = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (!first) {
      line.color = above;
      canvas.drawLine(Offset(cx, 0), Offset(cx, nodeY), line);
    }
    if (!last) {
      line.color = below;
      canvas.drawLine(Offset(cx, nodeY), Offset(cx, size.height), line);
    }
    final Color c = done ? Tac.gold : (locked ? Tac.keyline : Tac.cyan);
    final Rect r = Rect.fromCenter(center: Offset(cx, nodeY), width: nodeSize, height: nodeSize);
    if (current) {
      final Rect halo = r.inflate(5);
      canvas.drawPath(
        ChamferedBorder.buildPath(halo, 11, true, true, true, true),
        Paint()
          ..color = Tac.cyan.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    final Path node = ChamferedBorder.buildPath(r, 9, true, true, true, true);
    canvas.drawPath(node, Paint()..color = locked ? Tac.panel2 : c.withValues(alpha: 0.16));
    canvas.drawPath(
      node,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _ZonePathPainter old) =>
      old.first != first || old.last != last || old.above != above || old.below != below || old.done != done || old.locked != locked || old.current != current;
}
