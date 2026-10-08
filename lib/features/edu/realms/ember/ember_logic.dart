import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'ember_chart.dart';
import 'ember_jobs.dart';

/// Game phases.
const int emPlot = 0;
const int emSail = 1;
const int emJob = 2;
const int emMaster = 3;
const int emBossIntro = 4;
const int emBoss = 5;

/// One delivery order: which island, and which harbour job waits there.
class EmberOrder {
  final int island;
  final int kind;
  const EmberOrder(this.island, this.kind);
}

/// Ember Archipelago: plot routes on a coordinate chart, sail, then do the
/// harbour job to relight each beacon. Directed numbers decide the boss.
class EmberLogic extends RealmLogic {
  static const double fuelCap = 22.0;
  static const int islandCount = 5;
  static const int maxWaypoints = 12;

  static const List<String> _islandNamePool = <String>[
    'Tern Rock', 'Palm Cay', 'Salt Haven', 'Ember Point', 'Driftwood Key', 'Coral Rest', 'Lantern Isle', 'Mango Bay', 'Heron Reach',
  ];
  static const List<String> _cargoLine = <String>[
    'Take the lamp-oil to the island at',
    'Deliver the spare sailcloth to the island at',
    'Carry the lantern glass to the island at',
    'Bring the trade goods to the island at',
  ];
  static const List<String> _cargoShort = <String>['oil', 'sailcloth', 'glass', 'goods'];

  final EmberChart chart;
  final List<EmberOrder> orders = <EmberOrder>[];
  final List<String> islandNames = <String>[];
  final List<bool> lit = List<bool>.filled(islandCount, false);
  final List<bool> assisted = List<bool>.filled(islandCount, false);
  final List<double> litAt = List<double>.filled(islandCount, -100.0);

  int phase = emPlot;
  int orderIdx = 0;

  // Insets reported by the screen so drawing and touch use the same layout.
  double safeTop = 24;
  double safeBottom = 0;

  // The boat and the planned route.
  EP boat = const EP(0, 0);
  Offset boatPos = Offset.zero;
  double boatHeading = 0.0;
  final List<EP> route = <EP>[];
  final List<EP?> legReefs = <EP?>[];
  double fuel = fuelCap;

  // Sailing.
  List<EP> sailPath = <EP>[];
  List<double> sailCum = <double>[0.0];
  double sailDist = 0;
  double sailTotal = 0;
  final List<Offset> wake = <Offset>[];
  double _wakeT = 0;

  // Messages and marks.
  String message = '';
  bool messageBad = false;
  double messageUntil = 0;
  Offset? offMark;
  double offMarkUntil = 0;

  // The current order.
  EP orderOrigin = const EP(0, 0);
  double orderOpt = 0;
  double orderSpent = 0;
  bool hintOn = false;
  bool orderHint = false;

  // The harbour job.
  EmberJob? job;
  int jobStage = 0; // 0 working, 1 wrong once, 2 finished
  int jobAttempts = 0;
  bool jobSolved = false;
  bool jobFirstTry = false;
  String jobFeedback = '';
  String _jobFirstChosen = '';

  // The harbour master question.
  OdyQuestion? masterQ;
  int? masterChosen;
  bool masterUsed = false;

  // The boss.
  TideBoss? boss;
  int bossStage = 0; // 0 working, 1 wrong once, 2 finished
  int bossAttempts = 0;
  bool bossWon = false;
  bool bossFirst = false;
  String bossFeedback = '';
  String _bossFirstChosen = '';

  // Score keeping.
  int jobsDone = 0;
  int jobsFirst = 0;
  int navScore = 0;
  int masterRight = 0;
  int bossScore = 0;
  int hintsUsed = 0;
  int tows = 0;
  double effSum = 0;
  int effCount = 0;

