import 'dart:math';
import 'package:flutter/material.dart';
import 'darkom_ai.dart';
import 'darkom_combat.dart';
import 'darkom_coop.dart';
import 'darkom_entities.dart';
import 'darkom_logic.dart';
import 'darkom_story.dart';

/// The co-op side of [DarkomLogic]. The host runs the enemies; guests mirror
/// them. See darkom_coop.dart for the overview.
const List<String> _kTypes = <String>['shade', 'spitter', 'brute', 'wraith', 'bounty', 'echo'];

int _i(dynamic v, [int d = 0]) => v is num ? v.round() : d;
double _f(dynamic v, [double d = 0]) {
  if (v is! num) return d;
  final double x = v.toDouble();
  return (x.isNaN || x.isInfinite) ? d : x;
}

extension DarkomCoopLogic on DarkomLogic {
  bool get isGuest => coop != null && !coop!.args.isHost;
  bool get isCoopHost => coop != null && coop!.args.isHost;

  /// Players currently in the patrol, including this one.
  int get coopCount {
    final DarkomCoop? cp = coop;
    if (cp == null) return 1;
    int n = 1;
    for (final DAlly a in cp.allies.values) {
      if (a.seen && !a.gone) n++;
    }
    return n;
  }

  double get coopHpMul => coop == null ? 1.0 : 1.0 + 0.45 * (coopCount - 1);
  int get maxEnemiesNow => coop == null ? darkomMaxEnemies : darkomMaxEnemies + 4 * (coopCount - 1);
  double get coopWaveMul => coop == null ? 1.0 : 0.6 + 0.4 * coopCount;

  void coopWire() {
    final DarkomCoop? cp = coop;
    if (cp == null) return;
    cp.onSnap = (Map<String, dynamic> p) => this.coopApplySnap(p);
    cp.onHit = (String from, Map<String, dynamic> p) => this.coopApplyHit(from, p);
    cp.onHurt = (Map<String, dynamic> p) => this.coopApplyHurt(p);
    cp.onKill = (Map<String, dynamic> p) => this.coopApplyKill(p);
    cp.onHostLost = () => this.coopHostLost();
    cp.onFx = (String from, Map<String, dynamic> p) => this.coopApplyFx(from, p);
    cp.onHostChanged = (bool nowHost) => this.coopHostChanged(nowHost);
    cp.start();
  }

  // ---- per frame ---------------------------------------------------------

  void coopTick(double dt) {
    final DarkomCoop? cp = coop;
    if (cp == null) return;
    coopFxBudget = min(6.0, coopFxBudget + dt * 10);
    double sw = 0;
    if (swingT >= 0) {
      final double fr = swingDur > 0 ? swingT / swingDur : 0.0;
      sw = 0.05 + 0.95 * (fr < 0 ? 0.0 : (fr > 1 ? 1.0 : fr));
    }
    cp.tick(dt, hx, hy, hFace, hp, maxHp, heroDead, sw, false);
    if (cp.args.isHost) {
      for (final DAlly a in cp.allies.values) {
        if (a.alive) world.updateFlowSlot(a.slot, a.x, a.y);
      }
      coopSnapT -= dt;
      if (coopSnapT <= 0) {
        bool busy = false;
        for (final DEnemy e in enemies) {
          if (e.alive) {
            busy = true;
            break;
          }
        }
        if (!busy) {
          for (final DProj pr in projs) {
            if (pr.hostile) {
              busy = true;
              break;
            }
          }
        }
        coopSnapT = busy ? 0.15 + 0.02 * cp.allies.length : 1.0;
        cp.send('snap', this.coopBuildSnap());
      }
    }
  }

  // ---- host handover ------------------------------------------------------------------

  void coopHostLost() {
    final DarkomCoop? cp = coop;
    if (cp == null || phase == 4 || over) return;
    cp.handleHostLoss();
    if (!cp.args.isHost && cp.electNext() == null) {
      phase = 4;
      endT = 2.5;
      invuln = 99;
      showBanner('HOST LEFT', const Color(0xFFFF5252), dur: 2.5);
    }
  }

  void coopHostChanged(bool nowHost) {
    if (nowHost) {
      this.coopPromote();
    } else {
      aiAlly = null;
      showBanner('NEW HOST', const Color(0xFFFFD54F), dur: 1.6);
    }
  }

