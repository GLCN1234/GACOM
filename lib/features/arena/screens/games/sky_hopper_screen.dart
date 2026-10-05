import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';

class HopperPipe {
  double x;
  final double gapY;
  final double gap;
  bool passed = false;
  HopperPipe(this.x, this.gapY, this.gap);
}

/// The field is 100 wide and 150 tall. y grows downward.
class HopperEngine {
  static const double w = 100.0;
  static const double h = 150.0;
  static const double groundH = 12.0;
  static const double birdX = 28.0;
  static const double birdR = 3.2;
  static const double pipeW = 12.0;
  static const double spacing = 58.0;
  static const double gravity = 170.0;
  static const double flapV = -50.0;

  final Random rng;
  double y = 70.0;
  double vy = 0.0;
  final List<HopperPipe> pipes = <HopperPipe>[];
  int score = 0;
  bool over = false;
  bool started = false;
  double time = 0.0;

  HopperEngine(this.rng) {
    _spawn();
  }

  double get gap {
    final double g = 46.0 - score * 0.4;
    return g < 32.0 ? 32.0 : g;
  }

  double get speed {
    final double v = 34.0 + score * 0.5;
    return v > 44.0 ? 44.0 : v;
  }

  void flap() {
    if (over) return;
    started = true;
    vy = flapV;
  }

  void _spawn() {
    final double gp = gap;
    final double lo = gp / 2 + 14.0;
    final double hi = h - groundH - gp / 2 - 14.0;
    double cy;
    if (pipes.isEmpty) {
      cy = (lo + hi) / 2;
    } else {
      cy = pipes.last.gapY + (rng.nextDouble() * 2 - 1) * 40.0;
      if (cy < lo) { cy = lo; }
      if (cy > hi) { cy = hi; }
    }
    final double x = pipes.isEmpty ? w + 40.0 : pipes.last.x + spacing;
    pipes.add(HopperPipe(x, cy, gp));
  }

  static bool circleRect(double cx, double cy, double r, double rx, double ry, double rw, double rh) {
    final double nx = cx < rx ? rx : (cx > rx + rw ? rx + rw : cx);
    final double ny = cy < ry ? ry : (cy > ry + rh ? ry + rh : cy);
    final double dx = cx - nx;
    final double dy = cy - ny;
    return dx * dx + dy * dy < r * r;
  }

  bool _hitsPipe(HopperPipe p) {
    if (birdX + birdR < p.x || birdX - birdR > p.x + pipeW) return false;
    final double top = p.gapY - p.gap / 2;
    final double bottom = p.gapY + p.gap / 2;
    return circleRect(birdX, y, birdR, p.x, 0.0, pipeW, top) || circleRect(birdX, y, birdR, p.x, bottom, pipeW, h - groundH - bottom);
  }

  void update(double dt) {
    time += dt;
    if (over) return;
    if (!started) {
      y = 70.0 + sin(time * 4) * 2.5;
      return;
    }
    vy += gravity * dt;
    y += vy * dt;
    if (y - birdR < 0) {
      y = birdR;
      if (vy < 0) { vy = 0; }
    }
    final double sp = speed;
    for (final p in pipes) { p.x -= sp * dt; }
    while (pipes.isNotEmpty && pipes.first.x + pipeW < -5) { pipes.removeAt(0); }
    while (pipes.isEmpty || pipes.last.x < w + 20) { _spawn(); }
    for (final p in pipes) {
      if (!p.passed && p.x + pipeW < birdX - birdR) {
        p.passed = true;
        score++;
      }
    }
    if (y + birdR >= h - groundH) {
      over = true;
      y = h - groundH - birdR;
      return;
    }
    for (final p in pipes) {
      if (_hitsPipe(p)) {
        over = true;
        return;
      }
    }
  }
}

class SkyHopperScreen extends StatefulWidget {
  const SkyHopperScreen({super.key});
  @override
  State<SkyHopperScreen> createState() => _SkyHopperScreenState();
}

