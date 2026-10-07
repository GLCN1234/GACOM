import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import '../../../../core/services/duel_session.dart';

class GalleryTarget {
  final int type; // 0 normal, 1 small, 2 gold, 3 friendly
  double x;
  final double y;
  double vx;
  final double r;
  final double life;
  double age = 0.0;
  GalleryTarget(this.type, this.x, this.y, this.vx, this.r, this.life);
  int get points => type == 0 ? 10 : (type == 1 ? 25 : (type == 2 ? 50 : 0));
}

/// A 100 x 120 shooting range. Results of a shot: 0 ignored, 1 miss, 2 hit, 3 friendly hit.
class GalleryEngine {
  static const double w = 100.0;
  static const double h = 120.0;
  static const int magazine = 6;
  static const double roundTime = 60.0;
  static const double reloadTime = 1.1;
  static const double maxReloadWait = 1.1;

  final Random rng;
  final List<GalleryTarget> targets = <GalleryTarget>[];
  double timeLeft = roundTime;
  double elapsed = 0.0;
  double spawnT = 0.4;
  double reloadLeft = 0.0;
  int ammo = magazine;
  int score = 0;
  int combo = 0;
  int shots = 0;
  int hits = 0;
  int friendly = 0;
  bool over = false;
  int lastResult = 0;
  int lastPoints = 0;
  double lastX = 0.0;
  double lastY = 0.0;

  GalleryEngine(this.rng);

  int get multiplier {
    final int m = 1 + combo ~/ 3;
    return m > 5 ? 5 : m;
  }

  bool get reloading => reloadLeft > 0.0;

  void reload() {
    if (over || reloading || ammo >= magazine) return;
    reloadLeft = reloadTime;
  }

  /// Fires at (x, y). Returns the result code.
  int shoot(double x, double y) {
    lastX = x;
    lastY = y;
    if (over || reloading) {
      lastResult = 0;
      return 0;
    }
    if (ammo <= 0) {
      reloadLeft = reloadTime;
      lastResult = 0;
      return 0;
    }
    ammo--;
    shots++;
    GalleryTarget? best;
    double bestD = 1e9;
    for (final t in targets) {
      if (t.age < 0.1) continue;
      final double d = sqrt((t.x - x) * (t.x - x) + (t.y - y) * (t.y - y));
      if (d <= t.r + 1.5 && d < bestD) {
        bestD = d;
        best = t;
      }
    }
    if (ammo == 0) { reloadLeft = reloadTime; }
    if (best == null) {
      combo = 0;
      lastResult = 1;
      lastPoints = 0;
      return 1;
    }
    targets.remove(best);
    if (best.type == 3) {
      friendly++;
      combo = 0;
      final int before = score;
      score = score >= 30 ? score - 30 : 0;
      lastPoints = score - before;
      lastResult = 3;
      return 3;
    }
    final int pts = best.points * multiplier;
    score += pts;
    combo++;
    hits++;
    lastPoints = pts;
    lastResult = 2;
    return 2;
  }

  void _spawn() {
    final double prog = elapsed / roundTime;
    final double r = rng.nextDouble();
    int type = 0;
    if (r < 0.14) {
      type = 3;
    } else if (r < 0.14 + 0.08) {
      type = 2;
    } else if (r < 0.22 + 0.2 + 0.2 * prog) {
      type = 1;
    }
    final double rad = type == 1 ? 4.5 : (type == 2 ? 6.0 : 7.0);
    final double life = type == 1 ? 1.2 : (type == 2 ? 1.3 : (type == 3 ? 1.8 : 1.7));
    final double x = 10.0 + rng.nextDouble() * 80.0;
    final double y = 24.0 + rng.nextDouble() * 70.0;
    double vx = 0.0;
    if (rng.nextDouble() < 0.35) { vx = (rng.nextBool() ? 1 : -1) * (14.0 + rng.nextDouble() * 12.0); }
    targets.add(GalleryTarget(type, x, y, vx, rad, life));
  }

