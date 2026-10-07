import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import '../../../../core/services/duel_session.dart';

class DashObstacle {
  final int type; // 0 low crate, 1 high bar, 2 tall crate
  double x;
  final double w;
  final double bottom; // height above the ground
  final double height;
  DashObstacle(this.type, this.x, this.w, this.bottom, this.height);
}

class DashCoin {
  double x;
  final double h;
  bool taken = false;
  DashCoin(this.x, this.h);
}

/// Side-on runner. x runs left to right (160 wide); heights are measured up from the ground.
class DashEngine {
  static const double w = 160.0;
  static const double h = 90.0;
  static const double groundY = 70.0;
  static const double runnerX = 24.0;
  static const double runnerW = 6.0;
  static const double standH = 12.0;
  static const double slideH = 6.0;
  static const double gravity = 420.0;
  static const double jumpV = 150.0;
  static const double slideTime = 0.55;

  final Random rng;
  double hy = 0.0;
  double vy = 0.0;
  double slideLeft = 0.0;
  bool slideBuffered = false;
  double dist = 0.0;
  int coins = 0;
  bool over = false;
  double time = 0.0;
  double nextX = w + 60.0;
  final List<DashObstacle> obstacles = <DashObstacle>[];
  final List<DashCoin> coinList = <DashCoin>[];

  DashEngine(this.rng);

  bool get onGround => hy <= 0.0001 && vy <= 0.0;
  bool get sliding => slideLeft > 0.0;
  double get curH => sliding ? slideH : standH;

  double get speed {
    final double v = 62.0 + dist * 0.0105;
    return v > 130.0 ? 130.0 : v;
  }

  int get score => (dist / 10).floor() + coins * 5;

  void jump() {
    if (over || !onGround) return;
    vy = jumpV;
    slideLeft = 0.0;
    slideBuffered = false;
  }

  void slide() {
    if (over) return;
    if (onGround) {
      slideLeft = slideTime;
    } else {
      vy = vy > -260.0 ? -260.0 : vy;
      slideBuffered = true;
    }
  }

  void _spawn() {
    final double v = speed;
    final double gapDist = v * 0.95 + 20.0 + rng.nextDouble() * 45.0;
    final int t = rng.nextInt(3);
    if (t == 0) {
      obstacles.add(DashObstacle(0, nextX, 8.0, 0.0, 10.0));
    } else if (t == 1) {
      obstacles.add(DashObstacle(1, nextX, 14.0, 9.0, 16.0));
    } else {
      obstacles.add(DashObstacle(2, nextX, 8.0, 0.0, 17.0));
    }
    final double ch = rng.nextBool() ? 2.0 : 20.0;
    final double cx = nextX - gapDist * 0.5;
    for (int i = 0; i < 3; i++) { coinList.add(DashCoin(cx + i * 7.0, ch)); }
    nextX += gapDist;
  }

  void update(double dt) {
    time += dt;
    if (over) return;
    final double v = speed;
    final double move = v * dt;
    dist += move;
    nextX -= move;
    for (final o in obstacles) { o.x -= move; }
    for (final c in coinList) { c.x -= move; }
    obstacles.removeWhere((o) => o.x + o.w < -10);
    coinList.removeWhere((c) => c.x < -10 || c.taken);
    while (nextX < w + 40) { _spawn(); }
    if (hy > 0.0 || vy > 0.0) {
      vy -= gravity * dt;
      hy += vy * dt;
      if (hy <= 0.0) {
        hy = 0.0;
        vy = 0.0;
        if (slideBuffered) {
          slideLeft = slideTime;
          slideBuffered = false;
        }
      }
    }
    if (slideLeft > 0.0) { slideLeft -= dt; }
    const double inset = 0.8;
    final double rl = runnerX + inset;
    final double rr = runnerX + runnerW - inset;
    for (final o in obstacles) {
      if (rl < o.x + o.w && rr > o.x && hy < o.bottom + o.height && hy + curH > o.bottom) {
        over = true;
        return;
      }
    }
    for (final c in coinList) {
      if (!c.taken && rl < c.x + 3 && rr > c.x - 3 && hy < c.h + 3 && hy + curH > c.h - 3) {
        c.taken = true;
        coins++;
      }
    }
  }
}

