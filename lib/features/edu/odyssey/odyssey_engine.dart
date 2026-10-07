import 'dart:math';
import 'odyssey_questions.dart';

class OdyEnemy {
  double x;
  double y;
  double speed;
  double phase;
  OdyEnemy(this.x, this.y, this.speed, this.phase);
}

class OdyOrb {
  final double bx;
  final double by;
  double x;
  double y;
  final double phase;
  final int index;
  final String label;
  OdyOrb(this.bx, this.by, this.phase, this.index, this.label)
      : x = bx,
        y = by;
}

class OdyCrystal {
  double x;
  double y;
  double age = 0;
  OdyCrystal(this.x, this.y);
}

class OdyToast {
  final String text;
  final bool good;
  double life;
  OdyToast(this.text, this.good, this.life);
}

class OdyMistake {
  final String question;
  final String chosen;
  final String correct;
  final String subject;
  const OdyMistake(this.question, this.chosen, this.correct, this.subject);
}

class OdyActive {
  final OdyQuestion q;
  double timeLeft;
  final double total;
  final List<OdyOrb> orbs;
  OdyActive(this.q, this.total, this.orbs) : timeLeft = total;
}

/// The rules of Odyssey with no drawing code, so they can be tested alone.
///
/// The world is endless and split into wavy regions, one per subject. Every
/// so often a question appears for the subject of the region the player is
/// standing in, and its answers float around the player as glowing orbs.
/// Run into the right orb before time runs out, while dodging the Glitches
/// that chase you. Wrong answers and Glitch hits cost hearts.
class OdysseyEngine {
  static const double regionSize = 1500;
  static const double playerRadius = 14;
  static const double enemyRadius = 13;
  static const double orbRadius = 26;
  static const double crystalRadius = 11;
  static const double moveSpeed = 190;
  static const double dashSpeed = 520;
  static const double dashTime = 0.18;
  static const double dashCooldown = 2.2;
  static const int maxHearts = 5;

  final QuestionPool pool;
  final List<String> subjects;
  final bool mixed;
  final int seed;
  final Random rng;

  double px = 0;
  double py = 0;
  double vx = 0;
  double vy = 0;
  double facingX = 1;
  double facingY = 0;
  double inputX = 0;
  double inputY = 0;

  int hearts = 3;
  double invuln = 0;
  double dashLeft = 0;
  double dashCool = 0;
  double dashDirX = 1;
  double dashDirY = 0;

  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int correct = 0;
  int asked = 0;
  int crystals = 0;
  double distance = 0;
  double time = 0;
  bool over = false;
  bool novaFlash = false;

  final List<OdyEnemy> enemies = <OdyEnemy>[];
  final List<OdyCrystal> crystalList = <OdyCrystal>[];
  final List<OdyToast> toasts = <OdyToast>[];
  final List<OdyMistake> mistakes = <OdyMistake>[];
  final Map<String, int> askedBy = <String, int>{};
  final Map<String, int> correctBy = <String, int>{};
  OdyActive? active;

  double _askTimer = 3.5;
  double _enemyTimer = 6;
  double _crystalTimer = 1.2;

  OdysseyEngine({required this.pool, required this.subjects, required this.mixed, required this.seed, required this.rng});

  int get level => 1 + correct ~/ 3;
  int get finalScore => score + distance ~/ 40;

  static int _hash(int a, int b, int c) {
    int h = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791);
    h = (h ^ (h >> 13)) & 0x7fffffff;
    h = (h * 1274126177) & 0x7fffffff;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  /// Which subject owns the ground at this point. Borders wobble so regions
  /// feel like landscape rather than a chessboard.
  String subjectAt(double x, double y) {
    if (!mixed || subjects.length == 1) return subjects.first;
    final double wx = x + 260 * sin(y / 380);
    final double wy = y + 260 * sin(x / 410);
    final int cx = (wx / regionSize).floor();
    final int cy = (wy / regionSize).floor();
    return subjects[_hash(cx, cy, seed) % subjects.length];
  }

  void setInput(double x, double y) {
    final double m = sqrt(x * x + y * y);
    if (m > 1) {
      inputX = x / m;
      inputY = y / m;
    } else {
      inputX = x;
      inputY = y;
    }
  }

  bool tryDash() {
    if (over || dashCool > 0 || dashLeft > 0) return false;
    double dx = inputX;
    double dy = inputY;
    if (dx * dx + dy * dy < 0.01) {
      dx = facingX;
      dy = facingY;
    }
    final double m = sqrt(dx * dx + dy * dy);
    dashDirX = m == 0 ? 1 : dx / m;
    dashDirY = m == 0 ? 0 : dy / m;
    dashLeft = dashTime;
    dashCool = dashCooldown;
    return true;
  }

