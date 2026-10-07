import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';

const int kFrontierSize = 14;
const int kFrontierTiles = 196;
const double kFrontierDayLen = 18.0;
const int kFrontierLastDay = 30;
const double kFrontierTopPad = 118.0;
const double kFrontierBottomPad = 214.0;
const int kFrontierHall = 8;
const int kFrontierHallIndex = 7 * 14 + 7;

/// Static tables: names, costs, terrain and technologies.
class FrontierData {
  static const List<String> names = <String>['Farm', 'Lumber Camp', 'Quarry', 'House', 'School', 'Well', 'Watchtower', 'Wall'];
  static const List<String> shortNames = <String>['Farm', 'Lumber', 'Quarry', 'House', 'School', 'Well', 'Tower', 'Wall'];
  static const List<int> costWood = <int>[10, 6, 12, 14, 18, 6, 12, 4];
  static const List<int> costStone = <int>[0, 0, 0, 4, 10, 10, 14, 8];
  static const List<int> costCoin = <int>[5, 5, 10, 8, 20, 8, 15, 5];
  static const List<String> terrainNames = <String>['Meadow', 'Forest', 'Hills', 'Lake', 'Fertile soil'];

  static const List<String> techNames = <String>['Irrigation', 'Masonry', 'Writing', 'Palisade', 'Granary'];
  static const List<int> techCosts = <int>[5, 5, 6, 6, 8];
  static const List<String> techBlurbs = <String>[
    'Farms yield 30 percent more food.',
    'Stone costs 25 percent less.',
    'Each School makes 1 more knowledge a day.',
    'A palisade adds 8 to your defence.',
    'Starvation hurts less and takes a day longer to end the run.',
  ];

  static const List<String> blessingNames = <String>['Bountiful harvest', 'Timber blessing', 'Gift of wisdom', 'Builders favour'];
  static const List<String> blessingBlurbs = <String>[
    'Double food at the end of the next day.',
    'Double wood at the end of the next day.',
    '+3 knowledge right now.',
    'Your next build or upgrade costs half.',
  ];

  /// Which terrain a building may stand on. Terrain: 0 meadow, 1 forest, 2 hills, 3 lake, 4 fertile.
  static bool legal(int type, int terr) {
    switch (type) {
      case 0:
        return terr == 0 || terr == 4;
      case 1:
        return terr == 1;
      case 2:
        return terr == 2;
      case 3:
      case 4:
      case 5:
        return terr == 0 || terr == 4;
      case 6:
      case 7:
        return terr == 0 || terr == 2 || terr == 4;
      default:
        return false;
    }
  }
}

class FrontierSettler {
  double x;
  double y;
  double tx;
  double ty;
  double wait;
  double phase = 0;
  double facing = 1;
  final int look;
  FrontierSettler(this.x, this.y, this.tx, this.ty, this.wait, this.look);
}

class FrontierPopup {
  final double x;
  final double y;
  final String text;
  final int kind;
  double age = 0;
  FrontierPopup(this.x, this.y, this.text, this.kind);
}

class FrontierLogic extends RealmLogic {
  FrontierLogic(RealmContent content) : super(content) {
    _generate();
    bType[kFrontierHallIndex] = kFrontierHall;
    bLevel[kFrontierHallIndex] = 1;
    _recalc();
    _vis = Random(content.seed ^ 0x5bd1e995);
    _updateSettlers(0.0);
    _say('The charter is signed. Your people wait for a leader.');
  }

  // ---- world ---------------------------------------------------------------
  final List<int> terrain = List<int>.filled(kFrontierTiles, 0);
  final List<double> shade = List<double>.filled(kFrontierTiles, 0.5);
  final List<int> deco = List<int>.filled(kFrontierTiles, 0);
  final List<int> bType = List<int>.filled(kFrontierTiles, -1);
  final List<int> bLevel = List<int>.filled(kFrontierTiles, 0);
  final List<int> _sites = <int>[];
  Random _vis = Random(1);

