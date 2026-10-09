import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import '../edu/realms/realm_kit.dart';
import 'darkom_ai.dart';
import 'darkom_armory.dart';
import 'darkom_combat.dart';
import 'darkom_entities.dart';
import 'darkom_ghost.dart';
import 'darkom_service.dart';
import 'darkom_story.dart';
import 'darkom_world.dart';

/// What the screen loads before a run starts. The logic updates it when a
/// run is reported so "play again" starts the right chapter.
class DarkomBoot {
  DarkomProgress progress;
  DarkomArmory armory;
  DarkomGhost? ghost;
  DarkomBoot(this.progress, this.armory, this.ghost);
}

const int darkomMaxEnemies = 24;
const int darkomMaxProjectiles = 60;
const double darkomHeroRadius = 13;
const double darkomZoneRadius = 150;

/// The rules of Darkom City: movement, six weapons, enemies, contracts and
/// the Echo duel. No drawing happens here.
class DarkomLogic extends RealmLogic {
  final DarkomBoot boot;
  final int chapterNo;
  final bool roam;
  final DarkomChapterDef ch;
  final DarkomTheme theme;
  final DarkomWorld world;
  final DarkomArmory armory;
  final Random rnd;
  final String heroName;

  DarkomLogic(RealmContent content, this.boot)
      : chapterNo = _chapterOf(boot),
        roam = _chapterOf(boot) >= 6,
        ch = darkomChapter(_chapterOf(boot)),
        theme = darkomTheme(darkomChapter(_chapterOf(boot)).district),
        world = DarkomWorld.generate(darkomChapter(_chapterOf(boot)).district, content.seed + _chapterOf(boot) * 7919),
        armory = boot.armory,
        rnd = content.rng,
        heroName = _nameNow(),
        super(content) {
    _init();
  }

  static int _chapterOf(DarkomBoot b) {
    final int c = b.progress.chapter;
    return c < 1 ? 1 : (c > 6 ? 6 : c);
  }

  static String _nameNow() {
    try {
      final dynamic meta = SupabaseService.client.auth.currentUser?.userMetadata;
      final dynamic n = meta == null ? null : (meta['username'] ?? meta['full_name'] ?? meta['name']);
      final String s = n == null ? '' : n.toString().trim();
      if (s.isNotEmpty) return s.length > 14 ? s.substring(0, 14) : s;
    } catch (_) {}
    return 'You';
  }

  // ---- hero ---------------------------------------------------------------
  double hx = 0;
  double hy = 0;
  double hFace = 0;
  double faceSign = 1;
  double hp = 100;
  final double maxHp = 100;
  int lives = 3;
  double invuln = 0;
  double hitFlash = 0;
  int weaponIdx = 0;
  double atkCd = 0;
  double atkCdMax = 0.4;
  double specCd = 0;
  double specCdMax = 7;
  double dashCd = 0;
  double dashT = 0;
  double dashVx = 0;
  double dashVy = 0;
  double mana = 100;
  final double maxMana = 100;
  double manaPause = 0;
  double guard = 0;
  double guardAge = 0;
  double swingT = -1;
  double swingDur = 0.3;
  double swingDir = 1;
  double swingAng = 0;
  String swingKind = 'sword';
  double slamT = 0;
  double slamAng = 0;
  int flurry = 0;
  double flurryT = 0;
  double chargeT = 0;
  double chargeVx = 0;
  double chargeVy = 0;
  final Set<int> chargeHit = <int>{};
  double spinT = -1;
  double kvx = 0;
  double kvy = 0;
  double aimLock = 0;
  double hphase = 0;
  bool hmoving = false;
  bool heroDead = false;
  double deathT = 0;
  double swapFlash = 0;
  double noManaT = 0;
  final Map<String, int> weaponUse = <String, int>{};
  String get weapon => darkomWeaponKinds[weaponIdx % darkomWeaponKinds.length];

  // ---- world objects ------------------------------------------------------
  final List<DEnemy> enemies = <DEnemy>[];
  final List<DProj> projs = <DProj>[];
  final List<DAxe> axes = <DAxe>[];
  final List<DPart> parts = <DPart>[];
  final List<DText> texts = <DText>[];
  final List<DFx> fxs = <DFx>[];
  final List<DPick> picks = <DPick>[];
  final List<DLater> later = <DLater>[];
  DCourier? courier;
  DEnemy? echo;
  int nextId = 1;
  double camX = 0;
  double camY = 0;
  double shake = 0;
  bool shakeOn = true;

  // ---- run state ----------------------------------------------------------
  /// 0 contracts or roam, 1 walk to the arena, 2 Echo duel, 3 extraction, 4 ending
  int phase = 0;
  List<int> queue = <int>[];
  int qi = 0;
  int preDone = 0;
  String cKind = '';
  int cKills = 0;
  int cTarget = 0;
  double cTimer = 0;
  Offset? shard;
  bool carrying = false;
  Offset? gate;
  Offset? zone;
  DEnemy? hunted;
  bool huntDone = false;
  Offset checkpoint = Offset.zero;
  final List<String> doneKeys = <String>[];
  int contractsDone = 0;
  bool echoDefeated = false;
  int kills = 0;
  int roamBounties = 0;
  int wave = 0;
  int wavesCleared = 0;
  bool waveActive = false;
  double waveBreak = 2.0;
  final List<String> spawnQueue = <String>[];
  double spawnT = 1.0;
  double endT = 0;
  double duelT = 0;
  String echoWeapon = 'sword';
  DarkomGhostRecorder? ghostRec;
  bool reported = false;
  bool reportDone = false;
  DarkomRunResult? result;
  double chatterT = 25;
  int chatterI = 0;
  double lowHpSay = 0;

