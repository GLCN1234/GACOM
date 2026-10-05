import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';

class BzBullet {
  double x;
  double y;
  final double vx;
  final double vy;
  final double r;
  BzBullet(this.x, this.y, this.vx, this.vy, this.r);
}

class BzEnemy {
  final int type; // 0 grunt, 1 weaver, 2 shooter
  double x;
  double y;
  final double baseX;
  double hp;
  double age = 0.0;
  double fireT;
  final double r;
  BzEnemy(this.type, this.x, this.y, this.hp, this.r, this.fireT) : baseX = x;
}

class BzPower {
  final int kind; // 0 weapon, 1 shield, 2 life
  double x;
  double y;
  BzPower(this.kind, this.x, this.y);
}

class _Spawn {
  double delay;
  final int type;
  final double x;
  _Spawn(this.delay, this.type, this.x);
}

/// A vertical shoot-em-up on a 100 x 160 field. y grows downward.
class BlasterEngine {
  static const double w = 100.0;
  static const double h = 160.0;
  static const double playerR = 3.4;
  static const double minPlayerY = 84.0;
  static const double maxPlayerY = 150.0;
  static const double bulletSpeed = 130.0;

  final Random rng;
  double px = w / 2;
  double py = 138.0;
  int lives = 3;
  double inv = 0.0;
  int weapon = 1;
  double shield = 0.0;
  double fireT = 0.0;
  int score = 0;
  int wave = 0;
  double waveT = 1.0;
  bool over = false;
  double time = 0.0;
  int hitsTaken = 0;
  final List<BzBullet> bullets = <BzBullet>[];
  final List<BzBullet> enemyBullets = <BzBullet>[];
  final List<BzEnemy> enemies = <BzEnemy>[];
  final List<BzPower> powers = <BzPower>[];
  final List<_Spawn> _queue = <_Spawn>[];

  BlasterEngine(this.rng);

  double get speedMult {
    final double m = 1.0 + wave * 0.04;
    return m > 1.6 ? 1.6 : m;
  }

  void moveBy(double dx, double dy) {
    if (over) return;
    px += dx;
    py += dy;
    if (px < playerR) { px = playerR; }
    if (px > w - playerR) { px = w - playerR; }
    if (py < minPlayerY) { py = minPlayerY; }
    if (py > maxPlayerY) { py = maxPlayerY; }
  }

  double get _fireInterval => weapon == 1 ? 0.24 : (weapon == 2 ? 0.20 : 0.18);

  void _fire() {
    if (weapon == 1) {
      bullets.add(BzBullet(px, py - 4, 0, -bulletSpeed, 1.2));
    } else if (weapon == 2) {
      bullets.add(BzBullet(px - 2.2, py - 4, 0, -bulletSpeed, 1.2));
      bullets.add(BzBullet(px + 2.2, py - 4, 0, -bulletSpeed, 1.2));
    } else {
      bullets.add(BzBullet(px, py - 4, 0, -bulletSpeed, 1.2));
      bullets.add(BzBullet(px - 3, py - 3, -18, -bulletSpeed, 1.2));
      bullets.add(BzBullet(px + 3, py - 3, 18, -bulletSpeed, 1.2));
    }
  }

  void _spawnWave() {
    wave++;
    final int n = min(12, 3 + wave);
    for (int i = 0; i < n; i++) {
      int type = 0;
      final double r = rng.nextDouble();
      if (wave >= 5 && r < 0.22) {
        type = 2;
      } else if (wave >= 3 && r < 0.55) {
        type = 1;
      }
      _queue.add(_Spawn(i * 0.5, type, 12.0 + rng.nextDouble() * 76.0));
    }
  }

  static bool circles(double ax, double ay, double ar, double bx, double by, double br) {
    final double dx = ax - bx;
    final double dy = ay - by;
    final double rr = ar + br;
    return dx * dx + dy * dy < rr * rr;
  }

