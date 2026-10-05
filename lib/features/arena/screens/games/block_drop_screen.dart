import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';

class BdShape {
  final int n; // size of the square the piece rotates inside
  final List<List<int>> cells; // [row, col] at spawn orientation
  const BdShape(this.n, this.cells);
}

/// Piece types 1..7 are I, O, T, S, Z, J, L.
const List<BdShape> kBdShapes = [
  BdShape(4, [[1, 0], [1, 1], [1, 2], [1, 3]]),
  BdShape(2, [[0, 0], [0, 1], [1, 0], [1, 1]]),
  BdShape(3, [[0, 1], [1, 0], [1, 1], [1, 2]]),
  BdShape(3, [[0, 1], [0, 2], [1, 0], [1, 1]]),
  BdShape(3, [[0, 0], [0, 1], [1, 1], [1, 2]]),
  BdShape(3, [[0, 0], [1, 0], [1, 1], [1, 2]]),
  BdShape(3, [[0, 2], [1, 0], [1, 1], [1, 2]]),
];

const List<Color> kBdColors = [
  Color(0x00000000),
  Color(0xFF26C6DA),
  Color(0xFFFFD600),
  Color(0xFFAB47BC),
  Color(0xFF66BB6A),
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFFFFA726),
];

class BdPiece {
  int type;
  int rot;
  int row;
  int col;
  BdPiece(this.type, this.rot, this.row, this.col);
  BdPiece copy() => BdPiece(type, rot, row, col);

  /// Absolute [row, col] of the four squares.
  List<List<int>> cells() {
    final shape = kBdShapes[type - 1];
    final n = shape.n;
    List<List<int>> pts = [for (final p in shape.cells) [p[0], p[1]]];
    for (int k = 0; k < rot; k++) {
      pts = [for (final p in pts) [p[1], n - 1 - p[0]]];
    }
    return [for (final p in pts) [row + p[0], col + p[1]]];
  }
}

class BlockDropEngine {
  static const int rows = 20;
  static const int cols = 10;
  static const List<int> _lineScore = [0, 100, 300, 500, 800];
  static const List<List<int>> _kicks = [[0, 0], [0, -1], [0, 1], [0, -2], [0, 2], [-1, 0], [-1, -1], [-1, 1]];

  final Random rng;
  final List<List<int>> board = List.generate(rows, (_) => List<int>.filled(cols, 0));
  BdPiece? cur;
  int hold = 0;
  bool holdUsed = false;
  final List<int> _bag = <int>[];
  final List<int> next = <int>[];
  int score = 0;
  int lines = 0;
  bool gameOver = false;

  BlockDropEngine(this.rng) {
    _fillNext();
    _spawn();
  }

  int get level => lines ~/ 10 + 1;

  int get gravityMs {
    final int v = 800 - (level - 1) * 65;
    return v < 70 ? 70 : v;
  }

  int _drawType() {
    if (_bag.isEmpty) {
      _bag.addAll([1, 2, 3, 4, 5, 6, 7]);
      _bag.shuffle(rng);
    }
    return _bag.removeLast();
  }

  void _fillNext() {
    while (next.length < 3) { next.add(_drawType()); }
  }

  bool collides(BdPiece p) {
    for (final c in p.cells()) {
      final r = c[0];
      final col = c[1];
      if (col < 0 || col >= cols || r >= rows) return true;
      if (r >= 0 && board[r][col] != 0) return true;
    }
    return false;
  }

  BdPiece _fresh(int type) => BdPiece(type, 0, 0, (cols - kBdShapes[type - 1].n) ~/ 2);

  void _spawn() {
    final t = next.removeAt(0);
    _fillNext();
    cur = _fresh(t);
    holdUsed = false;
    if (collides(cur!)) { gameOver = true; }
  }

  bool _try(BdPiece p) {
    if (collides(p)) return false;
    cur = p;
    return true;
  }

  bool move(int dc) {
    if (gameOver) return false;
    final p = cur!.copy();
    p.col += dc;
    return _try(p);
  }

  bool rotate(bool cw) {
    if (gameOver) return false;
    final c = cur!;
    final nr = (c.rot + (cw ? 1 : 3)) % 4;
    for (final k in _kicks) {
      final p = BdPiece(c.type, nr, c.row + k[0], c.col + k[1]);
      if (!collides(p)) {
        cur = p;
        return true;
      }
    }
    return false;
  }

