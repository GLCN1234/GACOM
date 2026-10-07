import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/duel_session.dart';
import '../../../core/services/game_score_service.dart';
import '../edu_progress_recorder.dart';
import 'odyssey_engine.dart';
import 'odyssey_questions.dart';

/// What the player chose in the hub.
class OdysseyConfig {
  /// 'mix' for every subject, or one subject id.
  final String subjectId;
  final bool useSchool;
  const OdysseyConfig({this.subjectId = 'mix', this.useSchool = true});
}

Color _lighten(Color c, double amount) {
  final HSLColor h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness + amount).clamp(0.0, 1.0)).toColor();
}

Color _darken(Color c, double amount) {
  final HSLColor h = HSLColor.fromColor(c);
  return h.withLightness((h.lightness - amount).clamp(0.0, 1.0)).withSaturation((h.saturation * 0.85).clamp(0.0, 1.0)).toColor();
}

class OdysseyScreen extends StatefulWidget {
  final OdysseyConfig config;
  const OdysseyScreen({super.key, this.config = const OdysseyConfig()});
  @override
  State<OdysseyScreen> createState() => _OdysseyScreenState();
}

class _OdysseyScreenState extends State<OdysseyScreen> with SingleTickerProviderStateMixin {
  OdysseyEngine? _engine;
  QuestionPool? _pool;
  List<String> _subjectIds = <String>[];
  Map<String, OdySubject> _subjects = <String, OdySubject>{};
  bool _loading = true;
  bool _schoolUsed = false;
  bool _paused = false;
  bool _ended = false;
  bool _saved = false;
  late final Ticker _ticker;
  Duration? _last;
  int _n = 0;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // controls
  Offset? _stickOrigin;
  Offset _stickKnob = Offset.zero;
  final Set<LogicalKeyboardKey> _keys = <LogicalKeyboardKey>{};

  double? _maxSeconds;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _setup();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final bool inDuel = DuelSession.current != null;
    SchoolContent school = const SchoolContent(<String, List<Map<String, dynamic>>>{}, <String, String>{});
    // Duels use only the built-in questions so both players get the same ones.
    if (widget.config.useSchool && !inDuel) {
      school = await OdysseyData.loadSchool();
    }
    if (!mounted) return;

