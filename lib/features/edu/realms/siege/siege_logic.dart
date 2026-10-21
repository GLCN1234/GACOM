import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'siege_skins.dart';

double sgCl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Where the gate stands, in normalised screen height.
const double sgGateY = 0.855;

/// The divisors the player fights with. Every marcher's number is built from
/// these, so every marcher can always be brought down.
const List<int> sgDivisors = <int>[2, 3, 5, 7];

/// One attacker. [value] is the number it carries; dividing it exactly is how
/// you cut it down, and a marcher falls when its number reaches 1.
class SgMarcher {
  double x;
  double y;
  int value;
  final int startValue;
  double speed;
  double hitT = 0;
  double dieT = 0;
  bool dead = false;
  int shownStep = 0;
  SgMarcher(this.x, this.y, this.value, this.speed) : startValue = value;
}

/// A weapon: one divisor, with a cooldown after a wrong swing.
class SgWeapon {
  final int k;
  double coolLeft = 0;
  SgWeapon(this.k);
}

/// Gate Siege: the marchers carry numbers and your weapons are operations.
/// There is no question panel. Choosing a divisor that goes into the number is
/// the whole fight, which is how the maths does the work instead of gating it.
class SiegeLogic extends RealmLogic {
  SiegeLogic(RealmContent content) : super(content) {
    _startWave();
  }

  SiegeSkin get skin => SiegeSkin.equipped();

  static const int gateMax = 5;
  static const double wrongCooldown = 1.6;

  final List<SgMarcher> marchers = <SgMarcher>[];
  final List<SgWeapon> weapons = <SgWeapon>[for (final int k in sgDivisors) SgWeapon(k)];

  /// Index into [weapons], or -1 when nothing is armed.
  int armed = -1;

  int gate = gateMax;
  int wave = 0;
  int felled = 0;
  int cuts = 0;
  int misses = 0;
  double hitFlash = 0;
  double goodFlash = 0;
  double _spawnLeft = 0;
  int _toSpawn = 0;
  double _waveRest = 0;

  String note = '';
  double noteT = 0;

  @override
  int get hearts => gate;
  @override
  int get maxHearts => gateMax;

  @override
  String get resultTitle => gate <= 0 ? 'THE GATE FELL' : 'GATE HELD';

  @override
  bool get modal => false;

  @override
  String? get objectiveText => armed < 0
      ? 'Pick a weapon below, then tap a marcher it divides'
      : 'Armed with divide by ${weapons[armed].k}. Tap a marcher whose number it goes into';

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Wave ${wave < 1 ? 1 : wave}', Icons.flag_rounded, skin.accent),
        RealmChip('$felled felled', Icons.shield_rounded, const Color(0xFF69F0AE)),
        if (misses > 0) RealmChip('$misses missed', Icons.close_rounded, const Color(0xFFFF8A80)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Waves held': '${wave < 1 ? 0 : wave - (gate <= 0 ? 1 : 0)}',
        'Marchers felled': '$felled',
        'Clean cuts': '$cuts',
        'Wrong swings': '$misses',
      };

  @override
  int get finalScore => felled * 40 + cuts * 10 + (wave * 25);

  @override
  int get xp => stats.baseXp + felled * 3;

  // -------------------------------------------------------------- waves

  void _startWave() {
    wave++;
    _toSpawn = 2 + wave;
    if (_toSpawn > 9) _toSpawn = 9;
    _spawnLeft = 0;
    _waveRest = 0;
  }

  /// A number built only from the divisors on the player's belt, so it can
  /// always be taken apart. Later waves use more factors.
  int _makeValue() {
    final int factors = wave <= 1 ? 1 : (wave <= 3 ? 2 : (rng.nextDouble() < 0.35 ? 2 : 3));
    int v = 1;
    for (int i = 0; i < factors; i++) {
      v *= sgDivisors[rng.nextInt(sgDivisors.length)];
    }
    if (v == 1) v = sgDivisors[rng.nextInt(sgDivisors.length)];
    return v;
  }

  void _spawnOne() {
    final double lane = (rng.nextInt(4) + 0.5) / 4.0;
    final double jitter = (rng.nextDouble() - 0.5) * 0.06;
    // Screen heights per second: a first-wave marcher takes about 28 seconds to
    // reach the gate, a late one about half that.
    final double speed = 0.030 + wave * 0.0035 + rng.nextDouble() * 0.010;
    marchers.add(SgMarcher(sgCl(lane + jitter, 0.08, 0.92), -0.06 - rng.nextDouble() * 0.12, _makeValue(), speed));
  }

