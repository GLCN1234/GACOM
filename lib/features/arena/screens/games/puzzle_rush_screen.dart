import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../games/chess_rush/chess_rules.dart';
import '../../games/chess_rush/chess_puzzles_data.dart';

class _Puzzle {
  final String fen;
  final List<String> moves; // solver first, then the reply, and so on
  final int rating;
  final String theme;
  const _Puzzle(this.fen, this.moves, this.rating, this.theme);
}

List<_Puzzle> _loadPuzzles() {
  final out = <_Puzzle>[];
  for (final line in kPuzzleData) {
    final p = line.split('|');
    out.add(_Puzzle(p[0], p[1].split(' '), int.parse(p[2]), p[3]));
  }
  return out;
}

/// Easy puzzles first, getting harder. The order within each difficulty
/// band is shuffled with today's date as the seed, so everyone playing
/// on the same (UTC) day gets the same puzzles in the same order.
List<_Puzzle> _dailyOrder(List<_Puzzle> all) {
  final now = DateTime.now().toUtc();
  final rng = Random(now.year * 10000 + now.month * 100 + now.day);
  final tiers = <List<_Puzzle>>[<_Puzzle>[], <_Puzzle>[], <_Puzzle>[], <_Puzzle>[]];
  for (final p in all) {
    final t = p.rating < 900 ? 0 : (p.rating < 1100 ? 1 : (p.rating < 1250 ? 2 : 3));
    tiers[t].add(p);
  }
  final out = <_Puzzle>[];
  for (final t in tiers) {
    t.shuffle(rng);
    out.addAll(t);
  }
  return out;
}

const Set<String> _mateThemes = {'mate1', 'mate2', 'mate3'};

String _themeLabel(String theme) {
  switch (theme) {
    case 'mate1':
      return 'Mate in 1';
    case 'mate2':
      return 'Mate in 2';
    case 'mate3':
      return 'Mate in 3';
    default:
      return 'Win material';
  }
}

const List<String> _glyphs = ['', '\u265F', '\u265E', '\u265D', '\u265C', '\u265B', '\u265A'];

class PuzzleRushScreen extends StatefulWidget {
  const PuzzleRushScreen({super.key});
  @override
  State<PuzzleRushScreen> createState() => _PuzzleRushScreenState();
}

class _PuzzleRushScreenState extends State<PuzzleRushScreen> {
  static const int _runSeconds = 180;

  List<_Puzzle> _queue = <_Puzzle>[];
  int _qi = 0;
  int _phase = 0; // 0 setup, 1 running, 2 over
  int _secondsLeft = _runSeconds;
  int _lives = 3;
  int _solved = 0;
  Timer? _timer;
  _Puzzle? _puz;
  ChessPos? _pos;
  int _idx = 0;
  bool _flipped = false;
  bool _locked = false;
  int _sel = -1;
  List<ChessMove> _selMoves = <ChessMove>[];
  int _lastFrom = -1;
  int _lastTo = -1;
  int _hintFrom = -1;
  int _hintTo = -1;
  String _msg = '';
  String _endReason = '';
  int _epoch = 0;
  bool _saved = false;

