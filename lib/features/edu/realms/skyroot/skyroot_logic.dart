import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';

// ---------------------------------------------------------------------------
// World layout. Y grows downward. Layer 0 (Stream and Roots) is at the bottom,
// layer 4 (Crown) at the top.

const double skyW = 900;
const double skyH = 3600;
const double skyTrunkX = 450;
const List<double> skyLayerTop = <double>[2850, 2100, 1350, 600, 0];
const List<String> skyLayerNames = <String>['Stream and Roots', 'Forest Floor', 'Understory', 'Canopy', 'Crown'];
const List<String> skyLayerShort = <String>['RT', 'FL', 'UN', 'CA', 'CR'];
const List<String> skyStationNames = <String>['Water Test', 'Nutrient Cycle', 'Food Chain', 'Adaptations', 'The Blight Boss'];
const List<Offset> skyStations = <Offset>[
  Offset(205, 3385),
  Offset(690, 2640),
  Offset(205, 1790),
  Offset(715, 1010),
  Offset(595, 338),
];
const List<String> skyBloomNotes = <String>[
  'A mudskipper hops onto the mud and the river runs clear.',
  'A pangolin peeks out from the leaf litter.',
  'A bat wakes and a chameleon creeps out on a leaf.',
  'A hornbill lands on the branch and calls.',
  'The whole canopy hums with birds again.',
];

int skyLayerOf(double y) {
  if (y >= skyLayerTop[0]) return 0;
  if (y >= skyLayerTop[1]) return 1;
  if (y >= skyLayerTop[2]) return 2;
  if (y >= skyLayerTop[3]) return 3;
  return 4;
}

/// A thick line the ranger can stand or climb on. kind: 0 trunk, 1 branch, 2 vine.
class SkySeg {
  final double ax, ay, bx, by, r;
  final int kind;
  const SkySeg(this.ax, this.ay, this.bx, this.by, this.r, this.kind);

  double dist(double px, double py) {
    final double dx = bx - ax;
    final double dy = by - ay;
    final double l2 = dx * dx + dy * dy;
    double t = l2 == 0 ? 0.0 : ((px - ax) * dx + (py - ay) * dy) / l2;
    if (t < 0) t = 0;
    if (t > 1) t = 1;
    final double cx = ax + dx * t - px;
    final double cy = ay + dy * t - py;
    return sqrt(cx * cx + cy * cy);
  }

  bool contains(double px, double py) => dist(px, py) <= r;
}

const List<SkySeg> skySegs = <SkySeg>[
  SkySeg(450, 3400, 450, 260, 52, 0),
  // roots and bank
  SkySeg(450, 3410, 190, 3400, 26, 1),
  SkySeg(450, 3430, 730, 3440, 26, 1),
  // forest floor
  SkySeg(450, 2690, 700, 2640, 24, 1),
  SkySeg(450, 2420, 210, 2360, 22, 1),
  // understory
  SkySeg(450, 1850, 200, 1790, 24, 1),
  SkySeg(450, 1560, 710, 1500, 22, 1),
  // canopy
  SkySeg(450, 1090, 720, 1010, 24, 1),
  SkySeg(450, 830, 190, 760, 22, 1),
  // crown
  SkySeg(450, 420, 600, 340, 26, 1),
  SkySeg(450, 500, 250, 420, 22, 1),
  // hanging vines
  SkySeg(710, 1500, 722, 1760, 12, 2),
  SkySeg(200, 1790, 182, 2060, 12, 2),
  SkySeg(190, 760, 176, 1000, 12, 2),
  SkySeg(720, 1010, 738, 1250, 12, 2),
  SkySeg(210, 2360, 222, 2560, 12, 2),
  SkySeg(700, 2640, 712, 2830, 12, 2),
  SkySeg(250, 420, 244, 600, 12, 2),
];

const List<Offset> skyPodSpots = <Offset>[
  Offset(200, 3385),
  Offset(728, 3430),
  Offset(705, 2632),
  Offset(215, 2372),
  Offset(190, 1783),
  Offset(704, 1506),
  Offset(712, 1004),
  Offset(186, 755),
  Offset(255, 428),
  Offset(722, 1750),
  Offset(184, 2050),
  Offset(177, 990),
  Offset(738, 1242),
  Offset(222, 2552),
  Offset(244, 590),
  Offset(711, 2822),
];

// ---------------------------------------------------------------------------
// Content banks.

class SkyWater {
  final String site;
  final double ph;
  final double nitrate;
  final double turbidity;
  final String note;
  final List<String> sources;
  final List<String> fixes;
  final String why;
  // The first entry of sources and fixes is always the right one; the logic
  // shuffles them for each visit.
  const SkyWater(this.site, this.ph, this.nitrate, this.turbidity, this.note, this.sources, this.fixes, this.why);
}

