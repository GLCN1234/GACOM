import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'okada_skins.dart';

double okCl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Road space is this wide. The painter scales it to the screen.
const double okRoadW = 300.0;
const int okLanes = 3;

double okLaneX(int lane) => okRoadW * (lane + 0.5) / okLanes;

/// Which lane a road x sits in.
int okLaneOf(double x) {
  final int l = (x / (okRoadW / okLanes)).floor();
  return l < 0 ? 0 : (l >= okLanes ? okLanes - 1 : l);
}

/// A sign gantry across the road. One sign hangs over each lane and carries
/// one answer. Riding under the right sign is how the question is answered.
class OkGate {
  final double y;
  final OdyQuestion question;

  /// One answer per lane, in lane order.
  final List<String> signs;
  final int correctLane;
  bool passed = false;
  bool wasRight = false;
  OkGate(this.y, this.question, this.signs, this.correctLane);
}

/// Something to dodge: a slow danger car, a pothole or a fuel can to collect.
class OkProp {
  final double y;
  final int lane;

  /// car | pothole | fuel
  final String kind;
  bool used = false;
  OkProp(this.y, this.lane, this.kind);
}

/// Okada Run: an endless ride where the answers hang over the lanes. The
/// player never stops moving and never reads a question panel: steer into the
/// lane whose sign is right and the ride stays fast.
class OkadaLogic extends RealmLogic {
  /// Read live, so a skin bought or equipped mid-session shows at once. The
  /// lookup is cached against the loadout, so this is cheap per frame.
  OkadaSkin get skin => OkadaSkin.equipped();

  OkadaLogic(RealmContent content) : super(content) {
    x = okLaneX(1);
    _spawnAhead();
  }

  static const double gateGap = 1500.0;
  static const double baseSpeed = 230.0;
  static const double maxSpeed = 560.0;
  static const double boostAdd = 210.0;
  static const double boostSeconds = 2.2;

  /// Road position of the rider, and how far the ride has gone.
  double x = okRoadW / 2;
  double dist = 0;
  double speed = baseSpeed;
  double lean = 0;

  int _hearts = 3;
  int right = 0;
  int wrong = 0;
  int fuel = 0;
  double boostLeft = 0;
  double brakeLeft = 0;
  double hitFlash = 0;
  double goodFlash = 0;

  /// The sign text the rider just went under, for the result line.
  String lastLine = '';
  double lastLineT = 0;

  final List<OkGate> gates = <OkGate>[];
  final List<OkProp> props = <OkProp>[];
  double _nextGateY = 900;
  double _nextPropY = 420;

  OkGate? get nextGate {
    for (final OkGate g in gates) {
      if (!g.passed) return g;
    }
    return null;
  }

  OdyQuestion? get q => nextGate?.question;

  @override
  int get hearts => _hearts;
  @override
  int get maxHearts => 3;

  @override
  String get resultTitle => _hearts <= 0 ? 'RIDE OVER' : 'RIDE COMPLETE';

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('${(dist / 10).floor()} m', Icons.straighten_rounded, Colors.white),
        RealmChip('$right right', Icons.check_circle_rounded, const Color(0xFF69F0AE)),
        RealmChip('${speed.round()}', Icons.speed_rounded, skin.accent),
        if (fuel > 0) RealmChip('$fuel fuel', Icons.local_gas_station_rounded, const Color(0xFFFFD54F)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Distance': '${(dist / 10).floor()} m',
        'Right lane': '$right',
        'Wrong lane': '$wrong',
        'Top speed': '${speed.round()}',
      };

  @override
  int get finalScore => (dist / 10).floor() + right * 25;

  @override
  int get xp => stats.baseXp + (dist / 120).floor();

  /// Three signs: the right answer plus two wrong ones, shuffled into lanes.
  void _spawnGate(double y) {
    final OdyQuestion question = content.ask();
    final List<String> wrongs = <String>[];
    for (int i = 0; i < question.options.length; i++) {
      if (i != question.answerIndex) wrongs.add(question.options[i]);
    }
    wrongs.shuffle(rng);
    final List<String> picked = <String>[question.options[question.answerIndex]];
    for (int i = 0; i < wrongs.length && picked.length < okLanes; i++) {
      picked.add(wrongs[i]);
    }
    // A question with too few options still fills every lane.
    while (picked.length < okLanes) {
      picked.add('-');
    }
    final int correctLane = rng.nextInt(okLanes);
    final List<String> signs = List<String>.filled(okLanes, '-');
    signs[correctLane] = picked[0];
    int k = 1;
    for (int lane = 0; lane < okLanes; lane++) {
      if (lane == correctLane) continue;
      signs[lane] = picked[k];
      k++;
    }
    gates.add(OkGate(y, question, signs, correctLane));
  }