  // ---- HUD feed -----------------------------------------------------------
  final List<DToast> toasts = <DToast>[];
  double toastT = 0;
  String banner = '';
  double bannerT = 0;
  Color bannerColor = Colors.white;

  Offset get heroPos => Offset(hx, hy);
  Offset get extractPos => world.extract;
  bool get inDuel => phase == 2;

  void _init() {
    hx = world.extract.dx;
    hy = world.extract.dy;
    checkpoint = Offset(hx, hy);
    camX = hx;
    camY = hy;
    for (final String k in darkomWeaponKinds) {
      weaponUse[k] = 0;
    }
    mana = maxMana;
    if (roam) {
      say(ch.fixer, darkomRoamIntro, ch.fixerColor, dur: 7);
      waveBreak = 2.5;
      return;
    }
    final Set<String> done = boot.progress.contractsDone;
    final List<int> remaining = <int>[];
    for (int i = 0; i < ch.contracts.length; i++) {
      if (!done.contains(ch.keyFor(i))) remaining.add(i);
    }
    if (remaining.isEmpty && done.contains(ch.echoKey)) {
      for (int i = 0; i < ch.contracts.length; i++) {
        remaining.add(i);
      }
    }
    queue = remaining;
    preDone = ch.contracts.length - remaining.length;
    say(ch.fixer, ch.intro, ch.fixerColor, dur: 7);
    if (queue.isEmpty) {
      beginApproach();
    } else {
      startContract();
    }
  }

  // ---- RealmLogic ---------------------------------------------------------

  @override
  int get hearts => lives < 0 ? 0 : lives;

  @override
  int get maxHearts => 3;

  @override
  void onAction(int id) {
    if (over || phase == 4) return;
    switch (id) {
      case 0:
        this.heroAttack();
        break;
      case 1:
        this.heroSpecial();
        break;
      case 2:
        this.heroDash();
        break;
      case 3:
        this.swapWeapon();
        break;
      default:
        break;
    }
  }

  @override
  double actionReady(int id) {
    switch (id) {
      case 0: {
        if (weapon == 'staff' && mana < 13) return mana / 13;
        if (weapon == 'axe' && this.hasHeroAxe()) return 0.0;
        if (atkCd <= 0 || atkCdMax <= 0) return 1.0;
        final double v = 1.0 - atkCd / atkCdMax;
        return v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
      }
      case 1: {
        if (specCd <= 0 || specCdMax <= 0) return 1.0;
        final double v = 1.0 - specCd / specCdMax;
        return v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
      }
      case 2: {
        if (dashCd <= 0) return 1.0;
        final double v = 1.0 - dashCd / 1.6;
        return v < 0 ? 0.0 : (v > 1 ? 1.0 : v);
      }
      default:
        return 1.0;
    }
  }

  @override
  int get xp => result?.xp ?? 0;

  int get timeBonus => (phase == 4 && !roam) ? max(0, 560 - time.round()) : 0;

  @override
  int get finalScore => kills * 10 + contractsDone * 150 + (echoDefeated ? 500 : 0) + wavesCleared * 60 + roamBounties * 100 + timeBonus;

  @override
  List<RealmChip> get chips {
    final List<RealmChip> out = <RealmChip>[];
    if (roam) {
      out.add(RealmChip('Wave $wave', Icons.local_fire_department_rounded, const Color(0xFFFF9100)));
    } else if (phase >= 1) {
      out.add(RealmChip(echoDefeated ? 'Echo down' : 'Echo', Icons.bolt_rounded, const Color(0xFF00E5FF)));
    } else {
      out.add(RealmChip('Contract ${preDone + contractsDone}/${ch.contracts.length}', Icons.assignment_rounded, const Color(0xFFFFD54F)));
    }
    out.add(RealmChip('Kills $kills', Icons.whatshot_rounded, const Color(0xFFFF5252)));
    out.add(RealmChip(darkomWeapon(weapon).name, Icons.gavel_rounded, const Color(0xFFB0BEC5)));
    return out;
  }

  @override
  Map<String, String> get extraStats {
    final Map<String, String> m = <String, String>{};
    m['District'] = theme.name;
    if (roam) {
      m['Waves'] = '$wavesCleared';
    } else {
      m['Contracts'] = '$contractsDone/${queue.length}';
      m['Echo'] = echoDefeated ? 'Defeated' : 'Not yet';
    }
    m['Kills'] = '$kills';
    final DarkomRunResult? r = result;
    if (r != null) {
      if (!r.accepted) {
        m['Note'] = 'Run not counted';
      } else if (r.chapterAdvanced) {
        m['Chapter'] = r.chapter > 5 ? 'Story complete' : 'Now ${darkomChapter(r.chapter).name}';
      }
      if (r.unlocks.isNotEmpty) {
        m['Unlocked'] = r.unlocks.take(3).join(', ');
      }
    } else if (reportDone) {
      m['Saved'] = 'Offline';
    } else if (reported) {
      m['Saving'] = '...';
    }
    return m;
  }