  /// This phone takes over running the enemies. The enemies it was only
  /// drawing become real ones, with the same health and place.
  void coopPromote() {
    int top = nextId;
    for (final DEnemy e in enemies) {
      if (e.id >= top) top = e.id + 1;
      if (!e.alive) continue;
      final DarkomEnemyDef d = darkomEnemies[e.type] ?? darkomEnemies['shade']!;
      e.speed = d.speed * 1.12;
      e.dmg = d.dmg * dmgScale;
      e.spawnT = 0;
      e.aggro = true;
      e.cd = 0.8 + rnd.nextDouble();
      e.tele = 0;
      e.tShape = 0;
      e.blinkCd = 2 + rnd.nextDouble() * 2;
      if (e.bounty && coop!.args.contract == 'bounty') cpBoss = e;
    }
    nextId = top + 1000;
    coopTargets.clear();
    projs.removeWhere((DProj p) => p.hostile);
    cpBossSpawned = cpBoss != null || cpProgress > 0;
    if (waveBreak > 0.5 && cpClock > 1) waveBreak = 0.5;
    coopSnapT = 0;
    spawnQueue.clear();
    showBanner('YOU RUN THE STREETS NOW', const Color(0xFFFFD54F), dur: 2.2);
    say('Dispatch', 'The host dropped. You are the host now, the patrol continues.', const Color(0xFFFFD54F), dur: 4);
  }

  // ---- shared attack effects -------------------------------------------------------------------

  void coopFxOut(String k, double x, double y, double a, double r, int col, double life) {
    final DarkomCoop? cp = coop;
    if (cp == null || coopRemoteFx || coopFxBudget < 1 || heroDead) return;
    coopFxBudget -= 1;
    cp.send('fx', <String, dynamic>{
      'k': k,
      'x': x.round(),
      'y': y.round(),
      'a': a.round(),
      'b': r.round(),
      'c': col,
      'l': (life * 100).round(),
    });
  }

  void coopApplyFx(String from, Map<String, dynamic> p) {
    final DarkomCoop? cp = coop;
    final DAlly? al = cp?.allies[from];
    if (cp == null || al == null || !al.alive) return;
    final String k = p['k'] is String ? p['k'] as String : '';
    final double life = (_f(p['l'], 30) / 100).clamp(0.1, 1.2).toDouble();
    if (k == 'ring' || k == 'flash') {
      final double r = _f(p['b'], 80).clamp(10.0, 260.0).toDouble();
      final Color col = Color(_i(p['c'], 0xFFFFFFFF) & 0xFFFFFFFF);
      coopRemoteFx = true;
      if (k == 'ring') {
        ringFx(al.x, al.y, r, col, life: life);
      } else {
        flashFx(al.x, al.y, r, col, life: life);
      }
      coopRemoteFx = false;
    } else if (k == 'b') {
      if (projs.length >= darkomMaxProjectiles) return;
      final double vx = _f(p['a']).clamp(-900.0, 900.0).toDouble();
      // x,y are where the shot started; for bolts vx rides in 'a' and vy in 'b'
      final double vy = _f(p['b']).clamp(-900.0, 900.0).toDouble();
      projs.add(DProj(_f(p['x']), _f(p['y']), vx, vy, 0, 7, life, false, 1)..visual = true);
    } else if (k == 'nova') {
      for (int i = 0; i < 8; i++) {
        if (projs.length >= darkomMaxProjectiles) break;
        final double ang = i * pi / 4;
        projs.add(DProj(al.x + cos(ang) * 20, al.y + sin(ang) * 20, cos(ang) * 430, sin(ang) * 430, 0, 6, 0.5, false, 1)..visual = true);
      }
    }
  }

  // ---- Squad Contracts ----------------------------------------------------------------------------

  String coopContractTitle(String c) {
    switch (c) {
      case 'clear':
        return 'Block Sweep';
      case 'hold':
        return 'Hold the Line';
      case 'bounty':
        return 'Bounty Run';
      case 'data':
        return 'Data Run';
      default:
        return 'City Patrol';
    }
  }

