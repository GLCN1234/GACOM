part of 'darkom_arena_logic.dart';

// ---------------------------------------------------------------------------
// Map

/// A small symmetric arena. Every client builds the identical map from the
/// room code, so the code string is the only thing that has to be shared.
class ArenaMap {
  final List<Rect> blocks;
  ArenaMap._(this.blocks);

  static const List<Offset> cornerSpawns = <Offset>[Offset(140, 140), Offset(1260, 860), Offset(1260, 140), Offset(140, 860)];
  static const List<Offset> duelSpawns = <Offset>[Offset(140, 500), Offset(1260, 500)];

  factory ArenaMap.generate(String code) {
    int s = 7919;
    for (final int c in code.codeUnits) {
      s = (s * 131 + c) % 2147483647;
    }
    if (s <= 0) s = 1;
    double next() {
      s = (s * 48271) % 2147483647;
      return s / 2147483647;
    }

    final Rect pillar = Rect.fromCenter(center: const Offset(kArW / 2, kArH / 2), width: 70, height: 70);
    final List<Offset> keep = <Offset>[...cornerSpawns, ...duelSpawns];
    final List<Rect> quad = <Rect>[];
    int tries = 0;
    while (quad.length < 6 && tries < 140) {
      tries++;
      final double w = (46 + next() * 100).roundToDouble();
      final double h = (40 + next() * 84).roundToDouble();
      final double x0 = (50 + next() * (600 - w)).roundToDouble();
      final double y0 = (50 + next() * (400 - h)).roundToDouble();
      final Rect r = Rect.fromLTWH(x0, y0, w, h);
      bool ok = !r.inflate(40).overlaps(pillar);
      if (ok) {
        for (final Rect q in quad) {
          if (r.inflate(40).overlaps(q)) {
            ok = false;
            break;
          }
        }
      }
      if (ok) {
        for (final Offset sp in keep) {
          if (r.inflate(84).contains(sp)) {
            ok = false;
            break;
          }
        }
      }
      if (ok) quad.add(r);
    }
    final List<Rect> all = <Rect>[];
    for (final Rect r in quad) {
      all.add(r);
      all.add(Rect.fromLTRB(kArW - r.right, r.top, kArW - r.left, r.bottom));
      all.add(Rect.fromLTRB(r.left, kArH - r.bottom, r.right, kArH - r.top));
      all.add(Rect.fromLTRB(kArW - r.right, kArH - r.bottom, kArW - r.left, kArH - r.top));
    }
    all.add(pillar);
    return ArenaMap._(all);
  }

  static Offset spawnFor(int idx, String mode, int count) {
    if (mode != 'squad') return duelSpawns[idx % 2];
    if (count <= 2) return cornerSpawns[idx % 2];
    return cornerSpawns[idx % 4];
  }

  static double spawnFace(Offset p) => atan2(kArH / 2 - p.dy, kArW / 2 - p.dx);

  bool circleHits(double x, double y, double r) {
    if (x - r < 0 || y - r < 0 || x + r > kArW || y + r > kArH) return true;
    for (final Rect b in blocks) {
      final double nx = x < b.left ? b.left : (x > b.right ? b.right : x);
      final double ny = y < b.top ? b.top : (y > b.bottom ? b.bottom : y);
      final double dx = x - nx;
      final double dy = y - ny;
      if (dx * dx + dy * dy < r * r) return true;
    }
    return false;
  }

