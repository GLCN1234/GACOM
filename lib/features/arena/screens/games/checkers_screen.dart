import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../../../core/services/duel_session.dart';

/// One full move: a single step, or a whole chain of jumps.
class CMove {
  final int fr;
  final int fc;
  final List<List<int>> path; // landing squares, in order
  final List<List<int>> caps; // captured squares, one per landing (empty for a step)
  const CMove(this.fr, this.fc, this.path, this.caps);
  int get tr => path.last[0];
  int get tc => path.last[1];
}

/// Board codes: 0 empty, 1 human man, 2 AI man, 3 human king, 4 AI king.
/// The human plays from the bottom and moves up the board.
class CState {
  List<List<int>> b;
  int turn; // 1 = human, 2 = AI
  int noProgress;
  CState(this.b, this.turn, this.noProgress);
  CState.initial()
      : b = _initialBoard(),
        turn = 1,
        noProgress = 0;

  CState clone() => CState([for (final row in b) List<int>.from(row)], turn, noProgress);

  static List<List<int>> _initialBoard() {
    final b = List.generate(8, (_) => List<int>.filled(8, 0));
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c) % 2 == 1) { b[r][c] = 2; }
      }
    }
    for (int r = 5; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        if ((r + c) % 2 == 1) { b[r][c] = 1; }
      }
    }
    return b;
  }
}