  void _spawnAhead() {
    while (_nextGateY < dist + 3200) {
      _spawnGate(_nextGateY);
      _nextGateY += gateGap;
    }
    while (_nextPropY < dist + 3200) {
      // Keep props clear of a gantry so a hazard never blocks the right lane.
      final bool nearGate = gates.any((OkGate g) => (g.y - _nextPropY).abs() < 240);
      if (!nearGate) {
        final double roll = rng.nextDouble();
        final String kind = roll < 0.44 ? 'car' : (roll < 0.76 ? 'pothole' : 'fuel');
        props.add(OkProp(_nextPropY, rng.nextInt(okLanes), kind));
      }
      _nextPropY += 300 + rng.nextDouble() * 260;
    }
  }

  @override
  void onAction(int id) {
    if (over) return;
    if (id == 0) {
      if (fuel <= 0 || boostLeft > 0) return;
      fuel--;
      boostLeft = boostSeconds;
      cues.add('tap');
    } else if (id == 1) {
      brakeLeft = 0.9;
      cues.add('tap');
    }
  }

  @override
  double actionReady(int id) {
    if (id == 0) return fuel > 0 && boostLeft <= 0 ? 1 : 0;
    return brakeLeft > 0 ? 0 : 1;
  }

  @override
  void step(double dt) {
    if (over) return;
    if (boostLeft > 0) boostLeft -= dt;
    if (brakeLeft > 0) brakeLeft -= dt;
    if (hitFlash > 0) hitFlash -= dt;
    if (goodFlash > 0) goodFlash -= dt;
    if (lastLineT > 0) lastLineT -= dt;

    // Speed: creeps up with distance, boost adds, braking and hits take it off.
    final double want = okCl(baseSpeed + dist / 90, baseSpeed, maxSpeed) + (boostLeft > 0 ? boostAdd : 0) - (brakeLeft > 0 ? 120 : 0);
    speed += (want - speed) * okCl(dt * 2.4, 0.0, 1.0);
    speed = okCl(speed, 110, maxSpeed + boostAdd);

    // Steering. One thumb is enough: drag left and right, and the bike leans.
    final double steer = inputX;
    x = okCl(x + steer * 240 * dt, 14, okRoadW - 14);
    lean += (steer - lean) * okCl(dt * 7, 0.0, 1.0);

    final double prev = dist;
    dist += speed * dt;
    _spawnAhead();

    final int lane = okLaneOf(x);

    // Gantries: answered by the lane the rider is in as it goes under.
    for (final OkGate g in gates) {
      if (g.passed || dist < g.y) continue;
      g.passed = true;
      final bool ok = lane == g.correctLane;
      g.wasRight = ok;
      stats.record(g.question, ok, chosen: g.signs[lane]);
      if (ok) {
        right++;
        fuel++;
        goodFlash = 0.5;
        speed += 60;
        lastLine = 'Right lane';
        cues.add('good');
      } else {
        wrong++;
        hitFlash = 0.55;
        speed *= 0.62;
        _hearts--;
        lastLine = 'It was "${g.signs[g.correctLane]}"';
        cues.add('bad');
      }
      lastLineT = 2.2;
    }

    // Props: cars and potholes cost a heart, fuel cans feed the boost. The test
    // is a crossing, not a distance, because at full speed the rider covers
    // more ground in one frame than a prop is wide.
    for (final OkProp p in props) {
      if (p.used) continue;
      if (p.y < prev - 16 || p.y > dist + 16) continue;
      if (p.lane != lane) continue;
      p.used = true;
      if (p.kind == 'fuel') {
        fuel++;
        cues.add('tap');
        continue;
      }
      hitFlash = 0.5;
      speed *= p.kind == 'car' ? 0.55 : 0.72;
      _hearts--;
      cues.add('bad');
    }

    // Keep the lists short so a long ride stays smooth.
    gates.removeWhere((OkGate g) => g.y < dist - 400);
    props.removeWhere((OkProp p) => p.y < dist - 400);

    if (_hearts <= 0) {
      over = true;
      cues.add('lose');
    }
  }
}