  EmberLogic(RealmContent c)
      : chart = EmberChart.generate(c.rng),
        super(c) {
    final Random r = rng;
    final List<int> idx = <int>[0, 1, 2, 3, 4]..shuffle(r);
    final List<int> kinds = <int>[0, 1, 2, 3]..shuffle(r);
    kinds.add(r.nextInt(4));
    for (int i = 0; i < islandCount; i++) {
      orders.add(EmberOrder(idx[i], kinds[i]));
    }
    final List<String> pool = List<String>.from(_islandNamePool)..shuffle(r);
    islandNames.addAll(pool.take(islandCount));
    boat = chart.start;
    boatPos = Offset(boat.x.toDouble(), boat.y.toDouble());
    boatHeading = pi / 2;
    _beginOrder();
  }

  // ---- derived values -----------------------------------------------------

  EmberOrder get order => orders[orderIdx.clamp(0, orders.length - 1).toInt()];

  EP get target => chart.islands[order.island];

  int get litCount {
    int n = 0;
    for (final bool b in lit) {
      if (b) n++;
    }
    return n;
  }

  String get orderPrefix => _cargoLine[order.kind];

  String get orderCoords => target.label;

  String get orderShort => _cargoShort[order.kind];

  String get currentIslandName => islandNames[order.island.clamp(0, islandNames.length - 1).toInt()];

  EmberLayout layoutFor(Size size) => EmberLayout.forSize(size, safeTop, safeBottom);

  double get routeCost {
    double s = 0;
    EP prev = boat;
    for (final EP p in route) {
      s += prev.distanceTo(p);
      prev = p;
    }
    return s;
  }

  int get firstBadLeg {
    for (int i = 0; i < legReefs.length; i++) {
      if (legReefs[i] != null) return i;
    }
    return -1;
  }

  double get fuelShown => (phase == emSail ? fuel - sailDist : fuel).clamp(0.0, fuelCap).toDouble();

  bool get canSail => phase == emPlot && route.isNotEmpty && firstBadLeg < 0 && _fits(routeCost);

  bool _fits(double cost) => (cost * 10).round() / 10 <= fuel + 1e-9;

  double get avgEfficiency => effCount == 0 ? 0.0 : effSum / effCount;

  // ---- helpers ------------------------------------------------------------

  void say(String text, {bool bad = false, double seconds = 5}) {
    message = text;
    messageBad = bad;
    messageUntil = time + seconds;
  }

  bool get hasMessage => message.isNotEmpty && time < messageUntil;

  void _routeChanged() {
    legReefs.clear();
    EP prev = boat;
    for (final EP p in route) {
      legReefs.add(chart.legReef(prev, p));
      prev = p;
    }
  }

  void _beginOrder() {
    orderOrigin = boat;
    orderOpt = chart.dist(boat, target);
    orderSpent = 0;
    orderHint = false;
    hintOn = false;
    fuel = fuelCap;
    route.clear();
    _routeChanged();
  }

  // ---- RealmLogic ---------------------------------------------------------

  @override
  void step(double dt) {
    if (phase == emSail) _stepSail(dt);
  }

  @override
  bool get modal => phase == emJob || phase == emMaster || phase == emBossIntro || phase == emBoss;

  @override
  double actionReady(int id) {
    if (phase == emSail) return id == 0 ? (sailTotal <= 0 ? 0.0 : (sailDist / sailTotal).clamp(0.0, 1.0).toDouble()) : 0.0;
    if (phase != emPlot) return 0.0;
    if (id == 0) return canSail ? 1.0 : 0.0;
    return route.isNotEmpty ? 1.0 : 0.0;
  }

