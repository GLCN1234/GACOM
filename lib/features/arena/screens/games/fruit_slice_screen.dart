import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';

class SliceItem {
  final bool bomb;
  final int kind; // fruit colour / type
  double x;
  double y;
  double vx;
  double vy;
  final double r;
  double spin;
  SliceItem(this.bomb, this.kind, this.x, this.y, this.vx, this.vy, this.r, this.spin);
}

class SliceHalf {
  double x;
  double y;
  double vx;
  double vy;
  final int kind;
  final double r;
  double angle;
  final double spin;
  final bool left;
  SliceHalf(this.x, this.y, this.vx, this.vy, this.kind, this.r, this.angle, this.spin, this.left);
}

/// A 100 x 160 field. y grows downward; items are thrown up from below.
class SliceEngine {
  static const double w = 100.0;
  static const double h = 160.0;
  static const double gravity = 130.0;
  static const int maxLives = 3;

  final Random rng;
  final List<SliceItem> items = <SliceItem>[];
  final List<SliceHalf> halves = <SliceHalf>[];
  int lives = maxLives;
  int score = 0;
  int sliced = 0;
  int bestCombo = 0;
  bool over = false;
  bool hitBomb = false;
  double elapsed = 0.0;
  double spawnT = 0.6;
  int swipeFruit = 0;
  int lastBonus = 0;
  final List<List<double>> _recent = <List<double>>[];

  SliceEngine(this.rng);

  /// Shortest distance from the point (px, py) to the segment a-b.
  static double segDist(double px, double py, double ax, double ay, double bx, double by) {
    final double dx = bx - ax;
    final double dy = by - ay;
    final double len2 = dx * dx + dy * dy;
    double t = 0.0;
    if (len2 > 0.0) {
      t = ((px - ax) * dx + (py - ay) * dy) / len2;
      if (t < 0.0) { t = 0.0; }
      if (t > 1.0) { t = 1.0; }
    }
    final double cx = ax + t * dx;
    final double cy = ay + t * dy;
    return sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
  }

  void launch({bool? bomb}) {
    final bool isBomb = bomb ?? (rng.nextDouble() < min(0.2, 0.08 + elapsed * 0.002));
    final double r = isBomb ? 6.5 : (rng.nextDouble() < 0.2 ? 8.5 : 6.5);
    // Items thrown together get clearly different paths, so a fruit is
    // never stuck behind a bomb for its whole flight.
    double x0 = 0.0;
    double xl = 0.0;
    for (int tries = 0; tries < 8; tries++) {
      x0 = 15.0 + rng.nextDouble() * 70.0;
      xl = 12.0 + rng.nextDouble() * 76.0;
      bool ok = true;
      for (final q in _recent) {
        if (elapsed - q[2] < 0.5 && (x0 - q[0]).abs() + (xl - q[1]).abs() < 34.0) {
          ok = false;
          break;
        }
      }
      if (ok) break;
    }
    _recent.add([x0, xl, elapsed]);
    _recent.removeWhere((q) => elapsed - q[2] > 1.0);
    final double y0 = h + 8.0;
    final double apex = 38.0 + rng.nextDouble() * 42.0;
    final double vy0 = -sqrt(2.0 * gravity * (y0 - apex));
    final double flight = 2.0 * (-vy0) / gravity;
    final double vx0 = (xl - x0) / flight;
    items.add(SliceItem(isBomb, rng.nextInt(5), x0, y0, vx0, vy0, r, (rng.nextDouble() - 0.5) * 6.0));
  }

  void beginSwipe() {
    swipeFruit = 0;
  }

  /// Slices everything the segment touches. Returns how many items were cut.
  int slice(double ax, double ay, double bx, double by) {
    if (over) return 0;
    int cut = 0;
    for (final it in items.toList()) {
      if (it.y < -4 || it.y > h + 4) continue;
      if (segDist(it.x, it.y, ax, ay, bx, by) <= it.r) {
        items.remove(it);
        cut++;
        if (it.bomb) {
          hitBomb = true;
          over = true;
          return cut;
        }
        score += 1;
        sliced++;
        swipeFruit++;
        halves.add(SliceHalf(it.x, it.y, it.vx - 18.0, it.vy * 0.3, it.kind, it.r, 0.0, -2.0, true));
        halves.add(SliceHalf(it.x, it.y, it.vx + 18.0, it.vy * 0.3, it.kind, it.r, 0.0, 2.0, false));
      }
    }
    return cut;
  }

