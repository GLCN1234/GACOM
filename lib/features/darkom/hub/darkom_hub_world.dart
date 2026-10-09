import 'dart:math';
import 'package:flutter/material.dart';
import '../darkom_look.dart';
import 'darkom_hub_net.dart';

const Color kHubCyan = Color(0xFF00E5FF);
const Color kHubMagenta = Color(0xFFFF2E93);
const Color kHubViolet = Color(0xFF7C4DFF);
const Color kHubAmber = Color(0xFFFFB300);
const Color kHubGreen = Color(0xFF00E676);
const Color kHubInk = Color(0xFF05060A);
const Color kHubPanel = Color(0xFF0B0F1C);

/// A landmark you can walk into.
class HubPortal {
  final String id;
  final String label;
  final String hint;
  final double x;
  final double y;
  final Color color;
  final IconData icon;
  const HubPortal({required this.id, required this.label, required this.hint, required this.x, required this.y, required this.color, required this.icon});
}

/// A solid box on the plaza. [r] is the footprint on the ground, [h] is how
/// tall it looks.
class HubBlock {
  final Rect r;
  final double h;
  final String kind;
  final Color accent;
  final Color wall;
  final String sign;
  final String portal;
  HubBlock(this.r, this.h, this.kind, this.accent, {this.wall = const Color(0xFF141A2C), this.sign = '', this.portal = ''});
}

class HubCircle {
  final double x;
  final double y;
  final double r;
  const HubCircle(this.x, this.y, this.r);
}

class HubEmote {
  final String label;
  final String say;
  final IconData icon;
  const HubEmote(this.label, this.say, this.icon);
}

const List<HubEmote> kHubEmotes = <HubEmote>[
  HubEmote('Wave', 'Hello!', Icons.waving_hand_rounded),
  HubEmote('Laugh', 'Haha!', Icons.sentiment_very_satisfied_rounded),
  HubEmote('GG', 'GG!', Icons.emoji_events_rounded),
  HubEmote('Salute', 'Salute!', Icons.military_tech_rounded),
  HubEmote('Dance', 'Let us dance!', Icons.music_note_rounded),
  HubEmote('Point', 'Over here!', Icons.north_east_rounded),
];

class HubBubble {
  final String text;
  final int untilMs;
  const HubBubble(this.text, this.untilMs);
}

class HubEmoteShow {
  final int index;
  final int startMs;
  const HubEmoteShow(this.index, this.startMs);
}

/// The plaza layout: Neon Plaza, about 1800 by 1300 units.
class HubWorld {
  static const double width = 1800;
  static const double height = 1300;
  static const double radius = 14;
  static const double minX = 36;
  static const double maxX = 1764;
  static const double minY = 110;
  static const double maxY = 1250;
  static const double spawnX = 900;
  static const double spawnY = 930;
  static const double portalReach = 72;

  static const HubCircle fountain = HubCircle(900, 660, 85);

  static const List<HubPortal> portals = <HubPortal>[
    HubPortal(id: 'story', label: 'STORY GATE', hint: 'Missions, daily jobs and the story', x: 900, y: 262, color: kHubCyan, icon: Icons.location_city_rounded),
    HubPortal(id: 'arena', label: 'ARENA GATE', hint: 'Challenge a player to a 1v1 duel', x: 1640, y: 622, color: kHubMagenta, icon: Icons.sports_martial_arts_rounded),
    HubPortal(id: 'squad', label: 'SQUAD HALL', hint: 'Team up with your house', x: 160, y: 622, color: kHubGreen, icon: Icons.groups_rounded),
    HubPortal(id: 'locker', label: 'LOCKER', hint: 'Change how your hero looks', x: 380, y: 1112, color: kHubViolet, icon: Icons.checkroom_rounded),
    HubPortal(id: 'notice', label: 'NOTICE BOARD', hint: 'Plaza rules and safety tips', x: 1400, y: 1092, color: kHubAmber, icon: Icons.campaign_rounded),
  ];

  static final List<HubBlock> blocks = _build();

