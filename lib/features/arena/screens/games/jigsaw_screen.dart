import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/arcade_kit.dart';

class JigPiece {
  final int id;
  final int row;
  final int col;
  double x = 0.0; // top-left in cell units (1.0 = one cell)
  double y = 0.0;
  bool locked = false;
  int z = 0;
  JigPiece(this.id, this.row, this.col);
}

/// Jigsaw logic in cell units. Piece (row, col) belongs at x = col, y = row.
class JigsawEngine {
  static const double snap = 0.35;
  static const double tabDepth = 0.19; // how far a tab sticks out, in cells
  static const double margin = 0.3; // extra picture area drawn around each piece

  final Random rng;
  final int rows;
  final int cols;
  final List<JigPiece> pieces = <JigPiece>[];
  late final List<List<int>> hEdges; // [row][col] edge between (row,col) and (row,col+1)
  late final List<List<int>> vEdges; // [row][col] edge between (row,col) and (row+1,col)
  int moves = 0;
  int zCounter = 0;
  bool scattered = false;
  final Stopwatch clock = Stopwatch();

  JigsawEngine(this.rng, this.rows, this.cols) {
    hEdges = List<List<int>>.generate(rows, (_) => List<int>.generate(max(0, cols - 1), (_) => rng.nextBool() ? 1 : -1));
    vEdges = List<List<int>>.generate(max(0, rows - 1), (_) => List<int>.generate(cols, (_) => rng.nextBool() ? 1 : -1));
    int id = 0;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        pieces.add(JigPiece(id, r, c));
        id++;
      }
    }
  }

  /// Tab direction for one side of a piece: +1 sticks out, -1 is a dent, 0 is a flat border.
  /// Sides: 0 top, 1 right, 2 bottom, 3 left.
  int edgeDir(int row, int col, int side) {
    switch (side) {
      case 0:
        return row == 0 ? 0 : -vEdges[row - 1][col];
      case 1:
        return col == cols - 1 ? 0 : hEdges[row][col];
      case 2:
        return row == rows - 1 ? 0 : vEdges[row][col];
      default:
        return col == 0 ? 0 : -hEdges[row][col - 1];
    }
  }

  void scatter(double minX, double maxX, double minY, double maxY) {
    final List<JigPiece> order = List<JigPiece>.from(pieces)..shuffle(rng);
    final int n = order.length;
    final int perRow = max(1, min(cols + 1, n));
    final int rowsNeeded = (n / perRow).ceil();
    final double stepX = perRow > 1 ? (maxX - minX) / (perRow - 1) : 0.0;
    final double stepY = rowsNeeded > 1 ? (maxY - minY) / (rowsNeeded - 1) : 0.0;
    for (int i = 0; i < n; i++) {
      final int rr = i ~/ perRow;
      final int cc = i % perRow;
      final p = order[i];
      p.x = minX + stepX * cc + (rng.nextDouble() - 0.5) * 0.25;
      p.y = minY + stepY * rr + (rng.nextDouble() - 0.5) * 0.25;
      p.locked = false;
      p.z = zCounter++;
    }
    scattered = true;
    clock
      ..reset()
      ..start();
  }

  /// Top-most unlocked piece whose cell box (plus a little room for tabs) contains (x, y).
  JigPiece? pick(double x, double y) {
    JigPiece? best;
    for (final p in pieces) {
      if (p.locked) continue;
      if (x >= p.x - 0.12 && x <= p.x + 1.12 && y >= p.y - 0.12 && y <= p.y + 1.12) {
        if (best == null || p.z > best.z) best = p;
      }
    }
    return best;
  }

  void bringToFront(JigPiece p) {
    p.z = zCounter++;
  }

  /// Called when a piece is released. Returns true when it snapped into place.
  bool drop(JigPiece p) {
    moves++;
    final double dx = p.x - p.col;
    final double dy = p.y - p.row;
    if (dx * dx + dy * dy <= snap * snap) {
      p.x = p.col.toDouble();
      p.y = p.row.toDouble();
      p.locked = true;
      return true;
    }
    return false;
  }

  int get lockedCount {
    int n = 0;
    for (final p in pieces) {
      if (p.locked) n++;
    }
    return n;
  }

  bool get solved => lockedCount == pieces.length;

  int get seconds => clock.elapsed.inSeconds;

  int get score {
    final int timeLeft = pieces.length * 40 - seconds;
    final int moveLeft = pieces.length * 6 - moves;
    final int timeBonus = timeLeft > 0 ? timeLeft : 0;
    final int moveBonus = moveLeft > 0 ? moveLeft : 0;
    return pieces.length * 60 + timeBonus + moveBonus;
  }

  /// Outline of one piece in cell units, relative to its own top-left corner.
  Path piecePath(int row, int col) {
    final Path path = Path();
    final List<Offset> corners = const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
    path.moveTo(0, 0);
    for (int side = 0; side < 4; side++) {
      final Offset a = corners[side];
      final Offset b = corners[(side + 1) % 4];
      _edge(path, a, b, edgeDir(row, col, side).toDouble());
    }
    path.close();
    return path;
  }

  void _edge(Path path, Offset a, Offset b, double d) {
    final double ex = b.dx - a.dx;
    final double ey = b.dy - a.dy;
    // local frame: x along the edge, y turns clockwise so that -y is outward
    final double fx = -ey;
    final double fy = ex;
    Offset at(double u, double v) => Offset(a.dx + ex * u + fx * v, a.dy + ey * u + fy * v);
    if (d == 0.0) {
      path.lineTo(b.dx, b.dy);
      return;
    }
    final double t = tabDepth / 0.19 * d; // scale of the bump
    final p1 = at(0.35, 0.0);
    path.lineTo(p1.dx, p1.dy);
    final c1a = at(0.35, -0.03 * t);
    final c1b = at(0.40, -0.06 * t);
    final e1 = at(0.38, -0.10 * t);
    path.cubicTo(c1a.dx, c1a.dy, c1b.dx, c1b.dy, e1.dx, e1.dy);
    final c2a = at(0.30, -0.24 * t);
    final c2b = at(0.70, -0.24 * t);
    final e2 = at(0.62, -0.10 * t);
    path.cubicTo(c2a.dx, c2a.dy, c2b.dx, c2b.dy, e2.dx, e2.dy);
    final c3a = at(0.60, -0.06 * t);
    final c3b = at(0.65, -0.03 * t);
    final e3 = at(0.65, 0.0);
    path.cubicTo(c3a.dx, c3a.dy, c3b.dx, c3b.dy, e3.dx, e3.dy);
    path.lineTo(b.dx, b.dy);
  }
}

