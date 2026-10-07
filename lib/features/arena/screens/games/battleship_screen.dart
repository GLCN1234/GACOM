import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../../../core/services/duel_session.dart';

const List<String> kShipNames = ['Carrier', 'Battleship', 'Cruiser', 'Submarine', 'Destroyer'];
const List<int> kShipLens = [5, 4, 3, 3, 2];

class BsBoard {
  final List<List<int>> ship = List.generate(10, (_) => List<int>.filled(10, -1)); // ship index or -1
  final List<List<int>> shot = List.generate(10, (_) => List<int>.filled(10, 0)); // 0 none, 1 miss, 2 hit
  final List<int> hits = List<int>.filled(5, 0);
  final List<bool> placed = List<bool>.filled(5, false);

  bool canPlace(int idx, int r, int c, bool horiz) {
    final len = kShipLens[idx];
    for (int i = 0; i < len; i++) {
      final rr = horiz ? r : r + i;
      final cc = horiz ? c + i : c;
      if (rr < 0 || rr > 9 || cc < 0 || cc > 9) return false;
      if (ship[rr][cc] != -1) return false;
    }
    return true;
  }

  void place(int idx, int r, int c, bool horiz) {
    final len = kShipLens[idx];
    for (int i = 0; i < len; i++) {
      final rr = horiz ? r : r + i;
      final cc = horiz ? c + i : c;
      ship[rr][cc] = idx;
    }
    placed[idx] = true;
  }

  void remove(int idx) {
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 10; c++) {
        if (ship[r][c] == idx) { ship[r][c] = -1; }
      }
    }
    placed[idx] = false;
  }

  void clearShips() {
    for (int i = 0; i < 5; i++) { remove(i); }
  }

  bool get allPlaced => placed.every((p) => p);

  void randomize(Random rng) {
    clearShips();
    for (int idx = 0; idx < 5; idx++) {
      while (true) {
        final horiz = rng.nextBool();
        final r = rng.nextInt(10);
        final c = rng.nextInt(10);
        if (canPlace(idx, r, c, horiz)) {
          place(idx, r, c, horiz);
          break;
        }
      }
    }
  }

  /// -2 = already shot, -1 = miss, otherwise the index of the ship hit.
  int fire(int r, int c) {
    if (shot[r][c] != 0) return -2;
    final s = ship[r][c];
    if (s == -1) {
      shot[r][c] = 1;
      return -1;
    }
    shot[r][c] = 2;
    hits[s]++;
    return s;
  }

  bool isSunk(int idx) => hits[idx] >= kShipLens[idx];
  bool get allSunk {
    for (int i = 0; i < 5; i++) {
      if (!isSunk(i)) return false;
    }
    return true;
  }

  int get sunkCells {
    int n = 0;
    for (int i = 0; i < 5; i++) {
      if (isSunk(i)) { n += kShipLens[i]; }
    }
    return n;
  }

  int get shipsAlive {
    int n = 0;
    for (int i = 0; i < 5; i++) {
      if (!isSunk(i)) { n++; }
    }
    return n;
  }
}

/// level 1 = easy, 2 = medium, 3 = hard (probability density).
class BsAi {
  final int level;
  final Random rng;
  BsAi(this.level, this.rng);