  // ---- state ---------------------------------------------------------------
  int day = 1;
  int daysDone = 0;
  double dayT = 0;
  int food = 40;
  int wood = 30;
  int stone = 6;
  int coins = 40;
  int knowledge = 0;
  int pop = 3;
  int cap = 6;
  int starved = 0;
  bool won = false;
  String endReason = '';
  int speed = 1;
  bool foodBoost = false;
  bool woodBoost = false;
  bool discount = false;
  final List<bool> tech = List<bool>.filled(5, false);
  int raidsHeld = 0;
  int raidsLost = 0;

  int selX = -1;
  int selY = -1;

  // ---- panels --------------------------------------------------------------
  /// 0 none, 1 council offer, 2 council question, 3 blessing, 5 research menu, 6 research question.
  int panel = 0;
  OdyQuestion? q;
  int? chosen;
  bool lastOk = false;
  String resultLine = '';
  String councilSubject = '';
  int resTech = -1;
  final List<String> report = <String>[];

  // ---- visual state --------------------------------------------------------
  String toast = '';
  double toastT = 0;
  Size lastSize = Size.zero;
  final List<FrontierSettler> settlers = <FrontierSettler>[];
  final List<FrontierPopup> popups = <FrontierPopup>[];
  double raidFx = 0;
  bool raidFxWon = true;
  int raidFxCount = 0;

  @override
  bool get modal => panel != 0;

  @override
  int get hearts => -1;

  int get starveLimit => tech[4] ? 4 : 3;

  // ---- generation ----------------------------------------------------------

  double _vn(int salt, double fx, double fy) {
    final int ix = fx.floor();
    final int iy = fy.floor();
    double tx = fx - ix;
    double ty = fy - iy;
    tx = tx * tx * (3 - 2 * tx);
    ty = ty * ty * (3 - 2 * ty);
    final int s = content.seed + salt;
    final double a = realmUnit(ix, iy, s);
    final double b = realmUnit(ix + 1, iy, s);
    final double c = realmUnit(ix, iy + 1, s);
    final double d = realmUnit(ix + 1, iy + 1, s);
    final double top = a + (b - a) * tx;
    final double bot = c + (d - c) * tx;
    return top + (bot - top) * ty;
  }

  int _iabs(int v) => v < 0 ? -v : v;
  int _imax(int a, int b) => a > b ? a : b;
  int _imin(int a, int b) => a < b ? a : b;
  double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

  int _cheb(int x, int y) => _imax(_iabs(x - 7), _iabs(y - 7));

  void _generate() {
    final int s = content.seed;
    final int qd = realmHash(s, 3, 9) % 4;
    final double lx = (qd % 2 == 0) ? 2.0 : 11.0;
    final double ly = (qd ~/ 2 == 0) ? 2.0 : 11.0;
    final double px = 13.0 - lx;
    final double py = 13.0 - ly;
    for (int y = 0; y < kFrontierSize; y++) {
      for (int x = 0; x < kFrontierSize; x++) {
        final int i = y * kFrontierSize + x;
        shade[i] = realmUnit(x, y, s + 5);
        deco[i] = realmHash(x, y, s + 6) % 100;
        final double dl = sqrt((x - lx) * (x - lx) + (y - ly) * (y - ly));
        final double dp = sqrt((x - px) * (x - px) + (y - py) * (y - py));
        final double wn = _vn(11, x * 0.5, y * 0.5);
        int t = 0;
        if (dl < 2.4 + wn * 1.6 || dp < 1.0 + wn * 0.9) {
          t = 3;
        } else if (_vn(37, x * 0.4 + 1.7, y * 0.4 + 1.7) > 0.62) {
          t = 2;
        } else if (_vn(23, x * 0.4 + 3.1, y * 0.4 + 3.1) > 0.55) {
          t = 1;
        } else if (_vn(51, x * 0.4 + 5.3, y * 0.4 + 5.3) > 0.57) {
          t = 4;
        }
        if (_cheb(x, y) <= 1) t = 0;
        terrain[i] = t;
      }
    }
    _ensure(1, 9);
    _ensure(2, 7);
    _ensure(4, 9);
  }