  void update(double dt) {
    if (over) return;
    elapsed += dt;
    timeLeft -= dt;
    if (timeLeft <= 0.0) {
      timeLeft = 0.0;
      over = true;
      return;
    }
    if (reloadLeft > 0.0) {
      reloadLeft -= dt;
      if (reloadLeft <= 0.0) {
        reloadLeft = 0.0;
        ammo = magazine;
      }
    }
    spawnT -= dt;
    if (spawnT <= 0.0) {
      final double iv = 0.95 - elapsed * 0.008;
      spawnT += iv < 0.45 ? 0.45 : iv;
      if (targets.length < 5) { _spawn(); }
    }
    for (final t in targets) {
      t.age += dt;
      t.x += t.vx * dt;
      if (t.x < t.r + 2) {
        t.x = t.r + 2;
        t.vx = -t.vx;
      } else if (t.x > w - t.r - 2) {
        t.x = w - t.r - 2;
        t.vx = -t.vx;
      }
    }
    targets.removeWhere((t) => t.age >= t.life);
  }
}

class TargetGalleryScreen extends StatefulWidget {
  const TargetGalleryScreen({super.key});
  @override
  State<TargetGalleryScreen> createState() => _TargetGalleryScreenState();
}

class _TargetGalleryScreenState extends State<TargetGalleryScreen> with SingleTickerProviderStateMixin {
  final Random _rng = duelRandom();
  GalleryEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  double _flash = 0.0;
  String _pop = '';
  Offset _popAt = Offset.zero;

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
      _e = GalleryEngine(_rng);
      _saved = false;
      _pop = '';
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
    if (_flash > 0.0) { _flash -= dt; }
    if (e.over && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Target Gallery', score: e.score);
      SoundService.instance.playWin();
    }
    setState(() {});
  }

  void _shoot(Offset local, double scale) {
    final e = _e;
    if (e == null || e.over) return;
    final r = e.shoot(local.dx / scale, local.dy / scale);
    if (r == 0) {
      SoundService.instance.playTap();
      return;
    }
    SoundService.instance.playShoot();
    _flash = 0.12;
    if (r == 2) {
      SoundService.instance.playCorrect();
      _pop = '+${e.lastPoints}';
    } else if (r == 3) {
      SoundService.instance.playWrong();
      _pop = e.lastPoints == 0 ? 'FRIENDLY!' : '${e.lastPoints}';
    } else {
      _pop = '';
    }
    _popAt = local;
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'target_gallery',
      title: 'HOW TO PLAY TARGET GALLERY',
      steps: const [
        HowToPlayStep(icon: Icons.gps_fixed_rounded, title: 'Tap to shoot', description: 'Tap a target to shoot it before it disappears. Small targets are worth more, and gold ones are worth the most.'),
        HowToPlayStep(icon: Icons.warning_amber_rounded, title: 'Do not shoot friendlies', description: 'Blue smiling targets are friendly. Hitting one costs you 30 points and breaks your combo.'),
        HowToPlayStep(icon: Icons.bolt_rounded, title: 'Build a combo', description: 'Every 3 hits in a row raises your multiplier (up to x5). Missing a shot resets it.'),
        HowToPlayStep(icon: Icons.refresh_rounded, title: 'Watch your ammo', description: 'You have 6 shots. Reloading takes about a second, so reload early in a quiet moment. You have 60 seconds.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('TARGET GALLERY')),
        body: e == null
            ? ArcadeStartView(icon: Icons.track_changes_rounded, title: 'TARGET GALLERY', subtitle: '60 seconds. Hit targets, spare the friendlies.', onStart: _start)
            : Stack(children: [
                Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                    child: Row(children: [
                      Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white)),
                      const SizedBox(width: 10),
                      if (e.multiplier > 1) Text('x${e.multiplier}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFFFFD54F))),
                      const Spacer(),
                      Text('${e.timeLeft.ceil()}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: e.timeLeft <= 10 ? const Color(0xFFEF5350) : Colors.white)),
                    ]),
                  ),
                  Expanded(
                    child: LayoutBuilder(builder: (context, cons) {
                      final double s = min(cons.maxWidth / GalleryEngine.w, cons.maxHeight / GalleryEngine.h);
                      return Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) => _shoot(d.localPosition, s),
                          child: SizedBox(
                            width: GalleryEngine.w * s,
                            height: GalleryEngine.h * s,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(children: [
                                CustomPaint(size: Size(GalleryEngine.w * s, GalleryEngine.h * s), painter: _GalleryPainter(e, _flash > 0)),
                                if (_pop.isNotEmpty && _flash > -0.5)
                                  Positioned(left: _popAt.dx - 24, top: _popAt.dy - 30, child: Opacity(opacity: clampD(0.4 + _flash * 4, 0.0, 1.0), child: Text(_pop, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)])))),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Row(children: [
                      for (int i = 0; i < GalleryEngine.magazine; i++)
                        Container(
                          width: 10,
                          height: 22,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(color: i < e.ammo ? const Color(0xFFFFB300) : GacomColors.border, borderRadius: BorderRadius.circular(3)),
                        ),
                      const Spacer(),
                      if (e.reloading) const Text('RELOADING...', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFFFB300))),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                        onPressed: e.reloading || e.ammo >= GalleryEngine.magazine ? null : () => e.reload(),
                        child: const Text('RELOAD', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ]),
                  ),
                ]),
                if (e.over)
                  ArcadeResultOverlay(
                    good: e.score >= 300,
                    title: 'TIME UP',
                    detail: 'Score ${e.score}  -  ${e.hits} hits from ${e.shots} shots (${e.shots == 0 ? 0 : (e.hits * 100 / e.shots).round()}% accuracy)',
                    onAgain: _start,
                    onExit: () => Navigator.pop(context),
                  ),
              ]),
      ),
    );
  }
}

