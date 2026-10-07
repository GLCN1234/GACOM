import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';

class PoolBall {
  final int id;
  double x;
  double y;
  double vx = 0.0;
  double vy = 0.0;
  bool pocketed = false;
  PoolBall(this.id, this.x, this.y);
  bool get moving => vx != 0.0 || vy != 0.0;
}

class PoolPocket {
  final double x;
  final double y;
  final double r;
  const PoolPocket(this.x, this.y, this.r);
}

class PoolShotPlan {
  final double angle;
  final double speed;
  final double score;
  const PoolShotPlan(this.angle, this.speed, this.score);
}

/// Eight-ball pool. Table is 200 by 100 units, y points down, cue ball is id 0.
/// Solids are 1-7, the 8 ball is 8, stripes are 9-15.
class PoolEngine {
  static const double tw = 200.0;
  static const double th = 100.0;
  static const double br = 2.5;
  static const double decel = 28.0;
  static const double cushionE = 0.78;
  static const double ballE = 0.96;
  static const double sideMouth = 5.0;
  static const double maxSpeed = 250.0;
  static const List<PoolPocket> pockets = [
    PoolPocket(0.0, 0.0, 6.0),
    PoolPocket(tw, 0.0, 6.0),
    PoolPocket(0.0, th, 6.0),
    PoolPocket(tw, th, 6.0),
    PoolPocket(tw / 2, -2.5, 4.4),
    PoolPocket(tw / 2, th + 2.5, 4.4),
  ];
  static const List<double> aiSigmaDeg = [3.2, 1.3, 0.4];
  static const List<double> aiPowerNoise = [0.12, 0.07, 0.025];

  final Random rng;
  final int level;
  final List<PoolBall> balls = <PoolBall>[];
  int current = 0; // 0 = you, 1 = AI
  final List<int> groups = <int>[-1, -1]; // 0 solids, 1 stripes
  bool inHand = false;
  bool breakShot = true;
  bool over = false;
  int winner = -1;
  String message = 'Break! Pull back and release to shoot.';
  bool shotActive = false;
  int firstHit = -1;
  bool railAfter = false;
  bool cuePocketed = false;
  final List<int> pocketedNow = <int>[];
  int ownBefore = -1;
  bool wasBreak = false;
  int hitEvents = 0;
  int railEvents = 0;
  int pocketEvents = 0;
  int playerPocketed = 0;
  int shots = 0;
  int fouls0 = 0;
  int fouls1 = 0;

  PoolEngine(this.rng, {required this.level}) {
    _rack();
  }

  static int groupOf(int id) {
    if (id >= 1 && id <= 7) return 0;
    if (id >= 9 && id <= 15) return 1;
    return 2;
  }

  void _rack() {
    balls.clear();
    balls.add(PoolBall(0, 50.0, th / 2));
    final List<int> rest = <int>[1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15];
    rest.shuffle(rng);
    // slots: row r has r+1 balls; slot index in rack order
    final List<int> order = List<int>.filled(15, 0);
    order[4] = 8; // centre of the third row
    // back corners: one solid and one stripe
    int solid = -1;
    int stripe = -1;
    for (final id in rest) {
      if (solid == -1 && id <= 7) solid = id;
      if (stripe == -1 && id >= 9) stripe = id;
    }
    rest.remove(solid);
    rest.remove(stripe);
    final bool flip = rng.nextBool();
    order[10] = flip ? solid : stripe;
    order[14] = flip ? stripe : solid;
    int ri = 0;
    for (int i = 0; i < 15; i++) {
      if (order[i] == 0) {
        order[i] = rest[ri];
        ri++;
      }
    }
    const double gap = 0.05;
    int k = 0;
    for (int row = 0; row < 5; row++) {
      for (int c = 0; c <= row; c++) {
        final double x = 150.0 + row * (sqrt(3.0) * br + gap);
        final double y = th / 2 + (c - row / 2.0) * (2.0 * br + gap);
        balls.add(PoolBall(order[k], x, y));
        k++;
      }
    }
    // balls list index must equal id for quick lookup
    balls.sort((a, b) => a.id.compareTo(b.id));
  }

