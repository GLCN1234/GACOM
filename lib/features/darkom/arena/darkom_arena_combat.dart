part of 'darkom_arena_logic.dart';

/// The weapons: applying an attack (mine or a remote player's), hitting the
/// local player, the local player's buttons and the effects they spawn.
extension ArenaCombat on ArenaGame {
  // ---- attacks (mine and theirs share this) -------------------------------

  void _swing(ArenaPlayer o, String kind, double ang, double dur) {
    o.swingKind = kind;
    o.swingAng = ang;
    o.swingT = 0;
    o.swingDur = dur;
    o.aim = ang;
  }

  void _pend(ArenaPlayer o, String id, double t, double ox, double oy, double ang, bool circle, double range, double half, double dmg, double kb, double stun, bool melee) {
    if (identical(o, me)) return;
    if (pend.length > 40) return;
    pend.add(ArPending(o.id, id, t, ox, oy, ang, circle, range, half, dmg, kb, stun, melee));
  }

  void _axe(ArenaPlayer o, String id, double ox, double oy, double ang, double maxDist, double dmg) {
    if (axes.length >= 12) return;
    axes.add(ArAxe(o.id, id, ox, oy, cos(ang), sin(ang), maxDist, dmg));
  }

  void _bolt(ArenaPlayer o, double ox, double oy, double ang, double speed, double life, double dmg, double r, int kind, {double lead = 20, double catchUp = 0}) {
    if (projs.length >= kArMaxProj) return;
    final double off = lead + speed * catchUp;
    projs.add(ArProj(o.id, ox + cos(ang) * off, oy + sin(ang) * off, cos(ang) * speed, sin(ang) * speed, life - catchUp, dmg, r, kind));
  }