  String coopContractBrief(String c) {
    switch (c) {
      case 'clear':
        return 'Clear $cpTarget hostiles from the streets before time runs out.';
      case 'hold':
        return 'Survive ${cpTarget ~/ 60} minutes. They keep coming, and more of them as time goes on.';
      case 'bounty':
        return 'A bounty target is loose in the city. Find it and take it down together.';
      case 'data':
        return 'Collect $cpTarget data nodes spread across the city. Any one of you can pick one up.';
      default:
        return '';
    }
  }

  String coopContractChip() {
    final String c = coop?.args.contract ?? '';
    switch (c) {
      case 'hold':
        return '${max(0, cpTarget - cpClock.floor())}s';
      case 'bounty':
        return 'Bounty';
      default:
        return '$cpProgress/$cpTarget';
    }
  }

  void coopContractInit() {
    final DarkomCoop? cp = coop;
    if (cp == null || cp.args.contract.isEmpty) return;
    final int n = cp.args.playerIds.length;
    switch (cp.args.contract) {
      case 'clear':
        cpTarget = 14 + 8 * n;
        cpLimit = 420;
        break;
      case 'hold':
        cpTarget = 240;
        cpLimit = 240;
        break;
      case 'bounty':
        cpTarget = 1;
        cpLimit = 360;
        break;
      case 'data':
        cpTarget = 4 + n;
        cpLimit = 420;
        final Random r = Random(cp.args.seed ^ 0x2f1d);
        final List<Offset> pts = world.clearPts;
        for (int tries = 0; tries < 600 && cpNodes.length < cpTarget && pts.isNotEmpty; tries++) {
          final Offset c = pts[r.nextInt(pts.length)];
          if ((c - world.extract).distance < 700) continue;
          bool near = false;
          for (final Offset o in cpNodes) {
            if ((o - c).distance < 850) {
              near = true;
              break;
            }
          }
          if (!near) cpNodes.add(c);
        }
        cpTarget = cpNodes.length;
        break;
      default:
        break;
    }
    say('Dispatch', coopContractBrief(cp.args.contract), const Color(0xFF69F0AE), dur: 7);
  }

  /// The point the arrow and minimap flag should lead to, if the contract has one.
  Offset? coopTarget() {
    final DarkomCoop? cp = coop;
    if (cp == null || cp.args.contract != 'data' || cpResult != 0) return null;
    Offset? best;
    double bd = double.infinity;
    for (int i = 0; i < cpNodes.length; i++) {
      if (cpTaken.contains(i)) continue;
      final double d = (cpNodes[i] - heroPos).distanceSquared;
      if (d < bd) {
        bd = d;
        best = cpNodes[i];
      }
    }
    return best;
  }

  void coopContractEnd(bool win) {
    if (cpResult != 0) return;
    cpResult = win ? 1 : 2;
    phase = 4;
    endT = 3.0;
    invuln = 99;
    cues.add(win ? 'win' : 'bad');
    showBanner(win ? 'CONTRACT COMPLETE' : 'CONTRACT FAILED', win ? const Color(0xFF69F0AE) : const Color(0xFFFF5252), dur: 3.0);
  }

