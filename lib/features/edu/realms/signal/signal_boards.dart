import 'dart:math';
import 'dart:ui' show Offset, Rect;

// Pure rules of Signal Ridge: blocks, the interpreter, board and circuit
// generators, and the debugging puzzles. No drawing and no widgets.

const List<int> sgDx = <int>[0, 1, 0, -1];
const List<int> sgDy = <int>[-1, 0, 1, 0];

enum SKind { forward, left, right, act, rep, iff }

const List<String> _kindNames = <String>['FORWARD', 'TURN LEFT', 'TURN RIGHT', 'ACTIVATE', 'REPEAT', 'IF WALL AHEAD'];

String sgName(SKind k) => _kindNames[k.index];

class SCell {
  final int x;
  final int y;
  const SCell(this.x, this.y);
}

/// One program block. Containers (REPEAT, IF) hold other blocks.
class SBlock {
  SKind kind;
  int n;
  final List<SBlock> body;
  final List<SBlock> els;
  SBlock(this.kind, {this.n = 2, List<SBlock>? body, List<SBlock>? els})
      : body = body ?? <SBlock>[],
        els = els ?? <SBlock>[];

  bool get isContainer => kind == SKind.rep || kind == SKind.iff;

  SBlock copy() => SBlock(
        kind,
        n: n,
        body: <SBlock>[for (final SBlock b in body) b.copy()],
        els: <SBlock>[for (final SBlock b in els) b.copy()],
      );
}

String sgLabel(SBlock b) => b.kind == SKind.rep ? 'REPEAT ${b.n}' : sgName(b.kind);

int sgCount(List<SBlock> l) {
  int c = 0;
  for (final SBlock b in l) {
    c += 1 + sgCount(b.body) + sgCount(b.els);
  }
  return c;
}

void _flat(List<SBlock> l, List<SBlock> out) {
  for (final SBlock b in l) {
    out.add(b);
    _flat(b.body, out);
    _flat(b.els, out);
  }
}

/// Every block in reading order (a container comes before its children).
List<SBlock> sgFlatten(List<SBlock> l) {
  final List<SBlock> out = <SBlock>[];
  _flat(l, out);
  return out;
}

List<SBlock> sgClone(List<SBlock> l) => <SBlock>[for (final SBlock b in l) b.copy()];

String sgProgText(List<SBlock> l) {
  if (l.isEmpty) return '(empty)';
  return l.map(_blockText).join(', ');
}

String _blockText(SBlock b) {
  if (b.kind == SKind.rep) return 'REPEAT ${b.n} [${sgProgText(b.body)}]';
  if (b.kind == SKind.iff) return 'IF WALL AHEAD [${sgProgText(b.body)}] ELSE [${sgProgText(b.els)}]';
  return sgName(b.kind);
}

// ---------------------------------------------------------------------------
// Locating blocks

class SLoc {
  final List<SBlock> list;
  final int idx;
  final SBlock? owner;
  final int branch;
  const SLoc(this.list, this.idx, this.owner, this.branch);
}

SLoc? _loc(List<SBlock> list, SBlock? owner, int branch, SBlock t) {
  final int i = list.indexOf(t);
  if (i >= 0) return SLoc(list, i, owner, branch);
  for (final SBlock b in list) {
    final SLoc? r = _loc(b.body, b, 0, t) ?? _loc(b.els, b, 1, t);
    if (r != null) return r;
  }
  return null;
}

SLoc? sgLocate(List<SBlock> root, SBlock t) => _loc(root, null, 0, t);

// ---------------------------------------------------------------------------
// Interpreter

const int evMove = 0;
const int evTurn = 1;
const int evAct = 2;
const int evActNone = 3;
const int evRock = 4;
const int evEdge = 5;
const int evCheck = 6;

class SStep {
  final SBlock? block;
  final List<SBlock> chain;
  final int x;
  final int y;
  final int dir;
  final int event;
  final int lit;
  final int tower;
  final bool cond;
  SStep(this.block, this.chain, this.x, this.y, this.dir, this.event, this.lit, this.tower, this.cond);
}

class SSim {
  final List<SStep> steps;
  final bool allLit;
  final int crash;
  final int lit;
  final int missed;
  final List<SCell> trail;
  final int crashX;
  final int crashY;
  SSim(this.steps, this.allLit, this.crash, this.lit, this.missed, this.trail, this.crashX, this.crashY);
}

class SBoard {
  final int w;
  final int h;
  final List<List<bool>> rock;
  final int sx;
  final int sy;
  final int sdir;
  final List<SCell> towers;
  final bool fog;
  final List<SBlock> ref;
  SBoard({
    required this.w,
    required this.h,
    required this.rock,
    required this.sx,
    required this.sy,
    required this.sdir,
    required this.towers,
    required this.fog,
    required this.ref,
  });

  bool inside(int x, int y) => x >= 0 && y >= 0 && x < w && y < h;
  bool isRock(int x, int y) => inside(x, y) && rock[y][x];
  bool blocked(int x, int y) => !inside(x, y) || rock[y][x];
  bool wallAhead(int x, int y, int dir) => blocked(x + sgDx[dir], y + sgDy[dir]);