const List<SkyWater> skyWaterBank = <SkyWater>[
  SkyWater(
    'Ofada stream, below a cassava mill', 4.1, 6, 28,
    'The water smells sour and small fish are floating. A cassava grating mill drains into the stream.',
    <String>['Waste water from a cassava mill', 'Fertiliser washed off a maize farm', 'Soil washed down a bare hillside'],
    <String>['Collect the mill waste in settling pits and treat it before release', 'Add more fertiliser to the farm upstream', 'Pour sand into the stream to hide the smell'],
    'Acid water (low pH) with a sour smell points to cassava waste water. Settling and treating it protects the fish.',
  ),
  SkyWater(
    'Pond below a maize farm', 7.5, 44, 14,
    'Thick green scum covers the water and fish gasp at the surface in the morning. The farm uses a lot of fertiliser.',
    <String>['Fertiliser washed off the farm', 'Engine oil from a workshop', 'Waste water from a quarry'],
    <String>['Plant a belt of grass and trees between farm and water to trap nutrients', 'Cut down the trees along the bank', 'Stir the scum deep into the pond'],
    'Very high nitrate feeds algae. A planted buffer strip traps nutrients before they reach the water.',
  ),
  SkyWater(
    'Ose river, after heavy rain', 7.0, 5, 90,
    'The river runs the colour of cocoa. Trees were cleared along the bank for a new road.',
    <String>['Soil washed off bare cleared land', 'Sewage from a leaking latrine', 'Acid drainage from a mine'],
    <String>['Replant trees and grass on the bare bank to hold the soil', 'Dig the bank deeper to make a wider channel', 'Pour lime into the river'],
    'Normal pH and low nitrate but very cloudy water means soil is being washed in. Roots hold soil in place.',
  ),
  SkyWater(
    'Village stream beside a pit latrine', 7.1, 31, 38,
    'Children get stomach illness after drinking here. A pit latrine was dug just above the stream and there is a bad smell.',
    <String>['Waste leaking from a latrine', 'Soap from washing clothes', 'Engine oil from a workshop'],
    <String>['Move the latrine far from the water, build a sealed one and boil drinking water', 'Wash the goats in the stream more often', 'Open a new path through the stream'],
    'High nitrate with germs and a bad smell points to human waste. Keep latrines far away and treat drinking water.',
  ),
  SkyWater(
    'Stream below a gold mining pit', 3.6, 3, 62,
    'Rocks are stained orange and nothing grows in the water. Water pumped out of a mining pit flows in.',
    <String>['Acid drainage from the mining pit', 'Fertiliser from a farm', 'Cattle trampling the bank'],
    <String>['Pump pit water into lime ponds to neutralise it before release', 'Add more fish to the stream', 'Scrub the stained rocks every day'],
    'Very low pH and orange stain are signs of mine drainage. Lime neutralises the acid.',
  ),
  SkyWater(
    'Washing place on the Asa stream', 9.5, 11, 24,
    'White foam floats on the water below the spot where clothes are washed.',
    <String>['Detergent from washing clothes', 'Waste water from a cassava mill', 'Waste leaking from a latrine'],
    <String>['Wash on land away from the stream, use less detergent and let used water soak into soil', 'Wash faster in the middle of the stream', 'Add more detergent so the foam clears'],
    'A high pH and white foam point to detergent. Washing on land lets the soil filter the soapy water.',
  ),
  SkyWater(
    'Creek beside a mechanic village', 6.9, 2, 20,
    'A rainbow film shines on the water and a smell of fuel hangs in the air. A workshop drains beside the creek.',
    <String>['Engine oil from the workshop', 'Fertiliser runoff from a farm', 'Soil from a cleared hillside'],
    <String>['Stop the drain, soak up the oil and catch workshop oil in a sump', 'Set the oil film on fire', 'Wash the oil away with soap'],
    'A rainbow film on water is oil. Oil floats and blocks oxygen, so it must be caught at the source.',
  ),
  SkyWater(
    'Cattle watering point', 7.4, 36, 58,
    'The bank is trampled to mud and the water is cloudy and smelly where a large herd drinks.',
    <String>['Cattle dung and a trampled bank', 'Acid from a mine', 'Detergent from washing'],
    <String>['Fence the bank and build a trough so cattle drink away from the stream', 'Drive the herd into the stream to stir it', 'Plough the bank right to the water'],
    'Raised nitrate and cloudy water beside trampled banks point to cattle. A fence and trough protect the stream.',
  ),
  SkyWater(
    'Creek below a palm oil mill', 4.8, 14, 74,
    'The water is dark brown, warm and oily with a sweet rotting smell. A palm oil mill releases its waste here.',
    <String>['Waste liquid from a palm oil mill', 'Fertiliser from a cocoa farm', 'Soil from a new road'],
    <String>['Keep mill waste in lined ponds and treat it before it leaves the mill', 'Pour clean water in to dilute it', 'Block the creek with soil'],
    'Acid, dark, oily and warm water points to palm oil mill waste. Treatment ponds break it down before release.',
  ),
];

class SkyOrg {
  final String name;
  final int role; // 0 producer, 1 consumer, 2 decomposer
  final String fact;
  const SkyOrg(this.name, this.role, this.fact);
}

const List<String> skyRoleNames = <String>['PRODUCER', 'CONSUMER', 'DECOMPOSER'];

