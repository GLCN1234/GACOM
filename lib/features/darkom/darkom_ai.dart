import 'dart:math';
import 'package:flutter/material.dart';
import 'darkom_combat.dart';
import 'darkom_entities.dart';
import 'darkom_ghost.dart';
import 'darkom_logic.dart';
import 'darkom_story.dart';

/// Enemy behaviour, the Echo, projectiles, thrown axes and the courier.
/// Every dangerous attack starts with a telegraph of at least half a second.
extension DarkomAi on DarkomLogic {
  void updateEnemies(double dt) {
    for (int i = 0; i < enemies.length; i++) {
      final DEnemy e = enemies[i];
      if (e.alive) aiStep(e, dt);
    }
    enemies.removeWhere((DEnemy e) => !e.alive);
  }

  void aiTele(DEnemy e, int shape, double dur, {double r = 0, double a = 0, double w = 0, int atk = 0, double lx = 0, double ly = 0}) {
    e.tele = dur;
    e.teleMax = dur;
    e.tShape = shape;
    e.tR = r;
    e.tA = a;
    e.tW = w;
    e.atk = atk;
    e.ax = lx;
    e.ay = ly;
    e.moving = false;
  }

  void aiMove(DEnemy e, double tx, double ty, double speedMul, double dt, {bool away = false, double side = 0}) {
    final double dx = tx - e.x;
    final double dy = ty - e.y;
    final double d = sqrt(dx * dx + dy * dy);
    if (d < 1) return;
    double ux = dx / d;
    double uy = dy / d;
    if (e.losT > 0) {
      e.losT -= dt;
    } else {
      e.losT = 0.2;
      e.losOk = world.lineClear(e.x, e.y, tx, ty);
    }
    if (!e.losOk && !away) {
      final Offset f = world.flowDir(e.x, e.y);
      if (f.dx != 0 || f.dy != 0) {
        ux = f.dx;
        uy = f.dy;
      }
    }
    if (away) {
      ux = -ux;
      uy = -uy;
    }
    if (side != 0) {
      final double sx = -uy * side;
      final double sy = ux * side;
      ux = sx;
      uy = sy;
    }
    if (e.detour > 0) {
      e.detour -= dt;
      final double rx = -uy * e.detourDir;
      final double ry = ux * e.detourDir;
      ux = rx;
      uy = ry;
    }
    double px = 0;
    double py = 0;
    for (final DEnemy o in enemies) {
      if (identical(o, e) || !o.alive) continue;
      final double ox = e.x - o.x;
      final double oy = e.y - o.y;
      final double dd = ox * ox + oy * oy;
      final double rr = e.r + o.r + 6;
      if (dd < rr * rr && dd > 0.01) {
        final double dl = sqrt(dd);
        px += ox / dl * (rr - dl) / rr;
        py += oy / dl * (rr - dl) / rr;
      }
    }
    ux += px * 0.9;
    uy += py * 0.9;
    final double m = sqrt(ux * ux + uy * uy);
    if (m > 0.001) {
      ux /= m;
      uy /= m;
    }
    final double sp = e.speed * speedMul;
    final Offset np = world.move(e.x, e.y, ux * sp * dt, uy * sp * dt, e.r);
    e.stuckT += dt;
    if (e.stuckT >= 0.5) {
      final double mx = np.dx - e.lastX;
      final double my = np.dy - e.lastY;
      if (sqrt(mx * mx + my * my) < sp * 0.12 && e.detour <= 0) {
        e.detour = 0.8;
        e.detourDir = rnd.nextBool() ? 1.0 : -1.0;
      }
      e.lastX = np.dx;
      e.lastY = np.dy;
      e.stuckT = 0;
    }
    e.x = np.dx;
    e.y = np.dy;
    e.moving = true;
    e.phase += sp * dt * 0.06;
  }

