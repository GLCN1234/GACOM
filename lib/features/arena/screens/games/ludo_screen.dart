import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../../../core/services/duel_session.dart';

const List<Color> _ludoColors = [Color(0xFFE53935), Color(0xFF43A047), Color(0xFFFDD835), Color(0xFF1E88E5)];
const List<String> _ludoNames = ['Red', 'Green', 'Yellow', 'Blue'];

class _Cell {
  final int r;
  final int c;
  const _Cell(this.r, this.c);
}

class LudoMoveResult {
  final int captured;
  final bool finished;
  final bool extraTurn;
  const LudoMoveResult(this.captured, this.finished, this.extraTurn);
}

/// Pure game rules, no UI. Positions per token: -1 = in the yard,
/// 0..50 = on the shared 52-cell track (relative to that colour's
/// start), 51..55 = that colour's private home column, 56 = home.
class LudoEngine {
  static const int trackLen = 52;
  static const List<int> startIdx = [0, 13, 26, 39];
  // The four start cells plus the four star cells are safe squares.
  static const Set<int> safeIdx = {0, 8, 13, 21, 26, 34, 39, 47};

  static final List<_Cell> track = _buildTrack();
  static final List<List<_Cell>> homeCol = [
    [for (int c = 1; c <= 5; c++) _Cell(7, c)],
    [for (int r = 1; r <= 5; r++) _Cell(r, 7)],
    [for (int c = 13; c >= 9; c--) _Cell(7, c)],
    [for (int r = 13; r >= 9; r--) _Cell(r, 7)],
  ];
  static const List<_Cell> finishCell = [_Cell(7, 6), _Cell(6, 7), _Cell(7, 8), _Cell(8, 7)];

  static List<_Cell> _buildTrack() {
    final t = <_Cell>[];
    for (int c = 1; c <= 5; c++) { t.add(_Cell(6, c)); }
    for (int r = 5; r >= 0; r--) { t.add(_Cell(r, 6)); }
    t.add(const _Cell(0, 7));
    t.add(const _Cell(0, 8));
    for (int r = 1; r <= 5; r++) { t.add(_Cell(r, 8)); }
    for (int c = 9; c <= 14; c++) { t.add(_Cell(6, c)); }
    t.add(const _Cell(7, 14));
    t.add(const _Cell(8, 14));
    for (int c = 13; c >= 9; c--) { t.add(_Cell(8, c)); }
    for (int r = 9; r <= 14; r++) { t.add(_Cell(r, 8)); }
    t.add(const _Cell(14, 7));
    t.add(const _Cell(14, 6));
    for (int r = 13; r >= 9; r--) { t.add(_Cell(r, 6)); }
    for (int c = 5; c >= 0; c--) { t.add(_Cell(8, c)); }
    t.add(const _Cell(7, 0));
    t.add(const _Cell(6, 0));
    return t;
  }

  final List<int> active;
  final List<List<int>> pos = List.generate(4, (_) => List<int>.filled(4, -1));
  final Random _rng = duelRandom();
  int turn = 0;
  int? die;
  int sixesInRow = 0;
  int? winner;

  LudoEngine(this.active);

  int get color => active[turn];

  static _Cell cellFor(int color, int p) {
    if (p <= 50) return track[(startIdx[color] + p) % trackLen];
    if (p <= 55) return homeCol[color][p - 51];
    return finishCell[color];
  }

  static int trackIndex(int color, int p) => (startIdx[color] + p) % trackLen;

  int homeCount(int color) => pos[color].where((p) => p == 56).length;

  List<int> legalTokens() {
    final d = die;
    if (d == null) return <int>[];
    final out = <int>[];
    for (int t = 0; t < 4; t++) {
      final p = pos[color][t];
      if (p == -1) {
        if (d == 6) { out.add(t); }
      } else if (p < 56 && p + d <= 56) {
        out.add(t);
      }
    }
    return out;
  }

  /// Records a roll. Returns true when three sixes in a row forfeit the turn.
  bool applyRoll(int value) {
    die = value;
    if (value == 6) {
      sixesInRow++;
    } else {
      sixesInRow = 0;
    }
    if (sixesInRow >= 3) {
      endTurn();
      return true;
    }
    return false;
  }

  void endTurn() {
    turn = (turn + 1) % active.length;
    die = null;
    sixesInRow = 0;
  }

