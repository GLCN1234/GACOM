import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';
import 'crossword_bank.dart';
import '../../../../core/services/duel_session.dart';

class CwEntry {
  final int number;
  final bool across;
  final List<int> cells; // r * 5 + c
  final String answer;
  final String clue;
  const CwEntry(this.number, this.across, this.cells, this.answer, this.clue);
}

/// A 5 by 5 "window" mini crossword: three across and three down words of five letters,
/// with the four inner corners blocked.
class CrosswordEngine {
  static const int n = 5;
  static bool isBlock(int r, int c) => r.isOdd && c.isOdd;

  /// Builds a grid from the word bank. Returns six words: across rows 0,2,4 then down cols 0,2,4.
  static List<String>? generate(Random rng, List<String> words, {int tries = 4000}) {
    final Map<String, List<String>> idx = <String, List<String>>{};
    for (final w in words) {
      idx.putIfAbsent('${w[0]}${w[2]}${w[4]}', () => <String>[]).add(w);
    }
    for (int t = 0; t < tries; t++) {
      final String a0 = words[rng.nextInt(words.length)];
      final String a2 = words[rng.nextInt(words.length)];
      if (a0 == a2) continue;
      final List<String> pool = List<String>.from(words)..shuffle(rng);
      for (final a4 in pool) {
        if (a4 == a0 || a4 == a2) continue;
        final List<String>? c0 = idx['${a0[0]}${a2[0]}${a4[0]}'];
        final List<String>? c2 = idx['${a0[2]}${a2[2]}${a4[2]}'];
        final List<String>? c4 = idx['${a0[4]}${a2[4]}${a4[4]}'];
        if (c0 == null || c2 == null || c4 == null) continue;
        for (final d0 in c0) {
          for (final d2 in c2) {
            for (final d4 in c4) {
              final Set<String> all = <String>{a0, a2, a4, d0, d2, d4};
              if (all.length == 6) return <String>[a0, a2, a4, d0, d2, d4];
            }
          }
        }
      }
    }
    return null;
  }

  final List<String> solution = List<String>.filled(25, ''); // '' for blocks
  final List<String> entry = List<String>.filled(25, '');
  final Set<int> wrong = <int>{};
  final List<CwEntry> across = <CwEntry>[];
  final List<CwEntry> down = <CwEntry>[];
  final Map<int, int> numbers = <int, int>{};
  int selR = 0;
  int selC = 0;
  bool selAcross = true;
  int hints = 0;
  int checks = 0;
  bool over = false;
  bool won = false;
  final Stopwatch clock = Stopwatch();

  CrosswordEngine(List<String> six, Map<String, String> clues) {
    final rows = <int>[0, 2, 4];
    for (int i = 0; i < 3; i++) {
      for (int c = 0; c < n; c++) { solution[rows[i] * n + c] = six[i][c]; }
      for (int r = 0; r < n; r++) { solution[r * n + rows[i]] = six[3 + i][r]; }
    }
    numbers[0] = 1;
    numbers[2] = 2;
    numbers[4] = 3;
    numbers[2 * n] = 4;
    numbers[4 * n] = 5;
    across.add(CwEntry(1, true, [0, 1, 2, 3, 4], six[0], clues[six[0]] ?? ''));
    across.add(CwEntry(4, true, [10, 11, 12, 13, 14], six[1], clues[six[1]] ?? ''));
    across.add(CwEntry(5, true, [20, 21, 22, 23, 24], six[2], clues[six[2]] ?? ''));
    down.add(CwEntry(1, false, [0, 5, 10, 15, 20], six[3], clues[six[3]] ?? ''));
    down.add(CwEntry(2, false, [2, 7, 12, 17, 22], six[4], clues[six[4]] ?? ''));
    down.add(CwEntry(3, false, [4, 9, 14, 19, 24], six[5], clues[six[5]] ?? ''));
    clock.start();
  }

  bool inAcross(int r, int c) => !isBlock(r, c) && r.isEven;
  bool inDown(int r, int c) => !isBlock(r, c) && c.isEven;

  CwEntry? currentEntry() {
    final int cell = selR * n + selC;
    final list = selAcross ? across : down;
    for (final e in list) {
      if (e.cells.contains(cell)) return e;
    }
    return null;
  }

  void select(int r, int c) {
    if (isBlock(r, c) || over) return;
    if (r == selR && c == selC) {
      // toggle direction when the cell belongs to both
      if (inAcross(r, c) && inDown(r, c)) { selAcross = !selAcross; }
      return;
    }
    selR = r;
    selC = c;
    if (selAcross && !inAcross(r, c)) { selAcross = false; }
    else if (!selAcross && !inDown(r, c)) { selAcross = true; }
  }