  void aiStep(DEnemy e, double dt) {
    if (e.spawnT > 0) {
      e.spawnT -= dt;
      return;
    }
    if (e.flash > 0) e.flash -= dt;
    if (e.cd > 0) e.cd -= dt;
    if (e.vx.abs() > 2 || e.vy.abs() > 2) {
      final Offset kp = world.move(e.x, e.y, e.vx * dt, e.vy * dt, e.r);
      e.x = kp.dx;
      e.y = kp.dy;
      final double dec = exp(-8 * dt);
      e.vx *= dec;
      e.vy *= dec;
    }
    if (e.stun > 0) {
      e.stun -= dt;
      e.moving = false;
      return;
    }
    if (e.type == 'echo') {
      echoStep(e, dt);
      return;
    }
    if (e.tele > 0) {
      e.tele -= dt;
      e.moving = false;
      if (e.tele <= 0) {
        aiExec(e);
        // aiExec may start a follow-up telegraph (wraith blink); keep it visible.
        if (e.tele <= 0) e.tShape = 0;
      }
      return;
    }
    double tx = hx;
    double ty = hy;
    bool courierT = false;
    final DCourier? c = courier;
    if (c != null && c.downT <= 0 && cKind == 'escort' && phase == 0) {
      final double dc = sqrt((c.x - e.x) * (c.x - e.x) + (c.y - e.y) * (c.y - e.y));
      final double dh = sqrt((hx - e.x) * (hx - e.x) + (hy - e.y) * (hy - e.y));
      if (dc < 520 && dc < dh + 160) {
        tx = c.x;
        ty = c.y;
        courierT = true;
      }
    }
    if (heroDead && !courierT) {
      e.moving = false;
      return;
    }
    final double dx = tx - e.x;
    final double dy = ty - e.y;
    final double d = sqrt(dx * dx + dy * dy);
    if (!e.aggro) {
      if (d < 620) {
        e.aggro = true;
      } else {
        e.moving = false;
        return;
      }
    } else if (d > 1500 && !e.bounty) {
      e.aggro = false;
      e.moving = false;
      return;
    }
    e.face = atan2(dy, dx);
    final DarkomEnemyDef def = darkomEnemies[e.type] ?? darkomEnemies['shade']!;
    switch (e.type) {
      case 'spitter': {
        final bool clear = world.shotClear(e.x, e.y, tx, ty);
        if (d < 180) {
          aiMove(e, tx, ty, 0.95, dt, away: true);
        } else if (d > 330 || !clear) {
          aiMove(e, tx, ty, 1.0, dt);
        } else {
          aiMove(e, tx, ty, 0.45, dt, side: e.detourDir);
        }
        if (e.cd <= 0 && d < 340 && clear) {
          aiTele(e, 3, def.tele, r: 340, a: atan2(dy, dx), w: 18, atk: 2);
          e.tgtCourier = courierT;
        }
        break;
      }
      case 'brute': {
        if (d < def.reach - 20 && e.cd <= 0) {
          aiTele(e, 1, def.tele, r: def.reach, atk: 1);
          e.tgtCourier = courierT;
        } else if (d > def.reach * 0.55) {
          aiMove(e, tx, ty, 1.0, dt);
        } else {
          e.moving = false;
        }
        break;
      }
      case 'wraith': {
        if (e.blinkCd > 0) e.blinkCd -= dt;
        if (e.blinkCd <= 0 && d > 170) {
          e.blinkCd = 3.5 + rnd.nextDouble() * 2;
          for (int i = 0; i < 8; i++) {
            final double a = rnd.nextDouble() * pi * 2;
            final double rr = 90 + rnd.nextDouble() * 40;
            final double bx = tx + cos(a) * rr;
            final double by = ty + sin(a) * rr;
            if (!world.circleHits(bx, by, e.r + 2)) {
              e.bx = bx;
              e.by = by;
              aiTele(e, 2, 0.55, r: 34, atk: 4, lx: bx, ly: by);
              break;
            }
          }
          if (e.tele > 0) break;
        }
        if (d < def.reach - 8 && e.cd <= 0) {
          aiTele(e, 1, def.tele, r: def.reach, atk: 1);
          e.tgtCourier = courierT;
        } else if (d > def.reach * 0.6) {
          aiMove(e, tx, ty, 1.0, dt);
        } else {
          e.moving = false;
        }
        break;
      }
      case 'bounty': {
        if (!e.enraged && e.hp < e.maxHp * 0.35) {
          e.enraged = true;
          e.speed *= 1.2;
          floatText(e.x, e.y - e.r - 24, 'ENRAGED', const Color(0xFFFF1744), size: 15);
        }
        if (e.cd <= 0) {
          if (d < 150) {
            aiTele(e, 1, 0.9, r: 125, atk: 1);
            e.tgtCourier = courierT;
            break;
          } else if (d < 480 && world.shotClear(e.x, e.y, tx, ty)) {
            aiTele(e, 5, 0.85, r: 380, a: atan2(dy, dx), w: 0.28, atk: 3);
            break;
          }
        }
        if (d > 110) {
          aiMove(e, tx, ty, 1.0, dt);
        } else {
          e.moving = false;
        }
        break;
      }
      default: {
        // shade
        if (d < def.reach - 8 && e.cd <= 0) {
          aiTele(e, 1, def.tele, r: def.reach, atk: 1);
          e.tgtCourier = courierT;
        } else if (d > def.reach * 0.6) {
          aiMove(e, tx, ty, 1.0, dt);
        } else {
          e.moving = false;
        }
        break;
      }
    }
  }

