import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../../odyssey/odyssey_questions.dart';

double _delveCl(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

/// A rune door that blocks a corridor until its riddle is answered.
class DelveDoor {
  final int tx;
  final int ty;
  final String subjectId;
  bool open = false;
  double openAnim = 0;
  DelveDoor(this.tx, this.ty, this.subjectId);
}

/// kind: 0 coin, 1 fuel flask, 2 chest, 3 heart. For chests, [reward] is
/// 0 coins, 1 fuel, 2 heart.
class DelvePickup {
  final int kind;
  final double x;
  final double y;
  final int reward;
  bool taken = false;
  DelvePickup(this.kind, this.x, this.y, this.reward);
}

/// A dark wisp that wanders the corridors tile to tile.
class DelveShadow {
  double x;
  double y;
  int tx;
  int ty;
  int prev = -1;
  double flee = 0;
  double phase = 0;
  DelveShadow(this.x, this.y, this.tx, this.ty);
}

class DelveSpark {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final Color color;
  DelveSpark(this.x, this.y, this.vx, this.vy, this.life, this.color) : maxLife = life;
}

/// Rules of Delve.
///
/// Level layout: a perfect maze (depth-first backtracker) on a tile grid, plus a few
/// extra openings so there are loops. Tile values: 0 rock, 1 floor, 2 closed rune
/// door, 3 open rune door (floor).
///
/// Door rule (state of the design): doors are only placed on corridor tiles of the
/// shortest start-to-stairs route AND only where that tile is a true chokepoint
/// (blocking it alone cuts the stairs off). So a door is never a bypassable
/// decoration, and the number of doors on the way down is small (1 at depth 1,
/// growing to at most 4). There is therefore NOT a door-free route; instead the
/// stairs are always reachable when doors count as passable, and any player can
/// open any door by trying again for a fresh question as long as hearts remain.
class DelveLogic extends RealmLogic {
  static const double ts = 56;
  static const double pr = 13;
  static const double baseSpeed = 150;
  static const double fuelMax = 100;
  static const int maxH = 5;

  static int gridSize(int depth) {
    final int v = 15 + (depth - 1) * 2;
    return v > 31 ? 31 : v;
  }

  int depth = 1;
  int hp = maxH;
  double fuel = fuelMax;
  int coins = 0;
  int doorsOpened = 0;

  int n = 15;
  List<int> grid = <int>[];
  List<bool> seen = <bool>[];
  List<int> pd = <int>[];
  final List<DelveDoor> doors = <DelveDoor>[];
  final List<DelvePickup> pickups = <DelvePickup>[];
  final List<DelveShadow> shadows = <DelveShadow>[];
  final List<DelveSpark> sparks = <DelveSpark>[];
  int stairsIndex = 0;

  double px = 0;
  double py = 0;
  double _safeX = 0;
  double _safeY = 0;
  double facing = 1;
  double walk = 0;
  bool moving = false;
  double invuln = 0;
  double hurtT = 0;
  double sprintT = 0;
  double sprintCd = 0;
  double doorCd = 0;
  double _pdT = 0;
  String toast = '';
  double toastT = 0;

  bool _modal = false;
  OdyQuestion? question;
  int? chosen;
  String resultLine = '';
  String panelHeader = '';
  DelveDoor? _doorHot;
  bool _lastOk = false;

  final List<int> _queue = <int>[];
  final List<int> _cand = <int>[];

  static const List<String> _stories = <String>[
    'The keepers lit these halls with lessons, not oil.',
    'Scratched on the wall: a lantern only burns for the curious.',
    'The air hums. A rune door is somewhere ahead.',
    'Every keeper left a flask behind. Look for the glow.',
    'The shadows here were once students who gave up.',
    'Deeper still. The academy was larger than anyone knew.',
  ];

  DelveLogic(RealmContent content) : super(content) {
    _build();
    toast = 'The academy sleeps below. Find the stairs.';
    toastT = 3.5;
  }

  @override
  bool get modal => _modal;

  // ---- objective guidance -----------------------------------------------------

  Offset? _objTarget;
  String? _objText;

  void _pickObjective() {
    _objTarget = null;
    _objText = null;
    if (over || _modal) return;
    if (fuel < 30) {
      DelvePickup? best;
      double bd = 0;
      for (final DelvePickup p in pickups) {
        if (p.taken || p.kind != 1) continue;
        final double d = (p.x - px) * (p.x - px) + (p.y - py) * (p.y - py);
        if (best == null || d < bd) {
          best = p;
          bd = d;
        }
      }
      if (best != null) {
        _objTarget = Offset(best.x - px, best.y - py);
        _objText = 'Your torch is dying. Grab a fuel flask';
        return;
      }
    }
    DelveDoor? door;
    double dd = 0;
    for (final DelveDoor d in doors) {
      if (d.open) continue;
      final double cx = d.tx * ts + ts / 2;
      final double cy = d.ty * ts + ts / 2;
      final double q = (cx - px) * (cx - px) + (cy - py) * (cy - py);
      if (door == null || q < dd) {
        door = d;
        dd = q;
      }
    }
    if (door != null) {
      _objTarget = Offset(door.tx * ts + ts / 2 - px, door.ty * ts + ts / 2 - py);
      _objText = 'Reach the rune door and solve its riddle';
      return;
    }
    _objTarget = Offset((stairsIndex % n) * ts + ts / 2 - px, (stairsIndex ~/ n) * ts + ts / 2 - py);
    _objText = 'The way is open. Take the stairs down';
  }

  @override
  String? get objectiveText {
    _pickObjective();
    return _objText;
  }

  @override
  Offset? get objectiveDelta {
    _pickObjective();
    return _objTarget;
  }

  @override
  String? get objectiveDistance {
    _pickObjective();
    final Offset? t = _objTarget;
    if (t == null) return null;
    return '${(t.distance / 10).round()} m';
  }

  @override
  int get hearts => hp;

  @override
  int get maxHearts => maxH;

  @override
  int get finalScore => depth * 150 + coins + doorsOpened * 50;

  @override
  int get xp => stats.baseXp + depth * 4;

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Depth $depth', Icons.stairs_rounded, const Color(0xFF80DEEA)),
        RealmChip('Torch ${torchPercent}%', Icons.local_fire_department_rounded, const Color(0xFFFFB74D)),
        RealmChip('$coins', Icons.monetization_on_rounded, const Color(0xFFFFD54F)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Depth': '$depth',
        'Doors opened': '$doorsOpened',
        'Coins': '$coins',
      };

  int get torchPercent => (fuel / fuelMax * 100).round();
  double get lightRadius => 34 + 156 * (fuel / fuelMax);

  String get depthSubjectId => content.subjectIds[(depth - 1) % content.subjectIds.length];
  Color get tint => content.subject(depthSubjectId).color;

  bool solidAt(int tx, int ty) {
    if (tx < 0 || ty < 0 || tx >= n || ty >= n) return true;
    final int g = grid[ty * n + tx];
    return g == 0 || g == 2;
  }

  bool _shadowSolid(int tx, int ty) => solidAt(tx, ty);

  // ---- level generation ---------------------------------------------------

  void _build() {
    n = gridSize(depth);
    final int total = n * n;
    grid = List<int>.filled(total, 0);
    seen = List<bool>.filled(total, false);
    pd = List<int>.filled(total, -1);
    doors.clear();
    pickups.clear();
    shadows.clear();
    sparks.clear();
    final Random r = Random(realmHash(content.seed, depth, 911));
    final int m = (n - 1) ~/ 2;
    final List<bool> vis = List<bool>.filled(m * m, false);
    final List<int> stack = <int>[0];
    vis[0] = true;
    grid[1 * n + 1] = 1;
    const List<int> dxs = <int>[1, -1, 0, 0];
    const List<int> dys = <int>[0, 0, 1, -1];
    final List<int> opts = <int>[];
    while (stack.isNotEmpty) {
      final int cur = stack[stack.length - 1];
      final int cx = cur % m;
      final int cy = cur ~/ m;
      opts.clear();
      for (int k = 0; k < 4; k++) {
        final int nx = cx + dxs[k];
        final int ny = cy + dys[k];
        if (nx < 0 || ny < 0 || nx >= m || ny >= m) continue;
        if (vis[ny * m + nx]) continue;
        opts.add(k);
      }
      if (opts.isEmpty) {
        stack.removeLast();
        continue;
      }
      final int k = opts[r.nextInt(opts.length)];
      final int nx = cx + dxs[k];
      final int ny = cy + dys[k];
      vis[ny * m + nx] = true;
      grid[(2 * cy + 1 + dys[k]) * n + (2 * cx + 1 + dxs[k])] = 1;
      grid[(2 * ny + 1) * n + (2 * nx + 1)] = 1;
      stack.add(ny * m + nx);
    }
    // Extra openings make loops.
    final List<int> loopTiles = <int>[];
    int want = 2 + (m * m) ~/ 14;
    int tries = want * 12;
    while (want > 0 && tries > 0) {
      tries--;
      final int x = 1 + r.nextInt(n - 2);
      final int y = 1 + r.nextInt(n - 2);
      if (grid[y * n + x] != 0) continue;
      if ((x + y) % 2 == 0) continue;
      bool ok;
      if (x % 2 == 0) {
        ok = grid[y * n + x - 1] == 1 && grid[y * n + x + 1] == 1;
      } else {
        ok = grid[(y - 1) * n + x] == 1 && grid[(y + 1) * n + x] == 1;
      }
      if (!ok) continue;
      grid[y * n + x] = 1;
      loopTiles.add(y * n + x);
      want--;
    }
    final int startI = 1 * n + 1;
    final int stairI = (n - 2) * n + (n - 2);
    stairsIndex = stairI;

    // Rune doors on chokepoints of the shortest route.
    List<int> path = _pathTo(startI, stairI);
    final int wantDoors = depth <= 1 ? 1 : (1 + depth ~/ 2 > 4 ? 4 : 1 + depth ~/ 2);
    int placedDoors = _placeDoors(path, startI, stairI, wantDoors);
    if (placedDoors == 0 && loopTiles.isNotEmpty) {
      // Every route was bypassable through a loop: close the loops so the doors guard the only way.
      for (final int li in loopTiles) {
        grid[li] = 0;
      }
      path = _pathTo(startI, stairI);
      placedDoors = _placeDoors(path, startI, stairI, wantDoors);
    }
    final int len = path.length;

    // Pickups and shadows.
    final List<int> dist = _bfsFrom(startI, false);
    final List<bool> used = List<bool>.filled(total, false);
    used[startI] = true;
    used[stairI] = true;
    final List<int> floors = <int>[];
    for (int i = 0; i < total; i++) {
      if (grid[i] == 1 && !used[i] && dist[i] >= 0) floors.add(i);
    }
    for (int i = floors.length - 1; i > 0; i--) {
      final int j = r.nextInt(i + 1);
      final int t = floors[i];
      floors[i] = floors[j];
      floors[j] = t;
    }
    int fp = 0;
    final int coinN = (8 + (m * m) ~/ 5) > 45 ? 45 : (8 + (m * m) ~/ 5);
    // Fuel flasks along the route so the torch is always refillable.
    for (int pos = 18; pos < len - 3; pos += 34) {
      int idx = -1;
      for (int q = 0; q < 4; q++) {
        if (pos + q < len - 2) {
          final int ti = path[pos + q];
          if (grid[ti] == 1 && !used[ti]) {
            idx = ti;
            break;
          }
        }
      }
      if (idx < 0) continue;
      used[idx] = true;
      pickups.add(DelvePickup(1, (idx % n) * ts + ts / 2, (idx ~/ n) * ts + ts / 2, 0));
    }
    final int extraFlasks = 1 + (m * m) ~/ 60;
    final int chestN = 1 + (m * m) ~/ 40;
    final bool heartHere = depth >= 2 && r.nextDouble() < 0.4;
    int coinLeft = coinN;
    int flaskLeft = extraFlasks;
    int chestLeft = chestN;
    bool heartLeft = heartHere;
    while (fp < floors.length && (coinLeft > 0 || flaskLeft > 0 || chestLeft > 0 || heartLeft)) {
      final int idx = floors[fp++];
      if (used[idx]) continue;
      used[idx] = true;
      final double cx = (idx % n) * ts + ts / 2;
      final double cy = (idx ~/ n) * ts + ts / 2;
      if (heartLeft) {
        heartLeft = false;
        pickups.add(DelvePickup(3, cx, cy, 0));
      } else if (chestLeft > 0) {
        chestLeft--;
        final double q = r.nextDouble();
        final int rw = q < 0.45 ? 0 : (q < 0.88 ? 1 : 2);
        pickups.add(DelvePickup(2, cx, cy, rw));
      } else if (flaskLeft > 0) {
        flaskLeft--;
        pickups.add(DelvePickup(1, cx, cy, 0));
      } else {
        coinLeft--;
        pickups.add(DelvePickup(0, cx, cy, 0));
      }
    }
    final int shadowN = (2 + depth ~/ 2) > 7 ? 7 : (2 + depth ~/ 2);
    int made = 0;
    for (int i = fp; i < floors.length && made < shadowN; i++) {
      final int idx = floors[i];
      if (dist[idx] < 9) continue;
      final int tx = idx % n;
      final int ty = idx ~/ n;
      shadows.add(DelveShadow(tx * ts + ts / 2, ty * ts + ts / 2, tx, ty));
      made++;
    }

    px = 1 * ts + ts / 2;
    py = 1 * ts + ts / 2;
    _safeX = px;
    _safeY = py;
    _pdT = 0;
    _fillDist();
    _updateSeen();
  }

  int _placeDoors(List<int> path, int startI, int stairI, int wantDoors) {
    final int len = path.length;
    final List<int> doorPos = <int>[];
    for (int k = 0; k < wantDoors; k++) {
      final int target = (k + 1) * len ~/ (wantDoors + 1);
      bool placed = false;
      for (int off = 0; off <= len && !placed; off++) {
        for (int sg = 0; sg < 2 && !placed; sg++) {
          if (off == 0 && sg == 1) continue;
          final int pos = sg == 0 ? target + off : target - off;
          if (pos < 4 || pos > len - 5) continue;
          bool near = false;
          for (final int e in doorPos) {
            if ((pos - e).abs() < 6) near = true;
          }
          if (near) continue;
          final int ti = path[pos];
          if (!_isCorridor(ti)) continue;
          if (_reachableWithout(startI, stairI, ti)) continue;
          grid[ti] = 2;
          final String sid = content.subjectIds[(depth - 1 + k) % content.subjectIds.length];
          doors.add(DelveDoor(ti % n, ti ~/ n, sid));
          doorPos.add(pos);
          placed = true;
        }
      }
    }
    return doorPos.length;
  }

  bool _isCorridor(int i) {
    final int x = i % n;
    final int y = i ~/ n;
    if (x < 1 || y < 1 || x > n - 2 || y > n - 2) return false;
    final bool l = grid[y * n + x - 1] == 0;
    final bool rr = grid[y * n + x + 1] == 0;
    final bool u = grid[(y - 1) * n + x] == 0;
    final bool d = grid[(y + 1) * n + x] == 0;
    if (l && rr && !u && !d) return true;
    if (u && d && !l && !rr) return true;
    return false;
  }

  /// BFS over every non-rock tile (doors count as passable).
  List<int> _bfsFrom(int s, bool shadowRules) {
    final List<int> d = List<int>.filled(n * n, -1);
    _queue.clear();
    _queue.add(s);
    d[s] = 0;
    int head = 0;
    while (head < _queue.length) {
      final int cur = _queue[head++];
      final int cx = cur % n;
      final int cy = cur ~/ n;
      for (int k = 0; k < 4; k++) {
        final int nx = cx + (k == 0 ? 1 : (k == 1 ? -1 : 0));
        final int ny = cy + (k == 2 ? 1 : (k == 3 ? -1 : 0));
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        final int ni = ny * n + nx;
        if (d[ni] >= 0) continue;
        final int g = grid[ni];
        if (g == 0) continue;
        if (shadowRules && g == 2) continue;
        d[ni] = d[cur] + 1;
        _queue.add(ni);
      }
    }
    return d;
  }

  List<int> _pathTo(int s, int t) {
    final List<int> par = List<int>.filled(n * n, -2);
    _queue.clear();
    _queue.add(s);
    par[s] = -1;
    int head = 0;
    while (head < _queue.length && par[t] == -2) {
      final int cur = _queue[head++];
      final int cx = cur % n;
      final int cy = cur ~/ n;
      for (int k = 0; k < 4; k++) {
        final int nx = cx + (k == 0 ? 1 : (k == 1 ? -1 : 0));
        final int ny = cy + (k == 2 ? 1 : (k == 3 ? -1 : 0));
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        final int ni = ny * n + nx;
        if (par[ni] != -2 || grid[ni] == 0) continue;
        par[ni] = cur;
        _queue.add(ni);
      }
    }
    final List<int> out = <int>[];
    int c = t;
    while (c >= 0 && par[c] != -2) {
      out.add(c);
      c = par[c];
    }
    return out.reversed.toList();
  }

  bool _reachableWithout(int s, int t, int blocked) {
    final List<bool> v = List<bool>.filled(n * n, false);
    _queue.clear();
    _queue.add(s);
    v[s] = true;
    int head = 0;
    while (head < _queue.length) {
      final int cur = _queue[head++];
      if (cur == t) return true;
      final int cx = cur % n;
      final int cy = cur ~/ n;
      for (int k = 0; k < 4; k++) {
        final int nx = cx + (k == 0 ? 1 : (k == 1 ? -1 : 0));
        final int ny = cy + (k == 2 ? 1 : (k == 3 ? -1 : 0));
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        final int ni = ny * n + nx;
        if (v[ni] || grid[ni] == 0 || ni == blocked) continue;
        v[ni] = true;
        _queue.add(ni);
      }
    }
    return false;
  }

  void _fillDist() {
    final int ptx = (px / ts).floor();
    final int pty = (py / ts).floor();
    if (ptx < 0 || pty < 0 || ptx >= n || pty >= n) return;
    pd = _bfsFrom(pty * n + ptx, true);
  }

  // ---- actions ------------------------------------------------------------

  @override
  void onAction(int id) {
    if (id != 0 || over || _modal) return;
    if (sprintCd > 0) return;
    sprintT = 0.8;
    sprintCd = 3.5;
    fuel = _delveCl(fuel - 3, 0, fuelMax);
    cues.add('tap');
  }

  @override
  double actionReady(int id) {
    if (sprintCd <= 0) return 1;
    return _delveCl(1 - sprintCd / 3.5, 0, 1);
  }

  void _say(String s, [double t = 2.6]) {
    toast = s;
    toastT = t;
  }

  void _spark(double x, double y, Color c, int count) {
    for (int i = 0; i < count; i++) {
      if (sparks.length >= 60) return;
      final double a = rng.nextDouble() * 6.2832;
      final double sp = 40 + rng.nextDouble() * 90;
      sparks.add(DelveSpark(x, y, cos(a) * sp, sin(a) * sp, 0.5 + rng.nextDouble() * 0.5, c));
    }
  }

  // ---- panel --------------------------------------------------------------

  void _openDoor(DelveDoor d) {
    _modal = true;
    inputX = 0;
    inputY = 0;
    moving = false;
    _doorHot = d;
    chosen = null;
    resultLine = '';
    question = content.ask(d.subjectId);
    panelHeader = 'Rune door - ${content.subject(d.subjectId).label}';
  }

  void pickAnswer(int i) {
    final OdyQuestion? q = question;
    if (q == null || chosen != null || !_modal) return;
    chosen = i;
    final bool ok = i == q.answerIndex;
    _lastOk = ok;
    stats.record(q, ok, chosen: q.options[i]);
    final DelveDoor? d = _doorHot;
    if (ok) {
      cues.add('good');
      if (d != null) {
        d.open = true;
        grid[d.ty * n + d.tx] = 3;
        doorsOpened++;
        coins += 25;
        _spark(d.tx * ts + ts / 2, d.ty * ts + ts / 2, const Color(0xFFFFE082), 28);
      }
      resultLine = 'The rune blazes and the door swings open. +25 coins';
      _say('The door remembers those who know the lesson.');
    } else {
      cues.add('bad');
      hp = hp > 0 ? hp - 1 : 0;
      hurtT = 0.6;
      resultLine = 'A trap fires from the wall and the door stays shut.';
    }
  }

  void continuePanel() {
    if (!_modal || chosen == null) return;
    _modal = false;
    question = null;
    chosen = null;
    final DelveDoor? d = _doorHot;
    _doorHot = null;
    doorCd = 0.9;
    if (!_lastOk && d != null) {
      final double dcx = d.tx * ts + ts / 2;
      final double dcy = d.ty * ts + ts / 2;
      double vx = px - dcx;
      double vy = py - dcy;
      final double m = sqrt(vx * vx + vy * vy);
      if (m < 0.001) {
        vx = 1;
        vy = 0;
      } else {
        vx /= m;
        vy /= m;
      }
      px = dcx + vx * (ts / 2 + pr + 10);
      py = dcy + vy * (ts / 2 + pr + 10);
      _resolve();
      if (_solidAtPoint(px, py)) {
        px = _safeX;
        py = _safeY;
      }
    }
    if (hp <= 0) {
      over = true;
      cues.add('lose');
    }
  }

  // ---- simulation ---------------------------------------------------------

  bool _solidAtPoint(double x, double y) => solidAt((x / ts).floor(), (y / ts).floor());

  void _resolve() {
    for (int it = 0; it < 3; it++) {
      final int cx = (px / ts).floor();
      final int cy = (py / ts).floor();
      for (int ty = cy - 1; ty <= cy + 1; ty++) {
        for (int tx = cx - 1; tx <= cx + 1; tx++) {
          if (!solidAt(tx, ty)) continue;
          final double left = tx * ts;
          final double top = ty * ts;
          final double right = left + ts;
          final double bottom = top + ts;
          final double nx = _delveCl(px, left, right);
          final double ny = _delveCl(py, top, bottom);
          final double dx = px - nx;
          final double dy = py - ny;
          final double d2 = dx * dx + dy * dy;
          if (d2 >= pr * pr) continue;
          if (d2 > 1e-9) {
            final double d = sqrt(d2);
            final double push = pr - d;
            px += dx / d * push;
            py += dy / d * push;
          } else {
            final double dl = px - left;
            final double dr = right - px;
            final double dtp = py - top;
            final double db = bottom - py;
            double best = dl;
            int side = 0;
            if (dr < best) {
              best = dr;
              side = 1;
            }
            if (dtp < best) {
              best = dtp;
              side = 2;
            }
            if (db < best) {
              best = db;
              side = 3;
            }
            if (side == 0) px = left - pr;
            if (side == 1) px = right + pr;
            if (side == 2) py = top - pr;
            if (side == 3) py = bottom + pr;
          }
        }
      }
    }
  }

  @override
  void step(double dt) {
    if (over) return;
    if (toastT > 0) toastT -= dt;
    for (int i = sparks.length - 1; i >= 0; i--) {
      final DelveSpark s = sparks[i];
      s.life -= dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vx *= 0.96;
      s.vy *= 0.96;
      if (s.life <= 0) sparks.removeAt(i);
    }
    for (final DelveDoor d in doors) {
      if (d.open && d.openAnim < 1) d.openAnim = _delveCl(d.openAnim + dt * 1.6, 0, 1);
    }
    if (_modal) return;
    if (invuln > 0) invuln -= dt;
    if (hurtT > 0) hurtT -= dt;
    if (doorCd > 0) doorCd -= dt;
    if (sprintT > 0) sprintT -= dt;
    if (sprintCd > 0) sprintCd -= dt;

    _safeX = px;
    _safeY = py;
    final bool sprinting = sprintT > 0;
    final double sp = baseSpeed * (sprinting ? 1.85 : 1.0);
    moving = inputX.abs() + inputY.abs() > 0.05;
    if (moving) {
      px += inputX * sp * dt;
      _resolve();
      py += inputY * sp * dt;
      _resolve();
      walk += dt * (sprinting ? 16 : 10);
      if (inputX.abs() > 0.1) facing = inputX > 0 ? 1 : -1;
    }
    if (_solidAtPoint(px, py)) {
      px = _safeX;
      py = _safeY;
    }

    // Torch.
    final double drain = sprinting ? 3.2 : 0.8;
    fuel = _delveCl(fuel - drain * dt, 0, fuelMax);

    _updateSeen();
    _pickups();
    _checkDoors();
    if (_modal) return;
    _updateShadows(dt);
    if (over) return;

    // Stairs.
    final double sx = (stairsIndex % n) * ts + ts / 2;
    final double sy = (stairsIndex ~/ n) * ts + ts / 2;
    final double ddx = px - sx;
    final double ddy = py - sy;
    if (ddx * ddx + ddy * ddy < 24 * 24) _descend();
  }

  void _descend() {
    depth++;
    hp = hp + 1 > maxH ? maxH : hp + 1;
    fuel = _delveCl(fuel + 50, 0, fuelMax);
    invuln = 1.5;
    _build();
    cues.add('win');
    _say('Depth $depth. ' + _stories[(depth - 2) % _stories.length], 3.6);
  }

  void _checkDoors() {
    if (doorCd > 0) return;
    for (final DelveDoor d in doors) {
      if (d.open) continue;
      final double left = d.tx * ts;
      final double top = d.ty * ts;
      final double nx = _delveCl(px, left, left + ts);
      final double ny = _delveCl(py, top, top + ts);
      final double dx = px - nx;
      final double dy = py - ny;
      if (dx * dx + dy * dy < (pr + 5) * (pr + 5)) {
        _openDoor(d);
        return;
      }
    }
  }

  void _pickups() {
    for (final DelvePickup p in pickups) {
      if (p.taken) continue;
      final double dx = p.x - px;
      final double dy = p.y - py;
      final double d2 = dx * dx + dy * dy;
      if (p.kind == 0 && d2 < 24 * 24) {
        p.taken = true;
        coins += 5;
        cues.add('tap');
        _spark(p.x, p.y, const Color(0xFFFFD54F), 4);
      } else if (p.kind == 1 && d2 < 26 * 26) {
        p.taken = true;
        fuel = _delveCl(fuel + 30, 0, fuelMax);
        cues.add('good');
        _spark(p.x, p.y, const Color(0xFFFFB74D), 10);
        _say('Lantern oil. The flame leaps up.');
      } else if (p.kind == 2 && d2 < 30 * 30) {
        p.taken = true;
        _spark(p.x, p.y, const Color(0xFFFFE082), 16);
        cues.add('good');
        if (p.reward == 0) {
          final int c = 15 + depth * 3;
          coins += c;
          _say('A keeper\'s chest: $c coins.');
        } else if (p.reward == 1) {
          fuel = _delveCl(fuel + 40, 0, fuelMax);
          _say('A keeper\'s chest: lantern oil.');
        } else if (hp < maxH) {
          hp++;
          _say('A keeper\'s chest: a warm charm. +1 heart.');
        } else {
          coins += 30;
          _say('A keeper\'s chest: 30 coins.');
        }
      } else if (p.kind == 3 && d2 < 26 * 26 && hp < maxH) {
        p.taken = true;
        hp++;
        cues.add('good');
        _spark(p.x, p.y, const Color(0xFFFF8A80), 12);
        _say('A heart of warm stone. +1 heart.');
      }
    }
  }

  void _updateSeen() {
    final double rad = lightRadius + ts * 0.6;
    final int x0 = ((px - rad) / ts).floor();
    final int x1 = ((px + rad) / ts).floor();
    final int y0 = ((py - rad) / ts).floor();
    final int y1 = ((py + rad) / ts).floor();
    for (int ty = y0; ty <= y1; ty++) {
      if (ty < 0 || ty >= n) continue;
      for (int tx = x0; tx <= x1; tx++) {
        if (tx < 0 || tx >= n) continue;
        final int idx = ty * n + tx;
        if (seen[idx]) continue;
        final double dx = tx * ts + ts / 2 - px;
        final double dy = ty * ts + ts / 2 - py;
        if (dx * dx + dy * dy > rad * rad) continue;
        if (_sight(tx, ty, dx, dy)) seen[idx] = true;
      }
    }
  }

  bool _sight(int tx, int ty, double dx, double dy) {
    final double dist = sqrt(dx * dx + dy * dy);
    final int steps = (dist / 14).ceil();
    for (int s = 1; s < steps; s++) {
      final double t = s / steps;
      final int sx = ((px + dx * t) / ts).floor();
      final int sy = ((py + dy * t) / ts).floor();
      if (sx == tx && sy == ty) return true;
      if (solidAt(sx, sy)) return false;
    }
    return true;
  }

  void _updateShadows(double dt) {
    _pdT -= dt;
    if (_pdT <= 0) {
      _fillDist();
      _pdT = 0.3;
    }
    final double rad = lightRadius;
    final bool low = fuel < 12;
    final bool dead = fuel <= 0;
    final double speed = dead ? 98 : 72;
    for (final DelveShadow s in shadows) {
      s.phase += dt * 3;
      if (s.flee > 0) s.flee -= dt;
      final double tcx = s.tx * ts + ts / 2;
      final double tcy = s.ty * ts + ts / 2;
      final double dx = tcx - s.x;
      final double dy = tcy - s.y;
      final double d = sqrt(dx * dx + dy * dy);
      final double stepLen = speed * dt;
      if (d <= stepLen) {
        s.x = tcx;
        s.y = tcy;
        _pickNext(s, low, dead, rad);
      } else {
        s.x += dx / d * stepLen;
        s.y += dy / d * stepLen;
      }
      if (invuln <= 0) {
        final double hx = s.x - px;
        final double hy = s.y - py;
        if (hx * hx + hy * hy < (pr + 11) * (pr + 11)) {
          final int dmg = dead ? 2 : 1;
          hp = hp - dmg < 0 ? 0 : hp - dmg;
          invuln = 1.6;
          hurtT = 0.6;
          s.flee = 2.0;
          cues.add('bad');
          _say(dead ? 'Without light the shadows bite deep.' : 'A shadow drains your warmth.');
          if (hp <= 0) {
            over = true;
            cues.add('lose');
            return;
          }
        }
      }
    }
  }

  void _pickNext(DelveShadow s, bool low, bool dead, double rad) {
    final int myIdx = s.ty * n + s.tx;
    _cand.clear();
    for (int k = 0; k < 4; k++) {
      final int nx = s.tx + (k == 0 ? 1 : (k == 1 ? -1 : 0));
      final int ny = s.ty + (k == 2 ? 1 : (k == 3 ? -1 : 0));
      if (_shadowSolid(nx, ny)) continue;
      _cand.add(ny * n + nx);
    }
    if (_cand.isEmpty) return;
    final double hx = s.x - px;
    final double hy = s.y - py;
    final double dpx = sqrt(hx * hx + hy * hy);
    final int myD = pd[myIdx];
    int mode = 0;
    if (s.flee > 0 || (!low && dpx < rad * 1.05)) {
      mode = 1;
    } else if (myD >= 0 && myD <= (dead ? 16 : 9) && (dead || low || dpx > rad)) {
      mode = 2;
    }
    if (mode == 1 && myD < 0) mode = 0;
    int pick = -1;
    if (mode == 0) {
      final List<int> opts = <int>[];
      for (final int c in _cand) {
        if (c != s.prev) opts.add(c);
      }
      if (opts.isEmpty) {
        pick = _cand[0];
      } else {
        pick = opts[rng.nextInt(opts.length)];
      }
    } else {
      int bestV = mode == 1 ? -1 : 1 << 30;
      for (final int c in _cand) {
        final int v = pd[c];
        if (v < 0) continue;
        if (mode == 1 ? v > bestV : v < bestV) {
          bestV = v;
          pick = c;
        }
      }
      if (pick < 0) pick = _cand[rng.nextInt(_cand.length)];
    }
    s.prev = myIdx;
    s.tx = pick % n;
    s.ty = pick ~/ n;
  }
}
