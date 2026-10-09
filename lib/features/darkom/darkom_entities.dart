import 'dart:ui';

/// Plain data objects for the things that live in a Darkom City run.

class DEnemy {
  final int id;

  /// shade | spitter | brute | wraith | bounty | echo
  String type;
  double x;
  double y;
  double hp;
  double maxHp;
  double r;
  double speed;
  double dmg;
  double face = 0;
  double vx = 0;
  double vy = 0;
  double spawnT = 0.55;
  double cd = 1.0;

  // Telegraph: shape 0 none, 1 circle on self, 2 circle on locked point,
  // 3 line, 4 sector, 5 fan of three lines.
  double tele = 0;
  double teleMax = 0;
  int tShape = 0;
  double tR = 0;
  double tA = 0;
  double tW = 0;
  int atk = 0;
  double ax = 0;
  double ay = 0;
  bool tgtCourier = false;

  double stun = 0;
  double flash = 0;
  double phase = 0;
  bool moving = false;
  bool aggro = false;
  double blinkCd = 2.5;
  double blinkT = 0;
  double bx = 0;
  double by = 0;
  double losT = 0;
  bool losOk = true;
  double detour = 0;
  double detourDir = 1;
  double stuckT = 0;
  double lastX = 0;
  double lastY = 0;
  bool alive = true;
  bool bounty = false;
  bool enraged = false;
  String name = '';

  // Echo only.
  String weapon = 'sword';
  double dashT = 0;
  double dashCd = 2.0;
  double dashVx = 0;
  double dashVy = 0;
  bool dashHurts = false;
  bool dashHit = false;
  double swingT = -1;
  double wantAttack = 0;
  int nextEvent = 0;
  int dashIdx = 0;
  int atkCount = 0;

  DEnemy(this.id, this.type, this.x, this.y, double hp0, this.r, this.speed, this.dmg)
      : hp = hp0,
        maxHp = hp0 {
    lastX = x;
    lastY = y;
  }
}

class DProj {
  double x;
  double y;
  double vx;
  double vy;
  double dmg;
  double r;
  double life;
  bool hostile;

  /// 0 spit, 1 hero bolt, 2 hostile magic, 3 reflected
  int kind;
  DProj(this.x, this.y, this.vx, this.vy, this.dmg, this.r, this.life, this.hostile, this.kind);
}

/// A thrown boomerang axe. Hurts on the way out and on the way back.
class DAxe {
  double x;
  double y;
  double dx;
  double dy;
  double dist = 0;
  final double maxDist;
  final double speed;
  final double dmg;
  final bool hostile;
  final int ownerId;
  bool out = true;
  double spin = 0;
  bool dead = false;
  bool heroHit = false;
  final Set<int> hit = <int>{};
  DAxe(this.x, this.y, this.dx, this.dy, this.maxDist, this.speed, this.dmg, this.hostile, this.ownerId);
}

class DPart {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double maxLife;
  final double size;
  final Color color;
  DPart(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color) : maxLife = life;
}

class DText {
  double x;
  double y;
  final String text;
  double life;
  final double maxLife;
  final Color color;
  final double size;
  DText(this.x, this.y, this.text, this.life, this.color, this.size) : maxLife = life;
}

/// A short lived visual: 0 ring, 1 arc, 2 beam, 3 flash disc.
class DFx {
  final int kind;
  double x;
  double y;
  final double a;
  final double r;
  final double sweep;
  double life;
  final double maxLife;
  final Color color;
  DFx(this.kind, this.x, this.y, this.a, this.r, this.sweep, this.life, this.color) : maxLife = life;
}

class DPick {
  double x;
  double y;
  double life = 25;
  DPick(this.x, this.y);
}

class DCourier {
  double x;
  double y;
  double hp = 100;
  final double maxHp = 100;
  double downT = 0;
  double hurtT = 0;
  double phase = 0;
  bool moving = false;
  double face = 1;
  double flash = 0;
  final String name;
  double farT = 0;
  DCourier(this.x, this.y, this.name);
}

class DToast {
  final String who;
  final String text;
  final int colorValue;
  final double dur;
  DToast(this.who, this.text, this.colorValue, this.dur);
}

class DLater {
  double t;
  final void Function() fn;
  DLater(this.t, this.fn);
}