  int towerAt(int x, int y) {
    for (int i = 0; i < towers.length; i++) {
      if (towers[i].x == x && towers[i].y == y) return i;
    }
    return -1;
  }

  int get par => sgCount(ref);
  int get allowed => par + 2;
}

class _Ctx {
  int x;
  int y;
  int dir;
  int lit = 0;
  int crash = 0;
  int crashX = -1;
  int crashY = -1;
  bool stop = false;
  final List<SStep> steps = <SStep>[];
  final List<SCell> trail = <SCell>[];
  _Ctx(this.x, this.y, this.dir);

  void add(SBlock? b, List<SBlock> chain, int event, int tower, bool cond) {
    steps.add(SStep(b, chain, x, y, dir, event, lit, tower, cond));
  }
}

void _exec(SBoard b, List<SBlock> list, _Ctx c, List<SBlock> chain) {
  for (final SBlock blk in list) {
    if (c.stop) return;
    if (c.steps.length > 900) {
      c.stop = true;
      return;
    }
    switch (blk.kind) {
      case SKind.forward:
        {
          final int nx = c.x + sgDx[c.dir];
          final int ny = c.y + sgDy[c.dir];
          if (!b.inside(nx, ny)) {
            c.crash = 5;
            c.crashX = nx;
            c.crashY = ny;
            c.stop = true;
            c.add(blk, chain, evEdge, -1, false);
          } else if (b.rock[ny][nx]) {
            c.crash = 4;
            c.crashX = nx;
            c.crashY = ny;
            c.stop = true;
            c.add(blk, chain, evRock, -1, false);
          } else {
            c.x = nx;
            c.y = ny;
            c.trail.add(SCell(nx, ny));
            c.add(blk, chain, evMove, -1, false);
          }
          break;
        }
      case SKind.left:
        {
          c.dir = (c.dir + 3) % 4;
          c.add(blk, chain, evTurn, -1, false);
          break;
        }
      case SKind.right:
        {
          c.dir = (c.dir + 1) % 4;
          c.add(blk, chain, evTurn, -1, false);
          break;
        }
      case SKind.act:
        {
          final int ti = b.towerAt(c.x, c.y);
          if (ti >= 0 && (c.lit & (1 << ti)) == 0) {
            c.lit |= (1 << ti);
            c.add(blk, chain, evAct, ti, false);
          } else {
            c.add(blk, chain, evActNone, -1, false);
          }
          break;
        }
      case SKind.rep:
        {
          final List<SBlock> inner = <SBlock>[...chain, blk];
          for (int k = 0; k < blk.n; k++) {
            if (c.stop) return;
            _exec(b, blk.body, c, inner);
          }
          break;
        }
      case SKind.iff:
        {
          final bool cond = b.wallAhead(c.x, c.y, c.dir);
          c.add(blk, chain, evCheck, -1, cond);
          final List<SBlock> inner = <SBlock>[...chain, blk];
          _exec(b, cond ? blk.body : blk.els, c, inner);
          break;
        }
    }
  }
}

SSim sgRun(SBoard b, List<SBlock> prog) {
  final _Ctx c = _Ctx(b.sx, b.sy, b.sdir);
  c.trail.add(SCell(b.sx, b.sy));
  _exec(b, prog, c, const <SBlock>[]);
  final int full = (1 << b.towers.length) - 1;
  int missed = -1;
  for (int i = 0; i < b.towers.length; i++) {
    if ((c.lit & (1 << i)) == 0) {
      missed = i;
      break;
    }
  }
  return SSim(c.steps, b.towers.isNotEmpty && c.lit == full, c.crash, c.lit, missed, c.trail, c.crashX, c.crashY);
}

bool sgPasses(SBoard b, List<SBlock> prog) {
  final SSim s = sgRun(b, prog);
  return s.allLit && s.crash == 0;
}

// ---------------------------------------------------------------------------
// Hints

void _tok(List<SBlock> l, List<String> out) {
  for (final SBlock b in l) {
    switch (b.kind) {
      case SKind.forward:
        out.add('F');
        break;
      case SKind.left:
        out.add('L');
        break;
      case SKind.right:
        out.add('R');
        break;
      case SKind.act:
        out.add('A');
        break;
      case SKind.rep:
        out.add('REP${b.n}');
        _tok(b.body, out);
        out.add('END');
        break;
      case SKind.iff:
        out.add('IF');
        _tok(b.body, out);
        out.add('ELSE');
        _tok(b.els, out);
        out.add('END');
        break;
    }
  }
}

List<String> sgTokens(List<SBlock> l) {
  final List<String> out = <String>[];
  _tok(l, out);
  return out;
}

bool _isHeader(String t) => t != 'END' && t != 'ELSE';

class SPos {
  final SBlock? owner;
  final int branch;
  final int index;
  const SPos(this.owner, this.branch, this.index);
}