  void _ensure(int type, int want) {
    int have = 0;
    for (int i = 0; i < kFrontierTiles; i++) {
      if (terrain[i] == type) have++;
    }
    while (have < want) {
      int best = -1;
      double bestKey = 1e9;
      for (int i = 0; i < kFrontierTiles; i++) {
        if (terrain[i] != 0) continue;
        final int x = i % kFrontierSize;
        final int y = i ~/ kFrontierSize;
        if (_cheb(x, y) <= 1) continue;
        final double d = sqrt(((x - 7) * (x - 7) + (y - 7) * (y - 7)).toDouble());
        final double key = (d - 3.5).abs() * 100 + (realmHash(x, y, content.seed + type) % 100).toDouble();
        if (key < bestKey) {
          bestKey = key;
          best = i;
        }
      }
      if (best < 0) break;
      terrain[best] = type;
      have++;
    }
  }

  // ---- geometry ------------------------------------------------------------

  double tileSizeFor(Size s) {
    final double availH = s.height - kFrontierTopPad - kFrontierBottomPad;
    final double a = (s.width - 12) / kFrontierSize;
    final double b = availH / kFrontierSize;
    final double m = a < b ? a : b;
    return m < 12 ? 12 : m;
  }

  Offset originFor(Size s) {
    final double ts = tileSizeFor(s);
    final double availH = s.height - kFrontierTopPad - kFrontierBottomPad;
    final double ox = (s.width - ts * kFrontierSize) / 2;
    double oy = kFrontierTopPad + (availH - ts * kFrontierSize) / 2;
    if (oy < kFrontierTopPad) oy = kFrontierTopPad;
    return Offset(ox, oy);
  }

  int get sel => (selX < 0 || selY < 0) ? -1 : selY * kFrontierSize + selX;

  // ---- costs and capacity --------------------------------------------------

  void _recalc() {
    int c = 6;
    _sites.clear();
    for (int i = 0; i < kFrontierTiles; i++) {
      final int t = bType[i];
      if (t < 0) continue;
      _sites.add(i);
      if (t == 3) c += 2 + 2 * bLevel[i];
    }
    cap = c;
  }

  int get buildingCount {
    int n = 0;
    for (int i = 0; i < kFrontierTiles; i++) {
      if (bType[i] >= 0 && bType[i] != kFrontierHall) n++;
    }
    return n;
  }

  int countOf(int type) {
    int n = 0;
    for (int i = 0; i < kFrontierTiles; i++) {
      if (bType[i] == type) n++;
    }
    return n;
  }

  /// Cost as [wood, stone, coins]. [level] 0 is a new building, 1 or more is an upgrade from that level.
  List<int> costOf(int type, int level) {
    final int mult = level <= 0 ? 4 : level * 3;
    int w = (FrontierData.costWood[type] * mult + 3) ~/ 4;
    int s = (FrontierData.costStone[type] * mult + 3) ~/ 4;
    int c = (FrontierData.costCoin[type] * mult + 3) ~/ 4;
    if (tech[1]) s = (s * 3 + 3) ~/ 4;
    if (discount) {
      w = (w + 1) ~/ 2;
      s = (s + 1) ~/ 2;
      c = (c + 1) ~/ 2;
    }
    return <int>[w, s, c];
  }

  bool canAfford(List<int> c) => wood >= c[0] && stone >= c[1] && coins >= c[2];

  String costText(List<int> c) {
    final StringBuffer b = StringBuffer();
    if (c[0] > 0) b.write('${c[0]} wood ');
    if (c[1] > 0) b.write('${c[1]} stone ');
    if (c[2] > 0) b.write('${c[2]} coins');
    return b.toString().trim();
  }