  bool _dead(int epoch) => !mounted || epoch != _epoch || _phase != 1;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _epoch++;
      _queue = _dailyOrder(_loadPuzzles());
      _qi = 0;
      _lives = 3;
      _solved = 0;
      _secondsLeft = _runSeconds;
      _saved = false;
      _endReason = '';
      _phase = 1;
      _loadPuzzle();
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _phase != 1) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) { _finish('TIME UP'); }
    });
  }

  void _toSetup() {
    _timer?.cancel();
    setState(() {
      _epoch++;
      _phase = 0;
    });
  }

  void _loadPuzzle() {
    if (_qi >= _queue.length) {
      _queue.shuffle(Random());
      _qi = 0;
    }
    final p = _queue[_qi];
    final pos = ChessPos.fromFen(p.fen);
    _puz = p;
    _pos = pos;
    _idx = 0;
    _flipped = pos.turn == 1;
    _sel = -1;
    _selMoves = <ChessMove>[];
    _lastFrom = -1;
    _lastTo = -1;
    _hintFrom = -1;
    _hintTo = -1;
    _locked = false;
    _msg = '${pos.turn == 0 ? 'White' : 'Black'} to move';
  }

  void _finish(String reason) {
    _timer?.cancel();
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: 'Chess Puzzle Rush', score: _solved);
    }
    if (_solved >= 5) { SoundService.instance.playWin(); }
    setState(() {
      _epoch++;
      _phase = 2;
      _endReason = reason;
    });
  }

  void _onSquare(int idx) {
    if (_phase != 1 || _locked) return;
    final pos = _pos;
    if (pos == null) return;
    if (_sel != -1) {
      for (final m in _selMoves) {
        if (m.to == idx && (m.promo == 0 || m.promo == kQueen)) {
          _attempt(m);
          return;
        }
      }
    }
    final p = pos.sq[idx];
    if (p != 0 && pieceColor(p) == pos.turn) {
      final moves = <ChessMove>[for (final m in pos.legalMoves()) if (m.from == idx) m];
      setState(() {
        _sel = idx;
        _selMoves = moves;
      });
    } else {
      setState(() {
        _sel = -1;
        _selMoves = <ChessMove>[];
      });
    }
  }

  Future<void> _attempt(ChessMove m) async {
    final epoch = _epoch;
    final puz = _puz!;
    final pos = _pos!;
    final expected = puz.moves[_idx];
    final next = pos.apply(m);
    bool ok = m.uci == expected;
    // Any move that gives checkmate also solves a mating puzzle.
    if (!ok && _mateThemes.contains(puz.theme) && next.isCheckmate) { ok = true; }
    if (ok) {
      setState(() {
        _pos = next;
        _lastFrom = m.from;
        _lastTo = m.to;
        _sel = -1;
        _selMoves = <ChessMove>[];
        _idx++;
        _locked = true;
      });
      SoundService.instance.playPieceMove();
      if (_idx >= puz.moves.length || next.isCheckmate) {
        await _solvedPuzzle(epoch);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 420));
      if (_dead(epoch)) return;
      final reply = _pos!.moveFromUci(puz.moves[_idx]);
      if (reply == null) {
        await _solvedPuzzle(epoch);
        return;
      }
      final after = _pos!.apply(reply);
      setState(() {
        _pos = after;
        _lastFrom = reply.from;
        _lastTo = reply.to;
        _idx++;
        _locked = false;
      });
      SoundService.instance.playPieceMove();
      if (_idx >= puz.moves.length) { await _solvedPuzzle(epoch); }
    } else {
      SoundService.instance.playWrong();
      final exp = pos.moveFromUci(expected);
      setState(() {
        _lives--;
        _locked = true;
        _sel = -1;
        _selMoves = <ChessMove>[];
        _msg = 'Not quite - the best move was...';
        if (exp != null) {
          _hintFrom = exp.from;
          _hintTo = exp.to;
        }
      });
      await Future.delayed(const Duration(milliseconds: 1300));
      if (_dead(epoch)) return;
      if (_lives <= 0) {
        _finish('OUT OF LIVES');
        return;
      }
      setState(() {
        _qi++;
        _loadPuzzle();
      });
    }
  }

  Future<void> _solvedPuzzle(int epoch) async {
    SoundService.instance.playCorrect();
    setState(() {
      _solved++;
      _locked = true;
      _msg = 'Correct!';
    });
    await Future.delayed(const Duration(milliseconds: 550));
    if (_dead(epoch)) return;
    setState(() {
      _qi++;
      _loadPuzzle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return HowToPlayOverlay(
      gameKey: 'puzzle_rush',
      title: 'HOW TO PLAY PUZZLE RUSH',
      steps: const [
        HowToPlayStep(icon: Icons.psychology_rounded, title: 'Find the best move', description: 'Each puzzle is a tactic for the side to move. Look for checkmates and ways to win material.'),
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Tap to move', description: 'Tap one of your pieces, then tap the square to move it to. Some puzzles continue after the opponent replies.'),
        HowToPlayStep(icon: Icons.timer_rounded, title: '3 minutes, 3 strikes', description: 'Solve as many as you can before time runs out. Each wrong move costs a life, and the puzzles get harder as you go.'),
        HowToPlayStep(icon: Icons.today_rounded, title: 'A new set every day', description: 'Everyone gets the same puzzles in the same order each day, so you can compare scores on the leaderboard.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('PUZZLE RUSH')),
        body: _phase == 0 ? _setup() : Stack(children: [_game(), if (_phase == 2) _result()]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.bolt_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('CHESS PUZZLE RUSH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Solve as many chess tactics as you can in 3 minutes. Three wrong moves and the run ends.', textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 8),
        const Text('Today\'s puzzle set is the same for everyone.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: _start,
            child: const Text('START RUSH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ),
  );

  String _clock() {
    final s = max(0, _secondsLeft);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _game() {
    final pos = _pos;
    final puz = _puz;
    if (pos == null || puz == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, cons) {
      final side = max(120.0, min(cons.maxWidth - 16, cons.maxHeight - 170));
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text(_clock(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: _secondsLeft <= 20 ? const Color(0xFFEF5350) : GacomColors.textPrimary)),
            const Spacer(),
            for (int i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(Icons.favorite_rounded, size: 20, color: i < _lives ? const Color(0xFFEF5350) : GacomColors.border),
              ),
            const Spacer(),
            Text('Solved $_solved', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.deepOrange)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: LinearProgressIndicator(
            value: max(0, _secondsLeft) / _runSeconds,
            minHeight: 4,
            backgroundColor: GacomColors.cardDark,
            valueColor: const AlwaysStoppedAnimation<Color>(GacomColors.deepOrange),
          ),
        ),
        SizedBox(width: side, height: side, child: _board(pos, side)),
        const SizedBox(height: 10),
        Text('${_themeLabel(puz.theme)}  -  $_msg', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
      ]);
    });
  }

  Widget _board(ChessPos pos, double side) {
    final cell = side / 8;
    return Column(children: [
      for (int dr = 0; dr < 8; dr++)
        Row(children: [
          for (int dc = 0; dc < 8; dc++) _square(pos, dr, dc, cell),
        ]),
    ]);
  }

  Widget _square(ChessPos pos, int dr, int dc, double cell) {
    final r = _flipped ? 7 - dr : dr;
    final c = _flipped ? 7 - dc : dc;
    final idx = r * 8 + c;
    final light = (r + c) % 2 == 0;
    final piece = pos.sq[idx];
    final isDest = _selMoves.any((m) => m.to == idx);
    return GestureDetector(
      onTap: () => _onSquare(idx),
      child: Container(
        width: cell,
        height: cell,
        color: light ? const Color(0xFFEEEED2) : const Color(0xFF769656),
        child: Stack(alignment: Alignment.center, children: [
          if (idx == _lastFrom || idx == _lastTo) Container(color: const Color(0x66FFEB3B)),
          if (idx == _sel) Container(color: const Color(0x99FFC107)),
          if (idx == _hintFrom || idx == _hintTo) Container(color: const Color(0x99EF5350)),
          if (piece != 0)
            Text(
              '${_glyphs[pieceType(piece)]}\uFE0E',
              style: TextStyle(
                fontSize: cell * 0.78,
                height: 1.0,
                color: pieceColor(piece) == 0 ? const Color(0xFFFAFAFA) : const Color(0xFF1A1A1A),
                shadows: pieceColor(piece) == 0
                    ? const [Shadow(color: Colors.black, blurRadius: 3), Shadow(color: Colors.black, blurRadius: 1)]
                    : const [Shadow(color: Color(0x88FFFFFF), blurRadius: 2)],
              ),
            ),
          if (isDest)
            Container(
              width: piece != 0 ? cell * 0.9 : cell * 0.28,
              height: piece != 0 ? cell * 0.9 : cell * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: piece != 0 ? Colors.transparent : const Color(0x8826A69A),
                border: piece != 0 ? Border.all(color: const Color(0xAA26A69A), width: 3) : null,
              ),
            ),
        ]),
      ),
    );
  }

  Widget _result() => Container(
    color: Colors.black.withValues(alpha: 0.82),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 52),
          const SizedBox(height: 12),
          Text(_endReason, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text('You solved $_solved puzzle${_solved == 1 ? '' : 's'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _toSetup,
              child: const Text('TRY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    ),
  );
}
