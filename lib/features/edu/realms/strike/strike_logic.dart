import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'strike_skins.dart';

double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// One answer carried by an enemy.
class StrikeDrone {
  double x;
  double y;
  double vx = 0;
  double vy = 0;
  final int index;
  final bool correct;
  bool alive = true;
  double fireT;
  double turnT = 0;
  double wob;
  StrikeDrone(this.x, this.y, this.index, this.correct, this.fireT, this.wob);
}

class StrikeBullet {
  double x;
  double y;
  final double vx;
  final double vy;
  double ttl;
  final bool foe;
  StrikeBullet(this.x, this.y, this.vx, this.vy, this.ttl, this.foe);
}

class StrikeBurst {
  final double x;
  final double y;
  final Color color;
  double t = 0;
  StrikeBurst(this.x, this.y, this.color);
}

/// Strike: an action arena where every question is a fight. The answers are
/// carried by enemies. You run, dodge, and shoot the enemy carrying the right
/// answer. The rules live here with no drawing code.
class StrikeLogic extends RealmLogic {
  final StrikeSkin skin;
  StrikeLogic(RealmContent content, this.skin) : super(content) {
    px = worldSize / 2;
    py = worldSize / 2;
    _nextRound();
  }

  static const double worldSize = 1900;
  static const double totalSeconds = 180;
  static const double roundLimit = 16;
  static const double bulletSpeed = 720;
  static const double droneRadius = 26;

  double px = 0;
  double py = 0;
  double face = 1;
  double aim = 0;
  int hp = 5;
  double inv = 0;
  double dashT = 0;
  double dashCd = 0;
  double fireCd = 0;
  double flash = 0;
  int score = 0;
  int round = 0;
  int kills = 0;

  OdyQuestion? q;
  final List<StrikeDrone> drones = <StrikeDrone>[];
  final List<StrikeBullet> bullets = <StrikeBullet>[];
  final List<StrikeBurst> bursts = <StrikeBurst>[];

  /// 0 playing, 1 showing the result of the round.
  int phase = 0;
  double roundT = roundLimit;
  double resolveT = 0;
  String message = '';
  bool lastOk = false;
  int lock = -1;
  bool get moving => inputX.abs() > 0.05 || inputY.abs() > 0.05;

  double get timeLeft => max(0.0, totalSeconds - time);

  @override
  int get hearts => hp < 0 ? 0 : hp;

  @override
  int get finalScore => score;

  @override
  int get xp => stats.baseXp + round * 2;