class _GalleryPainter extends CustomPainter {
  final GalleryEngine e;
  final bool flash;
  _GalleryPainter(this.e, this.flash);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / GalleryEngine.w;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4E342E), Color(0xFF6D4C41), Color(0xFF3E2723)]).createShader(Offset.zero & size),
    );
    for (int i = 0; i < 3; i++) {
      final double y = (36.0 + i * 28.0) * s;
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 3 * s), Paint()..color = const Color(0x55000000));
    }
    for (final t in e.targets) {
      final double grow = clampD(t.age / 0.15, 0.0, 1.0);
      final double r = t.r * s * grow;
      final o = Offset(t.x * s, t.y * s);
      final double fade = t.life - t.age < 0.3 ? (t.life - t.age) / 0.3 : 1.0;
      if (t.type == 3) {
        canvas.drawCircle(o, r, Paint()..color = const Color(0xFF42A5F5).withValues(alpha: fade));
        canvas.drawCircle(o, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withValues(alpha: fade));
        canvas.drawCircle(o + Offset(-r * 0.3, -r * 0.2), r * 0.12, Paint()..color = Colors.white);
        canvas.drawCircle(o + Offset(r * 0.3, -r * 0.2), r * 0.12, Paint()..color = Colors.white);
        canvas.drawArc(Rect.fromCenter(center: o + Offset(0, r * 0.15), width: r * 0.8, height: r * 0.6), 0.2, pi - 0.4, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.6..color = Colors.white);
      } else {
        final base = t.type == 2 ? const Color(0xFFFFD54F) : const Color(0xFFE53935);
        canvas.drawCircle(o, r, Paint()..color = base.withValues(alpha: fade));
        canvas.drawCircle(o, r * 0.68, Paint()..color = Colors.white.withValues(alpha: fade));
        canvas.drawCircle(o, r * 0.38, Paint()..color = base.withValues(alpha: fade));
        canvas.drawCircle(o, r * 0.12, Paint()..color = Colors.white.withValues(alpha: fade));
      }
    }
    if (flash) { canvas.drawCircle(Offset(e.lastX * s, e.lastY * s), 3.2 * s, Paint()..color = Colors.white.withValues(alpha: 0.6)); }
    final cross = Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 1;
    canvas.drawLine(Offset(e.lastX * s - 5 * s, e.lastY * s), Offset(e.lastX * s + 5 * s, e.lastY * s), cross);
    canvas.drawLine(Offset(e.lastX * s, e.lastY * s - 5 * s), Offset(e.lastX * s, e.lastY * s + 5 * s), cross);
  }

  @override
  bool shouldRepaint(_GalleryPainter oldDelegate) => true;
}