  /// Host only. Runs the objective and keeps feeding enemies in.
  void coopContractTick(double dt) {
    final DarkomCoop? cp = coop;
    if (cp == null || phase == 4 || cpResult != 0) return;
    if (waveBreak > 0) {
      waveBreak -= dt;
      return;
    }
    cpClock += dt;
    final String c = cp.args.contract;
    final int count = coopCount;
    switch (c) {
      case 'clear':
        cpProgress = kills;
        if (cpProgress >= cpTarget) this.coopContractEnd(true);
        break;
      case 'hold':
        cpProgress = cpClock.floor();
        if (cpClock >= cpTarget) this.coopContractEnd(true);
        break;
      case 'bounty':
        if (!cpBossSpawned) {
          cpBossSpawned = true;
          final List<Offset> pts = world.clearPts;
          final Offset anchor = this.coopSpawnAnchor();
          Offset? far;
          double fd = -1;
          for (int i = 0; i < 14 && pts.isNotEmpty; i++) {
            final Offset q = pts[rnd.nextInt(pts.length)];
            final double d = (q - anchor).distance;
            if (d > fd) {
              fd = d;
              far = q;
            }
          }
          if (far != null) {
            final DEnemy? b = makeEnemy('bounty', far.dx, far.dy, bounty: true, name: darkomRoamBounties[(cp.args.seed.abs()) % darkomRoamBounties.length]);
            if (b != null) {
              b.hp *= 2.4;
              b.maxHp = b.hp;
              cpBoss = b;
              showBanner('BOUNTY TARGET LOOSE', const Color(0xFFFF1744), dur: 2.2);
            }
          }
        } else if (cpBoss != null && !cpBoss!.alive) {
          cpProgress = 1;
          this.coopContractEnd(true);
        }
        break;
      case 'data':
        for (int i = 0; i < cpNodes.length; i++) {
          if (cpTaken.contains(i)) continue;
          bool got = !heroDead && (cpNodes[i] - heroPos).distance < 48;
          if (!got) {
            for (final DAlly a in cp.allies.values) {
              if (a.alive && (cpNodes[i] - Offset(a.x, a.y)).distance < 48) {
                got = true;
                break;
              }
            }
          }
          if (got) {
            cpTaken.add(i);
            cues.add('good');
            floatText(cpNodes[i].dx, cpNodes[i].dy - 20, 'DATA', const Color(0xFFFFD54F), size: 16);
          }
        }
        cpProgress = cpTaken.length;
        if (cpTarget > 0 && cpProgress >= cpTarget) this.coopContractEnd(true);
        break;
      default:
        break;
    }
    if (cpResult == 0 && c != 'hold' && cpClock >= cpLimit) this.coopContractEnd(false);
    if (cpResult != 0) return;
    cpSpawnT -= dt;
    if (cpSpawnT > 0) return;
    int want;
    switch (c) {
      case 'hold':
        want = 4 + 2 * count + (cpClock ~/ 40) * count;
        break;
      case 'bounty':
        want = 2 + 2 * count;
        break;
      case 'data':
        want = 3 + 2 * count;
        break;
      default:
        want = 4 + 3 * count;
        break;
    }
    final int cap = this.maxEnemiesNow - 2;
    if (want > cap) want = cap;
    cpSpawnT = max(0.5, 1.5 - 0.12 * count);
    if (aliveCount() >= want || enemies.length >= this.maxEnemiesNow) return;
    final Offset? q = ambientSpawnPoint();
    if (q != null) makeEnemy(pickType(), q.dx, q.dy);
  }

  // ---- host: snapshot ------------------------------------------------------

  Map<String, dynamic> coopBuildSnap() {
    final List<List<dynamic>> es = <List<dynamic>>[];
    for (final DEnemy e in enemies) {
      if (!e.alive) continue;
      int flags = 0;
      if (e.bounty) flags |= 1;
      if (e.moving) flags |= 2;
      if (e.enraged) flags |= 4;
      if (e.aggro) flags |= 8;
      final int ti = _kTypes.indexOf(e.type);
      es.add(<dynamic>[
        e.id,
        ti < 0 ? 0 : ti,
        e.x.round(),
        e.y.round(),
        e.hp.round(),
        e.maxHp.round(),
        (e.face * 100).round(),
        flags,
        (e.tele * 100).round(),
        e.tShape,
        e.tR.round(),
        (e.tA * 100).round(),
        (e.tW * 100).round(),
        e.r.round(),
        e.bounty ? e.name : '',
        (e.teleMax * 100).round(),
      ]);
      if (es.length >= 40) break;
    }
    final List<List<num>> ps = <List<num>>[];
    for (final DProj pr in projs) {
      if (!pr.hostile) continue;
      ps.add(<num>[pr.x.round(), pr.y.round(), pr.vx.round(), pr.vy.round(), pr.kind, pr.r.round(), (pr.life * 100).round() / 100]);
      if (ps.length >= 40) break;
    }
    return <String, dynamic>{
      'q': ++coopSeq,
      'w': wave,
      'wa': waveActive ? 1 : 0,
      'k': kills,
      'ck': Map<String, int>.from(coopKills),
      'end': phase == 4 ? 1 : 0,
      'cc': (cpClock * 10).round() / 10,
      'cp': cpProgress,
      'cr': cpResult,
      'dn': cpTaken.toList(),
      'e': es,
      'p': ps,
    };
  }