  Offset move(double x, double y, double dx, double dy, double r) {
    final double len = sqrt(dx * dx + dy * dy);
    final int steps = len > 8 ? (len / 8).ceil() : 1;
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

  /// True when a bolt or axe at (x, y) with radius [pad] is inside a wall.
  bool wallAt(double x, double y, double pad) {
    if (x < 0 || y < 0 || x > kArW || y > kArH) return true;
    for (final Rect b in blocks) {
      if (x > b.left - pad && x < b.right + pad && y > b.top - pad && y < b.bottom + pad) return true;
    }
    return false;
  }

  bool lineClear(double x0, double y0, double x1, double y1) {
    final double dx = x1 - x0;
    final double dy = y1 - y0;
    final double len = sqrt(dx * dx + dy * dy);
    final int n = (len / 10).ceil();
    for (int i = 1; i < n; i++) {
      final double f = i / n;
      final double px = x0 + dx * f;
      final double py = y0 + dy * f;
      for (final Rect b in blocks) {
        if (px > b.left && px < b.right && py > b.top && py < b.bottom) return false;
      }
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Entities

class ArenaPlayer {
  final String id;
  DarkomLook look;
  ArenaPlayer(this.id, this.look);

  bool present = false;
  bool inMatch = false;
  bool ready = false;
  bool alive = true;
  String pick = 'sword';
  String weapon = 'sword';
  double lastSeen = 0;
  double absentT = 0;

  double x = 0;
  double y = 0;
  double tx = 0;
  double ty = 0;
  double tvx = 0;
  double tvy = 0;
  double vx = 0;
  double vy = 0;
  double stAge = 0;
  double stClock = 0;
  bool gotState = false;
  double aim = 0;
  double face = 1;
  double hp = kArHp;
  int flags = 0;
  double phase = 0;
  bool moving = false;

  int wins = 0;
  int elimPts = 0;

  String swingKind = '';
  double swingAng = 0;
  double swingT = -1;
  double swingDur = 0.25;
  double flash = 0;

  // remote rate limits
  final Map<String, double> lastAtk = <String, double>{};
  double tokens = 7;
  double tokClock = 0;
  double mana = 100;
  double manaClock = 0;

  String emote = '';
  double emoteT = 0;

  String get name => look.name;
}

class ArProj {
  final String owner;
  double x;
  double y;
  final double vx;
  final double vy;
  double life;
  final double dmg;
  final double r;
  final int kind;
  bool dead = false;
  ArProj(this.owner, this.x, this.y, this.vx, this.vy, this.life, this.dmg, this.r, this.kind);
}

class ArAxe {
  final String owner;
  final String id;
  double x;
  double y;
  double dx;
  double dy;
  double dist = 0;
  final double maxDist;
  final double dmg;
  bool out = true;
  double spin = 0;
  double life = 3;
  bool dead = false;
  bool hitOut = false;
  bool hitBack = false;
  ArAxe(this.owner, this.id, this.x, this.y, this.dx, this.dy, this.maxDist, this.dmg);
}

/// A hit shape that will be tested against the local player when [t] runs out.
class ArPending {
  final String owner;
  final String id;
  double t;
  final double ox;
  final double oy;
  final double ang;
  final bool circle;
  final double range;
  final double half;
  final double dmg;
  final double kb;
  final double stun;
  final bool melee;
  ArPending(this.owner, this.id, this.t, this.ox, this.oy, this.ang, this.circle, this.range, this.half, this.dmg, this.kb, this.stun, this.melee);
}

class ArCharge {
  final String owner;
  final String id;
  double t = 0.38;
  bool hit = false;
  ArCharge(this.owner, this.id);
}

class ArFx {
  /// 0 ring, 1 arc, 2 flash, 3 telegraph (shown during the delay)
  final int kind;
  final double x;
  final double y;
  final double a;
  final double r;
  final double sweep;
  double life;
  final double maxLife;
  double delay;
  final double warn;
  final Color color;
  ArFx(this.kind, this.x, this.y, this.a, this.r, this.sweep, this.life, this.color, this.delay)
      : maxLife = life,
        warn = delay;
}

class ArPart {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  ArPart(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color) : maxLife = life;
}

class ArText {
  final double x;
  double y;
  final String text;
  double life;
  final double maxLife;
  final Color color;
  final double size;
  ArText(this.x, this.y, this.text, this.life, this.color, this.size) : maxLife = life;
}