  int remaining(int group) {
    int n = 0;
    for (final b in balls) {
      if (b.id != 0 && b.id != 8 && !b.pocketed && groupOf(b.id) == group) n++;
    }
    return n;
  }

  bool get allStopped {
    for (final b in balls) {
      if (!b.pocketed && b.moving) return false;
    }
    return true;
  }

  List<int> legalTargets(int who) {
    final List<int> out = <int>[];
    final int g = groups[who];
    if (g == -1) {
      for (final b in balls) {
        if (b.id != 0 && b.id != 8 && !b.pocketed) out.add(b.id);
      }
    } else if (remaining(g) == 0) {
      if (!balls[8].pocketed) out.add(8);
    } else {
      for (final b in balls) {
        if (b.id != 0 && b.id != 8 && !b.pocketed && groupOf(b.id) == g) out.add(b.id);
      }
    }
    return out;
  }

  bool canPlace(double x, double y) {
    if (x < br || x > tw - br || y < br || y > th - br) return false;
    for (final b in balls) {
      if (b.id == 0 || b.pocketed) continue;
      final double dx = b.x - x;
      final double dy = b.y - y;
      if (dx * dx + dy * dy < (2.0 * br + 0.1) * (2.0 * br + 0.1)) return false;
    }
    return true;
  }

  void placeCue(double x, double y) {
    final c = balls[0];
    c.x = x;
    c.y = y;
    c.vx = 0.0;
    c.vy = 0.0;
    c.pocketed = false;
  }

  /// Moves the cue ball to the nearest free spot on a coarse grid if it overlaps another ball.
  void settleCue() {
    final c = balls[0];
    if (canPlace(c.x, c.y)) return;
    for (int gx = 0; gx < 40; gx++) {
      for (int gy = 0; gy < 20; gy++) {
        final double x = 50.0 + gx * 3.0 * (gx.isEven ? 1.0 : -1.0);
        final double y = 5.0 + gy * 4.5;
        if (canPlace(x, y)) {
          placeCue(x, y);
          return;
        }
      }
    }
  }

  void shoot(double angle, double speed) {
    final c = balls[0];
    final double sp = clampD(speed, 10.0, maxSpeed);
    c.vx = cos(angle) * sp;
    c.vy = sin(angle) * sp;
    firstHit = -1;
    railAfter = false;
    cuePocketed = false;
    pocketedNow.clear();
    final int g = groups[current];
    ownBefore = g == -1 ? -1 : remaining(g);
    wasBreak = breakShot;
    shotActive = true;
    inHand = false;
    shots++;
  }

  void step(double dt) {
    final int n = max(1, (dt * 240.0).ceil());
    final double h = dt / n;
    for (int i = 0; i < n; i++) {
      _sub(h);
    }
  }

  void _sub(double h) {
    for (final b in balls) {
      if (b.pocketed || !b.moving) continue;
      b.x += b.vx * h;
      b.y += b.vy * h;
      final double sp = sqrt(b.vx * b.vx + b.vy * b.vy);
      final double ns = sp - decel * h;
      if (ns < 1.0) {
        b.vx = 0.0;
        b.vy = 0.0;
      } else {
        final double f = ns / sp;
        b.vx *= f;
        b.vy *= f;
      }
    }
    for (final b in balls) {
      if (!b.pocketed) _pocketCheck(b);
    }
    for (final b in balls) {
      if (!b.pocketed) _cushion(b);
    }
    for (int i = 0; i < balls.length; i++) {
      final a = balls[i];
      if (a.pocketed) continue;
      for (int j = i + 1; j < balls.length; j++) {
        final b = balls[j];
        if (b.pocketed) continue;
        if (!a.moving && !b.moving) continue;
        _collide(a, b);
      }
    }
    for (final b in balls) {
      if (!b.pocketed) _cushion(b);
    }
  }

  void _pocketCheck(PoolBall b) {
    for (final p in pockets) {
      final double dx = b.x - p.x;
      final double dy = b.y - p.y;
      if (dx * dx + dy * dy < p.r * p.r) {
        b.pocketed = true;
        b.vx = 0.0;
        b.vy = 0.0;
        pocketEvents++;
        if (b.id == 0) {
          cuePocketed = true;
        } else {
          pocketedNow.add(b.id);
        }
        return;
      }
    }
  }

