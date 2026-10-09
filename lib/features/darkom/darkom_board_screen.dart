import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'darkom_missions.dart';
import 'darkom_service.dart';
import 'darkom_story.dart';

const Color _bg = Color(0xFF05060A);
const Color _panel = Color(0xFF10121C);
const Color _edge = Color(0xFF262A3D);
const Color _pink = Color(0xFFFF2E93);
const Color _gold = Color(0xFFFFD54F);
const Color _muted = Color(0xFF8E93AB);

/// Mission board for Darkom City: story, three daily missions and 24 missions
/// in each of the five districts. Route: '/darkom/missions'.
class DarkomBoardScreen extends StatefulWidget {
  const DarkomBoardScreen({super.key});

  @override
  State<DarkomBoardScreen> createState() => _DarkomBoardScreenState();
}

class _DarkomBoardScreenState extends State<DarkomBoardScreen> {
  DarkomProgress _progress = DarkomProgress.empty;
  DarkomMissionStats _stats = DarkomMissionStats.empty;
  bool _loading = true;

  /// -1 daily, 0 story, 1..5 districts
  int _tab = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    DarkomProgress p = DarkomProgress.empty;
    DarkomMissionStats s = DarkomMissionStats.empty;
    try {
      p = await DarkomService.loadProgress().timeout(const Duration(seconds: 6), onTimeout: () => DarkomProgress.empty);
    } catch (_) {}
    try {
      s = await DarkomService.loadMissionStats().timeout(const Duration(seconds: 6), onTimeout: () => DarkomMissionStats.empty);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _progress = p;
      _stats = s;
      _loading = false;
    });
  }

  Future<void> _play(DarkomMission m) async {
    await context.push<void>('/darkom/play', extra: m);
    if (mounted) _load();
  }

  Future<void> _story() async {
    await context.push<void>('/darkom');
    if (mounted) _load();
  }

  void _open(DarkomMission m, {bool daily = false}) {
    final bool open = m.isOpen(_progress.chapter);
    final int times = _stats.done[m.id] ?? 0;
    final bool bonusLeft = daily && !_stats.dailyDone.contains(m.id);
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: _panel,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: m.tierColor.withValues(alpha: 0.6))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Row(children: <Widget>[
                Icon(m.icon, color: m.tierColor, size: 22),
                const SizedBox(width: 8),
                Expanded(child: Text(m.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              Text('${m.theme.name}  |  ${m.tierName}', style: TextStyle(color: m.tierColor, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(m.brief, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                _tag(m.kindLabel, Colors.white70),
                for (final String t in m.tags) _tag(t, const Color(0xFFFF8A65)),
              ]),
              const SizedBox(height: 12),
              Text(
                times == 0
                    ? 'Reward: +${m.points} points on your first clear, then +${max(5, m.points ~/ 4)} on every repeat.'
                    : 'Cleared $times time${times == 1 ? '' : 's'}. Repeats pay +${max(5, m.points ~/ 4)} points.',
                style: const TextStyle(color: _gold, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              if (bonusLeft)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Daily bonus: +60 points on the first clear today.', style: TextStyle(color: Color(0xFF69F0AE), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              if (!open)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Locked. Reach Chapter ${m.district} in the story to open this tier.', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12)),
                ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _pink),
                  onPressed: open
                      ? () {
                          Navigator.of(ctx).pop();
                          _play(m);
                        }
                      : null,
                  child: const Text('START'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.4))),
        child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: <Widget>[
          _header(),
          _tabs(),
          const Divider(height: 1, color: _edge),
          Expanded(
            child: _loading ? const Center(child: CircularProgressIndicator(color: _pink)) : _body(),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    final int total = darkomMissions.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 2),
      child: Row(children: <Widget>[
        IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
        ),
        const Text('MISSION BOARD', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        const Spacer(),
        _pill(Icons.flag_rounded, '${_stats.cleared}/$total', const Color(0xFF40C4FF)),
        const SizedBox(width: 8),
        _pill(Icons.stars_rounded, '${_stats.points} pts', _gold),
      ]),
    );
  }

  Widget _pill(IconData i, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(i, color: c, size: 14),
          const SizedBox(width: 5),
          Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _tabs() {
    final List<MapEntry<int, String>> items = <MapEntry<int, String>>[
      const MapEntry<int, String>(-1, 'Daily'),
      const MapEntry<int, String>(0, 'Story'),
      for (int d = 1; d <= 5; d++) MapEntry<int, String>(d, darkomChapter(d).name),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        children: <Widget>[
          for (final MapEntry<int, String> e in items)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(e.value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _tab == e.key ? Colors.white : Colors.white70)),
                selected: _tab == e.key,
                selectedColor: _pink,
                backgroundColor: _panel,
                side: const BorderSide(color: _edge),
                onSelected: (_) => setState(() => _tab = e.key),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_tab == 0) return _storyTab();
    if (_tab == -1) return _dailyTab();
    return _districtTab(_tab);
  }

  Widget _storyTab() {
    final int ch = _progress.chapter;
    final bool roam = ch >= 6;
    final DarkomChapterDef def = darkomChapter(roam ? 5 : ch);
    return ListView(padding: const EdgeInsets.all(14), children: <Widget>[
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14), border: Border.all(color: _edge)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(roam ? 'Story complete: free roam' : 'Chapter ${def.n}: ${def.name}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(roam ? darkomRoamIntro : '${def.fixer}, ${def.fixerRole}: "${def.intro}"', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          const SizedBox(height: 10),
          Text('Best score ${_progress.bestScore}  |  Kills ${_progress.totalKills}  |  Echo wins ${_progress.echoWins}', style: const TextStyle(color: _muted, fontSize: 12)),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _pink),
              onPressed: _story,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(roam ? 'Play free roam' : 'Continue story'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      const Text(
        'Finishing story chapters opens the higher tiers of each district on the board. The Rookie tier of every district is open from the start.',
        style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
      ),
    ]);
  }

  Widget _dailyTab() {
    final DateTime now = DateTime.now().toUtc();
    final List<DarkomMission> list = darkomDailyMissions(now, _progress.chapter);
    final DateTime next = DateTime.utc(now.year, now.month, now.day).add(const Duration(days: 1));
    final Duration left = next.difference(now);
    return ListView(padding: const EdgeInsets.all(12), children: <Widget>[
      Text(
        'Three new missions every day. Your first clear of each one pays a +${DarkomMission.dailyBonus} point bonus. New set in ${left.inHours} h ${left.inMinutes % 60} min.',
        style: const TextStyle(color: _muted, fontSize: 12, height: 1.4),
      ),
      const SizedBox(height: 10),
      for (final DarkomMission m in list) _card(m, daily: true),
    ]);
  }

  Widget _districtTab(int d) {
    final List<DarkomMission> list = darkomMissionsIn(d);
    final DarkomChapterDef def = darkomChapter(d);
    final int cleared = list.where((DarkomMission m) => _stats.done.containsKey(m.id)).length;
    final List<Widget> out = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text('${def.fixer}, ${def.fixerRole}  |  $cleared/24 cleared', style: const TextStyle(color: _muted, fontSize: 12)),
      ),
    ];
    for (int t = 0; t < 4; t++) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
        child: Row(children: <Widget>[
          Container(width: 4, height: 14, color: darkomTierColors[t]),
          const SizedBox(width: 8),
          Text(darkomTierNames[t].toUpperCase(), style: TextStyle(color: darkomTierColors[t], fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ]),
      ));
      out.add(LayoutBuilder(builder: (BuildContext context, BoxConstraints bc) {
        final int cols = max(1, (bc.maxWidth / 300).floor());
        final double w = (bc.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final DarkomMission m in list.skip(t * 6).take(6)) SizedBox(width: w, child: _card(m)),
        ]);
      }));
    }
    return ListView(padding: const EdgeInsets.all(12), children: out);
  }

  Widget _card(DarkomMission m, {bool daily = false}) {
    final bool open = m.isOpen(_progress.chapter);
    final int times = _stats.done[m.id] ?? 0;
    final bool bonusLeft = daily && !_stats.dailyDone.contains(m.id);
    return Padding(
      padding: EdgeInsets.only(bottom: daily ? 8 : 0),
      child: Material(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(m, daily: daily),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: open ? m.tierColor.withValues(alpha: 0.35) : _edge)),
            child: Row(children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: m.tierColor.withValues(alpha: open ? 0.15 : 0.05), borderRadius: BorderRadius.circular(10)),
                child: Icon(open ? m.icon : Icons.lock_rounded, color: open ? m.tierColor : _muted, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: open ? Colors.white : _muted, fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(daily ? '${m.theme.name}  |  ${m.kindLabel}' : m.kindLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 11)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                Text('+${m.points + (bonusLeft ? DarkomMission.dailyBonus : 0)}', style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                if (times > 0)
                  Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF69F0AE), size: 13),
                    const SizedBox(width: 3),
                    Text('x$times', style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 11, fontWeight: FontWeight.w700)),
                  ])
                else if (!open)
                  const Text('Locked', style: TextStyle(color: _muted, fontSize: 11))
                else
                  const Text('New', style: TextStyle(color: _pink, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
