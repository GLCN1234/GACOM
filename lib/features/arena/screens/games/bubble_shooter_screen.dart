import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';

const List<Color> kBbColors = [
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFFEE58),
  Color(0xFFAB47BC),
  Color(0xFF26C6DA),
];

/// Bubble radius is 1 unit. Even-offset rows hold 11 bubbles, the others 10.
class BubbleEngine {
  static const int maxRows = 14;
  static const int dangerRow = 11;
  static const double rowStep = 1.7320508075688772; // sqrt(3)
  static const double fieldW = 22.0;
  static const double fieldH = 25.0;
  static const double shooterX = 11.0;
  static const double shooterY = 23.0;
  static const double speed = 42.0;

  final Random rng;
  final List<List<int>> grid = List.generate(maxRows, (_) => List<int>.filled(11, -1));
  int shift = 0;
  int colors = 4;
  int level = 1;
  int score = 0;
  int misses = 0;
  bool gameOver = false;
  int current = 0;
  int next = 0;
  int levelUps = 0;

  bool flying = false;
  double px = shooterX;
  double py = shooterY;
  double vx = 0;
  double vy = 0;
  int lastPopped = 0;
  int lastDropped = 0;
  bool lastPushed = false;

  BubbleEngine(this.rng) {
    _newBoard();
    current = _pickColor();
    next = _pickColor();
  }

  int get missLimit {
    final int v = 7 - level ~/ 2;
    return v < 3 ? 3 : v;
  }

  int colsOf(int r) => ((r + shift) % 2 == 0) ? 11 : 10;
  double xOf(int r, int c) => ((r + shift) % 2 == 0) ? 1.0 + 2.0 * c : 2.0 + 2.0 * c;
  double yOf(int r) => 1.0 + r * rowStep;

  List<List<int>> neighbors(int r, int c) {
    final out = <List<int>>[];
    void add(int rr, int cc) {
      if (rr >= 0 && rr < maxRows && cc >= 0 && cc < colsOf(rr)) { out.add([rr, cc]); }
    }
    add(r, c - 1);
    add(r, c + 1);
    final even = (r + shift) % 2 == 0;
    final offs = even ? [c - 1, c] : [c, c + 1];
    for (final rr in [r - 1, r + 1]) {
      for (final cc in offs) { add(rr, cc); }
    }
    return out;
  }

  int get count {
    int n = 0;
    for (final row in grid) {
      for (final v in row) {
        if (v >= 0) { n++; }
      }
    }
    return n;
  }

  Set<int> _colorsOnBoard() {
    final s = <int>{};
    for (final row in grid) {
      for (final v in row) {
        if (v >= 0) { s.add(v); }
      }
    }
    return s;
  }

  int _pickColor() {
    final s = _colorsOnBoard().toList();
    if (s.isEmpty) return rng.nextInt(colors);
    return s[rng.nextInt(s.length)];
  }