  bool softDrop() {
    if (gameOver) return false;
    final p = cur!.copy();
    p.row += 1;
    if (_try(p)) {
      score += 1;
      return true;
    }
    return false;
  }

  void hardDrop() {
    if (gameOver) return;
    int d = 0;
    while (true) {
      final p = cur!.copy();
      p.row += 1;
      if (collides(p)) break;
      cur = p;
      d++;
    }
    score += 2 * d;
    _lock();
  }

  /// One step of gravity. Returns true if the piece locked.
  bool tick() {
    if (gameOver) return false;
    final p = cur!.copy();
    p.row += 1;
    if (_try(p)) return false;
    _lock();
    return true;
  }

  BdPiece ghost() {
    BdPiece g = cur!.copy();
    while (true) {
      final p = g.copy();
      p.row += 1;
      if (collides(p)) break;
      g = p;
    }
    return g;
  }

  bool holdPiece() {
    if (gameOver || holdUsed) return false;
    final t = cur!.type;
    if (hold == 0) {
      hold = t;
      _spawn();
    } else {
      final h = hold;
      hold = t;
      cur = _fresh(h);
      if (collides(cur!)) { gameOver = true; }
    }
    holdUsed = true;
    return true;
  }

  void _lock() {
    final p = cur!;
    for (final c in p.cells()) {
      if (c[0] < 0) {
        gameOver = true;
        return;
      }
    }
    for (final c in p.cells()) { board[c[0]][c[1]] = p.type; }
    int cleared = 0;
    for (int r = rows - 1; r >= 0;) {
      if (board[r].every((v) => v != 0)) {
        board.removeAt(r);
        board.insert(0, List<int>.filled(cols, 0));
        cleared++;
      } else {
        r--;
      }
    }
    if (cleared > 0) {
      score += _lineScore[cleared] * level;
      lines += cleared;
    }
    _spawn();
  }
}

class BlockDropScreen extends StatefulWidget {
  const BlockDropScreen({super.key});
  @override
  State<BlockDropScreen> createState() => _BlockDropScreenState();
}