/// Procedural pictures so the puzzle needs no downloaded images.
class JigsawArt {
  static const int count = 5;
  static const List<String> names = ['SUNSET HILLS', 'NIGHT CITY', 'TROPICAL ISLAND', 'COLOUR MOSAIC', 'DEEP SPACE'];

  static void paint(Canvas canvas, Size size, int index) {
    final double w = size.width;
    final double h = size.height;
    final rng = Random(1000 + index);
    switch (index % count) {
      case 0:
      {
        canvas.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [Color(0xFF3B1F6B), Color(0xFFE2557A), Color(0xFFFFB347)], const [0.0, 0.55, 0.85]));
        canvas.drawCircle(Offset(w * 0.68, h * 0.55), w * 0.13, Paint()..color = const Color(0xFFFFF2B0));
        for (int i = 0; i < 6; i++) {
          final double bx = w * (0.1 + rng.nextDouble() * 0.5);
          final double by = h * (0.1 + rng.nextDouble() * 0.25);
          final p = Path()..moveTo(bx, by)..quadraticBezierTo(bx + 10, by - 8, bx + 20, by)..quadraticBezierTo(bx + 30, by - 8, bx + 40, by);
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = Colors.black54);
        }
        const hills = [Color(0xFF7A3E7A), Color(0xFF4A2A64), Color(0xFF241638)];
        for (int k = 0; k < 3; k++) {
          final p = Path()..moveTo(0, h);
          final double base = h * (0.62 + k * 0.12);
          for (int i = 0; i <= 20; i++) {
            final double x = w * i / 20.0;
            final double y = base + sin(i * 0.55 + k * 1.7) * h * 0.05 + cos(i * 0.21 + k) * h * 0.03;
            p.lineTo(x, y);
          }
          p.lineTo(w, h);
          p.close();
          canvas.drawPath(p, Paint()..color = hills[k]);
        }
        break;
      }
      case 1:
      {
        canvas.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [Color(0xFF050A24), Color(0xFF2B2A6B), Color(0xFF6B4A8A)]));
        for (int i = 0; i < 70; i++) {
          canvas.drawCircle(Offset(rng.nextDouble() * w, rng.nextDouble() * h * 0.6), rng.nextDouble() * 1.8 + 0.4, Paint()..color = Colors.white70);
        }
        canvas.drawCircle(Offset(w * 0.8, h * 0.18), w * 0.07, Paint()..color = const Color(0xFFFFF7D0));
        double x = 0.0;
        while (x < w) {
          final double bw = w * (0.06 + rng.nextDouble() * 0.08);
          final double bh = h * (0.22 + rng.nextDouble() * 0.38);
          canvas.drawRect(Rect.fromLTWH(x, h - bh, bw, bh), Paint()..color = Color.lerp(const Color(0xFF10132E), const Color(0xFF1C2050), rng.nextDouble())!);
          for (double wy = h - bh + 8; wy < h - 8; wy += 12) {
            for (double wx = x + 4; wx < x + bw - 6; wx += 9) {
              if (rng.nextDouble() < 0.55) canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 6), Paint()..color = const Color(0xFFFFD866));
            }
          }
          x += bw + 2;
        }
        break;
      }
      case 2:
      {
        canvas.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), const [Color(0xFF58C6F5), Color(0xFFB8ECFF)], const [0.0, 0.5]));
        canvas.drawCircle(Offset(w * 0.2, h * 0.2), w * 0.09, Paint()..color = const Color(0xFFFFE34D));
        canvas.drawRect(Rect.fromLTWH(0, h * 0.5, w, h * 0.5), Paint()..shader = ui.Gradient.linear(Offset(0, h * 0.5), Offset(0, h), const [Color(0xFF1AA6C8), Color(0xFF0B4E8C)]));
        for (int i = 0; i < 26; i++) {
          final double wx = rng.nextDouble() * w;
          final double wy = h * (0.52 + rng.nextDouble() * 0.46);
          final p = Path()..moveTo(wx, wy)..quadraticBezierTo(wx + 9, wy - 6, wx + 18, wy)..quadraticBezierTo(wx + 27, wy + 6, wx + 36, wy);
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = Colors.white54);
        }
        final island = Path()..moveTo(w * 0.3, h * 0.62)..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.72, h * 0.62)..close();
        canvas.drawPath(island, Paint()..color = const Color(0xFFE8C77A));
        final trunk = Path()..moveTo(w * 0.52, h * 0.55)..quadraticBezierTo(w * 0.56, h * 0.4, w * 0.5, h * 0.28);
        canvas.drawPath(trunk, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = const Color(0xFF7A4A21)..strokeCap = StrokeCap.round);
        for (int i = 0; i < 6; i++) {
          final double a = -pi / 2 + (i - 2.5) * 0.55;
          final p = Path()..moveTo(w * 0.5, h * 0.28)..quadraticBezierTo(w * 0.5 + cos(a) * 40, h * 0.28 + sin(a) * 40 - 10, w * 0.5 + cos(a) * 70, h * 0.28 + sin(a) * 55 + 18);
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = const Color(0xFF1E8E3E)..strokeCap = StrokeCap.round);
        }
        break;
      }
      case 3:
      {
        const palette = [Color(0xFFE53935), Color(0xFFFB8C00), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFEC407A), Color(0xFF00ACC1)];
        const int cells = 8;
        final double cw = w / cells;
        final double ch = h / cells;
        for (int r = 0; r < cells; r++) {
          for (int c = 0; c < cells; c++) {
            final Color a = palette[rng.nextInt(palette.length)];
            final Color b = palette[rng.nextInt(palette.length)];
            final Rect rect = Rect.fromLTWH(c * cw, r * ch, cw, ch);
            canvas.drawRect(rect, Paint()..color = a);
            final int shape = rng.nextInt(3);
            if (shape == 0) {
              canvas.drawCircle(rect.center, cw * 0.32, Paint()..color = b);
            } else if (shape == 1) {
              final tri = Path()..moveTo(rect.left, rect.bottom)..lineTo(rect.right, rect.bottom)..lineTo(rect.center.dx, rect.top)..close();
              canvas.drawPath(tri, Paint()..color = b);
            } else {
              canvas.drawRect(rect.deflate(cw * 0.25), Paint()..color = b);
            }
          }
        }
        break;
      }
      default:
      {
        canvas.drawRect(Offset.zero & size, Paint()..shader = ui.Gradient.radial(Offset(w * 0.35, h * 0.4), w * 0.9, const [Color(0xFF2A1B5E), Color(0xFF05020F)]));
        for (int i = 0; i < 120; i++) {
          canvas.drawCircle(Offset(rng.nextDouble() * w, rng.nextDouble() * h), rng.nextDouble() * 1.6 + 0.3, Paint()..color = Colors.white.withValues(alpha: 0.4 + rng.nextDouble() * 0.6));
        }
        canvas.drawCircle(Offset(w * 0.38, h * 0.45), w * 0.2, Paint()..shader = ui.Gradient.linear(Offset(w * 0.2, h * 0.3), Offset(w * 0.55, h * 0.6), const [Color(0xFFFF8F3D), Color(0xFF8A2D6B)]));
        canvas.save();
        canvas.translate(w * 0.38, h * 0.45);
        canvas.rotate(-0.4);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.62, height: w * 0.14), Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = const Color(0xFFFFD27F).withValues(alpha: 0.85));
        canvas.restore();
        canvas.drawCircle(Offset(w * 0.8, h * 0.2), w * 0.05, Paint()..color = const Color(0xFF7AD7F0));
        canvas.drawLine(Offset(w * 0.9, h * 0.72), Offset(w * 0.62, h * 0.86), Paint()..color = Colors.white70..strokeWidth = 3);
        canvas.drawCircle(Offset(w * 0.9, h * 0.72), 5, Paint()..color = Colors.white);
        break;
      }
    }
  }
}