  void _rail() {
    railEvents++;
    if (firstHit != -1) railAfter = true;
  }

  void _cushion(PoolBall b) {
    final bool mouth = (b.x - tw / 2).abs() < sideMouth;
    if (b.x < br) {
      b.x = br;
      if (b.vx < 0.0) { b.vx = -b.vx * cushionE; _rail(); }
    }
    if (b.x > tw - br) {
      b.x = tw - br;
      if (b.vx > 0.0) { b.vx = -b.vx * cushionE; _rail(); }
    }
    if (b.y < br && !mouth) {
      b.y = br;
      if (b.vy < 0.0) { b.vy = -b.vy * cushionE; _rail(); }
    }
    if (b.y > th - br && !mouth) {
      b.y = th - br;
      if (b.vy > 0.0) { b.vy = -b.vy * cushionE; _rail(); }
    }
  }

  void _collide(PoolBall a, PoolBall b) {
    final double dx = b.x - a.x;
    final double dy = b.y - a.y;
    final double d2 = dx * dx + dy * dy;
    const double minD = 2.0 * br;
    if (d2 >= minD * minD || d2 == 0.0) return;
    final double d = sqrt(d2);
    final double nx = dx / d;
    final double ny = dy / d;
    final double overlap = minD - d;
    a.x -= nx * overlap / 2.0;
    a.y -= ny * overlap / 2.0;
    b.x += nx * overlap / 2.0;
    b.y += ny * overlap / 2.0;
    final double vn = (a.vx - b.vx) * nx + (a.vy - b.vy) * ny;
    if (vn > 0.0) {
      final double j = (1.0 + ballE) / 2.0 * vn;
      a.vx -= j * nx;
      a.vy -= j * ny;
      b.vx += j * nx;
      b.vy += j * ny;
      hitEvents++;
      if (shotActive && firstHit == -1) {
        if (a.id == 0) { firstHit = b.id; }
        else if (b.id == 0) { firstHit = a.id; }
      }
    }
  }

  void _respotEight() {
    final c8 = balls[8];
    c8.vx = 0.0;
    c8.vy = 0.0;
    c8.pocketed = false;
    for (int i = 0; i < 60; i++) {
      final double x = 150.0 + i * (2.0 * br + 0.2);
      if (x > tw - br) break;
      if (canPlace(x, th / 2)) {
        c8.x = x;
        c8.y = th / 2;
        return;
      }
    }
    c8.x = 150.0;
    c8.y = th / 2;
  }

  /// Call once every ball has stopped after a shot. Applies the rules.
  void endShot() {
    shotActive = false;
    final int cur = current;
    final int opp = 1 - cur;
    bool foul = false;
    String reason = '';
    if (cuePocketed) { foul = true; reason = 'Scratch'; }
    if (firstHit == -1) {
      foul = true;
      if (reason.isEmpty) reason = 'No ball hit';
    } else {
      final int g = groups[cur];
      bool bad = false;
      if (g == -1) {
        bad = firstHit == 8;
      } else if (ownBefore == 0) {
        bad = firstHit != 8;
      } else {
        bad = groupOf(firstHit) != g;
      }
      if (bad) { foul = true; if (reason.isEmpty) reason = 'Wrong ball first'; }
    }
    if (!foul && !railAfter && pocketedNow.isEmpty) { foul = true; reason = 'No rail'; }

    if (pocketedNow.contains(8)) {
      if (wasBreak) {
        pocketedNow.remove(8);
        _respotEight();
      } else {
        over = true;
        final bool clean = !foul && ownBefore == 0;
        winner = clean ? cur : opp;
        if (clean) {
          message = cur == 0 ? 'You sank the 8 ball. You win!' : 'AI sank the 8 ball. AI wins.';
        } else {
          message = cur == 0 ? 'You sank the 8 ball too early or fouled. AI wins.' : 'AI lost the 8 ball. You win!';
        }
        breakShot = false;
        return;
      }
    }

    if (!foul && groups[cur] == -1) {
      for (final id in pocketedNow) {
        if (id != 8) {
          groups[cur] = groupOf(id);
          groups[opp] = 1 - groupOf(id);
          break;
        }
      }
    }
    bool ownPocketed = false;
    if (groups[cur] != -1) {
      for (final id in pocketedNow) {
        if (id != 8 && groupOf(id) == groups[cur]) {
          ownPocketed = true;
          if (cur == 0) playerPocketed++;
        }
      }
    }
    breakShot = false;
    if (cuePocketed) {
      placeCue(50.0, th / 2);
      settleCue();
    }
    if (foul) {
      if (cur == 0) { fouls0++; } else { fouls1++; }
      current = opp;
      inHand = true;
      message = '${cur == 0 ? 'Foul: ' : 'AI foul: '}$reason. ${current == 0 ? 'Ball in hand for you.' : 'Ball in hand for the AI.'}';
    } else if (ownPocketed) {
      inHand = false;
      message = cur == 0 ? 'Nice shot. Shoot again.' : 'AI pocketed one and shoots again.';
    } else {
      current = opp;
      inHand = false;
      message = current == 0 ? 'Your turn.' : 'AI is thinking...';
    }
  }