SPos? _walk(List<SBlock> list, SBlock? owner, int branch, List<int> cnt, int target) {
  for (int i = 0; i < list.length; i++) {
    if (cnt[0] == target) return SPos(owner, branch, i);
    final SBlock b = list[i];
    cnt[0]++;
    if (b.kind == SKind.rep) {
      final SPos? r = _walk(b.body, b, 0, cnt, target);
      if (r != null) return r;
      cnt[0]++;
    } else if (b.kind == SKind.iff) {
      final SPos? r = _walk(b.body, b, 0, cnt, target);
      if (r != null) return r;
      cnt[0]++;
      final SPos? r2 = _walk(b.els, b, 1, cnt, target);
      if (r2 != null) return r2;
      cnt[0]++;
    }
  }
  if (cnt[0] == target) return SPos(owner, branch, list.length);
  return null;
}

SBlock? _hdr(List<SBlock> list, List<int> cnt, int target) {
  for (final SBlock b in list) {
    if (cnt[0] == target) return b;
    cnt[0]++;
    if (b.kind == SKind.rep) {
      final SBlock? r = _hdr(b.body, cnt, target);
      if (r != null) return r;
      cnt[0]++;
    } else if (b.kind == SKind.iff) {
      final SBlock? r = _hdr(b.body, cnt, target);
      if (r != null) return r;
      cnt[0]++;
      final SBlock? r2 = _hdr(b.els, cnt, target);
      if (r2 != null) return r2;
      cnt[0]++;
    }
  }
  return null;
}

class SHint {
  final String text;
  final SBlock? bad;
  final SPos? at;
  final SKind? kind;
  const SHint(this.text, {this.bad, this.at, this.kind});
}

SHint sgHint(List<SBlock> ref, List<SBlock> prog) {
  final List<String> rf = sgTokens(ref);
  final List<String> pl = sgTokens(prog);
  int i = 0;
  while (i < rf.length && i < pl.length && rf[i] == pl[i]) {
    i++;
  }
  if (i >= rf.length && i >= pl.length) {
    return const SHint('Your blocks already follow the plan. Press RUN.');
  }
  final String? pTok = i < pl.length ? pl[i] : null;
  final String? rTok = i < rf.length ? rf[i] : null;
  if (pTok != null && _isHeader(pTok)) {
    final SBlock? bad = _hdr(prog, <int>[0], i);
    return SHint('The highlighted block is off track. Change it or delete it.', bad: bad);
  }
  if (rTok == null || !_isHeader(rTok)) {
    return const SHint('Compare your program with the goal again, block by block.');
  }
  final SPos? at = _walk(prog, null, 0, <int>[0], i);
  SKind k = SKind.forward;
  String name = 'FORWARD';
  if (rTok == 'L') {
    k = SKind.left;
    name = 'TURN LEFT';
  } else if (rTok == 'R') {
    k = SKind.right;
    name = 'TURN RIGHT';
  } else if (rTok == 'A') {
    k = SKind.act;
    name = 'ACTIVATE';
  } else if (rTok == 'IF') {
    k = SKind.iff;
    name = 'IF WALL AHEAD';
  } else if (rTok.startsWith('REP')) {
    k = SKind.rep;
    name = 'REPEAT ${rTok.substring(3)} (set the count to ${rTok.substring(3)})';
  }
  String where = '.';
  final SBlock? owner = at?.owner;
  if (owner != null) {
    if (owner.kind == SKind.rep) {
      where = ', inside the REPEAT.';
    } else {
      where = (at?.branch ?? 0) == 0 ? ', inside the IF part.' : ', inside the ELSE part.';
    }
  }
  return SHint('Next block: $name$where', at: at, kind: k);
}

// ---------------------------------------------------------------------------
// Board generation

List<List<bool>> _grid(int w, int h) => List<List<bool>>.generate(h, (int _) => List<bool>.filled(w, false));

void _scatter(Random rng, SBoard b, int count) {
  final SSim base = sgRun(b, b.ref);
  final Set<int> avoid = <int>{b.sy * b.w + b.sx};
  for (final SCell c in base.trail) {
    avoid.add(c.y * b.w + c.x);
  }
  for (final SCell c in b.towers) {
    avoid.add(c.y * b.w + c.x);
  }
  int placed = 0;
  int tries = 0;
  while (placed < count && tries < count * 10) {
    tries++;
    final int x = rng.nextInt(b.w);
    final int y = rng.nextInt(b.h);
    if (b.rock[y][x] || avoid.contains(y * b.w + x)) continue;
    b.rock[y][x] = true;
    if (sgPasses(b, b.ref)) {
      placed++;
    } else {
      b.rock[y][x] = false;
    }
  }
}