  static List<HubBlock> _build() {
    final List<HubBlock> b = <HubBlock>[
      HubBlock(Rect.fromLTWH(700, 100, 400, 90), 120, 'gate', kHubCyan, wall: const Color(0xFF101A2E), sign: 'STORY GATE', portal: 'story'),
      HubBlock(Rect.fromLTWH(1540, 420, 200, 110), 100, 'gate', kHubMagenta, wall: const Color(0xFF1E1226), sign: 'ARENA', portal: 'arena'),
      HubBlock(Rect.fromLTWH(60, 420, 200, 110), 100, 'gate', kHubGreen, wall: const Color(0xFF0F1F1C), sign: 'SQUAD HALL', portal: 'squad'),
      HubBlock(Rect.fromLTWH(260, 960, 240, 80), 84, 'gate', kHubViolet, wall: const Color(0xFF181430), sign: 'LOCKER', portal: 'locker'),
      HubBlock(Rect.fromLTWH(1320, 980, 160, 40), 70, 'board', kHubAmber, wall: const Color(0xFF1B1710), sign: 'NOTICES', portal: 'notice'),
      HubBlock(Rect.fromLTWH(400, 330, 170, 56), 66, 'stall', kHubAmber, wall: const Color(0xFF201A12), sign: 'RAMEN'),
      HubBlock(Rect.fromLTWH(1230, 330, 170, 56), 66, 'stall', kHubMagenta, wall: const Color(0xFF241420), sign: 'ARCADE'),
      HubBlock(Rect.fromLTWH(420, 800, 150, 56), 66, 'stall', kHubCyan, wall: const Color(0xFF10202A), sign: 'GADGETS'),
      HubBlock(Rect.fromLTWH(1240, 820, 150, 56), 66, 'stall', kHubGreen, wall: const Color(0xFF10241A), sign: 'TEA'),
      HubBlock(Rect.fromLTWH(790, 782, 70, 18), 14, 'bench', kHubCyan),
      HubBlock(Rect.fromLTWH(940, 782, 70, 18), 14, 'bench', kHubCyan),
      HubBlock(Rect.fromLTWH(790, 540, 70, 18), 14, 'bench', kHubCyan),
      HubBlock(Rect.fromLTWH(940, 540, 70, 18), 14, 'bench', kHubCyan),
      HubBlock(Rect.fromLTWH(650, 990, 44, 44), 34, 'crate', kHubAmber),
      HubBlock(Rect.fromLTWH(700, 1010, 40, 40), 30, 'crate', kHubAmber),
      HubBlock(Rect.fromLTWH(1120, 990, 44, 44), 34, 'crate', kHubAmber),
      HubBlock(Rect.fromLTWH(1500, 760, 40, 40), 30, 'crate', kHubAmber),
      HubBlock(Rect.fromLTWH(300, 640, 40, 40), 30, 'crate', kHubAmber),
      HubBlock(Rect.fromLTWH(600, 520, 54, 30), 26, 'planter', kHubGreen),
      HubBlock(Rect.fromLTWH(1150, 520, 54, 30), 26, 'planter', kHubGreen),
      HubBlock(Rect.fromLTWH(600, 1150, 54, 30), 26, 'planter', kHubGreen),
      HubBlock(Rect.fromLTWH(1150, 1150, 54, 30), 26, 'planter', kHubGreen),
    ];
    b.sort((HubBlock a, HubBlock c) => a.r.bottom.compareTo(c.r.bottom));
    return b;
  }

  static const List<Offset> lamps = <Offset>[
    Offset(600, 250), Offset(1200, 250), Offset(300, 520), Offset(1500, 560), Offset(640, 700), Offset(1160, 700),
    Offset(300, 900), Offset(1500, 900), Offset(640, 1090), Offset(1160, 1090), Offset(900, 1200), Offset(120, 1180), Offset(1680, 1180),
  ];

  /// x, y, radius x, radius y
  static const List<List<double>> puddles = <List<double>>[
    <double>[560, 620, 60, 18], <double>[1260, 640, 70, 20], <double>[880, 430, 80, 20], <double>[740, 1090, 62, 16],
    <double>[1000, 1000, 74, 20], <double>[300, 820, 50, 14], <double>[1520, 960, 56, 16], <double>[220, 1180, 66, 16], <double>[1100, 250, 60, 14],
  ];

