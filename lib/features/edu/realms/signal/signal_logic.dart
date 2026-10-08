import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'signal_boards.dart';

const Color sgAccentColor = Color(0xFFFF8A3D);
const Color sgGold = Color(0xFFFFD54F);

const List<String> sgStageNames = <String>['Pine Gap', 'Echo Hollow', 'Windy Pass', 'Lamp Station', 'Fault Line', 'Whiteout Peak'];

const List<String> sgStageBlurbs = <String>[
  'Build a program from FORWARD, TURN and ACTIVATE blocks. Park the bot on each tower and ACTIVATE it.',
  'REPEAT runs blocks again and again. A shorter program earns more stars.',
  'IF WALL AHEAD lets the bot decide for itself. Combine it with REPEAT to follow the ridge.',
  'Switches feed gates that feed one lamp. AND needs both, OR needs one, NOT flips, XOR needs exactly one.',
  'One block in this program is wrong. Find it, choose a fix, and test it.',
  'Whiteout! The bot only sees the cells next to it. Write rules that react to what it meets.',
];

/// Rules and state of Signal Ridge: six puzzles that rebuild a signal network.
class SignalLogic extends RealmLogic {
  SignalLogic(RealmContent content) : super(content);

  static const double panelH = 240;
  static const int stageCount = 6;

  // Layout facts reported by the HUD so the painter can leave room for it.
  double safeTop = 0;
  double safeBottom = 0;

  // Flow
  int phase = 0; // 0 map, 1 puzzle, 3 signal key question
  int stage = 0; // 0 to 5
  final List<int> starsBy = List<int>.filled(6, 0);
  final List<int> effBy = List<int>.filled(6, 0);
  final List<bool> doneBy = List<bool>.filled(6, false);
  int keys = 0;
  int keysAsked = 0;
  double panX = 0;

  // Puzzle state
  SBoard? board;
  List<SBlock> program = <SBlock>[];
  List<SBlock> runProg = <SBlock>[];
  SBlock? tgtOwner;
  int tgtBranch = 0;
  SBlock? sel;
  int attempts = 0;
  int fails = 0;
  int hints = 0;
  bool solutionShown = false;
  bool solved = false;
  bool recorded = false;
  int starsNow = 0;
  String msg = '';
  bool msgGood = true;
  String lastWrong = '';

  // Hints
  SKind? hintKind;
  SBlock? hintBad;
  final Set<SBlock> hintRegion = <SBlock>{};

  // Run engine
  int runState = 0; // 0 idle, 1 playing a step, 2 waiting for STEP, 3 finished
  bool manual = false;
  bool runCounted = true;
  int speedIdx = 0;
  SSim? sim;
  int runIdx = 0;
  double animT = 0;
  int px = 0;
  int py = 0;
  int pdir = 0;
  List<double> litAt = <double>[];
  List<SCell> ghost = <SCell>[];
  int ghostCrash = 0;
  int ghostCx = -1;
  int ghostCy = -1;
  int pulseTower = -1;
  double pulseAt = -99;
  final Set<int> explored = <int>{};

  // Circuit puzzle
  SCircuit? circ1;
  SCircuit? circ2;
  List<bool> sw = <bool>[];
  final List<int> predMasks = <int>[0, 0];
  int minOn = 1;
  int bSub = 0;
  bool predAnswered = false;
  bool predCorrect = false;
  bool reveal = false;
  bool partial = false;
  bool makePending = false;
  bool minimalOk = false;

  // Debug puzzle
  SDebug? dbg;
  int dbgSel = -1;
  List<SFix> dbgOptions = <SFix>[];

  // Key question
  OdyQuestion? question;
  int? keyChosen;

  // ---- derived -------------------------------------------------------------

  int get kind => stage == 3 ? 1 : (stage == 4 ? 2 : 0);

  SCircuit? get circ => bSub < 2 ? circ1 : circ2;