  /// Distance along an aim ray to the first ball (returns -1 id when none), for the aim guide.
  double castRay(double ox, double oy, double angle, List<int> hitId) {
    final double dx = cos(angle);
    final double dy = sin(angle);
    double best = 1000.0;
    int bid = -1;
    for (final b in balls) {
      if (b.id == 0 || b.pocketed) continue;
      final double fx = b.x - ox;
      final double fy = b.y - oy;
      final double t = fx * dx + fy * dy;
      if (t <= 0.0) continue;
      final double perp2 = fx * fx + fy * fy - t * t;
      final double r2 = (2.0 * br) * (2.0 * br);
      if (perp2 >= r2) continue;
      final double tHit = t - sqrt(r2 - perp2);
      if (tHit < best) { best = tHit; bid = b.id; }
    }
    if (hitId.isEmpty) { hitId.add(bid); } else { hitId[0] = bid; }
    if (bid == -1) {
      // distance to the nearest cushion
      double tx = 1000.0;
      double ty = 1000.0;
      if (dx > 1e-9) tx = (tw - br - ox) / dx;
      if (dx < -1e-9) tx = (br - ox) / dx;
      if (dy > 1e-9) ty = (th - br - oy) / dy;
      if (dy < -1e-9) ty = (br - oy) / dy;
      best = min(tx, ty);
    }
    return best;
  }

  // ---------------------------------------------------------------- AI

  double _gauss() {
    final double u1 = max(1e-9, rng.nextDouble());
    final double u2 = rng.nextDouble();
    return sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
  }

  bool _clear(double ax, double ay, double bx, double by, int ignoreA, int ignoreB, double minDist) {
    final double sx = bx - ax;
    final double sy = by - ay;
    final double len2 = sx * sx + sy * sy;
    for (final b in balls) {
      if (b.pocketed || b.id == ignoreA || b.id == ignoreB) continue;
      double t = len2 == 0.0 ? 0.0 : ((b.x - ax) * sx + (b.y - ay) * sy) / len2;
      t = clampD(t, 0.0, 1.0);
      final double cx = ax + sx * t - b.x;
      final double cy = ay + sy * t - b.y;
      if (cx * cx + cy * cy < minDist * minDist) return false;
    }
    return true;
  }

