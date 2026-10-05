import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';

class SudokuPuzzle {
  final List<List<int>> given;
  final List<List<int>> solution;
  const SudokuPuzzle(this.given, this.solution);
}

class SudokuEngine {
  static int _popcount(int v) {
    int n = 0;
    int x = v;
    while (x != 0) {
      n += x & 1;
      x >>= 1;
    }
    return n;
  }

  /// A random fully solved grid.
  static List<List<int>> randomSolution(Random rng) {
    for (int attempt = 0; attempt < 50; attempt++) {
      final g = List.generate(9, (_) => List<int>.filled(9, 0));
      final rows = List<int>.filled(9, 0);
      final cols = List<int>.filled(9, 0);
      final boxes = List<int>.filled(9, 0);
      int nodes = 0;
      bool fill(int pos) {
        if (pos == 81) return true;
        if (++nodes > 20000) return false;
        final r = pos ~/ 9;
        final c = pos % 9;
        final b = (r ~/ 3) * 3 + c ~/ 3;
        final avail = ~(rows[r] | cols[c] | boxes[b]) & 0x3FE;
        final cands = <int>[for (int v = 1; v <= 9; v++) if (((avail >> v) & 1) == 1) v];
        cands.shuffle(rng);
        for (final v in cands) {
          final bit = 1 << v;
          g[r][c] = v;
          rows[r] |= bit;
          cols[c] |= bit;
          boxes[b] |= bit;
          if (fill(pos + 1)) return true;
          g[r][c] = 0;
          rows[r] &= ~bit;
          cols[c] &= ~bit;
          boxes[b] &= ~bit;
        }
        return false;
      }
      if (fill(0)) return g;
    }
    throw StateError('could not build a sudoku grid');
  }

  /// Counts solutions of [grid], stopping once [limit] is reached.
  static int countSolutions(List<List<int>> grid, int limit) {
    final g = [for (final row in grid) List<int>.from(row)];
    final rows = List<int>.filled(9, 0);
    final cols = List<int>.filled(9, 0);
    final boxes = List<int>.filled(9, 0);
    int empties = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        final v = g[r][c];
        if (v == 0) {
          empties++;
        } else {
          final bit = 1 << v;
          rows[r] |= bit;
          cols[c] |= bit;
          boxes[(r ~/ 3) * 3 + c ~/ 3] |= bit;
        }
      }
    }
    int count = 0;
    void solve(int remaining) {
      if (count >= limit) return;
      if (remaining == 0) {
        count++;
        return;
      }
      int bestR = -1;
      int bestC = -1;
      int bestAvail = 0;
      int bestN = 10;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (g[r][c] != 0) continue;
          final avail = ~(rows[r] | cols[c] | boxes[(r ~/ 3) * 3 + c ~/ 3]) & 0x3FE;
          final n = _popcount(avail);
          if (n < bestN) {
            bestN = n;
            bestR = r;
            bestC = c;
            bestAvail = avail;
            if (n == 0) return;
          }
        }
      }
      final b = (bestR ~/ 3) * 3 + bestC ~/ 3;
      for (int v = 1; v <= 9; v++) {
        if (((bestAvail >> v) & 1) == 0) continue;
        final bit = 1 << v;
        g[bestR][bestC] = v;
        rows[bestR] |= bit;
        cols[bestC] |= bit;
        boxes[b] |= bit;
        solve(remaining - 1);
        g[bestR][bestC] = 0;
        rows[bestR] &= ~bit;
        cols[bestC] &= ~bit;
        boxes[b] &= ~bit;
        if (count >= limit) return;
      }
    }
    solve(empties);
    return count;
  }

  /// A puzzle with exactly one solution, with about [targetClues] givens.
  static SudokuPuzzle generate(int targetClues, Random rng) {
    final solution = randomSolution(rng);
    final puzzle = [for (final row in solution) List<int>.from(row)];
    final order = List<int>.generate(81, (i) => i)..shuffle(rng);
    int clues = 81;
    for (final idx in order) {
      if (clues <= targetClues) break;
      final r = idx ~/ 9;
      final c = idx % 9;
      final backup = puzzle[r][c];
      puzzle[r][c] = 0;
      if (countSolutions(puzzle, 2) == 1) {
        clues--;
      } else {
        puzzle[r][c] = backup;
      }
    }
    return SudokuPuzzle(puzzle, solution);
  }
}