class _SkyHopperScreenState extends State<SkyHopperScreen> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  HopperEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
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
      _e = HopperEngine(_rng);
      _saved = false;
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
    final before = e.score;
    e.update(dt);
    if (e.score != before) { SoundService.instance.playCorrect(); }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Sky Hopper', score: e.score);
      SoundService.instance.playLose();
    }
    setState(() {});
  }

  void _flap() {
    final e = _e;
    if (e == null || e.over) return;
    e.flap();
    SoundService.instance.playTap();
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'sky_hopper',
      title: 'HOW TO PLAY SKY HOPPER',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Tap to flap', description: 'Tap anywhere (or press Space) to make the bird hop upward. Gravity pulls it down between taps.'),
        HowToPlayStep(icon: Icons.swap_vert_rounded, title: 'Fly through the gaps', description: 'Steer through the gap in every pipe. Touching a pipe or the ground ends the run.'),
        HowToPlayStep(icon: Icons.trending_up_rounded, title: 'It gets tighter', description: 'Each pipe you clear scores a point. The gaps shrink and the pipes speed up as your score grows.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('SKY HOPPER')),
        body: e == null
            ? ArcadeStartView(icon: Icons.flutter_dash_rounded, title: 'SKY HOPPER', subtitle: 'Tap to flap through the gaps', onStart: _start)
            : Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.space || event.logicalKey == LogicalKeyboardKey.arrowUp)) {
                    _flap();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: Stack(children: [
                  LayoutBuilder(builder: (context, cons) {
                    final double s = min(cons.maxWidth / HopperEngine.w, cons.maxHeight / HopperEngine.h);
                    return Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _flap(),
                        child: SizedBox(
                          width: HopperEngine.w * s,
                          height: HopperEngine.h * s,
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(painter: _HopperPainter(e))),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(child: Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 52, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 6)]))),
                  ),
                  if (!e.started)
                    const Positioned(
                      bottom: 40,
                      left: 0,
                      right: 0,
                      child: Center(child: Text('TAP TO START', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white70))),
                    ),
                  if (e.over)
                    ArcadeResultOverlay(good: e.score >= 10, title: 'CRASHED', detail: 'You cleared ${e.score} pipe${e.score == 1 ? '' : 's'}', onAgain: _start, onExit: () => Navigator.pop(context)),
                ]),
              ),
      ),
    );
  }
}

class _HopperPainter extends CustomPainter {
  final HopperEngine e;
  _HopperPainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / HopperEngine.w;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4FC3F7), Color(0xFFB3E5FC)]).createShader(Offset.zero & size),
    );
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.55);
    for (int i = 0; i < 4; i++) {
      final double cx = ((i * 41.0 - e.time * (3.0 + i)) % 140.0) - 20.0;
      final double cy = 18.0 + i * 22.0;
      canvas.drawCircle(Offset(cx * s, cy * s), 5 * s, cloud);
      canvas.drawCircle(Offset((cx + 5) * s, (cy + 1) * s), 6 * s, cloud);
      canvas.drawCircle(Offset((cx + 11) * s, cy * s), 4.5 * s, cloud);
    }
    final pipe = Paint()..color = const Color(0xFF43A047);
    final pipeDark = Paint()..color = const Color(0xFF2E7D32);
    for (final p in e.pipes) {
      final double top = p.gapY - p.gap / 2;
      final double bottom = p.gapY + p.gap / 2;
      final double gh = HopperEngine.h - HopperEngine.groundH;
      canvas.drawRect(Rect.fromLTWH(p.x * s, 0, HopperEngine.pipeW * s, top * s), pipe);
      canvas.drawRect(Rect.fromLTWH((p.x - 1.5) * s, (top - 5) * s, (HopperEngine.pipeW + 3) * s, 5 * s), pipeDark);
      canvas.drawRect(Rect.fromLTWH(p.x * s, bottom * s, HopperEngine.pipeW * s, (gh - bottom) * s), pipe);
      canvas.drawRect(Rect.fromLTWH((p.x - 1.5) * s, bottom * s, (HopperEngine.pipeW + 3) * s, 5 * s), pipeDark);
    }
    final double gy = (HopperEngine.h - HopperEngine.groundH) * s;
    canvas.drawRect(Rect.fromLTWH(0, gy, size.width, HopperEngine.groundH * s), Paint()..color = const Color(0xFF8D6E63));
    canvas.drawRect(Rect.fromLTWH(0, gy, size.width, 2.5 * s), Paint()..color = const Color(0xFF7CB342));
    final double off = (e.time * e.speed) % 8.0;
    for (double x = -off; x < HopperEngine.w; x += 8.0) {
      canvas.drawRect(Rect.fromLTWH(x * s, gy + 5 * s, 4 * s, 1.5 * s), Paint()..color = const Color(0x33000000));
    }
    canvas.save();
    canvas.translate(HopperEngine.birdX * s, e.y * s);
    double rot = e.vy / 160.0;
    if (rot < -0.5) { rot = -0.5; }
    if (rot > 1.0) { rot = 1.0; }
    canvas.rotate(rot);
    canvas.drawCircle(Offset.zero, HopperEngine.birdR * s * 1.15, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawCircle(Offset(1.2 * s, -1.0 * s), 1.1 * s, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(1.5 * s, -1.0 * s), 0.55 * s, Paint()..color = Colors.black);
    canvas.drawPath(Path()..moveTo(3.2 * s, -0.4 * s)..lineTo(5.6 * s, 0.4 * s)..lineTo(3.2 * s, 1.4 * s)..close(), Paint()..color = const Color(0xFFFF7043));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HopperPainter oldDelegate) => true;
}