  double get defence {
    double d = 2.0;
    for (int i = 0; i < kFrontierTiles; i++) {
      if (bType[i] == 6) d += 6.0 * bLevel[i];
      if (bType[i] == 7) d += 3.0 * bLevel[i];
    }
    if (tech[3]) d += 8.0;
    return d;
  }

  double raidStrength(int d) => 5.0 + d * 1.5 + (realmHash(content.seed, d, 7) % 4).toDouble();

  int get nextRaidDay => ((day + 4) ~/ 5) * 5;

  bool isDrought(int d) => d >= 3 && d % 5 != 0 && realmUnit(content.seed, d, 91) < 0.22;

  double get wellCoverage {
    int w = 0;
    for (int i = 0; i < kFrontierTiles; i++) {
      if (bType[i] == 5) w += 6 * bLevel[i];
    }
    final int p = _imax(1, pop);
    return _cl(w / p, 0.0, 1.0);
  }

  // ---- messages ------------------------------------------------------------

  void _say(String s) {
    toast = s;
    toastT = 3.2;
  }

  String _storyFor(int d) {
    if (d % 5 == 0) return 'Scouts report smoke on the horizon. Raiders may come tonight.';
    switch (d) {
      case 2:
        return 'Travellers hear of your charter and ask to settle.';
      case 3:
        return 'The elders say a wise council makes a strong town.';
      case 7:
        return 'Traders whisper that your town is the talk of the valley.';
      case 12:
        return 'Children now play where the first tents stood.';
      case 18:
        return 'The capital sends a letter. They are watching your town.';
      case 24:
        return 'Your people sing at the evening fire. The charter is nearly won.';
      case 29:
        return 'One more day and the frontier is yours.';
      default:
        return '';
    }
  }

  // ---- input ---------------------------------------------------------------

  @override
  void onTap(Offset point, Size size) {
    lastSize = size;
    if (over || panel != 0) return;
    final double ts = tileSizeFor(size);
    final Offset o = originFor(size);
    final int tx = ((point.dx - o.dx) / ts).floor();
    final int ty = ((point.dy - o.dy) / ts).floor();
    if (tx < 0 || ty < 0 || tx >= kFrontierSize || ty >= kFrontierSize) {
      selX = -1;
      selY = -1;
      return;
    }
    selX = tx;
    selY = ty;
    cues.add('tap');
  }

  void selectTile(int x, int y) {
    if (x < 0 || y < 0 || x >= kFrontierSize || y >= kFrontierSize) return;
    selX = x;
    selY = y;
  }

  void toggleSpeed() {
    speed = speed == 1 ? 2 : 1;
  }

  bool canBuildHere(int type) {
    final int i = sel;
    if (i < 0) return false;
    if (bType[i] >= 0) return false;
    return FrontierData.legal(type, terrain[i]);
  }

  /// Builds on the selected tile. Returns true if it was built.
  bool build(int type) {
    if (over || panel != 0) return false;
    final int i = sel;
    if (i < 0) {
      _say('Tap a tile on the map first.');
      return false;
    }
    if (type < 0 || type > 7) return false;
    if (bType[i] >= 0) {
      _say('That tile is already built on.');
      return false;
    }
    if (!FrontierData.legal(type, terrain[i])) {
      _say('A ${FrontierData.names[type]} cannot stand on ${FrontierData.terrainNames[terrain[i]].toLowerCase()}.');
      cues.add('bad');
      return false;
    }
    final List<int> c = costOf(type, 0);
    if (!canAfford(c)) {
      _say('Not enough resources. Needs ${costText(c)}.');
      cues.add('bad');
      return false;
    }
    wood -= c[0];
    stone -= c[1];
    coins -= c[2];
    discount = false;
    bType[i] = type;
    bLevel[i] = 1;
    _recalc();
    popups.add(FrontierPopup(selX.toDouble(), selY.toDouble(), 'Built', 3));
    _say('${FrontierData.names[type]} built.');
    cues.add('good');
    return true;
  }

