import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';

class DartMark {
  final double x;
  final double y;
  final bool player;
  const DartMark(this.x, this.y, this.player);
}

/// Standard dartboard geometry in millimetres, with (0, 0) at the bull and y pointing down.
class DartsEngine {
  static const double boardR = 170.0;
  static const double bullR = 6.35;
  static const double outerBullR = 15.9;
  static const double trebleIn = 99.0;
  static const double trebleOut = 107.0;
  static const double doubleIn = 162.0;
  static const List<int> order = [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5];
  static const int rounds = 5;

  /// Score for a dart that lands at (x, y).
  static int scoreAt(double x, double y) {
    final double r = sqrt(x * x + y * y);
    if (r <= bullR) return 50;
    if (r <= outerBullR) return 25;
    if (r > boardR) return 0;
    double deg = atan2(x, -y) * 180.0 / pi;
    if (deg < 0) { deg += 360.0; }
    final int idx = ((deg + 9.0) % 360.0 / 18.0).floor() % 20;
    final int base = order[idx];
    if (r > trebleIn && r <= trebleOut) return base * 3;
    if (r > doubleIn) return base * 2;
    return base;
  }

  static String labelAt(double x, double y) {
    final double r = sqrt(x * x + y * y);
    if (r <= bullR) return 'BULLSEYE';
    if (r <= outerBullR) return 'OUTER BULL';
    if (r > boardR) return 'MISS';
    double deg = atan2(x, -y) * 180.0 / pi;
    if (deg < 0) { deg += 360.0; }
    final int idx = ((deg + 9.0) % 360.0 / 18.0).floor() % 20;
    final int base = order[idx];
    if (r > trebleIn && r <= trebleOut) return 'TREBLE $base';
    if (r > doubleIn) return 'DOUBLE $base';
    return '$base';
  }

  final Random rng;
  final double sigmaMin;
  final double sigmaMax;
  final double aiSigma;
  final List<int> playerRounds = <int>[];
  final List<int> aiRounds = <int>[];
  final List<DartMark> marks = <DartMark>[];
  int round = 1;
  bool playerTurn = true;
  int dartsThrown = 0;
  int turnScore = 0;
  bool over = false;
  int lastScore = 0;
  String lastLabel = '';

  DartsEngine(this.rng, {required this.sigmaMin, required this.sigmaMax, required this.aiSigma});

  int get playerTotal {
    int t = 0;
    for (final r in playerRounds) { t += r; }
    return t;
  }

  int get aiTotal {
    int t = 0;
    for (final r in aiRounds) { t += r; }
    return t;
  }

  double _gauss() {
    final double u1 = max(1e-12, rng.nextDouble());
    final double u2 = rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  /// Aim wobble in mm. It grows the longer the player holds the aim.
  double noiseFor(double holdSeconds) {
    final double f = holdSeconds / 2.5;
    return sigmaMin + (sigmaMax - sigmaMin) * (f > 1.0 ? 1.0 : (f < 0.0 ? 0.0 : f));
  }

  void _register(double x, double y, bool player) {
    final int s = scoreAt(x, y);
    lastScore = s;
    lastLabel = labelAt(x, y);
    marks.add(DartMark(x, y, player));
    dartsThrown++;
    turnScore += s;
    if (dartsThrown >= 3) {
      if (player) {
        playerRounds.add(turnScore);
        playerTurn = false;
      } else {
        aiRounds.add(turnScore);
        playerTurn = true;
        round++;
        if (round > rounds) { over = true; }
      }
      dartsThrown = 0;
      turnScore = 0;
    }
  }

  /// The player throws at the aim point (mm). Returns the landing spot.
  List<double> throwPlayer(double ax, double ay, double holdSeconds) {
    if (over || !playerTurn) return [ax, ay];
    if (dartsThrown == 0) { marks.clear(); }
    final double sg = noiseFor(holdSeconds);
    final double x = ax + _gauss() * sg;
    final double y = ay + _gauss() * sg;
    _register(x, y, true);
    return [x, y];
  }

  /// The AI throws at the treble 20.
  List<double> throwAi() {
    if (over || playerTurn) return [0.0, 0.0];
    if (dartsThrown == 0) { marks.clear(); }
    final double x = _gauss() * aiSigma;
    final double y = -103.0 + _gauss() * aiSigma;
    _register(x, y, false);
    return [x, y];
  }
}

class DartsScreen extends StatefulWidget {
  const DartsScreen({super.key});
  @override
  State<DartsScreen> createState() => _DartsScreenState();
}

class _DartsScreenState extends State<DartsScreen> {
  static const List<String> _levels = ['Easy', 'Medium', 'Hard'];
  static const List<double> _aiSigma = [30.0, 20.0, 12.0];
  static const List<double> _sigmaMin = [5.0, 7.0, 9.0];
  static const List<double> _sigmaMax = [20.0, 24.0, 28.0];
  static const double _fingerLift = 46.0;

