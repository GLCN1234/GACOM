import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'current_skins.dart';

double wcCl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// A word drifting down the river. Swimming into it is how it is chosen.
class WcTile {
  double x;
  double y;
  final int index;
  final String text;
  bool gone = false;
  double pop = 0;
  WcTile(this.x, this.y, this.index, this.text);
}

/// A log or drum in the water. Hitting one costs a heart.
class WcDebris {
  double x;
  double y;
  final double spin;
  final bool drum;
  WcDebris(this.x, this.y, this.spin, this.drum);
}

/// Word Current: the sentence sits on the bank and its possible words come
/// down the river. You swim into the one that fits. Nothing is tapped and no
/// panel opens, so the reading and the swimming are the same action.
class CurrentLogic extends RealmLogic {
  CurrentLogic(RealmContent content) : super(content) {
    _nextRound();
  }

  CurrentSkin get skin => CurrentSkin.equipped();

  static const double swimTop = 0.52;
  static const double swimBottom = 0.92;
  static const double diveSeconds = 0.9;
  static const double sprintSeconds = 1.4;

  double x = 0.5;
  double y = 0.78;
  double bob = 0;

  int _hearts = 3;
  int right = 0;
  int missed = 0;
  double flow = 0.18;
  double diveLeft = 0;
  double sprintLeft = 0;
  double sprintCool = 0;
  double hitFlash = 0;
  double goodFlash = 0;

  OdyQuestion? round;
  final List<WcTile> tiles = <WcTile>[];
  final List<WcDebris> debris = <WcDebris>[];
  bool _roundDone = false;
  double _nextDebris = 1.4;
  String note = '';
  double noteT = 0;

  bool get diving => diveLeft > 0;

  @override
  int get hearts => _hearts;
  @override
  int get maxHearts => 3;

