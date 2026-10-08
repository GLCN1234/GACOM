import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';

// ---------------------------------------------------------------------------
// Constants

const double windwardCellSize = 620.0;
const double windwardStormCell = 1500.0;
const double windwardRunSeconds = 720.0;
const double windwardDaySeconds = 60.0;
const int windwardHold = 6;
const int windwardMaxHull = 6;
const int windwardStartGold = 150;
const double windwardShipRadius = 12.0;
const double windwardBaseSpeed = 118.0;
const double windwardTurnRate = 1.9;
const double windwardTrimTime = 3.0;
const double windwardTrimCooldown = 12.0;
const double windwardHitCooldown = 1.5;
const int windwardRepairCost = 45;
const double windwardNoGo = 40.0 * pi / 180.0;
const int windwardContractQty = 3;

double windwardCl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Wraps an angle into the range -pi to pi.
double windwardWrap(double a) {
  double r = a;
  while (r > pi) {
    r -= 2 * pi;
  }
  while (r < -pi) {
    r += 2 * pi;
  }
  return r;
}

/// How much of full speed the ship keeps. [into] is the angle between the
/// heading and the direction the wind comes from, 0 (straight into the wind)
/// to pi (wind dead behind).
double windwardSailFactor(double into) {
  final double d = windwardCl(into, 0.0, pi);
  const double halfPi = pi / 2;
  const double threeEighths = pi * 3 / 4;
  if (d < windwardNoGo) {
    final double t = d / windwardNoGo;
    return 0.04 + 0.26 * t * t;
  }
  if (d < halfPi) {
    return 0.30 + 0.45 * ((d - windwardNoGo) / (halfPi - windwardNoGo));
  }
  if (d < threeEighths) {
    return 0.75 + 0.20 * ((d - halfPi) / (threeEighths - halfPi));
  }
  return 0.95 + 0.05 * ((d - threeEighths) / (pi - threeEighths));
}

int windwardBuyPrice(int mid, bool ok) {
  final int v = (mid * 1.10 * (ok ? 0.88 : 1.12)).round();
  return v < 1 ? 1 : v;
}

int windwardSellPrice(int mid, bool ok) {
  final int v = (mid * 0.90 * (ok ? 1.12 : 0.88)).round();
  return v < 1 ? 1 : v;
}

class WindwardGood {
  final String name;
  final int base;
  final Color color;
  const WindwardGood(this.name, this.base, this.color);
}

const List<WindwardGood> windwardGoods = <WindwardGood>[
  WindwardGood('Grain', 14, Color(0xFFE0B24A)),
  WindwardGood('Cloth', 30, Color(0xFF7E57C2)),
  WindwardGood('Spice', 46, Color(0xFFE64A19)),
  WindwardGood('Timber', 22, Color(0xFF8D6E63)),
  WindwardGood('Salt', 18, Color(0xFFB0BEC5)),
  WindwardGood('Ink', 36, Color(0xFF3949AB)),
];

const List<String> windwardNameA = <String>[
  'Ar', 'Bel', 'Cor', 'Dun', 'Esk', 'Fal', 'Gar', 'Hal', 'Ive', 'Jor', 'Kel', 'Lun', 'Mar',
  'Nor', 'Ost', 'Pen', 'Quil', 'Rav', 'Sol', 'Tar', 'Ulm', 'Val', 'Wyn', 'Yar', 'Zan',
];

const List<String> windwardNameB = <String>[
  'haven', 'wick', 'stead', 'holm', 'ness', 'cove', 'ford', 'bay', 'wharf', 'mere', 'point', 'rock',
];

const List<String> windwardStory = <String>[
  'The old trade winds are waking. Keep the wind on your quarter and the sails will fill.',
  'Storm clouds drift across the lanes. Rough water is no place for a loaded hold.',
  'Reefs scrape more hulls than storms ever do. Keep clear of the foam.',
  'Word spreads among the harbour masters. Captains who know their lessons get the best prices.',
  'Half the season is gone. The winds are strong and the warehouses are hungry.',
  'The last days of the season. Sell what you carry and find a quiet port.',
];

const List<double> windwardStoryTimes = <double>[110.0, 200.0, 300.0, 400.0, 540.0, 650.0];