class JigsawScreen extends StatefulWidget {
  const JigsawScreen({super.key});
  @override
  State<JigsawScreen> createState() => _JigsawScreenState();
}

class _JigsawScreenState extends State<JigsawScreen> {
  static const List<String> _sizes = ['3 x 3', '4 x 4', '5 x 5'];
  static const List<int> _dims = [3, 4, 5];
  final Random _rng = Random();
  JigsawEngine? _e;
  ui.Image? _image;
  int _level = 0;
  int _art = 0;
  bool _saved = false;
  bool _preview = false;
  bool _building = false;
  JigPiece? _held;
  Offset _grab = Offset.zero;
  double _cs = 60.0;
  Offset _origin = Offset.zero;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_building) return;
    setState(() => _building = true);
    const double side = 720.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    JigsawArt.paint(canvas, const Size(side, side), _art);
    final picture = recorder.endRecording();
    final img = await picture.toImage(side.toInt(), side.toInt());
    if (!mounted) {
      img.dispose();
      return;
    }
    _image?.dispose();
    final int n = _dims[_level];
    setState(() {
      _image = img;
      _e = JigsawEngine(_rng, n, n);
      _saved = false;
      _preview = false;
      _held = null;
      _building = false;
    });
  }

  void _toSetup() {
    setState(() => _e = null);
  }

  Offset _toCells(Offset px) => Offset((px.dx - _origin.dx) / _cs, (px.dy - _origin.dy) / _cs);

  void _down(Offset p) {
    final e = _e;
    if (e == null || e.solved || _preview) return;
    final c = _toCells(p);
    final piece = e.pick(c.dx, c.dy);
    if (piece == null) return;
    e.bringToFront(piece);
    _held = piece;
    _grab = Offset(c.dx - piece.x, c.dy - piece.y);
    setState(() {});
  }

  void _move(Offset p) {
    final piece = _held;
    if (piece == null) return;
    final c = _toCells(p);
    piece.x = c.dx - _grab.dx;
    piece.y = c.dy - _grab.dy;
    setState(() {});
  }

  void _up() {
    final e = _e;
    final piece = _held;
    _held = null;
    if (e == null || piece == null) return;
    final bool snapped = e.drop(piece);
    if (snapped) {
      SoundService.instance.playCorrect();
      if (e.solved) {
        e.clock.stop();
        if (!_saved) {
          _saved = true;
          GameScoreService.save(gameName: 'Jigsaw Puzzle', score: e.score, won: true);
          SoundService.instance.playWin();
        }
      }
    } else {
      SoundService.instance.playTap();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'jigsaw',
      title: 'HOW TO PLAY JIGSAW',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Drag the pieces', description: 'The pieces start in a pile below the board. Press a piece and drag it onto the board.'),
        HowToPlayStep(icon: Icons.extension_rounded, title: 'Match the shapes', description: 'Every piece has a place. Match the picture and the tabs. Drop it near the right spot and it snaps in and locks.'),
        HowToPlayStep(icon: Icons.visibility_rounded, title: 'Peek at the picture', description: 'Press and hold PREVIEW to see the finished picture while you work.'),
        HowToPlayStep(icon: Icons.timer_rounded, title: 'Be quick and neat', description: 'Your score rises with the number of pieces and falls with time and extra moves. Finish the picture to win.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('JIGSAW PUZZLE')),
        body: e == null || _image == null
            ? ArcadeStartView(
                icon: Icons.extension_rounded,
                title: 'JIGSAW PUZZLE',
                subtitle: _building ? 'Cutting the pieces...' : 'Rebuild the picture piece by piece.',
                buttonLabel: 'START',
                onStart: _start,
                extra: [
                  ArcadeChoiceRow(label: 'PIECES', options: _sizes, selected: _level, onSelect: (i) => setState(() => _level = i)),
                  const SizedBox(height: 16),
                  ArcadeChoiceRow(label: 'PICTURE', options: const ['1', '2', '3', '4', '5'], selected: _art, onSelect: (i) => setState(() => _art = i)),
                  const SizedBox(height: 6),
                  Text(JigsawArt.names[_art], style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, letterSpacing: 1)),
                ],
              )
            : Stack(children: [_game(e), if (e.solved) _result(e)]),
      ),
    );
  }

  Widget _game(JigsawEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      final double availH = cons.maxHeight - 56.0;
      double board = min(cons.maxWidth - 24.0, availH * 0.5);
      final double cs = board / e.cols;
      board = cs * e.cols;
      _cs = cs;
      _origin = Offset((cons.maxWidth - board) / 2.0, 44.0);
      if (!e.scattered) {
        final double trayTop = e.rows + 0.45;
        final double trayBottomPx = cons.maxHeight - 8.0;
        final double trayBottom = (trayBottomPx - _origin.dy) / cs - 1.1;
        final double minX = (12.0 - _origin.dx) / cs;
        final double maxX = (cons.maxWidth - 12.0 - _origin.dx) / cs - 1.0;
        e.scatter(minX, maxX, trayTop, max(trayTop, trayBottom));
      }
      return Stack(children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: (d) => _down(d.localPosition),
            onPointerMove: (d) => _move(d.localPosition),
            onPointerUp: (_) => _up(),
            onPointerCancel: (_) => _up(),
            child: CustomPaint(painter: _JigPainter(e, _image!, _origin, cs, _preview)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 6,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${e.lockedCount}/${e.pieces.length}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary)),
            const SizedBox(width: 14),
            Text('${e.seconds ~/ 60}:${(e.seconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textMuted)),
            const SizedBox(width: 14),
            Listener(
              onPointerDown: (_) => setState(() => _preview = true),
              onPointerUp: (_) => setState(() => _preview = false),
              onPointerCancel: (_) => setState(() => _preview = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: GacomColors.deepOrange), borderRadius: BorderRadius.circular(20)),
                child: const Text('HOLD: PREVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GacomColors.deepOrange)),
              ),
            ),
          ]),
        ),
      ]);
    });
  }

  Widget _result(JigsawEngine e) {
    return ArcadeResultOverlay(
      good: true,
      title: 'PUZZLE COMPLETE!',
      detail: '${e.seconds}s, ${e.moves} moves. Score ${e.score}',
      onAgain: _toSetup,
      onExit: () => Navigator.pop(context),
      againLabel: 'NEW PUZZLE',
    );
  }
}

