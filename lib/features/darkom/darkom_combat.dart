import 'dart:math';
import 'package:flutter/material.dart';
import 'darkom_entities.dart';
import 'darkom_logic.dart';
import 'darkom_story.dart';

/// Absolute difference between two angles, 0 to pi.
double dkAngDiff(double a, double b) {
  double d = a - b;
  while (d > pi) {
    d -= 2 * pi;
  }
  while (d < -pi) {
    d += 2 * pi;
  }
  return d < 0 ? -d : d;
}

Color dkBlade(Color c) => Color.lerp(c, Colors.white, 0.35) ?? c;

/// The hero's six weapons, specials, dash and damage handling.
extension DarkomCombat on DarkomLogic {
  Color get fxColor => armory.glowFor(weapon) ?? dkBlade(armory.metalFor(weapon));

  bool hasHeroAxe() {
    for (final DAxe a in axes) {
      if (!a.hostile && !a.dead) return true;
    }
    return false;
  }

  DEnemy? nearestTarget(double range) {
    DEnemy? best;
    double bd = 1e18;
    for (final DEnemy e in enemies) {
      if (!e.alive || e.spawnT > 0) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      final double d = sqrt(dx * dx + dy * dy);
      if (d - e.r > range) continue;
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    return best;
  }

  /// Auto aim: the angle to the nearest enemy in range, else the facing.
  double aimAt(double range) {
    final DEnemy? t = nearestTarget(range);
    if (t == null) return hFace;
    return atan2(t.y - hy, t.x - hx);
  }

  void noteUse(String w) {
    weaponUse[w] = (weaponUse[w] ?? 0) + 1;
    if (phase == 2) ghostRec?.event(0);
  }

  void beginSwing(String kind, double angle, double dur) {
    swingKind = kind;
    swingAng = angle;
    swingDur = dur;
    swingT = 0;
    swingDir = -swingDir;
    hFace = angle;
    aimLock = dur + 0.12;
  }

  bool blocksAngle(double ang) => (guard > 0 || chargeT > 0) && dkAngDiff(ang, hFace) < 1.22;

  // ---- damage -------------------------------------------------------------

  bool hurtEnemy(DEnemy e, double dmg, {double kx = 0, double ky = 0, double kb = 0, double stun = 0, bool crit = false}) {
    if (!e.alive || e.spawnT > 0) return false;
    e.hp -= dmg;
    e.flash = 0.12;
    e.aggro = true;
    final double len = sqrt(kx * kx + ky * ky);
    if (len > 0.001 && kb > 0) {
      final double k = kb * (e.bounty ? 0.3 : (e.type == 'echo' ? 0.5 : (e.type == 'brute' ? 0.6 : 1.0)));
      e.vx += kx / len * k;
      e.vy += ky / len * k;
    }
    if (stun > 0) {
      final double s = stun * (e.bounty ? 0.4 : (e.type == 'echo' ? 0.5 : 1.0));
      if (s > e.stun) e.stun = s;
      e.tele = 0;
      e.tShape = 0;
      e.dashT = 0;
    }
    final DarkomEnemyDef def = darkomEnemies[e.type] ?? darkomEnemies['shade']!;
    floatText(e.x, e.y - e.r - 4, dmg.round().toString(), crit ? const Color(0xFFFFD54F) : Colors.white, size: crit ? 19 : 14);
    spark(e.x, e.y, crit ? const Color(0xFFFFD54F) : def.glow, n: crit ? 7 : 4, spd: 170);
    cues.add('tap');
    if (e.hp <= 0) killEnemy(e);
    return true;
  }

  void killEnemy(DEnemy e) {
    if (!e.alive) return;
    e.alive = false;
    final DarkomEnemyDef def = darkomEnemies[e.type] ?? darkomEnemies['shade']!;
    spark(e.x, e.y, def.glow, n: 14, spd: 220, life: 0.55);
    spark(e.x, e.y, Colors.white, n: 4, spd: 120, size: 2.5);
    ringFx(e.x, e.y, e.r * 2.8, def.glow, life: 0.4);
    flashFx(e.x, e.y, e.r * 1.8, def.glow, life: 0.18);
    doShake(e.bounty || e.type == 'echo' ? 10 : 3);
    cues.add('good');
    kills++;
    if (e.type == 'echo') {
      onEchoDefeated();
      return;
    }
    if (e.bounty) {
      if (identical(hunted, e)) huntDone = true;
      if (roam) roamBounties++;
    }
    if (phase == 0 && cKind == 'clear' && !e.bounty) cKills++;
    floatText(e.x, e.y - e.r - 20, '+10', const Color(0xFFFFD54F), size: 13);
    if (picks.length < 6 && rnd.nextDouble() < (e.bounty ? 1.0 : 0.1)) {
      picks.add(DPick(e.x, e.y));
    }
  }

  /// Damage to the hero from an enemy at (sx, sy). Returns true if it landed
  /// or was blocked.
  bool hurtHero(double dmg, double sx, double sy, {double kb = 150}) {
    if (heroDead || phase == 4) return false;
    if (invuln > 0 || dashT > 0) return false;
    final double dx = sx - hx;
    final double dy = sy - hy;
    final double ang = atan2(dy, dx);
    if (blocksAngle(ang)) {
      hp -= dmg * 0.1;
      invuln = 0.15;
      kvx -= cos(ang) * 120;
      kvy -= sin(ang) * 120;
      spark(hx + cos(hFace) * 22, hy + sin(hFace) * 22, const Color(0xFF80D8FF), n: 6, spd: 180);
      floatText(hx, hy - 30, 'BLOCK', const Color(0xFF80D8FF), size: 13);
      cues.add('tap');
      doShake(2);
      if (hp <= 0) {
        hp = 0;
        loseLife();
      }
      return true;
    }
    hp -= dmg;
    hitFlash = 0.22;
    invuln = 0.45;
    kvx -= cos(ang) * kb;
    kvy -= sin(ang) * kb;
    doShake(6);
    cues.add('bad');
    floatText(hx, hy - 30, dmg.round().toString(), const Color(0xFFFF5252), size: 17);
    spark(hx, hy, const Color(0xFFFF5252), n: 6, spd: 170);
    if (hp <= 0) {
      hp = 0;
      loseLife();
    }
    return true;
  }

  int coneHit(double a, double range, double half, double dmg, {double kb = 0, double stun = 0, bool crit = false}) {
    int n = 0;
    for (final DEnemy e in enemies) {
      if (!e.alive || e.spawnT > 0) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      final double dist = sqrt(dx * dx + dy * dy);
      if (dist - e.r > range) continue;
      if (dist > e.r + 18 && dkAngDiff(atan2(dy, dx), a) > half + e.r / (dist < 1 ? 1 : dist)) continue;
      if (hurtEnemy(e, dmg, kx: dx, ky: dy, kb: kb, stun: stun, crit: crit)) n++;
    }
    if (n > 0) doShake(n > 1 ? 3 : 2);
    return n;
  }

  int aoeHit(double cx, double cy, double radius, double dmg, {double kb = 0, double stun = 0}) {
    int n = 0;
    for (final DEnemy e in enemies) {
      if (!e.alive || e.spawnT > 0) continue;
      final double dx = e.x - cx;
      final double dy = e.y - cy;
      if (sqrt(dx * dx + dy * dy) - e.r > radius) continue;
      if (hurtEnemy(e, dmg, kx: dx, ky: dy, kb: kb, stun: stun)) n++;
    }
    return n;
  }

  void reflectProj(DProj p) {
    p.vx = -p.vx * 1.1;
    p.vy = -p.vy * 1.1;
    p.hostile = false;
    p.kind = 3;
    p.dmg *= 1.6;
    p.life = 1.4;
    spark(p.x, p.y, const Color(0xFF80D8FF), n: 6);
    floatText(p.x, p.y - 10, 'REFLECT', const Color(0xFF80D8FF), size: 12);
  }

  void addAxe(double angle, double dmg, double maxDist) {
    if (axes.length > 12) return;
    axes.add(DAxe(hx, hy, cos(angle), sin(angle), maxDist, 520, dmg, false, -1));
  }

  void fireBolt(double angle, double dmg, {double speed = 560, double life = 0.85}) {
    if (projs.length >= darkomMaxProjectiles) return;
    projs.add(DProj(hx + cos(angle) * 20, hy + sin(angle) * 20, cos(angle) * speed, sin(angle) * speed, dmg, 7, life, false, 1));
  }

  // ---- buttons ------------------------------------------------------------

  void heroAttack() {
    if (heroDead || phase == 4) return;
    final String w = weapon;
    final DarkomWeaponDef d = darkomWeapon(w);
    switch (w) {
      case 'sword': {
        if (atkCd > 0) return;
        final double a = aimAt(d.auto);
        beginSwing('sword', a, 0.28);
        atkCd = d.cd;
        atkCdMax = d.cd;
        noteUse(w);
        kvx += cos(a) * 150;
        kvy += sin(a) * 150;
        final Color c = fxColor;
        laterIn(0.07, () {
          arcFx(hx, hy, a, 1.9, d.range, c);
          coneHit(a, d.range, 1.0, d.dmg, kb: 110);
        });
        break;
      }
      case 'dagger': {
        if (flurry <= 0 && atkCd > 0) return;
        if (flurry <= 0) {
          flurryT = 0;
          noteUse(w);
        }
        flurry = min(6, flurry + 3);
        break;
      }
      case 'hammer': {
        if (atkCd > 0 || slamT > 0) return;
        final double a = aimAt(d.auto);
        beginSwing('hammer', a, 0.85);
        slamT = 0.45;
        slamAng = a;
        atkCd = d.cd;
        atkCdMax = d.cd;
        noteUse(w);
        final Color c = fxColor;
        laterIn(0.45, () {
          final double px = hx + cos(a) * 74;
          final double py = hy + sin(a) * 74;
          ringFx(px, py, 96, c, life: 0.4);
          flashFx(px, py, 50, Colors.white, life: 0.15);
          spark(px, py, c, n: 12, spd: 230);
          aoeHit(px, py, 94, d.dmg, kb: 340, stun: 0.35);
          doShake(7);
        });
        break;
      }
      case 'axe': {
        if (atkCd > 0 || hasHeroAxe()) return;
        final double a = aimAt(d.auto);
        beginSwing('axe', a, 0.22);
        atkCd = 0.2;
        atkCdMax = 0.2;
        noteUse(w);
        addAxe(a, d.dmg, d.range);
        break;
      }
      case 'staff': {
        if (atkCd > 0) return;
        if (mana < 13) {
          if (noManaT <= 0) {
            floatText(hx, hy - 34, 'No mana', const Color(0xFF80D8FF), size: 13);
            noManaT = 0.8;
          }
          return;
        }
        mana -= 13;
        manaPause = 0.5;
        final double a = aimAt(d.auto);
        beginSwing('staff', a, 0.25);
        atkCd = d.cd;
        atkCdMax = d.cd;
        noteUse(w);
        fireBolt(a, d.dmg);
        spark(hx + cos(a) * 24, hy + sin(a) * 24, fxColor, n: 4, spd: 120);
        break;
      }
      default: {
        // shield: first press guards, a second press inside the guard window bashes
        if (guard > 0 && guardAge >= 0.06) {
          final double a = aimAt(d.auto);
          beginSwing('bash', a, 0.25);
          guard = 0;
          atkCd = 0.75;
          atkCdMax = 0.75;
          noteUse(w);
          kvx += cos(a) * 240;
          kvy += sin(a) * 240;
          final Color c = fxColor;
          laterIn(0.08, () {
            arcFx(hx, hy, a, 1.5, d.range + 6, c);
            coneHit(a, d.range, 0.9, d.dmg, kb: 380, stun: 1.2);
            for (final DProj p in projs) {
              if (p.hostile && (p.x - hx) * (p.x - hx) + (p.y - hy) * (p.y - hy) < 90 * 90) reflectProj(p);
            }
          });
        } else if (guard <= 0 && atkCd <= 0) {
          final double a = aimAt(d.auto);
          hFace = a;
          aimLock = 0.3;
          guard = 0.6;
          guardAge = 0;
          noteUse(w);
          ringFx(hx + cos(a) * 20, hy + sin(a) * 20, 34, const Color(0xFF80D8FF), life: 0.25);
        }
        break;
      }
    }
  }

  void daggerStab() {
    final DarkomWeaponDef d = darkomWeapon('dagger');
    final double a = aimAt(d.auto);
    beginSwing('dagger', a, 0.14);
    kvx += cos(a) * 170;
    kvy += sin(a) * 170;
    DEnemy? t;
    double bd = 1e18;
    for (final DEnemy e in enemies) {
      if (!e.alive || e.spawnT > 0) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      final double dist = sqrt(dx * dx + dy * dy);
      if (dist - e.r > d.range + 10) continue;
      if (dist > e.r + 18 && dkAngDiff(atan2(dy, dx), a) > 0.7) continue;
      if (dist < bd) {
        bd = dist;
        t = e;
      }
    }
    arcFx(hx, hy, a, 0.5, d.range, fxColor, life: 0.12);
    if (t != null) {
      final bool back = dkAngDiff(t.face, a) < 1.0 && t.type != 'echo';
      hurtEnemy(t, back ? d.dmg * 1.5 : d.dmg, kx: t.x - hx, ky: t.y - hy, kb: 50, crit: back);
    }
  }

  void heroSpecial() {
    if (heroDead || phase == 4) return;
    if (specCd > 0) return;
    final String w = weapon;
    final DarkomWeaponDef d = darkomWeapon(w);
    final Color c = fxColor;
    switch (w) {
      case 'sword': {
        specCd = d.scd;
        specCdMax = d.scd;
        spinT = 0;
        aimLock = 0.5;
        if (phase == 2) ghostRec?.event(2);
        laterIn(0.14, () {
          ringFx(hx, hy, 128, c, life: 0.35);
          arcFx(hx, hy, 0, 6.28, 120, c, life: 0.3);
          aoeHit(hx, hy, 126, d.sdmg, kb: 260, stun: 0.25);
          doShake(5);
        });
        laterIn(0.3, () {
          aoeHit(hx, hy, 126, d.sdmg * 0.5, kb: 120);
        });
        break;
      }
      case 'dagger': {
        final DEnemy? t = nearestTarget(330);
        double a = hFace;
        double travel = 200;
        if (t != null) {
          a = atan2(t.y - hy, t.x - hx);
          final double dist = sqrt((t.x - hx) * (t.x - hx) + (t.y - hy) * (t.y - hy));
          travel = max(0.0, dist - t.r - 20);
          specCd = d.scd;
          specCdMax = d.scd;
        } else {
          specCd = 2.5;
          specCdMax = 2.5;
        }
        hFace = a;
        aimLock = 0.4;
        dashT = 0.14;
        dashVx = cos(a) * travel / 0.14;
        dashVy = sin(a) * travel / 0.14;
        invuln = max(invuln, 0.3);
        spark(hx, hy, c, n: 10, spd: 140);
        ringFx(hx, hy, 40, const Color(0xFF9C6BFF), life: 0.3);
        if (phase == 2) ghostRec?.event(2);
        beginSwing('dagger', a, 0.3);
        if (t != null) {
          final DEnemy target = t;
          laterIn(0.16, () {
            hurtEnemy(target, d.sdmg, kx: cos(a), ky: sin(a), kb: 120, stun: 0.5, crit: true);
            arcFx(hx, hy, a, 0.6, 70, c, life: 0.15);
          });
          laterIn(0.26, () {
            hurtEnemy(target, 10, kx: cos(a), ky: sin(a), kb: 30);
          });
          laterIn(0.36, () {
            hurtEnemy(target, 10, kx: cos(a), ky: sin(a), kb: 30);
          });
        }
        break;
      }
      case 'hammer': {
        specCd = d.scd;
        specCdMax = d.scd;
        slamT = 0.4;
        aimLock = 0.6;
        beginSwing('hammer', hFace, 0.7);
        if (phase == 2) ghostRec?.event(2);
        laterIn(0.4, () {
          ringFx(hx, hy, 190, c, life: 0.5);
          ringFx(hx, hy, 110, Colors.white, life: 0.3);
          flashFx(hx, hy, 80, c, life: 0.2);
          spark(hx, hy, c, n: 16, spd: 260);
          aoeHit(hx, hy, 190, d.sdmg, kb: 220, stun: 1.8);
          doShake(10);
        });
        break;
      }
      case 'axe': {
        specCd = d.scd;
        specCdMax = d.scd;
        final double a = aimAt(d.auto);
        beginSwing('axe', a, 0.3);
        addAxe(a - 0.4, d.sdmg, 240);
        addAxe(a, d.sdmg, 270);
        addAxe(a + 0.4, d.sdmg, 240);
        if (phase == 2) ghostRec?.event(2);
        break;
      }
      case 'staff': {
        if (mana < 30) {
          if (noManaT <= 0) {
            floatText(hx, hy - 34, 'Need 30 mana', const Color(0xFF80D8FF), size: 13);
            noManaT = 0.8;
          }
          return;
        }
        mana -= 30;
        manaPause = 0.8;
        specCd = d.scd;
        specCdMax = d.scd;
        beginSwing('staff', hFace, 0.35);
        if (phase == 2) ghostRec?.event(2);
        ringFx(hx, hy, 170, c, life: 0.45);
        flashFx(hx, hy, 60, Colors.white, life: 0.2);
        laterIn(0.1, () {
          aoeHit(hx, hy, 170, d.sdmg, kb: 270, stun: 0.3);
          doShake(5);
          for (int i = 0; i < 8; i++) {
            final double ang = i * pi / 4;
            if (projs.length >= darkomMaxProjectiles) break;
            projs.add(DProj(hx + cos(ang) * 20, hy + sin(ang) * 20, cos(ang) * 430, sin(ang) * 430, 12, 6, 0.5, false, 1));
          }
        });
        break;
      }
      default: {
        specCd = d.scd;
        specCdMax = d.scd;
        final double a = aimAt(d.auto);
        hFace = a;
        aimLock = 0.6;
        chargeT = 0.38;
        chargeVx = cos(a) * 620;
        chargeVy = sin(a) * 620;
        chargeHit.clear();
        guard = 0;
        invuln = max(invuln, 0.12);
        beginSwing('bash', a, 0.38);
        spark(hx, hy, c, n: 8, spd: 140);
        if (phase == 2) ghostRec?.event(2);
        break;
      }
    }
  }

  void heroChargeHits() {
    for (final DEnemy e in enemies) {
      if (!e.alive || e.spawnT > 0 || chargeHit.contains(e.id)) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      if (sqrt(dx * dx + dy * dy) < e.r + 30) {
        chargeHit.add(e.id);
        hurtEnemy(e, darkomWeapon('shield').sdmg, kx: chargeVx, ky: chargeVy, kb: 400, stun: 0.8);
        doShake(4);
      }
    }
    for (final DProj p in projs) {
      if (p.hostile && (p.x - hx) * (p.x - hx) + (p.y - hy) * (p.y - hy) < 60 * 60) reflectProj(p);
    }
  }

  void heroDash() {
    if (heroDead || phase == 4 || dashCd > 0) return;
    double dx = inputX;
    double dy = inputY;
    final double m = sqrt(dx * dx + dy * dy);
    if (m < 0.2) {
      dx = cos(hFace);
      dy = sin(hFace);
    } else {
      dx /= m;
      dy /= m;
    }
    dashT = 0.2;
    dashVx = dx * 600;
    dashVy = dy * 600;
    dashCd = 1.6;
    invuln = max(invuln, 0.28);
    guard = 0;
    hFace = atan2(dy, dx);
    spark(hx, hy, const Color(0xFF00E5FF), n: 8, spd: 100);
    ringFx(hx, hy, 34, const Color(0xFF00E5FF), life: 0.25);
    if (phase == 2) ghostRec?.event(1);
  }

  void swapWeapon() {
    if (heroDead || phase == 4) return;
    weaponIdx = (weaponIdx + 1) % darkomWeaponKinds.length;
    guard = 0;
    flurry = 0;
    slamT = 0;
    swingT = -1;
    spinT = -1;
    if (atkCd < 0.2) {
      atkCd = 0.2;
      atkCdMax = 0.2;
    }
    swapFlash = 0.5;
    floatText(hx, hy - 36, darkomWeapon(weapon).name, const Color(0xFFFFD54F), size: 14);
    cues.add('tap');
  }

  /// Per frame upkeep of weapon states: guard window, dagger flurry, hammer windup.
  void updateHeroCombat(double dt) {
    if (guard > 0) {
      guard -= dt;
      guardAge += dt;
      if (guard <= 0) {
        guard = 0;
        if (atkCd < 0.35) {
          atkCd = 0.35;
          atkCdMax = 0.35;
        }
      }
    }
    if (slamT > 0) slamT -= dt;
    if (flurry > 0) {
      flurryT -= dt;
      if (flurryT <= 0) {
        daggerStab();
        flurry -= 1;
        flurryT = 0.13;
        if (flurry <= 0) {
          flurry = 0;
          atkCd = 0.32;
          atkCdMax = 0.32;
        }
      }
    }
  }
}