const List<SkyOrg> skyOrgBank = <SkyOrg>[
  // producers
  SkyOrg('Oil palm', 0, 'It makes its own food from sunlight, water and carbon dioxide.'),
  SkyOrg('Iroko tree', 0, 'Green leaves make food by photosynthesis.'),
  SkyOrg('Cassava plant', 0, 'It makes starch in its leaves and stores it in the roots.'),
  SkyOrg('Mango tree', 0, 'It is a green plant that makes its own food.'),
  SkyOrg('Spear grass', 0, 'Grass uses sunlight to make food, so it starts food chains.'),
  SkyOrg('Green algae in the stream', 0, 'Algae have chlorophyll and make food in water.'),
  SkyOrg('Water lily', 0, 'Its floating leaves catch sunlight to make food.'),
  SkyOrg('Moss on a root', 0, 'Moss is a small green plant that photosynthesises.'),
  SkyOrg('Cocoa tree', 0, 'Its leaves make the sugar that grows the pods.'),
  SkyOrg('Cocoyam plant', 0, 'Broad green leaves make food for the tuber.'),
  SkyOrg('Baobab tree', 0, 'A giant green plant that makes its own food.'),
  // consumers
  SkyOrg('Hornbill eating a fig', 1, 'It cannot make food, so it eats fruit and insects.'),
  SkyOrg('Pangolin licking up ants', 1, 'It feeds on other living things.'),
  SkyOrg('Grasshopper chewing grass', 1, 'A primary consumer that eats plants.'),
  SkyOrg('Grasscutter gnawing cane', 1, 'It eats plants, so it is a consumer.'),
  SkyOrg('Duiker antelope', 1, 'It browses leaves and fruit.'),
  SkyOrg('Python', 1, 'A secondary consumer that eats animals.'),
  SkyOrg('Fruit bat', 1, 'It eats ripe fruit and spreads the seeds.'),
  SkyOrg('Tilapia eating insects', 1, 'It gets energy by eating other animals.'),
  SkyOrg('Sunbird sipping nectar', 1, 'It feeds on nectar and small insects.'),
  SkyOrg('Mudskipper', 1, 'It eats small crabs and insects on the mud.'),
  SkyOrg('Tree frog catching a fly', 1, 'It feeds on insects.'),
  SkyOrg('Garden snail eating leaves', 1, 'It eats living leaves.'),
  SkyOrg('Chimpanzee', 1, 'It eats fruit, leaves and sometimes insects.'),
  // decomposers
  SkyOrg('Mushroom on a rotting log', 2, 'Fungi break down dead wood and return minerals to the soil.'),
  SkyOrg('Bracket fungus on a dead tree', 2, 'It feeds on dead wood and rots it.'),
  SkyOrg('Bread mould', 2, 'Mould digests dead food and releases nutrients.'),
  SkyOrg('Bacteria of decay in leaf litter', 2, 'They rot dead leaves into humus.'),
  SkyOrg('Soil fungi', 2, 'They digest dead roots and leaves.'),
  SkyOrg('Mould on a rotting mango', 2, 'It feeds on dead fruit and breaks it down.'),
  SkyOrg('Bacteria that rot a dead rat', 2, 'Bacteria of decay recycle dead animals.'),
  SkyOrg('Shelf fungus on a stump', 2, 'It digests dead wood and recycles it.'),
];

class SkyChain {
  final List<String> names; // producer first
  const SkyChain(this.names);
}

const List<SkyChain> skyChainBank = <SkyChain>[
  SkyChain(<String>['Spear grass', 'Grasshopper', 'Toad', 'Green snake', 'Snake eagle']),
  SkyChain(<String>['Algae', 'Water flea', 'Tilapia', 'Catfish', 'Fish eagle']),
  SkyChain(<String>['Cassava leaves', 'Caterpillar', 'Agama lizard', 'Cobra', 'Hawk']),
  SkyChain(<String>['Wild fig', 'Fruit fly', 'Gecko', 'Tree snake', 'Crowned eagle']),
  SkyChain(<String>['Oil palm fruit', 'Palm weevil', 'Shrew', 'Python', 'Leopard']),
  SkyChain(<String>['Lagoon algae', 'Shrimp', 'Mudskipper', 'Heron', 'Fish eagle']),
  SkyChain(<String>['Cocoa leaves', 'Mirid bug', 'Praying mantis', 'Sunbird', 'Sparrowhawk']),
  SkyChain(<String>['Elephant grass', 'Grasscutter', 'Cobra', 'Mongoose', 'Leopard']),
  SkyChain(<String>['Mango leaves', 'Leaf beetle', 'Spider', 'Tree frog', 'Green snake']),
  SkyChain(<String>['Phytoplankton', 'Zooplankton', 'Sardine', 'Tuna', 'Dolphin']),
  SkyChain(<String>['Rice plant', 'Stem borer', 'Frog', 'Water snake', 'Fish eagle']),
];

class SkyPair {
  final String who;
  final String trait;
  const SkyPair(this.who, this.trait);
}

const List<SkyPair> skyPairBank = <SkyPair>[
  SkyPair('Pangolin', 'Hard overlapping scales that curl into a ball'),
  SkyPair('Chameleon', 'Eyes that swivel and skin that changes colour'),
  SkyPair('Mudskipper', 'Fins that walk on mud and gills kept moist'),
  SkyPair('Insect-eating bat', 'Squeaks and listens to echoes to hunt in the dark'),
  SkyPair('Hornbill', 'Strong curved bill for picking fruit and seeds'),
  SkyPair('Gecko', 'Sticky toe pads that grip smooth leaves'),
  SkyPair('Weaver bird', 'Skilful beak that knots grass into hanging nests'),
  SkyPair('Termite colony', 'Tall mound with air channels that keeps the nest cool'),
  SkyPair('Python', 'Flexible jaws that swallow prey whole'),
  SkyPair('Sunbird', 'Thin curved bill for sipping nectar'),
  SkyPair('Iroko tree', 'Buttress roots that support a very tall trunk'),
  SkyPair('Mangrove tree', 'Stilt roots that stand in salty mud'),
  SkyPair('Oil palm', 'Crown of long leaves held high to catch sunlight'),
  SkyPair('Baobab tree', 'Swollen trunk that stores water for the dry season'),
  SkyPair('Water lily', 'Flat floating leaves with air spaces'),
  SkyPair('Acacia tree', 'Sharp thorns that keep browsing animals away'),
  SkyPair('Orchid on a branch', 'Roots that take moisture from the air'),
  SkyPair('Liana vine', 'Twisting stem that climbs trunks to reach light'),
  SkyPair('Frog', 'Moist skin and webbed feet for swimming'),
  SkyPair('Owl', 'Large forward eyes and silent feathers for night hunting'),
  SkyPair('Duiker antelope', 'Brown coat and slim legs to dart through the undergrowth'),
  SkyPair('Giant pouched rat', 'Cheek pouches to carry food home'),
  SkyPair('Kingfisher', 'Sharp bill and a dive to catch fish'),
  SkyPair('Colobus monkey', 'Long tail for balance when leaping between branches'),
];