  List<PoolShotPlan> candidates() {
    final c = balls[0];
    final List<PoolShotPlan> list = <PoolShotPlan>[];
    for (final id in legalTargets(current)) {
      final t = balls[id];
      for (final pk in pockets) {
        final double dx = pk.x - t.x;
        final double dy = pk.y - t.y;
        final double dist = sqrt(dx * dx + dy * dy);
        if (dist < 0.001) continue;
        final double ux = dx / dist;
        final double uy = dy / dist;
        final double gx = t.x - ux * 2.0 * br;
        final double gy = t.y - uy * 2.0 * br;
        if (gx < br || gx > tw - br || gy < br || gy > th - br) continue;
        final double cx = gx - c.x;
        final double cy = gy - c.y;
        final double cd = sqrt(cx * cx + cy * cy);
        if (cd < 0.01) continue;
        final double cosA = (cx * ux + cy * uy) / cd;
        if (cosA < 0.3) continue;
        if (!_clear(c.x, c.y, gx, gy, 0, id, 2.0 * br - 0.1)) continue;
        if (!_clear(t.x, t.y, pk.x, pk.y, 0, id, 2.0 * br - 0.1)) continue;
        final double vObj = sqrt(2.0 * decel * dist * 1.25) + 14.0;
        final double vHit = vObj / (0.98 * cosA);
        final double v0 = sqrt(vHit * vHit + 2.0 * decel * cd);
        final double score = cosA - (cd + dist) / 500.0;
        list.add(PoolShotPlan(atan2(cy, cx), clampD(v0, 40.0, maxSpeed), score));
      }
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  PoolShotPlan _safety() {
    final c = balls[0];
    final targets = legalTargets(current);
    double bestD = 1e9;
    int bid = -1;
    for (final id in targets) {
      final t = balls[id];
      final double dx = t.x - c.x;
      final double dy = t.y - c.y;
      final double d = sqrt(dx * dx + dy * dy);
      if (d < bestD) { bestD = d; bid = id; }
    }
    if (bid == -1) return PoolShotPlan(0.0, 80.0, 0.0);
    final t = balls[bid];
    final double ang = atan2(t.y - c.y, t.x - c.x);
    final double spd = clampD(sqrt(2.0 * decel * bestD) + 55.0, 70.0, 170.0);
    return PoolShotPlan(ang, spd, -1.0);
  }

  /// Chooses an AI shot (placing the cue ball first when in hand). Returns the noisy plan.
  PoolShotPlan aiPlan() {
    if (wasBreakPending()) {
      final c = balls[0];
      final double ang = atan2(th / 2 - c.y, 150.0 - c.x);
      return _noisy(PoolShotPlan(ang, 245.0, 0.0), 0.6);
    }
    if (inHand) {
      double bestScore = -1e9;
      double bx = 50.0;
      double by = th / 2;
      final List<List<double>> spots = <List<double>>[
        <double>[50.0, th / 2]
      ];
      for (int i = 0; i < 28; i++) {
        spots.add(<double>[8.0 + rng.nextDouble() * (tw - 16.0), 8.0 + rng.nextDouble() * (th - 16.0)]);
      }
      for (final s in spots) {
        if (!canPlace(s[0], s[1])) continue;
        placeCue(s[0], s[1]);
        final cands = candidates();
        final double sc = cands.isEmpty ? -5.0 : cands.first.score;
        if (sc > bestScore) { bestScore = sc; bx = s[0]; by = s[1]; }
      }
      placeCue(bx, by);
      inHand = false;
    }
    final cands = candidates();
    PoolShotPlan base;
    if (cands.isEmpty) {
      base = _safety();
    } else {
      int pick = 0;
      if (level == 0 && cands.length > 1 && rng.nextDouble() < 0.5) {
        pick = rng.nextInt(min(3, cands.length));
      } else if (level == 1 && cands.length > 1 && rng.nextDouble() < 0.2) {
        pick = rng.nextInt(min(2, cands.length));
      }
      base = cands[pick];
    }
    return _noisy(base, 1.0);
  }

  bool wasBreakPending() => breakShot && current == 1;

  PoolShotPlan _noisy(PoolShotPlan p, double mult) {
    final double ang = p.angle + _gauss() * aiSigmaDeg[level] * pi / 180.0 * mult;
    final double spd = p.speed * (1.0 + _gauss() * aiPowerNoise[level]);
    return PoolShotPlan(ang, clampD(spd, 20.0, maxSpeed), p.score);
  }
}

class PoolScreen extends StatefulWidget {
  const PoolScreen({super.key});
  @override
  State<PoolScreen> createState() => _PoolScreenState();
}

class _PoolScreenState extends State<PoolScreen> with SingleTickerProviderStateMixin {
  static const List<String> _levels = ['EASY', 'MEDIUM', 'HARD'];
  static const double _rail = 7.0;
  static const double _maxPull = 55.0;
  static const double _minPull = 6.0;
  static const List<Color> _colors = [
    Colors.white,
    Color(0xFFF2C500),
    Color(0xFF1E63C6),
    Color(0xFFD32F2F),
    Color(0xFF6A1B9A),
    Color(0xFFEF6C00),
    Color(0xFF2E7D32),
    Color(0xFF8D1B1B),
    Color(0xFF111111),
  ];

  final Random _rng = Random();
  PoolEngine? _e;
  int _level = 1;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _saved = false;
  bool _moving = false;
  double _aiWait = 0.0;
  double _k = 3.0;
  Offset? _finger; // table units
  bool _placing = false;

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
      _e = PoolEngine(_rng, level: _level);
      _saved = false;
      _moving = false;
      _aiWait = 0.0;
      _finger = null;
      _placing = false;
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _toSetup() {
    _ticker.stop();
    setState(() => _e = null);
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) { dt = 0.05; }
    if (e.over) {
      _finish(e);
      return;
    }
    if (_moving) {
      final int h0 = e.hitEvents;
      final int r0 = e.railEvents;
      final int p0 = e.pocketEvents;
      e.step(dt);
      if (e.hitEvents > h0) { SoundService.instance.playPieceMove(); }
      if (e.pocketEvents > p0) { SoundService.instance.playDrop(); }
      else if (e.railEvents > r0) { SoundService.instance.playTap(); }
      if (e.allStopped) {
        _moving = false;
        e.endShot();
        _aiWait = 0.9;
        if (e.over) { _finish(e); }
      }
    } else if (e.current == 1 && !e.over) {
      _aiWait -= dt;
      if (_aiWait <= 0.0) {
        final plan = e.aiPlan();
        e.shoot(plan.angle, plan.speed);
        SoundService.instance.playShoot();
        _moving = true;
      }
    }
    setState(() {});
  }

  void _finish(PoolEngine e) {
    if (_saved) return;
    _saved = true;
    _ticker.stop();
    final bool won = e.winner == 0;
    final int score = e.playerPocketed * 50 + (won ? 300 : 0);
    GameScoreService.save(gameName: '8-Ball Pool', score: score, won: won);
    if (won) { SoundService.instance.playWin(); } else { SoundService.instance.playLose(); }
    setState(() {});
  }

  Offset _toTable(Offset px) => Offset(px.dx / _k - _rail, px.dy / _k - _rail);

  bool get _myAim {
    final e = _e;
    return e != null && !e.over && !_moving && e.current == 0;
  }

  void _down(Offset p) {
    final e = _e;
    if (e == null || !_myAim) return;
    final t = _toTable(p);
    if (e.inHand) {
      _placing = true;
      if (e.canPlace(t.dx, t.dy)) { e.placeCue(t.dx, t.dy); }
      setState(() {});
    } else {
      setState(() => _finger = t);
    }
  }

  void _move(Offset p) {
    final e = _e;
    if (e == null || !_myAim) return;
    final t = _toTable(p);
    if (_placing) {
      if (e.canPlace(t.dx, t.dy)) { e.placeCue(t.dx, t.dy); }
      setState(() {});
    } else if (_finger != null) {
      setState(() => _finger = t);
    }
  }

  void _up() {
    final e = _e;
    if (e == null) return;
    if (_placing) {
      _placing = false;
      e.inHand = false;
      e.message = 'Cue ball placed. Pull back and release to shoot.';
      setState(() {});
      return;
    }
    final f = _finger;
    _finger = null;
    if (f == null || !_myAim) {
      setState(() {});
      return;
    }
    final c = e.balls[0];
    final double dx = c.x - f.dx;
    final double dy = c.y - f.dy;
    final double dist = sqrt(dx * dx + dy * dy);
    if (dist < _minPull) {
      setState(() {});
      return;
    }
    final double power = clampD(dist / _maxPull, 0.0, 1.0);
    final double speed = 25.0 + power * 225.0;
    e.shoot(atan2(dy, dx), speed);
    SoundService.instance.playShoot();
    _moving = true;
    setState(() {});
  }

  String _groupName(PoolEngine e, int who) {
    final int g = e.groups[who];
    if (g == -1) return 'open';
    return g == 0 ? 'solids' : 'stripes';
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'pool',
      title: 'HOW TO PLAY 8-BALL POOL',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Pull back to shoot', description: 'Put your finger anywhere on the table and pull it away from the cue ball, like a slingshot. The cue ball fires the opposite way. The further you pull, the harder the shot. Let go to shoot.'),
        HowToPlayStep(icon: Icons.sports_baseball_rounded, title: 'Pocket your group', description: 'The first ball you pocket decides your group: solids (1-7) or stripes (9-15). Keep potting your group and you keep your turn.'),
        HowToPlayStep(icon: Icons.warning_amber_rounded, title: 'Fouls', description: 'Scratching the cue ball, hitting nothing, hitting the wrong group first, or sending nothing to a cushion is a foul. Your opponent then places the cue ball anywhere.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Win with the 8 ball', description: 'Once your whole group is gone, pocket the black 8 ball to win. Pocket it early, or foul while doing it, and you lose.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('8-BALL POOL')),
        body: e == null
            ? ArcadeStartView(
                icon: Icons.sports_baseball_rounded,
                title: '8-BALL POOL',
                subtitle: 'Pot your group, then sink the 8 ball.',
                buttonLabel: 'BREAK',
                onStart: _start,
                extra: [ArcadeChoiceRow(label: 'AI SKILL', options: _levels, selected: _level, onSelect: (i) => setState(() => _level = i))],
              )
            : Stack(children: [_game(e), if (e.over) _result(e)]),
      ),
    );
  }