    final bool mixed = widget.config.subjectId == 'mix';
    List<String> ids;
    if (mixed) {
      if (!school.isEmpty) {
        ids = school.bySubject.keys.toList()..sort();
        _schoolUsed = true;
      } else {
        ids = odySubjects.map((OdySubject s) => s.id).toList();
      }
    } else {
      ids = <String>[widget.config.subjectId];
      _schoolUsed = school.bySubject.containsKey(widget.config.subjectId);
    }
    final Map<String, OdySubject> subs = <String, OdySubject>{};
    for (final String id in ids) {
      subs[id] = odySubjectById(id, school.labels[id]);
    }
    final Random rng = duelRandom();
    _pool = QuestionPool(rng: rng, school: school.bySubject);
    _subjectIds = ids;
    _subjects = subs;
    _maxSeconds = inDuel ? 150 : null;
    _startRun();
    setState(() => _loading = false);
  }

  void _startRun() {
    final Random rng = duelRandom();
    final OdysseyEngine e = OdysseyEngine(
      pool: _pool!,
      subjects: _subjectIds,
      mixed: widget.config.subjectId == 'mix' && _subjectIds.length > 1,
      seed: rng.nextInt(1 << 30),
      rng: rng,
    );
    _engine = e;
    _ended = false;
    _saved = false;
    _paused = false;
    _last = null;
    _stickOrigin = null;
    _stickKnob = Offset.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final OdysseyEngine? e = _engine;
    if (e == null) return;
    final Duration? prev = _last;
    _last = elapsed;
    if (prev == null || _paused || _ended) {
      return;
    }
    final double dt = (elapsed - prev).inMicroseconds / 1e6;
    _applyKeys(e);
    e.step(dt);
    if (_maxSeconds != null && e.time >= _maxSeconds!) e.over = true;
    _frame.value++;
    if (e.novaFlash) HapticFeedback.mediumImpact();
    if (e.over) {
      _finish(e);
    } else if (++_n % 3 == 0 && mounted) {
      setState(() {});
    }
  }

  void _applyKeys(OdysseyEngine e) {
    if (_keys.isEmpty) return;
    double x = 0;
    double y = 0;
    if (_keys.contains(LogicalKeyboardKey.arrowLeft) || _keys.contains(LogicalKeyboardKey.keyA)) x -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowRight) || _keys.contains(LogicalKeyboardKey.keyD)) x += 1;
    if (_keys.contains(LogicalKeyboardKey.arrowUp) || _keys.contains(LogicalKeyboardKey.keyW)) y -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowDown) || _keys.contains(LogicalKeyboardKey.keyS)) y += 1;
    if (_stickOrigin == null) e.setInput(x, y);
  }

  void _finish(OdysseyEngine e) {
    if (_ended) return;
    _ended = true;
    HapticFeedback.heavyImpact();
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: 'Odyssey', score: e.finalScore, won: e.correct > 0 ? true : null);
      final int bonus = e.xp - e.correct * 8;
      bool first = true;
      e.askedBy.forEach((String sid, int asked) {
        final int right = e.correctBy[sid] ?? 0;
        EduProgressRecorder.recordSession(
          subject: sid,
          xpEarned: right * 8 + (first ? bonus : 0),
          questionsAnswered: asked,
          correctAnswers: right,
        );
        first = false;
      });
    }
    if (mounted) setState(() {});
  }

  // ---- controls -----------------------------------------------------------

  void _panStart(DragStartDetails d) {
    _stickOrigin = d.localPosition;
    _stickKnob = Offset.zero;
  }

  void _panUpdate(DragUpdateDetails d) {
    final Offset? o = _stickOrigin;
    final OdysseyEngine? e = _engine;
    if (o == null || e == null) return;
    Offset v = d.localPosition - o;
    const double r = 58;
    if (v.distance > r) v = v / v.distance * r;
    _stickKnob = v;
    e.setInput(v.dx / r, v.dy / r);
  }

  void _panEnd() {
    _stickOrigin = null;
    _stickKnob = Offset.zero;
    _engine?.setInput(0, 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final OdysseyEngine? e = _engine;
    if (e == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _keys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.shiftLeft) {
        if (e.tryDash()) HapticFeedback.lightImpact();
      }
      if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.keyP) {
        setState(() => _paused = !_paused);
      }
    } else if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
      if (_keys.isEmpty && _stickOrigin == null) e.setInput(0, 0);
    }
    return KeyEventResult.handled;
  }

  Future<bool> _confirmLeave() async {
    final OdysseyEngine? e = _engine;
    if (e == null || _ended || e.asked == 0 && e.time < 5) return true;
    setState(() => _paused = true);
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Leave the world?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
        content: const Text('Your run ends here and your result is saved.', style: TextStyle(color: GacomColors.textSecondary)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep exploring')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: GacomColors.error))),
        ],
      ),
    );
    if (leave == true) {
      if (!_ended && e.asked > 0) {
        e.over = true;
        _finish(e);
      }
      return true;
    }
    if (mounted) setState(() => _paused = false);
    return false;
  }

  void _exit() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/edu/odyssey');
    }
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading || _engine == null) {
      return const Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            CircularProgressIndicator(color: GacomColors.deepOrange),
            SizedBox(height: 16),
            Text('Building your world...', style: TextStyle(color: GacomColors.textSecondary)),
          ]),
        ),
      );
    }
    final OdysseyEngine e = _engine!;
    return WillPopScope(
      onWillPop: _confirmLeave,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _panStart,
                onPanUpdate: _panUpdate,
                onPanEnd: (_) => _panEnd(),
                onPanCancel: _panEnd,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _WorldPainter(engine: e, subjects: _subjects, repaint: _frame, stickOrigin: () => _stickOrigin, stickKnob: () => _stickKnob),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            SafeArea(child: _hud(e)),
            if (_paused && !_ended) _pauseOverlay(),
            if (_ended) _resultOverlay(e),
          ]),
        ),
      ),
    );
  }

  Widget _hud(OdysseyEngine e) {
    final String region = e.subjectAt(e.px, e.py);
    final OdySubject rs = _subjects[region] ?? odySubjectById(region);
    final OdyActive? a = e.active;
    return Stack(children: <Widget>[
      // top-left: hearts and score
      Positioned(
        left: 12,
        top: 8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: List<Widget>.generate(OdysseyEngine.maxHearts, (int i) {
            if (i >= max(3, e.hearts)) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(i < e.hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: i < e.hearts ? const Color(0xFFFF5252) : Colors.white38, size: 22),
            );
          })),
          const SizedBox(height: 4),
          _pill('${e.score + e.distance ~/ 40}', Icons.star_rounded, GacomColors.gold),
          const SizedBox(height: 4),
          _pill(rs.label, Icons.place_rounded, _lighten(rs.color, 0.25)),
        ]),
      ),
      // top-right: pause and streak
      Positioned(
        right: 8,
        top: 4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
          IconButton(
            icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 30),
            onPressed: () => setState(() => _paused = true),
          ),
          if (e.streak >= 2) _pill('x${e.streak} streak', Icons.local_fire_department_rounded, const Color(0xFFFF9800)),
          if (_maxSeconds != null) ...<Widget>[
            const SizedBox(height: 4),
            _pill('${max(0, (_maxSeconds! - e.time).ceil())}s', Icons.timer_rounded, Colors.white),
          ],
        ]),
      ),
      // question card
      if (a != null)
        Positioned(
          left: 70,
          right: 70,
          top: 6,
          child: _questionCard(a, _subjects[a.q.subject] ?? odySubjectById(a.q.subject)),
        )
      else
        Positioned(
          left: 0,
          right: 0,
          top: 12,
          child: Center(child: _pill('Explore. A challenge is coming', Icons.explore_rounded, Colors.white70)),
        ),
      // toasts
      Positioned(
        left: 0,
        right: 0,
        top: a != null ? 120 : 52,
        child: Column(children: e.toasts.map((OdyToast t) => Opacity(
              opacity: t.life.clamp(0.0, 1.0),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: (t.good ? const Color(0xFF2E7D32) : const Color(0xFFC62828)).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                child: Text(t.text, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            )).toList()),
      ),
      // dash button
      Positioned(
        right: 20,
        bottom: 26,
        child: GestureDetector(
          onTapDown: (_) {
            if (e.tryDash()) HapticFeedback.lightImpact();
          },
          child: SizedBox(
            width: 74,
            height: 74,
            child: Stack(alignment: Alignment.center, children: <Widget>[
              SizedBox(
                width: 74,
                height: 74,
                child: CircularProgressIndicator(value: e.dashReady, strokeWidth: 5, color: e.dashReady >= 1 ? const Color(0xFF69F0AE) : Colors.white54, backgroundColor: Colors.white12),
              ),
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5), border: Border.all(color: Colors.white54)),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _pill(String text, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );

  Widget _questionCard(OdyActive a, OdySubject s) {
    final double frac = (a.timeLeft / a.total).clamp(0.0, 1.0);
    final Color c = _lighten(s.color, 0.25);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c, width: 1.4),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Row(children: <Widget>[
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(s.label.toUpperCase() + (a.q.fromSchool && a.q.topic.isNotEmpty ? '  /  ${a.q.topic}' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8))),
        ]),
        const SizedBox(height: 4),
        Text(a.q.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: frac, minHeight: 5, backgroundColor: Colors.white12, color: frac > 0.3 ? c : const Color(0xFFFF5252)),
        ),
        const SizedBox(height: 4),
        const Text('Run into the glowing orb with the right answer', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
      ]),
    );
  }

  Widget _pauseOverlay() => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('PAUSED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 8),
              const Text('Drag anywhere to move. Tap the bolt to dash.\nOn a keyboard: arrows or WASD, space to dash.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
              const SizedBox(height: 22),
              _bigButton('RESUME', () => setState(() => _paused = false)),
              const SizedBox(height: 10),
              _bigButton('LEAVE', () async {
                if (await _confirmLeave() && mounted) _exit();
              }, secondary: true),
            ]),
          ),
        ),
      );

  Widget _bigButton(String label, VoidCallback onTap, {bool secondary = false}) => SizedBox(
        width: 220,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: secondary ? Colors.white12 : GacomColors.deepOrange,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
          onPressed: onTap,
          child: Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      );

  Widget _resultOverlay(OdysseyEngine e) {
    final int total = e.finalScore;
    final double acc = e.asked == 0 ? 0 : e.correct / e.asked;
    final bool inDuel = DuelSession.current != null;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                const Text('RUN COMPLETE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('$total', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 54, color: GacomColors.deepOrange)),
                const SizedBox(height: 6),
                Wrap(alignment: WrapAlignment.center, spacing: 18, runSpacing: 8, children: <Widget>[
                  _stat('Correct', '${e.correct}/${e.asked}'),
                  _stat('Accuracy', '${(acc * 100).round()}%'),
                  _stat('Best streak', '${e.bestStreak}'),
                  _stat('XP', '+${e.xp}'),
                ]),
                if (e.askedBy.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                    child: Column(children: e.askedBy.entries.map((MapEntry<String, int> en) {
                      final OdySubject s = _subjects[en.key] ?? odySubjectById(en.key);
                      final int right = e.correctBy[en.key] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: <Widget>[
                          Container(width: 9, height: 9, decoration: BoxDecoration(color: _lighten(s.color, 0.2), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.label, style: const TextStyle(color: Colors.white, fontSize: 13))),
                          Text('$right / ${en.value}', style: const TextStyle(color: Colors.white70, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
                        ]),
                      );
                    }).toList()),
                  ),
                ],
                if (e.mistakes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text('REVIEW', style: TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12))),
                  const SizedBox(height: 6),
                  ...e.mistakes.take(8).map((OdyMistake m) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          Text(m.question, style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.3)),
                          const SizedBox(height: 4),
                          Text('Right answer: ${m.correct}', style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 12, fontWeight: FontWeight.w700)),
                          if (m.chosen != 'No answer') Text('You chose: ${m.chosen}', style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11.5)),
                        ]),
                      )),
                ],
                const SizedBox(height: 18),
                if (!inDuel) _bigButton('PLAY AGAIN', () => setState(_startRun)),
                if (!inDuel) const SizedBox(height: 10),
                _bigButton(inDuel ? 'SEND RESULT' : 'EXIT', _exit, secondary: !inDuel),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(children: <Widget>[
        Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ]);
}

