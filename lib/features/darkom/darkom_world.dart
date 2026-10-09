import 'dart:math';
import 'dart:ui';

/// One drawn block of the city. Tile coordinates.
class DBlock {
  final int tx;
  final int ty;
  final int tw;
  final int th;

  /// 0 building, 1 container or crate, 2 server rack, 3 pillar, 4 monument
  final int style;
  final int seed;

  /// Which edge carries a neon sign: 0 top, 1 right, 2 bottom, 3 left, -1 none.
  final int sign;
  final int colorIdx;
  const DBlock(this.tx, this.ty, this.tw, this.th, this.style, this.seed, this.sign, this.colorIdx);
}

class _Seg {
  final List<List<int>> roads = <List<int>>[];
  final List<List<int>> blocks = <List<int>>[];
}

/// A procedurally laid out district: roads, solid blocks, cover and water.
/// All randomness comes from the seed, so a district looks the same for the
/// same seed. Cells: 0 free, 1 building or wall, 2 cover, 3 water.
class DarkomWorld {
  static const int tile = 60;
  static const int cols = 40;
  static const int rows = 30;
  static const double width = 2400;
  static const double height = 1800;

  final String district;
  final List<int> cells;
  final List<DBlock> blocks;
  final List<List<int>> vRoads;
  final List<List<int>> hRoads;
  final int waterRow;
  final List<Offset> clearPts;
  final Offset extract;
  final Offset arena;
  final double arenaRadius;
  final Rect arenaRect;

  // Flow field toward a target tile (used by enemies and the courier).
  final List<int> flow = List<int>.filled(cols * rows, -1);
  final List<int> _queue = List<int>.filled(cols * rows, 0);
  int _flowTile = -1;

  DarkomWorld._(this.district, this.cells, this.blocks, this.vRoads, this.hRoads, this.waterRow, this.clearPts, this.extract, this.arena, this.arenaRadius, this.arenaRect);

  // ---- queries -------------------------------------------------------------