  void _newBoard() {
    for (final row in grid) {
      for (int c = 0; c < row.length; c++) { row[c] = -1; }
    }
    shift = 0;
    final int rows = min(4 + level, 8);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < colsOf(r); c++) { grid[r][c] = rng.nextInt(colors); }
    }
  }

  void swap() {
    if (flying || gameOver) return;
    final t = current;
    current = next;
    next = t;
  }

  void shoot(double angle) {
    if (flying || gameOver) return;
    px = shooterX;
    py = shooterY;
    vx = cos(angle) * speed;
    vy = -sin(angle) * speed;
    flying = true;
  }

  bool _hitsAt(double x, double y) {
    if (y <= 1.0) return true;
    for (int r = 0; r < maxRows; r++) {
      final yy = yOf(r);
      if ((yy - y).abs() > 2.0) continue;
      for (int c = 0; c < colsOf(r); c++) {
        if (grid[r][c] < 0) continue;
        final dx = xOf(r, c) - x;
        final dy = yy - y;
        if (dx * dx + dy * dy < 3.4) return true;
      }
    }
    return false;
  }

  /// Advances the flying bubble. Returns true on the frame it lands.
  bool update(double dt) {
    if (!flying) return false;
    final double dist = speed * dt;
    final int steps = max(1, (dist / 0.4).ceil());
    final double h = dt / steps;
    for (int i = 0; i < steps; i++) {
      px += vx * h;
      py += vy * h;
      if (px < 1.0) {
        px = 2.0 - px;
        vx = -vx;
      } else if (px > fieldW - 1.0) {
        px = 2.0 * (fieldW - 1.0) - px;
        vx = -vx;
      }
      if (_hitsAt(px, py)) {
        _land();
        return true;
      }
    }
    return false;
  }

  /// Points along the aim path (start, each wall bounce, end) for the guide line.
  List<List<double>> preview(double angle) {
    double x = shooterX;
    double y = shooterY;
    double dx = cos(angle);
    double dy = -sin(angle);
    final pts = <List<double>>[[x, y]];
    for (int i = 0; i < 600; i++) {
      x += dx * 0.4;
      y += dy * 0.4;
      if (x < 1.0) {
        x = 2.0 - x;
        dx = -dx;
        pts.add([x, y]);
      } else if (x > fieldW - 1.0) {
        x = 2.0 * (fieldW - 1.0) - x;
        dx = -dx;
        pts.add([x, y]);
      }
      if (_hitsAt(x, y)) break;
    }
    pts.add([x, y]);
    return pts;
  }

  void _land() {
    final r0 = ((py - 1.0) / rowStep).round();
    int br = -1;
    int bc = -1;
    double bd = 1e18;
    for (int pass = 0; pass < 2 && br < 0; pass++) {
      final int lo = pass == 0 ? max(0, r0 - 2) : 0;
      final int hi = pass == 0 ? min(maxRows - 1, r0 + 2) : maxRows - 1;
      for (int r = lo; r <= hi; r++) {
        for (int c = 0; c < colsOf(r); c++) {
          if (grid[r][c] != -1) continue;
          bool ok = r == 0;
          if (!ok) {
            for (final nb in neighbors(r, c)) {
              if (grid[nb[0]][nb[1]] >= 0) {
                ok = true;
                break;
              }
            }
          }
          if (!ok) continue;
          final dx = xOf(r, c) - px;
          final dy = yOf(r) - py;
          final d = dx * dx + dy * dy;
          if (d < bd) {
            bd = d;
            br = r;
            bc = c;
          }
        }
      }
    }
    if (br < 0) {
      flying = false;
      return;
    }
    placeAndResolve(br, bc, current);
  }

  /// Puts a bubble on the grid and plays out the consequences. Public so
  /// the logic can be exercised directly.
  void placeAndResolve(int r, int c, int color) {
    grid[r][c] = color;
    lastPopped = 0;
    lastDropped = 0;
    lastPushed = false;
    final cluster = <int>[];
    final seen = <int>{r * 11 + c};
    final queue = <List<int>>[[r, c]];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      cluster.add(cur[0] * 11 + cur[1]);
      for (final nb in neighbors(cur[0], cur[1])) {
        final key = nb[0] * 11 + nb[1];
        if (!seen.contains(key) && grid[nb[0]][nb[1]] == color) {
          seen.add(key);
          queue.add(nb);
        }
      }
    }
    if (cluster.length >= 3) {
      for (final k in cluster) { grid[k ~/ 11][k % 11] = -1; }
      lastPopped = cluster.length;
      score += cluster.length * 10 + (cluster.length - 3) * 5;
      final int dropped = _dropFloating();
      lastDropped = dropped;
      score += dropped * 20;
      misses = 0;
    } else {
      misses++;
    }
    flying = false;
    if (count == 0) {
      level++;
      levelUps++;
      score += 500;
      colors = min(6, 3 + level);
      _newBoard();
    } else if (misses >= missLimit) {
      pushRow();
      misses = 0;
      lastPushed = true;
    }
    for (int rr = dangerRow; rr < maxRows; rr++) {
      for (int cc = 0; cc < colsOf(rr); cc++) {
        if (grid[rr][cc] >= 0) { gameOver = true; }
      }
    }
    // The shot bubble is used up. The waiting bubble is loaded next, but
    // only if its colour is still on the board (otherwise it could never
    // be matched), and a fresh one is queued behind it.
    final present = _colorsOnBoard();
    int loaded = next;
    if (present.isNotEmpty && !present.contains(loaded)) { loaded = _pickColor(); }
    current = loaded;
    next = _pickColor();
  }

  /// Removes every bubble not connected to the ceiling. Returns how many.
  int _dropFloating() {
    final connected = <int>{};
    final queue = <List<int>>[];
    for (int c = 0; c < colsOf(0); c++) {
      if (grid[0][c] >= 0) {
        connected.add(c);
        queue.add([0, c]);
      }
    }
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final nb in neighbors(cur[0], cur[1])) {
        final key = nb[0] * 11 + nb[1];
        if (grid[nb[0]][nb[1]] >= 0 && !connected.contains(key)) {
          connected.add(key);
          queue.add(nb);
        }
      }
    }
    int dropped = 0;
    for (int r = 0; r < maxRows; r++) {
      for (int c = 0; c < colsOf(r); c++) {
        if (grid[r][c] >= 0 && !connected.contains(r * 11 + c)) {
          grid[r][c] = -1;
          dropped++;
        }
      }
    }
    return dropped;
  }

  void pushRow() {
    grid.removeLast();
    shift = 1 - shift;
    final row = List<int>.filled(11, -1);
    for (int c = 0; c < colsOf(0); c++) { row[c] = rng.nextInt(colors); }
    grid.insert(0, row);
  }
}