  void _advance(int dir) {
    final e = currentEntry();
    if (e == null) return;
    final int i = e.cells.indexOf(selR * n + selC);
    final int j = i + dir;
    if (j < 0 || j >= e.cells.length) return;
    selR = e.cells[j] ~/ n;
    selC = e.cells[j] % n;
  }

  void type(String letter) {
    if (over || isBlock(selR, selC)) return;
    final int cell = selR * n + selC;
    entry[cell] = letter.toUpperCase();
    wrong.remove(cell);
    _advance(1);
    _checkDone();
  }

  void backspace() {
    if (over || isBlock(selR, selC)) return;
    final int cell = selR * n + selC;
    if (entry[cell].isNotEmpty) {
      entry[cell] = '';
      wrong.remove(cell);
    } else {
      _advance(-1);
      final int c2 = selR * n + selC;
      entry[c2] = '';
      wrong.remove(c2);
    }
  }

  void check() {
    if (over) return;
    checks++;
    wrong.clear();
    for (int i = 0; i < 25; i++) {
      if (solution[i].isNotEmpty && entry[i].isNotEmpty && entry[i] != solution[i]) wrong.add(i);
    }
  }

  void hint() {
    if (over || isBlock(selR, selC)) return;
    final int cell = selR * n + selC;
    if (entry[cell] == solution[cell]) return;
    hints++;
    entry[cell] = solution[cell];
    wrong.remove(cell);
    _checkDone();
  }

  void giveUp() {
    for (int i = 0; i < 25; i++) { entry[i] = solution[i]; }
    wrong.clear();
    over = true;
    won = false;
    clock.stop();
  }

  bool get solved {
    for (int i = 0; i < 25; i++) {
      if (solution[i].isNotEmpty && entry[i] != solution[i]) return false;
    }
    return true;
  }

  void _checkDone() {
    if (solved) {
      over = true;
      won = true;
      clock.stop();
    }
  }

  int get seconds => clock.elapsed.inSeconds;

  int get score => won ? max(100, 1500 - seconds * 3 - hints * 150 - checks * 40) : 0;
}

class MiniCrosswordScreen extends StatefulWidget {
  const MiniCrosswordScreen({super.key});
  @override
  State<MiniCrosswordScreen> createState() => _MiniCrosswordScreenState();
}

class _MiniCrosswordScreenState extends State<MiniCrosswordScreen> {
  final Random _rng = duelRandom();
  late final Map<String, String> _clues;
  late final List<String> _words;
  CrosswordEngine? _e;
  Timer? _timer;
  bool _saved = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _clues = <String, String>{};
    for (final line in crosswordBank) {
      final int p = line.indexOf('|');
      _clues[line.substring(0, p)] = line.substring(p + 1);
    }
    _words = _clues.keys.toList();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    final six = CrosswordEngine.generate(_rng, _words);
    if (six == null) {
      setState(() => _failed = true);
      return;
    }
    _timer?.cancel();
    setState(() {
      _failed = false;
      _e = CrosswordEngine(six, _clues);
      _saved = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _after(CrosswordEngine e) {
    if (e.over && !_saved) {
      _saved = true;
      _timer?.cancel();
      if (e.won) {
        GameScoreService.save(gameName: 'Mini Crossword', score: e.score, won: true);
        SoundService.instance.playWin();
      } else {
        GameScoreService.save(gameName: 'Mini Crossword', score: 0, won: false);
        SoundService.instance.playLose();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'mini_crossword',
      title: 'HOW TO PLAY MINI CROSSWORD',
      steps: const [
        HowToPlayStep(icon: Icons.grid_on_rounded, title: 'Fill the grid', description: 'Tap a square, then type letters with the keyboard at the bottom. The clue for the selected word is shown above the grid.'),
        HowToPlayStep(icon: Icons.swap_horiz_rounded, title: 'Across and down', description: 'Tap the same square twice to switch between the across and down word. Dark squares are blocked.'),
        HowToPlayStep(icon: Icons.lightbulb_rounded, title: 'Get help', description: 'CHECK marks wrong letters in red. HINT reveals the selected letter. Both cost points, so use them wisely.'),
        HowToPlayStep(icon: Icons.timer_rounded, title: 'Speed counts', description: 'Your score starts at 1500 and drops with time, checks and hints. Finish the whole grid to win.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('MINI CROSSWORD')),
        body: e == null
            ? ArcadeStartView(
                icon: Icons.grid_on_rounded,
                title: 'MINI CROSSWORD',
                subtitle: _failed ? 'Could not build a puzzle. Try again.' : 'A fresh 5x5 puzzle every time.',
                buttonLabel: 'NEW PUZZLE',
                onStart: _start,
              )
            : Stack(children: [_game(e), if (e.over) _result(e)]),
      ),
    );
  }

  Widget _game(CrosswordEngine e) {
    final cur = e.currentEntry();
    return LayoutBuilder(builder: (context, cons) {
      double side = min(cons.maxWidth - 32.0, cons.maxHeight - 330.0);
      if (side < 200.0) side = 200.0;
      final double cell = side / 5.0;
      return SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 8),
          Text('TIME ${e.seconds ~/ 60}:${(e.seconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textMuted)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
            child: Text(cur == null ? '' : '${cur.number} ${cur.across ? 'ACROSS' : 'DOWN'}: ${cur.clue}', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: side,
            height: side,
            child: Column(children: [
              for (int r = 0; r < 5; r++)
                Row(children: [for (int c = 0; c < 5; c++) _cell(e, r, c, cell, cur)]),
            ]),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton(onPressed: () { e.check(); SoundService.instance.playTap(); _after(e); }, child: const Text('CHECK')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () { e.hint(); SoundService.instance.playTap(); _after(e); }, child: const Text('HINT')),
            const SizedBox(width: 8),
            TextButton(onPressed: () { e.giveUp(); _after(e); }, child: const Text('GIVE UP', style: TextStyle(color: GacomColors.textMuted))),
          ]),
          const SizedBox(height: 8),
          _keyboard(e),
          const SizedBox(height: 12),
        ]),
      );
    });
  }

