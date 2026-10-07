import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import '../../../../core/services/duel_session.dart';

class PinSeg {
  final double x1, y1, x2, y2;
  const PinSeg(this.x1, this.y1, this.x2, this.y2);
}

class PinBumper {
  final double x, y, r;
  const PinBumper(this.x, this.y, this.r);
}

class PinFlipper {
  final double px, py, len, sign;
  final double restDeg, upDeg;
  double theta;
  double omega = 0.0;
  bool pressed = false;
  PinFlipper(this.px, this.py, this.len, this.sign, this.restDeg, this.upDeg) : theta = restDeg * pi / 180.0;

  double get tipX => px + sign * len * cos(theta);
  double get tipY => py + len * sin(theta);
}

/// Pinball. Table is 100 wide by 180 tall, y points down. The ball launches up the right lane.
class PinballEngine {
  static const double w = 100.0;
  static const double h = 180.0;
  static const double br = 2.2;
  static const double fr = 2.0;
  static const double gravity = 150.0;
  static const double maxSpeed = 260.0;
  static const double wallE = 0.5;
  static const double flipSpeed = 13.0; // rad/s
  static const List<PinSeg> walls = [
    PinSeg(0.0, 38.0, 0.0, 124.0),
    PinSeg(0.0, 38.0, 5.0, 22.0),
    PinSeg(5.0, 22.0, 16.0, 11.0),
    PinSeg(16.0, 11.0, 30.0, 5.0),
    PinSeg(30.0, 5.0, 50.0, 2.0),
    PinSeg(50.0, 2.0, 70.0, 5.0),
    PinSeg(70.0, 5.0, 84.0, 11.0),
    PinSeg(84.0, 11.0, 95.0, 22.0),
    PinSeg(95.0, 22.0, 100.0, 38.0),
    PinSeg(100.0, 38.0, 100.0, 180.0),
    PinSeg(90.0, 55.0, 90.0, 180.0),
    PinSeg(90.0, 180.0, 100.0, 180.0),
    PinSeg(0.0, 124.0, 27.0, 150.0),
    PinSeg(90.0, 124.0, 63.0, 150.0),
  ];
  static const List<PinBumper> bumpers = [
    PinBumper(30.0, 60.0, 6.0),
    PinBumper(60.0, 60.0, 6.0),
    PinBumper(45.0, 84.0, 6.0),
  ];
  static const List<double> laneX = [30.0, 45.0, 60.0];
  static const double laneY = 26.0;

  final Random rng;
  final PinFlipper left = PinFlipper(27.0, 150.0, 15.0, 1.0, 28.0, -32.0);
  final PinFlipper right = PinFlipper(63.0, 150.0, 15.0, -1.0, 28.0, -32.0);
  double bx = 95.0, by = 176.0, bvx = 0.0, bvy = 0.0;
  bool waiting = true; // ball sits in the lane
  int ballsLeft = 3;
  int score = 0;
  int mult = 1;
  final List<bool> lanes = <bool>[false, false, false];
  double sinceLaunch = 0.0;
  bool saverUsed = false;
  bool over = false;
  String message = 'Tap to launch the ball.';
  double slowTime = 0.0;
  int bumperEvents = 0;
  int flipEvents = 0;
  int laneEvents = 0;
  int drainEvents = 0;
  int wallEvents = 0;
  int launchEvents = 0;

  PinballEngine(this.rng);

  void launch() {
    if (!waiting || over) return;
    waiting = false;
    bx = 95.0;
    by = 174.0;
    bvx = (rng.nextDouble() - 0.5) * 4.0;
    bvy = -(238.0 + rng.nextDouble() * 14.0);
    sinceLaunch = 0.0;
    saverUsed = false;
    slowTime = 0.0;
    launchEvents++;
    message = '';
  }

  void _toLane() {
    waiting = true;
    bx = 95.0;
    by = 176.0;
    bvx = 0.0;
    bvy = 0.0;
  }

  void setFlipper(bool isLeft, bool pressed) {
    if (isLeft) { left.pressed = pressed; } else { right.pressed = pressed; }
  }