  /// The telegraph has run out: do the attack.
  void aiExec(DEnemy e) {
    final DarkomEnemyDef def = darkomEnemies[e.type] ?? darkomEnemies['shade']!;
    final double cdMul = e.enraged ? 0.65 : 1.0;
    switch (e.atk) {
      case 1: {
        // melee circle around the attacker
        final bool heavy = e.type == 'brute' || e.type == 'bounty';
        final double r = e.tR;
        if (heavy) {
          ringFx(e.x, e.y, r, def.glow, life: 0.35);
          spark(e.x, e.y, def.glow, n: 10, spd: 200);
          doShake(e.type == 'bounty' ? 7 : 5);
        } else {
          final double a = atan2(hy - e.y, hx - e.x);
          e.vx += cos(a) * 170;
          e.vy += sin(a) * 170;
          arcFx(e.x, e.y, a, 1.4, r, def.glow, life: 0.15);
        }
        final double dd = sqrt((hx - e.x) * (hx - e.x) + (hy - e.y) * (hy - e.y));
        if (dd < r + darkomHeroRadius) this.hurtHero(e.dmg, e.x, e.y, kb: heavy ? 330 : 170);
        final DCourier? c = courier;
        if (c != null && c.downT <= 0) {
          final double dc = sqrt((c.x - e.x) * (c.x - e.x) + (c.y - e.y) * (c.y - e.y));
          if (dc < r + 14) hurtCourier(e.dmg);
        }
        e.cd = def.cd * cdMul;
        break;
      }
      case 2: {
        if (projs.length < darkomMaxProjectiles) {
          projs.add(DProj(e.x + cos(e.tA) * 18, e.y + sin(e.tA) * 18, cos(e.tA) * 300, sin(e.tA) * 300, e.dmg, 6, 1.7, true, 0));
        }
        spark(e.x + cos(e.tA) * 20, e.y + sin(e.tA) * 20, def.glow, n: 4, spd: 90);
        e.cd = def.cd * cdMul;
        break;
      }
      case 3: {
        for (int i = -1; i <= 1; i++) {
          if (projs.length >= darkomMaxProjectiles) break;
          final double a = e.tA + i * e.tW;
          projs.add(DProj(e.x + cos(a) * 24, e.y + sin(a) * 24, cos(a) * 320, sin(a) * 320, e.dmg * 0.55, 7, 1.6, true, 2));
        }
        e.cd = def.cd * cdMul;
        break;
      }
      case 4: {
        // wraith blink, then an attack warning right away
        spark(e.x, e.y, def.glow, n: 8, spd: 120);
        e.x = e.bx;
        e.y = e.by;
        spark(e.x, e.y, def.glow, n: 8, spd: 120);
        ringFx(e.x, e.y, 40, def.glow, life: 0.3);
        aiTele(e, 1, def.tele, r: def.reach, atk: 1);
        break;
      }
      default:
        echoExec(e);
        break;
    }
  }