/// Finds a start cell where [ref] runs without crashing, and puts a tower on
/// every cell where the program uses ACTIVATE.
SBoard? _tryStart(Random rng, int w, int h, List<SBlock> ref, int minT, int maxT, int scatter) {
  for (int attempt = 0; attempt < 80; attempt++) {
    final int sx = rng.nextInt(w);
    final int sy = rng.nextInt(h);
    final int sd = rng.nextInt(4);
    final SBoard b = SBoard(w: w, h: h, rock: _grid(w, h), sx: sx, sy: sy, sdir: sd, towers: <SCell>[], fog: false, ref: ref);
    final SSim s = sgRun(b, ref);
    if (s.crash != 0) continue;
    final List<SCell> acts = <SCell>[];
    bool bad = false;
    for (final SStep st in s.steps) {
      final SBlock? blk = st.block;
      if (blk != null && blk.kind == SKind.act) {
        if (st.x == sx && st.y == sy) bad = true;
        for (final SCell c in acts) {
          if (c.x == st.x && c.y == st.y) bad = true;
        }
        acts.add(SCell(st.x, st.y));
      }
    }
    if (bad || acts.length < minT || acts.length > maxT) continue;
    b.towers.addAll(acts);
    if (!sgPasses(b, ref)) continue;
    _scatter(rng, b, scatter);
    return b;
  }
  return null;
}

SBoard? _genLinear(Random rng, int w, int h, int towersN) {
  final List<SBlock> ref = <SBlock>[];
  for (int t = 0; t < towersN; t++) {
    final int turn = t == 0 ? rng.nextInt(3) : 1 + rng.nextInt(2);
    if (turn == 1) ref.add(SBlock(SKind.left));
    if (turn == 2) ref.add(SBlock(SKind.right));
    final int m = 1 + rng.nextInt(3);
    for (int i = 0; i < m; i++) {
      ref.add(SBlock(SKind.forward));
    }
    ref.add(SBlock(SKind.act));
  }
  return _tryStart(rng, w, h, ref, towersN, towersN, 7);
}

const List<List<SKind>> _repTemplates = <List<SKind>>[
  <SKind>[SKind.forward, SKind.forward, SKind.act],
  <SKind>[SKind.forward, SKind.act],
  <SKind>[SKind.forward, SKind.right, SKind.forward, SKind.left, SKind.act],
  <SKind>[SKind.forward, SKind.forward, SKind.right, SKind.act],
  <SKind>[SKind.forward, SKind.left, SKind.forward, SKind.right, SKind.act],
  <SKind>[SKind.forward, SKind.forward, SKind.left, SKind.act],
];

const List<List<SKind>> _dbgTemplates = <List<SKind>>[
  <SKind>[SKind.forward, SKind.right, SKind.forward, SKind.left, SKind.act],
  <SKind>[SKind.forward, SKind.forward, SKind.right, SKind.act],
  <SKind>[SKind.forward, SKind.left, SKind.forward, SKind.right, SKind.act],
  <SKind>[SKind.forward, SKind.act, SKind.right],
];

SBoard? _genRepeat(Random rng, int w, int h, bool debug) {
  final List<List<SKind>> pool = debug ? _dbgTemplates : _repTemplates;
  final List<SKind> tpl = pool[rng.nextInt(pool.length)];
  final int n = 3 + (rng.nextInt(4) == 0 ? 1 : 0);
  final List<SBlock> ref = <SBlock>[];
  final int pre = rng.nextInt(3);
  if (pre == 1) ref.add(SBlock(rng.nextBool() ? SKind.left : SKind.right));
  if (pre == 2) ref.add(SBlock(SKind.forward));
  ref.add(SBlock(SKind.rep, n: n, body: <SBlock>[for (final SKind k in tpl) SBlock(k)]));
  return _tryStart(rng, w, h, ref, 3, 4, (w * h) ~/ 8);
}

SBlock _spiralRef(int n, bool fog) {
  if (fog) {
    return SBlock(SKind.rep, n: n, body: <SBlock>[
      SBlock(SKind.act),
      SBlock(SKind.iff, body: <SBlock>[SBlock(SKind.right)], els: <SBlock>[SBlock(SKind.forward)]),
    ]);
  }
  return SBlock(SKind.rep, n: n, body: <SBlock>[
    SBlock(SKind.iff, body: <SBlock>[SBlock(SKind.act), SBlock(SKind.right)], els: <SBlock>[SBlock(SKind.forward)]),
  ]);
}