  List<int> choose(BsBoard t) {
    final unresolved = <List<int>>[];
    final open = <List<int>>[];
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 10; c++) {
        if (t.shot[r][c] == 0) { open.add([r, c]); }
        if (t.shot[r][c] == 2 && !t.isSunk(t.ship[r][c])) { unresolved.add([r, c]); }
      }
    }
    if (level == 3) return _density(t, unresolved, open);
    if (unresolved.isNotEmpty && (level == 2 || rng.nextDouble() < 0.7)) {
      final cand = <List<int>>[];
      for (final h in unresolved) {
        for (final d in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
          final nr = h[0] + d[0];
          final nc = h[1] + d[1];
          if (nr >= 0 && nr < 10 && nc >= 0 && nc < 10 && t.shot[nr][nc] == 0) { cand.add([nr, nc]); }
        }
      }
      if (cand.isNotEmpty) return cand[rng.nextInt(cand.length)];
    }
    if (level == 2) {
      final parity = open.where((x) => (x[0] + x[1]) % 2 == 0).toList();
      if (parity.isNotEmpty) return parity[rng.nextInt(parity.length)];
    }
    return open[rng.nextInt(open.length)];
  }

  List<int> _density(BsBoard t, List<List<int>> unresolved, List<List<int>> open) {
    final w = List.generate(10, (_) => List<double>.filled(10, 0));
    final unresolvedSet = <int>{for (final h in unresolved) h[0] * 10 + h[1]};
    for (int idx = 0; idx < 5; idx++) {
      if (t.isSunk(idx)) continue;
      final len = kShipLens[idx];
      for (final horiz in const [true, false]) {
        for (int r = 0; r < 10; r++) {
          for (int c = 0; c < 10; c++) {
            bool ok = true;
            int cover = 0;
            for (int i = 0; i < len; i++) {
              final rr = horiz ? r : r + i;
              final cc = horiz ? c + i : c;
              if (rr > 9 || cc > 9) { ok = false; break; }
              final sh = t.shot[rr][cc];
              if (sh == 1) { ok = false; break; }
              if (sh == 2) {
                if (!unresolvedSet.contains(rr * 10 + cc)) { ok = false; break; }
                cover++;
              }
            }
            if (!ok) continue;
            final weight = 1.0 + (cover > 0 ? 40.0 * cover * cover : 0.0);
            for (int i = 0; i < len; i++) {
              final rr = horiz ? r : r + i;
              final cc = horiz ? c + i : c;
              if (t.shot[rr][cc] == 0) { w[rr][cc] += weight; }
            }
          }
        }
      }
    }
    List<int> best = open.first;
    double bestW = -1;
    for (final cell in open) {
      final v = w[cell[0]][cell[1]] + rng.nextDouble() * 0.01;
      if (v > bestW) {
        bestW = v;
        best = cell;
      }
    }
    return best;
  }
}

class BattleshipScreen extends StatefulWidget {
  const BattleshipScreen({super.key});
  @override
  State<BattleshipScreen> createState() => _BattleshipScreenState();
}

class _BattleshipScreenState extends State<BattleshipScreen> {
  BsBoard _player = BsBoard();
  BsBoard _enemy = BsBoard();
  int _phase = 0; // 0 placing, 1 battle, 2 over
  int _level = 2;
  int _selShip = 0;
  bool _horiz = true;
  bool _busy = false;
  bool _won = false;
  bool _saved = false;
  int _shots = 0;
  int _epoch = 0;
  String _msg = 'Place your fleet';
  final Random _rng = duelRandom();
  late BsAi _ai = BsAi(_level, _rng);

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  void _nextUnplaced() {
    _selShip = -1;
    for (int i = 0; i < 5; i++) {
      if (!_player.placed[i]) {
        _selShip = i;
        break;
      }
    }
  }

  void _onPlaceTap(int r, int c) {
    if (_phase != 0) return;
    final existing = _player.ship[r][c];
    setState(() {
      if (existing != -1) {
        _player.remove(existing);
        _selShip = existing;
        _msg = 'Move the ${kShipNames[existing]}';
      } else if (_selShip != -1) {
        if (_player.canPlace(_selShip, r, c, _horiz)) {
          _player.place(_selShip, r, c, _horiz);
          SoundService.instance.playPieceMove();
          _nextUnplaced();
          _msg = _player.allPlaced ? 'Fleet ready - start the battle' : 'Place your fleet';
        } else {
          _msg = 'It does not fit there';
        }
      }
    });
  }

  void _randomPlace() {
    setState(() {
      _player.randomize(_rng);
      _nextUnplaced();
      _msg = 'Fleet ready - start the battle';
    });
  }

  void _clearPlace() {
    setState(() {
      _player.clearShips();
      _nextUnplaced();
      _msg = 'Place your fleet';
    });
  }

  void _startBattle() {
    if (!_player.allPlaced) return;
    setState(() {
      _epoch++;
      _enemy = BsBoard()..randomize(_rng);
      _ai = BsAi(_level, _rng);
      _phase = 1;
      _busy = false;
      _saved = false;
      _shots = 0;
      _msg = 'Your turn - tap the enemy waters';
    });
  }

