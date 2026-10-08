import 'dart:math';
import 'package:flutter/material.dart';

/// A grid point on the chart. x and y both run from -6 to 6.
class EP {
  final int x;
  final int y;
  const EP(this.x, this.y);

  @override
  bool operator ==(Object other) => other is EP && other.x == x && other.y == y;

  @override
  int get hashCode => (x + 20) * 64 + (y + 20);

  String get label => '($x, $y)';

  double distanceTo(EP o) {
    final double dx = (o.x - x).toDouble();
    final double dy = (o.y - y).toDouble();
    return sqrt(dx * dx + dy * dy);
  }
}

const int emberLo = -6;
const int emberHi = 6;
const int emberCellsPerSide = 12;

/// The fixed nautical chart: reef cells, islands and the home dock.
///
/// A reef cell is the unit square between four grid points. A leg is refused
/// when it passes through the inside of a reef cell. A leg that only runs
/// along the edge of a reef cell, or touches its corner, is allowed.
class EmberChart {
  final List<bool> _reef;
  final List<EP> islands;
  final EP start;

  List<EP>? _nodes;
  List<List<bool>>? _vis;
  final Map<int, List<double>> _from = <int, List<double>>{};

  EmberChart(this._reef, this.islands, this.start);

  static int _idx(int cx, int cy) => (cy - emberLo) * emberCellsPerSide + (cx - emberLo);

  /// True when the cell whose lower left corner is (cx, cy) is a reef.
  bool isReef(int cx, int cy) {
    if (cx < emberLo || cx > emberHi - 1 || cy < emberLo || cy > emberHi - 1) return false;
    return _reef[_idx(cx, cy)];
  }

  List<EP> get reefCells {
    final List<EP> out = <EP>[];
    for (int cy = emberLo; cy < emberHi; cy++) {
      for (int cx = emberLo; cx < emberHi; cx++) {
        if (_reef[_idx(cx, cy)]) out.add(EP(cx, cy));
      }
    }
    return out;
  }

  int get reefCount {
    int n = 0;
    for (final bool b in _reef) {
      if (b) n++;
    }
    return n;
  }

  /// The first reef cell that the leg a to b passes through, or null.
  EP? legReef(EP a, EP b) {
    final int x0 = min(a.x, b.x);
    final int x1 = max(a.x, b.x);
    final int y0 = min(a.y, b.y);
    final int y1 = max(a.y, b.y);
    for (int cx = x0; cx < x1; cx++) {
      for (int cy = y0; cy < y1; cy++) {
        if (!isReef(cx, cy)) continue;
        if (_crosses(a, b, cx, cy)) return EP(cx, cy);
      }
    }
    return null;
  }

  static bool _crosses(EP a, EP b, int cx, int cy) {
    final double ax = a.x.toDouble();
    final double ay = a.y.toDouble();
    final double dx = (b.x - a.x).toDouble();
    final double dy = (b.y - a.y).toDouble();
    double t0 = 0.0;
    double t1 = 1.0;
    final List<double> p = <double>[-dx, dx, -dy, dy];
    final List<double> q = <double>[ax - cx, cx + 1 - ax, ay - cy, cy + 1 - ay];
    for (int i = 0; i < 4; i++) {
      if (p[i] == 0) {
        if (q[i] < 0) return false;
      } else {
        final double t = q[i] / p[i];
        if (p[i] < 0) {
          if (t > t1) return false;
          if (t > t0) t0 = t;
        } else {
          if (t < t0) return false;
          if (t < t1) t1 = t;
        }
      }
    }
    if (t1 - t0 < 1e-9) return false;
    final double tm = (t0 + t1) / 2;
    final double mx = ax + dx * tm;
    final double my = ay + dy * tm;
    const double e = 1e-7;
    return mx > cx + e && mx < cx + 1 - e && my > cy + e && my < cy + 1 - e;
  }

  // ---- shortest sailing distance ----------------------------------------

  void _build() {
    if (_nodes != null) return;
    final Set<EP> seen = <EP>{start, ...islands};
    final List<EP> nodes = <EP>[start, ...islands];
    for (int cy = emberLo; cy < emberHi; cy++) {
      for (int cx = emberLo; cx < emberHi; cx++) {
        if (!_reef[_idx(cx, cy)]) continue;
        for (int ox = 0; ox <= 1; ox++) {
          for (int oy = 0; oy <= 1; oy++) {
            final EP c = EP(cx + ox, cy + oy);
            if (seen.add(c)) nodes.add(c);
          }
        }
      }
    }
    final int n = nodes.length;
    final List<List<bool>> vis = List<List<bool>>.generate(n, (int i) => List<bool>.filled(n, false));
    for (int i = 0; i < n; i++) {
      vis[i][i] = true;
      for (int j = i + 1; j < n; j++) {
        final bool ok = legReef(nodes[i], nodes[j]) == null;
        vis[i][j] = ok;
        vis[j][i] = ok;
      }
    }
    _nodes = nodes;
    _vis = vis;
  }