  static bool solid(double x, double y) {
    for (final HubBlock b in blocks) {
      final Rect r = b.r;
      if (x > r.left - radius && x < r.right + radius && y > r.top - radius * 0.7 && y < r.bottom + radius * 0.7) return true;
    }
    final double dx = x - fountain.x;
    final double dy = (y - fountain.y) * 1.15;
    final double rr = fountain.r + radius;
    if (dx * dx + dy * dy < rr * rr) return true;
    return false;
  }

  static HubPortal? portalNear(double x, double y) {
    HubPortal? best;
    double bd = portalReach * portalReach;
    for (final HubPortal p in portals) {
      final double dx = p.x - x;
      final double dy = p.y - y;
      final double d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = p;
      }
    }
    return best;
  }
}

/// Where the camera looks and how big the world is drawn.
class HubCam {
  final double x;
  final double y;
  final double zoom;
  final Size size;
  const HubCam(this.x, this.y, this.zoom, this.size);

  Rect get view => Rect.fromCenter(center: Offset(x, y), width: size.width / zoom, height: size.height / zoom);

  Offset toWorld(Offset s) => Offset((s.dx - size.width / 2) / zoom + x, (s.dy - size.height / 2) / zoom + y);
  Offset toScreen(double wx, double wy) => Offset((wx - x) * zoom + size.width / 2, (wy - y) * zoom + size.height / 2);
}

HubCam hubCamera(Size size, double px, double py) {
  final double zoom = (size.shortestSide / 470).clamp(0.85, 1.6).toDouble();
  final double hw = size.width / (2 * zoom);
  final double hh = size.height / (2 * zoom);
  double cx = px;
  double cy = py;
  if (HubWorld.width > hw * 2) {
    cx = cx.clamp(hw, HubWorld.width - hw).toDouble();
  } else {
    cx = HubWorld.width / 2;
  }
  if (HubWorld.height > hh * 2) {
    cy = cy.clamp(hh, HubWorld.height - hh).toDouble();
  } else {
    cy = HubWorld.height / 2;
  }
  return HubCam(cx, cy, zoom, size);
}

/// Everything that moves on the plaza, updated by the screen's ticker.
class HubSim {
  static const double speed = 190;
  double x = HubWorld.spawnX;
  double y = HubWorld.spawnY;
  double facing = 1;
  double phase = 0;
  double time = 0;
  bool moving = false;

  bool joyOn = false;
  Offset joyOrigin = Offset.zero;
  Offset joyDelta = Offset.zero;

  final Map<String, HubBubble> bubbles = <String, HubBubble>{};
  final Map<String, HubEmoteShow> emotes = <String, HubEmoteShow>{};

  void step(double dt, double ix, double iy) {
    double len = sqrt(ix * ix + iy * iy);
    if (len > 1) {
      ix /= len;
      iy /= len;
      len = 1;
    }
    moving = len > 0.12;
    if (moving) {
      final double nx = (x + ix * speed * dt).clamp(HubWorld.minX, HubWorld.maxX).toDouble();
      if (!HubWorld.solid(nx, y)) x = nx;
      final double ny = (y + iy * speed * dt).clamp(HubWorld.minY, HubWorld.maxY).toDouble();
      if (!HubWorld.solid(x, ny)) y = ny;
      if (ix.abs() > 0.15) facing = ix > 0 ? 1 : -1;
      phase += dt * 9;
    }
  }

  void prune(int nowMs) {
    bubbles.removeWhere((String k, HubBubble v) => v.untilMs < nowMs);
    emotes.removeWhere((String k, HubEmoteShow v) => nowMs - v.startMs > 2400);
  }
}

/// What the painter reads each frame.
class HubScene {
  final HubSim sim = HubSim();
  DarkomHubNet? net;
  DarkomLook? myLook;
  String myId = '';
  String? selectedId;
  HubPortal? near;
  double topInset = 0;
}