  void _reset() {
    setState(() {
      _epoch++;
      _player = BsBoard();
      _enemy = BsBoard();
      _phase = 0;
      _busy = false;
      _selShip = 0;
      _horiz = true;
      _msg = 'Place your fleet';
    });
  }

  void _onEnemyTap(int r, int c) {
    if (_phase != 1 || _busy) return;
    final res = _enemy.fire(r, c);
    if (res == -2) return;
    _shots++;
    setState(() {
      if (res == -1) {
        _msg = 'Miss';
        SoundService.instance.playTap();
      } else if (_enemy.isSunk(res)) {
        _msg = 'You sank their ${kShipNames[res]}!';
        SoundService.instance.playPieceCapture();
      } else {
        _msg = 'Hit!';
        SoundService.instance.playExplosion();
      }
    });
    if (_enemy.allSunk) {
      _finish(true);
      return;
    }
    _enemyTurn();
  }

  Future<void> _enemyTurn() async {
    final epoch = _epoch;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (_dead(epoch)) return;
    final cell = _ai.choose(_player);
    final res = _player.fire(cell[0], cell[1]);
    setState(() {
      if (res == -1) {
        _msg = 'Enemy fired and missed. Your turn';
        SoundService.instance.playTap();
      } else if (_player.isSunk(res)) {
        _msg = 'Enemy sank your ${kShipNames[res]}!';
        SoundService.instance.playLose();
      } else {
        _msg = 'Enemy hit your ${kShipNames[res]}!';
        SoundService.instance.playExplosion();
      }
    });
    if (_player.allSunk) {
      _finish(false);
      return;
    }
    setState(() => _busy = false);
  }