  /// Ends a swipe and awards the combo bonus. Returns the bonus.
  int endSwipe() {
    int bonus = 0;
    if (swipeFruit >= 3) {
      bonus = swipeFruit * 2;
      score += bonus;
    }
    if (swipeFruit > bestCombo) { bestCombo = swipeFruit; }
    swipeFruit = 0;
    lastBonus = bonus;
    return bonus;
  }

  void update(double dt) {
    if (over) return;
    elapsed += dt;
    spawnT -= dt;
    if (spawnT <= 0.0) {
      final double iv = 1.15 - elapsed * 0.01;
      spawnT += iv < 0.55 ? 0.55 : iv;
      int n = 1;
      if (rng.nextDouble() < 0.35) { n++; }
      if (rng.nextDouble() < 0.15) { n++; }
      for (int i = 0; i < n; i++) { launch(); }
    }
    for (final it in items) {
      it.vy += gravity * dt;
      it.x += it.vx * dt;
      it.y += it.vy * dt;
    }
    for (final it in items.toList()) {
      if (it.y > h + 12 && it.vy > 0) {
        items.remove(it);
        if (!it.bomb) {
          lives--;
          if (lives <= 0) { over = true; }
        }
      }
    }
    for (final p in halves) {
      p.vy += gravity * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.angle += p.spin * dt;
    }
    halves.removeWhere((p) => p.y > h + 14);
  }
}

class FruitSliceScreen extends StatefulWidget {
  const FruitSliceScreen({super.key});
  @override
  State<FruitSliceScreen> createState() => _FruitSliceScreenState();
}

class _FruitSliceScreenState extends State<FruitSliceScreen> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  SliceEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  int _lastLives = 3;
  int _lastScore = 0;
  double _scale = 3.0;
  Offset? _prev;
  final List<_TrailPoint> _trail = <_TrailPoint>[];
  double _clock = 0.0;
  String _bonus = '';
  double _bonusT = 0.0;

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
      _e = SliceEngine(_rng);
      _saved = false;
      _lastLives = 3;
      _lastScore = 0;
      _trail.clear();
      _bonus = '';
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
    _clock += dt;
    e.update(dt);
    _trail.removeWhere((p) => _clock - p.t > 0.25);
    if (_bonusT > 0.0) { _bonusT -= dt; }
    if (e.lives < _lastLives) { SoundService.instance.playWrong(); }
    _lastLives = e.lives;
    if (e.score > _lastScore) { SoundService.instance.playPieceCapture(); }
    _lastScore = e.score;
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Fruit Slice', score: e.score);
      if (e.hitBomb) {
        SoundService.instance.playExplosion();
      } else {
        SoundService.instance.playLose();
      }
    }
    setState(() {});
  }

  void _down(Offset p) {
    final e = _e;
    if (e == null || e.over) return;
    e.beginSwipe();
    _prev = p;
    _trail.add(_TrailPoint(p, _clock));
  }

  void _move(Offset p) {
    final e = _e;
    final prev = _prev;
    if (e == null || e.over || prev == null) return;
    e.slice(prev.dx / _scale, prev.dy / _scale, p.dx / _scale, p.dy / _scale);
    _trail.add(_TrailPoint(p, _clock));
    _prev = p;
  }

  void _up() {
    final e = _e;
    if (e == null) return;
    final b = e.endSwipe();
    if (b > 0) {
      _bonus = 'COMBO +$b';
      _bonusT = 1.0;
    }
    _prev = null;
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'fruit_slice',
      title: 'HOW TO PLAY FRUIT SLICE',
      steps: const [
        HowToPlayStep(icon: Icons.swipe_rounded, title: 'Swipe to slice', description: 'Drag your finger across fruit as it flies up to slice it. Each fruit scores a point.'),
        HowToPlayStep(icon: Icons.local_fire_department_rounded, title: 'Combos', description: 'Slice 3 or more fruits in a single swipe for a bonus.'),
        HowToPlayStep(icon: Icons.dangerous_rounded, title: 'Avoid the bombs', description: 'Slicing a bomb ends the game instantly. Let bombs fall.'),
        HowToPlayStep(icon: Icons.favorite_rounded, title: 'Three lives', description: 'Every fruit you let fall costs a life. It gets faster the longer you play.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('FRUIT SLICE')),
        body: e == null
            ? ArcadeStartView(icon: Icons.restaurant_rounded, title: 'FRUIT SLICE', subtitle: 'Swipe to slice. Avoid the bombs.', onStart: _start)
            : Stack(children: [
                LayoutBuilder(builder: (context, cons) {
                  _scale = min(cons.maxWidth / SliceEngine.w, cons.maxHeight / SliceEngine.h);
                  return Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (d) => _down(d.localPosition),
                      onPanUpdate: (d) => _move(d.localPosition),
                      onPanEnd: (_) => _up(),
                      onPanCancel: _up,
                      child: SizedBox(
                        width: SliceEngine.w * _scale,
                        height: SliceEngine.h * _scale,
                        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(painter: _SlicePainter(e, _trail, _clock))),
                      ),
                    ),
                  );
                }),
                Positioned(
                  top: 8,
                  left: 14,
                  right: 14,
                  child: Row(children: [
                    Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
                    const Spacer(),
                    for (int i = 0; i < SliceEngine.maxLives; i++)
                      Padding(padding: const EdgeInsets.only(left: 3), child: Icon(Icons.favorite_rounded, size: 22, color: i < e.lives ? const Color(0xFFEF5350) : Colors.white24)),
                  ]),
                ),
                if (_bonusT > 0.0)
                  Positioned(top: 70, left: 0, right: 0, child: Center(child: Opacity(opacity: clampD(_bonusT, 0.0, 1.0), child: Text(_bonus, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: Color(0xFFFFD54F), shadows: [Shadow(color: Colors.black, blurRadius: 4)]))))),
                if (e.over)
                  ArcadeResultOverlay(
                    good: e.score >= 40,
                    title: e.hitBomb ? 'BOOM!' : 'OUT OF LIVES',
                    detail: 'Score ${e.score}  -  ${e.sliced} fruit sliced  -  best swipe ${e.bestCombo}',
                    onAgain: _start,
                    onExit: () => Navigator.pop(context),
                  ),
              ]),
      ),
    );
  }
}