  bool canUpgradeSel() {
    final int i = sel;
    if (i < 0) return false;
    final int t = bType[i];
    return t >= 0 && t != kFrontierHall && bLevel[i] < 3;
  }

  bool upgrade() {
    if (over || panel != 0) return false;
    final int i = sel;
    if (i < 0 || !canUpgradeSel()) {
      _say('Nothing to upgrade here.');
      return false;
    }
    final int t = bType[i];
    final List<int> c = costOf(t, bLevel[i]);
    if (!canAfford(c)) {
      _say('Not enough resources. Needs ${costText(c)}.');
      cues.add('bad');
      return false;
    }
    wood -= c[0];
    stone -= c[1];
    coins -= c[2];
    discount = false;
    bLevel[i] = bLevel[i] + 1;
    _recalc();
    popups.add(FrontierPopup(selX.toDouble(), selY.toDouble(), 'Level ${bLevel[i]}', 3));
    _say('${FrontierData.names[t]} is now level ${bLevel[i]}.');
    cues.add('good');
    return true;
  }

  // ---- info text for the HUD -----------------------------------------------

  String productionText(int i) {
    final int t = bType[i];
    final int lv = bLevel[i];
    switch (t) {
      case 0:
        return 'Makes ${(terrain[i] == 4 ? 7 : 4) * lv} food a day.';
      case 1:
        return 'Makes ${4 * lv} wood a day.';
      case 2:
        return 'Makes ${3 * lv} stone a day.';
      case 3:
        return 'Houses ${2 + 2 * lv} settlers.';
      case 4:
        return 'Makes ${lv + (tech[2] ? 1 : 0)} knowledge a day.';
      case 5:
        return 'Shelters ${6 * lv} settlers from drought.';
      case 6:
        return 'Adds ${6 * lv} defence against raids.';
      case 7:
        return 'Adds ${3 * lv} defence against raids.';
      default:
        return 'The heart of the town. Houses 6 and adds 2 defence.';
    }
  }

  String get infoTitle {
    final int i = sel;
    if (i < 0) return 'Tap a tile';
    final int t = bType[i];
    if (t == kFrontierHall) return 'Town Hall';
    if (t >= 0) return '${FrontierData.names[t]}, level ${bLevel[i]} of 3';
    return '${FrontierData.terrainNames[terrain[i]]}';
  }

  String get infoBody {
    final int i = sel;
    if (i < 0) return 'Select a tile to see what can be built there.';
    final int t = bType[i];
    if (t >= 0) return productionText(i);
    if (terrain[i] == 3) return 'Water cannot be built on.';
    final StringBuffer b = StringBuffer();
    for (int k = 0; k < 8; k++) {
      if (FrontierData.legal(k, terrain[i])) {
        if (b.length > 0) b.write(', ');
        b.write(FrontierData.shortNames[k]);
      }
    }
    String extra = '';
    if (terrain[i] == 4) extra = ' Farms yield more here.';
    return 'You can build: ${b.toString()}.$extra';
  }

  // ---- time ----------------------------------------------------------------

  @override
  void step(double dt) {
    _updateFx(dt);
    if (over || panel != 0) return;
    dayT += dt * speed;
    if (dayT >= kFrontierDayLen) {
      dayT = kFrontierDayLen;
      _endDay();
    }
  }

  void _updateFx(double dt) {
    if (toastT > 0) {
      toastT -= dt;
      if (toastT < 0) toastT = 0;
    }
    if (raidFx > 0) {
      raidFx -= dt;
      if (raidFx < 0) raidFx = 0;
    }
    for (int i = 0; i < popups.length; i++) {
      popups[i].age += dt;
    }
    popups.removeWhere((FrontierPopup p) => p.age > 1.7);
    while (popups.length > 40) {
      popups.removeAt(0);
    }
    _updateSettlers(dt);
  }

