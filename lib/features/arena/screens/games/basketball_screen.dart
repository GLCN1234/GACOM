import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import '../../../../core/services/duel_session.dart';

/// Side-view free throws on a 100 x 150 court. y grows downward.
class BasketEngine {
  static const double w = 100.0;
  static const double h = 150.0;
  static const double floorY = 146.0;
  static const double ballR = 4.0;
  static const double rimR = 1.0;
  static const double rimHalf = 6.25;
  static const double gravity = 120.0;
  static const double startX = 18.0;
  static const double startY = 124.0;
  static const double maxSpeed = 170.0;
  static const double restitution = 0.55;
  static const double roundTime = 60.0;
  static const double subStep = 1.0 / 240.0;

  final Random rng;
  double hx = 72.0;
  double hy = 56.0;
  double bx = startX;
  double by = startY;
  double vx = 0.0;
  double vy = 0.0;
  bool flying = false;
  bool scored = false;
  int floorBounces = 0;
  double shotT = 0.0;
  double resetT = 0.0;
  int score = 0;
  int makes = 0;
  int shots = 0;
  int streak = 0;
  int bestStreak = 0;
  int lastPoints = 0;
  double timeLeft = roundTime;
  bool over = false;

  BasketEngine(this.rng);

  double get boardX => hx + rimHalf + 3.0;
  bool get canShoot => !flying && resetT <= 0.0 && !over;

  void _moveHoop() {
    hx = 62.0 + rng.nextDouble() * 18.0;
    hy = 46.0 + rng.nextDouble() * 18.0;
  }

  /// Launches the ball with an initial velocity (vx0, vy0). Returns false if it can't shoot now.
  bool shoot(double vx0, double vy0) {
    if (!canShoot) return false;
    double sp = sqrt(vx0 * vx0 + vy0 * vy0);
    if (sp < 1.0) return false;
    if (sp > maxSpeed) {
      vx0 = vx0 / sp * maxSpeed;
      vy0 = vy0 / sp * maxSpeed;
      sp = maxSpeed;
    }
    bx = startX;
    by = startY;
    vx = vx0;
    vy = vy0;
    flying = true;
    scored = false;
    floorBounces = 0;
    shotT = 0.0;
    shots++;
    return true;
  }

  void _rim(double cx, double cy) {
    final double dx = bx - cx;
    final double dy = by - cy;
    final double d2 = dx * dx + dy * dy;
    final double rr = ballR + rimR;
    if (d2 < rr * rr && d2 > 1e-9) {
      final double d = sqrt(d2);
      final double nx = dx / d;
      final double ny = dy / d;
      bx = cx + nx * rr;
      by = cy + ny * rr;
      final double vn = vx * nx + vy * ny;
      if (vn < 0) {
        vx -= (1 + restitution) * vn * nx;
        vy -= (1 + restitution) * vn * ny;
      }
    }
  }

  void _stepBall(double dt) {
    final double prevY = by;
    vy += gravity * dt;
    bx += vx * dt;
    by += vy * dt;
    shotT += dt;
    _rim(hx - rimHalf, hy);
    _rim(hx + rimHalf, hy);
    final double bb = boardX;
    if (vx > 0 && bx + ballR > bb && bx - ballR < bb + 1.0 && by > hy - 22 - ballR * 0.5 && by < hy + 2 + ballR * 0.5) {
      bx = bb - ballR;
      vx = -vx * 0.6;
    }
    if (!scored && prevY < hy && by >= hy && vy > 0 && bx > hx - rimHalf + rimR && bx < hx + rimHalf - rimR) {
      scored = true;
      streak++;
      if (streak > bestStreak) { bestStreak = streak; }
      lastPoints = 2 + (streak >= 5 ? 2 : (streak >= 3 ? 1 : 0));
      score += lastPoints;
      makes++;
    }
    if (bx < ballR) {
      bx = ballR;
      vx = vx.abs() * 0.6;
    }
    if (bx > w - ballR) {
      bx = w - ballR;
      vx = -vx.abs() * 0.6;
    }
    if (by + ballR >= floorY) {
      by = floorY - ballR;
      if (vy > 0) {
        vy = -vy * restitution;
        vx *= 0.92;
        floorBounces++;
      }
    }
  }

  void _endShot() {
    flying = false;
    resetT = 0.6;
    if (!scored) { streak = 0; }
  }

