import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';

/// Case Files: an open-town detective game. Walk the town, investigate
/// locations by answering questions, collect clues and deduce the culprit.

double caseClamp(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

const double caseWorldW = 1400;
const double caseWorldH = 1000;
const double caseWalkMaxY = 890;
const double casePlayerR = 11;
const int caseStartHours = 12;
const int caseMaxCases = 3;
const int caseMaxFails = 2;
const int caseSuspectCount = 5;

/// A location in town. The body is a footprint that blocks movement; the
/// door spot is where the player stands to investigate.
class CasePlace {
  final int id;
  final String name;
  final double l;
  final double t;
  final double r;
  final double b;
  final double doorX;
  final double doorY;
  final int color;
  final String lead;
  final String blurb;
  const CasePlace(this.id, this.name, this.l, this.t, this.r, this.b, this.doorX, this.doorY, this.color, this.lead, this.blurb);
}

const List<CasePlace> casePlaces = <CasePlace>[
  CasePlace(0, 'Library', 65, 80, 285, 250, 175, 278, 0xFF7E57C2, 'The librarian lets you see the visitor log if you can answer:', 'Dusty shelves, a sleepy cat and a very quiet librarian.'),
  CasePlace(1, 'Market', 415, 80, 635, 250, 525, 278, 0xFFEF6C00, 'The stallholder will share what she saw if you can answer:', 'Stalls of fruit and fish. Everyone here has an opinion.'),
  CasePlace(2, 'Harbour', 1115, 665, 1335, 835, 1225, 637, 0xFF0288D1, 'The harbour master opens the tide book if you can answer:', 'Gulls cry over the water and ropes creak on the pier.'),
  CasePlace(3, 'Clinic', 765, 665, 985, 835, 875, 637, 0xFF26A69A, 'The nurse checks the night register if you can answer:', 'A calm waiting room that smells of soap and mint tea.'),
  CasePlace(4, 'School', 765, 80, 985, 250, 875, 278, 0xFFFBC02D, 'The teacher asks what the class noticed, if you can answer:', 'A bell rings and children press their faces to the windows.'),
  CasePlace(5, 'Workshop', 415, 665, 635, 835, 525, 637, 0xFF8D6E63, 'The mechanic checks the repair tickets if you can answer:', 'Sparks, oil and a radio playing old songs.'),
  CasePlace(6, 'Bakery', 65, 665, 285, 835, 175, 637, 0xFFE57373, 'The baker shares the early morning gossip if you can answer:', 'Warm bread and sweet buns. Someone is always queueing.'),
  CasePlace(7, 'Town Hall', 1115, 80, 1335, 250, 1225, 278, 0xFF5C6BC0, 'The clerk unlocks the records if you can answer:', 'Stone steps, a brass clock and a lot of paperwork.'),
];

const List<String> caseHandNames = <String>['left', 'right'];
const List<String> caseShoeNames = <String>['red', 'blue', 'green', 'black'];
const List<String> caseCarryNames = <String>['umbrella', 'bag', 'toolbox', 'ledger'];
const List<String> caseCarryPhrases = <String>['an umbrella', 'a bag', 'a toolbox', 'a ledger'];
const List<int> caseShoeColors = <int>[0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFF263238];
const List<String> caseRoles = <String>['baker', 'sailor', 'teacher', 'doctor', 'clerk', 'mechanic', 'fisher', 'tailor', 'gardener', 'porter'];
const List<String> caseNames = <String>[
  'Ada Pell', 'Bode Ashby', 'Cora Finch', 'Dayo Quill', 'Edda Rook', 'Femi Lark',
  'Gwen Tully', 'Hale Okoro', 'Ines Moss', 'Jude Perrin', 'Kemi Daly', 'Lowe Barrow',
];
const List<String> caseWhats = <String>[
  'the brass harbour bell', 'the prize pie recipe', 'the town clock key',
  'the silver school cup', 'the lamp oil money box', 'the old river map',
];
const List<String> caseShorts = <String>['Bell', 'Pie Recipe', 'Clock Key', 'School Cup', 'Money Box', 'River Map'];
const List<String> caseWhens = <String>[
  'on market night', 'just before dawn', 'during the evening tide',
  'while the fair was on', 'on the night of the storm',
];

const List<List<String>> caseHerrings = <List<String>>[
  <String>['The librarian remembers a noisy hour of page turning, but nothing useful.', 'Someone returned a book very late. That is all the log shows.'],
  <String>['The stallholders argue about the price of fish. Nothing about the culprit.', 'A fruit seller saw gulls steal a loaf that night. Funny, but no help.'],
  <String>['The tide was high and the boats were all tied up. Nothing odd.', 'A sailor sang off key all night. That is the only thing anyone noticed.'],
  <String>['The night nurse saw only a sneezing visitor with a cold.', 'The register shows a lost scarf and nothing else.'],
  <String>['The children drew pictures of the thief. They drew a purple dragon.', 'The teacher noticed the playground gate swinging, but saw nobody.'],
  <String>['The mechanic fixed a bicycle bell that night. No leads here.', 'A wheel went missing, then turned up under a bench. Not our case.'],
  <String>['The baker says the ovens were lit from midnight. Nobody came by.', 'A crumb trail leads to a very guilty-looking dog.'],
  <String>['The records show the clock was five minutes slow. That is all.', 'The clerk found a stamp on the wrong form. A dull dead end.'],
];

/// A suspect with four checkable traits and a role.
class CaseSuspect {
  final String name;
  final String role;
  final int hand;
  final int shoe;
  final int carries;
  final int near;
  const CaseSuspect(this.name, this.role, this.hand, this.shoe, this.carries, this.near);

  /// Trait by kind: 0 hand, 1 shoe, 2 carries, 3 seen near.
  int attr(int k) {
    switch (k) {
      case 0:
        return hand;
      case 1:
        return shoe;
      case 2:
        return carries;
      default:
        return near;
    }
  }
}

/// A clue. Kinds 0 to 3 name a trait of the culprit, 4 rules out one suspect
/// by name, 5 is a story clue that rules out nobody.
class CaseClue {
  final int kind;
  final int value;
  final String text;
  final bool useful;
  const CaseClue(this.kind, this.value, this.text, this.useful);

  /// True when the suspect at [index] is still possible after this clue.
  bool fits(CaseSuspect s, int index) {
    if (kind <= 3) return s.attr(kind) == value;
    if (kind == 4) return index != value;
    return true;
  }
}

String caseTraitLabel(CaseSuspect s, int k) {
  switch (k) {
    case 0:
      return s.hand == 0 ? 'Left-handed' : 'Right-handed';
    case 1:
      return '${caseShoeNames[s.shoe][0].toUpperCase()}${caseShoeNames[s.shoe].substring(1)} shoes';
    case 2:
      return 'Carries ${caseCarryPhrases[s.carries]}';
    default:
      return 'Seen near ${casePlaces[s.near].name}';
  }
}

class CaseFilesLogic extends RealmLogic {
  CaseFilesLogic(RealmContent content) : super(content) {
    _newCase();
    phase = 2;
  }

  // ---- case state --------------------------------------------------------
  int caseNo = 1;
  int solved = 0;
  int failed = 0;
  int totalScore = 0;
  int totalClues = 0;
  int lastHours = 0;
  int hoursLeft = caseStartHours;
  int correctInCase = 0;
  int culprit = 0;
  int whatIndex = 0;
  int hookPlace = 0;
  String hook = '';
  String title = '';
  final List<CaseSuspect> suspects = <CaseSuspect>[];
  List<CaseClue> clueAt = <CaseClue>[];
  final List<bool> revealed = List<bool>.filled(8, false);
  final List<int> foundOrder = <int>[];
  final List<int> marks = List<int>.filled(caseSuspectCount, 0);
  int cluesNeeded = 0;

  // ---- phases ------------------------------------------------------------
  /// 0 walking, 1 question, 2 story card, 3 accusing, 4 verdict.
  int phase = 2;
  bool notebookOpen = false;
  bool forcedAccuse = false;
  int accuseSel = -1;
  bool verdictOk = false;
  int accused = -1;
  int caseScore = 0;
  OdyQuestion? question;
  int? chosen;
  int askLoc = -1;
  String resultLine = '';

  // ---- player ------------------------------------------------------------
  double px = 700;
  double py = 455;
  double facing = 1;
  double walkPhase = 0;
  bool moving = false;
  int atDoor = -1;
  bool hasTarget = false;
  double tx = 0;
  double ty = 0;
  int autoLoc = -1;
  double stuckT = 0;
  String toast = '';
  double toastT = 0;

  @override
  bool get modal => phase != 0 || notebookOpen;

  @override
  int get hearts => -1;

  int get cluesFound => foundOrder.length;
  bool get canAccuse => hoursLeft <= 0 || cluesFound >= cluesNeeded;
  bool get runEnds => caseNo >= caseMaxCases || failed >= caseMaxFails;
  CaseSuspect get culpritSuspect => suspects[culprit];

  void say(String s, {double secs = 3.2}) {
    toast = s;
    toastT = secs;
  }

  // ---- case generation ---------------------------------------------------

  void _newCase() {
    final Random r = rng;
    final List<String> names = List<String>.from(caseNames)..shuffle(r);
    final List<String> roles = List<String>.from(caseRoles)..shuffle(r);
    suspects.clear();
    for (int i = 0; i < caseSuspectCount; i++) {
      suspects.add(CaseSuspect(names[i], roles[i], r.nextInt(2), r.nextInt(4), r.nextInt(4), r.nextInt(8)));
    }
    culprit = r.nextInt(caseSuspectCount);
    whatIndex = r.nextInt(caseWhats.length);
    hookPlace = r.nextInt(8);
    final String when = caseWhens[r.nextInt(caseWhens.length)];
    hook = 'Someone took ${caseWhats[whatIndex]} from the ${casePlaces[hookPlace].name} $when.';
    title = 'The Missing ${caseShorts[whatIndex]}';

    final CaseSuspect cu = suspects[culprit];
    final List<bool> alive = List<bool>.filled(caseSuspectCount, true);
    final Set<int> used = <int>{};
    final List<CaseClue> useful = <CaseClue>[];
    while (true) {
      final List<int> rest = <int>[];
      for (int i = 0; i < caseSuspectCount; i++) {
        if (i != culprit && alive[i]) rest.add(i);
      }
      if (rest.isEmpty) break;
      final int t = rest[r.nextInt(rest.length)];
      final List<int> opts = <int>[];
      for (int k = 0; k < 4; k++) {
        if (suspects[t].attr(k) != cu.attr(k) && !used.contains(k * 100 + cu.attr(k))) opts.add(k);
      }
      int kind = 4;
      if (opts.isNotEmpty && r.nextDouble() >= 0.3) kind = opts[r.nextInt(opts.length)];
      final int value = kind == 4 ? t : cu.attr(kind);
      if (kind < 4) used.add(kind * 100 + value);
      final CaseClue c = CaseClue(kind, value, _clueText(kind, value), true);
      for (int i = 0; i < caseSuspectCount; i++) {
        if (i != culprit && !c.fits(suspects[i], i)) alive[i] = false;
      }
      useful.add(c);
    }
    cluesNeeded = useful.length;

    final List<int> order = <int>[0, 1, 2, 3, 4, 5, 6, 7]..shuffle(r);
    final List<CaseClue?> slots = List<CaseClue?>.filled(8, null);
    for (int i = 0; i < 8; i++) {
      final int loc = order[i];
      if (i < useful.length) {
        slots[loc] = useful[i];
      } else {
        final int v = r.nextInt(2);
        slots[loc] = CaseClue(5, v, caseHerrings[loc][v], false);
      }
    }
    clueAt = <CaseClue>[for (int i = 0; i < 8; i++) slots[i]!];
    for (int i = 0; i < 8; i++) {
      revealed[i] = false;
    }
    foundOrder.clear();
    for (int i = 0; i < caseSuspectCount; i++) {
      marks[i] = 0;
    }
    hoursLeft = caseStartHours;
    correctInCase = 0;
    forcedAccuse = false;
    accuseSel = -1;
    accused = -1;
    notebookOpen = false;
    question = null;
    chosen = null;
    askLoc = -1;
    px = 700;
    py = 455;
    hasTarget = false;
    autoLoc = -1;
    atDoor = -1;
  }

  String _clueText(int kind, int value) {
    switch (kind) {
      case 0:
        return 'Witness: the culprit wrote with their ${caseHandNames[value]} hand.';
      case 1:
        return 'Muddy footprints show the culprit wore ${caseShoeNames[value]} shoes.';
      case 2:
        return 'A passer-by saw the culprit carrying ${caseCarryPhrases[value]}.';
      case 3:
        return 'Someone saw the culprit near the ${casePlaces[value].name} that night.';
      default:
        {
          final CaseSuspect s = suspects[value];
          return 'It was not ${s.name} the ${s.role}: their alibi checks out.';
        }
    }
  }

  // ---- flow --------------------------------------------------------------

  void beginCase() {
    if (phase != 2) return;
    phase = 0;
    say('Walk to a door and inspect it. Walking is free, each inspection costs an hour.', secs: 4);
  }

  void toggleNotebook() {
    if (phase != 0) return;
    notebookOpen = !notebookOpen;
    inputX = 0;
    inputY = 0;
    hasTarget = false;
    autoLoc = -1;
  }

  void cycleMark(int i) {
    if (i < 0 || i >= caseSuspectCount) return;
    marks[i] = (marks[i] + 1) % 3;
    cues.add('tap');
  }

  @override
  void onAction(int id) {
    if (id == 0) inspect();
  }

  void inspect() {
    if (modal || over) return;
    if (atDoor >= 0) {
      startAsk(atDoor);
    } else {
      say('Walk to a door first. Tap a building to head there.');
    }
  }

  void startAsk(int loc) {
    if (phase != 0 || loc < 0 || loc > 7) return;
    if (revealed[loc]) {
      say('You already learned what the ${casePlaces[loc].name} can tell you.');
      return;
    }
    if (hoursLeft <= 0) return;
    question = content.ask(content.randomSubject());
    chosen = null;
    askLoc = loc;
    resultLine = '';
    phase = 1;
    notebookOpen = false;
    inputX = 0;
    inputY = 0;
    hasTarget = false;
    autoLoc = -1;
    cues.add('tap');
  }

  void answer(int i) {
    final OdyQuestion? q = question;
    if (phase != 1 || q == null || chosen != null) return;
    chosen = i;
    final bool ok = i == q.answerIndex;
    stats.record(q, ok, chosen: ok ? 'No answer' : q.options[i]);
    hoursLeft = hoursLeft > 0 ? hoursLeft - 1 : 0;
    if (ok) {
      revealed[askLoc] = true;
      foundOrder.add(askLoc);
      totalClues++;
      correctInCase++;
      resultLine = 'Clue found and written in your notebook.';
      cues.add('good');
    } else {
      resultLine = 'Wrong. An hour is lost and the clue stays hidden. Come back with a new question.';
      cues.add('bad');
    }
  }

  void closeAsk() {
    if (phase != 1 || chosen == null) return;
    question = null;
    chosen = null;
    phase = 0;
    if (hoursLeft <= 0) {
      forcedAccuse = true;
      accuseSel = -1;
      phase = 3;
      notebookOpen = false;
    }
  }

  void openAccuse() {
    if (phase != 0) return;
    if (!canAccuse) {
      say('You need at least $cluesNeeded clues before you can accuse.');
      return;
    }
    phase = 3;
    notebookOpen = false;
    accuseSel = -1;
  }

  void closeAccuse() {
    if (phase != 3 || forcedAccuse) return;
    phase = 0;
  }

  void selectSuspect(int i) {
    if (phase != 3) return;
    accuseSel = i;
    cues.add('tap');
  }

  void confirmAccuse() {
    if (phase != 3 || accuseSel < 0) return;
    accuse(accuseSel);
  }

  void accuse(int idx) {
    if (phase != 3) return;
    accused = idx;
    verdictOk = idx == culprit;
    if (verdictOk) {
      solved++;
      caseScore = 500 + hoursLeft * 60 + correctInCase * 20;
      cues.add('win');
    } else {
      failed++;
      caseScore = 50;
      cues.add('lose');
    }
    totalScore += caseScore;
    lastHours = hoursLeft;
    phase = 4;
    notebookOpen = false;
  }

  void nextCase() {
    if (phase != 4) return;
    if (runEnds) {
      over = true;
      return;
    }
    caseNo++;
    _newCase();
    phase = 2;
  }

  String get verdictText {
    final CaseSuspect c = suspects[culprit];
    if (verdictOk) {
      return '${c.name} the ${c.role} gave up ${caseWhats[whatIndex]}. The town sleeps easy tonight.';
    }
    final String who = accused >= 0 ? suspects[accused].name : 'someone';
    return 'You accused $who, but it was ${c.name} the ${c.role}. The culprit slipped away.';
  }

  String get caseIntro {
    switch (caseNo) {
      case 1:
        return 'Marrow Bay is a quiet coastal town, but small crimes keep happening. The only witnesses talk to people who know their lessons.';
      case 2:
        return 'The gulls were barely settled when another crime shook the town. The witnesses are waiting, if you know your lessons.';
      default:
        return 'One more case for the notebook. The whole town is watching, and the witnesses still only talk to the well taught.';
    }
  }

  // ---- movement ----------------------------------------------------------

  bool blockedAt(double x, double y) {
    if (x < 24 || x > caseWorldW - 24 || y < 30 || y > caseWalkMaxY) return true;
    for (final CasePlace p in casePlaces) {
      if (x > p.l - casePlayerR && x < p.r + casePlayerR && y > p.t - casePlayerR && y < p.b + casePlayerR) return true;
    }
    return false;
  }

  @override
  void step(double dt) {
    if (toastT > 0) toastT -= dt;
    moving = false;
    if (over || modal) return;
    const double speed = 190;
    double dx = inputX;
    double dy = inputY;
    final bool manual = dx * dx + dy * dy > 0.01;
    if (manual) {
      hasTarget = false;
      autoLoc = -1;
    } else if (hasTarget) {
      final double ex = tx - px;
      final double ey = ty - py;
      final double d = sqrt(ex * ex + ey * ey);
      if (d < 6) {
        hasTarget = false;
        dx = 0;
        dy = 0;
        if (autoLoc >= 0) {
          _updateDoor();
          if (atDoor == autoLoc) {
            final int loc = autoLoc;
            autoLoc = -1;
            startAsk(loc);
            return;
          }
          autoLoc = -1;
        }
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
            autoLoc = -1;
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
  }

  void _updateDoor() {
    int found = -1;
    for (final CasePlace p in casePlaces) {
      final double ex = px - p.doorX;
      final double ey = py - p.doorY;
      if (ex * ex + ey * ey < 34 * 34) {
        found = p.id;
        break;
      }
    }
    if (found != atDoor) {
      atDoor = found;
      if (found >= 0 && !revealed[found] && toastT <= 0) say(casePlaces[found].blurb, secs: 2.6);
    }
  }

  // ---- camera and taps ---------------------------------------------------

  double zoomFor(Size s) => caseClamp(s.shortestSide / 480.0, 0.6, 1.7);

  Offset cameraFor(Size s) {
    final double z = zoomFor(s);
    final double hw = s.width / (2 * z);
    final double hh = s.height / (2 * z);
    double cx = caseWorldW / 2;
    double cy = caseWorldH / 2;
    if (hw * 2 < caseWorldW) cx = caseClamp(px, hw, caseWorldW - hw);
    if (hh * 2 < caseWorldH) cy = caseClamp(py - 20, hh, caseWorldH - hh);
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
    for (final CasePlace p in casePlaces) {
      if (w.dx > p.l - 8 && w.dx < p.r + 8 && w.dy > p.t - 8 && w.dy < p.b + 8) {
        if (atDoor == p.id) {
          startAsk(p.id);
          return;
        }
        tx = p.doorX;
        ty = p.doorY;
        hasTarget = true;
        autoLoc = p.id;
        stuckT = 0;
        say('Heading to the ${p.name}.', secs: 1.4);
        cues.add('tap');
        return;
      }
    }
    final double gx = caseClamp(w.dx, 24, caseWorldW - 24);
    final double gy = caseClamp(w.dy, 30, caseWalkMaxY);
    if (blockedAt(gx, gy)) return;
    tx = gx;
    ty = gy;
    hasTarget = true;
    autoLoc = -1;
    stuckT = 0;
  }

  // ---- results -----------------------------------------------------------

  @override
  int get finalScore => totalScore;

  @override
  int get xp => stats.baseXp + solved * 10;

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('$hoursLeft h left', Icons.schedule_rounded, const Color(0xFFFFCA28)),
        RealmChip('Clues $cluesFound/$cluesNeeded', Icons.search_rounded, const Color(0xFF4DD0E1)),
        RealmChip('Case $caseNo/$caseMaxCases', Icons.folder_open_rounded, const Color(0xFFFF8A33)),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Cases solved': '$solved',
        'Clues': '$totalClues',
        'Hours left on last case': '$lastHours',
      };
}
