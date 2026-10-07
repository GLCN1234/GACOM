import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/duel_session.dart';
import '../../../core/services/game_score_service.dart';
import '../../../core/services/sound_service.dart';
import '../edu_progress_recorder.dart';
import '../odyssey/odyssey_engine.dart' show OdyMistake;
import '../odyssey/odyssey_questions.dart';
import '../../../shared/tutorial/how_to_gate.dart';
import '../../../shared/tutorial/how_to_model.dart';
import '../../../shared/tutorial/how_to_registry.dart';
import 'realm_kit.dart';

/// A button drawn at the bottom right that calls [RealmLogic.onAction].
class RealmAction {
  final int id;
  final IconData icon;
  final String label;
  const RealmAction(this.id, this.icon, this.label);
}

typedef RealmPainterBuilder = CustomPainter Function(RealmLogic logic, Listenable repaint);
typedef RealmHudBuilder = Widget Function(BuildContext context, RealmLogic logic, VoidCallback refresh);

/// The common screen around every realm game: loading, intro, pause, music,
/// joystick and keyboard, result screen, saving progress and duels. A game
/// only supplies its [RealmLogic], a painter and optional overlays.
class RealmShell extends StatefulWidget {
  /// Name used for the leaderboard and score saving, such as 'Biome'.
  final String gameName;
  final String title;
  final String story;
  final String howTo;
  final IconData icon;
  final Color accent;
  final RealmConfig config;
  final RealmLogic Function(RealmContent content) create;
  final RealmPainterBuilder painter;
  final RealmHudBuilder? hud;
  final List<RealmAction> actions;
  final bool joystick;
  final double duelSeconds;
  final Color background;

  const RealmShell({
    super.key,
    required this.gameName,
    required this.title,
    required this.story,
    required this.howTo,
    required this.icon,
    required this.accent,
    required this.config,
    required this.create,
    required this.painter,
    this.hud,
    this.actions = const <RealmAction>[],
    this.joystick = true,
    this.duelSeconds = 240,
    this.background = Colors.black,
  });

  @override
  State<RealmShell> createState() => _RealmShellState();
}

