import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../../../core/services/duel_session.dart';

/// Board: 12 pits in a loop. Pits 0-5 belong to the human (bottom row,
/// left to right), pits 6-11 to the AI (top row, shown right to left).
/// Sowing runs counter-clockwise, i.e. in increasing pit index.
class AyoState {
  List<int> pits;
  List<int> cap;
  int player; // 0 = human, 1 = AI
  int moves;
  AyoState(this.pits, this.cap, this.player, this.moves);
  AyoState.initial()
      : pits = List<int>.filled(12, 4),
        cap = [0, 0],
        player = 0,
        moves = 0;
  AyoState clone() => AyoState(List<int>.from(pits), List<int>.from(cap), player, moves);
}

class Ayo {
  static bool owns(int player, int i) => player == 0 ? i < 6 : i >= 6;

  static int sideSeeds(AyoState s, int player) {
    final lo = player == 0 ? 0 : 6;
    int t = 0;
    for (int i = lo; i < lo + 6; i++) { t += s.pits[i]; }
    return t;
  }

  /// The pits that each receive one seed, in order. A pit holding 12 or
  /// more seeds is skipped on the lap so it is never sown into itself.
  static List<int> sowPath(AyoState s, int pit) {
    final path = <int>[];
    int n = s.pits[pit];
    int i = pit;
    while (n > 0) {
      i = (i + 1) % 12;
      if (i == pit) continue;
      path.add(i);
      n--;
    }
    return path;
  }

  /// Plays [pit] for the side to move. Returns the seeds captured.
  /// A capture that would take every seed on the opponent's side is
  /// not allowed (the grand slam rule), so the move is simply played.
  static int applyMove(AyoState s, int pit) {
    final p = s.player;
    final path = sowPath(s, pit);
    s.pits[pit] = 0;
    for (final i in path) { s.pits[i]++; }
    int captured = 0;
    final last = path.last;
    if (!owns(p, last)) {
      final chain = <int>[];
      int j = last;
      while (!owns(p, j) && (s.pits[j] == 2 || s.pits[j] == 3)) {
        chain.add(j);
        j = (j + 11) % 12;
      }
      int total = 0;
      for (final k in chain) { total += s.pits[k]; }
      if (chain.isNotEmpty && total < sideSeeds(s, 1 - p)) {
        for (final k in chain) { s.pits[k] = 0; }
        s.cap[p] += total;
        captured = total;
      }
    }
    s.player = 1 - p;
    s.moves++;
    return captured;
  }

  /// Moves the side to play may choose. If the opponent has no seeds,
  /// only moves that give them seeds are legal.
  static List<int> legalMoves(AyoState s) {
    final p = s.player;
    final lo = p == 0 ? 0 : 6;
    final mine = <int>[for (int i = lo; i < lo + 6; i++) if (s.pits[i] > 0) i];
    if (mine.isEmpty) return mine;
    if (sideSeeds(s, 1 - p) == 0) {
      final feeding = <int>[];
      for (final i in mine) {
        final c = s.clone();
        applyMove(c, i);
        if (sideSeeds(c, 1 - p) > 0) { feeding.add(i); }
      }
      return feeding;
    }
    return mine;
  }

  /// Each side keeps the seeds left on its own side.
  static void sweep(AyoState s) {
    s.cap[0] += sideSeeds(s, 0);
    s.cap[1] += sideSeeds(s, 1);
    for (int i = 0; i < 12; i++) { s.pits[i] = 0; }
  }

  /// True when the game has ended (25+ captured, no legal move, or a
  /// move limit to stop endless shuffling). Sweeps leftover seeds when
  /// the end is by no-move or move limit.
  static bool checkOver(AyoState s) {
    if (s.cap[0] >= 25 || s.cap[1] >= 25) return true;
    if (s.moves >= 400 || legalMoves(s).isEmpty) {
      sweep(s);
      return true;
    }
    return false;
  }

  static double _eval(AyoState s) =>
      (s.cap[1] - s.cap[0]) * 10.0 + (sideSeeds(s, 1) - sideSeeds(s, 0)) * 0.5;

