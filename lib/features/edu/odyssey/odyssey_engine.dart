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
  double bx;
  double by;
  double x;
  double y;
  final double phase;
  final int index;
  final String label;
  /// Where this orb sits around the player; the orb drifts to keep that place.
  final double ang;
  final double rad;
  OdyOrb(this.bx, this.by, this.phase, this.index, this.label, {this.ang = 0, this.rad = 200})
      : x = bx,
        y = by;
}

class OdyCrystal {
  double x;
  double y;
  double age = 0;
  OdyCrystal(this.x, this.y);
}

/// A collectable star. Kind 0 restores a heart, kind 1 gives a short shield.
class OdyStar {
  double x;
  double y;
  final int kind;
  double age = 0;
  OdyStar(this.x, this.y, this.kind);
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

/// A compulsory question: the world freezes until the player answers it.
class OdyGate {
  final OdyQuestion q;
  int? chosen;
  /// Wrong options removed as a reward for finishing the rest mission.
  final Set<int> hidden = <int>{};
  OdyGate(this.q);
  bool get answered => chosen != null;
  bool get correct => chosen == q.answerIndex;
}

/// A small side goal that keeps free roaming interesting.
class OdyQuest {
  final String kind; // coins, stars, distance, dash
  final String title;
  final int target;
  final int reward;
  int progress = 0;
  OdyQuest(this.kind, this.title, this.target, this.reward);
}

class OdyActive {
  final OdyQuestion q;
  double timeLeft;
  final double total;
  final List<OdyOrb> orbs;
  /// True when this is a question the player got wrong earlier.
  final bool redo;
  OdyActive(this.q, this.total, this.orbs, {this.redo = false}) : timeLeft = total;
}

/// A longer goal that stays on the board until it is done, then gets harder.
class OdyMission {
  final String kind; // coins, correct, stars, streak
  final int tier;
  final int target;
  final int rewardScore;
  final int rewardXp;
  const OdyMission(this.kind, this.tier, this.target, this.rewardScore, this.rewardXp);

  String get title {
    switch (kind) {
      case 'coins':
        return 'Collect $target coins';
      case 'correct':
        return 'Answer $target questions correctly';
      case 'stars':
        return 'Find $target stars';
      default:
        return 'Reach a streak of $target';
    }
  }
}

/// The goal set during free roam. Finish it to open your question early with a hint.
class OdyRestMission {
  final String kind; // coins, stars, distance, dash
  final int target;
  int progress = 0;
  OdyRestMission(this.kind, this.target);
  bool get done => progress >= target;
  String get title {
    switch (kind) {
      case 'coins':
        return 'Collect $target coins';
      case 'stars':
        return target == 1 ? 'Find a star' : 'Find $target stars';
      case 'distance':
        return 'Travel $target steps';
      default:
        return 'Dash $target times';
    }
  }
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
  static const int maxHearts = 6;
  static const int coinsPerHeart = 20;
  static const double starRadius = 16;

  final QuestionPool pool;
  final List<String> subjects;
  final bool mixed;
  final int seed;
  final Random rng;
  /// Duels turn resting, gates and quests off so both players face the same rules.
  final bool allowRest;
  final Map<String, String> labels;

  double px = 0;
  double py = 0;
  double vx = 0;
  double vy = 0;
  double facingX = 1;
  double facingY = 0;
  double inputX = 0;
  double inputY = 0;

  int hearts = 5;
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
  final List<OdyStar> starList = <OdyStar>[];
  final List<OdyToast> toasts = <OdyToast>[];
  /// Sound cues for the screen to play: coin, star, shield, correct, wrong, hurt, nova.
  final List<String> cues = <String>[];
  double shield = 0;
  final List<OdyMistake> mistakes = <OdyMistake>[];
  final Map<String, int> askedBy = <String, int>{};
  final Map<String, int> correctBy = <String, int>{};
  OdyActive? active;
  OdyGate? gate;
  OdyQuest? quest;
  OdyRestMission? restMission;
  bool restMissionDone = false;
  final List<OdyMission> missions = <OdyMission>[];
  int missionsDone = 0;
  int starsFound = 0;
  int corrected = 0;
  final List<OdyQuestion> _redo = <OdyQuestion>[];
  int _sinceMiss = 0;
  int heroXp = 0;
  int _heroLevelSeen = 1;
  /// A big message shown for a moment: level ups, finished missions, corrections.
  String banner = '';
  double bannerLife = 0;
  int questsDone = 0;
  int gatesCleared = 0;
  double freeLeft = 0;
  double _questTimer = 20;
  String regionNow = '';
  String _pendingRegion = '';
  double _pendingT = 0;