/// A winding ridge path that only ever turns right at a wall. The reference
/// program is a wall follower, found by running it, so it always works.
SBoard? _genSpiral(Random rng, int w, int h, bool fog) {
  final List<List<bool>> rock = _grid(w, h);
  final List<List<bool>> seen = _grid(w, h);
  int x = rng.nextInt(w);
  int y = rng.nextInt(h);
  int dir = rng.nextInt(4);
  final int sx = x;
  final int sy = y;
  final int sd = dir;
  seen[y][x] = true;
  final List<SCell> path = <SCell>[SCell(x, y)];
  final List<SCell> corners = <SCell>[];
  for (int seg = 0; seg < 16; seg++) {
    int avail = 0;
    int cx = x;
    int cy = y;
    while (true) {
      final int nx = cx + sgDx[dir];
      final int ny = cy + sgDy[dir];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h || seen[ny][nx] || rock[ny][nx]) break;
      avail++;
      cx = nx;
      cy = ny;
    }
    if (avail < 1) break;
    final List<int> opts = <int>[];
    for (int len = 1; len <= avail; len++) {
      final int ex = x + sgDx[dir] * (len + 1);
      final int ey = y + sgDy[dir] * (len + 1);
      bool okEnd = true;
      if (ex >= 0 && ey >= 0 && ex < w && ey < h) {
        if (!rock[ey][ex] && seen[ey][ex]) okEnd = false;
      }
      if (okEnd) opts.add(len);
    }
    if (opts.isEmpty) break;
    final List<int> longer = opts.where((int l) => l >= 2).toList();
    final List<int> use = longer.isNotEmpty ? longer : opts;
    final int a = use[rng.nextInt(use.length)];
    final int b2 = use[rng.nextInt(use.length)];
    final int len = a > b2 ? a : b2;
    for (int i = 0; i < len; i++) {
      x += sgDx[dir];
      y += sgDy[dir];
      seen[y][x] = true;
      path.add(SCell(x, y));
    }
    final int ax = x + sgDx[dir];
    final int ay = y + sgDy[dir];
    if (ax >= 0 && ay >= 0 && ax < w && ay < h) rock[ay][ax] = true;
    corners.add(SCell(x, y));
    dir = (dir + 1) % 4;
  }
  if (corners.length < (fog ? 5 : 4) || path.length < (fog ? 18 : 12)) return null;
  final List<SCell> towers = <SCell>[];
  if (fog) {
    final List<SCell> rest = path.sublist(1, path.length - 1)..shuffle(rng);
    towers.add(rest[0]);
    towers.add(rest[1]);
    towers.add(path[path.length - 1]);
  } else {
    final List<SCell> cs = List<SCell>.from(corners)..shuffle(rng);
    towers.addAll(cs.take(3));
  }
  final SBoard b = SBoard(w: w, h: h, rock: rock, sx: sx, sy: sy, sdir: sd, towers: towers, fog: fog, ref: <SBlock>[]);
  int found = -1;
  for (int n = 1; n <= 40; n++) {
    b.ref.clear();
    b.ref.add(_spiralRef(n, fog));
    if (sgPasses(b, b.ref)) {
      found = n;
      break;
    }
  }
  if (found < 0 || found > 36) return null;
  _scatter(rng, b, fog ? 2 : 4);
  return b;
}

SBoard? _genStage(Random rng, int stage) {
  switch (stage) {
    case 0:
      return _genLinear(rng, 6, 6, 2);
    case 1:
      return _genRepeat(rng, 7, 7, false);
    case 2:
      return _genSpiral(rng, 8, 8, false);
    case 4:
      return _genRepeat(rng, 7, 7, true);
    default:
      return _genSpiral(rng, 9, 9, true);
  }
}

SBoard _fallback(bool fog, bool withRepeat) {
  final List<SBlock> ref = <SBlock>[];
  List<SCell> towers;
  if (withRepeat) {
    ref.add(SBlock(SKind.forward));
    ref.add(SBlock(SKind.rep, n: 3, body: <SBlock>[
      SBlock(SKind.forward),
      SBlock(SKind.right),
      SBlock(SKind.forward),
      SBlock(SKind.left),
      SBlock(SKind.act),
    ]));
    towers = <SCell>[const SCell(2, 1), const SCell(3, 2), const SCell(4, 3)];
  } else {
    ref.addAll(<SBlock>[
      SBlock(SKind.forward),
      SBlock(SKind.forward),
      SBlock(SKind.act),
      SBlock(SKind.right),
      SBlock(SKind.forward),
      SBlock(SKind.forward),
      SBlock(SKind.act),
    ]);
    towers = <SCell>[const SCell(2, 0), const SCell(2, 2)];
  }
  return SBoard(w: 7, h: 7, rock: _grid(7, 7), sx: 0, sy: 0, sdir: 1, towers: towers, fog: fog, ref: ref);
}

/// A solvable board for the given stage index (0 to 5; 3 is the circuit).
SBoard sgGenerate(Random rng, int stage) {
  for (int i = 0; i < 40; i++) {
    final SBoard? b = _genStage(rng, stage);
    if (b != null) return b;
  }
  for (int i = 0; i < 300; i++) {
    final SBoard? b = _genStage(Random(9001 + i * 7 + stage), stage);
    if (b != null) return b;
  }
  return _fallback(stage == 5, stage == 4);
}

// ---------------------------------------------------------------------------
// Debug puzzles

class SFix {
  final int op; // 0 change kind, 1 set count, 2 remove, 3 add after, 4 add before
  final int arg;
  final String label;
  const SFix(this.op, this.arg, this.label);
}

class SDebug {
  final SBoard board;
  final List<SBlock> buggy;
  final int badIdx;
  final int kind; // 0 wrong turn, 1 wrong count, 2 missing ACTIVATE
  final String explain;
  SDebug(this.board, this.buggy, this.badIdx, this.kind, this.explain);
}

