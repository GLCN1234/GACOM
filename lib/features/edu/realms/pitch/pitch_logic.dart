import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'pitch_skins.dart';

double pcCl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Normalised screen positions the painter and the rules both use.
const double pcGoalY = 0.165;
const double pcGoalLeft = 0.17;
const double pcGoalRight = 0.83;
const double pcWallY = 0.55;
const double pcSpotY = 0.88;

/// Phase of a round.
const int pcAim = 0;
const int pcFlight = 1;
const int pcShow = 2;

/// Set Piece: the goal is split into zones and each zone is labelled with one
/// answer. Putting the ball in the right zone is answering the question, so
/// the shot and the answer are one action. The keeper and the wall decide
/// whether it is also a goal, and never whether the answer was right.
class PitchLogic extends RealmLogic {
  PitchLogic(RealmContent content) : super(content) {
    _nextRound();
  }

  PitchSkin get skin => PitchSkin.equipped();

  static const double shotClock = 13.0;

  int phase = pcAim;
  OdyQuestion? round;

  /// The answer index shown in each goal zone, left to right.
  List<int> zones = <int>[];

  double ballX = 0.5;
  double ballY = pcSpotY;
  double clock = shotClock;

  // The shot in the air.
  double _flightT = 0;
  double _flightLen = 0.9;
  double _fromX = 0.5;
  double _toX = 0.5;
  double _bend = 0;
  double _power = 0;
  double lift = 0;

  // Aiming.
  double aimX = 0;
  double aimY = 0;

  double keeperX = 0.5;
  double _keeperDir = 1;
  double _keeperDive = 0;
  double keeperDiveTo = 0.5;

  /// The wall of defenders, as a span in normalised x.
  double wallFrom = 0.3;
  double wallTo = 0.46;

  int goals = 0;
  int _hearts = 3;
  int blocked = 0;
  double hitFlash = 0;
  double goodFlash = 0;
  String note = '';
  double noteT = 0;

  /// Set for the result card of the shot just taken.
  int lastZone = -1;

  @override
  int get hearts => _hearts;
  @override
  int get maxHearts => 3;