class Chk {
  static int owner(int p) => p == 0 ? 0 : (p % 2 == 1 ? 1 : 2);
  static bool isKing(int p) => p >= 3;
  static bool _in(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  /// All legal moves. If any capture exists, only captures are legal.
  static List<CMove> legalMoves(CState s) {
    final jumps = <CMove>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = s.b[r][c];
        if (owner(p) == s.turn) { _jumpsFrom(s.b, r, c, p, jumps); }
      }
    }
    if (jumps.isNotEmpty) return jumps;
    final steps = <CMove>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = s.b[r][c];
        if (owner(p) != s.turn) continue;
        final dirs = isKing(p) ? [-1, 1] : (s.turn == 1 ? [-1] : [1]);
        for (final dr in dirs) {
          for (final dc in [-1, 1]) {
            final nr = r + dr;
            final nc = c + dc;
            if (_in(nr, nc) && s.b[nr][nc] == 0) {
              steps.add(CMove(r, c, [[nr, nc]], <List<int>>[]));
            }
          }
        }
      }
    }
    return steps;
  }

  static void _jumpsFrom(List<List<int>> b, int r0, int c0, int p, List<CMove> out) {
    final me = owner(p);
    final path = <List<int>>[];
    final caps = <List<int>>[];
    b[r0][c0] = 0; // the moving piece is "in hand" while we search
    void record() {
      out.add(CMove(r0, c0, [for (final x in path) List<int>.from(x)], [for (final x in caps) List<int>.from(x)]));
    }
    void dfs(int r, int c, bool king) {
      bool any = false;
      final dirs = king ? [-1, 1] : (me == 1 ? [-1] : [1]);
      for (final dr in dirs) {
        for (final dc in [-1, 1]) {
          final mr = r + dr;
          final mc = c + dc;
          final lr = r + 2 * dr;
          final lc = c + 2 * dc;
          if (!_in(lr, lc)) continue;
          final mp = b[mr][mc];
          if (mp == 0 || owner(mp) == me || b[lr][lc] != 0) continue;
          any = true;
          b[mr][mc] = 0;
          path.add([lr, lc]);
          caps.add([mr, mc]);
          final promoted = !king && ((me == 1 && lr == 0) || (me == 2 && lr == 7));
          if (promoted) {
            record(); // becoming a king ends the move
          } else {
            dfs(lr, lc, king);
          }
          path.removeLast();
          caps.removeLast();
          b[mr][mc] = mp;
        }
      }
      if (!any && path.isNotEmpty) { record(); }
    }
    dfs(r0, c0, isKing(p));
    b[r0][c0] = p;
  }

  static void apply(CState s, CMove m) {
    final p = s.b[m.fr][m.fc];
    s.b[m.fr][m.fc] = 0;
    for (final c in m.caps) { s.b[c[0]][c[1]] = 0; }
    final end = m.path.last;
    int np = p;
    if (!isKing(p)) {
      if (owner(p) == 1 && end[0] == 0) { np = 3; }
      if (owner(p) == 2 && end[0] == 7) { np = 4; }
    }
    s.b[end[0]][end[1]] = np;
    s.noProgress = (m.caps.isNotEmpty || !isKing(p)) ? 0 : s.noProgress + 1;
    s.turn = 3 - s.turn;
  }

  /// Score from the AI's (player 2) point of view.
  static double eval(CState s) {
    double v = 0;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = s.b[r][c];
        if (p == 0) continue;
        double val = isKing(p) ? 160 : 100;
        if (!isKing(p)) {
          final adv = owner(p) == 2 ? r : 7 - r;
          val += adv * 3;
          if (owner(p) == 2 && r == 0) { val += 6; }
          if (owner(p) == 1 && r == 7) { val += 6; }
        }
        if (c >= 2 && c <= 5 && r >= 2 && r <= 5) { val += 3; }
        v += owner(p) == 2 ? val : -val;
      }
    }
    return v;
  }

  static double _search(CState s, int depth, double alpha, double beta) {
    final moves = legalMoves(s);
    if (moves.isEmpty) return s.turn == 2 ? -10000.0 - depth : 10000.0 + depth;
    if (s.noProgress >= 80) return 0;
    if (depth == 0) return eval(s);
    if (s.turn == 2) {
      double best = -1e9;
      for (final m in moves) {
        final c = s.clone();
        apply(c, m);
        final v = _search(c, depth - 1, alpha, beta);
        if (v > best) { best = v; }
        if (best > alpha) { alpha = best; }
        if (alpha >= beta) break;
      }
      return best;
    } else {
      double best = 1e9;
      for (final m in moves) {
        final c = s.clone();
        apply(c, m);
        final v = _search(c, depth - 1, alpha, beta);
        if (v < best) { best = v; }
        if (best < beta) { beta = best; }
        if (alpha >= beta) break;
      }
      return best;
    }
  }

  /// Best move for the AI. Easy mixes in random moves.
  static CMove bestMove(CState s, int depth, Random rng) {
    final moves = legalMoves(s);
    moves.shuffle(rng);
    if (depth <= 2 && rng.nextDouble() < 0.35) return moves.first;
    CMove best = moves.first;
    double bestV = -1e9;
    for (final m in moves) {
      final c = s.clone();
      apply(c, m);
      final v = _search(c, depth - 1, -1e9, 1e9);
      if (v > bestV) {
        bestV = v;
        best = m;
      }
    }
    return best;
  }
}

class CheckersScreen extends StatefulWidget {
  const CheckersScreen({super.key});
  @override
  State<CheckersScreen> createState() => _CheckersScreenState();
}

class _CheckersScreenState extends State<CheckersScreen> {
  CState _s = CState.initial();
  List<List<int>> _disp = [for (final r in CState.initial().b) List<int>.from(r)];
  bool _started = false;
  int _depth = 4;
  bool _busy = false;
  bool _over = false;
  bool _saved = false;
  int _winner = 0; // 0 draw, 1 human, 2 AI
  int _humanCaps = 0;
  int _epoch = 0;
  List<int>? _sel;
  String _msg = '';
  final Random _rng = duelRandom();

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  void _start() {
    setState(() {
      _epoch++;
      _s = CState.initial();
      _disp = [for (final r in _s.b) List<int>.from(r)];
      _started = true;
      _busy = false;
      _over = false;
      _saved = false;
      _winner = 0;
      _humanCaps = 0;
      _sel = null;
      _msg = 'Your move - tap a piece';
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _started = false;
      _busy = false;
      _over = false;
      _sel = null;
    });
  }