bool _fails(SBoard b, List<SBlock> p) => !sgPasses(b, p);

SDebug? _mutate(Random rng, SBoard b) {
  final List<int> order = <int>[0, 1, 2]..shuffle(rng);
  for (final int m in order) {
    final List<SBlock> p = sgClone(b.ref);
    final List<SBlock> flat = sgFlatten(p);
    if (m == 0) {
      final List<SBlock> turns = flat.where((SBlock x) => x.kind == SKind.left || x.kind == SKind.right).toList();
      if (turns.isEmpty) continue;
      final SBlock t = turns[rng.nextInt(turns.length)];
      t.kind = t.kind == SKind.left ? SKind.right : SKind.left;
      if (_fails(b, p)) {
        return SDebug(b, p, sgFlatten(p).indexOf(t), 0, 'One turn pointed the wrong way, so the bot left the path.');
      }
    } else if (m == 1) {
      final List<SBlock> reps = flat.where((SBlock x) => x.kind == SKind.rep).toList();
      if (reps.isEmpty) continue;
      final SBlock r = reps[rng.nextInt(reps.length)];
      final int orig = r.n;
      final List<int> deltas = <int>[-1, -2, 1]..shuffle(rng);
      for (final int d in deltas) {
        final int n2 = orig + d;
        if (n2 < 1 || n2 > 9) continue;
        r.n = n2;
        if (_fails(b, p)) {
          return SDebug(b, p, sgFlatten(p).indexOf(r), 1, 'The REPEAT count was wrong, so the bot did not finish the route.');
        }
      }
      r.n = orig;
    } else {
      final List<SBlock> acts = flat.where((SBlock x) => x.kind == SKind.act).toList()..shuffle(rng);
      for (final SBlock a in acts) {
        final SLoc? loc = sgLocate(p, a);
        if (loc == null || loc.idx < 1) continue;
        final SBlock prev = loc.list[loc.idx - 1];
        loc.list.removeAt(loc.idx);
        if (_fails(b, p)) {
          return SDebug(b, p, sgFlatten(p).indexOf(prev), 2, 'An ACTIVATE block was missing, so a tower stayed dark.');
        }
        loc.list.insert(loc.idx, a);
      }
    }
  }
  return null;
}

SDebug sgGenDebug(Random rng) {
  for (int i = 0; i < 60; i++) {
    final SBoard? b = _genStage(rng, 4);
    if (b == null) continue;
    final SDebug? d = _mutate(rng, b);
    if (d != null) return d;
  }
  for (int i = 0; i < 200; i++) {
    final Random r = Random(4242 + i * 13);
    final SBoard? b = _genStage(r, 4);
    if (b == null) continue;
    final SDebug? d = _mutate(r, b);
    if (d != null) return d;
  }
  final SBoard fb = _fallback(false, true);
  final SDebug? d = _mutate(Random(5), fb);
  if (d != null) return d;
  // Last resort: shorten the fallback REPEAT by hand.
  final List<SBlock> p = sgClone(fb.ref);
  final SBlock rep = p[1];
  rep.n = 2;
  return SDebug(fb, p, 1, 1, 'The REPEAT count was wrong, so the bot did not finish the route.');
}

List<SFix> sgFixCandidates(SBlock b) {
  final List<SFix> out = <SFix>[];
  final int actI = SKind.act.index;
  switch (b.kind) {
    case SKind.forward:
      out.add(SFix(0, SKind.left.index, 'Change it to TURN LEFT'));
      out.add(SFix(0, SKind.right.index, 'Change it to TURN RIGHT'));
      out.add(SFix(0, actI, 'Change it to ACTIVATE'));
      out.add(const SFix(2, 0, 'Remove this block'));
      out.add(SFix(3, actI, 'Add ACTIVATE after it'));
      break;
    case SKind.left:
      out.add(SFix(0, SKind.right.index, 'Change it to TURN RIGHT'));
      out.add(SFix(0, SKind.forward.index, 'Change it to FORWARD'));
      out.add(const SFix(2, 0, 'Remove this block'));
      out.add(SFix(3, actI, 'Add ACTIVATE after it'));
      break;
    case SKind.right:
      out.add(SFix(0, SKind.left.index, 'Change it to TURN LEFT'));
      out.add(SFix(0, SKind.forward.index, 'Change it to FORWARD'));
      out.add(const SFix(2, 0, 'Remove this block'));
      out.add(SFix(3, actI, 'Add ACTIVATE after it'));
      break;
    case SKind.act:
      out.add(SFix(0, SKind.forward.index, 'Change it to FORWARD'));
      out.add(SFix(0, SKind.left.index, 'Change it to TURN LEFT'));
      out.add(const SFix(2, 0, 'Remove this block'));
      break;
    case SKind.rep:
      for (final int d in <int>[-2, -1, 1, 2]) {
        final int n2 = b.n + d;
        if (n2 >= 1 && n2 <= 9) out.add(SFix(1, n2, 'Repeat $n2 times'));
      }
      out.add(const SFix(2, 0, 'Remove this block'));
      break;
    case SKind.iff:
      out.add(const SFix(2, 0, 'Remove this block'));
      break;
  }
  return out;
}