  @override
  String get resultTitle => _hearts <= 0 ? 'FULL TIME' : 'SET PIECES DONE';

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('$goals ${goals == 1 ? 'goal' : 'goals'}', Icons.sports_soccer_rounded, const Color(0xFF69F0AE)),
        RealmChip('${clock.ceil()}s', Icons.timer_rounded, clock < 4 ? const Color(0xFFFF8A80) : skin.accent),
        if (blocked > 0) RealmChip('$blocked blocked', Icons.groups_rounded, Colors.white70),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Goals': '$goals',
        'Right zone': '${stats.correct}',
        'Blocked by the wall': '$blocked',
      };

  @override
  int get finalScore => goals * 60 + stats.correct * 20;

  @override
  int get xp => stats.baseXp + goals * 4;

  /// The zone a point on the goal line falls in, or -1 when it is wide.
  int zoneAt(double x) {
    if (zones.isEmpty) return -1;
    if (x < pcGoalLeft || x > pcGoalRight) return -1;
    final double span = (pcGoalRight - pcGoalLeft) / zones.length;
    final int i = ((x - pcGoalLeft) / span).floor();
    return i < 0 ? 0 : (i >= zones.length ? zones.length - 1 : i);
  }

  /// Middle of zone [i] in normalised x.
  double zoneCentre(int i) {
    final double span = (pcGoalRight - pcGoalLeft) / (zones.isEmpty ? 1 : zones.length);
    return pcGoalLeft + span * (i + 0.5);
  }

  void _nextRound() {
    final OdyQuestion q = content.ask();
    round = q;
    final int n = q.options.length > 4 ? 4 : q.options.length;
    final List<int> idx = List<int>.generate(q.options.length, (int i) => i);
    // Keep the right answer in, then fill the rest of the zones at random.
    idx.remove(q.answerIndex);
    idx.shuffle(rng);
    final List<int> picked = <int>[q.answerIndex];
    for (int i = 0; i < idx.length && picked.length < n; i++) {
      picked.add(idx[i]);
    }
    picked.shuffle(rng);
    zones = picked;
    phase = pcAim;
    clock = shotClock;
    ballX = 0.5;
    ballY = pcSpotY;
    lift = 0;
    aimX = 0;
    aimY = 0;
    lastZone = -1;
    _keeperDive = 0;
    // The wall stands somewhere across the pitch, so a straight shot is not
    // always on and the player has to curve one in.
    final double from = 0.16 + rng.nextDouble() * 0.5;
    wallFrom = from;
    wallTo = from + 0.16;
  }

  // -------------------------------------------------------------- input

  @override
  void setInput(double x, double y) {
    super.setInput(x, y);
    if (over) return;
    if (phase != pcAim) return;
    if (x == 0 && y == 0) {
      // The drag ended. A real pull back and upfield is a shot.
      final double mag = sqrt(aimX * aimX + aimY * aimY);
      if (mag > 0.22 && aimY < -0.08) {
        _shoot(mag);
      } else {
        aimX = 0;
        aimY = 0;
      }
      return;
    }
    aimX = inputX;
    aimY = inputY;
  }

  @override
  void onAction(int id) {
    if (over || phase != pcAim || id != 0) return;
    // A straight shot at the middle, for anyone who would rather tap than drag.
    _shoot(0.6, straight: true);
  }

  @override
  double actionReady(int id) => phase == pcAim ? 1 : 0;

  void _shoot(double mag, {bool straight = false}) {
    _power = pcCl(mag, 0.2, 1.0);
    _fromX = ballX;
    // Drag left to send it left: the aim vector points where the ball goes.
    final double lateral = straight ? 0.0 : aimX * 1.15;
    _toX = pcCl(ballX + lateral, 0.04, 0.96);
    _bend = straight ? 0.0 : aimX * 0.22;
    _flightLen = 1.05 - _power * 0.42;
    _flightT = 0;
    phase = pcFlight;
    cues.add('tap');

    // The keeper commits to the side the ball is heading, but not exactly.
    final double guess = _toX + (rng.nextDouble() - 0.5) * 0.34;
    keeperDiveTo = pcCl(guess, pcGoalLeft, pcGoalRight);
    _keeperDive = 1;
  }

  /// Where the ball is across the pitch at [t] of its flight, including swerve.
  double _xAt(double t) {
    final double straight = _fromX + (_toX - _fromX) * t;
    return straight + sin(t * pi) * _bend;
  }

  void _land() {
    final OdyQuestion? q = round;
    phase = pcShow;
    if (q == null) return;
    final int zone = zoneAt(ballX);
    lastZone = zone;
    if (zone < 0) {
      // Wide. No answer was given, so nothing is recorded as known or not.
      note = 'Wide. Take it again';
      noteT = 1.8;
      cues.add('bad');
      return;
    }
    final int chosen = zones[zone];
    final bool ok = chosen == q.answerIndex;
    stats.record(q, ok, chosen: q.options[chosen]);
    final bool saved = (keeperDiveTo - ballX).abs() < 0.075 && _power < 0.82;
    if (ok && !saved) {
      goals++;
      goodFlash = 0.5;
      note = 'GOAL. ${q.options[chosen]}';
      cues.add('win');
    } else if (ok) {
      goodFlash = 0.35;
      note = 'Right answer, but the keeper got it';
      cues.add('good');
    } else {
      _hearts--;
      hitFlash = 0.55;
      note = 'It was "${q.options[q.answerIndex]}"';
      cues.add('bad');
    }
    noteT = 2.2;
  }

  // -------------------------------------------------------------- frame

  @override
  void step(double dt) {
    if (over) return;
    if (hitFlash > 0) hitFlash -= dt;
    if (goodFlash > 0) goodFlash -= dt;
    if (noteT > 0) noteT -= dt;
    if (_keeperDive > 0) _keeperDive -= dt * 1.6;

    if (phase == pcAim) {
      clock -= dt;
      // The keeper walks the line while the player lines it up.
      keeperX += _keeperDir * 0.14 * dt;
      if (keeperX > pcGoalRight - 0.06) {
        keeperX = pcGoalRight - 0.06;
        _keeperDir = -1;
      } else if (keeperX < pcGoalLeft + 0.06) {
        keeperX = pcGoalLeft + 0.06;
        _keeperDir = 1;
      }
      if (clock <= 0) {
        final OdyQuestion? q = round;
        if (q != null) {
          stats.record(q, false, chosen: 'No shot');
          _hearts--;
          hitFlash = 0.5;
          note = 'Too slow. It was "${q.options[q.answerIndex]}"';
          noteT = 2.2;
          cues.add('bad');
        }
        phase = pcShow;
        noteT = noteT < 1.2 ? 1.2 : noteT;
      }
    } else if (phase == pcFlight) {
      _flightT += dt / _flightLen;
      final double t = pcCl(_flightT, 0.0, 1.0);
      ballX = _xAt(t);
      ballY = pcSpotY + (pcGoalY - pcSpotY) * t;
      // A high shot clears the wall; a low one does not.
      lift = sin(t * pi) * _power;

      final double wallT = (pcSpotY - pcWallY) / (pcSpotY - pcGoalY);
      if (_flightT >= wallT && _flightT - dt / _flightLen < wallT) {
        final double wx = _xAt(wallT);
        if (wx > wallFrom && wx < wallTo && _power < 0.68) {
          blocked++;
          phase = pcAim;
          clock = clock < 2.5 ? 2.5 : clock;
          ballX = 0.5;
          ballY = pcSpotY;
          lift = 0;
          aimX = 0;
          aimY = 0;
          note = 'The wall blocked it. Curve it or hit it harder';
          noteT = 1.8;
          cues.add('bad');
          return;
        }
      }
      if (_flightT >= 1) {
        ballX = _xAt(1);
        ballY = pcGoalY;
        _land();
      }
    } else {
      // Showing the result of the last shot, then straight into the next one.
      if (noteT <= 0.6) {
        if (_hearts <= 0) {
          over = true;
          cues.add('lose');
          return;
        }
        _nextRound();
      }
    }

    // The keeper slides toward where it dived.
    if (_keeperDive > 0) {
      keeperX += (keeperDiveTo - keeperX) * pcCl(dt * 7, 0.0, 1.0);
    }
  }
}