  static double _search(AyoState s, int depth, double alpha, double beta) {
    final moves = legalMoves(s);
    final stalled = moves.isEmpty || s.moves >= 400;
    if (s.cap[0] >= 25 || s.cap[1] >= 25 || stalled) {
      if (stalled) { sweep(s); }
      final diff = (s.cap[1] - s.cap[0]).toDouble();
      return diff > 0 ? 1000 + diff : (diff < 0 ? -1000 + diff : 0.0);
    }
    if (depth == 0) return _eval(s);
    if (s.player == 1) {
      double best = -1e9;
      for (final m in moves) {
        final c = s.clone();
        applyMove(c, m);
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
        applyMove(c, m);
        final v = _search(c, depth - 1, alpha, beta);
        if (v < best) { best = v; }
        if (best < beta) { beta = best; }
        if (alpha >= beta) break;
      }
      return best;
    }
  }

  /// Best move for the AI (player 1). depth 1 = easy (greedy, sometimes
  /// random), larger depths search that many moves ahead.
  static int bestMove(AyoState s, int depth, Random rng) {
    final moves = legalMoves(s);
    moves.shuffle(rng);
    if (depth <= 1) {
      if (rng.nextDouble() < 0.45) return moves.first;
      int best = moves.first;
      int bestCap = -1;
      for (final m in moves) {
        final c = s.clone();
        final cp = applyMove(c, m);
        if (cp > bestCap) {
          bestCap = cp;
          best = m;
        }
      }
      return best;
    }
    int bestM = moves.first;
    double bestV = -1e9;
    for (final m in moves) {
      final c = s.clone();
      applyMove(c, m);
      final v = _search(c, depth - 1, -1e9, 1e9);
      if (v > bestV) {
        bestV = v;
        bestM = m;
      }
    }
    return bestM;
  }
}

class AyoScreen extends StatefulWidget {
  const AyoScreen({super.key});
  @override
  State<AyoScreen> createState() => _AyoScreenState();
}

class _AyoScreenState extends State<AyoScreen> {
  AyoState _s = AyoState.initial();
  List<int> _disp = List<int>.filled(12, 4);
  bool _started = false;
  int _depth = 3;
  bool _busy = false;
  bool _over = false;
  bool _saved = false;
  int _epoch = 0;
  String _msg = '';
  final Random _rng = duelRandom();

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  void _start() {
    setState(() {
      _epoch++;
      _s = AyoState.initial();
      _disp = List<int>.from(_s.pits);
      _started = true;
      _busy = false;
      _over = false;
      _saved = false;
      _msg = 'Your move - tap one of your pits';
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _started = false;
      _busy = false;
      _over = false;
    });
  }

  void _onPit(int i) {
    if (_busy || _over || _s.player != 0 || i > 5) return;
    final legal = Ayo.legalMoves(_s);
    if (!legal.contains(i)) {
      setState(() => _msg = _s.pits[i] == 0 ? 'That pit is empty' : 'You must give your opponent seeds');
      return;
    }
    _play(i);
  }