// ---------------------------------------------------------------------------
// World objects

class WindwardPort {
  final int key;
  final int cx;
  final int cy;
  final double x;
  final double y;
  final double radius;
  final String name;
  final String subjectId;
  final double dockAngle;
  final List<double> factor;
  WindwardPort(this.key, this.cx, this.cy, this.x, this.y, this.radius, this.name, this.subjectId, this.dockAngle, this.factor);
  double get dockRadius => radius + 100.0;
}

class WindwardReef {
  final double x;
  final double y;
  final double r;
  final bool rock;
  final double phase;
  const WindwardReef(this.x, this.y, this.r, this.rock, this.phase);
}

class WindwardCell {
  final List<WindwardReef> reefs;
  WindwardCell(this.reefs);
}

class WindwardStorm {
  double x = 0;
  double y = 0;
  double r = 0;
}

class WindwardContract {
  final int id;
  final int fromKey;
  final int toKey;
  final String fromName;
  final String toName;
  final double toX;
  final double toY;
  final int good;
  final int qty;
  final int reward;
  const WindwardContract(this.id, this.fromKey, this.toKey, this.fromName, this.toName, this.toX, this.toY, this.good, this.qty, this.reward);

  String get text => 'Deliver $qty ${windwardGoods[good].name.toLowerCase()} to $toName';
}

// ---------------------------------------------------------------------------
// Game rules

class WindwardLogic extends RealmLogic {
  // ship
  double shipX = 0;
  double shipY = 0;
  double heading = 0;
  double speed = 0;
  double startX = 0;
  double startY = 0;
  bool anchored = false;
  int hull = windwardMaxHull;
  bool sunk = false;
  bool retired = false;
  double hitCd = 0;
  double trimT = 0;
  double trimCd = 0;
  double gustT = 0;
  bool inStorm = false;
  double stormMix = 0;
  double rough = 0;

  // wind
  double windDir = 0;
  double windStr = 1;
  final double _windBase;
  final double _p1;
  final double _p2;
  final double _p3;
  final double _p4;

  // wake ring buffer
  static const int wakeSize = 26;
  final List<double> wakeX = List<double>.filled(wakeSize, 0.0);
  final List<double> wakeY = List<double>.filled(wakeSize, 0.0);
  final List<double> wakeAge = List<double>.filled(wakeSize, 9.0);
  int _wakeIdx = 0;
  double _wakeT = 0;

  // economy
  int gold = windwardStartGold;
  final List<int> cargo = List<int>.filled(windwardGoods.length, 0);
  int contractsDone = 0;
  int bonus = 0;
  final Set<int> visited = <int>{};
  final Set<int> doneOffers = <int>{};
  WindwardContract? active;

  // harbour state
  WindwardPort? harbour;
  WindwardPort? portInRange;
  double portDist = 0;
  OdyQuestion? question;
  int? chosen;
  bool tradeBuy = true;
  int tradeGood = 0;
  int lockMid = 0;
  String resultLine = '';
  String harbourMsg = '';

  // toast
  String toast = '';
  double toastT = 0;
  int _storyIdx = 0;
  bool _sawStorm = false;
  bool _sawReef = false;

  // world caches
  final Map<int, WindwardPort?> _portCache = <int, WindwardPort?>{};
  final Map<int, WindwardCell> _cells = <int, WindwardCell>{};
  final Map<int, WindwardContract?> _offers = <int, WindwardContract?>{};
  final List<WindwardStorm> storms = List<WindwardStorm>.generate(12, (int i) => WindwardStorm());
  int stormCount = 0;

  WindwardLogic(RealmContent content)
      : _windBase = realmUnit(1, 2, content.seed + 3) * 2 * pi,
        _p1 = realmUnit(3, 4, content.seed + 5) * 2 * pi,
        _p2 = realmUnit(5, 6, content.seed + 7) * 2 * pi,
        _p3 = realmUnit(7, 8, content.seed + 9) * 2 * pi,
        _p4 = realmUnit(9, 10, content.seed + 11) * 2 * pi,
        super(content) {
    final WindwardPort? home = portAt(0, 0);
    if (home != null) {
      startX = home.x + cos(home.dockAngle) * (home.radius + 150.0);
      startY = home.y + sin(home.dockAngle) * (home.radius + 150.0);
    }
    shipX = startX;
    shipY = startY;
    _updateWind();
    heading = windwardWrap(windDir + pi / 2);
    say('Cast off. Tap ANCHOR beside a port to dock.', 4.5);
  }