class _JigPainter extends CustomPainter {
  final JigsawEngine e;
  final ui.Image image;
  final Offset origin;
  final double cs;
  final bool preview;
  _JigPainter(this.e, this.image, this.origin, this.cs, this.preview);

  @override
  void paint(Canvas canvas, Size size) {
    final double board = cs * e.cols;
    final boardRect = Rect.fromLTWH(origin.dx, origin.dy, board, board);
    canvas.drawRect(boardRect, Paint()..color = const Color(0xFF0E1424));
    final double iw = image.width.toDouble();
    final double ih = image.height.toDouble();
    final double unitSrc = iw / e.cols; // image pixels per cell
    // faint ghost of the picture, and the full picture while previewing
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, iw, ih), boardRect, Paint()..color = Colors.white.withValues(alpha: preview ? 1.0 : 0.12));
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white12;
    for (int i = 0; i <= e.cols; i++) {
      canvas.drawLine(Offset(origin.dx + i * cs, origin.dy), Offset(origin.dx + i * cs, origin.dy + board), grid);
      canvas.drawLine(Offset(origin.dx, origin.dy + i * cs), Offset(origin.dx + board, origin.dy + i * cs), grid);
    }
    if (preview) return;
    final List<JigPiece> order = List<JigPiece>.from(e.pieces)..sort((a, b) => a.locked == b.locked ? a.z.compareTo(b.z) : (a.locked ? -1 : 1));
    for (final p in order) {
      final double m = JigsawEngine.margin;
      final Rect src = Rect.fromLTWH((p.col - m) * unitSrc, (p.row - m) * unitSrc, (1 + 2 * m) * unitSrc, (1 + 2 * m) * unitSrc);
      final Rect dst = Rect.fromLTWH(origin.dx + (p.x - m) * cs, origin.dy + (p.y - m) * cs, (1 + 2 * m) * cs, (1 + 2 * m) * cs);
      final Path path = e.piecePath(p.row, p.col).transform(Matrix4.identity().scaled(cs, cs).storage).shift(Offset(origin.dx + p.x * cs, origin.dy + p.y * cs));
      if (!p.locked) {
        canvas.drawPath(path.shift(const Offset(2, 3)), Paint()..color = Colors.black45);
      }
      canvas.save();
      canvas.clipPath(path);
      // clip the source rect to the picture so edge pieces don't sample outside it
      final double l = max(src.left, 0.0);
      final double t = max(src.top, 0.0);
      final double r = min(src.right, iw);
      final double b = min(src.bottom, ih);
      final Rect srcC = Rect.fromLTRB(l, t, r, b);
      final Rect dstC = Rect.fromLTRB(
        dst.left + (l - src.left) / src.width * dst.width,
        dst.top + (t - src.top) / src.height * dst.height,
        dst.right - (src.right - r) / src.width * dst.width,
        dst.bottom - (src.bottom - b) / src.height * dst.height,
      );
      canvas.drawImageRect(image, srcC, dstC, Paint()..filterQuality = FilterQuality.medium);
      canvas.restore();
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = p.locked ? 0.8 : 1.6..color = p.locked ? Colors.black26 : Colors.white70);
    }
  }

  @override
  bool shouldRepaint(_JigPainter oldDelegate) => true;
}