  /// Half the screen height in world units, so answer orbs always fit on screen.
  double viewHalfH = 300;

  double _askTimer = 4.0;
  double _enemyTimer = 14;
  double _starTimer = 18;
  double _crystalTimer = 1.2;

  OdysseyEngine({required this.pool, required this.subjects, required this.mixed, required this.seed, required this.rng, this.allowRest = true, this.labels = const <String, String>{}});

  int get level => 1 + correct ~/ 3;

  // ---- hero: level, rank, perks -------------------------------------------------
  static int xpToNext(int lv) => 60 + 40 * (lv - 1);

  /// Level reached with [xp] experience.
  static int heroLevelFor(int xp) {
    int lv = 1;
    int left = xp;
    while (left >= xpToNext(lv) && lv < 60) {
      left -= xpToNext(lv);
      lv++;
    }
    return lv;
  }

  int get heroLevel => heroLevelFor(heroXp);

  /// Experience inside the current level and what the level needs.
  int get heroXpInLevel {
    int lv = 1;
    int left = heroXp;
    while (left >= xpToNext(lv) && lv < 60) {
      left -= xpToNext(lv);
      lv++;
    }
    return left;
  }

  int get heroXpNeed => xpToNext(heroLevel);

  static const List<String> ranks = <String>['Wanderer', 'Scout', 'Pathfinder', 'Ranger', 'Vanguard', 'Warden', 'Champion', 'Legend'];
  String get heroRank => ranks[min(ranks.length - 1, (heroLevel - 1) ~/ 3)];
  /// 0 to 7, used to dress the hero.
  int get heroTier => min(ranks.length - 1, (heroLevel - 1) ~/ 3);

  /// Perks only count outside duels so both players stay equal.
  double get _perk => allowRest ? min(heroLevel, 20).toDouble() : 0;
  double get speedNow => moveSpeed * (1 + 0.012 * _perk);
  double get dashCooldownNow => dashCooldown * (1 - 0.02 * _perk);
  double get magnetNow => 4 + 0.8 * _perk;

  void _gainXp(int n) {
    if (!allowRest || n <= 0) return;
    heroXp += n;
    final int lv = heroLevel;
    if (lv > _heroLevelSeen) {
      _heroLevelSeen = lv;
      _say('LEVEL $lv  ${heroRank.toUpperCase()}');
      _toast('Faster, quicker dash, wider coin pull', true);
      cues.add('hero');
    }
  }

  /// Restores the saved hero when a run starts.
  void loadHero(int xp) {
    if (!allowRest || xp <= 0) return;
    heroXp = xp;
    _heroLevelSeen = heroLevel;
  }

  void _say(String text) {
    banner = text;
    bannerLife = 2.6;
  }

  // ---- missions -----------------------------------------------------------------
  static const List<int> _coinTiers = <int>[100, 250, 400, 700, 1000, 1500];
  static const List<int> _correctTiers = <int>[5, 12, 25, 45, 80, 130];
  static const List<int> _starTiers = <int>[2, 5, 10, 18, 30, 50];
  static const List<int> _streakTiers = <int>[3, 5, 8, 12, 18, 25];

  OdyMission _missionFor(String kind, int tier) {
    final int t = min(tier, 5);
    switch (kind) {
      case 'coins':
        return OdyMission(kind, tier, _coinTiers[t], 150 + 100 * t, 20 + 15 * t);
      case 'correct':
        return OdyMission(kind, tier, _correctTiers[t], 200 + 120 * t, 25 + 15 * t);
      case 'stars':
        return OdyMission(kind, tier, _starTiers[t], 150 + 100 * t, 20 + 15 * t);
      default:
        return OdyMission(kind, tier, _streakTiers[t], 200 + 120 * t, 25 + 15 * t);
    }
  }