  void step(double dt) {
    if (over) return;
    final int n = max(1, (dt * 240.0).ceil());
    final double s = dt / n;
    for (int i = 0; i < n; i++) {
      _flippers(s);
      if (waiting) continue;
      _ball(s);
      if (over || waiting) break;
    }
    if (!waiting) { sinceLaunch += dt; }
  }

  void _flip(PinFlipper f, double s) {
    final double target = (f.pressed ? f.upDeg : f.restDeg) * pi / 180.0;
    final double maxStep = flipSpeed * s;
    final double diff = target - f.theta;
    if (diff.abs() <= maxStep) {
      f.theta = target;
      f.omega = 0.0;
    } else {
      final double dir = diff > 0.0 ? 1.0 : -1.0;
      f.theta += dir * maxStep;
      f.omega = dir * flipSpeed;
    }
  }

  void _flippers(double s) {
    _flip(left, s);
    _flip(right, s);
  }

  void _ball(double s) {
    bvy += gravity * s;
    bx += bvx * s;
    by += bvy * s;
    final double sp = sqrt(bvx * bvx + bvy * bvy);
    if (sp > maxSpeed) {
      bvx = bvx / sp * maxSpeed;
      bvy = bvy / sp * maxSpeed;
    }
    for (final seg in walls) {
      _hitSegment(seg.x1, seg.y1, seg.x2, seg.y2, br, wallE, 0.0, 0.0, true);
    }
    _hitFlipper(left);
    _hitFlipper(right);
    for (final b in bumpers) {
      final double dx = bx - b.x;
      final double dy = by - b.y;
      final double d = sqrt(dx * dx + dy * dy);
      final double minD = br + b.r;
      if (d < minD && d > 0.0) {
        final double nx = dx / d;
        final double ny = dy / d;
        bx = b.x + nx * minD;
        by = b.y + ny * minD;
        final double vn = bvx * nx + bvy * ny;
        if (vn < 0.0) { bvx -= 2.0 * vn * nx; bvy -= 2.0 * vn * ny; }
        bvx += nx * 70.0;
        bvy += ny * 70.0;
        score += 100 * mult;
        bumperEvents++;
      }
    }
    // top rollover lanes
    for (int i = 0; i < 3; i++) {
      final double dx = bx - laneX[i];
      final double dy = by - laneY;
      if (dx * dx + dy * dy < 3.5 * 3.5 && !lanes[i]) {
        lanes[i] = true;
        score += 50 * mult;
        laneEvents++;
        if (lanes[0] && lanes[1] && lanes[2]) {
          score += 1000 * mult;
          if (mult < 5) mult++;
          message = 'LANES COMPLETE! Multiplier x$mult';
          lanes[0] = false;
          lanes[1] = false;
          lanes[2] = false;
        }
      }
    }
    // the ball rolled back down the launch lane
    if (bx > 91.0 && by > 150.0 && sp < 30.0) {
      _toLane();
      return;
    }
    // stuck ball nudge
    if (sp < 3.0 && bx < 90.0) {
      slowTime += s;
      if (slowTime > 3.5) {
        slowTime = 0.0;
        bvy -= 60.0;
        bvx += (rng.nextDouble() - 0.5) * 40.0;
      }
    } else {
      slowTime = 0.0;
    }
    if (by > h + 4.0) {
      _drain();
    }
  }

  void _drain() {
    drainEvents++;
    if (!saverUsed && sinceLaunch < 6.0) {
      saverUsed = true;
      message = 'BALL SAVED!';
      _toLane();
      return;
    }
    ballsLeft--;
    for (int i = 0; i < 3; i++) { lanes[i] = false; }
    mult = 1;
    if (ballsLeft <= 0) {
      over = true;
      message = 'Game over';
    } else {
      message = 'Ball lost. $ballsLeft left. Tap to launch.';
      _toLane();
    }
  }