  void _applyAttack(ArenaPlayer o, String w, bool sp, String id, double ox, double oy, double an, double dist) {
    final DarkomWeaponDef d = darkomWeapon(w);
    final Color c = arWeaponColor(o.look);
    final bool mine = identical(o, me);
    final double catchUp = mine ? 0 : 0.05;
    final double cs = cos(an);
    final double sn = sin(an);
    switch (w) {
      case 'sword': {
        if (!sp) {
          _swing(o, 'sword', an, 0.28);
          _addFx(ArFx(1, ox, oy, an, d.range, 1.9, 0.22, c, 0.07));
          _pend(o, id, 0.07, ox, oy, an, false, d.range, 1.0, d.dmg, 110, 0, true);
        } else {
          _swing(o, 'sword', an, 0.5);
          _addFx(ArFx(3, ox, oy, 0, 126, 0, 0.14, c, 0.14));
          _addFx(ArFx(0, ox, oy, 0, 126, 0, 0.35, c, 0.14));
          _addFx(ArFx(1, ox, oy, 0, 120, 6.28, 0.3, c, 0.14));
          _pend(o, '$id:a', 0.14, ox, oy, an, true, 126, 0, d.sdmg, 260, 0.25, false);
          _pend(o, '$id:b', 0.3, ox, oy, an, true, 126, 0, d.sdmg * 0.5, 120, 0, false);
        }
        break;
      }
      case 'dagger': {
        if (!sp) {
          _swing(o, 'dagger', an, 0.14);
          _addFx(ArFx(1, ox, oy, an, d.range, 0.5, 0.12, c, 0));
          _pend(o, id, 0.02, ox, oy, an, false, d.range + 10, 0.7, d.dmg, 50, 0, true);
        } else {
          final double lx = ox + cs * dist;
          final double ly = oy + sn * dist;
          _swing(o, 'dagger', an, 0.3);
          _spark(ox, oy, c, n: 8, spd: 140);
          _addFx(ArFx(0, ox, oy, 0, 40, 0, 0.3, const Color(0xFF9C6BFF), 0));
          _addFx(ArFx(3, lx, ly, 0, 46, 0, 0.16, c, 0.16));
          _addFx(ArFx(1, lx, ly, an, 70, 0.6, 0.15, c, 0.16));
          _pend(o, '$id:a', 0.16, lx, ly, an, true, 46, 0, d.sdmg, 120, 0.5, false);
          _pend(o, '$id:b', 0.26, lx, ly, an, true, 46, 0, 10, 30, 0, false);
          _pend(o, '$id:c', 0.36, lx, ly, an, true, 46, 0, 10, 30, 0, false);
        }
        break;
      }
      case 'hammer': {
        if (!sp) {
          final double px = ox + cs * 74;
          final double py = oy + sn * 74;
          _swing(o, 'hammer', an, 0.85);
          _addFx(ArFx(3, px, py, 0, 94, 0, 0.45, c, 0.45));
          _addFx(ArFx(0, px, py, 0, 96, 0, 0.4, c, 0.45));
          _addFx(ArFx(2, px, py, 0, 50, 0, 0.15, const Color(0xFFFFFFFF), 0.45));
          _pend(o, id, 0.45, px, py, an, true, 94, 0, d.dmg, 340, 0.35, false);
        } else {
          _swing(o, 'hammer', an, 0.7);
          _addFx(ArFx(3, ox, oy, 0, 190, 0, 0.4, c, 0.4));
          _addFx(ArFx(0, ox, oy, 0, 190, 0, 0.5, c, 0.4));
          _addFx(ArFx(0, ox, oy, 0, 110, 0, 0.3, const Color(0xFFFFFFFF), 0.4));
          _pend(o, id, 0.4, ox, oy, an, true, 190, 0, d.sdmg, 220, 0.5, false);
        }
        break;
      }
      case 'axe': {
        _swing(o, 'axe', an, sp ? 0.3 : 0.22);
        if (!sp) {
          if (!axes.any((ArAxe a) => a.owner == o.id && !a.dead)) _axe(o, id, ox, oy, an, d.range, d.dmg);
        } else {
          _axe(o, '$id:a', ox, oy, an - 0.4, 240, d.sdmg);
          _axe(o, '$id:b', ox, oy, an, 270, d.sdmg);
          _axe(o, '$id:c', ox, oy, an + 0.4, 240, d.sdmg);
        }
        break;
      }
      case 'staff': {
        if (!sp) {
          _swing(o, 'staff', an, 0.25);
          _bolt(o, ox, oy, an, 560, 0.85, d.dmg, 7, 1, catchUp: catchUp);
          _spark(ox + cs * 24, oy + sn * 24, c, n: 4, spd: 120);
        } else {
          _swing(o, 'staff', an, 0.35);
          _addFx(ArFx(3, ox, oy, 0, 170, 0, 0.1, c, 0.1));
          _addFx(ArFx(0, ox, oy, 0, 170, 0, 0.45, c, 0));
          _addFx(ArFx(2, ox, oy, 0, 60, 0, 0.2, const Color(0xFFFFFFFF), 0));
          _pend(o, id, 0.1, ox, oy, an, true, 170, 0, d.sdmg, 270, 0.3, false);
          for (int i = 0; i < 8; i++) {
            _bolt(o, ox, oy, i * pi / 4, 430, 0.5, 12, 6, 2, catchUp: catchUp);
          }
        }
        break;
      }
      default: {
        if (!sp) {
          _swing(o, 'bash', an, 0.25);
          _addFx(ArFx(1, ox, oy, an, d.range + 6, 1.5, 0.22, c, 0.08));
          _pend(o, id, 0.08, ox, oy, an, false, d.range, 0.9, d.dmg, 380, 1.2, true);
        } else {
          _swing(o, 'bash', an, 0.38);
          _spark(ox, oy, c, n: 8, spd: 140);
          if (!mine) charges.add(ArCharge(o.id, id));
        }
        break;
      }
    }
  }

  // ---- hitting me ---------------------------------------------------------

