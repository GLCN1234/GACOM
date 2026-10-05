import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';

/// The field is 100 units wide. Each tower block is [x, width].
class StackEngine {
  static const double fieldW = 100.0;
  static const double startW = 60.0;
  static const double perfectTol = 1.5;

  final List<List<double>> tower = <List<double>>[[20.0, startW]];
  double x = 0;
  double w = startW;
  int dirSign = 1;
  int score = 0;
  int perfects = 0;
  int streak = 0;
  bool gameOver = false;

  /// The most recent offcut: [x, width, level], or null.
  List<double>? cut;

  StackEngine() {
    _spawn();
  }

  int get level => tower.length;

  double get speed {
    final double v = 40.0 + score * 1.6;
    return v > 105.0 ? 105.0 : v;
  }

  void _spawn() {
    w = tower.last[1];
    if (level.isEven) {
      x = 0;
      dirSign = 1;
    } else {
      x = fieldW - w;
      dirSign = -1;
    }
  }

  void update(double dt) {
    if (gameOver) return;
    x += dirSign * speed * dt;
    if (x <= 0) {
      x = 0;
      dirSign = 1;
    } else if (x + w >= fieldW) {
      x = fieldW - w;
      dirSign = -1;
    }
  }

  /// Drops the moving block. 0 = missed (game over), 1 = placed, 2 = perfect.
  int drop() {
    if (gameOver) return 0;
    final top = tower.last;
    final double px = top[0];
    final double pw = top[1];
    final double left = max(x, px);
    final double right = min(x + w, px + pw);
    final double overlap = right - left;
    if (overlap <= 0) {
      gameOver = true;
      cut = [x, w, level.toDouble()];
      return 0;
    }
    if ((x - px).abs() <= perfectTol) {
      streak++;
      perfects++;
      score += 2;
      double nw = pw;
      double nx = px;
      if (streak >= 3) {
        nw = min(startW, pw + 2.0);
        nx = px - (nw - pw) / 2;
        if (nx < 0) { nx = 0; }
        if (nx + nw > fieldW) { nx = fieldW - nw; }
      }
      cut = null;
      tower.add([nx, nw]);
      _spawn();
      return 2;
    }
    streak = 0;
    score += 1;
    if (x < px) {
      cut = [x, left - x, level.toDouble()];
    } else {
      cut = [right, x + w - right, level.toDouble()];
    }
    tower.add([left, overlap]);
    _spawn();
    return 1;
  }
}

class _Falling {
  double x;
  double w;
  double y; // world level position in block units
  double vy = 0;
  final Color color;
  _Falling(this.x, this.w, this.y, this.color);
}

class StackTowerScreen extends StatefulWidget {
  const StackTowerScreen({super.key});
  @override
  State<StackTowerScreen> createState() => _StackTowerScreenState();
}

class _StackTowerScreenState extends State<StackTowerScreen> with SingleTickerProviderStateMixin {
  StackEngine? _e;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _camera = 0; // in block units
  final List<_Falling> _falling = <_Falling>[];
  bool _saved = false;
  String _flash = '';
  int _flashEpoch = 0;

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

  static Color blockColor(int i) => HSVColor.fromAHSV(1.0, (i * 11.0) % 360.0, 0.62, 0.95).toColor();