  // ---- guest: apply snapshot -----------------------------------------------

  void coopApplySnap(Map<String, dynamic> p) {
    if (!this.isGuest) return;
    final dynamic el = p['e'];
    final Map<int, DEnemy> byId = <int, DEnemy>{};
    for (final DEnemy e in enemies) {
      byId[e.id] = e;
    }
    final Set<int> keep = <int>{};
    if (el is List) {
      for (final dynamic row in el) {
        if (row is! List || row.length < 16) continue;
        final int id = _i(row[0]);
        if (coopDead.contains(id)) continue;
        keep.add(id);
        final int ti = _i(row[1]);
        final String type = (ti >= 0 && ti < _kTypes.length) ? _kTypes[ti] : 'shade';
        final double x = _f(row[2]);
        final double y = _f(row[3]);
        DEnemy? e = byId[id];
        if (e == null) {
          e = DEnemy(id, type, x, y, _f(row[4], 10), _f(row[13], 16), 0, 0);
          enemies.add(e);
          byId[id] = e;
        }
        coopTargets[id] = Offset(x, y);
        e.hp = _f(row[4], 1);
        e.maxHp = _f(row[5], 1);
        e.face = _f(row[6]) / 100;
        final int fl = _i(row[7]);
        e.bounty = (fl & 1) != 0;
        e.moving = (fl & 2) != 0;
        e.enraged = (fl & 4) != 0;
        e.aggro = (fl & 8) != 0;
        e.tele = _f(row[8]) / 100;
        e.tShape = _i(row[9]);
        e.tR = _f(row[10]);
        e.tA = _f(row[11]) / 100;
        e.tW = _f(row[12]) / 100;
        e.r = _f(row[13], 16);
        e.name = row[14] is String ? row[14] as String : '';
        e.teleMax = _f(row[15]) / 100;
      }
    }
    enemies.removeWhere((DEnemy e) => e.alive && !keep.contains(e.id));
    coopTargets.removeWhere((int id, Offset o) => !keep.contains(id));
    if (coopDead.length > 300) coopDead.clear();

    // hostile shots are the host's: replace ours with the latest set
    projs.removeWhere((DProj pr) => pr.hostile);
    final dynamic pl = p['p'];
    if (pl is List) {
      for (final dynamic row in pl) {
        if (row is! List || row.length < 7) continue;
        projs.add(DProj(_f(row[0]), _f(row[1]), _f(row[2]), _f(row[3]), 0, _f(row[5], 6), _f(row[6], 1), true, _i(row[4])));
      }
    }

    final int w = _i(p['w']);
    final bool wa = p['wa'] == 1;
    if (w > wave) {
      wave = w;
      showBanner('WAVE $w', theme.neonA, dur: 1.8);
    }
    if (waveActive && !wa) {
      wavesCleared++;
      cues.add('win');
      showBanner('WAVE $wave CLEARED', const Color(0xFF69F0AE), dur: 2.0);
      hp = min(maxHp, hp + 30);
    }
    waveActive = wa;
    final int k = _i(p['k']);
    if (k > kills) kills = k;
    final dynamic ck = p['ck'];
    if (ck is Map) {
      ck.forEach((dynamic key, dynamic v) {
        coopKills[key.toString()] = _i(v);
      });
    }
    cpClock = _f(p['cc'], cpClock);
    cpProgress = _i(p['cp'], cpProgress);
    final dynamic dn = p['dn'];
    if (dn is List) {
      for (final dynamic v in dn) {
        final int idx = _i(v, -1);
        if (idx >= 0 && idx < cpNodes.length && cpTaken.add(idx)) cues.add('good');
      }
    }
    final int cr = _i(p['cr']);
    if (cr != 0 && cpResult == 0) this.coopContractEnd(cr == 1);
    if (p['end'] == 1 && phase != 4 && (coop?.args.contract ?? '').isEmpty) {
      phase = 4;
      endT = 2.0;
      invuln = 99;
      showBanner('CURFEW', const Color(0xFFFFD54F), dur: 2.0);
    }
  }