// ---------------------------------------------------------------------------

class _WorldPainter extends CustomPainter {
  final OdysseyEngine engine;
  final Map<String, OdySubject> subjects;
  final Offset? Function() stickOrigin;
  final Offset Function() stickKnob;
  static const double tile = 150;
  final Map<String, List<Color>> _ground = <String, List<Color>>{};
  final Paint _p = Paint();

  _WorldPainter({required this.engine, required this.subjects, required Listenable repaint, required this.stickOrigin, required this.stickKnob}) : super(repaint: repaint);

  OdySubject _subj(String id) => subjects[id] ?? odySubjectById(id);

  List<Color> _groundFor(String id) {
    return _ground.putIfAbsent(id, () {
      final Color base = _subj(id).color;
      final Color a = _darken(base, 0.28);
      return <Color>[a, _lighten(a, 0.035), _lighten(a, 0.07), _darken(a, 0.04)];
    });
  }

  int _h(int a, int b) {
    int h = (a * 374761393) ^ (b * 668265263);
    h = (h ^ (h >> 13)) & 0x7fffffff;
    h = (h * 1274126177) & 0x7fffffff;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double px = engine.px;
    final double py = engine.py;
    canvas.save();
    canvas.translate(w / 2 - px, h / 2 - py);

    final int x0 = ((px - w / 2) / tile).floor() - 1;
    final int x1 = ((px + w / 2) / tile).floor() + 1;
    final int y0 = ((py - h / 2) / tile).floor() - 1;
    final int y1 = ((py + h / 2) / tile).floor() + 1;

    // ground and scenery
    for (int ix = x0; ix <= x1; ix++) {
      for (int iy = y0; iy <= y1; iy++) {
        final double cx = ix * tile + tile / 2;
        final double cy = iy * tile + tile / 2;
        final String sid = engine.subjectAt(cx, cy);
        final List<Color> g = _groundFor(sid);
        final int hh = _h(ix, iy);
        _p.color = g[hh & 3];
        canvas.drawRect(Rect.fromLTWH(ix * tile - 0.5, iy * tile - 0.5, tile + 1, tile + 1), _p);
        if (hh % 100 < 34) {
          final double ox = ix * tile + 20 + (hh >> 5) % (tile.toInt() - 40);
          final double oy = iy * tile + 20 + (hh >> 11) % (tile.toInt() - 40);
          _decor(canvas, sid, (hh >> 3) % 4, ox, oy, hh);
        }
      }
    }

    // crystals
    for (final OdyCrystal c in engine.crystalList) {
      final Path d = Path()
        ..moveTo(c.x, c.y - 11)
        ..lineTo(c.x + 8, c.y)
        ..lineTo(c.x, c.y + 11)
        ..lineTo(c.x - 8, c.y)
        ..close();
      _p.color = const Color(0xFF80DEEA).withValues(alpha: 0.25);
      canvas.drawCircle(Offset(c.x, c.y), 16 + sin(engine.time * 5 + c.x) * 2, _p);
      _p.color = const Color(0xFFB2EBF2);
      canvas.drawPath(d, _p);
    }

    // orbs
    final OdyActive? act = engine.active;
    if (act != null) {
      final OdySubject s = _subj(act.q.subject);
      final Color glow = _lighten(s.color, 0.3);
      for (final OdyOrb o in act.orbs) {
        _p.color = glow.withValues(alpha: 0.22);
        canvas.drawCircle(Offset(o.x, o.y), OdysseyEngine.orbRadius + 12 + sin(engine.time * 4 + o.phase) * 3, _p);
        _p.color = glow;
        canvas.drawCircle(Offset(o.x, o.y), OdysseyEngine.orbRadius, _p);
        _p.color = Colors.black.withValues(alpha: 0.35);
        canvas.drawCircle(Offset(o.x, o.y), OdysseyEngine.orbRadius - 5, _p);
        _text(canvas, String.fromCharCode(65 + o.index), Offset(o.x, o.y), 20, Colors.white, true, 60);
        _label(canvas, o.label, Offset(o.x, o.y + OdysseyEngine.orbRadius + 8));
      }
    }

    // enemies
    for (final OdyEnemy e in engine.enemies) {
      final double wob = sin(engine.time * 6 + e.phase) * 1.5;
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.2);
      canvas.drawCircle(Offset(e.x, e.y), 22 + wob, _p);
      _p.color = const Color(0xFF1A1030);
      canvas.drawCircle(Offset(e.x, e.y), OdysseyEngine.enemyRadius + wob * 0.4, _p);
      _p.color = const Color(0xFFFF5252);
      final double ex = (px - e.x);
      final double ey = (py - e.y);
      final double d = max(1.0, sqrt(ex * ex + ey * ey));
      final double lx = ex / d * 3;
      final double ly = ey / d * 3;
      canvas.drawCircle(Offset(e.x - 4 + lx, e.y - 2 + ly), 2.6, _p);
      canvas.drawCircle(Offset(e.x + 4 + lx, e.y - 2 + ly), 2.6, _p);
    }