  @override
  String get resultTitle => hp <= 0 ? 'YOU WERE TAKEN DOWN' : 'TIME IS UP';

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('$score', Icons.stars_rounded, skin.accent),
        RealmChip('x${stats.streak}', Icons.local_fire_department_rounded, const Color(0xFFFF8A3D)),
        RealmChip('${timeLeft.ceil()}s', Icons.timer_rounded, Colors.white),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Rounds': '$round',
        'Best streak': '${stats.bestStreak}',
      };

  @override
  double actionReady(int id) {
    if (id == 0) return fireCd <= 0 ? 1.0 : _cl(1 - fireCd / 0.2, 0.0, 1.0);
    return dashCd <= 0 ? 1.0 : _cl(1 - dashCd / 2.6, 0.0, 1.0);
  }

  // ---- rounds --------------------------------------------------------------

  void _nextRound() {
    round++;
    phase = 0;
    roundT = roundLimit;
    lock = -1;
    message = '';
    drones.clear();
    bullets.removeWhere((StrikeBullet b) => b.foe);
    final OdyQuestion nq = content.ask();
    q = nq;
    final int n = nq.options.length;
    final double base = rng.nextDouble() * pi * 2;
    for (int i = 0; i < n; i++) {
      final double a = base + i * (pi * 2 / n) + (rng.nextDouble() - 0.5) * 0.5;
      final double r = 330 + rng.nextDouble() * 180;
      final double x = _cl(px + cos(a) * r, 60.0, worldSize - 60);
      final double y = _cl(py + sin(a) * r, 60.0, worldSize - 60);
      drones.add(StrikeDrone(x, y, i, i == nq.answerIndex, 1.2 + rng.nextDouble() * 1.8, rng.nextDouble() * 6.28));
    }
  }

  double get _droneSpeed => min(52.0 + round * 2.5, 105.0);

  // ---- per frame -----------------------------------------------------------

  @override
  void step(double dt) {
    if (over) return;
    if (time >= totalSeconds) {
      over = true;
      cues.add(stats.correct > 0 ? 'win' : 'lose');
      return;
    }
    for (final StrikeBurst b in bursts) {
      b.t += dt;
    }
    bursts.removeWhere((StrikeBurst b) => b.t > 0.6);
    if (inv > 0) inv -= dt;
    if (dashT > 0) dashT -= dt;
    if (dashCd > 0) dashCd -= dt;
    if (fireCd > 0) fireCd -= dt;
    if (flash > 0) flash -= dt;

    final double speed = dashT > 0 ? 470 : 190;
    px = _cl(px + inputX * speed * dt, 34.0, worldSize - 34);
    py = _cl(py + inputY * speed * dt, 34.0, worldSize - 34);
    if (inputX.abs() > 0.1) face = inputX > 0 ? 1 : -1;

    _moveBullets(dt);

    if (phase == 1) {
      resolveT -= dt;
      if (resolveT <= 0) {
        if (hp <= 0) {
          over = true;
          cues.add('lose');
        } else {
          _nextRound();
        }
      }
      return;
    }

    roundT -= dt;
    if (roundT <= 0) {
      stats.record(q!, false);
      _resolve(false, 'TIME UP. The answer was ${q!.answer}.');
      return;
    }
    for (final StrikeDrone d in drones) {
      if (d.alive) _moveDrone(d, dt);
    }
  }

  void _moveDrone(StrikeDrone d, double dt) {
    final double dx = px - d.x;
    final double dy = py - d.y;
    final double dist = max(1.0, sqrt(dx * dx + dy * dy));
    final double ux = dx / dist;
    final double uy = dy / dist;
    final double sp = _droneSpeed;
    d.wob += dt * 2.2;
    switch (skin.behaviour) {
      case StrikeBehaviour.chase:
        d.vx = ux * sp + cos(d.wob) * 14;
        d.vy = uy * sp + sin(d.wob) * 14;
        break;
      case StrikeBehaviour.shoot:
        final double want = dist > 300 ? 1.0 : (dist < 220 ? -1.0 : 0.0);
        final double side = d.index.isEven ? 1.0 : -1.0;
        d.vx = ux * sp * 0.85 * want + (-uy) * side * sp * 0.55;
        d.vy = uy * sp * 0.85 * want + ux * side * sp * 0.55;
        d.fireT -= dt;
        if (d.fireT <= 0 && dist < 620) {
          d.fireT = max(1.5, 2.8 - round * 0.06) + rng.nextDouble() * 0.8;
          bullets.add(StrikeBullet(d.x, d.y, ux * 210, uy * 210, 3.2, true));
        }
        break;
      case StrikeBehaviour.drift:
        d.turnT -= dt;
        if (d.turnT <= 0) {
          d.turnT = 1.0 + rng.nextDouble() * 1.4;
          final double a = rng.nextDouble() * pi * 2;
          d.vx = cos(a) * 46 + ux * 24;
          d.vy = sin(a) * 46 + uy * 24;
        }
        break;
      case StrikeBehaviour.flee:
        if (dist < 360) {
          d.vx = -ux * (sp + 18) + (-uy) * 20 * sin(d.wob);
          d.vy = -uy * (sp + 18) + ux * 20 * sin(d.wob);
        } else {
          d.vx = cos(d.wob) * 26;
          d.vy = sin(d.wob) * 26;
        }
        break;
    }
    d.x += d.vx * dt;
    d.y += d.vy * dt;
    // Keep enemies inside the arena and turn them back from the walls.
    if (d.x < 50 || d.x > worldSize - 50) {
      d.x = _cl(d.x, 50.0, worldSize - 50);
      d.vx = -d.vx;
    }
    if (d.y < 50 || d.y > worldSize - 50) {
      d.y = _cl(d.y, 50.0, worldSize - 50);
      d.vy = -d.vy;
    }
    // Touching you.
    if (skin.behaviour != StrikeBehaviour.flee && dist < droneRadius + 18 && inv <= 0) {
      _hurt();
      if (skin.behaviour == StrikeBehaviour.drift) {
        d.alive = false;
        bursts.add(StrikeBurst(d.x, d.y, skin.foe));
      }
    }
  }

  void _moveBullets(double dt) {
    for (final StrikeBullet b in bullets) {
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.ttl -= dt;
      if (b.x < 0 || b.y < 0 || b.x > worldSize || b.y > worldSize) b.ttl = 0;
      if (b.ttl <= 0) continue;
      if (b.foe) {
        final double dx = b.x - px;
        final double dy = b.y - py;
        if (dx * dx + dy * dy < 20 * 20 && inv <= 0 && phase == 0) {
          b.ttl = 0;
          _hurt();
        }
      } else if (phase == 0) {
        for (final StrikeDrone d in drones) {
          if (!d.alive) continue;
          final double dx = b.x - d.x;
          final double dy = b.y - d.y;
          if (dx * dx + dy * dy < (droneRadius + 6) * (droneRadius + 6)) {
            b.ttl = 0;
            d.alive = false;
            bursts.add(StrikeBurst(d.x, d.y, d.correct ? const Color(0xFF69F0AE) : const Color(0xFFFF5252)));
            _judge(d);
            break;
          }
        }
      }
    }
    bullets.removeWhere((StrikeBullet b) => b.ttl <= 0);
  }

  void _hurt() {
    hp--;
    inv = 1.1;
    flash = 0.35;
    cues.add('bad');
    if (hp <= 0 && phase == 0) {
      stats.record(q!, false);
      _resolve(false, 'DOWN. The answer was ${q!.answer}.');
    }
  }

  void _judge(StrikeDrone d) {
    final OdyQuestion qq = q!;
    if (d.correct) {
      stats.record(qq, true);
      kills++;
      score += 100 + min(stats.streak, 10) * 15 + (roundT * 4).round();
      if (stats.streak > 0 && stats.streak % 3 == 0 && hp < 5) hp++;
      cues.add('good');
      _resolve(true, 'CORRECT. ${qq.answer}');
    } else {
      stats.record(qq, false, chosen: qq.options[d.index]);
      hp--;
      flash = 0.35;
      cues.add('bad');
      _resolve(false, 'WRONG. The answer was ${qq.answer}.');
    }
  }

  void _resolve(bool ok, String text) {
    phase = 1;
    resolveT = ok ? 1.1 : 1.9;
    lastOk = ok;
    message = text;
    lock = -1;
  }

  // ---- input ---------------------------------------------------------------

  void _fireAt(double tx, double ty) {
    if (phase != 0 || fireCd > 0 || over) return;
    final double dx = tx - px;
    final double dy = ty - py;
    final double m = max(1.0, sqrt(dx * dx + dy * dy));
    aim = atan2(dy, dx);
    if (dx.abs() > 4) face = dx > 0 ? 1 : -1;
    fireCd = 0.2;
    bullets.add(StrikeBullet(px, py - 16, dx / m * bulletSpeed, dy / m * bulletSpeed, 0.95, false));
    cues.add('tap');
  }

  /// Aims at where the enemy will be when the shot arrives.
  void _fireAtDrone(StrikeDrone d) {
    final double dist = sqrt((d.x - px) * (d.x - px) + (d.y - py) * (d.y - py));
    final double t = dist / bulletSpeed;
    _fireAt(d.x + d.vx * t, d.y + d.vy * t);
  }

  StrikeDrone? _nearest() {
    StrikeDrone? best;
    double bd = double.infinity;
    for (final StrikeDrone d in drones) {
      if (!d.alive) continue;
      final double dd = (d.x - px) * (d.x - px) + (d.y - py) * (d.y - py);
      if (dd < bd) {
        bd = dd;
        best = d;
      }
    }
    return best;
  }

  /// Camera corner of the view, shared with the painter so taps land right.
  static double camX(double playerX, double viewW) => _cl(playerX - viewW / 2, 0.0, max(0.0, worldSize - viewW));
  static double camY(double playerY, double viewH) => _cl(playerY - viewH / 2, 0.0, max(0.0, worldSize - viewH));

  @override
  void onTap(Offset point, Size size) {
    if (over || phase != 0) return;
    final double wx = point.dx + camX(px, size.width);
    final double wy = point.dy + camY(py, size.height);
    StrikeDrone? hit;
    double bd = 70 * 70;
    for (final StrikeDrone d in drones) {
      if (!d.alive) continue;
      final double dd = (d.x - wx) * (d.x - wx) + (d.y - wy) * (d.y - wy);
      if (dd < bd) {
        bd = dd;
        hit = d;
      }
    }
    if (hit != null) {
      lock = hit.index;
      _fireAtDrone(hit);
    } else {
      _fireAt(wx, wy);
    }
  }

  /// A tap on an answer in the question card locks that enemy and fires.
  void shootOption(int i) {
    if (over || phase != 0) return;
    for (final StrikeDrone d in drones) {
      if (d.alive && d.index == i) {
        lock = i;
        _fireAtDrone(d);
        return;
      }
    }
  }

  @override
  void onAction(int id) {
    if (over) return;
    if (id == 1) {
      if (dashCd <= 0) {
        dashT = 0.28;
        dashCd = 2.6;
        inv = max(inv, 0.3);
        cues.add('tap');
      }
      return;
    }
    StrikeDrone? t;
    if (lock >= 0) {
      for (final StrikeDrone d in drones) {
        if (d.alive && d.index == lock) t = d;
      }
    }
    t ??= _nearest();
    if (t != null) {
      _fireAtDrone(t);
    } else {
      _fireAt(px + face * 100, py);
    }
  }
}