  void _hitPlayer() {
    if (inv > 0.0) return;
    hitsTaken++;
    if (shield > 0.0) {
      shield = 0.0;
      inv = 0.6;
      return;
    }
    lives--;
    inv = 1.6;
    if (weapon > 1) { weapon--; }
    if (lives <= 0) { over = true; }
  }

  void _onKill(BzEnemy e) {
    score += e.type == 0 ? 10 : (e.type == 1 ? 25 : 50);
    if (rng.nextDouble() < 0.14) {
      final double k = rng.nextDouble();
      powers.add(BzPower(k < 0.5 ? 0 : (k < 0.9 ? 1 : 2), e.x, e.y));
    }
  }

  void update(double dt) {
    time += dt;
    if (over) return;
    if (inv > 0.0) { inv -= dt; }
    if (shield > 0.0) { shield -= dt; }
    fireT -= dt;
    if (fireT <= 0.0) {
      _fire();
      fireT += _fireInterval;
    }
    waveT -= dt;
    if (waveT <= 0.0) {
      _spawnWave();
      final double iv = 7.0 - wave * 0.2;
      waveT = iv < 4.5 ? 4.5 : iv;
    }
    for (final s in _queue) { s.delay -= dt; }
    for (final s in _queue.where((q) => q.delay <= 0.0).toList()) {
      if (s.type == 0) {
        enemies.add(BzEnemy(0, s.x, -6.0, 1.0, 4.0, 0.0));
      } else if (s.type == 1) {
        enemies.add(BzEnemy(1, s.x, -6.0, 2.0, 4.0, 0.0));
      } else {
        enemies.add(BzEnemy(2, s.x, -6.0, 3.0, 4.5, 1.2));
      }
    }
    _queue.removeWhere((q) => q.delay <= 0.0);
    for (final b in bullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    bullets.removeWhere((b) => b.y < -4 || b.x < -4 || b.x > w + 4);
    for (final b in enemyBullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
    }
    enemyBullets.removeWhere((b) => b.y > h + 4 || b.x < -4 || b.x > w + 4 || b.y < -10);
    final double sm = speedMult;
    for (final e in enemies) {
      e.age += dt;
      if (e.type == 0) {
        e.y += 24.0 * sm * dt;
      } else if (e.type == 1) {
        e.y += 20.0 * sm * dt;
        e.x = clampD(e.baseX + sin(e.age * 1.6) * 14.0, 4.0, w - 4.0);
      } else {
        if (e.y < 24.0) {
          e.y += 28.0 * dt;
        } else {
          e.x = clampD(e.baseX + sin(e.age * 0.9) * 20.0, 4.0, w - 4.0);
          e.fireT -= dt;
          if (e.fireT <= 0.0) {
            e.fireT = 1.8 / sm;
            final double dx = px - e.x;
            final double dy = py - e.y;
            final double len = max(1.0, sqrt(dx * dx + dy * dy));
            enemyBullets.add(BzBullet(e.x, e.y + 4, dx / len * 48.0, dy / len * 48.0, 1.4));
          }
        }
      }
    }
    enemies.removeWhere((e) => e.y > h + 10);
    for (final b in bullets.toList()) {
      for (final e in enemies) {
        if (circles(b.x, b.y, b.r, e.x, e.y, e.r)) {
          e.hp -= 1.0;
          bullets.remove(b);
          if (e.hp <= 0.0) {
            _onKill(e);
            enemies.remove(e);
          }
          break;
        }
      }
    }
    for (final b in enemyBullets.toList()) {
      if (circles(b.x, b.y, b.r, px, py, playerR)) {
        enemyBullets.remove(b);
        _hitPlayer();
      }
    }
    for (final e in enemies.toList()) {
      if (circles(e.x, e.y, e.r, px, py, playerR)) {
        enemies.remove(e);
        _hitPlayer();
      }
    }
    for (final p in powers) { p.y += 25.0 * dt; }
    for (final p in powers.toList()) {
      if (circles(p.x, p.y, 3.0, px, py, playerR + 1.0)) {
        powers.remove(p);
        if (p.kind == 0) {
          if (weapon < 3) {
            weapon++;
          } else {
            score += 100;
          }
        } else if (p.kind == 1) {
          shield = 8.0;
        } else {
          if (lives < 5) {
            lives++;
          } else {
            score += 100;
          }
        }
      }
    }
    powers.removeWhere((p) => p.y > h + 6);
  }
}

class StarBlasterScreen extends StatefulWidget {
  const StarBlasterScreen({super.key});
  @override
  State<StarBlasterScreen> createState() => _StarBlasterScreenState();
}

class _StarBlasterScreenState extends State<StarBlasterScreen> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  BlasterEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  int _lastLives = 3;
  int _lastScore = 0;
  double _scale = 3.0;
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
      _e = BlasterEngine(_rng);
      _saved = false;
      _lastLives = 3;
      _lastScore = 0;
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
    if (e.lives < _lastLives) { SoundService.instance.playExplosion(); }
    _lastLives = e.lives;
    if (e.score != _lastScore) {
      if (e.score - _lastScore >= 10) { SoundService.instance.playTap(); }
      _lastScore = e.score;
    }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Star Blaster', score: e.score);
      SoundService.instance.playLose();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'star_blaster',
      title: 'HOW TO PLAY STAR BLASTER',
      steps: const [
        HowToPlayStep(icon: Icons.open_with_rounded, title: 'Drag to fly', description: 'Drag anywhere on the screen to move your ship. It fires automatically. (Arrow keys or WASD work on a keyboard.)'),
        HowToPlayStep(icon: Icons.gps_fixed_rounded, title: 'Dodge and destroy', description: 'Red ships fly straight, purple ones weave, and orange gunships shoot back at you. Colliding with anything costs a life.'),
        HowToPlayStep(icon: Icons.bolt_rounded, title: 'Collect power-ups', description: 'W upgrades your weapon, S gives a shield that absorbs one hit, and the heart gives an extra life.'),
        HowToPlayStep(icon: Icons.trending_up_rounded, title: 'Waves get harder', description: 'Each wave brings more and faster enemies. You have 3 lives. How many waves can you survive?'),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF05060F),
        appBar: AppBar(title: const Text('STAR BLASTER')),
        body: e == null
            ? ArcadeStartView(icon: Icons.rocket_launch_rounded, title: 'STAR BLASTER', subtitle: 'Fly, shoot, and survive the waves', onStart: _start)
            : Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: (node, event) {
                  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                  final k = event.logicalKey;
                  if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) {
                    e.moveBy(-4, 0);
                  } else if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) {
                    e.moveBy(4, 0);
                  } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) {
                    e.moveBy(0, -4);
                  } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) {
                    e.moveBy(0, 4);
                  } else {
                    return KeyEventResult.ignored;
                  }
                  return KeyEventResult.handled;
                },
                child: Stack(children: [
                  LayoutBuilder(builder: (context, cons) {
                    _scale = min(cons.maxWidth / BlasterEngine.w, cons.maxHeight / BlasterEngine.h);
                    return Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => e.moveBy(d.delta.dx / _scale, d.delta.dy / _scale),
                        child: SizedBox(
                          width: BlasterEngine.w * _scale,
                          height: BlasterEngine.h * _scale,
                          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CustomPaint(painter: _BlasterPainter(e))),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    top: 8,
                    left: 14,
                    right: 14,
                    child: Row(children: [
                      for (int i = 0; i < e.lives; i++) const Padding(padding: EdgeInsets.only(right: 3), child: Icon(Icons.favorite_rounded, color: Color(0xFFEF5350), size: 18)),
                      const Spacer(),
                      Text('WAVE ${e.wave}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white70)),
                      const SizedBox(width: 12),
                      Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
                    ]),
                  ),
                  if (e.over)
                    ArcadeResultOverlay(good: e.score >= 500, title: 'SHIP DESTROYED', detail: 'Score ${e.score}  -  reached wave ${e.wave}', onAgain: _start, onExit: () => Navigator.pop(context)),
                ]),
              ),
      ),
    );
  }
}