class BubbleShooterScreen extends StatefulWidget {
  const BubbleShooterScreen({super.key});
  @override
  State<BubbleShooterScreen> createState() => _BubbleShooterScreenState();
}

class _BubbleShooterScreenState extends State<BubbleShooterScreen> with SingleTickerProviderStateMixin {
  final Random _rng = Random();
  BubbleEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _aim = pi / 2;
  bool _saved = false;
  int _seenLevelUps = 0;
  String _banner = '';
  int _bannerEpoch = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _start() {
    _ticker.stop();
    setState(() {
      _e = BubbleEngine(_rng);
      _aim = pi / 2;
      _saved = false;
      _seenLevelUps = 0;
      _banner = '';
    });
    _last = Duration.zero;
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final e = _e;
    if (e == null) return;
    double dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt > 0.05) { dt = 0.05; }
    if (e.flying && !e.gameOver) {
      final landed = e.update(dt);
      if (landed) { _afterLand(e); }
    }
    setState(() {});
  }

  void _afterLand(BubbleEngine e) {
    if (e.lastPopped > 0) {
      SoundService.instance.playCorrect();
    } else {
      SoundService.instance.playTap();
    }
    if (e.lastDropped > 0) { SoundService.instance.playExplosion(); }
    if (e.levelUps != _seenLevelUps) {
      _seenLevelUps = e.levelUps;
      _showBanner('LEVEL ${e.level}');
    } else if (e.lastPushed) {
      _showBanner('New row!');
    }
    if (e.gameOver && !_saved) {
      _saved = true;
      _ticker.stop();
      GameScoreService.save(gameName: 'Bubble Shooter', score: e.score);
      SoundService.instance.playLose();
    }
  }

  void _showBanner(String text) {
    final epoch = ++_bannerEpoch;
    setState(() => _banner = text);
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted && epoch == _bannerEpoch) { setState(() => _banner = ''); }
    });
  }

  void _setAim(Offset local, double scale) {
    final lx = local.dx / scale;
    final ly = local.dy / scale;
    if (ly >= BubbleEngine.shooterY - 1.5) return;
    double a = atan2(BubbleEngine.shooterY - ly, lx - BubbleEngine.shooterX);
    if (a < 0.2) { a = 0.2; }
    if (a > pi - 0.2) { a = pi - 0.2; }
    setState(() => _aim = a);
  }

  void _fire() {
    final e = _e;
    if (e == null || e.flying || e.gameOver) return;
    e.shoot(_aim);
    SoundService.instance.playShoot();
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'bubble_shooter',
      title: 'HOW TO PLAY BUBBLE SHOOTER',
      steps: const [
        HowToPlayStep(icon: Icons.gps_fixed_rounded, title: 'Aim and shoot', description: 'Drag on the board to aim. The dotted line shows where your bubble will go and bounce. Let go to fire.'),
        HowToPlayStep(icon: Icons.bubble_chart_rounded, title: 'Match three', description: 'Join 3 or more bubbles of the same colour and they pop. Bubbles left hanging with nothing above them fall too, for bonus points.'),
        HowToPlayStep(icon: Icons.swap_horiz_rounded, title: 'Swap bubbles', description: 'Tap the small bubble next to the launcher to swap it with the one loaded.'),
        HowToPlayStep(icon: Icons.warning_amber_rounded, title: 'Do not let them reach the line', description: 'If you keep missing, a new row drops from the top. The game ends when bubbles cross the red line. Clear the board to reach the next level.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('BUBBLE SHOOTER')),
        body: e == null ? _setup() : Stack(children: [_game(e), if (e.gameOver) _result(e)]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.bubble_chart_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('BUBBLE SHOOTER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Match colours and clear the board', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
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

  Widget _game(BubbleEngine e) {
    return LayoutBuilder(builder: (context, cons) {
      final double availW = cons.maxWidth - 16;
      final double availH = cons.maxHeight - 56;
      final double scale = min(availW / BubbleEngine.fieldW, availH / BubbleEngine.fieldH);
      final double w = scale * BubbleEngine.fieldW;
      final double h = scale * BubbleEngine.fieldH;
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: (cons.maxWidth - w) / 2 + 4, vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('SCORE ${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
            Text('LEVEL ${e.level}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.deepOrange)),
            Row(children: [
              for (int i = 0; i < e.missLimit; i++)
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < e.missLimit - e.misses ? GacomColors.textMuted : const Color(0xFFEF5350)),
                ),
            ]),
          ]),
        ),
        SizedBox(
          width: w,
          height: h,
          child: Stack(children: [
            GestureDetector(
              onPanDown: (d) => _setAim(d.localPosition, scale),
              onPanUpdate: (d) => _setAim(d.localPosition, scale),
              onPanEnd: (_) => _fire(),
              onTapDown: (d) => _setAim(d.localPosition, scale),
              onTapUp: (_) => _fire(),
              child: CustomPaint(size: Size(w, h), painter: _BubblePainter(e, _aim)),
            ),
            Positioned(
              left: (BubbleEngine.shooterX + 3.2) * scale - scale * 0.9,
              top: (BubbleEngine.shooterY + 0.4) * scale - scale * 0.9,
              child: GestureDetector(
                onTap: () => setState(e.swap),
                child: Container(
                  width: scale * 1.8,
                  height: scale * 1.8,
                  decoration: BoxDecoration(color: kBbColors[e.next], shape: BoxShape.circle, border: Border.all(color: Colors.white54, width: 1.5)),
                ),
              ),
            ),
            if (_banner.isNotEmpty)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(50)),
                  child: Text(_banner, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _result(BubbleEngine e) => Container(
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
          Text('Score ${e.score}  -  reached level ${e.level}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
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

class _BubblePainter extends CustomPainter {
  final BubbleEngine e;
  final double aim;
  _BubblePainter(this.e, this.aim);

  void _bubble(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(c, r, Paint()..color = color);
    canvas.drawCircle(c - Offset(r * 0.3, r * 0.3), r * 0.32, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.black.withValues(alpha: 0.35));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / BubbleEngine.fieldW;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)), Paint()..color = const Color(0xFF0B0D13));
    final lineY = (1.0 + (BubbleEngine.dangerRow - 0.5) * BubbleEngine.rowStep) * s;
    canvas.drawLine(Offset(0, lineY), Offset(size.width, lineY), Paint()..color = const Color(0x55EF5350)..strokeWidth = 2);
    for (int r = 0; r < BubbleEngine.maxRows; r++) {
      for (int c = 0; c < e.colsOf(r); c++) {
        final v = e.grid[r][c];
        if (v >= 0) { _bubble(canvas, Offset(e.xOf(r, c) * s, e.yOf(r) * s), s * 0.96, kBbColors[v]); }
      }
    }
    if (!e.flying && !e.gameOver) {
      final pts = e.preview(aim);
      final dot = Paint()..color = Colors.white.withValues(alpha: 0.55);
      for (int i = 0; i + 1 < pts.length; i++) {
        final a = Offset(pts[i][0] * s, pts[i][1] * s);
        final b = Offset(pts[i + 1][0] * s, pts[i + 1][1] * s);
        final double len = (b - a).distance;
        final int n = max(1, (len / (s * 1.4)).floor());
        for (int k = 1; k <= n; k++) {
          canvas.drawCircle(Offset.lerp(a, b, k / n)!, s * 0.14, dot);
        }
      }
    }
    final shooter = Offset(BubbleEngine.shooterX * s, BubbleEngine.shooterY * s);
    canvas.drawCircle(shooter, s * 1.5, Paint()..color = const Color(0xFF1E222D));
    canvas.save();
    canvas.translate(shooter.dx, shooter.dy);
    canvas.rotate(-aim + pi / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-s * 0.35, -s * 2.0, s * 0.7, s * 1.6), Radius.circular(s * 0.2)), Paint()..color = const Color(0xFF3A4052));
    canvas.restore();
    if (e.flying) {
      _bubble(canvas, Offset(e.px * s, e.py * s), s * 0.96, kBbColors[e.current]);
    } else {
      _bubble(canvas, shooter, s * 0.96, kBbColors[e.current]);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => true;
}