  void update(double dt) {
    if (over) return;
    timeLeft -= dt;
    if (timeLeft <= 0.0) {
      timeLeft = 0.0;
      over = true;
      return;
    }
    if (resetT > 0.0) {
      resetT -= dt;
      if (resetT <= 0.0) {
        resetT = 0.0;
        bx = startX;
        by = startY;
        vx = 0.0;
        vy = 0.0;
        if (scored && makes % 2 == 0) { _moveHoop(); }
      }
    }
    if (flying) {
      final int n = max(1, (dt / subStep).ceil());
      final double hStep = dt / n;
      for (int i = 0; i < n; i++) {
        _stepBall(hStep);
        if (floorBounces >= 3 || shotT > 4.0) {
          _endShot();
          break;
        }
      }
    }
  }

  /// Points of the free-flight path for the first [seconds] (no collisions), for the aim guide.
  List<List<double>> preview(double vx0, double vy0, double seconds) {
    final pts = <List<double>>[];
    for (double t = 0.0; t <= seconds; t += 0.05) {
      pts.add([startX + vx0 * t, startY + vy0 * t + 0.5 * gravity * t * t]);
    }
    return pts;
  }
}

class BasketballScreen extends StatefulWidget {
  const BasketballScreen({super.key});
  @override
  State<BasketballScreen> createState() => _BasketballScreenState();
}

class _BasketballScreenState extends State<BasketballScreen> with SingleTickerProviderStateMixin {
  final Random _rng = duelRandom();
  BasketEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  double _scale = 3.0;
  Offset? _dragStart;
  Offset? _dragNow;
  int _lastMakes = 0;
  String _pop = '';
  double _popT = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    _ticker.stop();
    setState(() {
      _e = BasketEngine(_rng);
      _saved = false;
      _lastMakes = 0;
      _dragStart = null;
      _dragNow = null;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) { dt = 0.05; }
    e.update(dt);
    if (_popT > 0.0) { _popT -= dt; }
    if (e.makes != _lastMakes) {
      _lastMakes = e.makes;
      _pop = '+${e.lastPoints}${e.streak >= 3 ? '  STREAK ${e.streak}' : ''}';
      _popT = 1.0;
      SoundService.instance.playCorrect();
    }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Basketball Shootout', score: e.score);
      SoundService.instance.playWin();
    }
    setState(() {});
  }

  /// Velocity for a drag: the ball is pulled back like a sling.
  Offset? _velocity() {
    final a = _dragStart;
    final b = _dragNow;
    if (a == null || b == null) return null;
    final pull = Offset((a.dx - b.dx) / _scale, (a.dy - b.dy) / _scale);
    if (pull.distance < 6.0) return null;
    Offset v = pull * 2.4;
    if (v.distance > BasketEngine.maxSpeed) { v = v / v.distance * BasketEngine.maxSpeed; }
    return v;
  }

  void _release() {
    final e = _e;
    final v = _velocity();
    if (e != null && v != null && e.canShoot) {
      if (e.shoot(v.dx, v.dy)) { SoundService.instance.playShoot(); }
    }
    _dragStart = null;
    _dragNow = null;
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'basketball',
      title: 'HOW TO PLAY BASKETBALL',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Pull back and release', description: 'Drag anywhere backward, like a sling, then let go. The farther you pull, the harder the throw.'),
        HowToPlayStep(icon: Icons.timeline_rounded, title: 'Follow the dots', description: 'The dotted line shows the start of the ball path. Judge the rest of the arc yourself.'),
        HowToPlayStep(icon: Icons.sports_basketball_rounded, title: 'Score baskets', description: 'A basket is worth 2 points. Streaks of 3 and 5 make each basket worth more. A miss breaks the streak.'),
        HowToPlayStep(icon: Icons.timer_rounded, title: '60 seconds', description: 'The hoop moves every second basket, so adjust your aim. Rim and backboard bounces are real, so a bank shot can go in.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('BASKETBALL')),
        body: e == null
            ? ArcadeStartView(icon: Icons.sports_basketball_rounded, title: 'BASKETBALL', subtitle: '60 seconds. Sink as many shots as you can.', onStart: _start)
            : Stack(children: [
                LayoutBuilder(builder: (context, cons) {
                  _scale = min(cons.maxWidth / BasketEngine.w, cons.maxHeight / BasketEngine.h);
                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) {
                        if (e.canShoot) { _dragStart = d.localPosition; }
                        _dragNow = d.localPosition;
                      },
                      onPanUpdate: (d) => _dragNow = d.localPosition,
                      onPanEnd: (_) => _release(),
                      onPanCancel: () {
                        _dragStart = null;
                        _dragNow = null;
                      },
                      child: SizedBox(
                        width: BasketEngine.w * _scale,
                        height: BasketEngine.h * _scale,
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(painter: _BasketPainter(e, _velocity()))),
                      ),
                    ),
                  );
                }),
                Positioned(
                  top: 8,
                  left: 14,
                  right: 14,
                  child: Row(children: [
                    Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                    const Spacer(),
                    Text('${e.timeLeft.ceil()}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: e.timeLeft <= 10 ? const Color(0xFFEF5350) : Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 4)])),
                  ]),
                ),
                if (_popT > 0.0)
                  Positioned(top: 70, left: 0, right: 0, child: Center(child: Opacity(opacity: clampD(_popT, 0.0, 1.0), child: Text(_pop, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Color(0xFFFFD54F), shadows: [Shadow(color: Colors.black, blurRadius: 4)]))))),
                if (e.over)
                  ArcadeResultOverlay(
                    good: e.score >= 20,
                    title: 'FINAL BUZZER',
                    detail: 'Score ${e.score}  -  ${e.makes} of ${e.shots} shots  -  best streak ${e.bestStreak}',
                    onAgain: _start,
                    onExit: () => Navigator.pop(context),
                  ),
              ]),
      ),
    );
  }
}