  int get totalStars {
    int t = 0;
    for (final int s in starsBy) {
      t += s;
    }
    return t;
  }

  int get effTotal {
    int t = 0;
    for (final int s in effBy) {
      t += s;
    }
    return t;
  }

  int get used => sgCount(program);
  int get allowedBlocks => board?.allowed ?? 8;
  int get maxBlocks => allowedBlocks + 6;

  List<SBlock> get shownProgram => (kind == 2 && (runState == 1 || runState == 2) && runProg.isNotEmpty) ? runProg : program;

  bool get running => runState == 1 || runState == 2;

  bool get editable => phase == 1 && kind == 0 && !solved && (runState == 0 || runState == 3);

  bool kindAllowed(SKind k) {
    if (k == SKind.rep) return stage >= 1;
    if (k == SKind.iff) return stage >= 2;
    return true;
  }

  Rect arena(Size s) {
    final double top = safeTop + 140;
    final double dock = phase == 0 ? 160.0 : panelH + 8;
    final double bottom = s.height - safeBottom - dock;
    final double want = top + 110;
    return Rect.fromLTRB(8, top, s.width - 8, bottom > want ? bottom : want);
  }

  Rect circuitRect(Size s) {
    final Rect a = arena(s);
    final double w = min(a.width, 480.0);
    return Rect.fromLTWH(a.center.dx - w / 2, a.top, w, a.height);
  }

  int get litShown {
    final SSim? s = sim;
    if (runState == 0 || s == null || runIdx <= 0) return 0;
    final int i = min(runIdx, s.steps.length) - 1;
    if (i < 0) return 0;
    return s.steps[i].lit;
  }

  bool isActive(SBlock b) {
    final SSim? s = sim;
    if (s == null || runState == 0 || runState == 3) return false;
    final int i = runState == 2 ? runIdx - 1 : runIdx;
    if (i < 0 || i >= s.steps.length) return false;
    final SStep st = s.steps[i];
    return identical(st.block, b) || st.chain.contains(b);
  }

  /// Bot position in cells and heading in radians (0 faces up).
  List<double> botPose() {
    final SBoard? b = board;
    if (b == null) return <double>[0, 0, 0];
    double x = px.toDouble();
    double y = py.toDouble();
    double d = pdir.toDouble();
    final SSim? s = sim;
    if (runState != 0 && s != null && runIdx < s.steps.length) {
      final SStep st = s.steps[runIdx];
      final double t = animT.clamp(0.0, 1.0).toDouble();
      final double e = t * t * (3 - 2 * t);
      if (st.event == evMove) {
        x = px + (st.x - px) * e;
        y = py + (st.y - py) * e;
      } else if (st.event == evTurn) {
        int dd = (st.dir - pdir) % 4;
        if (dd == 3) dd = -1;
        d = pdir + dd * e;
      } else if (st.event == evRock || st.event == evEdge) {
        final double k = sin(t * pi) * 0.38;
        x = px + sgDx[pdir] * k;
        y = py + sgDy[pdir] * k;
      }
    }
    return <double>[x, y, d * pi / 2];
  }

  // ---- RealmLogic ------------------------------------------------------------

  @override
  void step(double dt) {
    final double target = stage * 70.0 + (phase == 0 ? 0 : 24);
    panX += (target - panX) * min(1.0, dt * 1.6);
    if (phase == 1 && runState == 1) _advance(dt);
  }

  @override
  int get finalScore => totalStars * 100 + keys * 60 + effTotal;

  @override
  int get xp => stats.baseXp + totalStars * 4;

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Stage ${min(stage + 1, stageCount)}/$stageCount', Icons.flag_rounded, sgAccentColor),
        RealmChip('Stars $totalStars', Icons.star_rounded, sgGold),
        RealmChip('Keys $keys', Icons.vpn_key_rounded, const Color(0xFF69F0AE)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Stars': '$totalStars / 18',
        'Signal keys': '$keys / $keysAsked',
        'Efficiency': '$effTotal pts',
      };