  Widget _game(PoolEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      final double totalW = PoolEngine.tw + 2.0 * _rail;
      final double totalH = PoolEngine.th + 2.0 * _rail;
      double width = cons.maxWidth - 8.0;
      double height = width * totalH / totalW;
      if (height > cons.maxHeight - 120.0) {
        height = cons.maxHeight - 120.0;
        width = height * totalW / totalH;
      }
      _k = width / totalW;
      double aimAngle = 0.0;
      double power = 0.0;
      double rayLen = 0.0;
      int rayHit = -1;
      final f = _finger;
      final c = e.balls[0];
      if (f != null && _myAim) {
        final double dx = c.x - f.dx;
        final double dy = c.y - f.dy;
        final double dist = sqrt(dx * dx + dy * dy);
        if (dist >= _minPull) {
          aimAngle = atan2(dy, dx);
          power = clampD(dist / _maxPull, 0.0, 1.0);
          final List<int> hit = <int>[];
          rayLen = e.castRay(c.x, c.y, aimAngle, hit);
          rayHit = hit.isEmpty ? -1 : hit[0];
        }
      }
      final bool showAim = power > 0.0;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('YOU: ${_groupName(e, 0)}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: e.current == 0 ? GacomColors.deepOrange : GacomColors.textMuted)),
            Text('AI: ${_groupName(e, 1)}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: e.current == 1 ? GacomColors.accentCyan : GacomColors.textMuted)),
          ]),
        ),
        SizedBox(
          width: width,
          height: height,
          child: Listener(
            onPointerDown: (d) => _down(d.localPosition),
            onPointerMove: (d) => _move(d.localPosition),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) {
              _finger = null;
              _placing = false;
              setState(() {});
            },
            child: CustomPaint(painter: _PoolPainter(e, _colors, _rail, showAim, aimAngle, rayLen, rayHit, f)),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(e.message, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: width * 0.6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: showAim ? power : 0.0, minHeight: 8, backgroundColor: GacomColors.cardDark, color: Color.lerp(Colors.green, Colors.red, power)),
          ),
        ),
        const SizedBox(height: 4),
        Text(e.inHand && e.current == 0 ? 'BALL IN HAND: drag to place the cue ball' : 'POWER', style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, letterSpacing: 1)),
      ]);
    });
  }

  Widget _result(PoolEngine e) {
    final bool won = e.winner == 0;
    return ArcadeResultOverlay(
      good: won,
      title: won ? 'YOU WIN!' : 'AI WINS',
      detail: e.message,
      onAgain: _toSetup,
      onExit: () => Navigator.pop(context),
      againLabel: 'REMATCH',
    );
  }
}