  /// Circle (ball) against a segment. When moving, (svx, svy) is the surface velocity at the contact.
  bool _hitSegment(double x1, double y1, double x2, double y2, double rad, double e, double svx, double svy, bool isWall) {
    final double sx = x2 - x1;
    final double sy = y2 - y1;
    final double l2 = sx * sx + sy * sy;
    double t = l2 == 0.0 ? 0.0 : ((bx - x1) * sx + (by - y1) * sy) / l2;
    t = clampD(t, 0.0, 1.0);
    final double cx = x1 + sx * t;
    final double cy = y1 + sy * t;
    final double dx = bx - cx;
    final double dy = by - cy;
    final double d2 = dx * dx + dy * dy;
    if (d2 >= rad * rad) return false;
    double nx;
    double ny;
    double d = sqrt(d2);
    if (d < 1e-6) {
      // centre exactly on the segment: push to the side the ball came from
      final double len = sqrt(l2);
      nx = -sy / len;
      ny = sx / len;
      d = 0.0;
    } else {
      nx = dx / d;
      ny = dy / d;
    }
    bx = cx + nx * rad;
    by = cy + ny * rad;
    final double rvx = bvx - svx;
    final double rvy = bvy - svy;
    final double vn = rvx * nx + rvy * ny;
    if (vn < 0.0) {
      bvx -= (1.0 + e) * vn * nx;
      bvy -= (1.0 + e) * vn * ny;
      if (isWall) wallEvents++;
    }
    return true;
  }

  void _hitFlipper(PinFlipper f) {
    final double tx = f.tipX;
    final double ty = f.tipY;
    // surface velocity at the closest point along the flipper
    final double sx = tx - f.px;
    final double sy = ty - f.py;
    final double l2 = sx * sx + sy * sy;
    double t = l2 == 0.0 ? 0.0 : ((bx - f.px) * sx + (by - f.py) * sy) / l2;
    t = clampD(t, 0.0, 1.0);
    // d/dt of (sign*len*cos, len*sin) scaled by t, times omega
    final double svx = -f.sign * f.len * sin(f.theta) * f.omega * t;
    final double svy = f.len * cos(f.theta) * f.omega * t;
    final double sp0 = sqrt(bvx * bvx + bvy * bvy);
    if (_hitSegment(f.px, f.py, tx, ty, br + fr, 0.35, svx, svy, false)) {
      final double sp1 = sqrt(bvx * bvx + bvy * bvy);
      if (f.omega != 0.0 && sp1 > sp0 + 20.0) flipEvents++;
    }
  }
}

class PinballScreen extends StatefulWidget {
  const PinballScreen({super.key});
  @override
  State<PinballScreen> createState() => _PinballScreenState();
}