class _BasketPainter extends CustomPainter {
  final BasketEngine e;
  final Offset? aim;
  _BasketPainter(this.e, this.aim);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / BasketEngine.w;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A237E), Color(0xFF283593)]).createShader(Offset.zero & size),
    );
    canvas.drawRect(Rect.fromLTWH(0, BasketEngine.floorY * s, size.width, size.height - BasketEngine.floorY * s), Paint()..color = const Color(0xFF8D6E63));
    final double bb = e.boardX;
    final double rimY = e.hy;
    canvas.drawRect(Rect.fromLTWH(bb * s, (rimY - 22) * s, 1.4 * s, 24 * s), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH((bb + 1.4) * s, (rimY - 22) * s, 1.0 * s, 24 * s), Paint()..color = Colors.white30);
    canvas.drawRect(Rect.fromLTWH((bb - 3.2) * s, (rimY - 9) * s, 3.2 * s, 9 * s), Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0xFFFF7043));
    final net = Paint()..color = Colors.white.withValues(alpha: 0.7)..strokeWidth = 1.0;
    final double lx = e.hx - BasketEngine.rimHalf;
    final double rx = e.hx + BasketEngine.rimHalf;
    for (int i = 0; i <= 4; i++) {
      final double t = i / 4.0;
      canvas.drawLine(Offset((lx + (rx - lx) * t) * s, rimY * s), Offset((lx + 2 + (rx - lx - 4) * t) * s, (rimY + 9) * s), net);
    }
    canvas.drawLine(Offset((lx + 1) * s, (rimY + 4.5) * s), Offset((rx - 1) * s, (rimY + 4.5) * s), net);
    canvas.drawLine(Offset(lx * s, rimY * s), Offset(rx * s, rimY * s), Paint()..color = const Color(0xFFFF5722)..strokeWidth = 3.0..strokeCap = StrokeCap.round);
    final v = aim;
    if (v != null && e.canShoot) {
      final pts = e.preview(v.dx, v.dy, 0.55);
      for (int i = 0; i < pts.length; i++) {
        canvas.drawCircle(Offset(pts[i][0] * s, pts[i][1] * s), clampD(1.4 - i * 0.07, 0.4, 1.4) * s, Paint()..color = Colors.white.withValues(alpha: 0.85));
      }
    }
    final o = Offset(e.bx * s, e.by * s);
    final r = BasketEngine.ballR * s;
    canvas.drawCircle(o, r, Paint()..color = const Color(0xFFFF8F00));
    final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0..color = const Color(0xFF5D4037);
    canvas.drawCircle(o, r, line);
    canvas.drawLine(Offset(o.dx - r, o.dy), Offset(o.dx + r, o.dy), line);
    canvas.drawLine(Offset(o.dx, o.dy - r), Offset(o.dx, o.dy + r), line);
  }

  @override
  bool shouldRepaint(_BasketPainter oldDelegate) => true;
}