  // ---- world generation ---------------------------------------------------

  int _key(int cx, int cy) => (cx + 4096) * 8192 + (cy + 4096);

  WindwardPort? portAt(int cx, int cy) {
    final int k = _key(cx, cy);
    if (_portCache.containsKey(k)) return _portCache[k];
    final int seed = content.seed;
    WindwardPort? p;
    final bool has = (cx == 0 && cy == 0) || realmUnit(cx, cy, seed + 11) < 0.58;
    if (has) {
      final double x = (cx + 0.22 + 0.56 * realmUnit(cx, cy, seed + 12)) * windwardCellSize;
      final double y = (cy + 0.22 + 0.56 * realmUnit(cx, cy, seed + 14)) * windwardCellSize;
      final double r = 56.0 + 40.0 * realmUnit(cx, cy, seed + 15);
      final String sid = content.subjectIds[realmHash(cx, cy, seed + 13) % content.subjectIds.length];
      final String name = windwardNameA[realmHash(cx, cy, seed + 17) % windwardNameA.length] + windwardNameB[realmHash(cy, cx, seed + 19) % windwardNameB.length];
      final double dock = realmUnit(cx, cy, seed + 21) * 2 * pi;
      final List<double> f = List<double>.generate(windwardGoods.length, (int g) => 0.7 + 0.65 * realmUnit(k, g, seed + 23));
      p = WindwardPort(k, cx, cy, x, y, r, name, sid, dock, f);
    }
    _portCache[k] = p;
    return p;
  }

  WindwardCell cellAt(int cx, int cy) {
    final int k = _key(cx, cy);
    final WindwardCell? hit = _cells[k];
    if (hit != null) return hit;
    if (_cells.length > 300) _cells.clear();
    final int seed = content.seed;
    final List<WindwardReef> reefs = <WindwardReef>[];
    final WindwardPort? p = portAt(cx, cy);
    if (p != null) {
      final int n = 3 + realmHash(cx, cy, seed + 31) % 3;
      final double span = (2 * pi - 1.2) / n;
      for (int i = 0; i < n; i++) {
        final double jitter = (realmUnit(cx, cy, seed + 33 + i) - 0.5) * span * 0.5;
        final double a = p.dockAngle + 0.6 + span * (i + 0.5) + jitter;
        final double d = p.radius + 50.0 + 70.0 * realmUnit(cx, cy, seed + 40 + i);
        final double rr = 12.0 + 7.0 * realmUnit(cx, cy, seed + 50 + i);
        final double rx = p.x + cos(a) * d;
        final double ry = p.y + sin(a) * d;
        if (_farFromStart(rx, ry)) {
          reefs.add(WindwardReef(rx, ry, rr, false, realmUnit(cx, cy, seed + 60 + i) * 6.28));
        }
        if (realmUnit(cx, cy, seed + 70 + i) < 0.5) {
          final double a2 = a + 0.14;
          final double sx = p.x + cos(a2) * (d + 8.0);
          final double sy = p.y + sin(a2) * (d + 8.0);
          if (_farFromStart(sx, sy)) {
            reefs.add(WindwardReef(sx, sy, rr * 0.62, false, realmUnit(cx, cy, seed + 80 + i) * 6.28));
          }
        }
      }
    }
    final int rocks = realmHash(cx, cy, seed + 90) % 3;
    for (int i = 0; i < rocks; i++) {
      final double rx = (cx + 0.08 + 0.84 * realmUnit(cx, cy, seed + 91 + i * 2)) * windwardCellSize;
      final double ry = (cy + 0.08 + 0.84 * realmUnit(cx, cy, seed + 92 + i * 2)) * windwardCellSize;
      if (p != null) {
        final double dx = rx - p.x;
        final double dy = ry - p.y;
        if (sqrt(dx * dx + dy * dy) < p.radius + 170.0) continue;
      }
      if (!_farFromStart(rx, ry)) continue;
      reefs.add(WindwardReef(rx, ry, 10.0 + 6.0 * realmUnit(cx, cy, seed + 99 + i), true, realmUnit(cx, cy, seed + 101 + i) * 6.28));
    }
    final WindwardCell c = WindwardCell(reefs);
    _cells[k] = c;
    return c;
  }