List<SBlock> sgApplyFix(List<SBlock> prog, int flatIdx, SFix f) {
  final List<SBlock> p = sgClone(prog);
  final List<SBlock> flat = sgFlatten(p);
  if (flatIdx < 0 || flatIdx >= flat.length) return p;
  final SBlock t = flat[flatIdx];
  final SLoc? loc = sgLocate(p, t);
  switch (f.op) {
    case 0:
      t.kind = SKind.values[f.arg];
      break;
    case 1:
      t.n = f.arg;
      break;
    case 2:
      if (loc != null) loc.list.removeAt(loc.idx);
      break;
    case 3:
      if (loc != null) loc.list.insert(loc.idx + 1, SBlock(SKind.values[f.arg]));
      break;
    case 4:
      if (loc != null) loc.list.insert(loc.idx, SBlock(SKind.values[f.arg]));
      break;
  }
  return p;
}

/// Three fixes to offer for the tapped block. When the faulty block is
/// tapped, at least one of them really repairs the program.
List<SFix> sgPickFixes(Random rng, SDebug d, int flatIdx) {
  final List<SBlock> flat = sgFlatten(d.buggy);
  if (flatIdx < 0 || flatIdx >= flat.length) return <SFix>[];
  final List<SFix> cands = sgFixCandidates(flat[flatIdx]);
  final List<SFix> good = <SFix>[];
  final List<SFix> bad = <SFix>[];
  for (final SFix f in cands) {
    if (sgPasses(d.board, sgApplyFix(d.buggy, flatIdx, f))) {
      good.add(f);
    } else {
      bad.add(f);
    }
  }
  good.shuffle(rng);
  bad.shuffle(rng);
  final List<SFix> out = <SFix>[];
  if (good.isNotEmpty) out.add(good.first);
  for (final SFix f in bad) {
    if (out.length >= 3) break;
    out.add(f);
  }
  for (final SFix f in good.skip(1)) {
    if (out.length >= 3) break;
    out.add(f);
  }
  out.shuffle(rng);
  return out;
}

// ---------------------------------------------------------------------------
// Circuits

const List<String> sgGateNames = <String>['AND', 'OR', 'NOT', 'XOR'];

class SGate {
  final int type; // 0 AND, 1 OR, 2 NOT, 3 XOR
  final int a;
  final int b;
  const SGate(this.type, this.a, this.b);
}

class SCircuit {
  final int k;
  final List<SGate> gates;
  SCircuit(this.k, this.gates);

  int get nodes => k + gates.length;

  List<bool> eval(List<bool> sw) {
    final List<bool> v = List<bool>.filled(nodes, false);
    for (int i = 0; i < k; i++) {
      v[i] = i < sw.length ? sw[i] : false;
    }
    for (int g = 0; g < gates.length; g++) {
      final SGate gt = gates[g];
      final bool x = v[gt.a];
      final bool y = gt.b >= 0 ? v[gt.b] : false;
      bool r;
      switch (gt.type) {
        case 0:
          r = x && y;
          break;
        case 1:
          r = x || y;
          break;
        case 2:
          r = !x;
          break;
        default:
          r = x != y;
          break;
      }
      v[k + g] = r;
    }
    return v;
  }

  bool lamp(List<bool> sw) => eval(sw)[nodes - 1];

  String nodeName(int i) => String.fromCharCode(65 + i);

  String _wrap(int j) => j < k ? nodeName(j) : '(${expr(j)})';

  String expr(int i) {
    if (i < k) return nodeName(i);
    final SGate g = gates[i - k];
    if (g.type == 2) return 'NOT ${_wrap(g.a)}';
    return '${_wrap(g.a)} ${sgGateNames[g.type]} ${_wrap(g.b)}';
  }

  String get lampExpr => expr(nodes - 1);
}

List<bool> sgBits(int mask, int k) => List<bool>.generate(k, (int i) => (mask >> i) & 1 == 1);

int sgPop(int mask) {
  int c = 0;
  int m = mask;
  while (m > 0) {
    c += m & 1;
    m >>= 1;
  }
  return c;
}

SCircuit _buildCircuit(Random rng, int k, int nots, bool xor) {
  final List<int> pool = List<int>.generate(k, (int i) => i)..shuffle(rng);
  final List<SGate> gates = <SGate>[];
  int bin = k - 1;
  int left = nots;
  bool xorLeft = xor;
  while (bin > 0 || left > 0) {
    final bool doNot = left > 0 && (bin == 0 || rng.nextInt(3) == 0);
    if (doNot) {
      final int a = pool.removeAt(rng.nextInt(pool.length));
      gates.add(SGate(2, a, -1));
      pool.add(k + gates.length - 1);
      left--;
    } else {
      final int a = pool.removeAt(rng.nextInt(pool.length));
      final int b = pool.removeAt(rng.nextInt(pool.length));
      int type = rng.nextBool() ? 0 : 1;
      if (xorLeft && (bin == 1 || rng.nextBool())) {
        type = 3;
        xorLeft = false;
      }
      gates.add(SGate(type, a, b));
      pool.add(k + gates.length - 1);
      bin--;
    }
  }
  return SCircuit(k, gates);
}