  void _onSquare(int r, int c) {
    if (_busy || _over || _s.turn != 1) return;
    final moves = Chk.legalMoves(_s);
    if (moves.isEmpty) return;
    final sel = _sel;
    if (sel != null) {
      for (final m in moves) {
        if (m.fr == sel[0] && m.fc == sel[1] && m.tr == r && m.tc == c) {
          _play(m);
          return;
        }
      }
    }
    final p = _s.b[r][c];
    if (Chk.owner(p) == 1) {
      final canMove = moves.any((m) => m.fr == r && m.fc == c);
      if (canMove) {
        setState(() {
          _sel = [r, c];
          _msg = moves.first.caps.isNotEmpty ? 'Capture is mandatory' : '';
        });
      } else {
        setState(() {
          _sel = null;
          _msg = moves.first.caps.isNotEmpty ? 'You must capture with another piece' : 'That piece cannot move';
        });
      }
    } else {
      setState(() => _sel = null);
    }
  }

  Future<void> _play(CMove m) async {
    final epoch = _epoch;
    final mover = _s.turn;
    final next = _s.clone();
    Chk.apply(next, m);
    setState(() {
      _busy = true;
      _sel = null;
      _msg = '';
    });
    final piece = _disp[m.fr][m.fc];
    int cr = m.fr;
    int cc = m.fc;
    for (int i = 0; i < m.path.length; i++) {
      await Future.delayed(const Duration(milliseconds: 230));
      if (_dead(epoch)) return;
      final land = m.path[i];
      setState(() {
        _disp[cr][cc] = 0;
        if (m.caps.isNotEmpty) { _disp[m.caps[i][0]][m.caps[i][1]] = 0; }
        _disp[land[0]][land[1]] = piece;
      });
      cr = land[0];
      cc = land[1];
      if (m.caps.isNotEmpty) {
        SoundService.instance.playPieceCapture();
      } else {
        SoundService.instance.playPieceMove();
      }
    }
    if (mover == 1) { _humanCaps += m.caps.length; }
    setState(() {
      _s = next;
      _disp = [for (final row in next.b) List<int>.from(row)];
    });
    _afterMove(epoch);
  }

  void _afterMove(int epoch) {
    if (_dead(epoch)) return;
    final moves = Chk.legalMoves(_s);
    if (moves.isEmpty) {
      _finish(3 - _s.turn);
      return;
    }
    if (_s.noProgress >= 80) {
      _finish(0);
      return;
    }
    setState(() {
      _busy = false;
      _msg = _s.turn == 1 ? (moves.first.caps.isNotEmpty ? 'Your move - you must capture' : 'Your move') : '';
    });
    if (_s.turn == 2) { _aiTurn(); }
  }

  Future<void> _aiTurn() async {
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _msg = 'AI is thinking...';
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (_dead(epoch)) return;
    final m = Chk.bestMove(_s, _depth, _rng);
    await _play(m);
  }