class DashRunnerScreen extends StatefulWidget {
  const DashRunnerScreen({super.key});
  @override
  State<DashRunnerScreen> createState() => _DashRunnerScreenState();
}

class _DashRunnerScreenState extends State<DashRunnerScreen> with SingleTickerProviderStateMixin {
  final Random _rng = duelRandom();
  DashEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  int _lastCoins = 0;
  double _dragY = 0.0;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _ticker.stop();
    setState(() {
      _e = DashEngine(_rng);
      _saved = false;
      _lastCoins = 0;
    });
    _last = Duration.zero;
    _ticker.start();
    _focus.requestFocus();
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) { dt = 0.05; }
    e.update(dt);
    if (e.coins != _lastCoins) {
      _lastCoins = e.coins;
      SoundService.instance.playTap();
    }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Dash Runner', score: e.score);
      SoundService.instance.playLose();
    }
    setState(() {});
  }

  void _jump() {
    final e = _e;
    if (e == null || e.over) return;
    if (e.onGround) { SoundService.instance.playShoot(); }
    e.jump();
  }

  void _slide() {
    final e = _e;
    if (e == null || e.over) return;
    e.slide();
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTapDown: (_) => onTap(),
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border, width: 1.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: GacomColors.deepOrange, size: 26),
          Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textPrimary)),
        ]),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'dash_runner',
      title: 'HOW TO PLAY DASH RUNNER',
      steps: const [
        HowToPlayStep(icon: Icons.arrow_upward_rounded, title: 'Jump', description: 'Tap the field or the JUMP button (or press Space) to jump over crates.'),
        HowToPlayStep(icon: Icons.arrow_downward_rounded, title: 'Slide', description: 'Swipe down or tap SLIDE to duck under the high bars. In mid-air it makes you drop fast and slide on landing.'),
        HowToPlayStep(icon: Icons.monetization_on_rounded, title: 'Grab coins', description: 'Coins are worth 5 points each. Some float high, so jump for them.'),
        HowToPlayStep(icon: Icons.speed_rounded, title: 'It keeps speeding up', description: 'Distance scores points too. One hit ends the run.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('DASH RUNNER')),
        body: e == null
            ? ArcadeStartView(icon: Icons.directions_run_rounded, title: 'DASH RUNNER', subtitle: 'Jump, slide, and run as far as you can', onStart: _start)
            : Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.arrowUp) {
                    _jump();
                    return KeyEventResult.handled;
                  }
                  if (k == LogicalKeyboardKey.arrowDown) {
                    _slide();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Stack(children: [
                  Column(children: [
                    Expanded(
                      child: LayoutBuilder(builder: (context, cons) {
                        final double s = min(cons.maxWidth / DashEngine.w, cons.maxHeight / DashEngine.h);
                        return Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (_) => _jump(),
                            onVerticalDragStart: (_) => _dragY = 0.0,
                            onVerticalDragUpdate: (d) {
                              _dragY += d.delta.dy;
                              if (_dragY > 14) {
                                _dragY = -1000;
                                _slide();
                              }
                            },
                            child: SizedBox(
                              width: DashEngine.w * s,
                              height: DashEngine.h * s,
                              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(painter: _DashPainter(e))),
                            ),
                          ),
                        );
                      }),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
                      child: Row(children: [
                        _btn('SLIDE', Icons.arrow_downward_rounded, _slide),
                        _btn('JUMP', Icons.arrow_upward_rounded, _jump),
                      ]),
                    ),
                  ]),
                  Positioned(
                    top: 8,
                    left: 16,
                    child: Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                  ),
                  Positioned(
                    top: 14,
                    right: 16,
                    child: Row(children: [
                      const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFD54F), size: 18),
                      const SizedBox(width: 4),
                      Text('${e.coins}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                    ]),
                  ),
                  if (e.over)
                    ArcadeResultOverlay(good: e.score >= 150, title: 'WIPEOUT', detail: 'Score ${e.score}  -  ${e.dist.floor()} m  -  ${e.coins} coins', onAgain: _start, onExit: () => Navigator.pop(context)),
                ]),
              ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final DashEngine e;
  _DashPainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / DashEngine.w;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A237E), Color(0xFFFF8A65)]).createShader(Offset.zero & size),
    );
    final hill = Paint()..color = const Color(0x33000000);
    for (int i = 0; i < 4; i++) {
      final double cx = ((i * 55.0 - e.dist * 0.15) % 240.0) - 40.0;
      canvas.drawCircle(Offset(cx * s, (DashEngine.groundY + 18) * s), 34 * s, hill);
    }
    final double gy = DashEngine.groundY * s;
    canvas.drawRect(Rect.fromLTWH(0, gy, size.width, size.height - gy), Paint()..color = const Color(0xFF3E2723));
    canvas.drawRect(Rect.fromLTWH(0, gy, size.width, 2 * s), Paint()..color = const Color(0xFF8D6E63));
    final double off = e.dist % 12.0;
    for (double x = -off; x < DashEngine.w; x += 12.0) {
      canvas.drawRect(Rect.fromLTWH(x * s, gy + 7 * s, 6 * s, 1.5 * s), Paint()..color = const Color(0x44FFFFFF));
    }
    double yOf(double heightUp) => gy - heightUp * s;
    for (final c in e.coinList) {
      canvas.drawCircle(Offset(c.x * s, yOf(c.h)), 2.6 * s, Paint()..color = const Color(0xFFFFD54F));
      canvas.drawCircle(Offset(c.x * s, yOf(c.h)), 1.2 * s, Paint()..color = const Color(0xFFFFA000));
    }
    for (final o in e.obstacles) {
      final rect = Rect.fromLTWH(o.x * s, yOf(o.bottom + o.height), o.w * s, o.height * s);
      if (o.type == 1) {
        canvas.drawRect(rect, Paint()..color = const Color(0xFFE53935));
        for (double sx = rect.left; sx < rect.right; sx += 4 * s) {
          canvas.drawRect(Rect.fromLTWH(sx, rect.top, 2 * s, rect.height), Paint()..color = Colors.white.withValues(alpha: 0.7));
        }
      } else {
        canvas.drawRect(rect, Paint()..color = const Color(0xFF8D6E63));
        canvas.drawRect(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFF4E342E));
        canvas.drawLine(rect.topLeft, rect.bottomRight, Paint()..color = const Color(0xFF4E342E)..strokeWidth = 1.5);
        canvas.drawLine(rect.topRight, rect.bottomLeft, Paint()..color = const Color(0xFF4E342E)..strokeWidth = 1.5);
      }
    }
    final double rh = e.curH;
    final body = Rect.fromLTWH(DashEngine.runnerX * s, yOf(e.hy + rh), DashEngine.runnerW * s, rh * s);
    canvas.drawRRect(RRect.fromRectAndRadius(body, Radius.circular(1.5 * s)), Paint()..color = const Color(0xFF26C6DA));
    canvas.drawCircle(Offset(body.right - 1.6 * s, body.top + (e.sliding ? 2.0 : 3.0) * s), 1.0 * s, Paint()..color = Colors.white);
    if (e.onGround && !e.sliding && !e.over) {
      final double step = sin(e.dist * 0.5) * 2.0;
      canvas.drawRect(Rect.fromLTWH(body.left + 1 * s, body.bottom - 0.5 * s, 1.6 * s, 1.5 * s + step.abs() * 0.3 * s), Paint()..color = const Color(0xFF00838F));
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => true;
}