  @override
  bool get modal => phase == 3;

  @override
  String? get objectiveText {
    if (phase == 0) {
      return 'Ridge ${min(stage + 1, stageCount)} (${sgStageNames[min(stage, 5)]}): tap START to open the next puzzle.';
    }
    if (phase == 3) return 'Answer the signal key question to earn a key.';
    final String n = 'Stage ${stage + 1}';
    if (solved) return '$n cleared. Tap CONTINUE for the signal key.';
    if (kind == 0) return _botObjective(n);
    if (kind == 1) return _circuitObjective(n);
    return _debugObjective(n);
  }

  String _botObjective(String n) {
    final SBoard? b = board;
    if (b == null) return n;
    final String blocks = 'Blocks $used/${b.allowed}';
    final SSim? s = sim;
    if (running) return '$n: watch the bot run. $blocks';
    if (runState == 3 && s != null) {
      if (s.crash != 0) return '$n: the bot crashed. Follow the footprints, fix it, RUN. $blocks';
      if (s.missed >= 0) return '$n: tower ${s.missed + 1} is still dark. Fix the program and RUN. $blocks';
    }
    final String fog = b.fog ? ' in the fog' : '';
    return '$n: switch on all ${b.towers.length} towers$fog. $blocks';
  }

  String _circuitObjective(String n) {
    if (bSub < 2) {
      if (predAnswered) return predCorrect ? '$n: correct. Tap NEXT.' : '$n: study the wires, then tap TRY AGAIN.';
      return '$n: predict the lamp for round ${bSub + 1} of 2. Tap ON or OFF.';
    }
    if (makePending) return '$n: keep this answer or try with fewer switches ON.';
    return '$n: tap switches to light the lamp with as few ON as you can. ON: $onCount';
  }

  String _debugObjective(String n) {
    if (running) return '$n: testing the program. Watch the bot.';
    if (dbgSel >= 0) return '$n: choose the right fix for the block you tapped.';
    return '$n: tap the faulty block in the program.';
  }

  int get onCount {
    int c = 0;
    for (final bool b in sw) {
      if (b) c++;
    }
    return c;
  }