  LudoMoveResult move(int t) {
    final c = color;
    final d = die!;
    final from = pos[c][t];
    final to = from == -1 ? 0 : from + d;
    pos[c][t] = to;
    int captured = 0;
    if (to <= 50) {
      final idx = trackIndex(c, to);
      if (!safeIdx.contains(idx)) {
        for (final o in active) {
          if (o == c) continue;
          for (int j = 0; j < 4; j++) {
            final op = pos[o][j];
            if (op >= 0 && op <= 50 && trackIndex(o, op) == idx) {
              pos[o][j] = -1;
              captured++;
            }
          }
        }
      }
    }
    final finished = to == 56;
    if (pos[c].every((p) => p == 56)) { winner = c; }
    final extra = winner == null && (d == 6 || captured > 0 || finished);
    if (winner == null) {
      if (extra) {
        die = null;
      } else {
        endTurn();
      }
    }
    return LudoMoveResult(captured, finished, extra);
  }

  bool _captureAt(int c, int idx) {
    for (final o in active) {
      if (o == c) continue;
      for (int j = 0; j < 4; j++) {
        final op = pos[o][j];
        if (op >= 0 && op <= 50 && trackIndex(o, op) == idx) return true;
      }
    }
    return false;
  }

  bool _threatened(int c, int idx) {
    for (final o in active) {
      if (o == c) continue;
      for (int j = 0; j < 4; j++) {
        final op = pos[o][j];
        if (op >= 0 && op <= 50) {
          final dist = (idx - trackIndex(o, op) + trackLen) % trackLen;
          if (dist >= 1 && dist <= 6) return true;
        }
      }
    }
    return false;
  }

  /// Simple but sensible AI: finish > capture > leave the yard > enter
  /// the home column > land safe > escape danger > advance.
  int chooseAi() {
    final legal = legalTokens();
    final c = color;
    final d = die!;
    int best = legal.first;
    double bestScore = -1e9;
    for (final t in legal) {
      final p = pos[c][t];
      final to = p == -1 ? 0 : p + d;
      double s = to.toDouble();
      if (to == 56) { s += 100; }
      if (p == -1) { s += 55; }
      if (to >= 51 && to < 56) { s += 35; }
      if (to <= 50) {
        final idx = trackIndex(c, to);
        if (safeIdx.contains(idx)) {
          s += 22;
        } else {
          if (_captureAt(c, idx)) { s += 90; }
          if (_threatened(c, idx)) { s -= 25; }
        }
      }
      if (p >= 0 && p <= 50) {
        final idx = trackIndex(c, p);
        if (!safeIdx.contains(idx) && _threatened(c, idx)) { s += 30; }
      }
      s += _rng.nextDouble();
      if (s > bestScore) {
        bestScore = s;
        best = t;
      }
    }
    return best;
  }
}

Offset _yardSpot(int color, int t, double cell) {
  const origins = [[0, 0], [0, 9], [9, 9], [9, 0]];
  final r0 = origins[color][0];
  final c0 = origins[color][1];
  return Offset((c0 + 2 + (t % 2) * 2) * cell, (r0 + 2 + (t ~/ 2) * 2) * cell);
}

/// Screen position of every active token, keyed by colour * 4 + token.
Map<int, Offset> ludoTokenCenters(LudoEngine g, double cell) {
  final out = <int, Offset>{};
  final groups = <int, List<int>>{};
  for (final c in g.active) {
    for (int t = 0; t < 4; t++) {
      final p = g.pos[c][t];
      final key = c * 4 + t;
      if (p == -1) {
        out[key] = _yardSpot(c, t, cell);
      } else {
        final cl = LudoEngine.cellFor(c, p);
        groups.putIfAbsent(cl.r * 15 + cl.c, () => <int>[]).add(key);
      }
    }
  }
  groups.forEach((ck, keys) {
    final r = ck ~/ 15;
    final cc = ck % 15;
    final center = Offset((cc + 0.5) * cell, (r + 0.5) * cell);
    if (keys.length == 1) {
      out[keys[0]] = center;
    } else {
      for (int i = 0; i < keys.length; i++) {
        final a = 2 * pi * i / keys.length;
        out[keys[i]] = center + Offset(cos(a), sin(a)) * cell * 0.22;
      }
    }
  });
  return out;
}