  final Random _rng = Random();
  DartsEngine? _e;
  int _level = 1;
  bool _saved = false;
  bool _busy = false;
  int _epoch = 0;
  Offset? _aimPx;
  DateTime? _downAt;
  double _boardPx = 300.0;
  String _msg = 'Your throw. Press, aim, and release quickly.';
  double _holdNow = 0.0;

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  void _start() {
    setState(() {
      _epoch++;
      _e = DartsEngine(_rng, sigmaMin: _sigmaMin[_level], sigmaMax: _sigmaMax[_level], aiSigma: _aiSigma[_level]);
      _saved = false;
      _busy = false;
      _aimPx = null;
      _msg = 'Your throw. Press, aim, and release quickly.';
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _e = null;
    });
  }

  double get _k => (_boardPx * 0.44) / DartsEngine.boardR;

  Offset _toMm(Offset px) => Offset((px.dx - _boardPx / 2) / _k, (px.dy - _boardPx / 2) / _k);

  void _down(Offset p) {
    final e = _e;
    if (e == null || _busy || e.over || !e.playerTurn) return;
    _downAt = DateTime.now();
    setState(() => _aimPx = Offset(p.dx, p.dy - _fingerLift));
  }

  void _move(Offset p) {
    if (_downAt == null) return;
    setState(() {
      _aimPx = Offset(p.dx, p.dy - _fingerLift);
      _holdNow = DateTime.now().difference(_downAt!).inMilliseconds / 1000.0;
    });
  }

  Future<void> _up() async {
    final e = _e;
    final at = _downAt;
    final aim = _aimPx;
    _downAt = null;
    if (e == null || at == null || aim == null || _busy || e.over || !e.playerTurn) {
      setState(() => _aimPx = null);
      return;
    }
    final double hold = DateTime.now().difference(at).inMilliseconds / 1000.0;
    final mm = _toMm(aim);
    final epoch = _epoch;
    SoundService.instance.playShoot();
    e.throwPlayer(mm.dx, mm.dy, hold);
    setState(() {
      _aimPx = null;
      _holdNow = 0.0;
      _msg = 'You hit ${e.lastLabel}  (${e.lastScore})';
    });
    if (e.lastScore >= 40) { SoundService.instance.playCorrect(); }
    if (!e.playerTurn && !e.over) {
      setState(() => _busy = true);
      await Future.delayed(const Duration(milliseconds: 1100));
      if (_dead(epoch)) return;
      await _aiTurn(epoch);
    }
  }

  Future<void> _aiTurn(int epoch) async {
    final e = _e!;
    setState(() => _msg = 'AI is throwing...');
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (_dead(epoch)) return;
      e.throwAi();
      SoundService.instance.playShoot();
      setState(() => _msg = 'AI hit ${e.lastLabel}  (${e.lastScore})');
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (_dead(epoch)) return;
    if (e.over) {
      _finish();
      return;
    }
    setState(() {
      _busy = false;
      _msg = 'Round ${e.round}. Your throw.';
    });
  }

  void _finish() {
    final e = _e!;
    if (!_saved) {
      _saved = true;
      final bool? won = e.playerTotal > e.aiTotal ? true : (e.playerTotal < e.aiTotal ? false : null);
      GameScoreService.save(gameName: 'Darts', score: e.playerTotal, won: won);
      if (won == true) { SoundService.instance.playWin(); }
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'darts',
      title: 'HOW TO PLAY DARTS',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Press, aim, release', description: 'Press on the board and slide your finger to move the aim point (it sits above your finger). Let go to throw.'),
        HowToPlayStep(icon: Icons.timelapse_rounded, title: 'Be quick', description: 'The circle around your aim shows how wobbly your throw will be. It grows the longer you hold, so aim fast.'),
        HowToPlayStep(icon: Icons.stars_rounded, title: 'Scoring', description: 'The bullseye is 50 and the outer bull 25. The thin outer ring doubles the number and the inner ring triples it. The treble 20 is worth 60.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Beat the AI', description: 'Each round you throw 3 darts, then the AI throws 3. After 5 rounds the highest total wins.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('DARTS')),
        body: e == null
            ? ArcadeStartView(
                icon: Icons.adjust_rounded,
                title: 'DARTS',
                subtitle: '5 rounds of 3 darts. Beat the AI.',
                buttonLabel: 'START MATCH',
                onStart: _start,
                extra: [ArcadeChoiceRow(label: 'AI SKILL', options: _levels, selected: _level, onSelect: (i) => setState(() => _level = i))],
              )
            : Stack(children: [_game(e), if (e.over && !_busy) _result(e)]),
      ),
    );
  }