class _Snap {
  final List<List<int>> cur;
  final List<List<int>> notes;
  _Snap(this.cur, this.notes);
}

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});
  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  static const int _maxMistakes = 5;
  static const List<String> _levelNames = ['Easy', 'Medium', 'Hard'];
  static const List<int> _levelClues = [40, 32, 26];
  static const List<int> _levelBase = [100, 200, 300];

  final Random _rng = Random();
  SudokuPuzzle? _pz;
  List<List<int>> _cur = <List<int>>[];
  List<List<int>> _notes = <List<int>>[];
  final List<_Snap> _undo = <_Snap>[];
  int _level = 1;
  int _selR = -1;
  int _selC = -1;
  bool _noteMode = false;
  int _mistakes = 0;
  int _hints = 0;
  int _seconds = 0;
  bool _over = false;
  bool _won = false;
  bool _saved = false;
  bool _generating = false;
  int _flash = -1;
  int _epoch = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _newGame() async {
    _timer?.cancel();
    final epoch = ++_epoch;
    setState(() {
      _generating = true;
      _pz = null;
    });
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted || epoch != _epoch) return;
    final pz = SudokuEngine.generate(_levelClues[_level], _rng);
    setState(() {
      _pz = pz;
      _cur = [for (final row in pz.given) List<int>.from(row)];
      _notes = List.generate(9, (_) => List<int>.filled(9, 0));
      _undo.clear();
      _selR = -1;
      _selC = -1;
      _noteMode = false;
      _mistakes = 0;
      _hints = 0;
      _seconds = 0;
      _over = false;
      _won = false;
      _saved = false;
      _generating = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _over) {
        t.cancel();
        return;
      }
      setState(() => _seconds++);
    });
  }

  void _toSetup() {
    _timer?.cancel();
    setState(() {
      _epoch++;
      _pz = null;
      _generating = false;
    });
  }

  void _pushUndo() {
    _undo.add(_Snap([for (final r in _cur) List<int>.from(r)], [for (final r in _notes) List<int>.from(r)]));
    if (_undo.length > 60) { _undo.removeAt(0); }
  }

  bool _isGiven(int r, int c) => _pz!.given[r][c] != 0;

  void _clearPeerNotes(int r, int c, int v) {
    final bit = 1 << v;
    for (int i = 0; i < 9; i++) {
      _notes[r][i] &= ~bit;
      _notes[i][c] &= ~bit;
    }
    final br = (r ~/ 3) * 3;
    final bc = (c ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) { _notes[br + i][bc + j] &= ~bit; }
    }
  }

  void _checkWin() {
    final pz = _pz!;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_cur[r][c] != pz.solution[r][c]) return;
      }
    }
    _timer?.cancel();
    _over = true;
    _won = true;
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: 'Sudoku', score: _score(), won: true);
    }
    SoundService.instance.playWin();
  }

  int _score() {
    final int timeBonus = max(0, 600 - _seconds) ~/ 2;
    final int raw = _levelBase[_level] + timeBonus - _mistakes * 20 - _hints * 25;
    return max(10, raw);
  }

  void _input(int v) {
    if (_over || _selR < 0) return;
    final r = _selR;
    final c = _selC;
    if (_isGiven(r, c) || _cur[r][c] != 0) return;
    if (_noteMode) {
      setState(() {
        _pushUndo();
        _notes[r][c] ^= (1 << v);
      });
      return;
    }
    if (_pz!.solution[r][c] == v) {
      setState(() {
        _pushUndo();
        _cur[r][c] = v;
        _notes[r][c] = 0;
        _clearPeerNotes(r, c, v);
        _checkWin();
      });
      SoundService.instance.playCorrect();
    } else {
      setState(() {
        _mistakes++;
        _flash = r * 9 + c;
        if (_mistakes >= _maxMistakes) {
          _over = true;
          _won = false;
          _timer?.cancel();
          if (!_saved) {
            _saved = true;
            GameScoreService.save(gameName: 'Sudoku', score: 0, won: false);
          }
        }
      });
      SoundService.instance.playWrong();
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) { setState(() => _flash = -1); }
      });
    }
  }

  void _erase() {
    if (_over || _selR < 0) return;
    if (_isGiven(_selR, _selC) || _cur[_selR][_selC] != 0) return;
    setState(() {
      _pushUndo();
      _notes[_selR][_selC] = 0;
    });
  }

  void _undoMove() {
    if (_over || _undo.isEmpty) return;
    final s = _undo.removeLast();
    setState(() {
      _cur = s.cur;
      _notes = s.notes;
    });
  }

  void _hint() {
    if (_over || _pz == null) return;
    int r = _selR;
    int c = _selC;
    if (r < 0 || _cur[r][c] != 0) {
      r = -1;
      for (int i = 0; i < 81 && r < 0; i++) {
        if (_cur[i ~/ 9][i % 9] == 0) {
          r = i ~/ 9;
          c = i % 9;
        }
      }
      if (r < 0) return;
    }
    final v = _pz!.solution[r][c];
    setState(() {
      _pushUndo();
      _hints++;
      _selR = r;
      _selC = c;
      _cur[r][c] = v;
      _notes[r][c] = 0;
      _clearPeerNotes(r, c, v);
      _checkWin();
    });
    SoundService.instance.playCorrect();
  }

  int _digitCount(int v) {
    int n = 0;
    for (final row in _cur) {
      for (final x in row) {
        if (x == v) { n++; }
      }
    }
    return n;
  }

  String _clock() => '${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return HowToPlayOverlay(
      gameKey: 'sudoku',
      title: 'HOW TO PLAY SUDOKU',
      steps: const [
        HowToPlayStep(icon: Icons.grid_view_rounded, title: 'Fill the grid', description: 'Every row, every column, and every 3 by 3 box must contain the numbers 1 to 9 exactly once.'),
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Tap a square, then a number', description: 'Select an empty square and tap a number below. A wrong number costs a mistake, and 5 mistakes end the game.'),
        HowToPlayStep(icon: Icons.edit_rounded, title: 'Use notes', description: 'Turn on NOTES to jot small candidate numbers in a square without committing to them.'),
        HowToPlayStep(icon: Icons.lightbulb_rounded, title: 'Stuck?', description: 'HINT fills in one square for you, at a small cost to your score. UNDO takes back your last move.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('SUDOKU')),
        body: _pz == null ? _setup() : Stack(children: [_game(), if (_over) _result()]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: _generating
          ? const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: GacomColors.deepOrange),
              SizedBox(height: 14),
              Text('Building a puzzle...', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            ])
          : Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.grid_view_rounded, color: GacomColors.deepOrange, size: 54),
              const SizedBox(height: 14),
              const Text('SUDOKU', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Every puzzle has exactly one solution', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
              const SizedBox(height: 24),
              const Text('DIFFICULTY', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: GestureDetector(
                      onTap: () => setState(() => _level = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: _level == i ? GacomColors.deepOrange.withValues(alpha: 0.18) : GacomColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _level == i ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
                        ),
                        child: Text(_levelNames[i], style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _level == i ? GacomColors.deepOrange : GacomColors.textPrimary)),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                  onPressed: _newGame,
                  child: const Text('START', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
    ),
  );

  Widget _cell(int r, int c, double cell) {
    final pz = _pz!;
    final given = pz.given[r][c] != 0;
    final v = _cur[r][c];
    final selected = r == _selR && c == _selC;
    final sv = _selR >= 0 ? _cur[_selR][_selC] : 0;
    final peer = _selR >= 0 && !selected && (r == _selR || c == _selC || ((r ~/ 3 == _selR ~/ 3) && (c ~/ 3 == _selC ~/ 3)));
    final same = sv != 0 && v == sv && !selected;
    Color bg = GacomColors.cardDark;
    if (peer) { bg = const Color(0xFF232733); }
    if (same) { bg = const Color(0xFF3A2A1E); }
    if (selected) { bg = const Color(0xFF4A3220); }
    if (_flash == r * 9 + c) { bg = const Color(0xFF5A1F1F); }
    final thick = Border(
      top: BorderSide(color: r % 3 == 0 ? Colors.white54 : GacomColors.border, width: r % 3 == 0 ? 1.6 : 0.6),
      left: BorderSide(color: c % 3 == 0 ? Colors.white54 : GacomColors.border, width: c % 3 == 0 ? 1.6 : 0.6),
      right: BorderSide(color: c == 8 ? Colors.white54 : Colors.transparent, width: c == 8 ? 1.6 : 0),
      bottom: BorderSide(color: r == 8 ? Colors.white54 : Colors.transparent, width: r == 8 ? 1.6 : 0),
    );
    Widget content;
    if (v != 0) {
      content = Text('$v', style: TextStyle(fontSize: cell * 0.55, fontWeight: given ? FontWeight.w800 : FontWeight.w600, color: given ? Colors.white : const Color(0xFF4FC3F7)));
    } else if (_notes[r][c] != 0) {
      content = Padding(
        padding: const EdgeInsets.all(1),
        child: Column(children: [
          for (int i = 0; i < 3; i++)
            Expanded(
              child: Row(children: [
                for (int j = 0; j < 3; j++)
                  Expanded(
                    child: Center(
                      child: Text(((_notes[r][c] >> (i * 3 + j + 1)) & 1) == 1 ? '${i * 3 + j + 1}' : '', style: TextStyle(fontSize: cell * 0.2, color: GacomColors.textMuted, height: 1.0)),
                    ),
                  ),
              ]),
            ),
        ]),
      );
    } else {
      content = const SizedBox.shrink();
    }
    return GestureDetector(
      onTap: () => setState(() {
        _selR = r;
        _selC = c;
      }),
      child: Container(width: cell, height: cell, decoration: BoxDecoration(color: bg, border: thick), child: Center(child: content)),
    );
  }

  Widget _pad(String label, VoidCallback? onTap, {bool active = false}) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: active ? GacomColors.deepOrange.withValues(alpha: 0.2) : GacomColors.cardDark,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: active ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: onTap == null ? GacomColors.textMuted : (active ? GacomColors.deepOrange : GacomColors.textPrimary))),
    ),
  );

  Widget _game() {
    return LayoutBuilder(builder: (context, cons) {
      final double side = max(180.0, min(cons.maxWidth - 24, cons.maxHeight - 250));
      final cell = side / 9;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_levelNames[_level].toUpperCase(), style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
            Text('Mistakes $_mistakes/$_maxMistakes', style: TextStyle(color: _mistakes >= 3 ? const Color(0xFFEF5350) : GacomColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(_clock(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: side,
            height: side,
            child: Column(children: [
              for (int r = 0; r < 9; r++) Row(children: [for (int c = 0; c < 9; c++) _cell(r, c, cell)]),
            ]),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (int v = 1; v <= 9; v++)
              GestureDetector(
                onTap: _digitCount(v) >= 9 ? null : () => _input(v),
                child: Container(
                  width: min(36.0, (cons.maxWidth - 24 - 48) / 9 + 4),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: GacomColors.border, width: 1.5),
                  ),
                  child: Text('$v', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: _digitCount(v) >= 9 ? GacomColors.border : GacomColors.textPrimary)),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _pad(_noteMode ? 'NOTES: ON' : 'NOTES: OFF', () => setState(() => _noteMode = !_noteMode), active: _noteMode),
            _pad('ERASE NOTES', _erase),
            _pad('UNDO', _undo.isEmpty ? null : _undoMove),
            _pad('HINT', _hint),
          ]),
        ]),
      );
    });
  }

  Widget _result() => Container(
    color: Colors.black.withValues(alpha: 0.82),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: _won ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
          const SizedBox(height: 12),
          Text(_won ? 'SOLVED!' : 'TOO MANY MISTAKES', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text(_won ? 'Score ${_score()}  -  ${_clock()}  -  $_mistakes mistakes, $_hints hints' : 'Better luck on the next one', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _toSetup,
              child: const Text('NEW PUZZLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    ),
  );
}