  Future<void> _play(int pit) async {
    final epoch = _epoch;
    final mover = _s.player;
    final next = _s.clone();
    final path = Ayo.sowPath(next, pit);
    final captured = Ayo.applyMove(next, pit);
    setState(() {
      _busy = true;
      _msg = '';
      _disp[pit] = 0;
    });
    for (final i in path) {
      await Future.delayed(const Duration(milliseconds: 210));
      if (_dead(epoch)) return;
      setState(() => _disp[i] = _disp[i] + 1);
      SoundService.instance.playTap();
    }
    await Future.delayed(const Duration(milliseconds: 250));
    if (_dead(epoch)) return;
    if (captured > 0) { SoundService.instance.playPieceCapture(); }
    setState(() {
      _s = next;
      _disp = List<int>.from(next.pits);
      _msg = captured > 0 ? '${mover == 0 ? 'You' : 'AI'} captured $captured' : '';
    });
    if (captured > 0) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_dead(epoch)) return;
    }
    if (Ayo.checkOver(_s)) {
      _finish();
      return;
    }
    setState(() => _busy = false);
    if (_s.player == 1) { _aiTurn(); }
  }

  Future<void> _aiTurn() async {
    final epoch = _epoch;
    setState(() {
      _busy = true;
      _msg = 'AI is thinking...';
    });
    await Future.delayed(const Duration(milliseconds: 700));
    if (_dead(epoch)) return;
    final m = Ayo.bestMove(_s, _depth, _rng);
    await _play(m);
  }

  void _finish() {
    final mine = _s.cap[0];
    final theirs = _s.cap[1];
    final bool? won = mine > theirs ? true : (mine < theirs ? false : null);
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: 'Ayo', score: mine, won: won);
    }
    if (won == true) {
      SoundService.instance.playWin();
    } else if (won == false) {
      SoundService.instance.playLose();
    }
    setState(() {
      _over = true;
      _busy = false;
      _disp = List<int>.from(_s.pits);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HowToPlayOverlay(
      gameKey: 'ayo',
      title: 'HOW TO PLAY AYO',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Pick a pit', description: 'Tap one of your six pits (bottom row). All its seeds are picked up and dropped one by one, counter-clockwise.'),
        HowToPlayStep(icon: Icons.sync_rounded, title: 'Sow around the board', description: 'Seeds go into your pits, then your opponent pits. A pit with 12 or more seeds skips itself on the lap.'),
        HowToPlayStep(icon: Icons.savings_rounded, title: 'Capture', description: 'If your last seed lands in an opponent pit making it 2 or 3 seeds, you capture it, plus any earlier pits in a row that also hold 2 or 3.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Win', description: 'First to capture 25 seeds wins. If your opponent has no seeds, you must make a move that gives them some.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('AYO')),
        body: _started ? Stack(children: [_game(), if (_over) _result()]) : _setup(),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.grain_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('AYO', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('A traditional African seed-sowing strategy game', textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        const Text('DIFFICULTY', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final lv in [['Easy', 1], ['Medium', 3], ['Hard', 6]])
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

  Widget _store(String label, int count, {required bool active}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: GacomColors.cardDark,
      borderRadius: BorderRadius.circular(50),
      border: Border.all(color: active ? GacomColors.deepOrange : GacomColors.border, width: 2),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(width: 10),
      Text('$count', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
      Text(' / 25', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
    ]),
  );

  Widget _game() {
    final legal = (!_busy && !_over && _s.player == 0) ? Ayo.legalMoves(_s).toSet() : <int>{};
    return LayoutBuilder(builder: (context, cons) {
      final d = min((cons.maxWidth - 40 - 5 * 8) / 6, 78.0);
      Widget pit(int i) => GestureDetector(
        onTap: () => _onPit(i),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: d, height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2E1A0E),
              border: Border.all(color: legal.contains(i) ? GacomColors.deepOrange : const Color(0xFF1A0E06), width: legal.contains(i) ? 3 : 2),
            ),
            child: CustomPaint(painter: _SeedsPainter(_disp[i])),
          ),
          const SizedBox(height: 3),
          Text('${_disp[i]}', style: const TextStyle(color: Color(0xFFD9B98A), fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _store('AI', _s.cap[1], active: _s.player == 1 && !_over),
        const SizedBox(height: 14),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6B4423), Color(0xFF4A2D15)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF8A5A2F), width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (int i = 11; i >= 6; i--) pit(i)]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (int i = 0; i <= 5; i++) pit(i)]),
          ]),
        ),
        const SizedBox(height: 14),
        _store('YOU', _s.cap[0], active: _s.player == 0 && !_over),
        const SizedBox(height: 16),
        SizedBox(height: 20, child: Text(_msg, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
      ]);
    });
  }

  Widget _result() {
    final mine = _s.cap[0];
    final theirs = _s.cap[1];
    final won = mine > theirs;
    final draw = mine == theirs;
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
            Text('You captured $mine, AI captured $theirs', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
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

/// Seeds laid out on a golden-angle spiral, so each extra seed lands in
/// a stable, evenly spread spot instead of jumping around.
class _SeedsPainter extends CustomPainter {
  final int count;
  _SeedsPainter(this.count);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width / 2;
    final n = min(count, 20);
    for (int k = 0; k < n; k++) {
      final r = sqrt((k + 0.6) / 20.0) * radius * 0.72;
      final a = k * 2.399963;
      final p = c + Offset(cos(a), sin(a)) * r;
      canvas.drawCircle(p, radius * 0.13, Paint()..color = const Color(0xFFF1E3C8));
      canvas.drawCircle(p, radius * 0.13, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0xFF8C6B3F));
    }
  }

  @override
  bool shouldRepaint(_SeedsPainter oldDelegate) => oldDelegate.count != count;
}