  int missionProgress(OdyMission m) {
    switch (m.kind) {
      case 'coins':
        return crystals;
      case 'correct':
        return correct;
      case 'stars':
        return starsFound;
      default:
        return streak > bestStreak ? streak : bestStreak;
    }
  }

  void _checkMissions() {
    if (!allowRest) return;
    if (missions.isEmpty) {
      for (final String k in <String>['coins', 'correct', 'stars', 'streak']) {
        missions.add(_missionFor(k, 0));
      }
    }
    for (int i = 0; i < missions.length; i++) {
      final OdyMission m = missions[i];
      if (missionProgress(m) >= m.target) {
        score += m.rewardScore;
        missionsDone++;
        _say('MISSION DONE  +${m.rewardScore}');
        _toast(m.title, true);
        cues.add('star');
        if (hearts < maxHearts) hearts++;
        missions[i] = _missionFor(m.kind, m.tier + 1);
        _gainXp(m.rewardXp);
      }
    }
  }

  // ---- rest mission -------------------------------------------------------------
  OdyRestMission _newRestMission(double seconds) {
    final double mins = seconds / 60.0;
    final int pick = rng.nextInt(4);
    if (pick == 0) return OdyRestMission('coins', (mins * 40).round());
    if (pick == 1) return OdyRestMission('stars', max(1, mins.round()));
    if (pick == 2) return OdyRestMission('distance', (mins * 1400).round());
    return OdyRestMission('dash', (mins * 6).round());
  }

  void _restStep(String kind, int amount) {
    final OdyRestMission? m = restMission;
    if (m == null || m.kind != kind || freeLeft <= 0 || restMissionDone) return;
    m.progress += amount;
    if (m.done) {
      restMissionDone = true;
      score += 200;
      _gainXp(30);
      _say('REST MISSION DONE');
      _toast('Tap READY to answer now and get a hint', true);
      cues.add('star');
    }
  }

  /// Rest mission finished: open the compulsory question now, with two wrong answers removed.
  bool readyNow() {
    if (over || !resting || !restMissionDone || active != null || gate != null) return false;
    freeLeft = 0;
    _openGate(hint: true);
    return true;
  }
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
    dashCool = dashCooldownNow;
    _questStep('dash', 1);
    _restStep('dash', 1);
    return true;
  }

  bool get dashing => dashLeft > 0;
  double get dashReady => dashCool <= 0 ? 1 : 1 - dashCool / dashCooldownNow;

  bool get resting => freeLeft > 0;

  void say(String text, {bool good = true}) => _toast(text, good);

  /// Take a break from questions for [seconds]. Ends with a compulsory question.
  bool rest(double seconds) {
    if (!allowRest || over || active != null || gate != null || freeLeft > 0) return false;
    freeLeft = seconds;
    restMissionDone = false;
    restMission = _newRestMission(seconds);
    _toast('Free roam. Mission: ${restMission!.title}', true);
    return true;
  }

  /// Ask for a challenge right now instead of waiting.
  bool askNow() {
    if (over || active != null || gate != null) return false;
    freeLeft = 0;
    restMission = null;
    restMissionDone = false;
    _ask();
    return true;
  }

  void _openGate({bool hint = false}) {
    final OdyQuestion q = pool.pick(subjectAt(px, py));
    gate = OdyGate(q);
    final bool earned = hint || restMissionDone;
    if (earned) {
      final List<int> wrong = <int>[];
      for (int i = 0; i < q.options.length; i++) {
        if (i != q.answerIndex) wrong.add(i);
      }
      wrong.shuffle(rng);
      final int remove = q.options.length >= 4 ? 2 : (q.options.length == 3 ? 1 : 0);
      for (int i = 0; i < remove && i < wrong.length; i++) {
        gate!.hidden.add(wrong[i]);
      }
    } else if (restMission != null) {
      _toast('Mission missed. No hint this time', false);
    }
    restMission = null;
    restMissionDone = false;
    vx = 0;
    vy = 0;
    inputX = 0;
    inputY = 0;
    cues.add('gate');
  }