  void _start() {
    _ticker.stop();
    setState(() {
      _e = StackEngine();
      _camera = 0;
      _falling.clear();
      _saved = false;
      _flash = '';
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
    e.update(dt);
    final double target = max(0.0, e.level - 6.0);
    _camera += (target - _camera) * min(1.0, dt * 5.0);
    for (final f in _falling) {
      f.vy += 60.0 * dt;
      f.y -= f.vy * dt;
    }
    _falling.removeWhere((f) => f.y < _camera - 8);
    setState(() {});
  }

  void _tap() {
    final e = _e;
    if (e == null || e.gameOver) return;
    final result = e.drop();
    final c = e.cut;
    if (c != null) {
      _falling.add(_Falling(c[0], c[1], c[2], blockColor(e.level - (result == 0 ? 0 : 1))));
    }
    if (result == 2) {
      SoundService.instance.playCorrect();
      _showFlash(e.streak >= 3 ? 'PERFECT x${e.streak}  +width' : 'PERFECT!');
    } else if (result == 1) {
      SoundService.instance.playPieceMove();
    } else {
      SoundService.instance.playLose();
      if (!_saved) {
        _saved = true;
        GameScoreService.save(gameName: 'Stack Tower', score: e.score);
      }
    }
    setState(() {});
  }

  void _showFlash(String t) {
    final epoch = ++_flashEpoch;
    setState(() => _flash = t);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && epoch == _flashEpoch) { setState(() => _flash = ''); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final e = _e;
    return HowToPlayOverlay(
      gameKey: 'stack_tower',
      title: 'HOW TO PLAY STACK TOWER',
      steps: const [
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Tap to drop', description: 'A block slides back and forth. Tap anywhere to drop it onto the tower.'),
        HowToPlayStep(icon: Icons.content_cut_rounded, title: 'Overhang gets cut off', description: 'Only the part that lands on the block below stays. The better you line it up, the wider your tower stays.'),
        HowToPlayStep(icon: Icons.star_rounded, title: 'Perfect drops', description: 'Land it exactly in line for a perfect drop and bonus points. Three perfects in a row make the block wider again.'),
        HowToPlayStep(icon: Icons.trending_up_rounded, title: 'It speeds up', description: 'The block moves faster the higher you go. The game ends when a block misses the tower completely.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('STACK TOWER')),
        body: e == null ? _setup() : _game(e),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.layers_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('STACK TOWER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Time your taps and build the tallest tower', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
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

  Widget _game(StackEngine e) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _tap(),
          child: CustomPaint(painter: _StackPainter(e, _camera, _falling)),
        ),
      ),
      Positioned(
        top: 14,
        left: 0,
        right: 0,
        child: Center(
          child: Text('${e.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 54, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
        ),
      ),
      if (_flash.isNotEmpty)
        Positioned(
          top: 84,
          left: 0,
          right: 0,
          child: Center(child: Text(_flash, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFFFFD54F), shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
        ),
      if (e.gameOver) _result(e),
    ]);
  }

  Widget _result(StackEngine e) => Container(
    color: Colors.black.withValues(alpha: 0.78),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 52),
          const SizedBox(height: 12),
          const Text('TOWER FELL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Score ${e.score}  -  ${e.level - 1} blocks, ${e.perfects} perfect', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
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

class _StackPainter extends CustomPainter {
  final StackEngine e;
  final double camera;
  final List<_Falling> falling;
  _StackPainter(this.e, this.camera, this.falling);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / StackEngine.fieldW;
    final double bh = min(size.height / 12.0, 9.0 * s);
    final hue = (e.level * 4.0) % 360.0;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [HSVColor.fromAHSV(1, hue, 0.45, 0.35).toColor(), HSVColor.fromAHSV(1, (hue + 40) % 360, 0.5, 0.15).toColor()],
      ).createShader(Offset.zero & size),
    );
    // World level L occupies screen y = size.height - (L - camera + 1) * bh - 40.
    double screenY(double level) => size.height - (level - camera + 1.0) * bh - 40.0;
    void block(double x, double w, double level, Color c) {
      final rect = Rect.fromLTWH(x * s, screenY(level), w * s, bh);
      canvas.drawRect(rect, Paint()..color = c);
      canvas.drawRect(Rect.fromLTWH(rect.left, rect.top, rect.width, bh * 0.22), Paint()..color = Colors.white.withValues(alpha: 0.25));
    }
    for (int i = 0; i < e.tower.length; i++) {
      final y = screenY(i.toDouble());
      if (y > size.height + bh || y < -bh) continue;
      block(e.tower[i][0], e.tower[i][1], i.toDouble(), _StackTowerScreenState.blockColor(i));
    }
    if (!e.gameOver) { block(e.x, e.w, e.level.toDouble(), _StackTowerScreenState.blockColor(e.level)); }
    for (final f in falling) { block(f.x, f.w, f.y, f.color.withValues(alpha: 0.85)); }
  }

  @override
  bool shouldRepaint(_StackPainter oldDelegate) => true;
}
