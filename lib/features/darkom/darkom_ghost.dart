import 'dart:math';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'darkom_story.dart';

/// The recorded behaviour of the player's last Echo duel. The Echo uses it to
/// move and time its attacks the way the player did.
///
/// Stored as one compact string: g1|weapon|x,y;x,y;...|t:k,t:k,...
/// Positions are relative to the arena centre, sampled at 5 Hz. Events are
/// in tenths of a second: kind 0 attack, 1 dash, 2 special.
class DarkomGhost {
  static const String prefsKey = 'darkom_ghost_v1';
  static const int maxSamples = 600;
  static const int maxEvents = 400;
  static const double sampleStep = 0.2;

  final String weapon;
  final List<int> xs;
  final List<int> ys;
  final List<int> evT;
  final List<int> evK;
  const DarkomGhost(this.weapon, this.xs, this.ys, this.evT, this.evK);

  int get length => xs.length;
  double get duration => xs.length * sampleStep;

  /// Where the recorded player stood [t] seconds into the duel (loops).
  Offset posAt(double t) {
    if (xs.isEmpty) return Offset.zero;
    final double d = duration;
    double tt = t;
    if (d > 0) tt = t - (t / d).floorToDouble() * d;
    final double f = tt / sampleStep;
    final int i = f.floor();
    final int i0 = (i < 0 ? 0 : (i >= xs.length ? xs.length - 1 : i));
    final int i1 = (i0 + 1 >= xs.length ? 0 : i0 + 1);
    final double u = f - i;
    final double fu = u < 0 ? 0.0 : (u > 1 ? 1.0 : u);
    return Offset(xs[i0] + (xs[i1] - xs[i0]) * fu, ys[i0] + (ys[i1] - ys[i0]) * fu);
  }

  /// Mean seconds between the player's attacks, between 1.1 and 2.8.
  double get attackGap {
    final List<int> ts = <int>[];
    for (int i = 0; i < evT.length && i < evK.length; i++) {
      if (evK[i] == 0 || evK[i] == 2) ts.add(evT[i]);
    }
    if (ts.length < 3) return 2.0;
    final double span = (ts.last - ts.first) / 10.0;
    final double gap = span / (ts.length - 1);
    return gap < 1.1 ? 1.1 : (gap > 2.8 ? 2.8 : gap);
  }

  /// How often the player dashed, as dashes per 10 seconds.
  double get dashRate {
    int n = 0;
    for (final int k in evK) {
      if (k == 1) n++;
    }
    final double d = duration;
    if (d < 5) return 1.0;
    return n * 10.0 / d;
  }

  /// Event times (seconds) of one kind, in order.
  List<double> eventTimes(int kind) {
    final List<double> out = <double>[];
    for (int i = 0; i < evT.length && i < evK.length; i++) {
      if (evK[i] == kind) out.add(evT[i] / 10.0);
    }
    return out;
  }

  String encode() {
    final StringBuffer b = StringBuffer('g1|$weapon|');
    for (int i = 0; i < xs.length; i++) {
      if (i > 0) b.write(';');
      b.write('${xs[i]},${ys[i]}');
    }
    b.write('|');
    for (int i = 0; i < evT.length; i++) {
      if (i > 0) b.write(',');
      b.write('${evT[i]}:${evK[i]}');
    }
    return b.toString();
  }

  static DarkomGhost? decode(String? s) {
    if (s == null || s.length < 8 || s.length > 60000) return null;
    try {
      final List<String> parts = s.split('|');
      if (parts.length < 4 || parts[0] != 'g1') return null;
      final String w = parts[1];
      if (!darkomWeaponKinds.contains(w)) return null;
      final List<int> xs = <int>[];
      final List<int> ys = <int>[];
      if (parts[2].isNotEmpty) {
        for (final String p in parts[2].split(';')) {
          if (xs.length >= maxSamples) break;
          final List<String> xy = p.split(',');
          if (xy.length != 2) return null;
          final int? x = int.tryParse(xy[0]);
          final int? y = int.tryParse(xy[1]);
          if (x == null || y == null) return null;
          xs.add(x < -3000 ? -3000 : (x > 3000 ? 3000 : x));
          ys.add(y < -3000 ? -3000 : (y > 3000 ? 3000 : y));
        }
      }
      if (xs.length < 10) return null;
      final List<int> et = <int>[];
      final List<int> ek = <int>[];
      if (parts[3].isNotEmpty) {
        for (final String p in parts[3].split(',')) {
          if (et.length >= maxEvents) break;
          final List<String> tk = p.split(':');
          if (tk.length != 2) continue;
          final int? t = int.tryParse(tk[0]);
          final int? k = int.tryParse(tk[1]);
          if (t == null || k == null || t < 0 || t > 5000 || k < 0 || k > 2) continue;
          et.add(t);
          ek.add(k);
        }
      }
      return DarkomGhost(w, xs, ys, et, ek);
    } catch (_) {
      return null;
    }
  }

  static Future<DarkomGhost?> load() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return decode(p.getString(prefsKey));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(DarkomGhost g) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setString(prefsKey, g.encode());
    } catch (_) {}
  }
}

/// Collects the hero's behaviour during an Echo duel.
class DarkomGhostRecorder {
  final List<int> xs = <int>[];
  final List<int> ys = <int>[];
  final List<int> evT = <int>[];
  final List<int> evK = <int>[];
  double _acc = 0;
  double elapsed = 0;

  void sample(double dt, double rx, double ry) {
    elapsed += dt;
    _acc += dt;
    while (_acc >= DarkomGhost.sampleStep) {
      _acc -= DarkomGhost.sampleStep;
      if (xs.length < DarkomGhost.maxSamples) {
        xs.add(rx.round());
        ys.add(ry.round());
      }
    }
  }

  void event(int kind) {
    if (evT.length >= DarkomGhost.maxEvents) return;
    evT.add(min(5000, (elapsed * 10).round()));
    evK.add(kind);
  }

  DarkomGhost? build(String weapon) {
    if (xs.length < 10) return null;
    return DarkomGhost(weapon, List<int>.from(xs), List<int>.from(ys), List<int>.from(evT), List<int>.from(evK));
  }
}