  /// Guests: slide the mirrored enemies toward where the host says they are.
  void coopGuestEnemies(double dt) {
    final double k = min(1.0, dt * 14);
    for (final DEnemy e in enemies) {
      if (!e.alive) continue;
      if (e.spawnT > 0) e.spawnT -= dt;
      if (e.flash > 0) e.flash -= dt;
      final Offset? t = coopTargets[e.id];
      if (t != null) {
        final double dx = t.dx - e.x;
        final double dy = t.dy - e.y;
        if (dx * dx + dy * dy > 90000) {
          e.x = t.dx;
          e.y = t.dy;
        } else {
          e.x += dx * k;
          e.y += dy * k;
        }
      }
      if (e.tele > 0) {
        e.tele -= dt;
        if (e.tele <= 0) e.tShape = 0;
      }
      if (e.moving) e.phase += dt * 10;
    }
    enemies.removeWhere((DEnemy e) => !e.alive);
  }

  // ---- guest: hits go to the host --------------------------------------------

  bool coopHitRemote(DEnemy e, double dmg, double kx, double ky, double kb, double stun, bool crit) {
    final DarkomCoop? cp = coop;
    if (cp == null || !e.alive || e.spawnT > 0) return false;
    cp.send('hit', <String, dynamic>{
      'id': e.id,
      'd': dmg.round(),
      'kx': kx.round(),
      'ky': ky.round(),
      'kb': kb.round(),
      'st': (stun * 100).round(),
      'c': crit ? 1 : 0,
    });
    e.flash = 0.12;
    floatText(e.x, e.y - e.r - 4, dmg.round().toString(), crit ? const Color(0xFFFFD54F) : Colors.white, size: crit ? 19 : 14);
    spark(e.x, e.y, crit ? const Color(0xFFFFD54F) : const Color(0xFFFFFFFF), n: crit ? 7 : 4, spd: 170);
    cues.add('tap');
    return true;
  }

  // ---- host: a guest hit an enemy ---------------------------------------------

  void coopApplyHit(String from, Map<String, dynamic> p) {
    if (!this.isCoopHost) return;
    final int id = _i(p['id'], -1);
    DEnemy? target;
    for (final DEnemy e in enemies) {
      if (e.id == id) {
        target = e;
        break;
      }
    }
    if (target == null || !target.alive) return;
    final DAlly? a = coop!.allies[from];
    if (a == null || !a.alive) return;
    // a hit has to come from someone who is actually near the enemy
    final double dx = target.x - a.x;
    final double dy = target.y - a.y;
    if (dx * dx + dy * dy > 1100 * 1100) return;
    final double dmg = _f(p['d']).clamp(0.0, 120.0).toDouble();
    if (dmg <= 0) return;
    coopHitter = from;
    this.hurtEnemy(
      target,
      dmg,
      kx: _f(p['kx']),
      ky: _f(p['ky']),
      kb: _f(p['kb']).clamp(0.0, 500.0).toDouble(),
      stun: (_f(p['st']) / 100).clamp(0.0, 2.0).toDouble(),
      crit: p['c'] == 1,
    );
    coopHitter = '';
  }

  /// Host: an enemy died. Tell everyone who got it.
  void coopOnKillHost(DEnemy e) {
    final DarkomCoop? cp = coop;
    if (cp == null || !cp.args.isHost) return;
    final String by = coopHitter.isEmpty ? cp.args.myId : coopHitter;
    coopKills[by] = (coopKills[by] ?? 0) + 1;
    cp.send('kill', <String, dynamic>{'id': e.id, 'by': by});
  }

  void coopApplyKill(Map<String, dynamic> p) {
    if (!this.isGuest) return;
    final int id = _i(p['id'], -1);
    coopDead.add(id);
    for (final DEnemy e in enemies) {
      if (e.id == id) {
        if (e.alive) this.killEnemy(e);
        break;
      }
    }
    enemies.removeWhere((DEnemy e) => !e.alive);
    coopTargets.remove(id);
  }

  // ---- host: damage to allies ------------------------------------------------------