  @override
  String get resultTitle => _hearts <= 0 ? 'SWEPT AWAY' : 'SWIM COMPLETE';

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('$right caught', Icons.check_circle_rounded, const Color(0xFF69F0AE)),
        if (missed > 0) RealmChip('$missed missed', Icons.water_drop_rounded, const Color(0xFFFF8A80)),
        RealmChip('${(flow * 100).round()} flow', Icons.waves_rounded, skin.accent),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Words caught': '$right',
        'Words missed': '$missed',
        'Fastest flow': '${(flow * 100).round()}',
      };

  @override
  int get finalScore => right * 45 + (time * 2).floor();

  @override
  int get xp => stats.baseXp + right * 2;

  /// English first, and any subject when the player picked a mix.
  String get _subjectId {
    if (content.subjectIds.contains('english')) return 'english';
    return content.randomSubject();
  }

  void _nextRound() {
    final OdyQuestion q = content.ask(_subjectId);
    round = q;
    _roundDone = false;
    tiles.clear();
    final List<int> order = List<int>.generate(q.options.length, (int i) => i);
    order.shuffle(rng);
    // Spread the words across the river and stagger them down the current, so
    // every one of them can be reached.
    for (int slot = 0; slot < order.length; slot++) {
      final int idx = order[slot];
      final double lanes = order.length.toDouble();
      final double lx = (slot + 0.5) / lanes;
      final double jitter = (rng.nextDouble() - 0.5) * (0.6 / lanes);
      tiles.add(WcTile(wcCl(lx + jitter, 0.12, 0.88), -0.14 - slot * 0.16, idx, q.options[idx]));
    }
  }

  @override
  void onAction(int id) {
    if (over) return;
    if (id == 0) {
      if (sprintCool > 0 || sprintLeft > 0) return;
      sprintLeft = sprintSeconds;
      sprintCool = 4.0;
      cues.add('tap');
    } else if (id == 1) {
      if (diveLeft > 0) return;
      diveLeft = diveSeconds;
      cues.add('tap');
    }
  }

  @override
  double actionReady(int id) {
    if (id == 0) return sprintCool > 0 ? wcCl(1 - sprintCool / 4.0, 0.0, 1.0) : 1;
    return diveLeft > 0 ? wcCl(1 - diveLeft / diveSeconds, 0.0, 1.0) : 1;
  }

  void _answer(WcTile t) {
    final OdyQuestion? q = round;
    if (q == null || _roundDone) return;
    _roundDone = true;
    t.gone = true;
    t.pop = 0.4;
    final bool ok = t.index == q.answerIndex;
    stats.record(q, ok, chosen: t.text);
    if (ok) {
      right++;
      goodFlash = 0.4;
      note = 'Caught it';
      cues.add('good');
    } else {
      _hearts--;
      hitFlash = 0.5;
      note = 'It was "${q.options[q.answerIndex]}"';
      cues.add('bad');
    }
    noteT = 1.9;
  }

  @override
  void step(double dt) {
    if (over) return;
    if (diveLeft > 0) diveLeft -= dt;
    if (sprintLeft > 0) sprintLeft -= dt;
    if (sprintCool > 0) sprintCool -= dt;
    if (hitFlash > 0) hitFlash -= dt;
    if (goodFlash > 0) goodFlash -= dt;
    if (noteT > 0) noteT -= dt;

    // The river speeds up slowly, which is the only pressure in the game.
    flow = wcCl(0.18 + time / 150, 0.18, 0.46);
    bob += dt * 6;

    final double speed = (sprintLeft > 0 ? 0.62 : 0.40) * (diving ? 0.8 : 1.0);
    x = wcCl(x + inputX * speed * dt, 0.06, 0.94);
    y = wcCl(y + inputY * speed * 0.8 * dt, swimTop, swimBottom);

    // Words come down with the current.
    for (final WcTile t in tiles) {
      if (t.pop > 0) t.pop -= dt;
      if (t.gone) continue;
      // Once a round is answered the rest of its words rush away, so the next
      // sentence comes quickly instead of leaving the player waiting.
      t.y += flow * (_roundDone ? 3.2 : 1.0) * dt;
      t.x += sin(time * 1.3 + t.index) * 0.012 * dt;
      if (!diving && !_roundDone) {
        final double dx = (t.x - x).abs();
        final double dy = (t.y - y).abs();
        if (dx < 0.11 && dy < 0.055) _answer(t);
      }
    }

    // A round ends when it is answered, or when every word has floated past.
    if (!_roundDone && tiles.every((WcTile t) => t.y > 1.08)) {
      final OdyQuestion? q = round;
      if (q != null) {
        _roundDone = true;
        missed++;
        stats.record(q, false, chosen: 'Missed');
        note = 'Missed. It was "${q.options[q.answerIndex]}"';
        noteT = 1.9;
        cues.add('bad');
      }
    }
    if (_roundDone && tiles.every((WcTile t) => t.y > 1.12 || t.gone)) _nextRound();

    // Debris in the water.
    _nextDebris -= dt;
    if (_nextDebris <= 0) {
      debris.add(WcDebris(0.08 + rng.nextDouble() * 0.84, -0.12, (rng.nextDouble() - 0.5) * 2, rng.nextDouble() < 0.4));
      _nextDebris = wcCl(2.2 - time / 90, 0.8, 2.2);
    }
    for (final WcDebris d in debris) {
      d.y += flow * 1.15 * dt;
      if (diving) continue;
      if ((d.x - x).abs() < 0.085 && (d.y - y).abs() < 0.05) {
        d.y = 2;
        _hearts--;
        hitFlash = 0.5;
        note = 'Watch the logs';
        noteT = 1.4;
        cues.add('bad');
      }
    }
    debris.removeWhere((WcDebris d) => d.y > 1.2);
    tiles.removeWhere((WcTile t) => t.y > 1.3 && t.pop <= 0);

    if (_hearts <= 0) {
      over = true;
      cues.add('lose');
    }
  }
}