  bool _farFromStart(double x, double y) {
    final double dx = x - startX;
    final double dy = y - startY;
    return sqrt(dx * dx + dy * dy) > 110.0;
  }

  // ---- economy ------------------------------------------------------------

  int get day {
    final int d = (time / windwardDaySeconds).floor() + 1;
    return d > 12 ? 12 : d;
  }

  int get cargoCount {
    int n = 0;
    for (final int c in cargo) {
      n += c;
    }
    return n;
  }

  int midPrice(WindwardPort p, int g) {
    final double dayF = 0.88 + 0.24 * realmUnit(p.key, g + (time / windwardDaySeconds).floor() * 13, content.seed + 31);
    final int v = (windwardGoods[g].base * p.factor[g] * dayF).round();
    return v < 4 ? 4 : v;
  }

  int buyQuote(WindwardPort p, int g) => (midPrice(p, g) * 1.10).round();
  int sellQuote(WindwardPort p, int g) => (midPrice(p, g) * 0.90).round();

  /// The contract this port posts, or null if no other port is near.
  WindwardContract? offerAt(WindwardPort p) {
    if (_offers.containsKey(p.key)) return _offers[p.key];
    final List<WindwardPort> cands = <WindwardPort>[];
    for (int dx = -3; dx <= 3; dx++) {
      for (int dy = -3; dy <= 3; dy++) {
        if (dx == 0 && dy == 0) continue;
        final WindwardPort? q = portAt(p.cx + dx, p.cy + dy);
        if (q != null) cands.add(q);
      }
    }
    WindwardContract? c;
    if (cands.isNotEmpty) {
      cands.sort((WindwardPort a, WindwardPort b) => _dist2(p, a).compareTo(_dist2(p, b)));
      final int span = cands.length < 5 ? cands.length : 5;
      final WindwardPort q = cands[realmHash(p.cx, p.cy, content.seed + 61) % span];
      final double d = sqrt(_dist2(p, q));
      final int good = realmHash(p.cx, p.cy, content.seed + 63) % windwardGoods.length;
      final int reward = 50 + (d * 0.12).round();
      c = WindwardContract(p.key, p.key, q.key, p.name, q.name, q.x, q.y, good, windwardContractQty, reward);
    }
    _offers[p.key] = c;
    return c;
  }