  void _finish(int winner) {
    final bool? won = winner == 1 ? true : (winner == 2 ? false : null);
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: 'Checkers', score: _humanCaps * 10 + (winner == 1 ? 50 : 0), won: won);
    }
    if (won == true) {
      SoundService.instance.playWin();
    } else if (won == false) {
      SoundService.instance.playLose();
    }
    setState(() {
      _over = true;
      _busy = false;
      _winner = winner;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HowToPlayOverlay(
      gameKey: 'checkers',
      title: 'HOW TO PLAY CHECKERS',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Move a piece', description: 'Tap one of your orange pieces, then tap a highlighted square. Pieces move diagonally forward.'),
        HowToPlayStep(icon: Icons.flash_on_rounded, title: 'Captures are mandatory', description: 'Jump over a rival piece to capture it. If you can capture, you must, and chains of jumps continue.'),
        HowToPlayStep(icon: Icons.star_rounded, title: 'Make a king', description: 'Reach the far row to crown a piece. Kings can move and capture backwards too.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Win', description: 'Capture every rival piece or leave them with no legal move.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('CHECKERS')),
        body: _started ? Stack(children: [_game(), if (_over) _result()]) : _setup(),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.grid_on_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('CHECKERS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Classic draughts against the AI', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        const Text('DIFFICULTY', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final lv in [['Easy', 2], ['Medium', 4], ['Hard', 6]])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: GestureDetector(
                onTap: () => setState(() => _depth = lv[1] as int),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: _depth == lv[1] ? GacomColors.deepOrange.withValues(alpha: 0.18) : GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _depth == lv[1] ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
                  ),
                  child: Text(lv[0] as String, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _depth == lv[1] ? GacomColors.deepOrange : GacomColors.textPrimary)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: _start,
            child: const Text('START GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ),
  );

  Widget _piece(int p, double cell) {
    final human = Chk.owner(p) == 1;
    final colors = human
        ? const [Color(0xFFFF8A50), Color(0xFFD84315)]
        : const [Color(0xFF78909C), Color(0xFF263238)];
    return Container(
      margin: EdgeInsets.all(cell * 0.1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors, center: const Alignment(-0.3, -0.3)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 2))],
      ),
      child: Chk.isKing(p) ? Icon(Icons.star_rounded, size: cell * 0.46, color: const Color(0xFFFFD700)) : null,
    );
  }

  Widget _game() {
    final myTurn = !_busy && !_over && _s.turn == 1;
    final moves = myTurn ? Chk.legalMoves(_s) : <CMove>[];
    final movable = <int>{for (final m in moves) m.fr * 8 + m.fc};
    final sel = _sel;
    final dests = <int>{
      if (sel != null)
        for (final m in moves)
          if (m.fr == sel[0] && m.fc == sel[1]) m.tr * 8 + m.tc,
    };
    final forced = moves.isNotEmpty && moves.first.caps.isNotEmpty;
    return LayoutBuilder(builder: (context, cons) {
      final side = min(cons.maxWidth - 24, cons.maxHeight - 120);
      final cell = side / 8;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 22, child: Text(_msg, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
        const SizedBox(height: 8),
        Container(
          width: side + 8,
          height: side + 8,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFF3E2723), borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            for (int r = 0; r < 8; r++)
              Row(children: [
                for (int c = 0; c < 8; c++)
                  GestureDetector(
                    onTap: () => _onSquare(r, c),
                    child: Container(
                      width: cell,
                      height: cell,
                      color: (r + c) % 2 == 1 ? const Color(0xFF6D4C41) : const Color(0xFFD7B98E),
                      child: Stack(alignment: Alignment.center, children: [
                        if (_disp[r][c] != 0) _piece(_disp[r][c], cell),
                        if (sel != null && sel[0] == r && sel[1] == c)
                          Container(decoration: BoxDecoration(border: Border.all(color: const Color(0xFFFFD700), width: 3))),
                        if (dests.contains(r * 8 + c))
                          Container(width: cell * 0.3, height: cell * 0.3, decoration: const BoxDecoration(color: Color(0xAA66BB6A), shape: BoxShape.circle)),
                        if (sel == null && forced && movable.contains(r * 8 + c))
                          Container(decoration: BoxDecoration(border: Border.all(color: const Color(0xAAFFD700), width: 2))),
                      ]),
                    ),
                  ),
              ]),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Captured: $_humanCaps', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
      ]);
    });
  }

  Widget _result() {
    final won = _winner == 1;
    final draw = _winner == 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(26),
          decoration: GacomDecorations.glassCard(context, radius: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(won ? Icons.emoji_events_rounded : (draw ? Icons.sentiment_neutral_rounded : Icons.sentiment_dissatisfied_rounded), color: won ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
            const SizedBox(height: 12),
            Text(won ? 'YOU WIN!' : (draw ? 'DRAW' : 'AI WINS'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
            const SizedBox(height: 6),
            Text('You captured $_humanCaps pieces', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                onPressed: _toSetup,
                child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