class _RealmShellState extends State<RealmShell> with SingleTickerProviderStateMixin {
  RealmContent? _content;
  RealmLogic? _logic;
  bool _loading = true;
  bool _intro = true;
  bool _paused = false;
  bool _ended = false;
  bool _saved = false;
  bool _music = true;
  bool _inDuel = false;
  late final Ticker _ticker;
  Duration? _last;
  int _n = 0;
  int _coinCue = 0;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  Offset? _stickOrigin;
  Offset _stickKnob = Offset.zero;
  Size _size = Size.zero;
  final Set<LogicalKeyboardKey> _keys = <LogicalKeyboardKey>{};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    HeroLook.ensureLoaded();
    _setup();
    _startMusic();
  }

  @override
  void dispose() {
    SoundService.instance.stopBackgroundMusic();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final RealmContent c = await RealmContent.load(widget.config);
    if (!mounted) return;
    _content = c;
    _inDuel = c.inDuel;
    _intro = !c.inDuel;
    _newRun();
    setState(() => _loading = false);
  }

  void _newRun() {
    final RealmContent c = _content!;
    _logic = widget.create(c);
    _ended = false;
    _saved = false;
    _paused = false;
    _last = null;
    _stickOrigin = null;
    _stickKnob = Offset.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  Future<void> _startMusic() async {
    try {
      await SoundService.instance.init();
      _music = SoundService.instance.musicEnabled;
      await SoundService.instance.startBackgroundMusic();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _toggleMusic() {
    _music = !_music;
    SoundService.instance.setMusicEnabled(_music);
    if (_music) SoundService.instance.startBackgroundMusic();
    setState(() {});
  }

  void _playCues(RealmLogic l) {
    if (l.cues.isEmpty) return;
    final SoundService s = SoundService.instance;
    for (final String c in l.cues) {
      switch (c) {
        case 'tap': {
          _coinCue++;
          if (_coinCue % 2 == 0) s.playTap();
          break;
        }
        case 'good': {
          s.playCorrect();
          break;
        }
        case 'bad': {
          s.playWrong();
          break;
        }
        case 'win': {
          s.playWin();
          break;
        }
        case 'lose': {
          s.playLose();
          break;
        }
        default:
          break;
      }
    }
    l.cues.clear();
  }

  void _onTick(Duration elapsed) {
    final RealmLogic? l = _logic;
    if (l == null) return;
    final Duration? prev = _last;
    _last = elapsed;
    if (prev == null || _paused || _ended || _intro) return;
    final double dt = (elapsed - prev).inMicroseconds / 1e6;
    _applyKeys(l);
    l.tick(dt);
    _playCues(l);
    if (_inDuel && l.time >= widget.duelSeconds) l.over = true;
    _frame.value++;
    if (l.over) {
      _finish(l);
    } else if (++_n % 3 == 0 && mounted) {
      setState(() {});
    }
  }

  void _applyKeys(RealmLogic l) {
    if (_keys.isEmpty || _stickOrigin != null || l.modal) return;
    double x = 0;
    double y = 0;
    if (_keys.contains(LogicalKeyboardKey.arrowLeft) || _keys.contains(LogicalKeyboardKey.keyA)) x -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowRight) || _keys.contains(LogicalKeyboardKey.keyD)) x += 1;
    if (_keys.contains(LogicalKeyboardKey.arrowUp) || _keys.contains(LogicalKeyboardKey.keyW)) y -= 1;
    if (_keys.contains(LogicalKeyboardKey.arrowDown) || _keys.contains(LogicalKeyboardKey.keyS)) y += 1;
    l.setInput(x, y);
  }

  void _finish(RealmLogic l) {
    if (_ended) return;
    _ended = true;
    HapticFeedback.heavyImpact();
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: widget.gameName, score: l.finalScore, won: l.stats.correct > 0 ? true : null);
      final int bonus = l.xp - l.stats.correct * 8;
      bool first = true;
      l.stats.askedBy.forEach((String sid, int asked) {
        final int right = l.stats.correctBy[sid] ?? 0;
        EduProgressRecorder.recordSession(
          subject: sid,
          xpEarned: right * 8 + (first ? (bonus > 0 ? bonus : 0) : 0),
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
    final RealmLogic? l = _logic;
    if (o == null || l == null || l.modal) return;
    Offset v = d.localPosition - o;
    const double r = 58;
    if (v.distance > r) v = v / v.distance * r;
    _stickKnob = v;
    l.setInput(v.dx / r, v.dy / r);
  }

  void _panEnd() {
    _stickOrigin = null;
    _stickKnob = Offset.zero;
    _logic?.setInput(0, 0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final RealmLogic? l = _logic;
    if (l == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      _keys.add(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.space && widget.actions.isNotEmpty) {
        l.onAction(widget.actions.first.id);
      }
      if (event.logicalKey == LogicalKeyboardKey.keyE && widget.actions.length > 1) {
        l.onAction(widget.actions[1].id);
      }
      if (event.logicalKey == LogicalKeyboardKey.escape || event.logicalKey == LogicalKeyboardKey.keyP) {
        setState(() => _paused = !_paused);
      }
    } else if (event is KeyUpEvent) {
      _keys.remove(event.logicalKey);
      if (_keys.isEmpty && _stickOrigin == null) l.setInput(0, 0);
    }
    return KeyEventResult.handled;
  }

  String get _howKey => widget.gameName.toLowerCase().replaceAll(' ', '');

  void _showHowTo() {
    final GameHowTo? h = HowToRegistry.byKey(_howKey);
    if (h == null) return;
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (BuildContext c) => HowToScreen(gameKey: _howKey, howTo: h, first: false, onDone: () => Navigator.of(c).pop()),
    ));
  }

  Future<bool> _confirmLeave() async {
    final RealmLogic? l = _logic;
    if (l == null || _ended || _intro || l.time < 8) return true;
    setState(() => _paused = true);
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Leave this realm?', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
        content: const Text('Your run ends here and your result is saved.', style: TextStyle(color: GacomColors.textSecondary)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Leave', style: TextStyle(color: GacomColors.error))),
        ],
      ),
    );
    if (leave == true) {
      if (!_ended && l.stats.asked > 0) {
        l.over = true;
        _finish(l);
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
      context.go('/edu/realms');
    }
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final RealmLogic? l = _logic;
    if (_loading || l == null) {
      return Scaffold(
        backgroundColor: GacomColors.obsidian,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            CircularProgressIndicator(color: widget.accent),
            const SizedBox(height: 16),
            const Text('Building your world...', style: TextStyle(color: GacomColors.textSecondary)),
          ]),
        ),
      );
    }
    return WillPopScope(
      onWillPop: _confirmLeave,
      child: Scaffold(
        backgroundColor: widget.background,
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: Stack(children: <Widget>[
            Positioned.fill(
              child: LayoutBuilder(builder: (BuildContext c, BoxConstraints cons) {
                _size = Size(cons.maxWidth, cons.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (TapUpDetails d) {
                    if (_paused || _ended || _intro) return;
                    l.onTap(d.localPosition, _size);
                  },
                  onPanStart: widget.joystick ? _panStart : null,
                  onPanUpdate: widget.joystick ? _panUpdate : null,
                  onPanEnd: widget.joystick ? (_) => _panEnd() : null,
                  onPanCancel: widget.joystick ? _panEnd : null,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: widget.painter(l, _frame),
                      foregroundPainter: _StickPainter(origin: () => _stickOrigin, knob: () => _stickKnob, repaint: _frame),
                      size: Size.infinite,
                    ),
                  ),
                );
              }),
            ),
            SafeArea(child: _hud(l)),
            if (_intro) _introOverlay(),
            if (_paused && !_ended && !_intro) _pauseOverlay(),
            if (_ended) _resultOverlay(l),
          ]),
        ),
      ),
    );
  }

  Widget _hud(RealmLogic l) {
    final List<RealmChip> chips = l.chips;
    final int hearts = l.hearts;
    // A game HUD that has nothing to show used to return a plain empty box.
    // As the only unpositioned child it shrank this whole Stack to nothing and
    // hid the pause button, hearts and action buttons. Always give the Stack
    // the full screen, and pin any unpositioned game HUD to the top left.
    Widget? gameHud;
    if (widget.hud != null) {
      final Widget built = widget.hud!(context, l, () => setState(() {}));
      gameHud = built is Positioned ? built : Positioned(left: 0, top: 0, child: built);
    }
    return Stack(fit: StackFit.expand, children: <Widget>[
      Positioned(
        left: 12,
        right: 4,
        top: 4,
        child: Row(children: <Widget>[
          if (hearts >= 0)
            Row(children: List<Widget>.generate(l.maxHearts, (int i) {
              final int shown = hearts > 3 ? hearts : 3;
              if (i >= shown) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Icon(i < hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: i < hearts ? const Color(0xFFFF5252) : Colors.white38, size: 24),
              );
            })),
          const Spacer(),
          IconButton(
            icon: Icon(_music ? Icons.music_note_rounded : Icons.music_off_rounded, color: Colors.white, size: 24),
            onPressed: _toggleMusic,
          ),
          IconButton(
            icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white, size: 30),
            onPressed: () => setState(() => _paused = true),
          ),
        ]),
      ),
      Positioned(
        left: 12,
        right: 12,
        top: 50,
        child: Wrap(spacing: 6, runSpacing: 4, children: <Widget>[
          for (final RealmChip c in chips) _pill(c.text, c.icon, c.color),
          if (_inDuel) _pill('${(widget.duelSeconds - l.time).clamp(0.0, 9999.0).ceil()}s', Icons.timer_rounded, Colors.white),
        ]),
      ),
      if (gameHud != null) gameHud,
      if (widget.actions.isNotEmpty && !l.modal)
        Positioned(
          right: 18,
          bottom: 26,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            for (final RealmAction a in widget.actions) _actionButton(l, a),
          ]),
        ),
    ]);
  }

  Widget _actionButton(RealmLogic l, RealmAction a) {
    final double ready = l.actionReady(a.id).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTapDown: (_) => l.onAction(a.id),
        child: SizedBox(
          width: 70,
          height: 70,
          child: Stack(alignment: Alignment.center, children: <Widget>[
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(value: ready, strokeWidth: 5, color: ready >= 1 ? const Color(0xFF69F0AE) : Colors.white54, backgroundColor: Colors.white12),
            ),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.5), border: Border.all(color: Colors.white54)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Icon(a.icon, color: Colors.white, size: 22),
                Text(a.label, style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
      ),
    );
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

  Widget _introOverlay() => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Icon(widget.icon, color: widget.accent, size: 54),
                  const SizedBox(height: 10),
                  Text(widget.title.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(widget.story, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                    child: Text(widget.howTo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.45)),
                  ),
                  const SizedBox(height: 22),
                  _bigButton('BEGIN', () => setState(() {
                        _intro = false;
                        _last = null;
                      })),
                ]),
              ),
            ),
          ),
        ),
      );

  Widget _pauseOverlay() => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const Text('PAUSED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(widget.howTo, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
              ),
              const SizedBox(height: 22),
              _bigButton('RESUME', () => setState(() {
                    _paused = false;
                    _last = null;
                  })),
              if (HowToRegistry.byKey(_howKey) != null) ...<Widget>[
                const SizedBox(height: 10),
                _bigButton('HOW TO PLAY', _showHowTo, secondary: true),
              ],
              const SizedBox(height: 10),
              _bigButton('LEAVE', () async {
                if (await _confirmLeave() && mounted) _exit();
              }, secondary: true),
            ]),
          ),
        ),
      );

  Widget _resultOverlay(RealmLogic l) {
    final RealmStats st = l.stats;
    final int total = l.finalScore;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.86),
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
                  _stat('Correct', '${st.correct}/${st.asked}'),
                  _stat('Accuracy', '${(st.accuracy * 100).round()}%'),
                  _stat('Best streak', '${st.bestStreak}'),
                  _stat('XP', '+${l.xp}'),
                  for (final MapEntry<String, String> e in l.extraStats.entries) _stat(e.key, e.value),
                ]),
                if (st.askedBy.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                    child: Column(children: st.askedBy.entries.map((MapEntry<String, int> en) {
                      final OdySubject s = _content!.subject(en.key);
                      final int right = st.correctBy[en.key] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: <Widget>[
                          Container(width: 9, height: 9, decoration: BoxDecoration(color: realmLighten(s.color, 0.2), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s.label, style: const TextStyle(color: Colors.white, fontSize: 13))),
                          Text('$right / ${en.value}', style: const TextStyle(color: Colors.white70, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
                        ]),
                      );
                    }).toList()),
                  ),
                ],
                if (st.mistakes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerLeft, child: Text('REVIEW', style: TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12))),
                  const SizedBox(height: 6),
                  ...st.mistakes.take(8).map((OdyMistake m) => Container(
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
                if (!_inDuel) _bigButton('PLAY AGAIN', () => setState(_newRun)),
                if (!_inDuel) const SizedBox(height: 10),
                _bigButton(_inDuel ? 'SEND RESULT' : 'EXIT', _exit, secondary: !_inDuel),
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

class _StickPainter extends CustomPainter {
  final Offset? Function() origin;
  final Offset Function() knob;
  _StickPainter({required this.origin, required this.knob, required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset? so = origin();
    if (so == null) return;
    final Paint p = Paint();
    p.color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(so, 58, p);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2;
    p.color = Colors.white.withValues(alpha: 0.35);
    canvas.drawCircle(so, 58, p);
    p.style = PaintingStyle.fill;
    p.color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(so + knob(), 22, p);
  }

  @override
  bool shouldRepaint(covariant _StickPainter oldDelegate) => true;
}
