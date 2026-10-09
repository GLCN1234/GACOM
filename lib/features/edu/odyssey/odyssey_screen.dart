import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/duel_session.dart';
import '../../../core/services/game_score_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../shared/fx/feedback_fx.dart';
import '../../../shared/widgets/cosmetic_avatar.dart' show paintCosmeticTrail;
import '../edu_progress_recorder.dart';
import '../realms/realm_kit.dart' show HeroLook, ObjectiveArrowPainter, RealmDraw, realmDarken, realmLighten;
import 'odyssey_engine.dart';
import 'odyssey_questions.dart';
import '../../journey/journey_result_card.dart';
import '../../journey/journey_service.dart';

/// What the player chose in the hub.
class OdysseyConfig {
  /// 'mix' for every subject, or one subject id.
  final String subjectId;
  final bool useSchool;

  /// The Journey world this run reports to ('odyssey' or one of the new worlds).
  final String realmId;

  /// Optional skin of the intro screen for the Journey worlds.
  final Color? accent;
  final String? title;
  final String? story;
  const OdysseyConfig({this.subjectId = 'mix', this.useSchool = true, this.realmId = 'odyssey', this.accent, this.title, this.story});
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
  bool _intro = false;
  bool _inDuel = false;
  bool _ended = false;
  bool _saved = false;
  JourneyRunResult? _journey;
  late final Ticker _ticker;
  Duration? _last;
  int _n = 0;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // controls
  Offset? _stickOrigin;
  Offset _stickKnob = Offset.zero;
  final Set<LogicalKeyboardKey> _keys = <LogicalKeyboardKey>{};

  double? _maxSeconds;
  bool _music = true;
  int _coinCue = 0;

  @override
  void initState() {
    super.initState();
    HeroLook.ensureLoaded();
    _ticker = createTicker(_onTick);
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

  void _playCues(OdysseyEngine e) {
    if (e.cues.isEmpty) return;
    final SoundService s = SoundService.instance;
    for (final String c in e.cues) {
      switch (c) {
        case 'coin': {
          _coinCue++;
          if (_coinCue % 2 == 0) s.playTap();
          break;
        }
        case 'gate': {
          s.playTap();
          break;
        }
        case 'star':
        case 'shield':
        case 'nova': {
          s.playWin();
          if (mounted && c == 'nova') FeedbackFx.play(context, FxKind.reward, color: const Color(0xFFF6B93B));
          break;
        }
        case 'correct': {
          s.playCorrect();
          if (mounted) {
            FeedbackFx.play(context, FxKind.correct);
            final int st = e.streak;
            if (st == 3 || st == 5 || st == 10) FeedbackFx.combo(context, st);
          }
          break;
        }
        case 'hero': {
          _saveHero(e);
          s.playWin();
          if (mounted) FeedbackFx.play(context, FxKind.levelUp);
          break;
        }
        case 'wrong':
        case 'hurt': {
          s.playWrong();
          if (mounted && c == 'wrong') FeedbackFx.play(context, FxKind.wrong);
          break;
        }
        default:
          break;
      }
    }
    e.cues.clear();
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
    _maxSeconds = inDuel ? 240 : null;
    _inDuel = inDuel;
    _intro = !inDuel;
    _startRun();
    setState(() => _loading = false);
  }

  static const String _heroKey = 'ody_hero_xp';

  Future<void> _loadHero(OdysseyEngine e) async {
    if (_inDuel) return;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final int xp = p.getInt(_heroKey) ?? 0;
      if (mounted && identical(_engine, e) && e.heroXp == 0) e.loadHero(xp);
    } catch (_) {}
  }