  double _dist2(WindwardPort a, WindwardPort b) {
    final double dx = a.x - b.x;
    final double dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  bool acceptContract() {
    final WindwardPort? p = harbour;
    if (p == null || over || question != null) return false;
    final WindwardContract? c = offerAt(p);
    if (c == null || active != null || doneOffers.contains(c.id)) return false;
    active = c;
    harbourMsg = 'Contract taken: ${c.text}.';
    cues.add('tap');
    return true;
  }

  void abandonContract() {
    if (active == null) return;
    active = null;
    harbourMsg = 'Contract dropped.';
  }

  bool get canDeliver {
    final WindwardContract? c = active;
    final WindwardPort? p = harbour;
    if (c == null || p == null) return false;
    return c.toKey == p.key && cargo[c.good] >= c.qty && !doneOffers.contains(c.id);
  }

  bool deliverContract() {
    final WindwardContract? c = active;
    if (c == null || over || question != null || !canDeliver) return false;
    cargo[c.good] -= c.qty;
    gold += c.reward;
    if (hull < windwardMaxHull) hull += 1;
    contractsDone += 1;
    doneOffers.add(c.id);
    active = null;
    harbourMsg = 'Delivered. ${c.reward} gold and the shipwrights patch your hull.';
    cues.add('win');
    return true;
  }

  bool canBuy(WindwardPort p, int g) => cargoCount < windwardHold && gold >= windwardBuyPrice(midPrice(p, g), false);
  bool canSell(int g) => cargo[g] > 0;

  /// Starts a trade by asking the harbour master. Returns null when it began,
  /// or a message explaining why not.
  String? beginTrade(bool buy, int g) {
    final WindwardPort? p = harbour;
    if (p == null || over || question != null) return 'Not now.';
    if (g < 0 || g >= windwardGoods.length) return 'Not now.';
    if (buy) {
      if (cargoCount >= windwardHold) {
        harbourMsg = 'The hold is full.';
        return harbourMsg;
      }
      if (gold < windwardBuyPrice(midPrice(p, g), false)) {
        harbourMsg = 'Not enough gold.';
        return harbourMsg;
      }
    } else if (cargo[g] <= 0) {
      harbourMsg = 'You have none to sell.';
      return harbourMsg;
    }
    tradeBuy = buy;
    tradeGood = g;
    lockMid = midPrice(p, g);
    question = content.ask(p.subjectId);
    chosen = null;
    resultLine = '';
    harbourMsg = '';
    return null;
  }

  void answerTrade(int index) {
    final OdyQuestion? q = question;
    if (q == null || chosen != null || over) return;
    final bool ok = index == q.answerIndex;
    chosen = index;
    if (ok) {
      stats.record(q, true);
    } else {
      stats.record(q, false, chosen: q.options[index]);
    }
    final String gn = windwardGoods[tradeGood].name.toLowerCase();
    if (tradeBuy) {
      final int price = windwardBuyPrice(lockMid, ok);
      if (cargoCount < windwardHold && gold >= price) {
        gold -= price;
        cargo[tradeGood] += 1;
        resultLine = (ok ? 'Fair dealing. ' : 'A steep price. ') + 'Bought 1 $gn for $price gold.';
      } else {
        resultLine = 'The deal fell through.';
      }
    } else {
      final int price = windwardSellPrice(lockMid, ok);
      if (cargo[tradeGood] > 0) {
        cargo[tradeGood] -= 1;
        gold += price;
        resultLine = (ok ? 'Fair dealing. ' : 'A poor offer. ') + 'Sold 1 $gn for $price gold.';
      } else {
        resultLine = 'The deal fell through.';
      }
    }
    cues.add(ok ? 'good' : 'bad');
  }

  void continueTrade() {
    question = null;
    chosen = null;
  }

  bool buyRepair() {
    if (harbour == null || over || question != null) return false;
    if (hull >= windwardMaxHull) {
      harbourMsg = 'The hull is already sound.';
      return false;
    }
    if (gold < windwardRepairCost) {
      harbourMsg = 'Not enough gold for repairs.';
      return false;
    }
    gold -= windwardRepairCost;
    hull += 1;
    harbourMsg = 'Hull repaired.';
    cues.add('tap');
    return true;
  }

  void dock(WindwardPort p) {
    harbour = p;
    anchored = true;
    speed = 0;
    inputX = 0;
    inputY = 0;
    question = null;
    chosen = null;
    resultLine = '';
    harbourMsg = '';
    if (!visited.contains(p.key)) {
      visited.add(p.key);
      if (visited.length == 1) {
        say('The harbour master eyes you. Prove you know your lessons and we will talk prices.', 4.5);
      } else {
        say('${p.name} welcomes a new captain.', 3.0);
      }
    }
    cues.add('tap');
  }

  void leaveHarbour() {
    if (harbour == null) return;
    harbour = null;
    question = null;
    chosen = null;
    anchored = false;
    hitCd = hitCd > 1.0 ? hitCd : 1.0;
    cues.add('tap');
  }

  // ---- messages -----------------------------------------------------------

  void say(String msg, [double secs = 3.0]) {
    toast = msg;
    toastT = secs;
  }

  // ---- RealmLogic ---------------------------------------------------------

  @override
  bool get modal => harbour != null && !over;

  // ---- objective guidance -----------------------------------------------------

  Offset? _objTarget;
  String? _objText;

  WindwardPort? _nearestOfferPort() {
    final int scx = (shipX / windwardCellSize).floor();
    final int scy = (shipY / windwardCellSize).floor();
    WindwardPort? best;
    double bd = 0;
    for (int dx = -3; dx <= 3; dx++) {
      for (int dy = -3; dy <= 3; dy++) {
        final WindwardPort? p = portAt(scx + dx, scy + dy);
        if (p == null) continue;
        final WindwardContract? o = offerAt(p);
        if (o == null || doneOffers.contains(o.id)) continue;
        final double d = (p.x - shipX) * (p.x - shipX) + (p.y - shipY) * (p.y - shipY);
        if (best == null || d < bd) {
          best = p;
          bd = d;
        }
      }
    }
    return best;
  }

  void _pickObjective() {
    _objTarget = null;
    _objText = null;
    if (over || harbour != null) return;
    final WindwardContract? c = active;
    if (c != null) {
      final WindwardContract t = c;
      final String good = windwardGoods[t.good].name.toLowerCase();
      if (cargo[t.good] >= t.qty) {
        _objTarget = Offset(t.toX - shipX, t.toY - shipY);
        _objText = 'Sail to ${t.toName} and deliver ${t.qty} $good';
      } else {
        final WindwardPort? from = portAt(t.fromKey ~/ 8192 - 4096, t.fromKey % 8192 - 4096);
        _objText = 'Buy ${t.qty} $good at a port, then sail to ${t.toName}';
        if (from != null) {
          _objTarget = Offset(from.x - shipX, from.y - shipY);
          _objText = 'Dock at ${from.name} and buy ${t.qty} $good for ${t.toName}';
        }
      }
      return;
    }
    final WindwardPort? p = _nearestOfferPort();
    if (p != null) {
      _objTarget = Offset(p.x - shipX, p.y - shipY);
      _objText = cargoCount > 0 ? 'Sail to ${p.name}, sell your cargo or take a contract' : 'Sail to ${p.name} and take a trade contract';
    } else {
      _objText = 'Explore the sea to find a new port';
    }
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
  int get hearts => hull;

  @override
  int get maxHearts => windwardMaxHull;

  int get goldGain => gold > windwardStartGold ? gold - windwardStartGold : 0;

  @override
  int get finalScore => goldGain + contractsDone * 150 + visited.length * 40 + bonus;

  @override
  int get xp => stats.baseXp + contractsDone * 6;

  int get windKnots => (windStr * 12).round();

  @override
  List<RealmChip> get chips {
    final WindwardContract? c = active;
    return <RealmChip>[
      RealmChip('$gold gold', Icons.monetization_on_rounded, const Color(0xFFFFD54F)),
      RealmChip('Hold $cargoCount/$windwardHold', Icons.inventory_2_rounded, const Color(0xFFA1887F)),
      RealmChip('Wind $windKnots kn', Icons.air_rounded, const Color(0xFF4FC3F7)),
      RealmChip(c == null ? 'No contract' : 'Deliver ${c.qty} ${windwardGoods[c.good].name.toLowerCase()}', Icons.assignment_rounded, const Color(0xFF69F0AE)),
    ];
  }

  @override
  Map<String, String> get extraStats => <String, String>{
        'Gold': '$gold',
        'Contracts': '$contractsDone',
        'Ports': '${visited.length}',
      };

  @override
  double actionReady(int id) {
    if (id == 0) {
      if (trimCd <= 0) return 1.0;
      return windwardCl(1.0 - trimCd / windwardTrimCooldown, 0.0, 1.0);
    }
    return 1.0;
  }

  @override
  void onAction(int id) {
    if (over || modal) return;
    if (id == 0) {
      if (trimCd <= 0 && !anchored) {
        trimT = windwardTrimTime;
        trimCd = windwardTrimCooldown;
        cues.add('tap');
      }
      return;
    }
    if (id == 1) {
      final WindwardPort? p = portInRange;
      if (p != null) {
        dock(p);
      } else {
        anchored = !anchored;
        say(anchored ? 'Anchor down.' : 'Anchor up. Sails full.', 1.6);
        cues.add('tap');
      }
    }
  }

  /// Angle between the heading and the direction the wind comes from.
  double get intoWind => windwardWrap(heading - (windDir + pi)).abs();

  double get sailFactor => windwardSailFactor(intoWind);

  double get targetSpeed {
    final double wm = 0.6 + 0.4 * windStr;
    double s = windwardBaseSpeed * sailFactor * wm;
    if (inStorm) s *= 0.72;
    if (trimT > 0) s *= 1.5;
    if (anchored) s = 0;
    return s;
  }

  void _updateWind() {
    windDir = windwardWrap(_windBase + 0.9 * sin(time * 0.045 + _p1) + 0.55 * sin(time * 0.113 + _p2));
    windStr = windwardCl(1.0 + 0.38 * sin(time * 0.061 + _p3) + 0.17 * sin(time * 0.17 + _p4), 0.45, 1.55);
  }

  void _updateStorms() {
    stormCount = 0;
    final int seed = content.seed;
    final int scx = (shipX / windwardStormCell).floor();
    final int scy = (shipY / windwardStormCell).floor();
    final double grow = windwardCl(time / 30.0, 0.0, 1.0);
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final int sx = scx + dx;
        final int sy = scy + dy;
        if (realmUnit(sx, sy, seed + 41) > 0.55) continue;
        final double bx = (sx + 0.3 + 0.4 * realmUnit(sx, sy, seed + 43)) * windwardStormCell;
        final double by = (sy + 0.3 + 0.4 * realmUnit(sx, sy, seed + 44)) * windwardStormCell;
        final double a = 150.0 + 200.0 * realmUnit(sx, sy, seed + 45);
        final double b = 120.0 + 200.0 * realmUnit(sx, sy, seed + 47);
        final double w = 0.03 + 0.04 * realmUnit(sx, sy, seed + 49);
        final double ph = 6.28 * realmUnit(sx, sy, seed + 51);
        final double ph2 = 6.28 * realmUnit(sx, sy, seed + 52);
        final WindwardStorm s = storms[stormCount];
        s.x = bx + a * cos(w * time + ph);
        s.y = by + b * sin(w * time * 0.8 + ph2);
        s.r = (170.0 + 90.0 * realmUnit(sx, sy, seed + 53)) * grow;
        stormCount++;
      }
    }
  }