    // player
    final bool blink = engine.invuln > 0 && ((engine.time * 14).floor() % 2 == 0);
    if (engine.dashing) {
      for (int i = 1; i <= 4; i++) {
        _p.color = Colors.white.withValues(alpha: 0.18 / i);
        canvas.drawCircle(Offset(px - engine.dashDirX * 16 * i, py - engine.dashDirY * 16 * i), OdysseyEngine.playerRadius, _p);
      }
    }
    if (!blink) {
      _p.color = Colors.black.withValues(alpha: 0.3);
      canvas.drawOval(Rect.fromCenter(center: Offset(px, py + 12), width: 26, height: 10), _p);
      _p.color = const Color(0xFFFF8A33).withValues(alpha: 0.28);
      canvas.drawCircle(Offset(px, py), 24, _p);
      _p.color = const Color(0xFFFFF3E0);
      canvas.drawCircle(Offset(px, py), OdysseyEngine.playerRadius, _p);
      _p.color = const Color(0xFFFF6A00);
      canvas.drawCircle(Offset(px + engine.facingX * 6, py + engine.facingY * 6), 6, _p);
    }
    canvas.restore();

    // off-screen answer arrows
    if (act != null) {
      for (final OdyOrb o in act.orbs) {
        final double sx = o.x - px + w / 2;
        final double sy = o.y - py + h / 2;
        if (sx < 24 || sx > w - 24 || sy < 120 || sy > h - 24) {
          final double cx = sx.clamp(26.0, w - 26.0);
          final double cy = sy.clamp(130.0, h - 26.0);
          _p.color = _lighten(_subj(act.q.subject).color, 0.3);
          canvas.drawCircle(Offset(cx, cy), 15, _p);
          _text(canvas, String.fromCharCode(65 + o.index), Offset(cx, cy), 15, Colors.black, true, 40);
        }
      }
    }