  List<double> _dijkstra(int s) {
    final List<double>? cached = _from[s];
    if (cached != null) return cached;
    final List<EP> nodes = _nodes!;
    final List<List<bool>> vis = _vis!;
    final int n = nodes.length;
    final List<double> d = List<double>.filled(n, 1e9);
    final List<bool> done = List<bool>.filled(n, false);
    d[s] = 0;
    for (int iter = 0; iter < n; iter++) {
      int u = -1;
      double best = 1e9;
      for (int i = 0; i < n; i++) {
        if (!done[i] && d[i] < best) {
          best = d[i];
          u = i;
        }
      }
      if (u < 0) break;
      done[u] = true;
      for (int v = 0; v < n; v++) {
        if (done[v] || !vis[u][v]) continue;
        final double nd = d[u] + nodes[u].distanceTo(nodes[v]);
        if (nd < d[v]) d[v] = nd;
      }
    }
    _from[s] = d;
    return d;
  }

  /// The length of the shortest legal route from a to b, in chart units.
  /// Routes may bend only at grid points, exactly like the player's routes.
  double dist(EP a, EP b) {
    if (a == b) return 0.0;
    if (legReef(a, b) == null) return a.distanceTo(b);
    _build();
    final List<EP> nodes = _nodes!;
    final List<int> va = <int>[];
    final List<int> vb = <int>[];
    for (int i = 0; i < nodes.length; i++) {
      if (legReef(a, nodes[i]) == null) va.add(i);
      if (legReef(b, nodes[i]) == null) vb.add(i);
    }
    double best = 1e9;
    for (final int i in va) {
      final List<double> d = _dijkstra(i);
      final double ai = a.distanceTo(nodes[i]);
      for (final int j in vb) {
        final double c = ai + d[j] + nodes[j].distanceTo(b);
        if (c < best) best = c;
      }
    }
    if (best > 1e8) {
      // Axis aligned legs never cross a reef, so an L shaped route always works.
      return ((a.x - b.x).abs() + (a.y - b.y).abs()).toDouble();
    }
    return best;
  }

  /// True when every pair of key places (home and the islands) has a legal
  /// route no longer than 130 percent of the straight line.
  bool get valid {
    final List<EP> keys = <EP>[start, ...islands];
    for (int i = 0; i < keys.length; i++) {
      for (int j = i + 1; j < keys.length; j++) {
        final double straight = keys[i].distanceTo(keys[j]);
        if (dist(keys[i], keys[j]) > straight * 1.3 + 1e-9) return false;
      }
    }
    return true;
  }

  // ---- generation --------------------------------------------------------

  static const List<EP> _fallbackIslands = <EP>[EP(4, 3), EP(-4, 3), EP(-3, -4), EP(3, -3), EP(-5, -1)];

  static List<EP>? _placeIslands(Random rng) {
    const List<List<int>> quads = <List<int>>[
      <int>[1, 1],
      <int>[-1, 1],
      <int>[-1, -1],
      <int>[1, -1],
    ];
    final List<int> extra = quads[1 + rng.nextInt(3)];
    final List<List<int>> order = <List<int>>[...quads, extra];
    final List<EP> res = <EP>[];
    for (final List<int> q in order) {
      EP? pick;
      for (int t = 0; t < 80 && pick == null; t++) {
        final EP p = EP(q[0] * (1 + rng.nextInt(5)), q[1] * (1 + rng.nextInt(5)));
        bool ok = max(p.x.abs(), p.y.abs()) >= 2;
        for (final EP r in res) {
          if (max((r.x - p.x).abs(), (r.y - p.y).abs()) < 3) ok = false;
        }
        if (ok) pick = p;
      }
      if (pick == null) return null;
      res.add(pick);
    }
    res.shuffle(rng);
    return res;
  }