  Widget _cell(CrosswordEngine e, int r, int c, double cell, CwEntry? cur) {
    final int i = r * 5 + c;
    if (CrosswordEngine.isBlock(r, c)) {
      return Container(width: cell, height: cell, color: const Color(0xFF05070D));
    }
    final bool selected = r == e.selR && c == e.selC;
    final bool inWord = cur != null && cur.cells.contains(i);
    final bool bad = e.wrong.contains(i);
    final int? number = e.numbers[i];
    return GestureDetector(
      onTap: () {
        e.select(r, c);
        SoundService.instance.playTap();
        setState(() {});
      },
      child: Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          color: selected ? GacomColors.deepOrange.withValues(alpha: 0.45) : (inWord ? GacomColors.deepOrange.withValues(alpha: 0.16) : GacomColors.cardDark),
          border: Border.all(color: GacomColors.border, width: 1),
        ),
        child: Stack(children: [
          if (number != null) Positioned(left: 3, top: 1, child: Text('$number', style: const TextStyle(fontSize: 10, color: GacomColors.textMuted, fontWeight: FontWeight.w700))),
          Center(child: Text(e.entry[i], style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: cell * 0.5, color: bad ? Colors.redAccent : GacomColors.textPrimary))),
        ]),
      ),
    );
  }

  Widget _keyboard(CrosswordEngine e) {
    const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    final double keyW = min(31.0, (MediaQuery.of(context).size.width - 16.0) / 10.0 - 4.0);
    return Column(children: [
      for (int ri = 0; ri < rows.length; ri++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final ch in rows[ri].split(''))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: GestureDetector(
                  onTap: () {
                    e.type(ch);
                    SoundService.instance.playLetterType();
                    _after(e);
                  },
                  child: Container(
                    width: keyW,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(8), border: Border.all(color: GacomColors.border)),
                    child: Text(ch, style: const TextStyle(fontWeight: FontWeight.w800, color: GacomColors.textPrimary)),
                  ),
                ),
              ),
            if (ri == rows.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () { e.backspace(); SoundService.instance.playTap(); _after(e); },
                  child: Container(
                    width: keyW * 1.4,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: GacomColors.border, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.backspace_rounded, size: 18, color: GacomColors.textPrimary),
                  ),
                ),
              ),
          ]),
        ),
    ]);
  }

  Widget _result(CrosswordEngine e) {
    return ArcadeResultOverlay(
      good: e.won,
      title: e.won ? 'SOLVED!' : 'ANSWERS REVEALED',
      detail: e.won ? 'Time ${e.seconds}s, ${e.hints} hints, ${e.checks} checks. Score ${e.score}' : 'Better luck with the next puzzle.',
      onAgain: () {
        setState(() => _e = null);
        _start();
      },
      onExit: () => Navigator.pop(context),
      againLabel: 'NEW PUZZLE',
    );
  }
}