// ---------------------------------------------------------------------------

class SkyrootLogic extends RealmLogic {
  SkyrootLogic(RealmContent content) : super(content) {
    // Starting pressure: a little blight at the roots, almost none above.
    blight = <double>[24, 14, 8, 3, 0];
    shown = List<double>.from(blight);
    pos = const Offset(450, 3330);
    camX = 450;
    camY = 3290;
    podTaken = List<bool>.filled(skyPodSpots.length, false);
  }

  // ---- ranger and world -----------------------------------------------------
  Offset pos = const Offset(450, 3330);
  double facing = 1;
  bool moving = false;
  bool onLedge = false;
  double climbPhase = 0;
  int nearIdx = -1;
  double camX = 450;
  double camY = 3250;

  // ---- blight ---------------------------------------------------------------
  List<double> blight = <double>[];
  List<double> shown = <double>[];
  final List<double> shield = <double>[0, 0, 0, 0, 0];
  final List<bool> tended = <bool>[false, false, false, false, false];
  final List<int> tendCount = <int>[0, 0, 0, 0, 0];
  final List<double> bloom = <double>[0, 0, 0, 0, 0];
  List<bool> podTaken = <bool>[];
  int seeds = 0;
  int tendScore = 0;

  // ---- panels ---------------------------------------------------------------
  /// 0 none, 1 water, 2 cycle, 3 chain, 4 adapt, 5 boss, 6 summary, 7 quiet.
  int panel = 0;
  String hint = '';
  String toastText = '';
  double toastT = 0;
  int shakeKey = -1;
  double shakeAt = -10;

  // summary card
  String sumTitle = '';
  String sumBody = '';
  String sumLine = '';
  int sumPoints = 0;
  bool sumGood = true;

  // task tallies for the current panel
  int _taskOk = 0;
  int _taskTotal = 0;

  // water
  SkyWater? water;
  List<String> waterSrcOpts = <String>[];
  List<String> waterFixOpts = <String>[];
  int waterSrcAns = 0;
  int waterFixAns = 0;
  int waterStage = 0; // 0 source, 1 fix, 2 done
  final Set<int> waterWrong = <int>{};
  bool _waterFirst = true;
  String _waterFirstWrong = '';
  final List<int> _waterBag = <int>[];

  // cycle
  List<SkyOrg> cycItems = <SkyOrg>[];
  int cycIdx = 0;
  final Set<int> cycWrong = <int>{};
  bool _cycFirst = true;
  String _cycFirstWrong = '';
  String cycLast = '';
  final List<bool> cycResults = <bool>[];
  final List<int> _orgBag = <int>[];

  // chain
  SkyChain? chain;
  List<int> chnPerm = <int>[]; // slot -> species index
  List<int> chnTaken = <int>[]; // slot -> order number (1..5) or 0
  int chnNext = 0;
  bool _chnOrderFirst = true;
  String _chnFirstWrong = '';
  int chnStage = 0; // 0 order, 1 question, 2 done
  int chnRemoved = 1;
  List<int> chnOpts = <int>[]; // code: bit0 prey rises, bit1 predator rises
  final Set<int> chnWrong = <int>{};
  bool _chnQFirst = true;
  String _chnQFirstWrong = '';
  final List<int> _chainBag = <int>[];

  // adaptations
  List<SkyPair> adPairs = <SkyPair>[];
  List<int> adTraitOrder = <int>[]; // trait slot -> pair index
  List<bool> adLocked = <bool>[];
  List<bool> adFirst = <bool>[];
  List<String> adFirstWrong = <String>[];
  List<bool> adTraitLocked = <bool>[];
  int adSel = -1;
  final List<int> _pairBag = <int>[];

  // boss
  bool bossActive = false;
  bool bossLocked = false;
  bool bossWon = false;
  int bossCleared = 0;
  int bossBest = 0;
  int bossLeaves = 3;
  OdyQuestion? bossQ;
  int? bossChosen;
  String bossResult = '';

  @override
  int get hearts => bossActive && !bossWon ? bossLeaves : -1;

  @override
  int get maxHearts => 3;

  @override
  bool get modal => panel != 0;

  int get layersBloomed {
    int n = 0;
    for (int i = 0; i < 4; i++) {
      if (tended[i]) n++;
    }
    return n;
  }

  bool get allBelowTended => layersBloomed >= 4;

  // ---- main step ------------------------------------------------------------

  @override
  void step(double dt) {
    final double k = min(1.0, dt * 2.5);
    for (int i = 0; i < 5; i++) {
      shown[i] += (blight[i] - shown[i]) * k;
      final double target = tended[i] ? ((62 - blight[i]) / 40).clamp(0.0, 1.0).toDouble() : 0.0;
      bloom[i] += (target - bloom[i]) * min(1.0, dt * 1.2);
    }
    if (toastT > 0) toastT -= dt;
    final double ck = min(1.0, dt * 4.0);
    camX += (pos.dx - camX) * ck;
    camY += (pos.dy - 40 - camY) * ck;
    _updateNear();
    if (panel != 0 || over) return;
    _moveRanger(dt);
    _collectPods();
    _growBlight(dt);
    if (blight[4] >= 100 && !bossWon) {
      blight[4] = 100;
      panel = 7;
      inputX = 0;
      inputY = 0;
      moving = false;
      cues.add('lose');
    }
  }

  void _growBlight(double dt) {
    for (int i = 0; i < 5; i++) {
      if (shield[i] > 0) {
        shield[i] -= dt;
        continue;
      }
      final double gate = i == 0 ? 1.0 : ((blight[i - 1] - 35) / 25).clamp(0.0, 1.0).toDouble();
      blight[i] = min(100.0, blight[i] + 1.0 * gate * dt);
    }
  }