  bool coopHurtAlly(DAlly a, double dmg, double sx, double sy, double kb) {
    final DarkomCoop? cp = coop;
    if (cp == null || !a.alive || a.invuln > 0) return false;
    a.invuln = 0.5;
    a.hp = max(0.0, a.hp - dmg);
    cp.send('hurt', <String, dynamic>{
      'to': a.id,
      'd': dmg.round(),
      'sx': sx.round(),
      'sy': sy.round(),
      'kb': kb.round(),
    });
    return true;
  }

  bool coopProjHitsAlly(DProj p) {
    final DarkomCoop? cp = coop;
    if (cp == null || !cp.args.isHost) return false;
    for (final DAlly a in cp.allies.values) {
      if (!a.alive) continue;
      final double dx = p.x - a.x;
      final double dy = p.y - a.y;
      final double rr = p.r + darkomHeroRadius;
      if (dx * dx + dy * dy < rr * rr) {
        if (this.coopHurtAlly(a, p.dmg, p.x - p.vx * 0.05, p.y - p.vy * 0.05, 120)) return true;
      }
    }
    return false;
  }

  void coopAxeHitsAllies(DAxe ax) {
    final DarkomCoop? cp = coop;
    if (cp == null || !cp.args.isHost) return;
    for (final DAlly a in cp.allies.values) {
      if (!a.alive || ax.hit.contains(1000 + a.slot)) continue;
      final double dx = a.x - ax.x;
      final double dy = a.y - ax.y;
      final double rr = darkomHeroRadius + 16;
      if (dx * dx + dy * dy < rr * rr) {
        ax.hit.add(1000 + a.slot);
        this.coopHurtAlly(a, ax.dmg, ax.x, ax.y, 130);
      }
    }
  }

  /// Guest (and host): the host says an enemy hit us.
  void coopApplyHurt(Map<String, dynamic> p) {
    final double d = _f(p['d']).clamp(0.0, 80.0).toDouble();
    if (d <= 0) return;
    this.hurtHero(d, _f(p['sx']), _f(p['sy']), kb: _f(p['kb'], 150).clamp(0.0, 400.0).toDouble());
  }

  // ---- host: who an enemy goes for ----------------------------------------------------

  void coopAiStep(DEnemy e, double dt) {
    final DarkomCoop? cp = coop;
    if (cp == null) {
      this.aiStep(e, dt);
      return;
    }
    DAlly? best;
    double bd = heroDead ? double.infinity : (e.x - hx) * (e.x - hx) + (e.y - hy) * (e.y - hy);
    for (final DAlly a in cp.allies.values) {
      if (!a.alive) continue;
      final double d = (e.x - a.x) * (e.x - a.x) + (e.y - a.y) * (e.y - a.y);
      if (d < bd) {
        bd = d;
        best = a;
      }
    }
    if (best == null) {
      this.aiStep(e, dt);
      return;
    }
    final double sx = hx;
    final double sy = hy;
    final bool sd = heroDead;
    hx = best.x;
    hy = best.y;
    heroDead = false;
    aiAlly = best;
    try {
      this.aiStep(e, dt);
    } finally {
      hx = sx;
      hy = sy;
      heroDead = sd;
      aiAlly = null;
    }
  }

  // ---- spawning --------------------------------------------------------------------------

  Offset coopSpawnAnchor() {
    final DarkomCoop? cp = coop;
    if (cp == null) return heroPos;
    final List<Offset> pts = <Offset>[];
    if (!heroDead) pts.add(heroPos);
    for (final DAlly a in cp.allies.values) {
      if (a.alive) pts.add(Offset(a.x, a.y));
    }
    if (pts.isEmpty) return heroPos;
    return pts[rnd.nextInt(pts.length)];
  }

  bool coopClearOfAllies(Offset p) {
    final DarkomCoop? cp = coop;
    if (cp == null) return true;
    if (!heroDead && (p - heroPos).distance < 480) return false;
    for (final DAlly a in cp.allies.values) {
      if (a.alive && (p - Offset(a.x, a.y)).distance < 480) return false;
    }
    return true;
  }

  Offset coopRespawnPoint() {
    final DarkomCoop? cp = coop;
    if (cp != null) {
      DAlly? best;
      for (final DAlly a in cp.allies.values) {
        if (a.alive) {
          best = a;
          break;
        }
      }
      if (best != null) return Offset(best.x + 28, best.y);
    }
    return checkpoint;
  }
}