  bool _inShape(ArPending p) {
    final ArenaPlayer m = me;
    final double dx = m.x - p.ox;
    final double dy = m.y - p.oy;
    final double dist = sqrt(dx * dx + dy * dy);
    if (dist - kArR > p.range + kArAllow) return false;
    if (!p.circle) {
      if (dist > kArR + 18 && arAngDiff(atan2(dy, dx), p.ang) > p.half + kArR / (dist < 1 ? 1 : dist)) return false;
    }
    if (dist > 20 && !map.wallAt(p.ox, p.oy, 0) && !map.lineClear(p.ox, p.oy, m.x, m.y)) return false;
    return true;
  }

  /// Applies damage to the local player if it can land. The attacker's
  /// position (sx, sy) sets the knockback direction and the block arc.
  bool _hitMe(String owner, String id, double dmg, double sx, double sy, double kb, double stun) {
    final ArenaPlayer m = me;
    if (phase != ArPhase.fight || !m.alive) return false;
    if (invuln > 0 || dashT > 0) return false;
    final double ang = atan2(sy - m.y, sx - m.x);
    final bool blk = (guard > 0 || chargeT > 0) && arAngDiff(ang, face) < 1.22;
    double real = blk ? dmg * 0.1 : dmg;
    if (real < 1) real = 1;
    m.hp -= real;
    lastHitBy = owner;
    if (blk) {
      invuln = 0.15;
      kvx -= cos(ang) * 120;
      kvy -= sin(ang) * 120;
      _spark(m.x + cos(face) * 22, m.y + sin(face) * 22, const Color(0xFF80D8FF), n: 6, spd: 180);
      _text(m.x, m.y - 34, 'BLOCK', const Color(0xFF80D8FF), size: 13);
    } else {
      hitFlash = 0.22;
      invuln = 0.1;
      kvx -= cos(ang) * kb;
      kvy -= sin(ang) * kb;
      final double s = stun > kArStunCap ? kArStunCap : stun;
      if (s > stunT) stunT = s;
      if (s > 0.01) {
        flurry = 0;
        slamT = 0;
        guard = 0;
        aimLock = 0;
      }
      shake = 6;
      _text(m.x, m.y - 34, real.round().toString(), const Color(0xFFFF5252), size: 17);
      _spark(m.x, m.y, const Color(0xFFFF5252), n: 6, spd: 170);
    }
    if (m.hp < 0) m.hp = 0;
    _send('hit', <String, dynamic>{'u': myId, 'a': owner, 'id': id, 'd': real.round(), 'hp': m.hp.round(), 'b': blk, 'ts': _now()});
    if (m.hp <= 0) _killMe(owner);
    return true;
  }

  void _killMe(String by) {
    final ArenaPlayer m = me;
    if (!m.alive) return;
    _eliminate(m, by);
    guard = 0;
    flurry = 0;
    slamT = 0;
    chargeT = 0;
    dashT = 0;
    _sendRound(by);
    resendLeft = 3;
    roundResend = 1.0;
    _checkRoundEnd();
  }

  void _sendRound(String by) {
    _send('round', <String, dynamic>{'u': myId, 'r': round, 'loser': myId, 'by': by, 'ts': _now()});
  }

  // ---- my actions ---------------------------------------------------------

  void setInput(double x, double y) {
    inX = x;
    inY = y;
  }

  ArenaPlayer? _nearestFoe(double range) {
    ArenaPlayer? best;
    double bd = 1e18;
    for (final ArenaPlayer p in roster) {
      if (identical(p, me) || !p.alive) continue;
      final double dx = p.x - me.x;
      final double dy = p.y - me.y;
      final double dd = sqrt(dx * dx + dy * dy);
      if (dd - kArR > range) continue;
      if (dd < bd) {
        bd = dd;
        best = p;
      }
    }
    return best;
  }

  double _aimAt(double range) {
    final ArenaPlayer? t = _nearestFoe(range);
    if (t == null) return face;
    return atan2(t.y - me.y, t.x - me.x);
  }

  String _newId() => '${myId.length > 6 ? myId.substring(0, 6) : myId}${(_seq++).toRadixString(36)}';