  @override
  bool get modal => false;

  // ---- objective guidance -------------------------------------------------

  DEnemy? nearestAliveEnemy() {
    DEnemy? best;
    double bd = 1e18;
    for (final DEnemy e in enemies) {
      if (!e.alive) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      final double d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    return best;
  }

  Offset? get targetPoint {
    if (over) return null;
    if (roam) {
      final DEnemy? b = nearestBounty();
      if (b != null) return Offset(b.x, b.y);
      final DEnemy? n = nearestAliveEnemy();
      return n == null ? null : Offset(n.x, n.y);
    }
    switch (phase) {
      case 0:
        switch (cKind) {
          case 'clear': {
            final DEnemy? n = nearestAliveEnemy();
            return n == null ? null : Offset(n.x, n.y);
          }
          case 'recover':
            return carrying ? extractPos : shard;
          case 'escort': {
            final DCourier? c = courier;
            final Offset? g = gate;
            if (c == null) return g;
            if (c.downT > 0) return Offset(c.x, c.y);
            if ((Offset(c.x, c.y) - heroPos).distance > 380) return Offset(c.x, c.y);
            return g;
          }
          case 'hunt': {
            final DEnemy? h = hunted;
            return (h != null && h.alive) ? Offset(h.x, h.y) : null;
          }
          case 'survive':
            return zone;
          default:
            return null;
        }
      case 1:
        return world.arena;
      case 2: {
        final DEnemy? e = echo;
        return (e != null && e.alive) ? Offset(e.x, e.y) : null;
      }
      case 3:
        return extractPos;
      default:
        return null;
    }
  }

  DEnemy? nearestBounty() {
    DEnemy? best;
    double bd = 1e18;
    for (final DEnemy e in enemies) {
      if (!e.alive || !e.bounty) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      final double d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    return best;
  }

  @override
  Offset? get objectiveDelta {
    final Offset? t = targetPoint;
    if (t == null || heroDead) return null;
    return Offset(t.dx - hx, t.dy - hy);
  }

  @override
  String? get objectiveDistance {
    final Offset? d = objectiveDelta;
    if (d == null) return null;
    return '${(d.distance / 10).round()} m';
  }

  @override
  String? get objectiveText {
    if (over) return null;
    if (heroDead) return lives > 0 ? 'You are down. Returning to the checkpoint...' : 'You are down. The run is over.';
    if (roam) {
      if (!waveActive) return wave == 0 ? 'Get ready. The first wave arrives soon.' : 'Wave $wave cleared. Next wave in ${max(1, waveBreak.ceil())}.';
      final int left = spawnQueue.length + aliveCount();
      if (nearestBounty() != null) return 'Wave $wave: stop ${nearestBounty()!.name} ($left left)';
      return 'Wave $wave: defeat the shades ($left left)';
    }
    switch (phase) {
      case 0:
        return '${contractLabel()}: ${contractText()}';
      case 1:
        return 'Echo duel: walk to the lit arena.';
      case 2: {
        final DEnemy? e = echo;
        final String n = e == null ? 'your Echo' : (e.name.isEmpty ? 'your Echo' : e.name);
        return 'Defeat $n. Watch the red warnings.';
      }
      case 3:
        return 'Echo defeated. Reach the extraction gate.';
      default:
        return 'Chapter complete.';
    }
  }

  String contractLabel() => 'Contract ${(qi < queue.length ? queue[qi] : 0) + 1} of ${ch.contracts.length}';

  String contractText() {
    switch (cKind) {
      case 'clear':
        return 'defeat shades ($cKills/$cTarget)';
      case 'recover':
        return carrying ? 'carry the shard to the extraction gate' : 'grab the memory shard';
      case 'escort': {
        final DCourier? c = courier;
        final String n = ch.courierName;
        if (c != null && c.downT > 0) return '$n is down, hold the line';
        if (c != null && (Offset(c.x, c.y) - heroPos).distance > 380) return 'go back for $n';
        return 'lead $n to ${ch.gateName}';
      }
      case 'hunt':
        return 'hunt ${ch.bountyName}';
      case 'survive': {
        final Offset? z = zone;
        if (z != null && (z - heroPos).distance > darkomZoneRadius) return 'reach the glowing zone';
        return 'hold the zone (${max(0, (cTarget - cTimer).ceil())} s)';
      }
      default:
        return 'follow the arrow';
    }
  }

  // ---- toasts, banner, effects -------------------------------------------

  void say(String who, String text, Color c, {double dur = 4.5}) {
    if (toasts.length >= 4) toasts.removeAt(1 < toasts.length ? 1 : 0);
    toasts.add(DToast(who, text, c.value, dur));
  }

  void showBanner(String text, Color c, {double dur = 2.4}) {
    banner = text;
    bannerT = dur;
    bannerColor = c;
  }

  void spark(double x, double y, Color c, {int n = 6, double spd = 150, double size = 3, double life = 0.4}) {
    for (int i = 0; i < n; i++) {
      if (parts.length >= 160) break;
      final double a = rnd.nextDouble() * pi * 2;
      final double s = spd * (0.4 + rnd.nextDouble() * 0.8);
      parts.add(DPart(x, y, cos(a) * s, sin(a) * s, life * (0.6 + rnd.nextDouble() * 0.6), size * (0.7 + rnd.nextDouble() * 0.6), c));
    }
  }

  void floatText(double x, double y, String t, Color c, {double size = 14}) {
    if (texts.length >= 24) texts.removeAt(0);
    texts.add(DText(x + (rnd.nextDouble() - 0.5) * 12, y - 14, t, 0.85, c, size));
  }

  void ringFx(double x, double y, double r, Color c, {double life = 0.35}) {
    if (fxs.length >= 40) fxs.removeAt(0);
    fxs.add(DFx(0, x, y, 0, r, 0, life, c));
  }

  void arcFx(double x, double y, double angle, double sweep, double r, Color c, {double life = 0.22}) {
    if (fxs.length >= 40) fxs.removeAt(0);
    fxs.add(DFx(1, x, y, angle, r, sweep, life, c));
  }

  void flashFx(double x, double y, double r, Color c, {double life = 0.2}) {
    if (fxs.length >= 40) fxs.removeAt(0);
    fxs.add(DFx(3, x, y, 0, r, 0, life, c));
  }

  void doShake(double a) {
    if (!shakeOn) return;
    if (a > shake) shake = a;
  }

  void laterIn(double t, void Function() fn) {
    if (later.length > 40) return;
    later.add(DLater(t, fn));
  }

  // ---- step ---------------------------------------------------------------

  @override
  void step(double dt) {
    if (over) return;
    if (phase == 4) {
      endT -= dt;
      if (endT <= 0) {
        over = true;
        cues.add('win');
        return;
      }
    }
    _updateTimers(dt);
    if (heroDead) {
      deathT -= dt;
      if (deathT <= 0) _afterDeath();
    } else {
      _updateHero(dt);
    }
    _updateLater(dt);
    world.updateFlow(hx, hy);
    this.updateEnemies(dt);
    this.updateCourier(dt);
    this.updateProjectiles(dt);
    this.updateAxes(dt);
    _updatePicks(dt);
    _updateFx(dt);
    _updateContract(dt);
    if (phase == 0 || phase == 1 || phase == 3) {
      if (!roam) _updateSpawns(dt);
    }
    if (phase == 2 && !heroDead) {
      duelT += dt;
      ghostRec?.sample(dt, hx - world.arena.dx, hy - world.arena.dy);
    }
    // chatter from the fixer every so often
    chatterT -= dt;
    if (chatterT <= 0 && toasts.isEmpty && phase < 4) {
      chatterT = 38;
      if (ch.chatter.isNotEmpty) {
        say(ch.fixer, ch.chatter[chatterI % ch.chatter.length], ch.fixerColor, dur: 4);
        chatterI++;
      }
    }
    // camera
    final double k = dt * 9 > 1 ? 1.0 : dt * 9;
    camX += (hx - camX) * k;
    camY += (hy - camY) * k;
  }

  void _updateTimers(double dt) {
    if (invuln > 0) invuln -= dt;
    if (hitFlash > 0) hitFlash -= dt;
    if (swapFlash > 0) swapFlash -= dt;
    if (noManaT > 0) noManaT -= dt;
    if (atkCd > 0) atkCd -= dt;
    if (specCd > 0) specCd -= dt;
    if (dashCd > 0) dashCd -= dt;
    if (aimLock > 0) aimLock -= dt;
    if (swingT >= 0) {
      swingT += dt;
      if (swingT > swingDur) swingT = -1;
    }
    if (spinT >= 0) {
      spinT += dt;
      if (spinT > 0.4) spinT = -1;
    }
    if (shake > 0) {
      shake -= dt * 30;
      if (shake < 0) shake = 0;
    }
    if (bannerT > 0) bannerT -= dt;
    if (toasts.isNotEmpty) {
      toastT += dt;
      if (toastT >= toasts.first.dur) {
        toasts.removeAt(0);
        toastT = 0;
      }
    } else {
      toastT = 0;
    }
    if (manaPause > 0) {
      manaPause -= dt;
    } else if (mana < maxMana) {
      mana += (weapon == 'staff' ? 20 : 8) * dt;
      if (mana > maxMana) mana = maxMana;
    }
  }

  void _updateHero(double dt) {
    final double imag = sqrt(inputX * inputX + inputY * inputY);
    hmoving = imag > 0.12;
    double vx = 0;
    double vy = 0;
    double sp = 190;
    if (carrying) sp *= 0.93;
    if (slamT > 0) sp *= 0.3;
    if (guard > 0) sp *= 0.6;
    if (flurry > 0) sp *= 0.7;
    if (dashT > 0) {
      vx = dashVx;
      vy = dashVy;
      dashT -= dt;
    } else if (chargeT > 0) {
      vx = chargeVx;
      vy = chargeVy;
      chargeT -= dt;
      this.heroChargeHits();
    } else if (hmoving) {
      vx = inputX * sp;
      vy = inputY * sp;
      if (aimLock <= 0) {
        hFace = atan2(inputY, inputX);
      }
    }
    final double c = cos(hFace);
    if (c > 0.25) {
      faceSign = 1;
    } else if (c < -0.25) {
      faceSign = -1;
    }
    vx += kvx;
    vy += kvy;
    final double dec = exp(-9 * dt);
    kvx *= dec;
    kvy *= dec;
    final Offset np = world.move(hx, hy, vx * dt, vy * dt, darkomHeroRadius);
    hx = np.dx;
    hy = np.dy;
    hphase += sqrt(vx * vx + vy * vy) * dt * 0.055;
    this.updateHeroCombat(dt);
    if (hp < 30 && lowHpSay <= 0 && toasts.isEmpty && phase < 4) {
      lowHpSay = 20;
      say(ch.fixer, darkomHurtLines[rnd.nextInt(darkomHurtLines.length)], ch.fixerColor, dur: 3);
    }
    if (lowHpSay > 0) lowHpSay -= dt;
  }

  void _updateLater(double dt) {
    for (int i = later.length - 1; i >= 0; i--) {
      final DLater l = later[i];
      l.t -= dt;
      if (l.t <= 0) {
        later.removeAt(i);
        try {
          l.fn();
        } catch (_) {}
      }
    }
  }

  void _updatePicks(double dt) {
    for (int i = picks.length - 1; i >= 0; i--) {
      final DPick p = picks[i];
      p.life -= dt;
      final double dx = p.x - hx;
      final double dy = p.y - hy;
      if (!heroDead && dx * dx + dy * dy < 30 * 30) {
        hp = min(maxHp, hp + 25);
        floatText(p.x, p.y, '+25', const Color(0xFF69F0AE), size: 15);
        spark(p.x, p.y, const Color(0xFF69F0AE), n: 8);
        picks.removeAt(i);
      } else if (p.life <= 0) {
        picks.removeAt(i);
      }
    }
  }

  void _updateFx(double dt) {
    for (int i = parts.length - 1; i >= 0; i--) {
      final DPart p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final double d = exp(-3.5 * dt);
      p.vx *= d;
      p.vy *= d;
    }
    for (int i = texts.length - 1; i >= 0; i--) {
      final DText t = texts[i];
      t.life -= dt;
      t.y -= 38 * dt;
      if (t.life <= 0) texts.removeAt(i);
    }
    for (int i = fxs.length - 1; i >= 0; i--) {
      fxs[i].life -= dt;
      if (fxs[i].life <= 0) fxs.removeAt(i);
    }
  }

  // ---- death --------------------------------------------------------------

  void loseLife() {
    if (heroDead) return;
    lives -= 1;
    heroDead = true;
    deathT = 1.2;
    cues.add('lose');
    doShake(10);
    spark(hx, hy, const Color(0xFFFF5252), n: 14, spd: 220);
    ringFx(hx, hy, 80, const Color(0xFFFF5252), life: 0.5);
    later.clear();
    guard = 0;
    flurry = 0;
    slamT = 0;
    chargeT = 0;
    dashT = 0;
    spinT = -1;
    swingT = -1;
    if (carrying) {
      carrying = false;
      shard = Offset(hx, hy);
    }
    if (lives > 0) {
      showBanner('DOWN', const Color(0xFFFF5252), dur: 1.4);
    } else {
      showBanner('OUT OF LIVES', const Color(0xFFFF5252), dur: 2.0);
    }
  }

  void _afterDeath() {
    if (lives <= 0) {
      over = true;
      return;
    }
    heroDead = false;
    hx = checkpoint.dx;
    hy = checkpoint.dy;
    hp = maxHp;
    invuln = 2.6;
    kvx = 0;
    kvy = 0;
    mana = maxMana;
    projs.removeWhere((DProj p) => p.hostile);
    axes.removeWhere((DAxe a) => a.hostile);
    for (final DEnemy e in enemies) {
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      final double d = sqrt(dx * dx + dy * dy);
      if (d < 280 && e.type != 'echo') {
        final double nx = d < 1 ? 1.0 : dx / d;
        final double ny = d < 1 ? 0.0 : dy / d;
        e.vx += nx * 380;
        e.vy += ny * 380;
        e.stun = max(e.stun, 0.9);
        e.tele = 0;
        e.tShape = 0;
      } else if (e.type == 'echo') {
        e.tele = 0;
        e.tShape = 0;
        e.cd = max(e.cd, 1.5);
        e.hp = min(e.maxHp, e.hp + e.maxHp * 0.12);
      }
    }
    ringFx(hx, hy, 120, const Color(0xFF00E5FF), life: 0.6);
    showBanner('BACK IN', const Color(0xFF00E5FF), dur: 1.2);
    camX = hx;
    camY = hy;
  }

  // ---- enemies ------------------------------------------------------------

  int aliveCount() {
    int n = 0;
    for (final DEnemy e in enemies) {
      if (e.alive) n++;
    }
    return n;
  }

  double get hpScale {
    final double c = roam ? (5 + wave * 0.05) : chapterNo.toDouble();
    return 1 + 0.12 * (c - 1);
  }

  double get dmgScale {
    if (roam) return 1.25;
    return 0.9 + 0.07 * chapterNo;
  }

  DEnemy? makeEnemy(String type, double x, double y, {bool bounty = false, String name = ''}) {
    if (enemies.length >= darkomMaxEnemies) return null;
    final DarkomEnemyDef d = darkomEnemies[type] ?? darkomEnemies['shade']!;
    double hpv = d.hp * hpScale;
    if (bounty) hpv = d.hp * (1 + 0.15 * (roam ? 4 + wave * 0.3 : chapterNo - 1));
    final DEnemy e = DEnemy(nextId++, type, x, y, hpv, d.r, d.speed * (1 + 0.03 * (chapterNo > 5 ? 4 : chapterNo - 1)), d.dmg * dmgScale);
    e.bounty = bounty;
    e.name = name;
    e.cd = 0.6 + rnd.nextDouble() * 1.2;
    e.blinkCd = 2 + rnd.nextDouble() * 2.5;
    e.face = rnd.nextDouble() * pi * 2;
    enemies.add(e);
    return e;
  }

  DEnemy? spawnNear(String type, Offset c, double minR, double maxR, {bool bounty = false, String name = ''}) {
    for (int i = 0; i < 16; i++) {
      final double a = rnd.nextDouble() * pi * 2;
      final double r = minR + rnd.nextDouble() * (maxR - minR);
      final double x = c.dx + cos(a) * r;
      final double y = c.dy + sin(a) * r;
      if (world.circleHits(x, y, 26)) continue;
      return makeEnemy(type, x, y, bounty: bounty, name: name);
    }
    return null;
  }

  Offset? ambientSpawnPoint() {
    final List<Offset> pts = world.clearPts;
    if (pts.isEmpty) return null;
    for (int i = 0; i < 12; i++) {
      final Offset p = pts[rnd.nextInt(pts.length)];
      final double d = (p - heroPos).distance;
      if (d > 520 && d < 1300) return p;
    }
    return null;
  }

  String pickType() {
    final List<int> mix = darkomSpawnMix(chapterNo > 5 ? 5 : chapterNo);
    int total = 0;
    for (final int w in mix) {
      total += w;
    }
    int r = rnd.nextInt(total < 1 ? 1 : total);
    const List<String> names = <String>['shade', 'spitter', 'brute', 'wraith'];
    for (int i = 0; i < mix.length; i++) {
      if (r < mix[i]) return names[i];
      r -= mix[i];
    }
    return 'shade';
  }

  int ambientTarget() {
    final int c = chapterNo > 5 ? 5 : chapterNo;
    if (phase == 1 || phase == 3) return 2;
    if (phase != 0) return 0;
    switch (cKind) {
      case 'clear': {
        final int remaining = cTarget - cKills;
        final int want = remaining + 1;
        final int cap = 4 + c;
        return max(3, want < cap ? want : cap);
      }
      case 'recover':
        return 3 + c ~/ 2 + (carrying ? 2 : 0);
      case 'escort':
        return 4 + c ~/ 2;
      case 'hunt':
        return 2 + c ~/ 2;
      case 'survive':
        return 6 + c;
      default:
        return 3;
    }
  }

  void _updateSpawns(double dt) {
    spawnT -= dt;
    if (spawnT > 0) return;
    if (aliveCount() >= ambientTarget() || enemies.length >= darkomMaxEnemies) {
      spawnT = 0.4;
      return;
    }
    final Offset? p = ambientSpawnPoint();
    if (p == null) {
      spawnT = 0.3;
      return;
    }
    makeEnemy(pickType(), p.dx, p.dy);
    final double base = 1.6 - 0.07 * (chapterNo > 5 ? 5 : chapterNo);
    spawnT = max(0.7, base) * (cKind == 'clear' ? 0.75 : 1.0);
  }

  // ---- contracts ----------------------------------------------------------

  void startContract() {
    if (qi >= queue.length) {
      beginApproach();
      return;
    }
    final int idx = queue[qi];
    final DarkomContractDef def = ch.contracts[idx];
    cKind = def.kind;
    cKills = 0;
    cTimer = 0;
    cTarget = def.target;
    shard = null;
    carrying = false;
    gate = null;
    zone = null;
    courier = null;
    hunted = null;
    huntDone = false;
    checkpoint = world.circleHits(hx, hy, darkomHeroRadius) ? world.nearestClear(hx, hy) : Offset(hx, hy);
    switch (def.kind) {
      case 'recover': {
        final Offset s = world.pickPoint(rnd, extractPos, minDist: 900, avoid: <Offset>[heroPos]);
        shard = s;
        for (int i = 0; i < 2 + (chapterNo > 3 ? 1 : 0); i++) {
          spawnNear(i == 2 ? 'brute' : 'shade', s, 120, 220);
        }
        break;
      }
      case 'escort': {
        Offset cp = Offset(hx + 34, hy + 10);
        if (world.circleHits(cp.dx, cp.dy, 14)) cp = world.nearestClear(hx, hy);
        courier = DCourier(cp.dx, cp.dy, ch.courierName);
        gate = world.pickPoint(rnd, heroPos, minDist: 950);
        break;
      }
      case 'hunt': {
        final Offset p = world.pickPoint(rnd, heroPos, minDist: 800);
        final DEnemy? b = spawnNear('bounty', p, 0, 40, bounty: true, name: ch.bountyName);
        hunted = b ?? makeEnemy('bounty', p.dx, p.dy, bounty: true, name: ch.bountyName);
        if (hunted == null) {
          // Too many enemies around: clear room, then place the bounty.
          enemies.removeWhere((DEnemy e) => !e.bounty && e.type != 'echo');
          hunted = makeEnemy('bounty', p.dx, p.dy, bounty: true, name: ch.bountyName);
        }
        for (int i = 0; i < 3; i++) {
          spawnNear(i == 0 ? 'spitter' : 'shade', p, 140, 260);
        }
        break;
      }
      case 'survive': {
        zone = world.pickPoint(rnd, heroPos, minDist: 600, maxDist: 1300);
        break;
      }
      default:
        break;
    }
    say(ch.fixer, def.briefing, ch.fixerColor, dur: 6);
    showBanner(def.title.toUpperCase(), theme.neonA, dur: 2.2);
    cues.add('tap');
  }

  void completeContract() {
    if (qi >= queue.length) return;
    final int idx = queue[qi];
    final DarkomContractDef def = ch.contracts[idx];
    doneKeys.add(ch.keyFor(idx));
    contractsDone++;
    cues.add('win');
    showBanner('CONTRACT COMPLETE', const Color(0xFF69F0AE), dur: 2.4);
    say(ch.fixer, def.doneLine, ch.fixerColor, dur: 4);
    floatText(hx, hy - 20, '+150', const Color(0xFFFFD54F), size: 20);
    ringFx(hx, hy, 140, const Color(0xFF69F0AE), life: 0.6);
    hp = min(maxHp, hp + 35);
    courier = null;
    shard = null;
    carrying = false;
    gate = null;
    zone = null;
    hunted = null;
    huntDone = false;
    qi++;
    if (qi >= queue.length) {
      beginApproach();
    } else {
      startContract();
    }
  }

  void beginApproach() {
    phase = 1;
    cKind = '';
    checkpoint = Offset(hx, hy);
    say(ch.fixer, ch.echoIntro, ch.fixerColor, dur: 6);
    showBanner('THE ECHO AWAITS', const Color(0xFF00E5FF), dur: 2.4);
  }

  String mostUsedWeapon() {
    String best = weapon;
    int bn = -1;
    for (final String k in darkomWeaponKinds) {
      final int n = weaponUse[k] ?? 0;
      if (n > bn || (n == bn && k == weapon)) {
        bn = n;
        best = k;
      }
    }
    if (bn <= 0) return weapon;
    return best;
  }

  void startDuel() {
    phase = 2;
    for (final DEnemy e in enemies) {
      spark(e.x, e.y, const Color(0xFF9C6BFF), n: 5);
    }
    enemies.clear();
    projs.clear();
    axes.clear();
    carrying = false;
    echoWeapon = mostUsedWeapon();
    checkpoint = Offset(hx, hy);
    Offset ep = Offset(2 * world.arena.dx - hx, 2 * world.arena.dy - hy);
    if (world.circleHits(ep.dx, ep.dy, 20) || (ep - heroPos).distance < 300) {
      ep = world.pickPoint(rnd, heroPos, minDist: 320, maxDist: 650);
    }
    final DEnemy? e = makeEnemy('echo', ep.dx, ep.dy, name: ch.echoName);
    if (e != null) {
      e.hp = 200.0 + 45.0 * (chapterNo > 5 ? 5 : chapterNo);
      e.maxHp = e.hp;
      e.speed = 150;
      e.dmg = 14 * (0.7 + 0.06 * (chapterNo > 5 ? 5 : chapterNo));
      e.weapon = echoWeapon;
      e.spawnT = 1.5;
      e.cd = 1.5;
      e.aggro = true;
    }
    echo = e;
    ghostRec = DarkomGhostRecorder();
    duelT = 0;
    showBanner(ch.echoName.toUpperCase(), const Color(0xFF00E5FF), dur: 2.6);
    say(ch.fixer, 'It carries your weapon and your habits. Watch the warnings.', ch.fixerColor, dur: 4);
    cues.add('bad');
  }

  void onEchoDefeated() {
    if (phase != 2) return;
    phase = 3;
    echoDefeated = true;
    doneKeys.add(ch.echoKey);
    hp = maxHp;
    cues.add('win');
    showBanner('ECHO DEFEATED', const Color(0xFF69F0AE), dur: 2.6);
    floatText(hx, hy - 30, '+500', const Color(0xFFFFD54F), size: 22);
    say(ch.fixer, 'Now get out. Extraction gate, ${(extractPos - heroPos).distance ~/ 10} metres away.', ch.fixerColor, dur: 4);
    checkpoint = Offset(hx, hy);
    // Expire hostile shots instead of removing them: this can run while the
    // projectile loop is still walking the list.
    for (final DProj p in projs) {
      if (p.hostile) p.life = 0;
    }
  }

  void finishChapter() {
    if (phase == 4) return;
    phase = 4;
    endT = 2.8;
    invuln = 99;
    showBanner('CHAPTER COMPLETE', const Color(0xFFFFD54F), dur: 2.8);
    say(ch.fixer, ch.outro, ch.fixerColor, dur: 4.5);
  }

  void _updateContract(double dt) {
    if (heroDead || phase == 4) return;
    if (roam) {
      _updateRoam(dt);
      return;
    }
    switch (phase) {
      case 0:
        _updateActiveContract(dt);
        break;
      case 1:
        if ((world.arena - heroPos).distance < world.arenaRadius) startDuel();
        break;
      case 2: {
        final DEnemy? e = echo;
        if (e == null || !e.alive) {
          if (duelT > 0.5) onEchoDefeated();
        }
        break;
      }
      case 3:
        if ((extractPos - heroPos).distance < 80) finishChapter();
        break;
      default:
        break;
    }
  }

  void _updateActiveContract(double dt) {
    switch (cKind) {
      case 'clear':
        if (cKills >= cTarget) completeContract();
        break;
      case 'recover': {
        if (!carrying) {
          final Offset? s = shard;
          if (s != null && (s - heroPos).distance < 50) {
            carrying = true;
            shard = null;
            cues.add('good');
            showBanner('SHARD ACQUIRED', const Color(0xFF00E5FF), dur: 1.8);
            say(ch.fixer, 'You have it. Now run for the extraction gate.', ch.fixerColor, dur: 3.5);
            spark(hx, hy, const Color(0xFF00E5FF), n: 12);
          }
        } else if ((extractPos - heroPos).distance < 80) {
          completeContract();
        }
        break;
      }
      case 'escort': {
        final DCourier? c = courier;
        final Offset? g = gate;
        if (c != null && g != null && c.downT <= 0 && (Offset(c.x, c.y) - g).distance < 110) completeContract();
        break;
      }
      case 'hunt':
        if (huntDone) completeContract();
        break;
      case 'survive': {
        final Offset? z = zone;
        if (z != null && (z - heroPos).distance < darkomZoneRadius) {
          cTimer += dt;
          if (cTimer >= cTarget) completeContract();
        }
        break;
      }
      default:
        completeContract();
        break;
    }
  }

  // ---- roam (story finished) ----------------------------------------------

  void _updateRoam(double dt) {
    if (time >= 480) {
      phase = 4;
      endT = 2.0;
      invuln = 99;
      showBanner('CURFEW', const Color(0xFFFFD54F), dur: 2.0);
      return;
    }
    if (!waveActive) {
      waveBreak -= dt;
      if (waveBreak <= 0) _startWave();
      return;
    }
    // trickle the queued enemies in
    spawnT -= dt;
    if (spawnQueue.isNotEmpty && spawnT <= 0 && enemies.length < darkomMaxEnemies && aliveCount() < 8 + wave ~/ 2) {
      final Offset? p = ambientSpawnPoint();
      if (p != null) {
        final String t = spawnQueue.removeAt(0);
        if (t == 'bounty') {
          makeEnemy('bounty', p.dx, p.dy, bounty: true, name: darkomRoamBounties[(wave ~/ 3) % darkomRoamBounties.length]);
        } else {
          makeEnemy(t, p.dx, p.dy);
        }
        spawnT = 0.7;
      } else {
        spawnT = 0.3;
      }
    }
    if (spawnQueue.isEmpty && aliveCount() == 0) {
      waveActive = false;
      wavesCleared++;
      waveBreak = 3.5;
      cues.add('win');
      showBanner('WAVE $wave CLEARED', const Color(0xFF69F0AE), dur: 2.0);
      floatText(hx, hy - 20, '+60', const Color(0xFFFFD54F), size: 18);
      hp = min(maxHp, hp + 30);
    }
  }

  void _startWave() {
    wave++;
    waveActive = true;
    spawnQueue.clear();
    final int n = min(20, 4 + wave * 2);
    if (wave % 3 == 0) spawnQueue.add('bounty');
    for (int i = 0; i < n; i++) {
      spawnQueue.add(pickType());
    }
    spawnT = 0.5;
    checkpoint = Offset(hx, hy);
    showBanner('WAVE $wave', theme.neonA, dur: 1.8);
  }

  // ---- run end ------------------------------------------------------------

  @override
  Future<void> onRunEnd() async {
    if (reported) return;
    reported = true;
    try {
      final DarkomGhost? g = ghostRec?.build(echoWeapon);
      if (g != null) {
        boot.ghost = g;
        await DarkomGhost.save(g);
      }
    } catch (_) {}
    DarkomRunResult? r;
    try {
      r = await DarkomService.reportRun(
        district: ch.district,
        kills: kills,
        score: finalScore,
        durationSec: time.round(),
        contractsDone: List<String>.from(doneKeys),
        echoDefeated: echoDefeated,
      );
    } catch (_) {
      r = null;
    }
    result = r;
    reportDone = true;
    if (r != null) {
      try {
        final DarkomProgress old = boot.progress;
        final Set<String> merged = Set<String>.from(old.contractsDone)..addAll(r.newContracts);
        boot.progress = DarkomProgress(
          chapter: r.chapter < old.chapter ? old.chapter : r.chapter,
          bestScore: finalScore > old.bestScore ? finalScore : old.bestScore,
          totalKills: old.totalKills + kills,
          echoWins: old.echoWins + (echoDefeated ? 1 : 0),
          contractsDone: merged,
          runsToday: old.runsToday + 1,
        );
      } catch (_) {}
    }
  }
}