  // ---- the Echo -----------------------------------------------------------

  double echoReach(String w) {
    switch (w) {
      case 'dagger':
        return 140;
      case 'hammer':
        return 125;
      case 'axe':
        return 300;
      case 'staff':
        return 320;
      case 'shield':
        return 210;
      default:
        return 100;
    }
  }

  void echoStep(DEnemy e, double dt) {
    final double dxh = hx - e.x;
    final double dyh = hy - e.y;
    final double d = sqrt(dxh * dxh + dyh * dyh);
    if (e.swingT >= 0) {
      e.swingT += dt;
      if (e.swingT > 0.4) e.swingT = -1;
    }
    if (e.dashT > 0) {
      e.dashT -= dt;
      final Offset np = world.move(e.x, e.y, e.dashVx * dt, e.dashVy * dt, e.r);
      e.x = np.dx;
      e.y = np.dy;
      e.moving = true;
      e.phase += dt * 20;
      if (e.dashHurts && !e.dashHit && !heroDead && d < e.r + darkomHeroRadius + 12) {
        e.dashHit = true;
        this.hurtHero(e.dmg, e.x, e.y, kb: 260);
      }
      spark(e.x, e.y, const Color(0xFF00E5FF), n: 1, spd: 30, life: 0.3);
      return;
    }
    if (e.dashCd > 0) e.dashCd -= dt;
    if (e.tele > 0) {
      e.tele -= dt;
      e.moving = false;
      if (e.tele <= 0) {
        aiExec(e);
        // aiExec may start a follow-up telegraph (wraith blink); keep it visible.
        if (e.tele <= 0) e.tShape = 0;
      }
      return;
    }
    if (heroDead) {
      e.moving = false;
      return;
    }
    e.face = atan2(dyh, dxh);
    final DarkomGhost? ghost = boot.ghost;
    final double ta = (duelT - 2.5) / 4.0;
    final double aggr = ta < 0 ? 0.0 : (ta > 1 ? 1.0 : ta);
    final Offset ar = world.arena;
    double gx;
    double gy;
    if (ghost != null) {
      final Offset g = ghost.posAt(duelT);
      gx = ar.dx + g.dx * 0.85;
      gy = ar.dy + g.dy * 0.85;
    } else {
      gx = 2 * ar.dx - hx;
      gy = 2 * ar.dy - hy;
    }
    final bool ranged = e.weapon == 'axe' || e.weapon == 'staff';
    final double wantD = ranged ? 250.0 : 70.0;
    final double inv = d < 1 ? 0.0 : 1.0 / d;
    final double px = hx + (e.x - hx) * inv * wantD;
    final double py = hy + (e.y - hy) * inv * wantD;
    final double tx = gx + (px - gx) * aggr;
    final double ty = gy + (py - gy) * aggr;
    final double toTarget = sqrt((tx - e.x) * (tx - e.x) + (ty - e.y) * (ty - e.y));
    if (ranged && aggr > 0.5 && d < 160) {
      aiMove(e, hx, hy, 0.9, dt, away: true);
    } else if (toTarget > 12) {
      aiMove(e, tx, ty, aggr < 1 ? 0.8 : 1.0, dt);
    } else {
      e.moving = false;
    }

    // dodge dash: when the hero swings nearby, or when the recording dashed
    bool wantDash = false;
    if (e.dashCd <= 0 && d < 280) {
      if (swingT >= 0 && d < 170 && rnd.nextDouble() < 1.6 * dt) wantDash = true;
      if (ghost != null) {
        final List<double> dts = ghost.eventTimes(1);
        while (e.dashIdx < dts.length && dts[e.dashIdx] <= duelT) {
          if (d < 260) wantDash = true;
          e.dashIdx++;
        }
      }
    }
    if (wantDash) {
      final double side = rnd.nextBool() ? 1.0 : -1.0;
      final double a = atan2(dyh, dxh) + side * pi / 2;
      final double tx2 = e.x + cos(a) * 110;
      final double ty2 = e.y + sin(a) * 110;
      if (!world.circleHits(tx2, ty2, e.r + 2) && world.lineClear(e.x, e.y, tx2, ty2)) {
        e.dashT = 0.2;
        e.dashVx = cos(a) * 520;
        e.dashVy = sin(a) * 520;
        e.dashHurts = false;
        e.dashHit = false;
        e.dashCd = 2.8 + rnd.nextDouble();
        spark(e.x, e.y, const Color(0xFF00E5FF), n: 6, spd: 110);
        return;
      }
    }

    // attack timing: from the recording when there is one
    if (e.wantAttack > 0) e.wantAttack -= dt;
    if (ghost != null) {
      final List<double> ats = ghost.eventTimes(0);
      while (e.nextEvent < ats.length && ats[e.nextEvent] <= duelT) {
        e.wantAttack = 1.2;
        e.nextEvent++;
      }
    }
    if (e.cd > 0) {
      e.blinkT = 0;
    } else {
      e.blinkT += dt;
    }
    final double gap = ghost == null ? 2.0 : ghost.attackGap;
    final bool timing = ghost == null || e.wantAttack > 0 || e.blinkT > gap * 0.6;
    final bool inRange = d < echoReach(e.weapon);
    final bool seen = !ranged || world.shotClear(e.x, e.y, hx, hy);
    if (e.cd <= 0 && aggr > 0.35 && inRange && seen && timing) {
      echoStartAttack(e, d);
    }
  }