class _PoolPainter extends CustomPainter {
  final PoolEngine e;
  final List<Color> colors;
  final double rail;
  final bool showAim;
  final double aimAngle;
  final double rayLen;
  final int rayHit;
  final Offset? finger;
  _PoolPainter(this.e, this.colors, this.rail, this.showAim, this.aimAngle, this.rayLen, this.rayHit, this.finger);

  @override
  void paint(Canvas canvas, Size size) {
    final double k = size.width / (PoolEngine.tw + 2.0 * rail);
    Offset o(double x, double y) => Offset((x + rail) * k, (y + rail) * k);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(rail * k * 0.9)), Paint()..color = const Color(0xFF5D3A1A));
    final felt = Rect.fromLTWH(rail * k, rail * k, PoolEngine.tw * k, PoolEngine.th * k);
    canvas.drawRect(felt, Paint()..color = const Color(0xFF0B6E3A));
    canvas.drawRect(felt, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF084D2A));
    for (final p in PoolEngine.pockets) {
      canvas.drawCircle(o(p.x, p.y), (p.r + 0.6) * k, Paint()..color = const Color(0xFF050505));
    }
    final spot = Paint()..color = Colors.white24;
    canvas.drawCircle(o(50.0, PoolEngine.th / 2), 1.2 * k, spot);
    canvas.drawCircle(o(150.0, PoolEngine.th / 2), 1.2 * k, spot);
    final c = e.balls[0];
    if (showAim && !c.pocketed) {
      final double len = rayLen;
      final Offset a = o(c.x, c.y);
      final Offset b = o(c.x + cos(aimAngle) * len, c.y + sin(aimAngle) * len);
      canvas.drawLine(a, b, Paint()..color = Colors.white70..strokeWidth = 1.4);
      canvas.drawCircle(b, PoolEngine.br * k, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white70);
      if (rayHit != -1) {
        final t = e.balls[rayHit];
        final double gx = c.x + cos(aimAngle) * len;
        final double gy = c.y + sin(aimAngle) * len;
        final double nx = t.x - gx;
        final double ny = t.y - gy;
        final double nl = max(0.001, sqrt(nx * nx + ny * ny));
        canvas.drawLine(o(t.x, t.y), o(t.x + nx / nl * 14.0, t.y + ny / nl * 14.0), Paint()..color = Colors.yellowAccent.withValues(alpha: 0.8)..strokeWidth = 1.4);
      }
      // cue stick behind the ball
      final double back = 4.0 + 18.0;
      canvas.drawLine(o(c.x - cos(aimAngle) * 4.0, c.y - sin(aimAngle) * 4.0), o(c.x - cos(aimAngle) * back, c.y - sin(aimAngle) * back), Paint()..color = const Color(0xFFD9B27A)..strokeWidth = 3.0..strokeCap = StrokeCap.round);
    }
    for (final b in e.balls) {
      if (b.pocketed) continue;
      final Offset p = o(b.x, b.y);
      final double r = PoolEngine.br * k;
      final int idx = b.id <= 8 ? b.id : b.id - 8;
      final Color col = colors[idx];
      canvas.drawCircle(p + Offset(r * 0.18, r * 0.22), r, Paint()..color = Colors.black26);
      if (b.id >= 9) {
        canvas.drawCircle(p, r, Paint()..color = Colors.white);
        canvas.save();
        canvas.clipPath(Path()..addOval(Rect.fromCircle(center: p, radius: r)));
        canvas.drawRect(Rect.fromLTWH(p.dx - r, p.dy - r * 0.55, r * 2, r * 1.1), Paint()..color = col);
        canvas.restore();
      } else {
        canvas.drawCircle(p, r, Paint()..color = col);
      }
      if (b.id != 0) {
        canvas.drawCircle(p, r * 0.5, Paint()..color = Colors.white);
        if (r > 5.0) {
          final tp = TextPainter(text: TextSpan(text: '${b.id}', style: TextStyle(color: Colors.black, fontSize: r * 0.62, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
          tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
        }
      }
      canvas.drawCircle(p - Offset(r * 0.3, r * 0.3), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.45));
    }
    final f = finger;
    if (f != null && showAim) {
      canvas.drawCircle(o(f.dx, f.dy), 7, Paint()..color = Colors.white24);
    }
  }

  @override
  bool shouldRepaint(_PoolPainter oldDelegate) => true;
}