  bool _walkable(double x, double y) {
    if (x < 20 || x > skyW - 20 || y < 120 || y > skyH - 20) return false;
    for (final SkySeg s in skySegs) {
      if (s.contains(x, y)) return true;
    }
    return false;
  }

  void _moveRanger(double dt) {
    const double speed = 150;
    final double ix = inputX;
    final double iy = inputY;
    moving = (ix.abs() + iy.abs()) > 0.06;
    if (moving) {
      final double mx = ix * speed * dt;
      final double my = iy * speed * dt;
      final double nx = pos.dx + mx;
      final double ny = pos.dy + my;
      bool moved = false;
      if (_walkable(nx, ny)) {
        pos = Offset(nx, ny);
        moved = true;
      } else {
        // slide along one axis
        if (_walkable(nx, pos.dy)) {
          pos = Offset(nx, pos.dy);
          moved = true;
        } else if (_walkable(pos.dx, ny)) {
          pos = Offset(pos.dx, ny);
          moved = true;
        }
      }
      if (!moved) {
        // follow the axis of a branch the ranger is standing on
        for (final SkySeg s in skySegs) {
          if (!s.contains(pos.dx, pos.dy)) continue;
          double ax = s.bx - s.ax;
          double ay = s.by - s.ay;
          final double len = sqrt(ax * ax + ay * ay);
          if (len < 1) continue;
          ax /= len;
          ay /= len;
          final double dot = ix * ax + iy * ay;
          if (dot.abs() < 0.2) continue;
          final double tx = pos.dx + ax * dot * speed * dt;
          final double ty = pos.dy + ay * dot * speed * dt;
          if (_walkable(tx, ty)) {
            pos = Offset(tx, ty);
            moved = true;
            break;
          }
        }
      }
      if (moved) {
        climbPhase += (mx.abs() + my.abs()) * 0.09 + 0.02;
      }
      if (ix.abs() > 0.15) facing = ix > 0 ? 1.0 : -1.0;
    }
    // standing on a branch (away from the trunk) uses the walking pose
    onLedge = false;
    if ((pos.dx - skyTrunkX).abs() > 46) {
      for (final SkySeg s in skySegs) {
        if (s.kind == 1 && s.dist(pos.dx, pos.dy) <= s.r * 0.8) {
          onLedge = true;
          break;
        }
      }
    }
  }

  void _collectPods() {
    for (int i = 0; i < skyPodSpots.length; i++) {
      if (podTaken[i]) continue;
      final Offset d = skyPodSpots[i] - pos;
      if (d.dx * d.dx + d.dy * d.dy < 30 * 30) {
        podTaken[i] = true;
        seeds++;
        cues.add('tap');
        _toast('Seed pod collected');
      }
    }
  }