  void echoStartAttack(DEnemy e, double d) {
    final double a = atan2(hy - e.y, hx - e.x);
    switch (e.weapon) {
      case 'dagger':
        aiTele(e, 3, 0.55, r: 150, a: a, w: 36, atk: 11);
        break;
      case 'hammer':
        aiTele(e, 2, 0.85, r: 98, atk: 12, lx: hx, ly: hy);
        break;
      case 'axe':
        aiTele(e, 3, 0.6, r: 300, a: a, w: 28, atk: 13);
        break;
      case 'staff':
        aiTele(e, 5, 0.7, r: 340, a: a, w: 0.3, atk: 14);
        break;
      case 'shield':
        aiTele(e, 3, 0.65, r: 230, a: a, w: 38, atk: 15);
        break;
      default:
        aiTele(e, 4, 0.6, r: 105, a: a, w: 1.0, atk: 10);
        break;
    }
    e.atkCount++;
  }

  void echoExec(DEnemy e) {
    final DarkomGhost? ghost = boot.ghost;
    final double gap = ghost == null ? 2.0 : ghost.attackGap;
    e.cd = gap * (0.85 + rnd.nextDouble() * 0.3);
    e.blinkT = 0;
    const Color cy = Color(0xFF00E5FF);
    final double dh = sqrt((hx - e.x) * (hx - e.x) + (hy - e.y) * (hy - e.y));
    switch (e.atk) {
      case 10: {
        e.swingT = 0;
        arcFx(e.x, e.y, e.tA, 2.0, e.tR, cy, life: 0.2);
        if (dh < e.tR + darkomHeroRadius && dkAngDiff(atan2(hy - e.y, hx - e.x), e.tA) < e.tW + 0.15) {
          this.hurtHero(e.dmg, e.x, e.y, kb: 200);
        }
        break;
      }
      case 11: {
        e.dashT = 0.12;
        e.dashVx = cos(e.tA) * 150 / 0.12;
        e.dashVy = sin(e.tA) * 150 / 0.12;
        e.dashHurts = true;
        e.dashHit = false;
        e.swingT = 0;
        break;
      }
      case 12: {
        e.swingT = 0;
        ringFx(e.ax, e.ay, e.tR, cy, life: 0.4);
        flashFx(e.ax, e.ay, 40, Colors.white, life: 0.15);
        spark(e.ax, e.ay, cy, n: 10, spd: 200);
        doShake(5);
        final double dd = sqrt((hx - e.ax) * (hx - e.ax) + (hy - e.ay) * (hy - e.ay));
        if (dd < e.tR + darkomHeroRadius) this.hurtHero(e.dmg * 1.5, e.ax, e.ay, kb: 300);
        break;
      }
      case 13: {
        e.swingT = 0;
        if (axes.length < 12) {
          axes.add(DAxe(e.x, e.y, cos(e.tA), sin(e.tA), 300, 440, e.dmg * 0.9, true, e.id));
        }
        break;
      }
      case 14: {
        e.swingT = 0;
        for (int i = -1; i <= 1; i++) {
          if (projs.length >= darkomMaxProjectiles) break;
          final double a = e.tA + i * e.tW;
          projs.add(DProj(e.x + cos(a) * 22, e.y + sin(a) * 22, cos(a) * 340, sin(a) * 340, e.dmg * 0.75, 7, 1.5, true, 2));
        }
        break;
      }
      default: {
        e.swingT = 0;
        e.dashT = 0.35;
        e.dashVx = cos(e.tA) * 660;
        e.dashVy = sin(e.tA) * 660;
        e.dashHurts = true;
        e.dashHit = false;
        break;
      }
    }
  }