  @override
  void step(double dt) {
    if (over) return;
    if (toastT > 0) toastT -= dt;
    if (hitCd > 0) hitCd -= dt;
    if (trimCd > 0) trimCd -= dt;
    if (trimT > 0) trimT -= dt;
    _updateWind();
    for (int i = 0; i < wakeSize; i++) {
      wakeAge[i] += dt;
    }
    if (time >= windwardRunSeconds) {
      _retire();
      return;
    }
    if (_storyIdx < windwardStory.length && time >= windwardStoryTimes[_storyIdx] && harbour == null) {
      say(windwardStory[_storyIdx], 4.5);
      _storyIdx++;
    }
    if (harbour != null) {
      speed = 0;
      return;
    }
    _updateStorms();
    _steer(dt);
    _move(dt);
    _collide();
    _weather(dt);
    _findPort();
    _wake(dt);
  }

  void _steer(double dt) {
    final double m = sqrt(inputX * inputX + inputY * inputY);
    if (m > 0.18) {
      final double target = atan2(inputY, inputX);
      final double d = windwardWrap(target - heading);
      final double rate = windwardTurnRate * (anchored ? 0.5 : 1.0) * (0.45 + 0.55 * windwardCl(m, 0.0, 1.0));
      final double step = rate * dt;
      heading = windwardWrap(heading + windwardCl(d, -step, step));
    }
    final double ts = targetSpeed;
    final double k = ts < speed ? 2.2 : 1.1;
    speed += (ts - speed) * windwardCl(k * dt, 0.0, 1.0);
    if (speed < 0) speed = 0;
  }