  int cellAt(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= cols || ty >= rows) return 1;
    return cells[ty * cols + tx];
  }

  bool solidTile(int tx, int ty) => cellAt(tx, ty) != 0;

  /// True when a point is inside something walkers can not enter.
  bool solidAt(double x, double y) => solidTile((x / tile).floor(), (y / tile).floor());

  /// Projectiles fly over water but stop at walls and cover.
  bool wallAt(double x, double y) {
    final int c = cellAt((x / tile).floor(), (y / tile).floor());
    return c == 1 || c == 2;
  }

  static double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

  bool circleHits(double x, double y, double r) {
    final int x0 = ((x - r) / tile).floor();
    final int x1 = ((x + r) / tile).floor();
    final int y0 = ((y - r) / tile).floor();
    final int y1 = ((y + r) / tile).floor();
    for (int ty = y0; ty <= y1; ty++) {
      for (int tx = x0; tx <= x1; tx++) {
        if (!solidTile(tx, ty)) continue;
        final double nx = _cl(x, tx * tile.toDouble(), (tx + 1) * tile.toDouble());
        final double ny = _cl(y, ty * tile.toDouble(), (ty + 1) * tile.toDouble());
        final double dx = x - nx;
        final double dy = y - ny;
        if (dx * dx + dy * dy < r * r) return true;
      }
    }
    return false;
  }

  /// Moves a circle by (dx, dy), sliding along walls. Returns the new centre.
  Offset move(double x, double y, double dx, double dy, double r) {
    final double len = sqrt(dx * dx + dy * dy);
    final int steps = len > 16 ? (len / 16).ceil() : 1;
    final double sx = dx / steps;
    final double sy = dy / steps;
    double px = x;
    double py = y;
    for (int i = 0; i < steps; i++) {
      if (!circleHits(px + sx, py, r)) px += sx;
      if (!circleHits(px, py + sy, r)) py += sy;
    }
    return Offset(px, py);
  }

  /// A straight line between two points with no wall or water between.
  bool lineClear(double x0, double y0, double x1, double y1) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double len = sqrt(dx * dx + dy * dy);
    final int n = (len / 24).ceil();
    for (int i = 1; i < n; i++) {
      final double f = i / n;
      if (solidAt(x0 + dx * f, y0 + dy * f)) return false;
    }
    return true;
  }

  /// A straight line a bolt can fly along (water allowed).
  bool shotClear(double x0, double y0, double x1, double y1) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double len = sqrt(dx * dx + dy * dy);
    final int n = (len / 24).ceil();
    for (int i = 1; i < n; i++) {
      final double f = i / n;
      if (wallAt(x0 + dx * f, y0 + dy * f)) return false;
    }
    return true;
  }

  Offset nearestClear(double x, double y) {
    Offset best = extract;
    double bd = 1e18;
    for (final Offset p in clearPts) {
      final double dx = p.dx - x;
      final double dy = p.dy - y;
      final double d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  /// A random clear, reachable point between [minDist] and [maxDist] of
  /// [from], at least 300 units from every point in [avoid]. Relaxes the
  /// limits instead of failing.
  Offset pickPoint(Random r, Offset from, {double minDist = 0, double maxDist = 99999, List<Offset> avoid = const <Offset>[]}) {
    if (clearPts.isEmpty) return extract;
    for (int i = 0; i < 70; i++) {
      final Offset p = clearPts[r.nextInt(clearPts.length)];
      final double d = (p - from).distance;
      if (d < minDist || d > maxDist) continue;
      bool ok = true;
      for (final Offset a in avoid) {
        if ((p - a).distance < 300) {
          ok = false;
          break;
        }
      }
      if (ok) return p;
    }
    // Relax: the farthest point inside maxDist, else any point.
    Offset best = clearPts[r.nextInt(clearPts.length)];
    double bd = -1;
    for (int i = 0; i < 40; i++) {
      final Offset p = clearPts[r.nextInt(clearPts.length)];
      final double d = (p - from).distance;
      if (d <= maxDist && d > bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }

  // ---- flow field ----------------------------------------------------------

  /// Rebuilds the distance field toward the tile under (x, y) when needed.
  void updateFlow(double x, double y) {
    int tx = (x / tile).floor();
    int ty = (y / tile).floor();
    tx = tx < 0 ? 0 : (tx >= cols ? cols - 1 : tx);
    ty = ty < 0 ? 0 : (ty >= rows ? rows - 1 : ty);
    final int start = ty * cols + tx;
    if (start == _flowTile) return;
    _flowTile = start;
    for (int i = 0; i < flow.length; i++) {
      flow[i] = -1;
    }
    int head = 0;
    int tail = 0;
    flow[start] = 0;
    _queue[tail++] = start;
    while (head < tail) {
      final int c = _queue[head++];
      final int cx = c % cols;
      final int cy = c ~/ cols;
      final int d = flow[c] + 1;
      if (cx > 0 && flow[c - 1] < 0 && cells[c - 1] == 0) {
        flow[c - 1] = d;
        _queue[tail++] = c - 1;
      }
      if (cx < cols - 1 && flow[c + 1] < 0 && cells[c + 1] == 0) {
        flow[c + 1] = d;
        _queue[tail++] = c + 1;
      }
      if (cy > 0 && flow[c - cols] < 0 && cells[c - cols] == 0) {
        flow[c - cols] = d;
        _queue[tail++] = c - cols;
      }
      if (cy < rows - 1 && flow[c + cols] < 0 && cells[c + cols] == 0) {
        flow[c + cols] = d;
        _queue[tail++] = c + cols;
      }
    }
  }

  /// Unit direction from (x, y) along the flow field, or zero.
  Offset flowDir(double x, double y) {
    final int tx = (x / tile).floor();
    final int ty = (y / tile).floor();
    if (tx < 0 || ty < 0 || tx >= cols || ty >= rows) return Offset.zero;
    final int c = ty * cols + tx;
    int cur = flow[c];
    if (cur < 0) {
      // Standing in a solid tile edge: look for any neighbour with a value.
      cur = 1 << 20;
    }
    int bx = tx;
    int by = ty;
    int bd = cur;
    for (int oy = -1; oy <= 1; oy++) {
      for (int ox = -1; ox <= 1; ox++) {
        if (ox == 0 && oy == 0) continue;
        final int nx = tx + ox;
        final int ny = ty + oy;
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
        final int v = flow[ny * cols + nx];
        if (v < 0) continue;
        if (ox != 0 && oy != 0) {
          // No cutting corners through walls.
          if (cells[ty * cols + nx] != 0 || cells[ny * cols + tx] != 0) continue;
        }
        final int score = v * 2 + (ox != 0 && oy != 0 ? 1 : 0);
        if (score < bd * 2) {
          bd = v;
          bx = nx;
          by = ny;
        }
      }
    }
    if (bx == tx && by == ty) return Offset.zero;
    final double cx = bx * tile + tile / 2;
    final double cy = by * tile + tile / 2;
    final double dx = cx - x;
    final double dy = cy - y;
    final double d = sqrt(dx * dx + dy * dy);
    if (d < 0.001) return Offset.zero;
    return Offset(dx / d, dy / d);
  }

  // ---- generation ----------------------------------------------------------

  static _Seg _segments(Random r, int total, int minB, int maxB) {
    final _Seg s = _Seg();
    s.roads.add(<int>[1, 3]);
    int x = 4;
    while (x <= total - 3) {
      int bw = minB + r.nextInt(maxB - minB + 1);
      if (x + bw > total - 1) bw = total - 1 - x;
      if (bw < 3) break;
      s.blocks.add(<int>[x, x + bw - 1]);
      x += bw;
      if (x + 2 > total - 2) break;
      s.roads.add(<int>[x, x + 2]);
      x += 3;
    }
    return s;
  }

  static DarkomWorld generate(String district, int seed) {
    final Random r = Random(seed & 0x7fffffff);
    final List<int> cells = List<int>.filled(cols * rows, 0);
    final List<DBlock> blocks = <DBlock>[];
    for (int x = 0; x < cols; x++) {
      cells[x] = 1;
      cells[(rows - 1) * cols + x] = 1;
    }
    for (int y = 0; y < rows; y++) {
      cells[y * cols] = 1;
      cells[y * cols + cols - 1] = 1;
    }

    bool areaFree(int x, int y, int w, int h, int margin) {
      for (int yy = y - margin; yy < y + h + margin; yy++) {
        for (int xx = x - margin; xx < x + w + margin; xx++) {
          if (xx < 1 || yy < 1 || xx >= cols - 1 || yy >= rows - 1) {
            if (margin == 0) return false;
            continue;
          }
          if (cells[yy * cols + xx] != 0) return false;
        }
      }
      return true;
    }

    void put(int x, int y, int w, int h, int style, {int sign = -1, int code = 1}) {
      for (int yy = y; yy < y + h; yy++) {
        for (int xx = x; xx < x + w; xx++) {
          if (xx >= 1 && yy >= 1 && xx < cols - 1 && yy < rows - 1) cells[yy * cols + xx] = code;
        }
      }
      blocks.add(DBlock(x, y, w, h, style, r.nextInt(1 << 20), sign, r.nextInt(2)));
    }

    final bool docks = district == 'docks';
    final int landRows = docks ? 20 : rows;
    final bool big = district == 'spire' || district == 'grid';
    final _Seg sx = _segments(r, cols, big ? 6 : 5, big ? 9 : 8);
    final _Seg sy = _segments(r, landRows, big ? 6 : 5, big ? 8 : 7);

    // Pick the arena: the roomiest block close to the middle.
    int arenaBx = -1;
    int arenaBy = -1;
    double arenaScore = -1e9;
    for (int i = 0; i < sx.blocks.length; i++) {
      for (int j = 0; j < sy.blocks.length; j++) {
        final int w = sx.blocks[i][1] - sx.blocks[i][0] + 1;
        final int h = sy.blocks[j][1] - sy.blocks[j][0] + 1;
        final double cxm = (sx.blocks[i][0] + sx.blocks[i][1]) / 2.0;
        final double cym = (sy.blocks[j][0] + sy.blocks[j][1]) / 2.0;
        final double dist = sqrt((cxm - 20) * (cxm - 20) + (cym - landRows / 2) * (cym - landRows / 2));
        final double sc = (w < h ? w : h) * 3.0 + w * h * 0.4 - dist * 2.0;
        if (sc > arenaScore) {
          arenaScore = sc;
          arenaBx = i;
          arenaBy = j;
        }
      }
    }

    for (int i = 0; i < sx.blocks.length; i++) {
      for (int j = 0; j < sy.blocks.length; j++) {
        final int x0 = sx.blocks[i][0];
        final int x1 = sx.blocks[i][1];
        final int y0 = sy.blocks[j][0];
        final int y1 = sy.blocks[j][1];
        final int w = x1 - x0 + 1;
        final int h = y1 - y0 + 1;
        if (i == arenaBx && j == arenaBy) {
          // Arena: open floor with four pillars for cover.
          if (w >= 5 && h >= 5) {
            put(x0 + 1, y0 + 1, 1, 1, 3, code: 2);
            put(x1 - 1, y0 + 1, 1, 1, 3, code: 2);
            put(x0 + 1, y1 - 1, 1, 1, 3, code: 2);
            put(x1 - 1, y1 - 1, 1, 1, 3, code: 2);
          }
          continue;
        }
        final double roll = r.nextDouble();
        switch (district) {
          case 'neon': {
            if (roll < 0.10) {
              _scatter(r, areaFree, put, x0, y0, w, h, 2 + r.nextInt(3), 1, 1);
            } else if ((w >= 6 || h >= 6) && r.nextDouble() < 0.5) {
              if (w >= h && w >= 6) {
                final int s = 2 + r.nextInt(w - 4);
                put(x0, y0, s, h, 0, sign: r.nextInt(4));
                put(x0 + s + 1, y0, w - s - 1, h, 0, sign: r.nextInt(4));
              } else if (h >= 6) {
                final int s = 2 + r.nextInt(h - 4);
                put(x0, y0, w, s, 0, sign: r.nextInt(4));
                put(x0, y0 + s + 1, w, h - s - 1, 0, sign: r.nextInt(4));
              } else {
                put(x0, y0, w, h, 0, sign: r.nextInt(4));
              }
            } else {
              put(x0, y0, w, h, 0, sign: r.nextDouble() < 0.7 ? r.nextInt(4) : -1);
            }
            break;
          }
          case 'rustyard': {
            if (roll < 0.35) {
              if (w >= 5 && h >= 5) {
                put(x0 + 1, y0 + 1, w - 2, h - 2, 0, sign: r.nextDouble() < 0.4 ? r.nextInt(4) : -1);
              } else {
                put(x0, y0, w, h, 0);
              }
            } else {
              _scatter(r, areaFree, put, x0, y0, w, h, (w * h) ~/ 6, 2, 1);
            }
            break;
          }
          case 'docks': {
            if (roll < 0.55) {
              if (w >= 5 && h >= 5 && r.nextDouble() < 0.5) {
                put(x0 + 1, y0, w - 2, h, 0, sign: r.nextDouble() < 0.5 ? r.nextInt(4) : -1);
              } else {
                put(x0, y0, w, h, 0, sign: r.nextDouble() < 0.5 ? r.nextInt(4) : -1);
              }
            } else {
              _scatter(r, areaFree, put, x0, y0, w, h, (w * h) ~/ 7 + 1, 2, 1);
            }
            break;
          }
          case 'spire': {
            if (roll < 0.30) {
              if (w >= 5 && h >= 5) {
                put(x0 + 1, y0 + 1, 1, 1, 3, code: 2);
                put(x1 - 1, y0 + 1, 1, 1, 3, code: 2);
                put(x0 + 1, y1 - 1, 1, 1, 3, code: 2);
                put(x1 - 1, y1 - 1, 1, 1, 3, code: 2);
                put(x0 + w ~/ 2 - 1, y0 + h ~/ 2 - 1, 2, 2, 4);
              }
            } else if (w >= 5 && h >= 5) {
              put(x0 + 1, y0 + 1, w - 2, h - 2, 0, sign: r.nextDouble() < 0.8 ? r.nextInt(4) : -1);
            } else {
              put(x0, y0, w, h, 0, sign: r.nextInt(4));
            }
            break;
          }
          default: {
            // The Dead Grid: rows of server racks with aisles between them.
            final bool horiz = w >= h;
            final int len = horiz ? h : w;
            for (int k = (r.nextBool() ? 0 : 1); k < len; k += 2) {
              if (r.nextDouble() < 0.12) continue;
              if (horiz) {
                put(x0, y0 + k, w, 1, 2);
              } else {
                put(x0 + k, y0, 1, h, 2);
              }
            }
            break;
          }
        }
      }
    }

    int waterRow = -1;
    if (docks) {
      waterRow = 22;
      // Quay rows 19 to 21 stay open. Water below, with three piers.
      for (int y = 19; y <= 21; y++) {
        for (int x = 1; x < cols - 1; x++) {
          cells[y * cols + x] = 0;
        }
      }
      blocks.removeWhere((DBlock b) => b.ty + b.th > 19 && b.ty < 22);
      for (int y = waterRow; y < rows - 1; y++) {
        for (int x = 1; x < cols - 1; x++) {
          cells[y * cols + x] = 3;
        }
      }
      final List<int> piers = <int>[4 + r.nextInt(4), 17 + r.nextInt(4), 30 + r.nextInt(4)];
      for (final int px in piers) {
        for (int y = waterRow; y <= waterRow + 4; y++) {
          for (int x = px; x < px + 3; x++) {
            cells[y * cols + x] = 0;
          }
        }
        put(px + (r.nextBool() ? 0 : 2), waterRow + 3, 1, 1, 1, code: 2);
      }
    }

    // Reachability from the first crossroad, which is always open.
    final List<int> seen = List<int>.filled(cols * rows, 0);
    final List<int> q = <int>[2 * cols + 2];
    seen[2 * cols + 2] = 1;
    int head = 0;
    while (head < q.length) {
      final int c = q[head++];
      final int cx = c % cols;
      final int cy = c ~/ cols;
      for (int d = 0; d < 4; d++) {
        final int nx = cx + (d == 0 ? 1 : (d == 1 ? -1 : 0));
        final int ny = cy + (d == 2 ? 1 : (d == 3 ? -1 : 0));
        if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) continue;
        final int ni = ny * cols + nx;
        if (seen[ni] == 1 || cells[ni] != 0) continue;
        seen[ni] = 1;
        q.add(ni);
      }
    }
    final List<Offset> clear = <Offset>[];
    for (int y = 2; y < rows - 2; y++) {
      for (int x = 2; x < cols - 2; x++) {
        if (seen[y * cols + x] != 1) continue;
        bool ok = true;
        for (int oy = -1; oy <= 1 && ok; oy++) {
          for (int ox = -1; ox <= 1; ox++) {
            if (cells[(y + oy) * cols + x + ox] != 0) {
              ok = false;
              break;
            }
          }
        }
        if (ok) clear.add(Offset(x * tile + tile / 2.0, y * tile + tile / 2.0));
      }
    }
    if (clear.isEmpty) clear.add(Offset(2 * tile + tile / 2.0, 2 * tile + tile / 2.0));

    // Arena centre and rectangle.
    Offset arena = Offset(width / 2, (docks ? 10 : 15) * tile.toDouble());
    Rect arenaRect = Rect.fromCenter(center: arena, width: 360, height: 360);
    if (arenaBx >= 0 && arenaBy >= 0) {
      final int ax0 = sx.blocks[arenaBx][0];
      final int ax1 = sx.blocks[arenaBx][1];
      final int ay0 = sy.blocks[arenaBy][0];
      final int ay1 = sy.blocks[arenaBy][1];
      arenaRect = Rect.fromLTRB(ax0 * tile.toDouble(), ay0 * tile.toDouble(), (ax1 + 1) * tile.toDouble(), (ay1 + 1) * tile.toDouble());
      arena = arenaRect.center;
    }
    // Make sure the arena centre can be reached; it can only fail if a
    // pillar sits there, so slide to the nearest clear point.
    {
      final int atx = (arena.dx / tile).floor();
      final int aty = (arena.dy / tile).floor();
      if (atx < 0 || aty < 0 || atx >= cols || aty >= rows || seen[aty * cols + atx] != 1 || cells[aty * cols + atx] != 0) {
        Offset best = clear.first;
        double bd = 1e18;
        for (final Offset p in clear) {
          final double d = (p - arena).distance;
          if (d < bd) {
            bd = d;
            best = p;
          }
        }
        arena = best;
      }
    }

    // Extraction: the clear point nearest a district specific corner.
    final Offset anchor = district == 'neon'
        ? Offset(3 * tile.toDouble(), 26 * tile.toDouble())
        : district == 'rustyard'
            ? Offset(36 * tile.toDouble(), 26 * tile.toDouble())
            : district == 'docks'
                ? Offset(4 * tile.toDouble(), 17 * tile.toDouble())
                : district == 'spire'
                    ? Offset(20 * tile.toDouble(), 26 * tile.toDouble())
                    : Offset(3 * tile.toDouble(), 3 * tile.toDouble());
    Offset extract = clear.first;
    double bd = 1e18;
    for (final Offset p in clear) {
      final double d = (p - anchor).distance;
      if (d < bd && (p - arena).distance > 500) {
        bd = d;
        extract = p;
      }
    }

    final List<List<int>> vr = List<List<int>>.from(sx.roads);
    final List<List<int>> hr = List<List<int>>.from(sy.roads);
    if (docks) hr.add(<int>[19, 21]);

    return DarkomWorld._(district, cells, blocks, vr, hr, waterRow, clear, extract, arena, 240, arenaRect);
  }

  static void _scatter(Random r, bool Function(int, int, int, int, int) areaFree, void Function(int, int, int, int, int, {int sign, int code}) put, int x0, int y0, int w, int h, int count, int maxLen, int unused) {
    for (int n = 0; n < count; n++) {
      for (int tries = 0; tries < 10; tries++) {
        final bool horiz = r.nextBool();
        final int len = 1 + r.nextInt(maxLen);
        final int cw = horiz ? len : 1;
        final int ch = horiz ? 1 : len;
        if (cw > w || ch > h) continue;
        final int px = x0 + r.nextInt(w - cw + 1);
        final int py = y0 + r.nextInt(h - ch + 1);
        if (!areaFree(px, py, cw, ch, 1)) continue;
        put(px, py, cw, ch, 1, code: 2);
        break;
      }
    }
  }
}