  // ---- projectiles and thrown axes ----------------------------------------

  void updateProjectiles(double dt) {
    for (int i = projs.length - 1; i >= 0; i--) {
      final DProj p = projs[i];
      p.life -= dt;
      if (p.life <= 0) {
        projs.removeAt(i);
        continue;
      }
      final double nx = p.x + p.vx * dt;
      final double ny = p.y + p.vy * dt;
      if (world.wallAt(nx, ny)) {
        spark(p.x, p.y, p.hostile ? const Color(0xFFFF6E40) : const Color(0xFF80D8FF), n: 4, spd: 110);
        projs.removeAt(i);
        continue;
      }
      p.x = nx;
      p.y = ny;
      if (p.hostile) {
        if (!heroDead) {
          final double dx = p.x - hx;
          final double dy = p.y - hy;
          if (dx * dx + dy * dy < (p.r + darkomHeroRadius) * (p.r + darkomHeroRadius)) {
            if (this.blocksAngle(atan2(dy, dx))) {
              this.reflectProj(p);
              continue;
            }
            if (this.hurtHero(p.dmg, p.x - p.vx * 0.05, p.y - p.vy * 0.05, kb: 120)) {
              projs.removeAt(i);
              continue;
            }
          }
        }
        final DCourier? c = courier;
        if (c != null && c.downT <= 0) {
          final double dx = p.x - c.x;
          final double dy = p.y - c.y;
          if (dx * dx + dy * dy < (p.r + 13) * (p.r + 13)) {
            hurtCourier(p.dmg);
            projs.removeAt(i);
            continue;
          }
        }
      } else {
        bool gone = false;
        for (final DEnemy e in enemies) {
          if (!e.alive || e.spawnT > 0) continue;
          final double dx = p.x - e.x;
          final double dy = p.y - e.y;
          if (dx * dx + dy * dy < (p.r + e.r) * (p.r + e.r)) {
            this.hurtEnemy(e, p.dmg, kx: p.vx, ky: p.vy, kb: p.kind == 3 ? 130 : 90);
            gone = true;
            break;
          }
        }
        if (gone) projs.removeAt(i);
      }
    }
  }