  bool get dashing => dashLeft > 0;
  double get dashReady => dashCool <= 0 ? 1 : 1 - dashCool / dashCooldown;

  void _toast(String text, bool good) {
    toasts.add(OdyToast(text, good, 2.2));
    if (toasts.length > 4) toasts.removeAt(0);
  }

  void step(double dtIn) {
    if (over) return;
    final double dt = dtIn > 0.05 ? 0.05 : dtIn;
    time += dt;
    novaFlash = false;

    // --- player ---
    if (invuln > 0) invuln -= dt;
    if (dashCool > 0) dashCool -= dt;
    double tvx;
    double tvy;
    if (dashLeft > 0) {
      dashLeft -= dt;
      tvx = dashDirX * dashSpeed;
      tvy = dashDirY * dashSpeed;
      vx = tvx;
      vy = tvy;
    } else {
      tvx = inputX * moveSpeed;
      tvy = inputY * moveSpeed;
      final double k = min(1.0, dt * 11);
      vx += (tvx - vx) * k;
      vy += (tvy - vy) * k;
    }
    final double sp = sqrt(vx * vx + vy * vy);
    if (sp > 8) {
      facingX = vx / sp;
      facingY = vy / sp;
    }
    px += vx * dt;
    py += vy * dt;
    distance += sp * dt;

    // --- toasts ---
    for (final OdyToast t in toasts) {
      t.life -= dt;
    }
    toasts.removeWhere((OdyToast t) => t.life <= 0);

    // --- questions ---
    final OdyActive? a = active;
    if (a == null) {
      _askTimer -= dt;
      if (_askTimer <= 0) _ask();
    } else {
      a.timeLeft -= dt;
      for (final OdyOrb o in a.orbs) {
        o.x = o.bx + cos(time * 1.3 + o.phase) * 16;
        o.y = o.by + sin(time * 1.7 + o.phase) * 16;
      }
      OdyOrb? hit;
      for (final OdyOrb o in a.orbs) {
        final double dx = o.x - px;
        final double dy = o.y - py;
        if (dx * dx + dy * dy <= (orbRadius + playerRadius) * (orbRadius + playerRadius)) {
          hit = o;
          break;
        }
      }
      if (hit != null) {
        _resolve(hit.index);
      } else if (a.timeLeft <= 0) {
        _timeout();
      }
    }
    if (over) return;

    // --- enemies ---
    _enemyTimer -= dt;
    final int cap = min(10, 2 + level);
    if (_enemyTimer <= 0 && enemies.length < cap) {
      _spawnEnemy(520 + rng.nextDouble() * 140);
      _enemyTimer = max(1.2, 4.2 - level * 0.3);
    } else if (_enemyTimer <= 0) {
      _enemyTimer = 1.0;
    }
    for (final OdyEnemy e in enemies) {
      final double dx = px - e.x;
      final double dy = py - e.y;
      final double d = sqrt(dx * dx + dy * dy);
      if (d > 1) {
        final double wob = sin(time * 3 + e.phase) * 0.35;
        final double ang = atan2(dy, dx) + wob;
        e.x += cos(ang) * e.speed * dt;
        e.y += sin(ang) * e.speed * dt;
      }
    }
    // Glitches that fall far behind rejoin the hunt from the front.
    for (final OdyEnemy e in enemies) {
      final double dx = e.x - px;
      final double dy = e.y - py;
      if (dx * dx + dy * dy > 1100 * 1100) {
        final double ang = rng.nextDouble() * 2 * pi;
        e.x = px + cos(ang) * 600;
        e.y = py + sin(ang) * 600;
      }
    }
    if (invuln <= 0 && dashLeft <= 0) {
      for (final OdyEnemy e in enemies) {
        final double dx = e.x - px;
        final double dy = e.y - py;
        final double r = playerRadius + enemyRadius;
        if (dx * dx + dy * dy <= r * r) {
          _hurt();
          // knock the Glitch back so one touch is one hit
          final double d = max(1.0, sqrt(dx * dx + dy * dy));
          e.x += dx / d * 120;
          e.y += dy / d * 120;
          break;
        }
      }
    }
    if (over) return;

    // --- crystals ---
    _crystalTimer -= dt;
    if (_crystalTimer <= 0 && crystalList.length < 6) {
      final double ang = rng.nextDouble() * 2 * pi;
      final double r = 140 + rng.nextDouble() * 280;
      crystalList.add(OdyCrystal(px + cos(ang) * r, py + sin(ang) * r));
      _crystalTimer = 2.4;
    } else if (_crystalTimer <= 0) {
      _crystalTimer = 1.0;
    }
    crystalList.removeWhere((OdyCrystal c) {
      c.age += dt;
      final double dx = c.x - px;
      final double dy = c.y - py;
      if (dx * dx + dy * dy <= (crystalRadius + playerRadius + 4) * (crystalRadius + playerRadius + 4)) {
        crystals++;
        score += 10;
        if (crystals % 10 == 0 && hearts < maxHearts) {
          hearts++;
          _toast('+1 heart', true);
        }
        return true;
      }
      return dx * dx + dy * dy > 900 * 900 || c.age > 40;
    });
  }