    // joystick
    final Offset? so = stickOrigin();
    if (so != null) {
      _p.color = Colors.white.withValues(alpha: 0.12);
      canvas.drawCircle(so, 58, _p);
      _p.style = PaintingStyle.stroke;
      _p.strokeWidth = 2;
      _p.color = Colors.white.withValues(alpha: 0.35);
      canvas.drawCircle(so, 58, _p);
      _p.style = PaintingStyle.fill;
      _p.color = Colors.white.withValues(alpha: 0.55);
      canvas.drawCircle(so + stickKnob(), 22, _p);
    }
  }

  void _decor(Canvas canvas, String sid, int type, double x, double y, int hh) {
    final Color base = _subj(sid).color;
    final Color light = _lighten(base, 0.18);
    switch (type) {
      case 0: {
        // plant or tree
        _p.color = Colors.black.withValues(alpha: 0.25);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 14), width: 34, height: 11), _p);
        _p.color = _darken(base, 0.18);
        canvas.drawRect(Rect.fromLTWH(x - 3, y - 2, 6, 16), _p);
        _p.color = light.withValues(alpha: 0.9);
        canvas.drawCircle(Offset(x, y - 8), 15, _p);
        _p.color = _lighten(light, 0.08).withValues(alpha: 0.7);
        canvas.drawCircle(Offset(x - 4, y - 11), 8, _p);
        break;
      }
      case 1: {
        // rock
        _p.color = Colors.black.withValues(alpha: 0.25);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 9), width: 30, height: 9), _p);
        _p.color = _darken(base, 0.1).withValues(alpha: 0.95);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 28, height: 20), const Radius.circular(8)), _p);
        _p.color = light.withValues(alpha: 0.4);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 10, y - 8, 12, 5), const Radius.circular(3)), _p);
        break;
      }
      case 2: {
        // crystal shard
        final Path s = Path()
          ..moveTo(x, y - 18)
          ..lineTo(x + 7, y + 4)
          ..lineTo(x, y + 10)
          ..lineTo(x - 7, y + 4)
          ..close();
        _p.color = light.withValues(alpha: 0.35);
        canvas.drawCircle(Offset(x, y - 2), 16, _p);
        _p.color = _lighten(base, 0.3).withValues(alpha: 0.9);
        canvas.drawPath(s, _p);
        break;
      }
      default: {
        // glowing rune ring
        _p.style = PaintingStyle.stroke;
        _p.strokeWidth = 3;
        _p.color = light.withValues(alpha: 0.45);
        canvas.drawCircle(Offset(x, y), 16, _p);
        _p.strokeWidth = 1.5;
        canvas.drawCircle(Offset(x, y), 8, _p);
        _p.style = PaintingStyle.fill;
        break;
      }
    }
  }

  void _text(Canvas canvas, String text, Offset center, double size, Color color, bool bold, double maxW) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontFamily: 'Rajdhani')),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _label(Canvas canvas, String text, Offset topCenter) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.15)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: 150);
    final Rect r = Rect.fromLTWH(topCenter.dx - tp.width / 2 - 8, topCenter.dy - 2, tp.width + 16, tp.height + 8);
    _p.color = Colors.black.withValues(alpha: 0.72);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), _p);
    tp.paint(canvas, Offset(r.left + 8, r.top + 4));
  }

  @override
  bool shouldRepaint(covariant _WorldPainter oldDelegate) => true;
}