class _BlockDropScreenState extends State<BlockDropScreen> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  BlockDropEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _acc = 0;
  bool _paused = false;
  bool _saved = false;
  int _lastLines = 0;
  Timer? _repeatDelay;
  Timer? _repeatTimer;
  double _dragX = 0;
  double _dragY = 0;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _stopRepeat();
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _ticker.stop();
    setState(() {
      _e = BlockDropEngine(_rng);
      _paused = false;
      _saved = false;
      _acc = 0;
      _lastLines = 0;
    });
    _last = Duration.zero;
    _ticker.start();
    _focus.requestFocus();
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000.0;
    _last = elapsed;
    if (dt > 100) { dt = 100; }
    if (_paused || e.gameOver) return;
    _acc += dt;
    final g = e.gravityMs;
    while (_acc >= g && !e.gameOver) {
      _acc -= g;
      e.tick();
    }
    _afterChange(e);
    setState(() {});
  }

  void _afterChange(BlockDropEngine e) {
    if (e.lines != _lastLines) {
      _lastLines = e.lines;
      SoundService.instance.playCorrect();
    }
    if (e.gameOver && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Block Drop', score: e.score);
      SoundService.instance.playLose();
    }
  }

  void _act(void Function(BlockDropEngine e) f) {
    final e = _e;
    if (e == null || _paused || e.gameOver) return;
    f(e);
    _afterChange(e);
    setState(() {});
  }

  void _startRepeat(void Function(BlockDropEngine e) f, int periodMs) {
    _stopRepeat();
    _act(f);
    _repeatDelay = Timer(const Duration(milliseconds: 170), () {
      _repeatTimer = Timer.periodic(Duration(milliseconds: periodMs), (_) => _act(f));
    });
  }

  void _stopRepeat() {
    _repeatDelay?.cancel();
    _repeatTimer?.cancel();
    _repeatDelay = null;
    _repeatTimer = null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _act((e) => e.move(-1));
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _act((e) => e.move(1));
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _act((e) => e.softDrop());
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyX) {
      _act((e) => e.rotate(true));
    } else if (k == LogicalKeyboardKey.keyZ) {
      _act((e) => e.rotate(false));
    } else if (k == LogicalKeyboardKey.space) {
      _act((e) => e.hardDrop());
    } else if (k == LogicalKeyboardKey.keyC || k == LogicalKeyboardKey.shiftLeft) {
      _act((e) => e.holdPiece());
    } else if (k == LogicalKeyboardKey.keyP) {
      setState(() => _paused = !_paused);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'block_drop',
      title: 'HOW TO PLAY BLOCK DROP',
      steps: const [
        HowToPlayStep(icon: Icons.view_module_rounded, title: 'Clear lines', description: 'Pieces fall from the top. Fill a whole row with no gaps and it disappears. Clearing 4 rows at once scores the most.'),
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Controls', description: 'Use the buttons, or drag on the board to move and tap it to rotate. Keyboard: arrows, Z and X to rotate, Space to drop, C to hold.'),
        HowToPlayStep(icon: Icons.save_alt_rounded, title: 'Hold a piece', description: 'HOLD stores the falling piece for later and swaps it with the stored one. You can hold once per piece.'),
        HowToPlayStep(icon: Icons.speed_rounded, title: 'It speeds up', description: 'Every 10 lines the level goes up and pieces fall faster. The game ends when the stack reaches the top.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(
          title: const Text('BLOCK DROP'),
          actions: [
            if (e != null && !e.gameOver)
              IconButton(icon: Icon(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded), onPressed: () => setState(() => _paused = !_paused)),
          ],
        ),
        body: e == null
            ? _setup()
            : Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: _onKey,
                child: Stack(children: [_game(e), if (_paused && !e.gameOver) _pauseOverlay(), if (e.gameOver) _result(e)]),
              ),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.view_module_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('BLOCK DROP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Stack the falling blocks and clear lines', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: _start,
            child: const Text('PLAY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ),
  );

  Widget _stat(String label, String value) => Column(children: [
    Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
    Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
  ]);

  Widget _ctrl(IconData icon, {VoidCallback? onTap, void Function(BlockDropEngine e)? repeat, int periodMs = 60, double size = 54}) {
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border, width: 1.5)),
      child: Icon(icon, color: GacomColors.textPrimary, size: size * 0.5),
    );
    if (repeat != null) {
      return Listener(
        onPointerDown: (_) => _startRepeat(repeat, periodMs),
        onPointerUp: (_) => _stopRepeat(),
        onPointerCancel: (_) => _stopRepeat(),
        child: child,
      );
    }
    return GestureDetector(onTap: onTap, child: child);
  }

  Widget _game(BlockDropEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      final double availH = cons.maxHeight - 100;
      final double byWidth = (cons.maxWidth - 24 - 96) * 2;
      final double boardH = max(200.0, min(availH, byWidth));
      final double boardW = boardH / 2;
      final double cell = boardW / BlockDropEngine.cols;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _stat('SCORE', '${e.score}'),
            _stat('LEVEL', '${e.level}'),
            _stat('LINES', '${e.lines}'),
          ]),
        ),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => _act((en) => en.rotate(true)),
            onHorizontalDragStart: (_) => _dragX = 0,
            onHorizontalDragUpdate: (d) {
              _dragX += d.delta.dx;
              while (_dragX > cell * 0.9) {
                _act((en) => en.move(1));
                _dragX -= cell * 0.9;
              }
              while (_dragX < -cell * 0.9) {
                _act((en) => en.move(-1));
                _dragX += cell * 0.9;
              }
            },
            onVerticalDragStart: (_) => _dragY = 0,
            onVerticalDragUpdate: (d) {
              _dragY += d.delta.dy;
              while (_dragY > cell * 0.8) {
                _act((en) => en.softDrop());
                _dragY -= cell * 0.8;
              }
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) > 1400) { _act((en) => en.hardDrop()); }
            },
            child: Container(
              width: boardW,
              height: boardH,
              decoration: BoxDecoration(border: Border.all(color: GacomColors.border, width: 2), borderRadius: BorderRadius.circular(4)),
              child: CustomPaint(painter: _BdBoardPainter(e)),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Column(children: [
              const Text('HOLD', style: TextStyle(color: GacomColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              SizedBox(width: 60, height: 60, child: CustomPaint(painter: _BdMiniPainter(e.hold, dim: e.holdUsed))),
              const SizedBox(height: 14),
              const Text('NEXT', style: TextStyle(color: GacomColors.textMuted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
              const SizedBox(height: 4),
              for (final t in e.next) SizedBox(width: 60, height: 50, child: CustomPaint(painter: _BdMiniPainter(t))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _ctrl(Icons.arrow_left_rounded, repeat: (en) => en.move(-1), periodMs: 70),
          const SizedBox(width: 8),
          _ctrl(Icons.arrow_drop_down_rounded, repeat: (en) => en.softDrop(), periodMs: 45),
          const SizedBox(width: 8),
          _ctrl(Icons.arrow_right_rounded, repeat: (en) => en.move(1), periodMs: 70),
          const SizedBox(width: 18),
          _ctrl(Icons.rotate_right_rounded, onTap: () => _act((en) => en.rotate(true))),
          const SizedBox(width: 8),
          _ctrl(Icons.vertical_align_bottom_rounded, onTap: () => _act((en) => en.hardDrop())),
          const SizedBox(width: 8),
          _ctrl(Icons.save_alt_rounded, onTap: () => _act((en) => en.holdPiece())),
        ]),
      ]);
    });
  }

  Widget _pauseOverlay() => Container(
    color: Colors.black.withValues(alpha: 0.75),
    child: Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
        onPressed: () => setState(() => _paused = false),
        child: const Text('RESUME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    ),
  );

  Widget _result(BlockDropEngine e) => Container(
    color: Colors.black.withValues(alpha: 0.82),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 52),
          const SizedBox(height: 12),
          const Text('GAME OVER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Score ${e.score}  -  Level ${e.level}  -  ${e.lines} lines', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _start,
              child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class _BdBoardPainter extends CustomPainter {
  final BlockDropEngine e;
  _BdBoardPainter(this.e);

  void _block(Canvas canvas, double cell, int r, int c, Color color, {bool outline = false}) {
    final rect = Rect.fromLTWH(c * cell + 0.5, r * cell + 0.5, cell - 1, cell - 1);
    if (outline) {
      canvas.drawRect(rect.deflate(1), Paint()..color = color.withValues(alpha: 0.55)..style = PaintingStyle.stroke..strokeWidth = 1.5);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), Paint()..color = color);
      canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(cell * 0.18), const Radius.circular(2)), Paint()..color = Colors.white.withValues(alpha: 0.18));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / BlockDropEngine.cols;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0B0D13));
    final grid = Paint()..color = const Color(0x14FFFFFF)..strokeWidth = 1;
    for (int i = 1; i < BlockDropEngine.cols; i++) { canvas.drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), grid); }
    for (int i = 1; i < BlockDropEngine.rows; i++) { canvas.drawLine(Offset(0, i * cell), Offset(size.width, i * cell), grid); }
    for (int r = 0; r < BlockDropEngine.rows; r++) {
      for (int c = 0; c < BlockDropEngine.cols; c++) {
        final v = e.board[r][c];
        if (v != 0) { _block(canvas, cell, r, c, kBdColors[v]); }
      }
    }
    final cur = e.cur;
    if (cur != null && !e.gameOver) {
      for (final p in e.ghost().cells()) {
        if (p[0] >= 0) { _block(canvas, cell, p[0], p[1], kBdColors[cur.type], outline: true); }
      }
      for (final p in cur.cells()) {
        if (p[0] >= 0) { _block(canvas, cell, p[0], p[1], kBdColors[cur.type]); }
      }
    }
  }

  @override
  bool shouldRepaint(_BdBoardPainter oldDelegate) => true;
}

class _BdMiniPainter extends CustomPainter {
  final int type;
  final bool dim;
  _BdMiniPainter(this.type, {this.dim = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 0) return;
    final shape = kBdShapes[type - 1];
    final cell = min(size.width, size.height) / 4.2;
    int minR = 9;
    int maxR = 0;
    int minC = 9;
    int maxC = 0;
    for (final p in shape.cells) {
      minR = min(minR, p[0]);
      maxR = max(maxR, p[0]);
      minC = min(minC, p[1]);
      maxC = max(maxC, p[1]);
    }
    final double w = (maxC - minC + 1) * cell;
    final double h = (maxR - minR + 1) * cell;
    final double ox = (size.width - w) / 2;
    final double oy = (size.height - h) / 2;
    final color = dim ? kBdColors[type].withValues(alpha: 0.35) : kBdColors[type];
    for (final p in shape.cells) {
      final rect = Rect.fromLTWH(ox + (p[1] - minC) * cell + 0.5, oy + (p[0] - minR) * cell + 0.5, cell - 1, cell - 1);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BdMiniPainter oldDelegate) => oldDelegate.type != type || oldDelegate.dim != dim;
}