  void _finish(bool won) {
    if (!_saved) {
      _saved = true;
      final int bonus = max(0, 100 - _shots);
      final int score = won ? 100 + bonus + _player.shipsAlive * 10 : _enemy.sunkCells * 3;
      GameScoreService.save(gameName: 'Battleship', score: score, won: won);
    }
    if (won) {
      SoundService.instance.playWin();
    }
    setState(() {
      _won = won;
      _phase = 2;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HowToPlayOverlay(
      gameKey: 'battleship',
      title: 'HOW TO PLAY BATTLESHIP',
      steps: const [
        HowToPlayStep(icon: Icons.directions_boat_rounded, title: 'Place your fleet', description: 'Tap a ship, then tap the grid to place it. Use ROTATE to turn it, or RANDOM to place all five for you.'),
        HowToPlayStep(icon: Icons.gps_fixed_rounded, title: 'Fire at the enemy', description: 'Take turns with the AI. Tap a square on the enemy waters to fire.'),
        HowToPlayStep(icon: Icons.whatshot_rounded, title: 'Hits and misses', description: 'Red means you hit a ship. A white dot is a miss. Hit every square of a ship to sink it.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Win', description: 'Sink all five enemy ships before they sink yours.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('BATTLESHIP')),
        body: _phase == 0 ? _placing() : Stack(children: [_battle(), if (_phase == 2) _result()]),
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? GacomColors.deepOrange.withValues(alpha: 0.18) : GacomColors.cardDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
      ),
      child: Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: active ? GacomColors.deepOrange : GacomColors.textPrimary)),
    ),
  );

  Widget _placing() {
    return LayoutBuilder(builder: (context, cons) {
      final side = min(cons.maxWidth - 32, 380.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(children: [
          Text(_msg, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          _BoardView(board: _player, showShips: true, hideSunkReveal: false, side: side, onTap: _onPlaceTap),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (int i = 0; i < 5; i++)
              _chip('${kShipNames[i]} (${kShipLens[i]})${_player.placed[i] ? ' - placed' : ''}', _selShip == i, () => setState(() => _selShip = i)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _chip(_horiz ? 'ROTATE (horizontal)' : 'ROTATE (vertical)', false, () => setState(() => _horiz = !_horiz)),
            _chip('RANDOM', false, _randomPlace),
            _chip('CLEAR', false, _clearPlace),
          ]),
          const SizedBox(height: 18),
          const Text('DIFFICULTY', style: TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final lv in [['Easy', 1], ['Medium', 2], ['Hard', 3]])
              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _chip(lv[0] as String, _level == lv[1], () => setState(() => _level = lv[1] as int))),
          ]),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, disabledBackgroundColor: GacomColors.cardDark, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _player.allPlaced ? _startBattle : null,
              child: const Text('START BATTLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ]),
      );
    });
  }

  Widget _fleet(String title, BsBoard b) => Column(children: [
    Text(title, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
    const SizedBox(height: 4),
    Wrap(spacing: 4, runSpacing: 4, alignment: WrapAlignment.center, children: [
      for (int i = 0; i < 5; i++)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: b.isSunk(i) ? const Color(0x44D32F2F) : GacomColors.cardDark,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: b.isSunk(i) ? const Color(0xFFD32F2F) : GacomColors.border),
          ),
          child: Text(kShipNames[i], style: TextStyle(fontSize: 10, color: b.isSunk(i) ? const Color(0xFFEF9A9A) : GacomColors.textSecondary, decoration: b.isSunk(i) ? TextDecoration.lineThrough : null)),
        ),
    ]),
  ]);

  Widget _battle() {
    return LayoutBuilder(builder: (context, cons) {
      final side = min(cons.maxWidth - 32, 380.0);
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(children: [
          SizedBox(height: 20, child: Text(_msg, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
          const SizedBox(height: 8),
          const Text('ENEMY WATERS', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          _BoardView(board: _enemy, showShips: false, hideSunkReveal: false, side: side, onTap: _onEnemyTap),
          const SizedBox(height: 8),
          _fleet('ENEMY FLEET', _enemy),
          const SizedBox(height: 16),
          const Text('YOUR WATERS', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 4),
          _BoardView(board: _player, showShips: true, hideSunkReveal: false, side: side * 0.62, onTap: (r, c) {}),
          const SizedBox(height: 8),
          _fleet('YOUR FLEET', _player),
        ]),
      );
    });
  }

  Widget _result() => Container(
    color: Colors.black.withValues(alpha: 0.8),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: _won ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
          const SizedBox(height: 12),
          Text(_won ? 'VICTORY!' : 'DEFEAT', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text(_won ? 'You sank the fleet in $_shots shots' : 'You sank ${5 - _enemy.shipsAlive} of 5 enemy ships', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _reset,
              child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class _BoardView extends StatelessWidget {
  final BsBoard board;
  final bool showShips;
  final bool hideSunkReveal;
  final double side;
  final void Function(int r, int c) onTap;
  const _BoardView({required this.board, required this.showShips, required this.hideSunkReveal, required this.side, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cell = side / 10;
    return SizedBox(
      width: side,
      height: side,
      child: GestureDetector(
        onTapUp: (d) {
          final r = (d.localPosition.dy / cell).floor();
          final c = (d.localPosition.dx / cell).floor();
          if (r >= 0 && r < 10 && c >= 0 && c < 10) { onTap(r, c); }
        },
        child: CustomPaint(painter: _BoardPainter(board, showShips), size: Size(side, side)),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final BsBoard board;
  final bool showShips;
  _BoardPainter(this.board, this.showShips);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 10;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), Paint()..color = const Color(0xFF0D2A44));
    final line = Paint()..color = const Color(0xFF1B4467)..strokeWidth = 1;
    for (int i = 0; i <= 10; i++) {
      canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line);
      canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
    for (int r = 0; r < 10; r++) {
      for (int c = 0; c < 10; c++) {
        final rect = Rect.fromLTWH(c * cell, r * cell, cell, cell);
        final s = board.ship[r][c];
        if (s != -1) {
          if (showShips) {
            canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(4)), Paint()..color = const Color(0xFF78909C));
          } else if (board.isSunk(s)) {
            canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(4)), Paint()..color = const Color(0xFF8D2B2B));
          }
        }
        final sh = board.shot[r][c];
        if (sh == 2) {
          canvas.drawCircle(rect.center, cell * 0.3, Paint()..color = const Color(0xFFE53935));
          final x = Paint()..color = Colors.white..strokeWidth = 2;
          final d = cell * 0.14;
          canvas.drawLine(rect.center + Offset(-d, -d), rect.center + Offset(d, d), x);
          canvas.drawLine(rect.center + Offset(-d, d), rect.center + Offset(d, -d), x);
        } else if (sh == 1) {
          canvas.drawCircle(rect.center, cell * 0.11, Paint()..color = Colors.white.withValues(alpha: 0.85));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => true;
}
