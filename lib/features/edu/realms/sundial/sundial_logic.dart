import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'sundial_content.dart';

/// Sundial City: a walkable town square that lost its voice. Walk to a
/// building, press FIX, repair its job (order a letter, mend a sign, spot a
/// contradiction, punctuate, choose a meaning), then hold the final debate.
/// Rumours spread slowly between buildings while you walk.

double sdClamp(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

const double sdWorldW = 1800;
const double sdWorldH = 1300;
const double sdWalkMaxY = 1268;
const Offset sdTower = Offset(900, 650);
const double sdTowerR = 42;
const double sdPlayerR = 11;
const double sdWhisperEvery = 32;
const double sdSpreadAfter = 45;
const double sdDoorReach = 46;
const double sdStartVoice = 10;
const double sdJobVoice = 16;
const double sdBossVoice = 10;
const double sdMistakeVoice = 3;
const int sdLoseCount = 5;
const int sdHall = 5;

/// One building of the square.
class SdBuilding {
  final int id;
  final String name;
  final String job;
  final String verb;
  final double l;
  final double t;
  final double r;
  final double b;
  final double doorX;
  final double doorY;
  final int color;
  final int items;
  final String bubble;
  final List<int> adj;
  const SdBuilding(this.id, this.name, this.job, this.verb, this.l, this.t, this.r, this.b, this.doorX, this.doorY, this.color, this.items, this.bubble, this.adj);

  double get cx => (l + r) / 2;
  double get cy => (t + b) / 2;
  bool get doorBelow => doorY > b;
}

const List<SdBuilding> sdBuildings = <SdBuilding>[
  SdBuilding(0, 'Post Office', 'Letter order', 'Put the letter back in order', 130, 100, 400, 290, 265, 322, 0xFFC0392B, 2, 'Every letter finds its way home now.', <int>[5, 2]),
  SdBuilding(1, 'Market', 'Sign repair', 'Mend the street signs', 1400, 100, 1670, 290, 1535, 322, 0xFF2E9E6B, 3, 'Fresh signs, fair prices, every word in its place.', <int>[5, 4]),
  SdBuilding(2, 'Courthouse', 'Witness', 'Find the sentence that cannot be true', 130, 1010, 400, 1200, 265, 978, 0xFFA79F94, 2, 'The truth never contradicts itself.', <int>[0, 3]),
  SdBuilding(3, 'School', 'Punctuation', 'Choose the correct punctuation', 730, 1010, 1070, 1200, 900, 978, 0xFF3F7CC4, 3, 'A comma in time saves a sentence.', <int>[2, 4]),
  SdBuilding(4, 'Library', 'Word in context', 'Choose the meaning', 1400, 1010, 1670, 1200, 1535, 978, 0xFF8A5A3C, 3, 'Words mean what their company says.', <int>[3, 1]),
  SdBuilding(5, 'Town Hall', 'The debate', 'Build the argument', 730, 70, 1070, 290, 900, 322, 0xFF4F6D8C, 2, 'The square has its voice again.', <int>[0, 1]),
];

class SundialLogic extends RealmLogic {
  SundialLogic(RealmContent content) : super(content) {
    say('Follow the arrow to a door and press FIX.', secs: 5);
  }

  // ---- city state --------------------------------------------------------
  final List<bool> fixed = List<bool>.filled(6, false);
  final List<bool> whisper = List<bool>.filled(6, false);
  final List<bool> spread = List<bool>.filled(6, false);
  final List<double> wAge = List<double>.filled(6, 0);
  final List<double> bubbleT = List<double>.filled(6, 0);
  final List<int> itemsDone = List<int>.filled(6, 0);
  final List<List<int>> queue = <List<int>>[<int>[], <int>[], <int>[], <int>[], <int>[], <int>[]];
  final Map<String, List<int>> _bags = <String, List<int>>{};
  double voice = sdStartVoice;
  double whisperClock = 0;
  int firstTry = 0;
  int whispersCleared = 0;
  int totalItems = 0;
  bool won = false;
  bool rumourEnded = false;
  int lastGain = 0;
  bool lastWasWhispered = false;

  // ---- phases ------------------------------------------------------------
  /// 0 walking, 1 job panel, 2 job finished card, 3 rumour ending, 4 victory.
  int phase = 0;
  int job = -1;
  int itemIx = 0;
  bool retry = false;
  bool itemDone = false;
  bool msgGood = false;
  String msg = '';

  // ---- item state --------------------------------------------------------
  // letters
  List<int> lOrder = <int>[];
  List<int> lPicks = <int>[];
  // signs
  SdSign? sign;
  List<String> tiles = <String>[];
  List<bool> tileUsed = <bool>[];
  List<int> gapTile = <int>[];
  // witness
  int cPick = -1;
  int cWrong = -1;
  // multiple choice (punctuation and vocabulary)
  List<String> opts = <String>[];
  int optRight = 0;
  final Set<int> optWrong = <int>{};
  // library question
  OdyQuestion? libQ;
  int? libChosen;
  // debate
  List<int> dOrder = <int>[];
  List<int> dSlot = <int>[-1, -1, -1];

  // ---- player ------------------------------------------------------------
  double px = 900;
  double py = 790;
  double facing = 1;
  double walkPhase = 0;
  bool moving = false;
  int atDoor = -1;
  bool hasTarget = false;
  double tx = 0;
  double ty = 0;
  double stuckT = 0;
  String toast = '';
  double toastT = 0;
  int target = -1;

  @override
  bool get modal => phase != 0;

  bool get hallOpen {
    for (int i = 0; i < 5; i++) {
      if (!fixed[i]) return false;
    }
    return true;
  }

  int get fixedCount {
    int n = 0;
    for (final bool f in fixed) {
      if (f) n++;
    }
    return n;
  }

  int get whisperCount {
    int n = 0;
    for (int i = 0; i < 6; i++) {
      if (whisper[i] && !fixed[i]) n++;
    }
    return n;
  }

  bool canEnter(int b) => b != sdHall || hallOpen;

  int get itemTotal => job < 0 ? 0 : sdBuildings[job].items;
  SdBuilding? get jobBuilding => job < 0 ? null : sdBuildings[job];

  void say(String s, {double secs = 3.2}) {
    toast = s;
    toastT = secs;
  }

  // ---- day and night -----------------------------------------------------

  /// 0 to 1 through one full day. A day lasts four minutes.
  double get dayF => ((time / 240.0) + 0.12) % 1.0;

  /// 1 at noon, 0 at midnight.
  double get light => 0.5 + 0.5 * cos(2 * pi * (dayF - 0.30));

  /// Unit direction the sundial shadow points.
  Offset get shadowDir {
    final double a = 2 * pi * dayF;
    return Offset(-cos(a), -sin(a));
  }

  double get shadowLen => 90 + 170 * (1 - light);

  // ---- random bags -------------------------------------------------------

  int _draw(String key, int n) {
    List<int>? bag = _bags[key];
    if (bag == null || bag.isEmpty) {
      bag = List<int>.generate(n, (int i) => i)..shuffle(rng);
      _bags[key] = bag;
    }
    return bag.removeLast();
  }

  void _fillQueue(int b) {
    final List<int> q = queue[b];
    q.clear();
    final int n = sdBuildings[b].items;
    for (int i = 0; i < n; i++) {
      switch (b) {
        case 0:
          q.add(_draw('letter', sdLetters.length));
          break;
        case 1:
          q.add(_draw('sign', sdSigns.length));
          break;
        case 2:
          q.add(_draw('case', sdCases.length));
          break;
        case 3:
          q.add(_draw('punct', sdPunct.length));
          break;
        case 4:
          q.add(i < 2 ? -1 : _draw('vocab', sdVocab.length));
          break;
        default:
          q.add(_draw('debate', sdDebates.length));
          break;
      }
    }
  }

  // ---- opening and leaving a job ----------------------------------------

  @override
  void onAction(int id) {
    if (id != 0) return;
    if (modal || over) return;
    if (atDoor < 0) {
      say('Walk to a building door, then press FIX.');
      return;
    }
    openJob(atDoor);
  }

  @override
  double actionReady(int id) => (atDoor >= 0 && phase == 0) ? 1 : 0;

  void openJob(int b) {
    if (phase != 0 || over || b < 0 || b > 5) return;
    final SdBuilding bd = sdBuildings[b];
    if (fixed[b]) {
      say('The ${bd.name} already has its voice back.');
      return;
    }
    if (!canEnter(b)) {
      say('The Town Hall stays sealed until the other five buildings speak.');
      return;
    }
    if (queue[b].isEmpty) _fillQueue(b);
    job = b;
    itemIx = itemsDone[b];
    phase = 1;
    inputX = 0;
    inputY = 0;
    hasTarget = false;
    _startItem();
    cues.add('tap');
  }

  /// Leave a job between items. Not possible once the current item has been tried.
  bool get canStepOut => phase == 1 && !retry && !itemDone;

  void stepOut() {
    if (!canStepOut) return;
    phase = 0;
    job = -1;
  }

  // ---- starting an item --------------------------------------------------

  void _startItem() {
    retry = false;
    itemDone = false;
    msg = '';
    msgGood = false;
    optWrong.clear();
    lPicks = <int>[];
    cPick = -1;
    cWrong = -1;
    libChosen = null;
    dSlot = <int>[-1, -1, -1];
    if (job < 0 || itemIx >= queue[job].length) return;
    final int idx = queue[job][itemIx];
    switch (job) {
      case 0: {
        lOrder = <int>[0, 1, 2, 3, 4]..shuffle(rng);
        for (int tries = 0; tries < 6; tries++) {
          bool identity = true;
          for (int i = 0; i < 5; i++) {
            if (lOrder[i] != i) identity = false;
          }
          if (!identity) break;
          lOrder.shuffle(rng);
        }
        break;
      }
      case 1: {
        final SdSign s = sdSigns[idx];
        sign = s;
        tiles = <String>[...s.answers, ...s.wrong]..shuffle(rng);
        tileUsed = List<bool>.filled(tiles.length, false);
        gapTile = List<int>.filled(s.gaps, -1);
        break;
      }
      case 3: {
        final SdPunct p = sdPunct[idx];
        opts = <String>[p.right, ...p.wrong]..shuffle(rng);
        optRight = opts.indexOf(p.right);
        break;
      }
      case 4: {
        if (itemIx < 2) {
          libQ ??= content.subjectIds.contains('english') ? content.ask('english') : content.ask();
        } else {
          final SdVocab v = sdVocab[idx];
          opts = <String>[v.right, ...v.wrong]..shuffle(rng);
          optRight = opts.indexOf(v.right);
        }
        break;
      }
      case 5: {
        dOrder = <int>[0, 1, 2, 3, 4, 5, 6]..shuffle(rng);
        break;
      }
      default:
        break;
    }
  }

  // ---- judging -----------------------------------------------------------

  void _judge(bool ok, {required String prompt, required String chosen, required String answer}) {
    if (!retry) {
      stats.recordTask('english', ok, prompt: prompt, chosen: ok ? 'No answer' : chosen, answer: answer);
      totalItems++;
      if (ok) {
        firstTry++;
        itemDone = true;
        msgGood = true;
        msg = 'Right first time.';
        cues.add('good');
      } else {
        retry = true;
        msgGood = false;
        msg = 'Not quite. The right answer is shown. Try it once more.';
        voice = max(0.0, voice - sdMistakeVoice);
        _rumourGrows();
        cues.add('bad');
      }
    } else if (ok) {
      itemDone = true;
      msgGood = true;
      msg = 'Good. Now you have it.';
      cues.add('good');
    } else {
      msgGood = false;
      msg = 'Look at the answer shown and try once more.';
      cues.add('bad');
    }
  }

  /// A mistake feeds the rumour: the next whisper comes sooner and whispers
  /// already in the square age a little.
  void _rumourGrows() {
    whisperClock += 8;
    for (int i = 0; i < 6; i++) {
      if (whisper[i] && !fixed[i] && !spread[i]) wAge[i] += 5;
    }
  }

  // ---- letter order ------------------------------------------------------

  SdLetter get letter => sdLetters[queue[0][itemIx]];

  void tapLetter(int p) {
    if (job != 0 || itemDone || p < 0 || p > 4) return;
    if (lPicks.contains(p)) {
      lPicks.remove(p);
    } else if (lPicks.length < 5) {
      lPicks.add(p);
    }
    cues.add('tap');
  }

  /// The number that sentence p should carry (1 to 5).
  int letterRightNumber(int p) => lOrder[p] + 1;

  void sendLetter() {
    if (job != 0 || itemDone || lPicks.length != 5) return;
    final SdLetter L = letter;
    bool ok = true;
    for (int k = 0; k < 5; k++) {
      if (lOrder[lPicks[k]] != k) ok = false;
    }
    final String chosen = lPicks.map((int p) => '${lOrder[p] + 1}').join(', ');
    _judge(ok, prompt: 'Put the sentences of "${L.title}" in order.', chosen: 'You sent them as: $chosen', answer: L.lines.join(' '));
    if (!ok) lPicks = <int>[];
  }

  // ---- sign repair -------------------------------------------------------

  void tapTile(int i) {
    final SdSign? s = sign;
    if (job != 1 || itemDone || s == null || i < 0 || i >= tiles.length || tileUsed[i]) return;
    for (int g = 0; g < gapTile.length; g++) {
      if (gapTile[g] < 0) {
        gapTile[g] = i;
        tileUsed[i] = true;
        cues.add('tap');
        return;
      }
    }
  }

  void tapGap(int g) {
    if (job != 1 || itemDone || g < 0 || g >= gapTile.length) return;
    final int t = gapTile[g];
    if (t < 0) return;
    gapTile[g] = -1;
    tileUsed[t] = false;
    cues.add('tap');
  }

  bool get signFull {
    if (gapTile.isEmpty) return false;
    for (final int t in gapTile) {
      if (t < 0) return false;
    }
    return true;
  }

  void checkSign() {
    final SdSign? s = sign;
    if (job != 1 || itemDone || s == null || !signFull) return;
    final List<String> given = <String>[for (final int t in gapTile) tiles[t]];
    bool ok = true;
    for (int g = 0; g < s.gaps; g++) {
      if (given[g] != s.answers[g]) ok = false;
    }
    _judge(ok, prompt: 'Fix the sign: ${s.text.replaceAll('__', '_____')}', chosen: given.join(', '), answer: s.solved);
    if (!ok) {
      for (int i = 0; i < tileUsed.length; i++) {
        tileUsed[i] = false;
      }
      for (int g = 0; g < gapTile.length; g++) {
        gapTile[g] = -1;
      }
    }
  }

  // ---- witness -----------------------------------------------------------

  SdCase get witness => sdCases[queue[2][itemIx]];

  void pickStatement(int i) {
    if (job != 2 || itemDone) return;
    final SdCase c = witness;
    if (i < 0 || i >= c.b.length) return;
    cPick = i;
    cues.add('tap');
  }

  void confirmWitness() {
    if (job != 2 || itemDone || cPick < 0) return;
    final SdCase c = witness;
    final bool ok = cPick == c.bad;
    _judge(ok, prompt: '${c.title}: which sentence in the second statement cannot be true if the first statement is true?', chosen: c.b[cPick], answer: c.b[c.bad]);
    if (!ok) {
      cWrong = cPick;
      cPick = -1;
    }
  }

  // ---- punctuation and vocabulary ---------------------------------------

  SdPunct get punct => sdPunct[queue[3][itemIx]];
  SdVocab get vocab => sdVocab[queue[4][itemIx]];

  void pickOption(int i) {
    if ((job != 3 && !(job == 4 && itemIx >= 2)) || itemDone || i < 0 || i >= opts.length || optWrong.contains(i)) return;
    final bool ok = i == optRight;
    if (job == 3) {
      final SdPunct p = punct;
      _judge(ok, prompt: 'Punctuate this sentence: ${p.raw}', chosen: opts[i], answer: p.right);
    } else {
      final SdVocab v = vocab;
      _judge(ok, prompt: 'What does "${v.word}" mean here? ${v.plain}', chosen: opts[i], answer: v.right);
    }
    if (!ok) optWrong.add(i);
  }

  /// Library school question: a wrong answer shows the right one and moves on.
  void answerLib(int i) {
    final OdyQuestion? q = libQ;
    if (job != 4 || itemIx >= 2 || q == null || libChosen != null || itemDone) return;
    libChosen = i;
    final bool ok = i == q.answerIndex;
    stats.record(q, ok, chosen: ok ? 'No answer' : q.options[i]);
    totalItems++;
    itemDone = true;
    if (ok) {
      firstTry++;
      msgGood = true;
      msg = 'Correct.';
      cues.add('good');
    } else {
      msgGood = false;
      msg = 'Not quite. The right answer is highlighted.';
      voice = max(0.0, voice - sdMistakeVoice);
      _rumourGrows();
      cues.add('bad');
    }
  }

  // ---- debate ------------------------------------------------------------

  SdDebate get debate => sdDebates[queue[5][itemIx]];

  void tapCard(int c) {
    if (job != 5 || itemDone || c < 0 || c > 6 || dSlot.contains(c)) return;
    for (int s = 0; s < 3; s++) {
      if (dSlot[s] < 0) {
        dSlot[s] = c;
        cues.add('tap');
        return;
      }
    }
  }

  void tapSlot(int s) {
    if (job != 5 || itemDone || s < 0 || s > 2 || dSlot[s] < 0) return;
    dSlot[s] = -1;
    cues.add('tap');
  }

  bool get debateFull => !dSlot.contains(-1);

  bool debateSlotRight(int s) => dSlot[s] == sdDebateAnswer[s];

  void submitDebate() {
    if (job != 5 || itemDone || !debateFull) return;
    final SdDebate d = debate;
    bool ok = true;
    for (int s = 0; s < 3; s++) {
      if (dSlot[s] != sdDebateAnswer[s]) ok = false;
    }
    final String chosen = <String>[for (int s = 0; s < 3; s++) '${sdDebateSlots[s]}: ${d.cards[dSlot[s]]}'].join(' | ');
    final String answer = <String>[for (int s = 0; s < 3; s++) '${sdDebateSlots[s]}: ${d.cards[sdDebateAnswer[s]]}'].join(' | ');
    _judge(ok, prompt: 'Build the argument: ${d.question}', chosen: chosen, answer: answer);
    if (!ok) dSlot = <int>[-1, -1, -1];
  }

  // ---- finishing an item and a job --------------------------------------

  void nextItem() {
    if (phase != 1 || !itemDone) return;
    itemsDone[job] = itemsDone[job] + 1;
    libQ = null;
    if (itemsDone[job] >= sdBuildings[job].items) {
      _completeJob();
    } else {
      itemIx = itemsDone[job];
      _startItem();
    }
  }

  void _completeJob() {
    final int b = job;
    fixed[b] = true;
    lastWasWhispered = whisper[b];
    if (whisper[b]) {
      whisper[b] = false;
      whispersCleared++;
    }
    final double gain = b == sdHall ? sdBossVoice : sdJobVoice;
    final double before = voice;
    voice = min(100.0, voice + gain);
    lastGain = (voice - before).round();
    bubbleT[b] = 10;
    cues.add('win');
    if (b == sdHall) {
      won = true;
      for (int i = 0; i < 6; i++) {
        whisper[i] = false;
      }
      phase = 4;
    } else {
      phase = 2;
    }
  }

  void closeCard() {
    if (phase != 2) return;
    phase = 0;
    job = -1;
    if (hallOpen && !fixed[sdHall]) {
      say('The Town Hall doors are open. Walk there and press FIX.', secs: 4.5);
    }
  }

  /// FINISH on the victory card or the gentle ending card.
  void finishRun() {
    if (phase != 4 && phase != 3) return;
    over = true;
  }

  // ---- whispers ----------------------------------------------------------

  bool _eligible(int b) => !fixed[b] && !whisper[b];

  void _addWhisper(int b) {
    whisper[b] = true;
    wAge[b] = 0;
    spread[b] = false;
    cues.add('bad');
  }

  void _spawnWhisper() {
    final List<int> pool = <int>[for (int i = 0; i < 6; i++) if (_eligible(i)) i];
    if (pool.isEmpty) return;
    final int b = pool[rng.nextInt(pool.length)];
    _addWhisper(b);
    say('A rumour is stirring at the ${sdBuildings[b].name}.', secs: 3.5);
  }

  void _spreadFrom(int b) {
    final List<int> pool = <int>[for (final int a in sdBuildings[b].adj) if (_eligible(a)) a];
    if (pool.isEmpty) return;
    final int t = pool[rng.nextInt(pool.length)];
    _addWhisper(t);
    say('The rumour spread to the ${sdBuildings[t].name}.', secs: 3.5);
  }

  void _whisperStep(double dt) {
    whisperClock += dt;
    if (whisperClock >= sdWhisperEvery) {
      whisperClock -= sdWhisperEvery;
      if (whisperClock > sdWhisperEvery) whisperClock = 0;
      _spawnWhisper();
    }
    for (int i = 0; i < 6; i++) {
      if (!whisper[i] || fixed[i]) continue;
      wAge[i] += dt;
      if (!spread[i] && wAge[i] >= sdSpreadAfter) {
        spread[i] = true;
        _spreadFrom(i);
      }
    }
    if (whisperCount >= sdLoseCount) {
      rumourEnded = true;
      phase = 3;
      inputX = 0;
      inputY = 0;
      hasTarget = false;
      cues.add('lose');
    }
  }

  /// Seconds until the next whisper appears.
  double get nextWhisperIn => max(0.0, sdWhisperEvery - whisperClock);

  // ---- movement ----------------------------------------------------------

  bool blockedAt(double x, double y) {
    if (x < 30 || x > sdWorldW - 30 || y < 40 || y > sdWalkMaxY) return true;
    for (final SdBuilding p in sdBuildings) {
      if (x > p.l - sdPlayerR && x < p.r + sdPlayerR && y > p.t - sdPlayerR && y < p.b + sdPlayerR) return true;
    }
    final double ex = x - sdTower.dx;
    final double ey = y - sdTower.dy;
    final double rr = sdTowerR + sdPlayerR;
    return ex * ex + ey * ey < rr * rr;
  }

  @override
  void step(double dt) {
    if (toastT > 0) toastT -= dt;
    for (int i = 0; i < 6; i++) {
      if (bubbleT[i] > 0) bubbleT[i] -= dt;
    }
    moving = false;
    if (over || modal) return;
    const double speed = 200;
    double dx = inputX;
    double dy = inputY;
    final bool manual = dx * dx + dy * dy > 0.01;
    if (manual) {
      hasTarget = false;
    } else if (hasTarget) {
      final double ex = tx - px;
      final double ey = ty - py;
      final double d = sqrt(ex * ex + ey * ey);
      if (d < 6) {
        hasTarget = false;
        dx = 0;
        dy = 0;
      } else {
        dx = ex / d;
        dy = ey / d;
        final double stepLen = speed * dt;
        if (d < stepLen) {
          dx = ex / stepLen;
          dy = ey / stepLen;
        }
      }
    }
    if (dx != 0 || dy != 0) {
      final double ox = px;
      final double oy = py;
      final double nx = px + dx * speed * dt;
      if (!blockedAt(nx, py)) px = nx;
      final double ny = py + dy * speed * dt;
      if (!blockedAt(px, ny)) py = ny;
      final double mx = px - ox;
      final double my = py - oy;
      final double moved = sqrt(mx * mx + my * my);
      moving = moved > 0.01;
      if (moving) {
        walkPhase += dt * 11;
        if (mx.abs() > 0.01) facing = mx > 0 ? 1 : -1;
      }
      if (hasTarget) {
        final double want = sqrt(dx * dx + dy * dy) * speed * dt;
        if (moved < want * 0.25) {
          stuckT += dt;
          if (stuckT > 0.7) {
            hasTarget = false;
            stuckT = 0;
            say('The way is blocked. Try the streets.');
          }
        } else {
          stuckT = 0;
        }
      }
    } else {
      stuckT = 0;
    }
    _updateDoor();
    _whisperStep(dt);
    if (phase == 0) _updateTarget();
  }

  void _updateDoor() {
    int found = -1;
    for (final SdBuilding p in sdBuildings) {
      final double ex = px - p.doorX;
      final double ey = py - p.doorY;
      if (ex * ex + ey * ey < sdDoorReach * sdDoorReach) {
        found = p.id;
        break;
      }
    }
    atDoor = found;
  }

  double _doorDist(int b) {
    final SdBuilding p = sdBuildings[b];
    final double ex = p.doorX - px;
    final double ey = p.doorY - py;
    return sqrt(ex * ex + ey * ey);
  }

  void _updateTarget() {
    int best = -1;
    double bd = 1e12;
    for (int i = 0; i < 6; i++) {
      if (fixed[i] || !whisper[i] || !canEnter(i)) continue;
      final double d = _doorDist(i);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    if (best < 0) {
      for (int i = 0; i < 6; i++) {
        if (fixed[i] || !canEnter(i)) continue;
        final double d = _doorDist(i);
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
    }
    target = best;
  }

  // ---- camera and taps ---------------------------------------------------

  double zoomFor(Size s) => sdClamp(s.shortestSide / 500.0, 0.55, 1.5);

  Offset cameraFor(Size s) {
    final double z = zoomFor(s);
    final double hw = s.width / (2 * z);
    final double hh = s.height / (2 * z);
    double cx = sdWorldW / 2;
    double cy = sdWorldH / 2;
    if (hw * 2 < sdWorldW) cx = sdClamp(px, hw, sdWorldW - hw);
    if (hh * 2 < sdWorldH) cy = sdClamp(py - 20, hh, sdWorldH - hh);
    return Offset(cx, cy);
  }

  Offset screenToWorld(Offset p, Size s) {
    final double z = zoomFor(s);
    final Offset cam = cameraFor(s);
    return Offset(cam.dx + (p.dx - s.width / 2) / z, cam.dy + (p.dy - s.height / 2) / z);
  }

  @override
  void onTap(Offset point, Size size) {
    if (modal || over) return;
    final Offset w = screenToWorld(point, size);
    for (final SdBuilding p in sdBuildings) {
      if (w.dx > p.l - 8 && w.dx < p.r + 8 && w.dy > p.t - 8 && w.dy < p.b + 8) {
        if (atDoor == p.id) {
          openJob(p.id);
          return;
        }
        tx = p.doorX;
        ty = p.doorY;
        hasTarget = true;
        stuckT = 0;
        say('Heading to the ${p.name}. Press FIX at the door.', secs: 1.8);
        cues.add('tap');
        return;
      }
    }
    final double gx = sdClamp(w.dx, 30, sdWorldW - 30);
    final double gy = sdClamp(w.dy, 40, sdWalkMaxY);
    if (blockedAt(gx, gy)) return;
    tx = gx;
    ty = gy;
    hasTarget = true;
    stuckT = 0;
  }

  // ---- objective ---------------------------------------------------------

  @override
  String? get objectiveText {
    if (phase != 0 || over) return null;
    final int t = target;
    if (t < 0) return null;
    final SdBuilding b = sdBuildings[t];
    if (atDoor == t) return 'Press FIX to open the ${b.name} job.';
    if (whisper[t]) return 'A rumour is at the ${b.name}. Walk there and press FIX.';
    if (t == sdHall) return 'The Town Hall is open. Walk there and press FIX to hold the debate.';
    return 'Walk to the ${b.name} and press FIX.';
  }

  @override
  Offset? get objectiveDelta {
    if (phase != 0 || over || target < 0) return null;
    final SdBuilding b = sdBuildings[target];
    return Offset(b.doorX - px, b.doorY - py);
  }

  @override
  String? get objectiveDistance {
    if (phase != 0 || over || target < 0) return null;
    return '${(_doorDist(target) / 10).round()} m';
  }

  // ---- results -----------------------------------------------------------

  @override
  int get finalScore => (voice * 10).round() + firstTry * 15 + whispersCleared * 40 + (won ? 400 : 0);

  @override
  int get xp => stats.baseXp + fixedCount * 10 + (won ? 40 : 0);

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('Voice ${voice.round()}%', Icons.record_voice_over_rounded, const Color(0xFFF6B93B)),
        RealmChip('Buildings fixed $fixedCount/6', Icons.home_work_rounded, const Color(0xFF69F0AE)),
        RealmChip('Whispers $whisperCount', Icons.hearing_rounded, whisperCount >= 3 ? const Color(0xFFFF5252) : const Color(0xFFB0BEC5)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Voice restored': '${voice.round()}%',
        'Buildings fixed': '$fixedCount/6',
        'Jobs first try': '$firstTry/$totalItems',
        'Whispers contained': '$whispersCleared',
        'Ending': won ? 'The bell rang' : (rumourEnded ? 'The rumour took the square' : 'Left early'),
      };
}