  Future<void> _saveHero(OdysseyEngine e) async {
    if (_inDuel) return;
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      if (e.heroXp > (p.getInt(_heroKey) ?? 0)) await p.setInt(_heroKey, e.heroXp);
    } catch (_) {}
  }

  void _startRun() {
    final Random rng = duelRandom();
    final OdysseyEngine e = OdysseyEngine(
      pool: _pool!,
      subjects: _subjectIds,
      mixed: widget.config.subjectId == 'mix' && _subjectIds.length > 1,
      seed: rng.nextInt(1 << 30),
      rng: rng,
      allowRest: !_inDuel,
      labels: <String, String>{for (final MapEntry<String, OdySubject> en in _subjects.entries) en.key: en.value.label},
    );
    _engine = e;
    _loadHero(e);
    _ended = false;
    _saved = false;
    _journey = null;
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
    if (prev == null || _paused || _ended || _intro) {
      return;
    }
    final double dt = (elapsed - prev).inMicroseconds / 1e6;
    _applyKeys(e);
    e.step(dt);
    _playCues(e);
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

  /// Sends the run's numbers to Journey once. Never during a duel.
  Future<void> _reportJourney(OdysseyEngine e) async {
    if (_inDuel) return;
    final JourneyRunResult? r = await JourneyService.reportRun(widget.config.realmId, asked: e.asked, correct: e.correct, bestStreak: e.bestStreak);
    if (!mounted || !identical(_engine, e)) return;
    setState(() => _journey = r);
  }

  void _finish(OdysseyEngine e) {
    if (_ended) return;
    _ended = true;
    HapticFeedback.heavyImpact();
    if (!_saved) {
      _saved = true;
      _saveHero(e);
      _reportJourney(e);
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
            if (e.gate != null && !_ended) _gateOverlay(e),
            if (_intro) _introOverlay(),
            if (_paused && !_ended) _pauseOverlay(),
            if (_ended) _resultOverlay(e),
          ]),
        ),
      ),
    );
  }

  Color get _accent => widget.config.accent ?? const Color(0xFF69F0AE);

  /// What to do next and an arrow towards it: the nearest coin or star for
  /// the current quest, otherwise the nearest coin.
  List<Widget> _objectiveLayer(OdysseyEngine e) {
    final OdyQuest? q = e.quest;
    final OdyRestMission? rm = e.restMission;
    String text;
    Offset? target;
    double best = double.infinity;
    void consider(double x, double y) {
      final double dx = x - e.px;
      final double dy = y - e.py;
      final double d = dx * dx + dy * dy;
      if (d < best) {
        best = d;
        target = Offset(dx, dy);
      }
    }

    if (rm != null && e.resting) {
      final int shown = rm.progress > rm.target ? rm.target : rm.progress;
      text = e.restMissionDone ? 'Mission done. Tap READY for your question' : 'Rest mission: ${rm.title}  $shown/${rm.target}';
      if (!e.restMissionDone && rm.kind == 'coins') {
        for (final OdyCrystal c in e.crystalList) {
          consider(c.x, c.y);
        }
      } else if (!e.restMissionDone && rm.kind == 'stars') {
        for (final OdyStar st in e.starList) {
          consider(st.x, st.y);
        }
      }
    } else if (q != null && q.kind == 'stars') {
      text = 'Find a star. Follow the arrow';
      for (final OdyStar s in e.starList) {
        consider(s.x, s.y);
      }
    } else if (q != null && q.kind == 'coins') {
      text = '${q.title}  ${q.progress > q.target ? q.target : q.progress}/${q.target}';
      for (final OdyCrystal c in e.crystalList) {
        consider(c.x, c.y);
      }
    } else if (q != null) {
      text = '${q.title}  ${q.progress > q.target ? q.target : q.progress}/${q.target}';
    } else {
      text = 'Collect coins and answer the glowing orbs to score';
      for (final OdyCrystal c in e.crystalList) {
        consider(c.x, c.y);
      }
    }
    final Offset? t = target;
    final double dist = sqrt(best);
    return <Widget>[
      Positioned(
        left: 12,
        right: 12,
        top: 84,
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xCC0B0B0F), borderRadius: BorderRadius.circular(14), border: Border.all(color: _accent, width: 1.2)),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(Icons.flag_rounded, color: _accent, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.25, fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      ),
      if (t != null && dist > 120)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: ObjectiveArrowPainter(delta: t, color: _accent, label: '${(dist / 10).round()} m')),
          ),
        ),
    ];
  }

  Widget _hud(OdysseyEngine e) {
    final Size sz = MediaQuery.of(context).size;
    final bool land = sz.width > sz.height;
    e.viewHalfH = sz.height / 2;
    final String region = e.subjectAt(e.px, e.py);
    final OdySubject rs = _subjects[region] ?? odySubjectById(region);
    final OdyActive? a = e.active;
    return Stack(children: <Widget>[
      // top bar: hearts, music, pause
      Positioned(
        left: 12,
        right: 4,
        top: 4,
        child: Row(children: <Widget>[
          Row(children: List<Widget>.generate(OdysseyEngine.maxHearts, (int i) {
            if (i >= max(3, e.hearts)) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(i < e.hearts ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: i < e.hearts ? const Color(0xFFFF5252) : Colors.white38, size: 24),
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
      // stats row
      Positioned(
        left: 12,
        right: 12,
        top: 50,
        child: Wrap(spacing: 6, runSpacing: 4, children: <Widget>[
          if (!_inDuel) _heroBar(e),
          _pill('${e.score + e.distance ~/ 40}', Icons.star_rounded, GacomColors.gold),
          _pill('${e.crystals} coins', Icons.monetization_on_rounded, const Color(0xFFFFD54F)),
          _pill(rs.label, Icons.place_rounded, _lighten(rs.color, 0.25)),
          if (e.streak >= 2) _pill('x${e.streak}', Icons.local_fire_department_rounded, const Color(0xFFFF9800)),
          if (e.shield > 0) _pill('Shield ${e.shield.ceil()}s', Icons.shield_rounded, const Color(0xFF40C4FF)),
          if (e.quest != null) _pill('${e.quest!.title}  ${e.quest!.progress > e.quest!.target ? e.quest!.target : e.quest!.progress}/${e.quest!.target}', Icons.flag_rounded, const Color(0xFF69F0AE)),
          if (e.resting) _pill('Free roam ${_clock(e.freeLeft)}', Icons.self_improvement_rounded, const Color(0xFF80D8FF)),
          if (e.resting && e.restMission != null)
            _pill(e.restMissionDone ? 'Mission done' : '${e.restMission!.title}  ${e.restMission!.progress > e.restMission!.target ? e.restMission!.target : e.restMission!.progress}/${e.restMission!.target}', Icons.flag_circle_rounded, e.restMissionDone ? const Color(0xFF69F0AE) : const Color(0xFFFFD54F)),
          if (_maxSeconds != null) _pill('${max(0, (_maxSeconds! - e.time).ceil())}s', Icons.timer_rounded, Colors.white),
        ]),
      ),
      if (a == null && e.gate == null && !_paused && !_ended) ..._objectiveLayer(e),
      // question card
      if (a != null)
        Positioned(
          left: 10,
          right: land ? null : 10,
          width: land ? min(sz.width * 0.5, 440.0) : null,
          top: land ? 62 : 88,
          child: _questionCard(a, _subjects[a.q.subject] ?? odySubjectById(a.q.subject)),
        )
      else
        Positioned(
          left: 0,
          right: 0,
          top: 92,
          child: Center(child: _pill('Explore, collect coins and stars', Icons.explore_rounded, Colors.white70)),
        ),
      // toasts
      Positioned(
        left: land && a != null ? sz.width * 0.56 : 0,
        right: land && a != null ? 70 : 0,
        top: land ? (a != null ? 96 : 100) : (a != null ? 232 : 128),
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
      // rest and ask buttons
      if (!_inDuel && e.gate == null)
        Positioned(
          left: 16,
          bottom: 30,
          child: e.resting
              ? (e.restMissionDone
                  ? _roundAction(Icons.lightbulb_rounded, 'READY', const Color(0xFFFFD54F), () => setState(e.readyNow))
                  : _roundAction(Icons.help_outline_rounded, 'ASK ME', const Color(0xFF69F0AE), () => e.askNow()))
              : (a == null ? _roundAction(Icons.self_improvement_rounded, 'REST', const Color(0xFF80D8FF), _openRest) : const SizedBox.shrink()),
        ),
      if (!_inDuel && e.gate == null)
        Positioned(
          left: 16,
          bottom: 84,
          child: _roundAction(Icons.assignment_turned_in_rounded, 'MISSIONS', const Color(0xFFFFD54F), _openMissions),
        ),
      if (e.banner.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(context).size.width > MediaQuery.of(context).size.height ? 110 : 190,
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: e.bannerLife.clamp(0.0, 1.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xE60B0B0F),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFFFD54F), width: 2),
                  ),
                  child: Text(e.banner, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD54F), fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: 1.2)),
                ),
              ),
            ),
          ),
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

  static const List<Color> _tierColors = <Color>[
    Color(0xFFB0BEC5), Color(0xFF81C784), Color(0xFF4FC3F7), Color(0xFFBA68C8), Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFFFD54F), Color(0xFFFFF59D),
  ];

  Widget _heroBar(OdysseyEngine e) {
    final Color c = _tierColors[e.heroTier];
    final double frac = e.heroXpNeed == 0 ? 0 : (e.heroXpInLevel / e.heroXpNeed).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20), border: Border.all(color: c, width: 1.4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(Icons.shield_moon_rounded, size: 15, color: c),
        const SizedBox(width: 5),
        Text('Lv ${e.heroLevel}  ${e.heroRank}', style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(width: 7),
        SizedBox(
          width: 54,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: frac, minHeight: 5, backgroundColor: Colors.white12, color: c),
          ),
        ),
      ]),
    );
  }

  Future<void> _openMissions() async {
    final OdysseyEngine? e = _engine;
    if (e == null) return;
    setState(() => _paused = true);
    Widget row(String title, int p, int t, String reward) {
      final int shown = p > t ? t : p;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(title, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700))),
            Text('$shown/$t', style: const TextStyle(color: GacomColors.textSecondary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: t == 0 ? 0 : (shown / t).clamp(0.0, 1.0), minHeight: 6, backgroundColor: Colors.white12, color: const Color(0xFFFFD54F)),
          ),
          const SizedBox(height: 2),
          Text(reward, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11)),
        ]),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: GacomColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (BuildContext c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text('LEVEL ${e.heroLevel}  ${e.heroRank.toUpperCase()}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('${e.heroXpInLevel}/${e.heroXpNeed} XP to the next level. Every level makes you faster, shortens your dash wait and widens your coin pull.',
                style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 16),
            if (e.restMission != null && e.resting) ...<Widget>[
              const Text('REST MISSION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF80D8FF), letterSpacing: 1)),
              const SizedBox(height: 6),
              row(e.restMission!.title, e.restMission!.progress, e.restMission!.target, 'Finish it, then tap READY to answer early with two wrong answers removed'),
            ],
            if (e.quest != null) ...<Widget>[
              const Text('QUICK QUEST', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF69F0AE), letterSpacing: 1)),
              const SizedBox(height: 6),
              row(e.quest!.title, e.quest!.progress, e.quest!.target, '+${e.quest!.reward} points'),
            ],
            const Text('MISSIONS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFFFD54F), letterSpacing: 1)),
            const SizedBox(height: 6),
            for (final OdyMission m in e.missions) row(m.title, e.missionProgress(m), m.target, '+${m.rewardScore} points, +${m.rewardXp} XP, +1 heart'),
            if (e.missions.isEmpty) const Text('Missions appear as you play.', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12.5)),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _paused = false);
  }

  String _clock(double sec) {
    final int t = sec.ceil();
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  Widget _roundAction(IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(30), border: Border.all(color: color, width: 1.5)),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.8)),
          ]),
        ),
      );

  Future<void> _openRest() async {
    final OdysseyEngine? e = _engine;
    if (e == null) return;
    setState(() => _paused = true);
    final int? mins = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: GacomColors.cardDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (BuildContext c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Text('FREE ROAM', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary, letterSpacing: 1)),
            const SizedBox(height: 6),
            const Text('Explore and finish the rest mission, such as collecting a set number of coins. Tap READY when it is done to answer early with two wrong answers removed. When the time is up, one question must be answered before you move on.',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            Row(children: <Widget>[
              for (final int m in <int>[1, 3, 5])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () => Navigator.pop(c, m),
                      child: Text('$m min', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (mins != null) e.rest(mins * 60.0);
    setState(() => _paused = false);
  }

  Widget _introOverlay() => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.88),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Icon(Icons.explore_rounded, color: widget.config.accent ?? const Color(0xFF69F0AE), size: 54),
                  const SizedBox(height: 10),
                  Text((widget.config.title ?? 'THE GLITCH STORM').toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: Colors.white, letterSpacing: 2)),
                  const SizedBox(height: 12),
                  Text(
                    widget.config.story ?? 'A storm of Glitches has scrambled the realms of knowledge. You are the last Explorer. Cross each realm, restore it with the right answers, and gather coins and stars to keep your hearts full.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      _inDuel
                          ? 'Duel rules: the same world for both players. Highest score in the time wins.'
                          : 'Your pace is yours. Answer challenge orbs when you like and level up your hero as you go. Tap REST for 1, 3 or 5 minutes of free roam: finish the rest mission and you can answer early, with a hint. Open MISSIONS to see your goals. Mistakes come back later as corrections.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.45),
                    ),
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

  Widget _gateOverlay(OdysseyEngine e) {
    final OdyGate g = e.gate!;
    final OdySubject s = _subjects[g.q.subject] ?? odySubjectById(g.q.subject);
    final Color c = _lighten(s.color, 0.25);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.86),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                Text('CHECKPOINT  /  ${s.label.toUpperCase()}', style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                const Text('Answer to continue your journey', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: c, width: 1.2)),
                  child: Text(g.q.text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
                for (int i = 0; i < g.q.options.length; i++) _gateOption(e, g, i),
                if (g.answered) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(g.correct ? 'Correct. +150' : 'Not this time. The answer is ${g.q.answer}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: g.correct ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80), fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 14),
                  Center(child: _bigButton('CONTINUE', () => setState(e.closeGate))),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gateOption(OdysseyEngine e, OdyGate g, int i) {
    Color bg = Colors.white10;
    Color border = Colors.white24;
    if (g.answered) {
      if (i == g.q.answerIndex) {
        bg = const Color(0xFF1B5E20).withValues(alpha: 0.7);
        border = const Color(0xFF69F0AE);
      } else if (i == g.chosen) {
        bg = const Color(0xFFB71C1C).withValues(alpha: 0.6);
        border = const Color(0xFFFF8A80);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: g.hidden.contains(i) && !g.answered
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white12)),
              child: const Text('Removed by your hint', style: TextStyle(color: Colors.white30, fontSize: 13, fontStyle: FontStyle.italic)),
            )
          : GestureDetector(
        onTap: g.answered ? null : () => setState(() => e.answerGate(i)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
          child: Row(children: <Widget>[
            Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white54, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(child: Text(g.q.options[i], style: const TextStyle(color: Colors.white, fontSize: 15))),
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
          Expanded(child: Text((a.redo ? 'CORRECTION  /  ' : '') + s.label.toUpperCase() + (a.q.fromSchool && a.q.topic.isNotEmpty ? '  /  ${a.q.topic}' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.8))),
        ]),
        const SizedBox(height: 4),
        Text(a.q.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: frac, minHeight: 5, backgroundColor: Colors.white12, color: frac > 0.3 ? c : const Color(0xFFFF5252)),
        ),
        const SizedBox(height: 4),
        const Text('Walk into the glowing orb with the right answer. No rush.', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
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
                  if (e.questsDone > 0) _stat('Quests', '${e.questsDone}'),
                  if (!_inDuel) _stat('Level', '${e.heroLevel}'),
                  if (e.missionsDone > 0) _stat('Missions', '${e.missionsDone}'),
                  if (e.corrected > 0) _stat('Corrected', '${e.corrected}'),
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
                if (!inDuel && _journey != null) ...<Widget>[
                  const SizedBox(height: 16),
                  JourneyResultCard(result: _journey),
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
      return <Color>[a, _lighten(a, 0.018), _lighten(a, 0.03), _darken(a, 0.015)];
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
        if (hh % 100 < 14) {
          final double ox = ix * tile + 20 + (hh >> 5) % (tile.toInt() - 40);
          final double oy = iy * tile + 20 + (hh >> 11) % (tile.toInt() - 40);
          _decor(canvas, sid, (hh >> 3) % 3, ox, oy, hh);
        }
      }
    }

    // coins
    for (final OdyCrystal c in engine.crystalList) {
      final double pulse = 1 + sin(engine.time * 6 + c.x * 0.05) * 0.06;
      final double squash = (cos(engine.time * 4 + c.y * 0.04)).abs() * 0.5 + 0.5;
      _p.color = const Color(0xFFFFD54F).withValues(alpha: 0.22);
      canvas.drawCircle(Offset(c.x, c.y), 16 * pulse, _p);
      _p.color = const Color(0xFFFFB300);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.x, c.y), width: 20 * squash + 4, height: 20), _p);
      _p.color = const Color(0xFFFFE082);
      canvas.drawOval(Rect.fromCenter(center: Offset(c.x, c.y), width: 11 * squash + 2, height: 12), _p);
    }

    // stars: life (red heart star) and shield (blue)
    for (final OdyStar st in engine.starList) {
      final bool life = st.kind == 0;
      final Color col = life ? const Color(0xFFFF5252) : const Color(0xFF40C4FF);
      final double bob = sin(engine.time * 3 + st.x) * 4;
      final double r = OdysseyEngine.starRadius + 4 + sin(engine.time * 5) * 2;
      _p.color = col.withValues(alpha: 0.22);
      canvas.drawCircle(Offset(st.x, st.y + bob), r + 12, _p);
      _p.color = col.withValues(alpha: 0.4);
      canvas.drawCircle(Offset(st.x, st.y + bob), r + 4, _p);
      final Path star = Path();
      for (int i = 0; i < 10; i++) {
        final double rr = i.isEven ? r : r * 0.45;
        final double ang = -pi / 2 + i * pi / 5 + engine.time * 0.8;
        final double sx = st.x + cos(ang) * rr;
        final double sy = st.y + bob + sin(ang) * rr;
        if (i == 0) {
          star.moveTo(sx, sy);
        } else {
          star.lineTo(sx, sy);
        }
      }
      star.close();
      _p.color = life ? const Color(0xFFFFEB3B) : const Color(0xFFE1F5FE);
      canvas.drawPath(star, _p);
      _p.color = col;
      canvas.drawCircle(Offset(st.x, st.y + bob), 5, _p);
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
        canvas.drawOval(Rect.fromCenter(center: Offset(px - engine.dashDirX * 18 * i, py - engine.dashDirY * 18 * i), width: 16, height: 30), _p);
      }
    }
    // rank aura: grows with the hero's level
    if (engine.allowRest && engine.heroTier >= 1) {
      const List<Color> tc = <Color>[Color(0xFFB0BEC5), Color(0xFF81C784), Color(0xFF4FC3F7), Color(0xFFBA68C8), Color(0xFFFFB74D), Color(0xFFFF8A65), Color(0xFFFFD54F), Color(0xFFFFF59D)];
      final Color ac = tc[engine.heroTier];
      final double pulse = 0.5 + 0.5 * sin(engine.time * 3);
      _p.style = PaintingStyle.fill;
      _p.color = ac.withValues(alpha: 0.10 + 0.06 * pulse);
      canvas.drawCircle(Offset(px, py + 2), 26 + engine.heroTier * 2.5, _p);
      if (engine.heroTier >= 3) {
        for (int i = 0; i < engine.heroTier - 1; i++) {
          final double ang = engine.time * 1.6 + i * 2 * pi / (engine.heroTier - 1);
          _p.color = ac.withValues(alpha: 0.9);
          canvas.drawCircle(Offset(px + cos(ang) * 30, py + 2 + sin(ang) * 22), 2.6, _p);
        }
      }
    }
    if (!blink) {
      _drawHero(canvas, px, py);
    }
    if (engine.shield > 0) {
      _p.style = PaintingStyle.stroke;
      _p.strokeWidth = 3;
      _p.color = const Color(0xFF40C4FF).withValues(alpha: engine.shield < 2 ? 0.35 + 0.3 * sin(engine.time * 18) : 0.85);
      canvas.drawCircle(Offset(px, py - 6), 34, _p);
      _p.style = PaintingStyle.fill;
      _p.color = const Color(0xFF40C4FF).withValues(alpha: 0.12);
      canvas.drawCircle(Offset(px, py - 6), 34, _p);
    }
    canvas.restore();

    // off-screen answer arrows
    if (act != null) {
      for (final OdyOrb o in act.orbs) {
        final double sx = o.x - px + w / 2;
        final double sy = o.y - py + h / 2;
        if (sx < 24 || sx > w - 24 || sy < 210 || sy > h - 24) {
          final double cx = sx.clamp(26.0, w - 26.0);
          final double cy = sy.clamp(220.0, h - 26.0);
          _p.color = _lighten(_subj(act.q.subject).color, 0.3);
          canvas.drawCircle(Offset(cx, cy), 15, _p);
          _text(canvas, String.fromCharCode(65 + o.index), Offset(cx, cy), 15, Colors.black, true, 40);
        }
      }
    }

    // arrows to life stars that are off screen
    for (final OdyStar st in engine.starList) {
      if (st.kind != 0) continue;
      final double sx = st.x - px + w / 2;
      final double sy = st.y - py + h / 2;
      if (sx < 20 || sx > w - 20 || sy < 210 || sy > h - 20) {
        final double cx = sx.clamp(24.0, w - 24.0);
        final double cy = sy.clamp(220.0, h - 24.0);
        _p.color = const Color(0xFFFFEB3B);
        canvas.drawCircle(Offset(cx, cy), 13, _p);
        _p.color = const Color(0xFFFF5252);
        canvas.drawCircle(Offset(cx, cy), 6, _p);
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

  /// A small humanoid: head, hair, body, swinging arms and legs. Feet stand
  /// on (x, y + 18), so the collision circle sits around the torso.
  void _drawHero(Canvas canvas, double x, double y) {
    final double sp = sqrt(engine.vx * engine.vx + engine.vy * engine.vy);
    final bool moving = sp > 20;
    final double cyc = engine.distance / 14.0;
    final double swing = moving ? sin(cyc) : 0.0;
    final double bob = moving ? (sin(cyc * 2).abs() * 2.2) : sin(engine.time * 2.4) * 0.8;
    final double fx = engine.facingX >= 0 ? 1.0 : -1.0;
    final double lean = moving ? (engine.vx / OdysseyEngine.dashSpeed) * 0.35 : 0.0;
    final double footY = y + 18;
    final HeroLook look = HeroLook.current;

    canvas.save();
    canvas.translate(x, footY);
    canvas.rotate(lean);
    canvas.translate(-x, -footY);

    // shadow
    _p.color = Colors.black.withValues(alpha: 0.32);
    canvas.drawOval(Rect.fromCenter(center: Offset(x, footY + 1), width: 30, height: 9), _p);

    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (moving) {
      canvas.save();
      canvas.translate(x, y);
      paintCosmeticTrail(canvas, look.trail, look.trailColor, cyc, fx);
      canvas.restore();
    }

    // back arm and back leg
    stroke.strokeWidth = 5;
    stroke.color = realmDarken(look.skin, 0.06);
    canvas.drawLine(Offset(x - 8 * fx, y - 3 - bob), Offset(x - 11 * fx - swing * 6 * fx, y + 8 - bob), stroke);
    stroke.strokeWidth = 6;
    stroke.color = realmDarken(look.pants, 0.08);
    canvas.drawLine(Offset(x - 3, y + 7 - bob), Offset(x - 3 - swing * 7 * fx, footY - 1), stroke);

    // body
    _p.color = look.shirt;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 9, y - 8 - bob, 18, 20), const Radius.circular(7)), _p);
    _p.color = realmLighten(look.shirt, 0.15);
    canvas.drawRect(Rect.fromLTWH(x - 9, y + 1 - bob, 18, 3), _p);

    // front leg and front arm
    stroke.strokeWidth = 6;
    stroke.color = look.pants;
    canvas.drawLine(Offset(x + 3, y + 7 - bob), Offset(x + 3 + swing * 7 * fx, footY - 1), stroke);
    stroke.strokeWidth = 5;
    stroke.color = look.skin;
    canvas.drawLine(Offset(x + 8 * fx, y - 3 - bob), Offset(x + 11 * fx + swing * 6 * fx, y + 8 - bob), stroke);

    // shoes
    _p.color = Colors.white;
    canvas.drawCircle(Offset(x - 3 - swing * 7 * fx, footY), 3.4, _p);
    canvas.drawCircle(Offset(x + 3 + swing * 7 * fx, footY), 3.4, _p);

    // head
    final double hy = y - 17 - bob;
    _p.color = look.skin;
    canvas.drawCircle(Offset(x, hy), 9.5, _p);
    // hair
    _p.color = look.hair;
    canvas.drawArc(Rect.fromCircle(center: Offset(x, hy), radius: 10), pi, pi, true, _p);
    canvas.drawCircle(Offset(x - 6 * fx, hy - 2), 4.2, _p);
    // eyes look where the hero walks
    final double ex = engine.facingX * 2.4;
    final double ey = engine.facingY * 1.6;
    _p.color = Colors.white;
    canvas.drawCircle(Offset(x - 3.4 + ex * 0.4, hy + 1 + ey * 0.3), 2.6, _p);
    canvas.drawCircle(Offset(x + 3.4 + ex * 0.4, hy + 1 + ey * 0.3), 2.6, _p);
    _p.color = const Color(0xFF14101A);
    canvas.drawCircle(Offset(x - 3.4 + ex, hy + 1 + ey), 1.3, _p);
    canvas.drawCircle(Offset(x + 3.4 + ex, hy + 1 + ey), 1.3, _p);

    canvas.restore();
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
        _p.color = _darken(base, 0.02).withValues(alpha: 0.95);
        canvas.drawCircle(Offset(x, y - 8), 15, _p);
        _p.color = _lighten(base, 0.06).withValues(alpha: 0.6);
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
      default: {
        // grass tuft
        _p.color = _darken(base, 0.12).withValues(alpha: 0.9);
        for (int i = -1; i <= 1; i++) {
          final Path blade = Path()
            ..moveTo(x + i * 5.0, y + 6)
            ..lineTo(x + i * 5.0 - 2, y - 6 - (i == 0 ? 4 : 0))
            ..lineTo(x + i * 5.0 + 3, y + 6)
            ..close();
          canvas.drawPath(blade, _p);
        }
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