class _BlasterPainter extends CustomPainter {
  final BlasterEngine e;
  _BlasterPainter(this.e);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / BlasterEngine.w;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF05060F));
    final star = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (int i = 0; i < 40; i++) {
      final double sx = (i * 37.0) % 100.0;
      final double speed = 8.0 + (i % 5) * 6.0;
      final double sy = ((i * 53.0) + e.time * speed) % 160.0;
      canvas.drawCircle(Offset(sx * s, sy * s), (0.3 + (i % 3) * 0.2) * s, star);
    }
    for (final p in e.powers) {
      final c = p.kind == 0 ? const Color(0xFFFFB300) : (p.kind == 1 ? const Color(0xFF29B6F6) : const Color(0xFFEF5350));
      canvas.drawCircle(Offset(p.x * s, p.y * s), 3.2 * s, Paint()..color = c.withValues(alpha: 0.85));
      final tp = TextPainter(text: TextSpan(text: p.kind == 0 ? 'W' : (p.kind == 1 ? 'S' : '+'), style: TextStyle(fontSize: 3.6 * s, fontWeight: FontWeight.w900, color: Colors.white)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(p.x * s - tp.width / 2, p.y * s - tp.height / 2));
    }
    for (final en in e.enemies) {
      final c = en.type == 0 ? const Color(0xFFEF5350) : (en.type == 1 ? const Color(0xFFAB47BC) : const Color(0xFFFF9800));
      final o = Offset(en.x * s, en.y * s);
      final path = Path()..moveTo(o.dx, o.dy + en.r * s)..lineTo(o.dx - en.r * s, o.dy - en.r * s * 0.7)..lineTo(o.dx, o.dy - en.r * s * 0.2)..lineTo(o.dx + en.r * s, o.dy - en.r * s * 0.7)..close();
      canvas.drawPath(path, Paint()..color = c);
      if (en.type == 2) { canvas.drawCircle(o, en.r * s * 0.35, Paint()..color = Colors.white70); }
    }
    for (final b in e.bullets) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(b.x * s, b.y * s), width: 1.6 * s, height: 4.2 * s), Radius.circular(s)), Paint()..color = const Color(0xFF80DEEA));
    }
    for (final b in e.enemyBullets) {
      canvas.drawCircle(Offset(b.x * s, b.y * s), b.r * s, Paint()..color = const Color(0xFFFF5252));
      canvas.drawCircle(Offset(b.x * s, b.y * s), b.r * s * 0.5, Paint()..color = Colors.white);
    }
    final blink = e.inv > 0.0 && ((e.time * 14).floor() % 2 == 0);
    if (!e.over && !blink) {
      final o = Offset(e.px * s, e.py * s);
      final r = BlasterEngine.playerR * s;
      final ship = Path()..moveTo(o.dx, o.dy - r * 1.5)..lineTo(o.dx - r * 1.2, o.dy + r)..lineTo(o.dx, o.dy + r * 0.4)..lineTo(o.dx + r * 1.2, o.dy + r)..close();
      canvas.drawPath(ship, Paint()..color = const Color(0xFF4FC3F7));
      canvas.drawCircle(Offset(o.dx, o.dy - r * 0.2), r * 0.35, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(o.dx, o.dy + r * 1.2), r * 0.35, Paint()..color = const Color(0xFFFFB74D).withValues(alpha: 0.8));
      if (e.shield > 0.0) {
        canvas.drawCircle(o, r * 2.0, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = const Color(0xFF29B6F6).withValues(alpha: 0.4 + 0.4 * sin(e.time * 8).abs()));
      }
    }
  }

  @override
  bool shouldRepaint(_BlasterPainter oldDelegate) => true;
}