  void updateAxes(double dt) {
    for (int i = axes.length - 1; i >= 0; i--) {
      final DAxe a = axes[i];
      a.spin += dt * 18;
      final double step = a.speed * dt;
      if (a.out) {
        final double nx = a.x + a.dx * step;
        final double ny = a.y + a.dy * step;
        if (world.wallAt(nx, ny)) {
          a.out = false;
          a.hit.clear();
          a.heroHit = false;
          spark(a.x, a.y, const Color(0xFFB0BEC5), n: 4, spd: 100);
        } else {
          a.x = nx;
          a.y = ny;
          a.dist += step;
          if (a.dist >= a.maxDist) {
            a.out = false;
            a.hit.clear();
            a.heroHit = false;
          }
        }
      } else {
        double ox = hx;
        double oy = hy;
        bool ownerOk = true;
        if (a.hostile) {
          ownerOk = false;
          for (final DEnemy e in enemies) {
            if (e.id == a.ownerId && e.alive) {
              ox = e.x;
              oy = e.y;
              ownerOk = true;
              break;
            }
          }
        }
        if (!ownerOk) {
          axes.removeAt(i);
          continue;
        }
        final double dx = ox - a.x;
        final double dy = oy - a.y;
        final double d = sqrt(dx * dx + dy * dy);
        if (d < 26) {
          axes.removeAt(i);
          continue;
        }
        a.dx = dx / d;
        a.dy = dy / d;
        a.x += a.dx * step * 1.1;
        a.y += a.dy * step * 1.1;
      }
      if (!a.hostile) {
        for (final DEnemy e in enemies) {
          if (!e.alive || e.spawnT > 0 || a.hit.contains(e.id)) continue;
          final double dx = e.x - a.x;
          final double dy = e.y - a.y;
          if (dx * dx + dy * dy < (e.r + 16) * (e.r + 16)) {
            a.hit.add(e.id);
            this.hurtEnemy(e, a.dmg, kx: a.dx, ky: a.dy, kb: 80);
          }
        }
      } else if (!a.heroHit && !heroDead) {
        final double dx = hx - a.x;
        final double dy = hy - a.y;
        if (dx * dx + dy * dy < (darkomHeroRadius + 16) * (darkomHeroRadius + 16)) {
          a.heroHit = true;
          this.hurtHero(a.dmg, a.x, a.y, kb: 130);
        }
      }
    }
  }

  // ---- courier ------------------------------------------------------------

  void hurtCourier(double dmg) {
    final DCourier? c = courier;
    if (c == null || c.downT > 0) return;
    c.hp -= dmg;
    c.flash = 0.15;
    c.hurtT = 3.5;
    spark(c.x, c.y, const Color(0xFFFF8A80), n: 4);
    if (c.hp <= 0) {
      c.hp = 0;
      c.downT = 6;
      say(c.name, 'I am down! Hold them off!', const Color(0xFFFF8A80), dur: 3.5);
    }
  }

  void updateCourier(double dt) {
    final DCourier? c = courier;
    if (c == null) return;
    if (c.flash > 0) c.flash -= dt;
    if (c.hurtT > 0) c.hurtT -= dt;
    c.moving = false;
    if (c.downT > 0) {
      c.downT -= dt;
      if (c.downT <= 0) {
        c.hp = 55;
        say(c.name, 'Back on my feet. Go, go.', const Color(0xFF69F0AE), dur: 3);
      }
      return;
    }
    if (c.hurtT <= 0 && c.hp < c.maxHp) {
      c.hp += 4 * dt;
      if (c.hp > c.maxHp) c.hp = c.maxHp;
    }
    final double dx = hx - c.x;
    final double dy = hy - c.y;
    final double d = sqrt(dx * dx + dy * dy);
    if (d > 85) {
      double ux = dx / d;
      double uy = dy / d;
      if (!world.lineClear(c.x, c.y, hx, hy)) {
        final Offset f = world.flowDir(c.x, c.y);
        if (f.dx != 0 || f.dy != 0) {
          ux = f.dx;
          uy = f.dy;
        }
      }
      final Offset np = world.move(c.x, c.y, ux * 165 * dt, uy * 165 * dt, 13);
      c.x = np.dx;
      c.y = np.dy;
      c.moving = true;
      c.phase += 165 * dt * 0.055;
      if (ux.abs() > 0.2) c.face = ux > 0 ? 1.0 : -1.0;
    }
    if (d >= 900) {
      c.farT += dt;
      if (c.farT > 6) {
        final Offset p = world.nearestClear(hx, hy);
        c.x = p.dx;
        c.y = p.dy;
        c.farT = 0;
      }
    } else {
      c.farT = 0;
    }
  }
}