  void _emit(String k, double an, {double dist = 0}) {
    final ArenaPlayer m = me;
    final String id = _newId();
    _applyAttack(m, m.weapon, k == 's', id, m.x, m.y, an, dist);
    _send('atk', <String, dynamic>{
      'u': myId,
      'id': id,
      'k': k,
      'w': m.weapon,
      'x': _r1(m.x),
      'y': _r1(m.y),
      'an': (an * 100).roundToDouble() / 100,
      'd': dist.round(),
      'rd': round,
      'ts': _now(),
    });
  }

  void _beginSwingLocal(double a, double dur) {
    face = a;
    aimLock = dur + 0.12;
  }

  bool _hasMyAxe() => axes.any((ArAxe a) => a.owner == myId && !a.dead);

  void pressAttack() {
    if (!canAct) return;
    final String w = me.weapon;
    final DarkomWeaponDef d = darkomWeapon(w);
    switch (w) {
      case 'sword': {
        if (atkCd > 0) return;
        final double a = _aimAt(d.auto);
        _beginSwingLocal(a, 0.28);
        atkCd = d.cd;
        atkCdMax = d.cd;
        kvx += cos(a) * 150;
        kvy += sin(a) * 150;
        _emit('a', a);
        break;
      }
      case 'dagger': {
        if (flurry <= 0 && atkCd > 0) return;
        if (flurry <= 0) flurryT = 0;
        flurry = min(6, flurry + 3);
        break;
      }
      case 'hammer': {
        if (atkCd > 0 || slamT > 0) return;
        final double a = _aimAt(d.auto);
        _beginSwingLocal(a, 0.85);
        slamT = 0.45;
        atkCd = d.cd;
        atkCdMax = d.cd;
        _emit('a', a);
        break;
      }
      case 'axe': {
        if (atkCd > 0 || _hasMyAxe()) return;
        final double a = _aimAt(d.auto);
        _beginSwingLocal(a, 0.22);
        atkCd = 0.2;
        atkCdMax = 0.2;
        _emit('a', a);
        break;
      }
      case 'staff': {
        if (atkCd > 0) return;
        if (mana < 13) {
          if (noManaT <= 0) {
            _text(me.x, me.y - 34, 'No mana', const Color(0xFF80D8FF), size: 13);
            noManaT = 0.8;
          }
          return;
        }
        mana -= 13;
        manaPause = 0.5;
        final double a = _aimAt(d.auto);
        _beginSwingLocal(a, 0.25);
        atkCd = d.cd;
        atkCdMax = d.cd;
        _emit('a', a);
        break;
      }
      default: {
        if (guard > 0 && guardAge >= 0.06) {
          final double a = _aimAt(d.auto);
          _beginSwingLocal(a, 0.25);
          guard = 0;
          atkCd = 0.75;
          atkCdMax = 0.75;
          kvx += cos(a) * 240;
          kvy += sin(a) * 240;
          _emit('a', a);
        } else if (guard <= 0 && atkCd <= 0) {
          final double a = _aimAt(d.auto);
          face = a;
          aimLock = 0.3;
          guard = 0.6;
          guardAge = 0;
          _addFx(ArFx(0, me.x + cos(a) * 20, me.y + sin(a) * 20, 0, 34, 0, 0.25, const Color(0xFF80D8FF), 0));
        }
        break;
      }
    }
  }

  void _daggerStab() {
    final DarkomWeaponDef d = darkomWeapon('dagger');
    final double a = _aimAt(d.auto);
    _beginSwingLocal(a, 0.14);
    kvx += cos(a) * 170;
    kvy += sin(a) * 170;
    _emit('a', a);
  }