  void _updateSettlers(double dt) {
    final int want = _imin(pop, 12);
    while (settlers.length < want) {
      final FrontierSettler s = FrontierSettler(7.5, 7.9, 7.5, 7.9, _vis.nextDouble() * 2, settlers.length);
      _pickTarget(s);
      settlers.add(s);
    }
    while (settlers.length > want) {
      settlers.removeLast();
    }
    for (int k = 0; k < settlers.length; k++) {
      final FrontierSettler s = settlers[k];
      if (s.wait > 0) {
        s.wait -= dt;
        continue;
      }
      final double dx = s.tx - s.x;
      final double dy = s.ty - s.y;
      final double dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.06) {
        s.wait = 1.0 + _vis.nextDouble() * 3.0;
        _pickTarget(s);
      } else {
        final double stepLen = 1.1 * dt;
        final double m = stepLen > dist ? dist : stepLen;
        s.x += dx / dist * m;
        s.y += dy / dist * m;
        if (dx.abs() > 0.01) s.facing = dx > 0 ? 1.0 : -1.0;
        s.phase += dt * 9;
      }
    }
  }

  void _pickTarget(FrontierSettler s) {
    if (_sites.isEmpty) return;
    final int i = _sites[_vis.nextInt(_sites.length)];
    s.tx = (i % kFrontierSize) + 0.5 + (_vis.nextDouble() - 0.5) * 0.5;
    s.ty = (i ~/ kFrontierSize) + 0.92;
  }

  // ---- day end -------------------------------------------------------------

  void _endDay() {
    final int d = day;
    daysDone++;
    report.clear();

    // production
    final bool dr = isDrought(d);
    double foodMul = 1.0 + (tech[0] ? 0.3 : 0.0);
    if (dr) {
      final double cov = wellCoverage;
      foodMul = foodMul * (0.4 + 0.6 * cov);
    }
    if (foodBoost) foodMul = foodMul * 2.0;
    final double woodMul = woodBoost ? 2.0 : 1.0;
    int gF = 0;
    int gW = 0;
    int gS = 0;
    int gK = 0;
    for (int i = 0; i < kFrontierTiles; i++) {
      final int t = bType[i];
      if (t < 0 || t == kFrontierHall) continue;
      final int lv = bLevel[i];
      final double bx = (i % kFrontierSize).toDouble();
      final double by = (i ~/ kFrontierSize).toDouble();
      if (t == 0) {
        final double base = (terrain[i] == 4 ? 7.0 : 4.0) * lv;
        final int a = (base * foodMul).round();
        gF += a;
        popups.add(FrontierPopup(bx, by, '+$a', 0));
      } else if (t == 1) {
        final int a = (4.0 * lv * woodMul).round();
        gW += a;
        popups.add(FrontierPopup(bx, by, '+$a', 1));
      } else if (t == 2) {
        final int a = 3 * lv;
        gS += a;
        popups.add(FrontierPopup(bx, by, '+$a', 2));
      } else if (t == 4) {
        final int a = lv + (tech[2] ? 1 : 0);
        gK += a;
        popups.add(FrontierPopup(bx, by, '+$a', 4));
      }
    }
    food = _imin(999, food + gF);
    wood = _imin(999, wood + gW);
    stone = _imin(999, stone + gS);
    knowledge = _imin(999, knowledge + gK);
    foodBoost = false;
    woodBoost = false;
    report.add('Harvest: +$gF food, +$gW wood, +$gS stone, +$gK knowledge.');
    if (dr) {
      if (wellCoverage >= 1.0) {
        report.add('A drought struck, but your wells kept the fields green.');
      } else {
        report.add('A drought parched the fields. Wells would have helped.');
      }
    }

    // eating
    final int need = pop;
    if (food >= need) {
      food -= need;
      starved = 0;
      report.add('The settlers ate $need food.');
      // growth
      final int space = cap - pop;
      if (space > 0 && pop > 0) {
        int g = 1;
        if (food >= pop * 3 && space >= 2) g = 2;
        pop = pop + g;
        if (pop > cap) pop = cap;
        report.add('New settlers arrive. Population $pop of $cap.');
      } else if (pop >= cap) {
        report.add('The town is full. Build houses to grow.');
      }
    } else {
      final int ate = food;
      food = 0;
      starved++;
      int loss = tech[4] ? (pop + 7) ~/ 8 : (pop + 3) ~/ 4;
      if (loss < 1) loss = 1;
      if (loss > pop) loss = pop;
      pop -= loss;
      report.add('Hunger! Only $ate food for $need settlers. $loss left the town.');
    }

    // coins from taxes
    final int tax = (pop + 1) ~/ 2;
    coins = _imin(999, coins + tax);
    report.add('Taxes bring in $tax coins.');

    // raid
    if (d % 5 == 0) _raid(d);

    // ending checks
    if (pop <= 0) {
      _finish(false, 'The town fell silent.');
    } else if (starved >= starveLimit) {
      _finish(false, 'The settlers left, starving.');
    } else if (d >= kFrontierLastDay) {
      _finish(true, 'The frontier is yours.');
    } else {
      _openCouncil();
    }
  }

  void _raid(int d) {
    final double strength = raidStrength(d);
    final double def = defence;
    raidFx = 4.0;
    raidFxCount = _imin(8, 2 + d ~/ 4);
    if (def >= strength) {
      raidsHeld++;
      raidFxWon = true;
      coins = _imin(999, coins + 5);
      report.add('Raiders attacked (strength ${strength.round()}) but your defence (${def.round()}) held. +5 coins.');
      _say('The raiders were driven off.');
      return;
    }
    raidsLost++;
    raidFxWon = false;
    final double s = _cl((strength - def) / strength, 0.0, 1.0);
    final double frac = 0.12 + 0.3 * s;
    final int lf = (food * frac).floor();
    final int lw = (wood * frac).floor();
    final int ls = (stone * frac).floor();
    final int lc = (coins * frac).floor();
    food -= lf;
    wood -= lw;
    stone -= ls;
    coins -= lc;
    int lp = (pop * 0.35 * s).floor();
    if (s > 0.5 && lp < 1) lp = 1;
    if (lp > pop) lp = pop;
    pop -= lp;
    report.add('Raiders broke through (strength ${strength.round()} against ${def.round()}). Lost $lf food, $lw wood, $ls stone, $lp settlers.');
    _say('Raiders plundered the town.');
    cues.add('bad');
  }

  void _finish(bool win, String reason) {
    over = true;
    won = win;
    endReason = reason;
    panel = 0;
    cues.add(win ? 'win' : 'lose');
    _say(reason);
  }

  // ---- council -------------------------------------------------------------

  void _openCouncil() {
    final String sid = content.randomSubject();
    councilSubject = sid;
    q = content.ask(sid);
    chosen = null;
    resultLine = '';
    panel = 1;
    selX = -1;
    selY = -1;
  }

  void councilAnswer() {
    if (panel != 1) return;
    panel = 2;
  }

  void councilSkip() {
    if (panel != 1) return;
    _say('The council disperses. No blessing this time.');
    _nextDay();
  }

  void councilPick(int i) {
    final OdyQuestion? qq = q;
    if (panel != 2 || chosen != null || qq == null) return;
    if (i < 0 || i >= qq.options.length) return;
    chosen = i;
    final bool ok = i == qq.answerIndex;
    stats.record(qq, ok, chosen: ok ? 'No answer' : qq.options[i]);
    lastOk = ok;
    if (ok) {
      resultLine = 'Wise words. The elders offer a blessing.';
      cues.add('good');
    } else {
      int loss = food ~/ 5;
      if (loss < 3) loss = 3;
      if (loss > food) loss = food;
      food -= loss;
      resultLine = 'Not quite. The granary loses $loss food. Right answer: ${qq.answer}.';
      cues.add('bad');
    }
  }

  void councilContinue() {
    if (panel != 2 || chosen == null) return;
    if (lastOk) {
      panel = 3;
    } else {
      _nextDay();
    }
  }

  void chooseBlessing(int k) {
    if (panel != 3) return;
    if (k == 0) {
      foodBoost = true;
    } else if (k == 1) {
      woodBoost = true;
    } else if (k == 2) {
      knowledge = _imin(999, knowledge + 3);
    } else {
      discount = true;
    }
    _say('Blessing received: ${FrontierData.blessingNames[k]}.');
    cues.add('good');
    _nextDay();
  }

  void _nextDay() {
    day = day + 1;
    dayT = 0;
    panel = 0;
    q = null;
    chosen = null;
    final String s = _storyFor(day);
    if (s.isNotEmpty && toastT < 1.5) _say(s);
  }

  // ---- research ------------------------------------------------------------

  void openResearch() {
    if (over || panel != 0) return;
    selX = -1;
    selY = -1;
    panel = 5;
  }

  void closeResearch() {
    if (panel == 5) panel = 0;
  }

  /// The player asks to research technology [i]; a question must be answered first.
  bool startResearch(int i) {
    if (panel != 5 || i < 0 || i >= 5) return false;
    if (tech[i]) return false;
    if (knowledge < FrontierData.techCosts[i]) return false;
    resTech = i;
    final String sid = content.randomSubject();
    councilSubject = sid;
    q = content.ask(sid);
    chosen = null;
    resultLine = '';
    panel = 6;
    return true;
  }

  void researchPick(int i) {
    final OdyQuestion? qq = q;
    if (panel != 6 || chosen != null || qq == null || resTech < 0) return;
    if (i < 0 || i >= qq.options.length) return;
    chosen = i;
    final bool ok = i == qq.answerIndex;
    stats.record(qq, ok, chosen: ok ? 'No answer' : qq.options[i]);
    lastOk = ok;
    if (ok) {
      knowledge -= FrontierData.techCosts[resTech];
      if (knowledge < 0) knowledge = 0;
      tech[resTech] = true;
      resultLine = 'Theory proven. ${FrontierData.techNames[resTech]} is researched.';
      cues.add('good');
    } else {
      resultLine = 'The theory fails the test. Try again later. Right answer: ${qq.answer}.';
      cues.add('bad');
    }
  }

  void researchContinue() {
    if (panel != 6 || chosen == null) return;
    panel = lastOk ? 0 : 5;
    q = null;
    chosen = null;
    if (lastOk) _say('${FrontierData.techNames[resTech]} will serve the town well.');
  }

  int get techCount {
    int n = 0;
    for (int i = 0; i < 5; i++) {
      if (tech[i]) n++;
    }
    return n;
  }

  // ---- results -------------------------------------------------------------

  @override
  int get finalScore => daysDone * 20 + pop * 30 + buildingCount * 10 + (won ? 300 : 0);

  @override
  int get xp => stats.baseXp + daysDone ~/ 3;

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Day $day/$kFrontierLastDay', Icons.wb_sunny_rounded, const Color(0xFFFFD54F)),
        RealmChip('$food', Icons.restaurant_rounded, const Color(0xFF9CCC65)),
        RealmChip('$wood', Icons.forest_rounded, const Color(0xFFBCAAA4)),
        RealmChip('$stone', Icons.landscape_rounded, const Color(0xFFB0BEC5)),
        RealmChip('$knowledge', Icons.menu_book_rounded, const Color(0xFF81D4FA)),
        RealmChip('$pop/$cap', Icons.groups_rounded, const Color(0xFFFFAB91)),
        RealmChip('$coins', Icons.paid_rounded, const Color(0xFFFFD54F)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Days survived': '$daysDone',
        'Population': '$pop',
        'Buildings': '$buildingCount',
        'Technologies': '$techCount',
        'Outcome': endReason.isEmpty ? 'Left early' : endReason,
      };
}