/// How many switches are ON in the cheapest pattern that lights the lamp, or
/// -1 when no pattern does.
int sgMinOn(SCircuit c) {
  int best = -1;
  for (int m = 0; m < (1 << c.k); m++) {
    if (c.lamp(sgBits(m, c.k))) {
      final int p = sgPop(m);
      if (best < 0 || p < best) best = p;
    }
  }
  return best;
}

int _onCount(SCircuit c) {
  int n = 0;
  for (int m = 0; m < (1 << c.k); m++) {
    if (c.lamp(sgBits(m, c.k))) n++;
  }
  return n;
}

/// A small circuit for the predict rounds: 3 switches, AND, OR and NOT.
SCircuit sgGenPredictCircuit(Random rng) {
  for (int i = 0; i < 60; i++) {
    final SCircuit c = _buildCircuit(rng, 3, 1 + rng.nextInt(2), false);
    final int on = _onCount(c);
    if (on >= 2 && on <= 6) return c;
  }
  return SCircuit(3, const <SGate>[SGate(0, 0, 1), SGate(2, 2, -1), SGate(1, 3, 4)]);
}

/// A bigger circuit for the make round: 4 switches, sometimes with XOR. The
/// lamp is dark with every switch off and can be lit.
SCircuit sgGenMakeCircuit(Random rng) {
  for (int i = 0; i < 120; i++) {
    final SCircuit c = _buildCircuit(rng, 4, rng.nextInt(2), rng.nextInt(10) < 6);
    final int on = _onCount(c);
    if (on < 2 || on > 10) continue;
    if (c.lamp(sgBits(0, 4))) continue;
    final int m = sgMinOn(c);
    if (m >= 1 && m <= 3) return c;
  }
  return SCircuit(4, const <SGate>[SGate(0, 0, 1), SGate(1, 2, 3), SGate(1, 4, 5)]);
}

/// A switch pattern (bit mask) different from [not], optionally with a given
/// lamp result.
int sgRandomPattern(Random rng, SCircuit c, {int not = -1, int want = -1}) {
  final int total = 1 << c.k;
  for (int i = 0; i < 80; i++) {
    final int m = rng.nextInt(total);
    if (m == not) continue;
    if (want >= 0 && (c.lamp(sgBits(m, c.k)) ? 1 : 0) != want) continue;
    return m;
  }
  for (int m = 0; m < total; m++) {
    if (m != not) return m;
  }
  return 0;
}

/// Positions for every circuit node (switches, then gates) and, as the last
/// entry, the lamp.
List<Offset> sgCircuitLayout(SCircuit c, Rect r) {
  final int n = c.nodes;
  final List<int> depth = List<int>.filled(n, 0);
  for (int g = 0; g < c.gates.length; g++) {
    final SGate gt = c.gates[g];
    final int da = depth[gt.a];
    final int db = gt.b >= 0 ? depth[gt.b] : 0;
    depth[c.k + g] = 1 + (da > db ? da : db);
  }
  final int dMax = depth[n - 1];
  final double left = r.left + 24;
  final double right = r.right - 30;
  final List<double> ys = List<double>.filled(n + 1, 0);
  final double span = r.height - 56;
  for (int i = 0; i < c.k; i++) {
    ys[i] = r.top + 28 + (c.k <= 1 ? span / 2 : span * i / (c.k - 1));
  }
  for (int g = 0; g < c.gates.length; g++) {
    final SGate gt = c.gates[g];
    final double ya = ys[gt.a];
    final double yb = gt.b >= 0 ? ys[gt.b] : ya;
    ys[c.k + g] = (ya + yb) / 2;
  }
  for (int d = 1; d <= dMax; d++) {
    final List<int> col = <int>[];
    for (int g = 0; g < c.gates.length; g++) {
      if (depth[c.k + g] == d) col.add(c.k + g);
    }
    col.sort((int a, int b) => ys[a].compareTo(ys[b]));
    for (int j = 1; j < col.length; j++) {
      if (ys[col[j]] - ys[col[j - 1]] < 46) ys[col[j]] = ys[col[j - 1]] + 46;
    }
    for (final int id in col) {
      if (ys[id] > r.bottom - 24) ys[id] = r.bottom - 24;
      if (ys[id] < r.top + 24) ys[id] = r.top + 24;
    }
  }
  ys[n] = ys[n - 1];
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < n; i++) {
    final int d = i < c.k ? 0 : depth[i];
    out.add(Offset(left + (right - left) * d / (dMax + 1), ys[i]));
  }
  out.add(Offset(right, ys[n]));
  return out;
}