  // -------------------------------------------------------------- input

  @override
  void onAction(int id) {
    if (over) return;
    if (id >= 0 && id < weapons.length) {
      armed = armed == id ? -1 : id;
      cues.add('tap');
    }
  }

  @override
  double actionReady(int id) {
    if (id < 0 || id >= weapons.length) return 1;
    final SgWeapon w = weapons[id];
    if (w.coolLeft <= 0) return 1;
    return sgCl(1 - w.coolLeft / wrongCooldown, 0.0, 1.0);
  }

  /// Arm a weapon from the bar in the HUD.
  void arm(int index) {
    if (over || index < 0 || index >= weapons.length) return;
    armed = armed == index ? -1 : index;
    cues.add('tap');
  }

  @override
  void onTap(Offset point, Size size) {
    if (over || size.width <= 0 || size.height <= 0) return;
    if (armed < 0) {
      note = 'Pick a weapon first';
      noteT = 1.6;
      return;
    }
    final SgWeapon w = weapons[armed];
    if (w.coolLeft > 0) {
      note = 'That weapon is still cooling';
      noteT = 1.4;
      return;
    }
    final double r = size.width * 0.085;
    SgMarcher? best;
    double bestD = r;
    for (final SgMarcher m in marchers) {
      if (m.dead || m.dieT > 0) continue;
      final double dx = m.x * size.width - point.dx;
      final double dy = m.y * size.height - point.dy;
      final double d = sqrt(dx * dx + dy * dy);
      if (d <= bestD) {
        bestD = d;
        best = m;
      }
    }
    if (best == null) return;
    _swing(best, w);
  }

  void _swing(SgMarcher m, SgWeapon w) {
    final bool ok = m.value % w.k == 0;
    stats.recordTask(
      'math',
      ok,
      prompt: 'Does ${w.k} divide ${m.value}?',
      chosen: 'divide by ${w.k}',
      answer: ok ? 'yes' : 'no, ${w.k} does not go into ${m.value}',
    );
    if (!ok) {
      misses++;
      w.coolLeft = wrongCooldown;
      m.speed *= 1.22;
      m.hitT = 0.35;
      hitFlash = 0.45;
      note = '${w.k} does not go into ${m.value}';
      noteT = 1.8;
      cues.add('bad');
      return;
    }
    cuts++;
    m.shownStep = m.value;
    m.value = m.value ~/ w.k;
    m.hitT = 0.3;
    goodFlash = 0.35;
    cues.add('good');
    if (m.value <= 1) {
      m.dieT = 0.42;
      felled++;
      note = 'Down. ${m.startValue} came apart';
      noteT = 1.5;
    } else {
      note = '${m.shownStep} ÷ ${w.k} = ${m.value}';
      noteT = 1.6;
    }
  }

  // -------------------------------------------------------------- frame

  @override
  void step(double dt) {
    if (over) return;
    if (hitFlash > 0) hitFlash -= dt;
    if (goodFlash > 0) goodFlash -= dt;
    if (noteT > 0) noteT -= dt;
    for (final SgWeapon w in weapons) {
      if (w.coolLeft > 0) w.coolLeft -= dt;
    }

    for (final SgMarcher m in marchers) {
      if (m.hitT > 0) m.hitT -= dt;
      if (m.dieT > 0) {
        m.dieT -= dt;
        if (m.dieT <= 0) m.dead = true;
        continue;
      }
      if (m.dead) continue;
      m.y += m.speed * dt;
      if (m.y >= sgGateY) {
        m.dead = true;
        gate--;
        hitFlash = 0.5;
        note = '${m.value} got through';
        noteT = 1.6;
        cues.add('bad');
      }
    }
    marchers.removeWhere((SgMarcher m) => m.dead);

    // Spawning, then a short rest between waves.
    if (_toSpawn > 0) {
      _spawnLeft -= dt;
      if (_spawnLeft <= 0) {
        _spawnOne();
        _toSpawn--;
        _spawnLeft = sgCl(1.5 - wave * 0.06, 0.45, 1.5);
      }
    } else if (marchers.isEmpty) {
      _waveRest -= dt;
      if (_waveRest <= 0) {
        if (gate < gateMax && wave % 3 == 0) gate++;
        _startWave();
        note = 'Wave $wave';
        noteT = 1.6;
      }
    }

    if (gate <= 0) {
      gate = 0;
      over = true;
      cues.add('lose');
    }
  }
}