  @override
  void onTap(Offset point, Size size) {
    if (phase != 1 || kind != 1 || solved || bSub != 2 || makePending) return;
    final SCircuit? c = circ2;
    if (c == null) return;
    final List<Offset> pos = sgCircuitLayout(c, circuitRect(size).deflate(6));
    int best = -1;
    double bd = 30;
    for (int i = 0; i < c.k && i < pos.length; i++) {
      final double d = (pos[i] - point).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    if (best >= 0) toggleSwitch(best);
  }

  // ---- stage flow --------------------------------------------------------------

  void startStage() {
    if (phase != 0 || over) return;
    phase = 1;
    attempts = 0;
    fails = 0;
    hints = 0;
    solutionShown = false;
    solved = false;
    recorded = false;
    starsNow = 0;
    msg = '';
    lastWrong = '';
    sel = null;
    tgtOwner = null;
    tgtBranch = 0;
    program = <SBlock>[];
    runProg = <SBlock>[];
    _clearHint();
    runState = 0;
    sim = null;
    ghost = <SCell>[];
    ghostCrash = 0;
    pulseTower = -1;
    explored.clear();
    dbgSel = -1;
    dbgOptions = <SFix>[];
    makePending = false;
    minimalOk = false;
    if (kind == 1) {
      board = null;
      circ1 = sgGenPredictCircuit(rng);
      circ2 = sgGenMakeCircuit(rng);
      minOn = sgMinOn(circ2!);
      final int first = rng.nextInt(2);
      predMasks[0] = sgRandomPattern(rng, circ1!, want: first);
      predMasks[1] = sgRandomPattern(rng, circ1!, not: predMasks[0], want: 1 - first);
      bSub = 0;
      sw = sgBits(predMasks[0], 3);
      predAnswered = false;
      predCorrect = false;
      reveal = false;
      partial = false;
    } else if (kind == 2) {
      final SDebug d = sgGenDebug(rng);
      dbg = d;
      board = d.board;
      program = sgClone(d.buggy);
      _resetPose();
    } else {
      board = sgGenerate(rng, stage);
      _resetPose();
    }
    cues.add('tap');
  }

  void _resetPose() {
    final SBoard? b = board;
    if (b == null) return;
    px = b.sx;
    py = b.sy;
    pdir = b.sdir;
    litAt = List<double>.filled(b.towers.length, -1.0);
    _reveal(b.sx, b.sy);
  }

  void _reveal(int x, int y) {
    final SBoard? b = board;
    if (b == null || !b.fog) return;
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        final int xx = x + dx;
        final int yy = y + dy;
        if (b.inside(xx, yy)) explored.add(yy * b.w + xx);
      }
    }
  }

  void setMsg(String m, bool good) {
    msg = m;
    msgGood = good;
  }

  void _clearHint() {
    hintKind = null;
    hintBad = null;
    hintRegion.clear();
  }

  // ---- editing the program -------------------------------------------------------

  void _validateTarget() {
    final SBlock? o = tgtOwner;
    if (o != null && !sgFlatten(program).contains(o)) {
      tgtOwner = null;
      tgtBranch = 0;
    }
    final SBlock? s = sel;
    if (s != null && !sgFlatten(program).contains(s)) sel = null;
  }

  List<SBlock> _targetList() {
    _validateTarget();
    final SBlock? o = tgtOwner;
    if (o == null) return program;
    return tgtBranch == 0 ? o.body : o.els;
  }

  void _touch() {
    if (runState != 0) resetRun();
    _clearHint();
    msg = '';
  }

  void addBlock(SKind k) {
    if (!editable) return;
    if (!kindAllowed(k)) return;
    _validateTarget();
    final SBlock? o = tgtOwner;
    if (k == SKind.rep && o != null) {
      setMsg('REPEAT must sit on the main line. Tap END first.', false);
      return;
    }
    if (k == SKind.iff && o != null && o.kind != SKind.rep) {
      setMsg('An IF cannot sit inside another IF.', false);
      return;
    }
    if (used >= maxBlocks) {
      setMsg('That is too many blocks. Delete some first.', false);
      return;
    }
    _touch();
    final SBlock nb = SBlock(k, n: 2);
    _targetList().add(nb);
    if (nb.isContainer) {
      tgtOwner = nb;
      tgtBranch = 0;
    }
    sel = nb;
    cues.add('tap');
  }

  void tapBlock(SBlock b) {
    if (!editable) return;
    _touch();
    sel = b;
    if (b.isContainer) {
      tgtOwner = b;
      tgtBranch = 0;
    } else {
      final SLoc? loc = sgLocate(program, b);
      if (loc != null) {
        tgtOwner = loc.owner;
        tgtBranch = loc.branch;
      }
    }
  }

  void setTarget(SBlock? owner, int branch) {
    if (!editable) return;
    tgtOwner = owner;
    tgtBranch = branch;
    sel = owner;
  }

  void changeCount(SBlock b, int d) {
    if (!editable) return;
    _touch();
    b.n = (b.n + d).clamp(1, 40).toInt();
    sel = b;
  }

  void deleteSelected() {
    if (!editable) return;
    _touch();
    _validateTarget();
    final SBlock? s = sel;
    if (s != null) {
      final SLoc? loc = sgLocate(program, s);
      if (loc != null) loc.list.removeAt(loc.idx);
      sel = null;
    } else {
      final List<SBlock> l = _targetList();
      if (l.isNotEmpty) {
        l.removeLast();
      } else if (tgtOwner != null) {
        final SLoc? loc = sgLocate(program, tgtOwner!);
        if (loc != null) loc.list.removeAt(loc.idx);
        tgtOwner = null;
        tgtBranch = 0;
      }
    }
    _validateTarget();
  }

  void clearAll() {
    if (!editable) return;
    _touch();
    program = <SBlock>[];
    sel = null;
    tgtOwner = null;
    tgtBranch = 0;
    ghost = <SCell>[];
    ghostCrash = 0;
  }

  // ---- running --------------------------------------------------------------------

  double _dur(int ev) {
    switch (ev) {
      case evMove:
        return 0.42;
      case evTurn:
        return 0.3;
      case evAct:
        return 0.55;
      case evActNone:
        return 0.12;
      case evRock:
      case evEdge:
        return 0.65;
      case evCheck:
        return 0.16;
      default:
        return 0.3;
    }
  }

  void resetRun() {
    runState = 0;
    manual = false;
    sim = null;
    runIdx = 0;
    animT = 0;
    final SBoard? b = board;
    if (b != null) {
      px = b.sx;
      py = b.sy;
      pdir = b.sdir;
      litAt = List<double>.filled(b.towers.length, -1.0);
    }
  }

  void _beginRun(List<SBlock> prog, bool manualMode, bool counted) {
    final SBoard? b = board;
    if (b == null) return;
    _clearHint();
    runProg = prog;
    runCounted = counted;
    sim = sgRun(b, prog);
    runIdx = 0;
    animT = 0;
    px = b.sx;
    py = b.sy;
    pdir = b.sdir;
    litAt = List<double>.filled(b.towers.length, -1.0);
    ghost = <SCell>[];
    ghostCrash = 0;
    pulseTower = -1;
    msg = '';
    manual = manualMode;
    runState = 1;
    _reveal(b.sx, b.sy);
    cues.add('tap');
  }

  void runPressed() {
    if (kind != 0 || solved || phase != 1) return;
    if (running) {
      resetRun();
      return;
    }
    if (program.isEmpty) {
      setMsg('Add some blocks first, then press RUN.', false);
      return;
    }
    _beginRun(program, false, true);
  }

  void stepPressed() {
    if (kind != 0 || solved || phase != 1) return;
    if (runState == 2) {
      runState = 1;
      return;
    }
    if (runState == 1) {
      manual = true;
      return;
    }
    if (program.isEmpty) {
      setMsg('Add some blocks first, then press STEP.', false);
      return;
    }
    _beginRun(program, true, true);
  }

  void toggleSpeed() {
    speedIdx = 1 - speedIdx;
  }

  void watchBuggy() {
    if (kind != 2 || solved || running) return;
    _beginRun(program, false, false);
  }

  void _advance(double dt) {
    final SSim? s = sim;
    if (s == null) {
      runState = 0;
      return;
    }
    if (runIdx >= s.steps.length) {
      _finishRun();
      return;
    }
    final SStep st = s.steps[runIdx];
    final double speed = manual ? 1.4 : (speedIdx == 0 ? 1.0 : 3.2);
    animT += dt / (_dur(st.event) / speed);
    if (animT >= 1) {
      animT = 0;
      _completeStep(st);
      runIdx++;
      if (runIdx >= s.steps.length) {
        _finishRun();
      } else if (manual) {
        runState = 2;
      }
    }
  }

  void _completeStep(SStep st) {
    px = st.x;
    py = st.y;
    pdir = st.dir;
    _reveal(st.x, st.y);
    if (st.event == evAct && st.tower >= 0 && st.tower < litAt.length) {
      litAt[st.tower] = time;
      cues.add('good');
    } else if (st.event == evRock || st.event == evEdge) {
      cues.add('bad');
    } else if (st.event == evMove || st.event == evTurn) {
      cues.add('tap');
    }
  }

  void _finishRun() {
    final SSim? s = sim;
    if (s == null) {
      runState = 0;
      return;
    }
    runState = 3;
    manual = false;
    final bool ok = s.allLit && s.crash == 0;
    ghost = List<SCell>.from(s.trail);
    ghostCrash = s.crash;
    ghostCx = s.crashX;
    ghostCy = s.crashY;
    if (!runCounted) {
      setMsg('That is how the faulty program runs. Find the wrong block and pick a fix.', true);
      return;
    }
    attempts++;
    if (ok) {
      ghost = <SCell>[];
      ghostCrash = 0;
      _onSolved();
    } else {
      _onRunFailed(s);
    }
  }

  String _failText(SSim s) {
    if (s.crash == 4) return 'The bot hit a rock. The footprints show where it went.';
    if (s.crash == 5) return 'The bot rolled off the edge of the ridge. Check your turns.';
    if (s.missed >= 0) return 'The program ended and tower ${s.missed + 1} is still dark.';
    return 'Not all towers are on yet.';
  }

  void _onRunFailed(SSim s) {
    fails++;
    pulseTower = s.missed;
    pulseAt = time;
    cues.add('bad');
    if (kind == 2) {
      setMsg('That fix does not work. ${_failText(s)} Tap a block to try again.', false);
      dbgSel = -1;
      dbgOptions = <SFix>[];
    } else {
      setMsg(_failText(s), false);
    }
  }

  // ---- finishing a puzzle ------------------------------------------------------------

  int _calcStars() {
    int s;
    if (kind == 0) {
      final SBoard? b = board;
      final int u = used;
      if (b == null) {
        s = 1;
      } else {
        s = u <= b.par ? 3 : (u <= b.allowed ? 2 : 1);
      }
    } else if (kind == 2) {
      s = fails == 0 ? 3 : (fails <= 2 ? 2 : 1);
    } else {
      s = (fails == 0 && minimalOk) ? 3 : (fails <= 2 ? 2 : 1);
    }
    if (hints > 0 || solutionShown) s = min(s, 1);
    return s;
  }

  int _calcEff() {
    if (solutionShown) return 0;
    if (kind == 0) {
      final SBoard? b = board;
      final int spare = b == null ? 0 : max(0, b.allowed - used);
      return spare * 6 + (fails == 0 ? 20 : 0);
    }
    if (kind == 2) return fails == 0 ? 30 : 10;
    return (fails == 0 ? 20 : 0) + (minimalOk ? 20 : 0);
  }

  void _onSolved() {
    if (solved) return;
    solved = true;
    starsNow = _calcStars();
    starsBy[stage] = starsNow;
    effBy[stage] = _calcEff();
    doneBy[stage] = true;
    _recordPuzzle(fails <= 1 && !solutionShown);
    final String plural = starsNow == 1 ? 'star' : 'stars';
    if (kind == 1) {
      setMsg('Signal restored! $starsNow $plural.', true);
    } else if (kind == 2) {
      setMsg('Fixed. ${dbg?.explain ?? ''}', true);
    } else {
      setMsg('Every tower is on. Signal restored! $starsNow $plural.', true);
    }
    cues.add('win');
  }

  void _recordPuzzle(bool ok) {
    if (recorded) return;
    recorded = true;
    final String name = sgStageNames[stage];
    String prompt;
    String chosen;
    String answer;
    if (kind == 0) {
      final SBoard? b = board;
      prompt = 'Ridge ${stage + 1} ($name): write a program that switches on all ${b?.towers.length ?? 0} towers in at most ${b?.allowed ?? 0} blocks.';
      chosen = sgProgText(program);
      answer = b == null ? '' : sgProgText(b.ref);
    } else if (kind == 1) {
      prompt = 'Circuit puzzle: lamp = ${circ2?.lampExpr ?? ''}. Predict the lamp, then light it with the fewest switches ON.';
      chosen = lastWrong.isEmpty ? 'No answer' : lastWrong;
      answer = 'Fewest switches ON: $minOn';
    } else {
      prompt = 'Debug the program: ${sgProgText(dbg?.buggy ?? program)}';
      chosen = lastWrong.isEmpty ? 'No answer' : lastWrong;
      answer = dbg == null ? '' : sgProgText(dbg!.board.ref);
    }
    stats.recordTask('coding', ok, prompt: prompt, chosen: chosen, answer: answer);
  }

  // ---- hints and help ------------------------------------------------------------------

  void useHint() {
    if (phase != 1 || solved || running) return;
    hints++;
    if (kind == 0) {
      final SBoard? b = board;
      if (b == null) return;
      if (runState == 3) resetRun();
      _clearHint();
      final SHint h = sgHint(b.ref, program);
      setMsg(h.text, true);
      hintKind = h.kind;
      hintBad = h.bad;
      final SPos? at = h.at;
      if (at != null) {
        tgtOwner = at.owner;
        tgtBranch = at.branch;
      }
    } else if (kind == 1) {
      if (bSub < 2) {
        if (predAnswered) {
          hints--;
          return;
        }
        partial = true;
        reveal = true;
        setMsg('The values on the wires are shown. Work out the last gate yourself.', true);
      } else {
        final SCircuit? c = circ2;
        if (c == null) return;
        int found = -1;
        for (int m = 0; m < (1 << c.k); m++) {
          if (sgPop(m) == minOn && c.lamp(sgBits(m, c.k))) {
            found = m;
            break;
          }
        }
        String text = 'Try a different set of switches.';
        if (found >= 0) {
          for (int i = 0; i < c.k; i++) {
            if (((found >> i) & 1) == 1 && i < sw.length && !sw[i]) {
              text = 'Try turning switch ${c.nodeName(i)} ON.';
              break;
            }
          }
        }
        setMsg(text, true);
      }
    } else {
      final SDebug? d = dbg;
      if (d == null) return;
      if (runState == 3) resetRun();
      final List<SBlock> flat = sgFlatten(program);
      final int i = d.badIdx;
      if (i < 0 || i >= flat.length) return;
      _clearHint();
      if (hints <= 1) {
        for (int j = i - 1; j <= i + 1; j++) {
          if (j >= 0 && j < flat.length) hintRegion.add(flat[j]);
        }
        setMsg('The fault is in the highlighted region.', true);
      } else {
        hintBad = flat[i];
        setMsg('That block is the faulty one. Tap it and choose a fix.', true);
      }
    }
  }

  void showSolution() {
    if (solved || fails < 3 || kind == 1 || running) return;
    solutionShown = true;
    if (kind == 0) {
      final SBoard? b = board;
      if (b == null) return;
      resetRun();
      _clearHint();
      program = sgClone(b.ref);
      sel = null;
      tgtOwner = null;
      tgtBranch = 0;
      setMsg('Here is one working program. Press RUN to watch it.', true);
    } else {
      final SDebug? d = dbg;
      if (d == null) return;
      resetRun();
      dbgSel = d.badIdx;
      dbgOptions = sgPickFixes(Random(content.seed + 101 * (dbgSel + 1)), d, dbgSel);
      for (int i = 0; i < dbgOptions.length; i++) {
        if (sgPasses(d.board, sgApplyFix(program, dbgSel, dbgOptions[i]))) {
          chooseFix(i);
          return;
        }
      }
    }
  }

  void skipStage() {
    if (solved || phase != 1 || fails < 4) return;
    resetRun();
    starsBy[stage] = 0;
    doneBy[stage] = true;
    _recordPuzzle(false);
    cues.add('lose');
    _advanceStage();
  }

  void _advanceStage() {
    phase = 0;
    if (stage >= stageCount - 1) {
      over = true;
    } else {
      stage++;
    }
  }

  // ---- circuit actions -----------------------------------------------------------------------

  void toggleSwitch(int i) {
    if (kind != 1 || bSub != 2 || solved || makePending) return;
    if (i < 0 || i >= sw.length) return;
    sw[i] = !sw[i];
    msg = '';
    cues.add('tap');
  }

  void answerPredict(bool lampOn) {
    if (kind != 1 || bSub >= 2 || predAnswered || solved) return;
    final SCircuit c = circ1!;
    final bool truth = c.lamp(sw);
    attempts++;
    predAnswered = true;
    reveal = true;
    partial = false;
    predCorrect = lampOn == truth;
    final String res = truth ? 'ON' : 'OFF';
    final String ex = 'Lamp = ${c.lampExpr}, so the lamp is $res.';
    if (predCorrect) {
      setMsg('Correct! $ex', true);
      cues.add('good');
    } else {
      fails++;
      lastWrong = 'Predicted the lamp ${lampOn ? 'ON' : 'OFF'} but it is $res';
      setMsg('Not quite. $ex Follow the glowing wires to see why.', false);
      cues.add('bad');
    }
  }

  void nextPredict() {
    if (kind != 1 || !predAnswered || solved) return;
    if (!predCorrect) {
      final int m = sgRandomPattern(Random(content.seed + 977 * (fails + 1)), circ1!, not: predMasks[bSub]);
      predMasks[bSub] = m;
      sw = sgBits(m, 3);
    } else if (bSub == 0) {
      bSub = 1;
      sw = sgBits(predMasks[1], 3);
    } else {
      bSub = 2;
      sw = List<bool>.filled(4, false);
    }
    predAnswered = false;
    reveal = bSub == 2;
    partial = false;
    msg = '';
  }

  void resetSwitches() {
    if (kind != 1 || bSub != 2 || solved || makePending) return;
    sw = List<bool>.filled(4, false);
    msg = '';
  }

  void makeSubmit() {
    if (kind != 1 || bSub != 2 || solved || makePending) return;
    final SCircuit c = circ2!;
    if (!c.lamp(sw)) {
      setMsg('The lamp is still OFF. Try other switches.', false);
      return;
    }
    if (onCount <= minOn) {
      minimalOk = true;
      attempts++;
      _onSolved();
    } else {
      makePending = true;
      setMsg('It works with $onCount switches ON, but $minOn is enough. Keep it or try for fewer?', true);
    }
  }

  void keepMake() {
    if (!makePending) return;
    makePending = false;
    minimalOk = false;
    attempts++;
    _onSolved();
  }

  void tryFewer() {
    if (!makePending) return;
    makePending = false;
    msg = '';
  }

  // ---- debug actions ---------------------------------------------------------------------------

  void tapDebugBlock(SBlock b) {
    if (kind != 2 || solved || running) return;
    if (runState == 3) resetRun();
    final int idx = sgFlatten(program).indexOf(b);
    final SDebug? d = dbg;
    if (idx < 0 || d == null) return;
    dbgSel = idx;
    dbgOptions = sgPickFixes(Random(content.seed + 101 * (idx + 1)), d, idx);
    setMsg('Choose the fix for ${sgLabel(b)}.', true);
    cues.add('tap');
  }

  void chooseFix(int i) {
    if (kind != 2 || solved || running) return;
    if (i < 0 || i >= dbgOptions.length || dbgSel < 0) return;
    final SFix f = dbgOptions[i];
    lastWrong = f.label;
    final List<SBlock> p = sgApplyFix(program, dbgSel, f);
    _beginRun(p, false, true);
  }

  // ---- key question ------------------------------------------------------------------------------

  void continueFromClear() {
    if (!solved || phase != 1) return;
    question = content.subjectIds.contains('coding') ? content.ask('coding') : content.ask();
    keyChosen = null;
    phase = 3;
  }

  void answerKey(int i) {
    final OdyQuestion? q = question;
    if (q == null || keyChosen != null) return;
    keyChosen = i;
    final bool ok = i == q.answerIndex;
    stats.record(q, ok, chosen: q.options[i]);
    keysAsked++;
    if (ok) {
      keys++;
      cues.add('good');
    } else {
      cues.add('bad');
    }
  }

  void closeKey() {
    if (keyChosen == null) return;
    question = null;
    keyChosen = null;
    _advanceStage();
  }
}