  Widget _scoreCol(String name, int total, List<int> rounds, bool active) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? GacomColors.deepOrange : GacomColors.border, width: 2)),
    child: Column(children: [
      Text(name, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      Text('$total', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: GacomColors.textPrimary)),
      Text(rounds.isEmpty ? '-' : rounds.join(' + '), style: const TextStyle(color: GacomColors.textMuted, fontSize: 10)),
    ]),
  );

  Widget _game(DartsEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      _boardPx = max(220.0, min(cons.maxWidth - 16, cons.maxHeight - 150));
      final double sigma = e.noiseFor(_holdNow);
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _scoreCol('YOU', e.playerTotal, e.playerRounds, e.playerTurn && !e.over),
          const SizedBox(width: 12),
          Text('ROUND ${min(e.round, DartsEngine.rounds)}/${DartsEngine.rounds}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textMuted)),
          const SizedBox(width: 12),
          _scoreCol('AI', e.aiTotal, e.aiRounds, !e.playerTurn && !e.over),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: _boardPx,
          height: _boardPx,
          child: Listener(
            onPointerDown: (d) => _down(d.localPosition),
            onPointerMove: (d) => _move(d.localPosition),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) {
              _downAt = null;
              setState(() => _aimPx = null);
            },
            child: CustomPaint(painter: _BoardPainter(e, _aimPx, sigma * _k)),
          ),
        ),
        const SizedBox(height: 8),
        Text(_msg, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 4),
        Text('Dart ${min(e.dartsThrown + 1, 3)} of 3', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      ]);
    });
  }

  Widget _result(DartsEngine e) {
    final bool won = e.playerTotal > e.aiTotal;
    final bool draw = e.playerTotal == e.aiTotal;
    return ArcadeResultOverlay(
      good: won,
      title: won ? 'YOU WIN!' : (draw ? 'DRAW' : 'AI WINS'),
      detail: 'You ${e.playerTotal}  -  AI ${e.aiTotal}',
      onAgain: _toSetup,
      onExit: () => Navigator.pop(context),
      againLabel: 'REMATCH',
    );
  }
}

class _BoardPainter extends CustomPainter {
  final DartsEngine e;
  final Offset? aim;
  final double wobblePx;
  _BoardPainter(this.e, this.aim, this.wobblePx);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final double k = size.width * 0.44 / DartsEngine.boardR;
    canvas.drawCircle(c, size.width * 0.485, Paint()..color = const Color(0xFF111111));
    void ring(double outerMm, double innerMm, Color a, Color b) {
      for (int i = 0; i < 20; i++) {
        final double start = (-90.0 + i * 18.0 - 9.0) * pi / 180.0;
        final paint = Paint()..color = i.isEven ? a : b;
        canvas.drawArc(Rect.fromCircle(center: c, radius: outerMm * k), start, 18.0 * pi / 180.0, true, paint);
      }
      if (innerMm > 0) {
        // the inner circle of the next ring is painted by the next call
      }
    }
    const black = Color(0xFF1B1B1B);
    const cream = Color(0xFFF1E3C0);
    const red = Color(0xFFC62828);
    const green = Color(0xFF2E7D32);
    ring(DartsEngine.boardR, DartsEngine.doubleIn, red, green);
    ring(DartsEngine.doubleIn, DartsEngine.trebleOut, black, cream);
    ring(DartsEngine.trebleOut, DartsEngine.trebleIn, red, green);
    ring(DartsEngine.trebleIn, DartsEngine.outerBullR, black, cream);
    canvas.drawCircle(c, DartsEngine.outerBullR * k, Paint()..color = green);
    canvas.drawCircle(c, DartsEngine.bullR * k, Paint()..color = red);
    final wire = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = Colors.white54;
    for (final r in [DartsEngine.boardR, DartsEngine.doubleIn, DartsEngine.trebleOut, DartsEngine.trebleIn, DartsEngine.outerBullR, DartsEngine.bullR]) {
      canvas.drawCircle(c, r * k, wire);
    }
    for (int i = 0; i < 20; i++) {
      final double a = (-90.0 + i * 18.0 - 9.0) * pi / 180.0;
      canvas.drawLine(c + Offset(cos(a), sin(a)) * DartsEngine.outerBullR * k, c + Offset(cos(a), sin(a)) * DartsEngine.boardR * k, wire);
      final double mid = (-90.0 + i * 18.0) * pi / 180.0;
      final tp = TextPainter(text: TextSpan(text: '${DartsEngine.order[i]}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size.width * 0.045)), textDirection: TextDirection.ltr)..layout();
      final o = c + Offset(cos(mid), sin(mid)) * (DartsEngine.boardR * 1.1 * k);
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }
    for (final m in e.marks) {
      final o = c + Offset(m.x * k, m.y * k);
      canvas.drawCircle(o, 3.2, Paint()..color = m.player ? const Color(0xFFFFEB3B) : const Color(0xFF42A5F5));
      canvas.drawCircle(o, 3.2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black);
    }
    final a = aim;
    if (a != null) {
      canvas.drawCircle(a, max(4.0, wobblePx), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = Colors.white.withValues(alpha: 0.9));
      canvas.drawLine(a + const Offset(-8, 0), a + const Offset(8, 0), Paint()..color = Colors.white..strokeWidth = 1.5);
      canvas.drawLine(a + const Offset(0, -8), a + const Offset(0, 8), Paint()..color = Colors.white..strokeWidth = 1.5);
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => true;
}