  static EmberChart _withReefs(Random rng, List<EP> isl) {
    const EP start = EP(0, 0);
    final List<EP> keys = <EP>[start, ...isl];
    final List<bool> blocked = List<bool>.filled(emberCellsPerSide * emberCellsPerSide, false);
    for (final EP k in keys) {
      for (int ox = -1; ox <= 0; ox++) {
        for (int oy = -1; oy <= 0; oy++) {
          final int cx = k.x + ox;
          final int cy = k.y + oy;
          if (cx >= emberLo && cx <= emberHi - 1 && cy >= emberLo && cy <= emberHi - 1) {
            blocked[_idx(cx, cy)] = true;
          }
        }
      }
    }
    List<bool> cur = List<bool>.filled(emberCellsPerSide * emberCellsPerSide, false);
    int count = 0;
    final int want = 16 + rng.nextInt(9);
    int fails = 0;
    while (count < want && fails < 70) {
      int cx;
      int cy;
      if (rng.nextDouble() < 0.7) {
        final EP a = keys[rng.nextInt(keys.length)];
        final EP b = keys[rng.nextInt(keys.length)];
        if (a == b) {
          fails++;
          continue;
        }
        final double t = 0.25 + 0.5 * rng.nextDouble();
        cx = (a.x + (b.x - a.x) * t).floor().clamp(emberLo, emberHi - 1).toInt();
        cy = (a.y + (b.y - a.y) * t).floor().clamp(emberLo, emberHi - 1).toInt();
      } else {
        cx = emberLo + rng.nextInt(emberCellsPerSide);
        cy = emberLo + rng.nextInt(emberCellsPerSide);
      }
      final int size = 1 + rng.nextInt(3);
      final List<EP> blob = <EP>[EP(cx, cy)];
      for (int s = 1; s < size; s++) {
        final EP from = blob[rng.nextInt(blob.length)];
        final int dir = rng.nextInt(4);
        final int nx = from.x + (dir == 0 ? 1 : (dir == 1 ? -1 : 0));
        final int ny = from.y + (dir == 2 ? 1 : (dir == 3 ? -1 : 0));
        blob.add(EP(nx, ny));
      }
      final List<bool> cand = List<bool>.from(cur);
      int added = 0;
      for (final EP c in blob) {
        if (c.x < emberLo || c.x > emberHi - 1 || c.y < emberLo || c.y > emberHi - 1) continue;
        final int i = _idx(c.x, c.y);
        if (blocked[i] || cand[i]) continue;
        cand[i] = true;
        added++;
      }
      if (added == 0) {
        fails++;
        continue;
      }
      final EmberChart test = EmberChart(cand, isl, start);
      if (test.valid) {
        cur = cand;
        count += added;
      } else {
        fails++;
      }
    }
    return EmberChart(cur, isl, start);
  }

  /// Builds a chart from the run's random source. The result always passes
  /// [valid]: a route within 130 percent of the straight line exists between
  /// any two key places. With no reefs it is trivially valid, which is the
  /// last resort.
  static EmberChart generate(Random rng) {
    for (int attempt = 0; attempt < 8; attempt++) {
      final List<EP>? isl = _placeIslands(rng);
      if (isl == null) continue;
      final EmberChart c = _withReefs(rng, isl);
      if (c.valid) return c;
    }
    return EmberChart(List<bool>.filled(emberCellsPerSide * emberCellsPerSide, false), List<EP>.from(_fallbackIslands), const EP(0, 0));
  }
}

/// What a tap on the chart means.
class EmberTap {
  final EP point;
  final bool onChart;
  const EmberTap(this.point, this.onChart);
}

/// The one place that decides where the chart sits on screen. The painter and
/// the tap handling both call it, so drawing and touch can never disagree.
class EmberLayout {
  final Rect board;
  final double cell;

  /// Screen position of the grid point (-6, 6), the top left corner.
  final Offset origin;

  EmberLayout(this.board, this.cell, this.origin);

  static const double marginL = 20;
  static const double marginB = 18;
  static const double marginT = 8;
  static const double marginR = 10;

  /// Space kept free below the chart for the order strip and the action buttons.
  static const double reserveBottom = 188;

  /// Space kept free above the chart for the chips and the objective bar.
  static const double reserveTop = 140;

  factory EmberLayout.forSize(Size size, double safeTop, double safeBottom) {
    final double top = safeTop + reserveTop;
    final double limit = size.height - safeBottom - reserveBottom;
    final double availH = max(120.0, limit - top);
    final double availW = max(120.0, size.width - 12);
    final double cw = (availW - marginL - marginR) / emberCellsPerSide;
    final double ch = (availH - marginT - marginB) / emberCellsPerSide;
    double cell = min(cw, ch);
    if (cell > 54) cell = 54;
    if (cell < 9) cell = 9;
    final double bw = marginL + marginR + emberCellsPerSide * cell;
    final double bh = marginT + marginB + emberCellsPerSide * cell;
    final double bl = (size.width - bw) / 2;
    return EmberLayout(Rect.fromLTWH(bl, top, bw, bh), cell, Offset(bl + marginL, top + marginT));
  }

  /// Screen position of chart coordinates (x, y). y grows upward.
  Offset pos(num x, num y) => Offset(origin.dx + (x + 6) * cell, origin.dy + (6 - y) * cell);

  Offset posOf(EP p) => pos(p.x.toDouble(), p.y.toDouble());

  Rect get gridRect => Rect.fromLTWH(origin.dx, origin.dy, emberCellsPerSide * cell, emberCellsPerSide * cell);

  /// Maps a screen tap to the nearest grid point. Null when the tap is not
  /// on the chart board at all.
  EmberTap? tap(Offset p) {
    if (!board.inflate(4).contains(p)) return null;
    final double gx = (p.dx - origin.dx) / cell - 6;
    final double gy = 6 - (p.dy - origin.dy) / cell;
    final int rx = gx.round();
    final int ry = gy.round();
    final bool on = rx >= emberLo && rx <= emberHi && ry >= emberLo && ry <= emberHi;
    return EmberTap(EP(rx.clamp(emberLo, emberHi).toInt(), ry.clamp(emberLo, emberHi).toInt()), on);
  }
}