class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});
  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  LudoEngine? _g;
  int _opponents = 3;
  bool _busy = false;
  int _shownDie = 1;
  String _msg = '';
  int _epoch = 0;
  bool _saved = false;
  bool _humanExtra = false;
  List<int> _movable = <int>[];
  final Random _rng = duelRandom();

  static List<int> _activeFor(int opponents) =>
      opponents == 1 ? [0, 2] : (opponents == 2 ? [0, 1, 2] : [0, 1, 2, 3]);

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  void _start() {
    setState(() {
      _epoch++;
      _g = LudoEngine(_activeFor(_opponents));
      _busy = false;
      _saved = false;
      _humanExtra = false;
      _movable = <int>[];
      _shownDie = 1;
      _msg = 'Your turn - tap ROLL';
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _g = null;
      _busy = false;
      _movable = <int>[];
    });
  }

  Future<void> _roll() async {
    final g = _g;
    if (g == null || _busy || g.winner != null || g.die != null || g.color != 0) return;
    await _rollSequence(g, human: true);
  }

  Future<void> _rollSequence(LudoEngine g, {required bool human}) async {
    final epoch = _epoch;
    _humanExtra = false;
    setState(() {
      _busy = true;
      _movable = <int>[];
      _msg = human ? 'Rolling...' : '${_ludoNames[g.color]} is rolling...';
    });
    for (int i = 0; i < 7; i++) {
      await Future.delayed(const Duration(milliseconds: 70));
      if (_dead(epoch)) return;
      setState(() => _shownDie = _rng.nextInt(6) + 1);
      if (i % 3 == 0) { SoundService.instance.playTap(); }
    }
    final value = _rng.nextInt(6) + 1;
    final forfeited = g.applyRoll(value);
    setState(() => _shownDie = value);
    if (forfeited) {
      setState(() => _msg = 'Three sixes in a row - turn lost');
      SoundService.instance.playWrong();
      await Future.delayed(const Duration(milliseconds: 900));
      if (_dead(epoch)) return;
      _afterTurn();
      return;
    }
    final legal = g.legalTokens();
    if (legal.isEmpty) {
      setState(() => _msg = 'No move possible');
      await Future.delayed(const Duration(milliseconds: 800));
      if (_dead(epoch)) return;
      g.endTurn();
      _afterTurn();
      return;
    }
    if (human && legal.length > 1) {
      setState(() {
        _movable = legal;
        _busy = false;
        _msg = 'Tap a glowing token to move it';
      });
      return;
    }
    final token = human ? legal.first : g.chooseAi();
    await Future.delayed(const Duration(milliseconds: 450));
    if (_dead(epoch)) return;
    await _applyMove(g, token);
  }

  Future<void> _applyMove(LudoEngine g, int token) async {
    final epoch = _epoch;
    final c = g.color;
    final res = g.move(token);
    _humanExtra = c == 0 && res.extraTurn;
    setState(() {
      _movable = <int>[];
      _busy = true;
      if (res.captured > 0) {
        _msg = '${c == 0 ? 'You' : _ludoNames[c]} captured ${res.captured}!';
      } else if (res.finished) {
        _msg = '${c == 0 ? 'You' : _ludoNames[c]} got a token home!';
      } else {
        _msg = '';
      }
    });
    if (res.captured > 0) {
      SoundService.instance.playPieceCapture();
    } else if (res.finished) {
      SoundService.instance.playCorrect();
    } else {
      SoundService.instance.playPieceMove();
    }
    await Future.delayed(const Duration(milliseconds: 550));
    if (_dead(epoch)) return;
    if (g.winner != null) {
      _finish(g);
      return;
    }
    _afterTurn();
  }

  void _afterTurn() {
    final g = _g;
    if (g == null || g.winner != null) return;
    final epoch = _epoch;
    if (g.color == 0) {
      setState(() {
        _busy = false;
        _msg = _humanExtra ? 'Roll again!' : 'Your turn - tap ROLL';
      });
    } else {
      setState(() {
        _busy = true;
        _msg = '${_ludoNames[g.color]} is thinking...';
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_dead(epoch)) return;
        _rollSequence(g, human: false);
      });
    }
  }

  void _finish(LudoEngine g) {
    final won = g.winner == 0;
    if (!_saved) {
      _saved = true;
      final score = g.homeCount(0) * 10 + (won ? 50 : 0);
      GameScoreService.save(gameName: 'Ludo', score: score, won: won);
    }
    if (won) {
      SoundService.instance.playWin();
    } else {
      SoundService.instance.playLose();
    }
    setState(() => _busy = false);
  }

  void _onBoardTap(Offset local, double cell) {
    final g = _g;
    if (g == null || _busy || _movable.isEmpty || g.color != 0) return;
    final centers = ludoTokenCenters(g, cell);
    int? hit;
    double bestDist = cell * 0.7;
    for (final t in _movable) {
      final o = centers[t];
      if (o == null) continue;
      final dd = (o - local).distance;
      if (dd < bestDist) {
        bestDist = dd;
        hit = t;
      }
    }
    if (hit != null) { _applyMove(g, hit); }
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return HowToPlayOverlay(
      gameKey: 'ludo',
      title: 'HOW TO PLAY LUDO',
      steps: const [
        HowToPlayStep(icon: Icons.casino_rounded, title: 'Roll the dice', description: 'Tap ROLL on your turn. You need a 6 to bring a token out of your yard.'),
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Move a token', description: 'Tap a glowing token to move it forward by the number rolled.'),
        HowToPlayStep(icon: Icons.replay_rounded, title: 'Extra turns', description: 'A 6, a capture, or getting a token home gives you another roll. Three 6s in a row lose your turn.'),
        HowToPlayStep(icon: Icons.flag_rounded, title: 'Win the race', description: 'Land on a rival token to send it back (except on star and start squares). Get all 4 tokens home first.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('LUDO')),
        body: g == null ? _setup() : Stack(children: [_game(g), if (g.winner != null) _result(g)]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.casino_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('LUDO', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Race your four tokens home against the AI', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 24),
        const Text('OPPONENTS', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final n in [1, 2, 3])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: GestureDetector(
                onTap: () => setState(() => _opponents = n),
                child: Container(
                  width: 64, padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _opponents == n ? GacomColors.deepOrange.withValues(alpha: 0.18) : GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _opponents == n ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
                  ),
                  child: Text('$n', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: _opponents == n ? GacomColors.deepOrange : GacomColors.textPrimary)),
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

  Widget _game(LudoEngine g) {
    final myTurn = g.color == 0 && !_busy && g.die == null && g.winner == null;
    return Column(children: [
      _players(g),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: LayoutBuilder(builder: (context, cons) {
            final side = min(cons.maxWidth, cons.maxHeight);
            final cell = side / 15;
            return Center(
              child: SizedBox(
                width: side, height: side,
                child: GestureDetector(
                  onTapUp: (d) => _onBoardTap(d.localPosition, cell),
                  child: CustomPaint(painter: _LudoPainter(g, _movable), size: Size(side, side)),
                ),
              ),
            );
          }),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Row(children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: CustomPaint(painter: _DiePainter(_shownDie)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(_msg, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, disabledBackgroundColor: GacomColors.cardDark, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: myTurn ? _roll : null,
            child: const Text('ROLL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
      ),
    ]);
  }

  Widget _players(LudoEngine g) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final c in g.active)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: GacomColors.cardDark,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: g.color == c && g.winner == null ? _ludoColors[c] : GacomColors.border, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: _ludoColors[c], shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text('${c == 0 ? 'You' : _ludoNames[c]} ${g.homeCount(c)}/4', style: const TextStyle(color: GacomColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
    ]),
  );

  Widget _result(LudoEngine g) {
    final won = g.winner == 0;
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(26),
          decoration: GacomDecorations.glassCard(context, radius: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: won ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
            const SizedBox(height: 12),
            Text(won ? 'YOU WIN!' : '${_ludoNames[g.winner!]} WINS', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Your tokens home: ${g.homeCount(0)}/4', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
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

void _drawText(Canvas canvas, String text, Offset center, double fontSize, Color color) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: FontWeight.w800)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

class _LudoPainter extends CustomPainter {
  final LudoEngine g;
  final List<int> movable;
  _LudoPainter(this.g, this.movable);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 15;
    Rect cellRect(int r, int c) => Rect.fromLTWH(c * cell, r * cell, cell, cell);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(cell * 0.4)),
      Paint()..color = const Color(0xFF14161E),
    );

    const origins = [[0, 0], [0, 9], [9, 9], [9, 0]];
    for (int k = 0; k < 4; k++) {
      final r0 = origins[k][0];
      final c0 = origins[k][1];
      final isActive = g.active.contains(k);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(c0 * cell, r0 * cell, 6 * cell, 6 * cell), Radius.circular(cell * 0.5)),
        Paint()..color = _ludoColors[k].withValues(alpha: isActive ? 0.85 : 0.22),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH((c0 + 1) * cell, (r0 + 1) * cell, 4 * cell, 4 * cell), Radius.circular(cell * 0.4)),
        Paint()..color = const Color(0xFF0B0D13),
      );
      for (int t = 0; t < 4; t++) {
        canvas.drawCircle(_yardSpot(k, t, cell), cell * 0.42, Paint()..color = _ludoColors[k].withValues(alpha: isActive ? 0.3 : 0.1));
      }
    }

    final cellFill = Paint()..color = const Color(0xFF1E222D);
    final cellBorder = Paint()..color = const Color(0xFF2C3242)..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < LudoEngine.trackLen; i++) {
      final cl = LudoEngine.track[i];
      final rect = cellRect(cl.r, cl.c).deflate(0.5);
      canvas.drawRect(rect, cellFill);
      final startOf = LudoEngine.startIdx.indexOf(i);
      if (startOf >= 0) {
        canvas.drawRect(rect, Paint()..color = _ludoColors[startOf].withValues(alpha: g.active.contains(startOf) ? 0.6 : 0.2));
      }
      canvas.drawRect(rect, cellBorder);
      if (LudoEngine.safeIdx.contains(i) && startOf < 0) {
        _drawText(canvas, '*', rect.center + Offset(0, cell * 0.12), cell * 0.7, Colors.white.withValues(alpha: 0.5));
      }
    }

    for (int k = 0; k < 4; k++) {
      final isActive = g.active.contains(k);
      for (final cl in LudoEngine.homeCol[k]) {
        final rect = cellRect(cl.r, cl.c).deflate(0.5);
        canvas.drawRect(rect, Paint()..color = _ludoColors[k].withValues(alpha: isActive ? 0.55 : 0.15));
        canvas.drawRect(rect, cellBorder);
      }
    }

    final cx = 7.5 * cell;
    final cy = 7.5 * cell;
    final edges = [
      [Offset(6 * cell, 6 * cell), Offset(6 * cell, 9 * cell)],
      [Offset(6 * cell, 6 * cell), Offset(9 * cell, 6 * cell)],
      [Offset(9 * cell, 6 * cell), Offset(9 * cell, 9 * cell)],
      [Offset(6 * cell, 9 * cell), Offset(9 * cell, 9 * cell)],
    ];
    for (int k = 0; k < 4; k++) {
      final path = Path()
        ..moveTo(edges[k][0].dx, edges[k][0].dy)
        ..lineTo(edges[k][1].dx, edges[k][1].dy)
        ..lineTo(cx, cy)
        ..close();
      canvas.drawPath(path, Paint()..color = _ludoColors[k].withValues(alpha: g.active.contains(k) ? 0.9 : 0.25));
    }

    final centers = ludoTokenCenters(g, cell);
    final ordered = centers.keys.toList()
      ..sort((a, b) {
        final ma = (a ~/ 4 == 0 && movable.contains(a % 4)) ? 1 : 0;
        final mb = (b ~/ 4 == 0 && movable.contains(b % 4)) ? 1 : 0;
        return ma.compareTo(mb);
      });
    for (final key in ordered) {
      final color = key ~/ 4;
      final center = centers[key]!;
      final radius = cell * 0.34;
      final isMovable = color == 0 && movable.contains(key % 4);
      canvas.drawCircle(center + const Offset(0, 1.5), radius, Paint()..color = Colors.black.withValues(alpha: 0.4));
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
      canvas.drawCircle(center, radius * 0.78, Paint()..color = _ludoColors[color]);
      canvas.drawCircle(center, radius * 0.28, Paint()..color = Colors.black.withValues(alpha: 0.25));
      if (isMovable) {
        canvas.drawCircle(center, radius + 4, Paint()..color = const Color(0xFFFFD700)..style = PaintingStyle.stroke..strokeWidth = 3);
      }
    }
  }

  @override
  bool shouldRepaint(_LudoPainter oldDelegate) => true;
}

class _DiePainter extends CustomPainter {
  final int value;
  _DiePainter(this.value);

  static const Map<int, List<List<double>>> _pips = {
    1: [[0.5, 0.5]],
    2: [[0.27, 0.27], [0.73, 0.73]],
    3: [[0.27, 0.27], [0.5, 0.5], [0.73, 0.73]],
    4: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.73], [0.73, 0.73]],
    5: [[0.27, 0.27], [0.73, 0.27], [0.5, 0.5], [0.27, 0.73], [0.73, 0.73]],
    6: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.5], [0.73, 0.5], [0.27, 0.73], [0.73, 0.73]],
  };

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pips[value] ?? _pips[1]!) {
      canvas.drawCircle(Offset(p[0] * size.width, p[1] * size.height), size.width * 0.085, Paint()..color = const Color(0xFF14161E));
    }
  }

  @override
  bool shouldRepaint(_DiePainter oldDelegate) => oldDelegate.value != value;
}