  void pressSpecial() {
    if (!canAct || specCd > 0) return;
    final String w = me.weapon;
    final DarkomWeaponDef d = darkomWeapon(w);
    switch (w) {
      case 'sword': {
        specCd = d.scd;
        specCdMax = d.scd;
        aimLock = 0.5;
        _emit('s', face);
        break;
      }
      case 'dagger': {
        final ArenaPlayer? t = _nearestFoe(330);
        double a = face;
        double travel = 200;
        if (t != null) {
          a = atan2(t.y - me.y, t.x - me.x);
          final double dd = sqrt((t.x - me.x) * (t.x - me.x) + (t.y - me.y) * (t.y - me.y));
          travel = max(0.0, dd - kArR - 20);
          specCd = d.scd;
          specCdMax = d.scd;
        } else {
          specCd = 2.5;
          specCdMax = 2.5;
        }
        face = a;
        aimLock = 0.4;
        dashT = 0.14;
        dashVx = cos(a) * travel / 0.14;
        dashVy = sin(a) * travel / 0.14;
        invuln = max(invuln, 0.3);
        _emit('s', a, dist: travel);
        break;
      }
      case 'hammer': {
        specCd = d.scd;
        specCdMax = d.scd;
        slamT = 0.4;
        aimLock = 0.6;
        _emit('s', face);
        break;
      }
      case 'axe': {
        specCd = d.scd;
        specCdMax = d.scd;
        final double a = _aimAt(d.auto);
        face = a;
        _emit('s', a);
        break;
      }
      case 'staff': {
        if (mana < 30) {
          if (noManaT <= 0) {
            _text(me.x, me.y - 34, 'Need 30 mana', const Color(0xFF80D8FF), size: 13);
            noManaT = 0.8;
          }
          return;
        }
        mana -= 30;
        manaPause = 0.8;
        specCd = d.scd;
        specCdMax = d.scd;
        _emit('s', face);
        break;
      }
      default: {
        specCd = d.scd;
        specCdMax = d.scd;
        final double a = _aimAt(d.auto);
        face = a;
        aimLock = 0.6;
        chargeT = 0.38;
        chargeVx = cos(a) * 620;
        chargeVy = sin(a) * 620;
        guard = 0;
        invuln = max(invuln, 0.12);
        _emit('s', a);
        break;
      }
    }
  }

  void pressDash() {
    if (!canAct || dashCd > 0) return;
    double dx = inX;
    double dy = inY;
    final double m = sqrt(dx * dx + dy * dy);
    if (m < 0.2) {
      dx = cos(face);
      dy = sin(face);
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
    face = atan2(dy, dx);
    _spark(me.x, me.y, const Color(0xFF00E5FF), n: 8, spd: 100);
    _addFx(ArFx(0, me.x, me.y, 0, 34, 0, 0.25, const Color(0xFF00E5FF), 0));
  }

  // ---- effects ------------------------------------------------------------

  void _addFx(ArFx f) {
    if (fx.length >= kArMaxFx) fx.removeAt(0);
    fx.add(f);
  }

  void _spark(double x, double y, Color c, {int n = 6, double spd = 150, double life = 0.4, double size = 2.2}) {
    for (int i = 0; i < n; i++) {
      if (parts.length >= kArMaxParts) break;
      final double a = _rnd.nextDouble() * 2 * pi;
      final double s = spd * (0.4 + _rnd.nextDouble() * 0.6);
      parts.add(ArPart(x, y, cos(a) * s, sin(a) * s, life * (0.6 + _rnd.nextDouble() * 0.4), size, c));
    }
  }

  void _burst(double x, double y, Color c) {
    _spark(x, y, c, n: 14, spd: 220, life: 0.55);
    _spark(x, y, const Color(0xFFFFFFFF), n: 4, spd: 120, size: 2.6);
    _addFx(ArFx(0, x, y, 0, 60, 0, 0.4, c, 0));
    _addFx(ArFx(2, x, y, 0, 36, 0, 0.18, c, 0));
    shake = max(shake, 8.0);
  }

  void _text(double x, double y, String s, Color c, {double size = 14}) {
    if (texts.length >= kArMaxTexts) texts.removeAt(0);
    texts.add(ArText(x, y, s, 0.8, c, size));
  }

}