  void _move(double dt) {
    shipX += cos(heading) * speed * dt;
    shipY += sin(heading) * speed * dt;
  }

  void _collide() {
    final int scx = (shipX / windwardCellSize).floor();
    final int scy = (shipY / windwardCellSize).floor();
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final WindwardPort? p = portAt(scx + dx, scy + dy);
        if (p != null) {
          final double lim = p.radius * 0.9 + windwardShipRadius;
          if (_pushOut(p.x, p.y, lim)) {
            speed *= 0.3;
            damage('land');
          }
        }
        final WindwardCell cell = cellAt(scx + dx, scy + dy);
        for (final WindwardReef r in cell.reefs) {
          if (_pushOut(r.x, r.y, r.r + windwardShipRadius)) {
            speed *= 0.35;
            damage(r.rock ? 'rock' : 'reef');
          }
        }
      }
    }
  }

  /// Moves the ship out of a circle if it is inside; true if it was.
  bool _pushOut(double cx, double cy, double lim) {
    final double dx = shipX - cx;
    final double dy = shipY - cy;
    final double d2 = dx * dx + dy * dy;
    if (d2 >= lim * lim) return false;
    final double d = sqrt(d2);
    double nx = 1.0;
    double ny = 0.0;
    if (d > 0.001) {
      nx = dx / d;
      ny = dy / d;
    }
    shipX = cx + nx * (lim + 0.5);
    shipY = cy + ny * (lim + 0.5);
    return true;
  }

  void _weather(double dt) {
    bool inside = false;
    bool core = false;
    for (int i = 0; i < stormCount; i++) {
      final WindwardStorm s = storms[i];
      final double dx = shipX - s.x;
      final double dy = shipY - s.y;
      final double d = sqrt(dx * dx + dy * dy);
      if (s.r > 20 && d < s.r) {
        inside = true;
        if (d < s.r * 0.7) core = true;
      }
    }
    inStorm = inside;
    stormMix += ((inside ? 1.0 : 0.0) - stormMix) * windwardCl(2.0 * dt, 0.0, 1.0);
    rough = core ? 1.0 : (inside ? 0.5 : 0.0);
    if (inside && !_sawStorm) {
      _sawStorm = true;
      say('Rough water. Ride out of the storm quickly.', 3.5);
    }
    if (core) {
      gustT += dt;
      if (gustT >= 2.6) {
        gustT = 0;
        damage('gust');
      }
    } else if (gustT > 0) {
      gustT -= dt;
      if (gustT < 0) gustT = 0;
    }
  }

  bool damage(String why) {
    if (over || hitCd > 0 || hull <= 0) return false;
    hull -= 1;
    hitCd = windwardHitCooldown;
    cues.add('bad');
    if (hull <= 0) {
      hull = 0;
      sunk = true;
      over = true;
      cues.add('lose');
      say('The sea takes your ship. The old winds will wait for another captain.', 5.0);
      return true;
    }
    String msg = 'The hull scrapes.';
    if (why == 'reef') {
      msg = _sawReef ? 'Reef! The hull scrapes.' : 'Reef! Keep clear of the white foam.';
      _sawReef = true;
    } else if (why == 'rock') {
      msg = 'Rocks! Hull damaged.';
    } else if (why == 'land') {
      msg = 'Aground on the shoals!';
    } else if (why == 'gust') {
      msg = 'A gust slams the ship.';
    }
    say(msg, 2.2);
    return true;
  }

  void _findPort() {
    final int scx = (shipX / windwardCellSize).floor();
    final int scy = (shipY / windwardCellSize).floor();
    WindwardPort? best;
    double bestD = 1e9;
    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final WindwardPort? p = portAt(scx + dx, scy + dy);
        if (p == null) continue;
        final double ex = shipX - p.x;
        final double ey = shipY - p.y;
        final double d = sqrt(ex * ex + ey * ey);
        if (d < p.dockRadius && d < bestD) {
          bestD = d;
          best = p;
        }
      }
    }
    portInRange = best;
    portDist = bestD;
  }

  void _wake(double dt) {
    _wakeT += dt;
    if (speed > 18 && _wakeT >= 0.12) {
      _wakeT = 0;
      wakeX[_wakeIdx] = shipX - cos(heading) * 22.0;
      wakeY[_wakeIdx] = shipY - sin(heading) * 22.0;
      wakeAge[_wakeIdx] = 0;
      _wakeIdx = (_wakeIdx + 1) % wakeSize;
    }
  }

  void _retire() {
    if (over) return;
    retired = true;
    bonus = 100 + hull * 20;
    over = true;
    cues.add('win');
    say('The season ends. You retire with a full ledger.', 4.0);
  }
}