  void answerGate(int index) {
    final OdyGate? g = gate;
    if (g == null || g.answered) return;
    g.chosen = index;
    final bool ok = g.correct;
    _record(g.q, ok);
    gatesCleared++;
    if (ok) {
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      score += 150;
      _gainXp(15);
      cues.add('correct');
    } else {
      streak = 0;
      cues.add('wrong');
      mistakes.add(OdyMistake(g.q.text, g.q.options[index], g.q.answer, g.q.subject));
      _redo.add(g.q);
      _sinceMiss = 0;
      // A wrong gate answer costs a heart but can never end the run.
      if (hearts > 1) hearts--;
    }
  }

  void closeGate() {
    final OdyGate? g = gate;
    if (g == null || !g.answered) return;
    gate = null;
    invuln = 2.5;
    _askTimer = 10;
    _toast(g.correct ? 'Back to exploring. +150' : 'Answer: ${g.q.answer}', g.correct);
  }

  void _questStep(String kind, int amount) {
    final OdyQuest? qu = quest;
    if (qu == null || qu.kind != kind) return;
    qu.progress += amount;
    if (qu.progress >= qu.target) {
      score += qu.reward;
      questsDone++;
      _toast('Quest done: +${qu.reward}', true);
      _gainXp(12);
      cues.add('star');
      if (questsDone % 2 == 0 && hearts < maxHearts) {
        hearts++;
        _toast('Quest reward: +1 heart', true);
      }
      quest = null;
      _questTimer = 6;
    }
  }

  void _newQuest() {
    final int pick = rng.nextInt(4);
    if (pick == 0) {
      final int n = 12 + rng.nextInt(3) * 4;
      quest = OdyQuest('coins', 'Collect $n coins', n, 150);
    } else if (pick == 1) {
      quest = OdyQuest('stars', 'Find a star', 1, 120);
    } else if (pick == 2) {
      final int n = 2200 + rng.nextInt(3) * 800;
      quest = OdyQuest('distance', 'Travel $n steps', n, 180);
    } else {
      quest = OdyQuest('dash', 'Dash 5 times', 5, 100);
    }
  }

  void _toast(String text, bool good) {
    toasts.add(OdyToast(text, good, 2.2));
    if (toasts.length > 4) toasts.removeAt(0);
  }