  @override
  String? get objectiveText {
    if (over) return 'Run complete';
    if (phase == emSail) return 'Sailing... watch the fuel';
    if (phase == emJob) return 'Finish the harbour job at ${target.label}';
    if (phase == emMaster) return 'Answer the harbour master';
    if (phase == emBossIntro || phase == emBoss) return 'Steer the Night Tide to the safe mark';
    if (route.isEmpty) return 'Order: $orderShort to ${target.label}. Tap the grid to plot a route';
    if (firstBadLeg >= 0) return 'The red leg crosses a reef. Press UNDO';
    if (!_fits(routeCost)) return 'Too long for the tank. Plot a shorter route';
    return 'Check the fuel cost, then press SAIL';
  }

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Beacons $litCount/$islandCount', Icons.local_fire_department_rounded, const Color(0xFFFFB74D)),
        RealmChip('Fuel ${fuelShown.toStringAsFixed(1)}', Icons.local_gas_station_rounded, const Color(0xFF2ED3E6)),
        RealmChip('Jobs $jobsFirst/$jobsDone', Icons.build_rounded, const Color(0xFF69F0AE)),
      ];

  @override
  int get finalScore {
    final int s = litCount * 100 + jobsFirst * 60 + navScore + masterRight * 40 + bossScore - tows * 10;
    return s < 0 ? 0 : s;
  }

  @override
  int get xp => stats.baseXp + litCount * 6 + (bossWon ? 25 : 0) + (effCount > 0 && avgEfficiency >= 0.9 ? 10 : 0);

  @override
  Map<String, String> get extraStats => <String, String>{
        'Beacons lit': '$litCount/$islandCount',
        'Jobs first try': '$jobsFirst/$jobsDone',
        'Fuel efficiency': effCount == 0 ? '-' : '${(avgEfficiency * 100).round()}%',
        'Night Tide': bossWon ? (bossFirst ? 'Cleared first try' : 'Cleared') : 'Not cleared',
        'Island hints': '$hintsUsed',
      };

  // ---- plotting -----------------------------------------------------------

  @override
  void onTap(Offset point, Size size) {
    if (over || phase != emPlot) return;
    final EmberLayout lay = layoutFor(size);
    final EmberTap? tp = lay.tap(point);
    if (tp == null) return;
    if (!tp.onChart) {
      offMark = Offset(tp.point.x.toDouble(), tp.point.y.toDouble());
      offMarkUntil = time + 1.6;
      say('That point is off the chart. The grid only runs from -6 to 6.', bad: true);
      cues.add('bad');
      return;
    }
    final EP p = tp.point;
    if (p == boat) {
      if (route.isNotEmpty) {
        route.clear();
        _routeChanged();
        say('Route cleared. Your boat is at ${boat.label}.');
        cues.add('tap');
      } else {
        say('Your boat is at ${boat.label}. Tap a grid point to start a route.');
      }
      return;
    }
    if (route.isNotEmpty && route.last == p) {
      route.removeLast();
      _routeChanged();
      say('Waypoint removed.');
      cues.add('tap');
      return;
    }
    if (route.length >= maxWaypoints) {
      say('That is $maxWaypoints waypoints already. Press UNDO or tap your boat to start again.', bad: true);
      cues.add('bad');
      return;
    }
    final EP prev = route.isEmpty ? boat : route.last;
    route.add(p);
    _routeChanged();
    final EP? hit = legReefs.isEmpty ? null : legReefs.last;
    if (hit != null) {
      say('Leg ${route.length} crosses a reef and is refused. It is drawn in red. Press UNDO to remove it.', bad: true);
      cues.add('bad');
    } else {
      say('Waypoint ${route.length} at ${p.label}. This leg costs ${prev.distanceTo(p).toStringAsFixed(1)} fuel.');
      cues.add('tap');
    }
  }

  @override
  void onAction(int id) {
    if (over || phase != emPlot) return;
    if (id == 0) {
      _trySail();
    } else if (id == 1) {
      if (route.isEmpty) {
        say('Nothing to undo. Tap the grid to plot a route.');
      } else {
        route.removeLast();
        _routeChanged();
        say('Last waypoint removed.');
        cues.add('tap');
      }
    }
  }

  void toggleHint() {
    if (phase != emPlot) return;
    hintOn = !hintOn;
    if (hintOn && !orderHint) {
      orderHint = true;
      hintsUsed++;
      say('The island is ringed on the chart. This lowers your fuel bonus for this order.');
    }
    cues.add('tap');
  }

  void _trySail() {
    if (route.isEmpty) {
      say('Plot a route first: tap grid points on the chart.', bad: true);
      cues.add('bad');
      return;
    }
    final int bad = firstBadLeg;
    if (bad >= 0) {
      say('Leg ${bad + 1} crosses a reef. It is drawn in red. Press UNDO and go around it.', bad: true);
      cues.add('bad');
      return;
    }
    final double cost = routeCost;
    if (!_fits(cost)) {
      say('Not enough fuel: this route costs ${cost.toStringAsFixed(1)} but the tank has ${fuel.toStringAsFixed(1)}. Plot a shorter route.', bad: true);
      cues.add('bad');
      return;
    }
    _startSail();
  }

  void _startSail() {
    final List<EP> path = <EP>[boat];
    for (final EP p in route) {
      path.add(p);
      if (p == target) break;
    }
    final List<double> cum = <double>[0.0];
    double acc = 0;
    for (int i = 1; i < path.length; i++) {
      acc += path[i - 1].distanceTo(path[i]);
      cum.add(acc);
    }
    sailPath = path;
    sailCum = cum;
    sailTotal = acc;
    sailDist = 0;
    wake.clear();
    _wakeT = 0;
    phase = emSail;
    boatPos = Offset(boat.x.toDouble(), boat.y.toDouble());
    if (path.length > 1) {
      boatHeading = atan2((path[1].y - path[0].y).toDouble(), (path[1].x - path[0].x).toDouble());
    }
    say('Sailing... ${acc.toStringAsFixed(1)} fuel for this route.');
    cues.add('tap');
  }

  void _stepSail(double dt) {
    final double speed = max(3.2, sailTotal / 3.4);
    sailDist = min(sailTotal, sailDist + speed * dt);
    _placeBoat(sailDist);
    _wakeT += dt;
    if (_wakeT > 0.05) {
      _wakeT = 0;
      wake.add(boatPos);
      if (wake.length > 40) wake.removeAt(0);
    }
    if (sailDist >= sailTotal - 1e-9) _arrive();
  }

  void _placeBoat(double d) {
    if (sailPath.length < 2) return;
    for (int i = 0; i < sailPath.length - 1; i++) {
      final bool last = i == sailPath.length - 2;
      final double a = sailCum[i];
      final double b = sailCum[i + 1];
      if (d <= b || last) {
        final double len = b - a;
        final double t = len <= 0 ? 1.0 : ((d - a) / len).clamp(0.0, 1.0).toDouble();
        final EP p = sailPath[i];
        final EP q = sailPath[i + 1];
        boatPos = Offset(p.x + (q.x - p.x) * t, p.y + (q.y - p.y) * t);
        boatHeading = atan2((q.y - p.y).toDouble(), (q.x - p.x).toDouble());
        return;
      }
    }
  }

  void _arrive() {
    final EP here = sailPath.last;
    fuel = max(0.0, fuel - sailTotal);
    orderSpent += sailTotal;
    boat = here;
    boatPos = Offset(here.x.toDouble(), here.y.toDouble());
    route.clear();
    _routeChanged();
    wake.clear();
    phase = emPlot;
    if (here == target) {
      _arriveAtTarget();
      return;
    }
    final int isl = chart.islands.indexOf(here);
    if (isl >= 0) {
      say('The islanders at ${here.label} are not waiting for you. Read the order again.', bad: true);
    } else {
      say('Nobody lives at ${here.label}.', bad: true);
    }
    cues.add('bad');
    _towIfNeeded();
  }

  void _towIfNeeded() {
    final double need = chart.dist(boat, target);
    if (!_fits(need)) {
      fuel = fuelCap;
      tows++;
      say('Out of fuel for the way ahead. A fisher tows you and fills your tank, but it costs you some score.', bad: true, seconds: 6);
    }
  }

  void _arriveAtTarget() {
    final double opt = orderOpt;
    final double spent = orderSpent;
    double eff = spent <= 0.0001 ? 1.0 : (opt / spent);
    if (eff > 1) eff = 1;
    if (eff < 0) eff = 0;
    int pts = (60 * eff).round();
    if (orderHint) pts = pts ~/ 2;
    navScore += pts;
    effSum += eff;
    effCount++;
    final int level = litCount;
    final int kind = order.kind;
    switch (kind) {
      case emberJobCargo:
        job = CargoJob.generate(rng, level);
        break;
      case emberJobSail:
        job = SailJob.generate(rng, level);
        break;
      case emberJobLamp:
        job = LampJob.generate(rng, level);
        break;
      default:
        job = BarterJob.generate(rng, level);
        break;
    }
    jobStage = 0;
    jobAttempts = 0;
    jobSolved = false;
    jobFirstTry = false;
    jobFeedback = '';
    _jobFirstChosen = '';
    masterQ = null;
    masterChosen = null;
    masterUsed = false;
    hintOn = false;
    phase = emJob;
    say('Docked at ${target.label}. Route cost ${spent.toStringAsFixed(1)}, best possible ${opt.toStringAsFixed(1)}.');
    cues.add('tap');
  }

  // ---- harbour jobs -------------------------------------------------------

  void cargoAdjust(int i, int d) {
    final EmberJob? j = job;
    if (j is CargoJob && jobStage != 2) {
      j.adjust(i, d);
      cues.add('tap');
    }
  }

  void sailAdd(int piece) {
    final EmberJob? j = job;
    if (j is SailJob && jobStage != 2) {
      j.add(piece);
      cues.add('tap');
    }
  }

  void sailUndo() {
    final EmberJob? j = job;
    if (j is SailJob && jobStage != 2) {
      j.undo();
      cues.add('tap');
    }
  }

  void sailClear() {
    final EmberJob? j = job;
    if (j is SailJob && jobStage != 2) {
      j.clear();
      cues.add('tap');
    }
  }

  void lampAdjust(int d) {
    final EmberJob? j = job;
    if (j is LampJob && jobStage != 2) {
      j.adjust(d);
      cues.add('tap');
    }
  }

  void barterPick(int i) {
    final EmberJob? j = job;
    if (j is BarterJob && jobStage != 2) {
      j.pick(i);
      cues.add('tap');
    }
  }

  void barterKey(String k) {
    final EmberJob? j = job;
    if (j is BarterJob && jobStage != 2) {
      j.key(k);
      cues.add('tap');
    }
  }

  void jobSubmit() {
    final EmberJob? j = job;
    if (j == null || jobStage != 0 || !j.canSubmit) return;
    jobAttempts++;
    if (j.check()) {
      _concludeJob(true);
      return;
    }
    fuel = max(0.0, fuel - 2);
    cues.add('bad');
    if (jobAttempts == 1) {
      _jobFirstChosen = j.chosenText;
      jobStage = 1;
      jobFeedback = 'Not quite. ${j.working} That cost 2 fuel. Try once more.';
    } else {
      _concludeJob(false);
    }
  }

  void jobRetry() {
    if (jobStage == 1) jobStage = 0;
  }

  void _concludeJob(bool solved) {
    final EmberJob j = job!;
    final bool firstTry = solved && jobAttempts == 1;
    stats.recordTask(
      'math',
      firstTry,
      prompt: '${j.title}: ${j.statement}',
      chosen: firstTry ? j.chosenText : (_jobFirstChosen.isEmpty ? j.chosenText : _jobFirstChosen),
      answer: j.answerText,
    );
    jobSolved = solved;
    jobFirstTry = firstTry;
    jobsDone++;
    if (firstTry) jobsFirst++;
    final int idx = order.island.clamp(0, islandCount - 1).toInt();
    lit[idx] = true;
    assisted[idx] = !solved;
    litAt[idx] = time;
    fuel = fuelCap;
    jobStage = 2;
    jobFeedback = solved ? '' : 'The answer was ${j.answerText}. ${j.working}';
    cues.add('good');
  }

  void openMaster() {
    if (jobStage != 2 || masterUsed) return;
    masterQ = content.ask('math');
    masterChosen = null;
    phase = emMaster;
  }

  void masterPick(int i) {
    final OdyQuestion? q = masterQ;
    if (q == null || masterChosen != null) return;
    masterChosen = i;
    final bool ok = i == q.answerIndex;
    stats.record(q, ok, chosen: (i >= 0 && i < q.options.length) ? q.options[i] : 'No answer');
    if (ok) {
      masterRight++;
      cues.add('good');
    } else {
      cues.add('bad');
    }
  }

  void masterDone() {
    masterUsed = true;
    phase = emJob;
  }

  /// Leaves the finished job: back to the chart, or on to the boss.
  void closeJob() {
    if (jobStage != 2) return;
    job = null;
    masterQ = null;
    if (litCount >= islandCount) {
      phase = emBossIntro;
      return;
    }
    orderIdx = litCount.clamp(0, orders.length - 1).toInt();
    phase = emPlot;
    _beginOrder();
    say('Tank full. New order: $orderShort to ${target.label}.');
  }

  // ---- boss ---------------------------------------------------------------

  void bossStart() {
    if (phase != emBossIntro) return;
    boss = TideBoss.generate(rng);
    bossStage = 0;
    bossAttempts = 0;
    bossFeedback = '';
    _bossFirstChosen = '';
    phase = emBoss;
  }

  void bossPick(int opt) {
    final TideBoss? b = boss;
    if (b == null || bossStage != 0) return;
    b.pick(opt);
    cues.add('tap');
  }

  void bossUndo() {
    final TideBoss? b = boss;
    if (b == null || bossStage != 0) return;
    b.undo();
    cues.add('tap');
  }

  void bossSubmit() {
    final TideBoss? b = boss;
    if (b == null || bossStage != 0 || !b.complete) return;
    bossAttempts++;
    final String prompt = 'Night Tide: events ${b.events.map(emberSigned).join(', ')}, safe mark ${emberSigned(b.safe)}';
    if (b.check()) {
      bossWon = true;
      bossFirst = bossAttempts == 1;
      bossScore = bossFirst ? 200 : 120;
      stats.recordTask('math', bossFirst, prompt: prompt, chosen: bossFirst ? b.chosenText : (_bossFirstChosen.isEmpty ? b.chosenText : _bossFirstChosen), answer: b.answerText);
      bossStage = 2;
      cues.add('win');
      return;
    }
    cues.add('bad');
    if (bossAttempts == 1) {
      _bossFirstChosen = b.chosenText;
      bossStage = 1;
      bossFeedback = 'Not quite. Your tide ended at ${emberSigned(b.level)} but the safe mark is ${emberSigned(b.safe)}. ${b.working}';
    } else {
      bossWon = false;
      bossFirst = false;
      bossScore = 40;
      stats.recordTask('math', false, prompt: prompt, chosen: _bossFirstChosen.isEmpty ? b.chosenText : _bossFirstChosen, answer: b.answerText);
      bossStage = 2;
      bossFeedback = 'The safe mark was ${emberSigned(b.safe)}. ${b.working}';
    }
  }

  void bossRetry() {
    if (bossStage == 1) bossStage = 0;
  }

  void bossFinish() {
    if (bossStage != 2) return;
    over = true;
    cues.add(bossWon ? 'win' : 'lose');
  }
}