  void _spawnEnemy(double dist) {
    final double ang = rng.nextDouble() * 2 * pi;
    final double speed = min(140.0, 62.0 + level * 8 + rng.nextDouble() * 14);
    enemies.add(OdyEnemy(px + cos(ang) * dist, py + sin(ang) * dist, speed, rng.nextDouble() * 6.28));
  }

  void _hurt() {
    hearts--;
    invuln = 1.6;
    streak = 0;
    _toast('Glitch hit', false);
    if (hearts <= 0) {
      hearts = 0;
      over = true;
      active = null;
    }
  }

  void _ask() {
    final String subject = subjectAt(px, py);
    final OdyQuestion q = pool.pick(subject);
    final double total = max(11.0, 22.0 - level * 0.9);
    final int n = q.options.length;
    final double base = rng.nextDouble() * 2 * pi;
    final List<OdyOrb> orbs = <OdyOrb>[];
    for (int i = 0; i < n; i++) {
      final double ang = base + i * 2 * pi / n;
      final double r = 250 + rng.nextDouble() * 70;
      orbs.add(OdyOrb(px + cos(ang) * r, py + sin(ang) * r, rng.nextDouble() * 6.28, i, q.options[i]));
    }
    active = OdyActive(q, total, orbs);
  }

  void _after() {
    active = null;
    _askTimer = max(2.0, 4.5 - level * 0.25);
  }

  void _record(OdyQuestion q, bool ok) {
    asked++;
    askedBy[q.subject] = (askedBy[q.subject] ?? 0) + 1;
    if (ok) {
      correct++;
      correctBy[q.subject] = (correctBy[q.subject] ?? 0) + 1;
    }
  }

  void _resolve(int index) {
    final OdyActive a = active!;
    final OdyQuestion q = a.q;
    final bool ok = index == q.answerIndex;
    _record(q, ok);
    if (ok) {
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      final int streakCap = min(streak, 8);
      final int timeBonus = (a.timeLeft * 3).floor();
      final int gain = 100 + 25 * streakCap + timeBonus;
      score += gain;
      _toast('+$gain', true);
      final OdyOrb orb = a.orbs[index];
      for (int i = 0; i < 5; i++) {
        final double ang = rng.nextDouble() * 2 * pi;
        crystalList.add(OdyCrystal(orb.x + cos(ang) * 40, orb.y + sin(ang) * 40));
      }
      if (streak % 5 == 0) {
        enemies.clear();
        novaFlash = true;
        if (hearts < maxHearts) hearts++;
        _toast('NOVA streak $streak', true);
      }
    } else {
      streak = 0;
      mistakes.add(OdyMistake(q.text, q.options[index], q.answer, q.subject));
      _toast('Answer: ${q.answer}', false);
      hearts--;
      invuln = 1.0;
      _spawnEnemy(380);
      _spawnEnemy(380);
      if (hearts <= 0) {
        hearts = 0;
        over = true;
      }
    }
    _after();
  }

  void _timeout() {
    final OdyActive a = active!;
    final OdyQuestion q = a.q;
    _record(q, false);
    streak = 0;
    mistakes.add(OdyMistake(q.text, 'No answer', q.answer, q.subject));
    _toast('Time up. Answer: ${q.answer}', false);
    _spawnEnemy(380);
    _spawnEnemy(380);
    _after();
  }

  /// Total XP for the run. Subject results are reported separately.
  int get xp {
    final int walk = min(20, distance ~/ 1500);
    final int streakBonus = bestStreak >= 5 ? 15 : 0;
    return correct * 8 + streakBonus + walk;
  }
}