  void _updateNear() {
    int best = -1;
    double bd = 70;
    for (int i = 0; i < 5; i++) {
      final double d = (skyStations[i] - pos).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    nearIdx = best;
  }

  void _toast(String t) {
    toastText = t;
    toastT = 2.2;
  }

  double shakeOffset(int key) {
    if (key != shakeKey) return 0;
    final double d = time - shakeAt;
    if (d < 0 || d > 0.45) return 0;
    return sin(d * 55) * 8 * (1 - d / 0.45);
  }

  void _shake(int key) {
    shakeKey = key;
    shakeAt = time;
  }

  // ---- station state --------------------------------------------------------

  bool stationReady(int i) {
    if (i < 0 || i > 4) return false;
    if (i < 4) return !tended[i] || blight[i] > 60 || bossLocked;
    return allBelowTended && !bossLocked && !bossWon;
  }

  String? get stationPrompt {
    final int i = nearIdx;
    if (i < 0) return null;
    if (i < 4) {
      if (!tended[i]) return 'TEND: ${skyStationNames[i]}';
      if (blight[i] > 60 || bossLocked) return 'TEND AGAIN: ${skyStationNames[i]}';
      return '${skyLayerNames[i]} is blooming. Nothing to tend now.';
    }
    if (!allBelowTended) return 'Tend the four layers below first';
    if (bossLocked) return 'The Blight pushed back. Tend a layer, then return';
    return 'FACE THE BLIGHT';
  }

  @override
  double actionReady(int id) => stationReady(nearIdx) ? 1.0 : 0.0;

  @override
  void onAction(int id) {
    if (id != 0 || panel != 0 || over) return;
    final int i = nearIdx;
    if (!stationReady(i)) return;
    inputX = 0;
    inputY = 0;
    moving = false;
    hint = '';
    _taskOk = 0;
    _taskTotal = 0;
    switch (i) {
      case 0:
        _openWater();
        break;
      case 1:
        _openCycle();
        break;
      case 2:
        _openChain();
        break;
      case 3:
        _openAdapt();
        break;
      default:
        _openBoss();
        break;
    }
    cues.add('tap');
  }

  void closePanel() {
    if (panel >= 1 && panel <= 5) {
      panel = 0;
      hint = '';
    }
  }

  // ---- bag helper -------------------------------------------------------------

  int _bagPick(List<int> bag, int size) {
    if (bag.isEmpty) {
      for (int i = 0; i < size; i++) {
        bag.add(i);
      }
      bag.shuffle(rng);
    }
    return bag.removeLast();
  }

  // ---- 1 water test ---------------------------------------------------------

  void _openWater() {
    final SkyWater w = skyWaterBank[_bagPick(_waterBag, skyWaterBank.length)];
    water = w;
    final List<int> so = <int>[0, 1, 2]..shuffle(rng);
    final List<int> fo = <int>[0, 1, 2]..shuffle(rng);
    waterSrcOpts = <String>[for (final int i in so) w.sources[i]];
    waterFixOpts = <String>[for (final int i in fo) w.fixes[i]];
    waterSrcAns = so.indexOf(0);
    waterFixAns = fo.indexOf(0);
    waterStage = 0;
    waterWrong.clear();
    _waterFirst = true;
    _waterFirstWrong = '';
    panel = 1;
  }

  void waterPick(int i) {
    final SkyWater? w = water;
    if (w == null || waterStage > 1 || waterWrong.contains(i)) return;
    final bool src = waterStage == 0;
    final int ans = src ? waterSrcAns : waterFixAns;
    final List<String> opts = src ? waterSrcOpts : waterFixOpts;
    if (i < 0 || i >= opts.length) return;
    if (i == ans) {
      stats.recordTask(
        'biology',
        _waterFirst,
        prompt: src ? 'Water test at ${w.site}: what is the most likely source of the pollution?' : 'Water test at ${w.site}: what is the best fix?',
        chosen: _waterFirst ? opts[ans] : _waterFirstWrong,
        answer: opts[ans],
      );
      _taskTotal++;
      if (_waterFirst) _taskOk++;
      cues.add('good');
      waterWrong.clear();
      _waterFirst = true;
      _waterFirstWrong = '';
      waterStage++;
      hint = '';
    } else {
      if (_waterFirst) _waterFirstWrong = opts[i];
      _waterFirst = false;
      waterWrong.add(i);
      _shake(i);
      cues.add('bad');
      hint = 'Look at the three readings and the note again.';
    }
  }

  void waterFinish() {
    if (waterStage < 2) return;
    _completeTend(0);
  }

  // ---- 2 nutrient cycle -----------------------------------------------------

  void _openCycle() {
    final List<List<int>> byRole = <List<int>>[<int>[], <int>[], <int>[]];
    for (int i = 0; i < skyOrgBank.length; i++) {
      byRole[skyOrgBank[i].role].add(i);
    }
    final List<SkyOrg> picked = <SkyOrg>[];
    for (int r = 0; r < 3; r++) {
      byRole[r].shuffle(rng);
      for (int j = 0; j < 2; j++) {
        picked.add(skyOrgBank[byRole[r][j]]);
      }
    }
    picked.shuffle(rng);
    cycItems = picked;
    cycIdx = 0;
    cycWrong.clear();
    cycResults.clear();
    _cycFirst = true;
    _cycFirstWrong = '';
    cycLast = '';
    panel = 2;
  }

  bool get cycDone => cycIdx >= cycItems.length;

  void cyclePick(int role) {
    if (cycDone || cycWrong.contains(role)) return;
    final SkyOrg o = cycItems[cycIdx];
    if (role == o.role) {
      stats.recordTask(
        'biology',
        _cycFirst,
        prompt: 'In the forest nutrient cycle, what is "${o.name}"?',
        chosen: _cycFirst ? skyRoleNames[o.role] : _cycFirstWrong,
        answer: skyRoleNames[o.role],
      );
      _taskTotal++;
      if (_cycFirst) _taskOk++;
      cycResults.add(_cycFirst);
      cycLast = '${o.name}: ${skyRoleNames[o.role].toLowerCase()}. ${o.fact}';
      cycIdx++;
      cycWrong.clear();
      _cycFirst = true;
      _cycFirstWrong = '';
      hint = '';
      cues.add('good');
    } else {
      if (_cycFirst) _cycFirstWrong = skyRoleNames[role];
      _cycFirst = false;
      cycWrong.add(role);
      _shake(role);
      cues.add('bad');
      hint = 'Producers make food, consumers eat other living things, decomposers rot the dead.';
    }
  }

  void cycleFinish() {
    if (!cycDone) return;
    _completeTend(1);
  }

  // ---- 3 food chain ---------------------------------------------------------

  void _openChain() {
    final SkyChain c = skyChainBank[_bagPick(_chainBag, skyChainBank.length)];
    chain = c;
    chnPerm = <int>[0, 1, 2, 3, 4]..shuffle(rng);
    // make sure the cards are not already in the right order
    if (chnPerm[0] == 0 && chnPerm[1] == 1 && chnPerm[2] == 2) {
      chnPerm = <int>[chnPerm[4], chnPerm[3], chnPerm[2], chnPerm[1], chnPerm[0]];
    }
    chnTaken = <int>[0, 0, 0, 0, 0];
    chnNext = 0;
    _chnOrderFirst = true;
    _chnFirstWrong = '';
    chnStage = 0;
    chnRemoved = 1 + rng.nextInt(3);
    // option codes: bit0 means the food of the lost species rises,
    // bit1 means its predator rises. The only right answer is "prey up, predator down" = code 1.
    final List<int> wrong = <int>[0, 2, 3]..shuffle(rng);
    chnOpts = <int>[1, wrong[0], wrong[1]]..shuffle(rng);
    chnWrong.clear();
    _chnQFirst = true;
    _chnQFirstWrong = '';
    panel = 3;
  }

  String get chnQuestion {
    final SkyChain? c = chain;
    if (c == null) return '';
    return 'The ${c.names[chnRemoved]} disappears from the forest. What happens to the ${c.names[chnRemoved - 1]} and the ${c.names[chnRemoved + 1]}?';
  }

  String chnOptionText(int code) {
    final SkyChain? c = chain;
    if (c == null) return '';
    final String a = c.names[chnRemoved - 1];
    final String b = c.names[chnRemoved + 1];
    return '$a ${(code & 1) != 0 ? 'increase' : 'decrease'}, $b ${(code & 2) != 0 ? 'increase' : 'decrease'}';
  }

  void chainTap(int slot) {
    final SkyChain? c = chain;
    if (c == null || chnStage != 0 || slot < 0 || slot >= 5 || chnTaken[slot] != 0) return;
    if (chnPerm[slot] == chnNext) {
      chnNext++;
      chnTaken[slot] = chnNext;
      cues.add('tap');
      hint = '';
      if (chnNext >= 5) {
        stats.recordTask(
          'biology',
          _chnOrderFirst,
          prompt: 'Put this food chain in the order energy flows: ${c.names.join(', ')}',
          chosen: _chnOrderFirst ? c.names.join(' -> ') : _chnFirstWrong,
          answer: c.names.join(' -> '),
        );
        _taskTotal++;
        if (_chnOrderFirst) _taskOk++;
        cues.add('good');
        chnStage = 1;
      }
    } else {
      if (_chnOrderFirst) _chnFirstWrong = 'Tapped ${c.names[chnPerm[slot]]} when ${c.names[chnNext]} was next';
      _chnOrderFirst = false;
      _shake(slot);
      cues.add('bad');
      hint = chnNext == 0 ? 'Energy starts with the producer, the green plant.' : 'Energy passes to the animal that eats the one you just tapped.';
    }
  }

  void chainPick(int i) {
    final SkyChain? c = chain;
    if (c == null || chnStage != 1 || i < 0 || i >= chnOpts.length || chnWrong.contains(i)) return;
    if (chnOpts[i] == 1) {
      stats.recordTask(
        'biology',
        _chnQFirst,
        prompt: chnQuestion,
        chosen: _chnQFirst ? chnOptionText(1) : _chnQFirstWrong,
        answer: chnOptionText(1),
      );
      _taskTotal++;
      if (_chnQFirst) _taskOk++;
      cues.add('good');
      chnStage = 2;
      hint = 'Its food is no longer eaten, so it increases. The animals that ate it lose their food and decrease.';
    } else {
      if (_chnQFirst) _chnQFirstWrong = chnOptionText(chnOpts[i]);
      _chnQFirst = false;
      chnWrong.add(i);
      _shake(20 + i);
      cues.add('bad');
      hint = 'Think about who eats it and who it eats.';
    }
  }

  void chainFinish() {
    if (chnStage < 2) return;
    _completeTend(2);
  }

  // ---- 4 adaptations --------------------------------------------------------

  void _openAdapt() {
    final List<int> idx = <int>[];
    while (idx.length < 4) {
      final int p = _bagPick(_pairBag, skyPairBank.length);
      if (!idx.contains(p)) idx.add(p);
    }
    adPairs = <SkyPair>[for (final int i in idx) skyPairBank[i]];
    adTraitOrder = <int>[0, 1, 2, 3]..shuffle(rng);
    adLocked = <bool>[false, false, false, false];
    adTraitLocked = <bool>[false, false, false, false];
    adFirst = <bool>[true, true, true, true];
    adFirstWrong = <String>['', '', '', ''];
    adSel = -1;
    panel = 4;
  }

  bool get adDone {
    if (adLocked.isEmpty) return false;
    for (final bool b in adLocked) {
      if (!b) return false;
    }
    return true;
  }

  void adaptTapAnimal(int i) {
    if (i < 0 || i >= adLocked.length || adLocked[i]) return;
    adSel = adSel == i ? -1 : i;
    cues.add('tap');
  }

  void adaptTapTrait(int slot) {
    if (slot < 0 || slot >= adTraitOrder.length || adTraitLocked[slot]) return;
    if (adSel < 0) {
      hint = 'Tap an animal or plant first, then the trait that fits it.';
      return;
    }
    final int pairOfSlot = adTraitOrder[slot];
    final SkyPair p = adPairs[adSel];
    if (pairOfSlot == adSel) {
      stats.recordTask(
        'biology',
        adFirst[adSel],
        prompt: 'Which adaptation or habitat feature fits the ${p.who}?',
        chosen: adFirst[adSel] ? p.trait : adFirstWrong[adSel],
        answer: p.trait,
      );
      _taskTotal++;
      if (adFirst[adSel]) _taskOk++;
      adLocked[adSel] = true;
      adTraitLocked[slot] = true;
      adSel = -1;
      hint = '';
      cues.add('good');
    } else {
      if (adFirst[adSel]) adFirstWrong[adSel] = adPairs[pairOfSlot].trait;
      adFirst[adSel] = false;
      _shake(10 + slot);
      cues.add('bad');
      hint = 'That trait belongs to a different living thing. Try another.';
    }
  }

  void adaptFinish() {
    if (!adDone) return;
    _completeTend(3);
  }

  // ---- 5 boss ---------------------------------------------------------------

  void _openBoss() {
    if (!bossActive) {
      bossActive = true;
      bossCleared = 0;
      bossLeaves = 3;
      if (blight[4] < 60) blight[4] = 60;
      shown[4] = max(shown[4], 60.0);
    }
    _nextBossQuestion();
    panel = 5;
  }

  void _nextBossQuestion() {
    bossChosen = null;
    bossResult = '';
    bossQ = content.subjectIds.contains('biology') ? content.ask('biology') : content.ask();
  }

  void bossAnswer(int i) {
    final OdyQuestion? q = bossQ;
    if (q == null || bossChosen != null || i < 0 || i >= q.options.length) return;
    bossChosen = i;
    final bool ok = i == q.answerIndex;
    stats.record(q, ok, chosen: q.options[i]);
    if (ok) {
      bossCleared++;
      if (bossCleared > bossBest) bossBest = bossCleared;
      blight[4] = bossCleared >= 5 ? 0.0 : max(0.0, blight[4] - 20);
      bossResult = bossCleared >= 5 ? 'The last fifth of the crown is clear.' : 'Right. The blight pulls back from the crown.';
      cues.add('good');
    } else {
      bossLeaves--;
      blight[4] = min(99.0, blight[4] + 6);
      bossResult = bossLeaves > 0 ? 'Not quite. The blight creeps forward and a leaf falls.' : 'Not quite. The last leaf falls.';
      cues.add('bad');
    }
  }

  void bossContinue() {
    if (bossChosen == null) return;
    if (bossCleared >= 5) {
      bossWon = true;
      bossActive = false;
      tended[4] = true;
      blight[4] = 0;
      cues.add('win');
      _openSummary(
        title: 'THE BLIGHT IS GONE',
        body: 'Green light pours through the crown. Birds return to every branch and the rains will come.',
        line: 'All five fifths of the crown are clear.',
        points: 400,
        good: true,
      );
      return;
    }
    if (bossLeaves <= 0) {
      bossActive = false;
      bossLocked = true;
      bossCleared = 0;
      if (blight[4] < 55) blight[4] = 55;
      cues.add('lose');
      _openSummary(
        title: 'THE BLIGHT PUSHES BACK',
        body: 'The boss retreats into the bark. Climb down and tend any layer to gather strength, then come back to try a fresh set of questions.',
        line: 'You cleared ${bossBest > 0 ? bossBest : 0} of 5 fifths at best.',
        points: 0,
        good: false,
      );
      return;
    }
    _nextBossQuestion();
  }

  // ---- finishing a tend and summary ----------------------------------------

  void _completeTend(int layer) {
    final bool first = !tended[layer];
    final double frac = _taskTotal == 0 ? 1.0 : _taskOk / _taskTotal;
    final double cut = first ? 55 + 25 * frac : 30 + 15 * frac;
    blight[layer] = max(0.0, blight[layer] - cut);
    shield[layer] = first ? 50.0 : 25.0;
    tended[layer] = true;
    tendCount[layer]++;
    bossLocked = false;
    final int pts = ((first ? 150 : 60) * (0.5 + 0.5 * frac)).round();
    tendScore += pts;
    cues.add('win');
    _openSummary(
      title: first ? 'THE ${skyLayerNames[layer].toUpperCase()} BLOOMS' : '${skyLayerNames[layer].toUpperCase()} TENDED AGAIN',
      body: skyBloomNotes[layer],
      line: 'First-try answers: $_taskOk of $_taskTotal. Blight here is now ${blight[layer].round()} percent.',
      points: pts,
      good: true,
    );
  }

  void _openSummary({required String title, required String body, required String line, required int points, required bool good}) {
    sumTitle = title;
    sumBody = body;
    sumLine = line;
    sumPoints = points;
    sumGood = good;
    panel = 6;
  }

  void closeSummary() {
    if (panel != 6) return;
    panel = 0;
    if (bossWon) {
      over = true;
    }
  }

  void closeQuiet() {
    if (panel != 7) return;
    over = true;
  }

  // ---- shell hooks ------------------------------------------------------------

  @override
  int get finalScore {
    int s = tendScore + seeds * 10 + (stats.accuracy * 150).round();
    double sum = 0;
    for (final double b in blight) {
      sum += b;
    }
    s += ((500 - sum) / 5).clamp(0.0, 100.0).round();
    s += bossWon ? 400 : bossBest * 60;
    return s;
  }

  @override
  int get xp => stats.baseXp + layersBloomed * 10 + seeds * 2 + (bossWon ? 60 : 0);

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Layers $layersBloomed/4', Icons.forest_rounded, const Color(0xFF4BD37B)),
        RealmChip('Crown blight ${blight[4].round()}%', Icons.warning_amber_rounded, blight[4] > 70 ? const Color(0xFFFF8A80) : const Color(0xFFBCAAA4)),
        RealmChip('Seeds $seeds', Icons.spa_rounded, const Color(0xFFFFD54F)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Layers bloomed': '$layersBloomed/4',
        'Seeds': '$seeds',
        'Crown blight': '${blight[4].round()}%',
        'Boss': bossWon ? 'Defeated' : (bossBest > 0 ? '$bossBest of 5 fifths' : 'Not faced'),
      };

  // ---- objective --------------------------------------------------------------

  int get objIdx {
    int best = -1;
    double bv = -1;
    for (int i = 0; i < 4; i++) {
      if (!tended[i] && blight[i] > bv) {
        bv = blight[i];
        best = i;
      }
    }
    if (best >= 0) return best;
    if (bossLocked) {
      best = 0;
      bv = -1;
      for (int i = 0; i < 4; i++) {
        if (blight[i] > bv) {
          bv = blight[i];
          best = i;
        }
      }
      return best;
    }
    return 4;
  }

  @override
  String? get objectiveText {
    if (over) return null;
    final int i = objIdx;
    final Offset d = skyStations[i] - pos;
    final String name = skyLayerNames[i];
    final bool near = d.distance < 70;
    if (i == 4) {
      return near ? 'Press TEND to face the Blight Boss' : 'The four layers have bloomed. Climb to the Crown and face the Blight';
    }
    if (near) return 'Press TEND at the $name station';
    final String dir = d.dy < -120 ? 'Climb up' : (d.dy > 120 ? 'Climb down' : 'Walk along the branch');
    if (bossLocked) return 'The Blight pushed back. $dir to the $name and TEND it, then return to the Crown';
    if (tended[i]) return 'The $name is turning grey again. $dir and TEND the station';
    if (blight[i] >= 40) return 'The $name is turning grey. $dir and TEND the station';
    return 'The $name needs tending. $dir and TEND the station';
  }

  @override
  Offset? get objectiveDelta => skyStations[objIdx] - pos;

  @override
  String? get objectiveDistance => '${((skyStations[objIdx] - pos).distance / 10).round()} m';
}