  void step(double dtIn) {
    if (over) return;
    final double dt = dtIn > 0.05 ? 0.05 : dtIn;
    time += dt;
    novaFlash = false;
    if (bannerLife > 0) {
      bannerLife -= dt;
      if (bannerLife <= 0) banner = '';
    }
    if (gate != null) {
      for (final OdyToast t in toasts) {
        t.life -= dt;
      }
      toasts.removeWhere((OdyToast t) => t.life <= 0);
      return;
    }

    // --- player ---
    if (invuln > 0) invuln -= dt;
    if (shield > 0) shield -= dt;
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
      tvx = inputX * speedNow;
      tvy = inputY * speedNow;
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
    _questStep('distance', (sp * dt).round());
    _restStep('distance', (sp * dt).round());
    // region change toast, once the player has stayed in the new region a moment
    final String here = subjectAt(px, py);
    if (regionNow.isEmpty) {
      regionNow = here;
    } else if (here != regionNow) {
      if (here == _pendingRegion) {
        _pendingT += dt;
        if (_pendingT > 1.2) {
          regionNow = here;
          _pendingT = 0;
          if (mixed) _toast('Entering ${labels[here] ?? here}', true);
        }
      } else {
        _pendingRegion = here;
        _pendingT = 0;
      }
    }

    // --- toasts ---
    for (final OdyToast t in toasts) {
      t.life -= dt;
    }
    toasts.removeWhere((OdyToast t) => t.life <= 0);

    // --- questions ---
    final OdyActive? a = active;
    if (a == null) {
      if (freeLeft > 0) {
        freeLeft -= dt;
        if (freeLeft <= 0) {
          freeLeft = 0;
          _openGate();
          return;
        }
      } else {
        _askTimer -= dt;
        if (_askTimer <= 0) _ask();
      }
    } else {
      a.timeLeft -= dt;
      // Answers stay with the player: an orb that is left behind drifts back to its place.
      for (final OdyOrb o in a.orbs) {
        final double tx = px + cos(o.ang) * o.rad;
        final double ty = py + sin(o.ang) * o.rad;
        final double ddx = tx - o.bx;
        final double ddy = ty - o.by;
        final double dd = sqrt(ddx * ddx + ddy * ddy);
        if (dd > 60) {
          final double mv = min(dd - 40, 165 * dt);
          o.bx += ddx / dd * mv;
          o.by += ddy / dd * mv;
        }
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
    final int cap = min(7, 1 + (level + 1) ~/ 2);
    if (_enemyTimer <= 0 && enemies.length < cap) {
      _spawnEnemy(560 + rng.nextDouble() * 140);
      _enemyTimer = max(3.0, 7.0 - level * 0.4);
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
    if (invuln <= 0 && shield <= 0 && dashLeft <= 0) {
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
    if (_crystalTimer <= 0 && crystalList.length < 12) {
      // a short arc of coins in front of the player's direction of travel
      final double base = atan2(facingY, facingX) + (rng.nextDouble() - 0.5) * 1.6;
      final double r = 170 + rng.nextDouble() * 200;
      final double cx = px + cos(base) * r;
      final double cy = py + sin(base) * r;
      final double along = base + pi / 2;
      for (int i = 0; i < 5; i++) {
        final double o = (i - 2) * 30.0;
        crystalList.add(OdyCrystal(cx + cos(along) * o, cy + sin(along) * o));
      }
      _crystalTimer = 4.0;
    } else if (_crystalTimer <= 0) {
      _crystalTimer = 1.5;
    }
    crystalList.removeWhere((OdyCrystal c) {
      c.age += dt;
      final double dx = c.x - px;
      final double dy = c.y - py;
      if (dx * dx + dy * dy <= (crystalRadius + playerRadius + magnetNow) * (crystalRadius + playerRadius + magnetNow)) {
        crystals++;
        score += 10;
        cues.add('coin');
        _questStep('coins', 1);
        _restStep('coins', 1);
        if (crystals % 4 == 0) _gainXp(1);
        if (crystals % coinsPerHeart == 0) {
          if (hearts < maxHearts) {
            hearts++;
            _toast('$coinsPerHeart coins: +1 heart', true);
          } else {
            score += 100;
            _toast('$coinsPerHeart coins: +100', true);
          }
          cues.add('star');
        }
        return true;
      }
      return dx * dx + dy * dy > 1000 * 1000 || c.age > 45;
    });

    // --- quests ---
    if (allowRest) {
      if (quest == null) {
        _questTimer -= dt;
        if (_questTimer <= 0) _newQuest();
      }
    }

    // --- stars: life and shield ---
    _starTimer -= dt;
    if (_starTimer <= 0) {
      if (starList.length < 2) {
        final double ang = rng.nextDouble() * 2 * pi;
        final double r = 220 + rng.nextDouble() * 160;
        // life stars are more common when the player is low
        final int kind = (hearts <= 2 || rng.nextDouble() < 0.6) ? 0 : 1;
        starList.add(OdyStar(px + cos(ang) * r, py + sin(ang) * r, kind));
      }
      _starTimer = hearts <= 2 ? 9.0 : 22.0;
    }
    _checkMissions();
    starList.removeWhere((OdyStar st) {
      st.age += dt;
      final double dx = st.x - px;
      final double dy = st.y - py;
      final double rr = starRadius + playerRadius + 6;
      if (dx * dx + dy * dy <= rr * rr) {
        if (st.kind == 0) {
          if (hearts < maxHearts) {
            hearts++;
            _toast('Life star: +1 heart', true);
          } else {
            score += 150;
            _toast('Life star: +150', true);
          }
          cues.add('star');
          starsFound++;
          _gainXp(8);
          _restStep('stars', 1);
          _questStep('stars', 1);
        } else {
          shield = 7;
          starsFound++;
          _gainXp(8);
          _restStep('stars', 1);
          _questStep('stars', 1);
          _toast('Shield for 7 seconds', true);
          cues.add('shield');
        }
        return true;
      }
      return st.age > 60 || dx * dx + dy * dy > 1200 * 1200;
    });
  }

  void _spawnEnemy(double dist) {
    final double ang = rng.nextDouble() * 2 * pi;
    final double speed = min(140.0, 62.0 + level * 8 + rng.nextDouble() * 14);
    enemies.add(OdyEnemy(px + cos(ang) * dist, py + sin(ang) * dist, speed, rng.nextDouble() * 6.28));
  }

  void _hurt() {
    cues.add('hurt');
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
    // Now and then an earlier mistake comes back so it can be put right.
    OdyQuestion? back;
    if (allowRest && _redo.isNotEmpty && _sinceMiss >= 2 && rng.nextDouble() < 0.4) {
      back = _redo.removeAt(0);
    }
    final bool isRedo = back != null;
    final OdyQuestion q = back ?? pool.pick(subject);
    final double total = max(30.0, 48.0 - level * 1.2);
    final int n = q.options.length;
    final double base = rng.nextDouble() * 2 * pi;
    final List<OdyOrb> orbs = <OdyOrb>[];
    for (int i = 0; i < n; i++) {
      final double ang = base + i * 2 * pi / n;
      final double r = min(190 + rng.nextDouble() * 50, max(120.0, viewHalfH * 0.78));
      orbs.add(OdyOrb(px + cos(ang) * r, py + sin(ang) * r, rng.nextDouble() * 6.28, i, q.options[i], ang: ang, rad: r));
    }
    active = OdyActive(q, total, orbs, redo: isRedo);
    if (isRedo) _toast('Correction: you missed this one earlier', true);
  }

  void _after() {
    active = null;
    _askTimer = max(3.0, 6.0 - level * 0.25);
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
    _sinceMiss++;
    if (ok) {
      streak++;
      if (streak > bestStreak) bestStreak = streak;
      _gainXp(a.redo ? 28 : 12);
      if (a.redo) {
        corrected++;
        score += 100;
        _say('CORRECTION MADE  +100');
      }
      final int streakCap = min(streak, 8);
      final int timeBonus = (a.timeLeft * 3).floor();
      final int gain = 100 + 25 * streakCap + timeBonus;
      score += gain;
      _toast('+$gain', true);
      cues.add('correct');
      final OdyOrb orb = a.orbs[index];
      if (streak % 3 == 0 && starList.length < 3) {
        starList.add(OdyStar(orb.x, orb.y, 0));
      }
      for (int i = 0; i < 5; i++) {
        final double ang = rng.nextDouble() * 2 * pi;
        crystalList.add(OdyCrystal(orb.x + cos(ang) * 40, orb.y + sin(ang) * 40));
      }
      if (streak % 5 == 0) {
        enemies.clear();
        novaFlash = true;
        cues.add('nova');
        if (hearts < maxHearts) hearts++;
        _toast('NOVA streak $streak', true);
      }
    } else {
      streak = 0;
      cues.add('wrong');
      mistakes.add(OdyMistake(q.text, q.options[index], q.answer, q.subject));
      if (_redo.length < 6) _redo.add(q);
      _sinceMiss = 0;
      _toast('Answer: ${q.answer}', false);
      hearts--;
      invuln = 1.0;
      _spawnEnemy(420);
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
    if (_redo.length < 6) _redo.add(q);
    _sinceMiss = 0;
    _toast('Time up. Answer: ${q.answer}', false);
    cues.add('wrong');
    _spawnEnemy(420);
    _after();
  }

  /// Total XP for the run. Subject results are reported separately.
  int get xp {
    final int walk = min(20, distance ~/ 1500);
    final int streakBonus = bestStreak >= 5 ? 15 : 0;
    final int questBonus = (questsDone > 5 ? 5 : questsDone) * 4;
    return correct * 8 + streakBonus + walk + questBonus + min(40, missionsDone * 5) + min(30, corrected * 5);
  }
}