class _PinballScreenState extends State<PinballScreen> with SingleTickerProviderStateMixin {
  final Random _rng = duelRandom();
  PinballEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  double _px = 300.0;
  final Map<int, bool> _pointers = <int, bool>{}; // pointer id -> true if left side

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
      _e = PinballEngine(_rng);
      _saved = false;
      _pointers.clear();
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _syncFlippers() {
    final e = _e;
    if (e == null) return;
    e.setFlipper(true, _pointers.containsValue(true));
    e.setFlipper(false, _pointers.containsValue(false));
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) { dt = 0.05; }
    final int b0 = e.bumperEvents;
    final int f0 = e.flipEvents;
    final int l0 = e.laneEvents;
    final int d0 = e.drainEvents;
    e.step(dt);
    if (e.bumperEvents > b0) { SoundService.instance.playCorrect(); }
    if (e.flipEvents > f0) { SoundService.instance.playTap(); }
    if (e.laneEvents > l0) { SoundService.instance.playPieceMove(); }
    if (e.drainEvents > d0) { SoundService.instance.playWrong(); }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Pinball', score: e.score);
      SoundService.instance.playLose();
    }
    setState(() {});
  }

  void _down(PointerDownEvent d) {
    final e = _e;
    if (e == null || e.over) return;
    if (e.waiting) {
      e.launch();
      SoundService.instance.playShoot();
    }
    _pointers[d.pointer] = d.localPosition.dx < _px / 2.0;
    _syncFlippers();
  }

  void _upPointer(int id) {
    _pointers.remove(id);
    _syncFlippers();
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'pinball',
      title: 'HOW TO PLAY PINBALL',
      steps: const [
        HowToPlayStep(icon: Icons.rocket_launch_rounded, title: 'Launch', description: 'Tap the table to fire the ball up the right-hand lane. You get 3 balls.'),
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Flippers', description: 'Touch the left half of the table for the left flipper and the right half for the right flipper. Time your tap as the ball arrives.'),
        HowToPlayStep(icon: Icons.blur_circular_rounded, title: 'Score', description: 'Round bumpers kick the ball and score 100. Roll the ball through all three top lanes to light them up for a 1000 point bonus and a higher multiplier (up to x5).'),
        HowToPlayStep(icon: Icons.shield_rounded, title: 'Ball save', description: 'Lose the ball within 6 seconds of launching and you get it back once, free. Otherwise it costs one of your 3 balls.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('PINBALL')),
        body: e == null
            ? ArcadeStartView(
                icon: Icons.blur_circular_rounded,
                title: 'PINBALL',
                subtitle: '3 balls. Bumpers, lanes, multipliers.',
                buttonLabel: 'PLAY',
                onStart: _start,
              )
            : Stack(children: [_game(e), if (e.over) _result(e)]),
      ),
    );
  }

  Widget _game(PinballEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      double th = cons.maxHeight - 64.0;
      double tw = th * PinballEngine.w / PinballEngine.h;
      if (tw > cons.maxWidth - 16.0) {
        tw = cons.maxWidth - 16.0;
        th = tw * PinballEngine.h / PinballEngine.w;
      }
      _px = tw;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('SCORE ${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textPrimary)),
          const SizedBox(width: 16),
          Text('x${e.mult}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.deepOrange)),
          const SizedBox(width: 16),
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(Icons.circle, size: 14, color: i < e.ballsLeft ? GacomColors.accentCyan : GacomColors.border),
            ),
        ]),
        const SizedBox(height: 4),
        SizedBox(
          width: tw,
          height: th,
          child: Listener(
            onPointerDown: _down,
            onPointerUp: (d) => _upPointer(d.pointer),
            onPointerCancel: (d) => _upPointer(d.pointer),
            child: CustomPaint(painter: _PinballPainter(e)),
          ),
        ),
        SizedBox(height: 22, child: Center(child: Text(e.message, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12)))),
      ]);
    });
  }

  Widget _result(PinballEngine e) {
    return ArcadeResultOverlay(
      good: e.score >= 3000,
      title: 'GAME OVER',
      detail: 'Final score ${e.score}',
      onAgain: _start,
      onExit: () => Navigator.pop(context),
    );
  }
}

class _PinballPainter extends CustomPainter {
  final PinballEngine e;
  _PinballPainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / PinballEngine.w;
    Offset o(double x, double y) => Offset(x * k, y * k);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), const Radius.circular(10)), Paint()..color = const Color(0xFF100B26));
    final wall = Paint()..color = const Color(0xFF7C5CFF)..strokeWidth = 2.4..strokeCap = StrokeCap.round;
    for (final s in PinballEngine.walls) {
      canvas.drawLine(o(s.x1, s.y1), o(s.x2, s.y2), wall);
    }
    for (final b in PinballEngine.bumpers) {
      canvas.drawCircle(o(b.x, b.y), b.r * k, Paint()..color = GacomColors.deepOrange);
      canvas.drawCircle(o(b.x, b.y), b.r * k * 0.6, Paint()..color = Colors.white24);
    }
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(o(PinballEngine.laneX[i], PinballEngine.laneY), 3.0 * k, Paint()..color = e.lanes[i] ? const Color(0xFFFFD700) : Colors.white12);
    }
    final fp = Paint()..color = GacomColors.accentCyan..strokeWidth = PinballEngine.fr * 2.0 * k..strokeCap = StrokeCap.round;
    for (final f in [e.left, e.right]) {
      canvas.drawLine(o(f.px, f.py), o(f.tipX, f.tipY), fp);
    }
    canvas.drawCircle(o(e.bx, e.by), PinballEngine.br * k, Paint()..color = Colors.white);
    canvas.drawCircle(o(e.bx - 0.6, e.by - 0.6), PinballEngine.br * k * 0.35, Paint()..color = Colors.white54);
  }

  @override
  bool shouldRepaint(_PinballPainter oldDelegate) => true;
}