class _TrailPoint {
  final Offset p;
  final double t;
  _TrailPoint(this.p, this.t);
}

const List<Color> _fruitColors = [Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFF7CB342), Color(0xFFFDD835), Color(0xFF8E24AA)];

class _SlicePainter extends CustomPainter {
  final SliceEngine e;
  final List<_TrailPoint> trail;
  final double clock;
  _SlicePainter(this.e, this.trail, this.clock);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / SliceEngine.w;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3E2723), Color(0xFF5D4037)]).createShader(Offset.zero & size),
    );
    for (final p in e.halves) {
      canvas.save();
      canvas.translate(p.x * s, p.y * s);
      canvas.rotate(p.angle);
      final rect = Rect.fromCircle(center: Offset.zero, radius: p.r * s);
      canvas.drawArc(rect, p.left ? pi / 2 : -pi / 2, pi, true, Paint()..color = _fruitColors[p.kind]);
      canvas.drawArc(rect.deflate(p.r * s * 0.28), p.left ? pi / 2 : -pi / 2, pi, true, Paint()..color = Colors.white.withValues(alpha: 0.8));
      canvas.restore();
    }
    for (final it in e.items) {
      final o = Offset(it.x * s, it.y * s);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(e.elapsed * it.spin);
      if (it.bomb) {
        canvas.drawCircle(Offset.zero, it.r * s, Paint()..color = const Color(0xFF212121));
        canvas.drawCircle(Offset(-it.r * s * 0.3, -it.r * s * 0.3), it.r * s * 0.25, Paint()..color = Colors.white24);
        canvas.drawLine(Offset(0, -it.r * s), Offset(it.r * s * 0.5, -it.r * s * 1.4), Paint()..color = const Color(0xFFFFB300)..strokeWidth = 2.5);
        canvas.drawCircle(Offset(it.r * s * 0.5, -it.r * s * 1.4), 1.8 * s, Paint()..color = const Color(0xFFFF5252));
      } else {
        canvas.drawCircle(Offset.zero, it.r * s, Paint()..color = _fruitColors[it.kind]);
        canvas.drawCircle(Offset(-it.r * s * 0.3, -it.r * s * 0.3), it.r * s * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.4));
        canvas.drawLine(Offset(0, -it.r * s), Offset(it.r * s * 0.25, -it.r * s * 1.25), Paint()..color = const Color(0xFF33691E)..strokeWidth = 2);
      }
      canvas.restore();
    }
    for (int i = 1; i < trail.length; i++) {
      final double age = clock - trail[i].t;
      final double a = clampD(1.0 - age / 0.25, 0.0, 1.0);
      canvas.drawLine(trail[i - 1].p, trail[i].p, Paint()..color = Colors.white.withValues(alpha: a)..strokeWidth = 2.0 + 4.0 * a..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_SlicePainter oldDelegate) => true;
}
