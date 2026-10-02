import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/theme/app_theme.dart';
import 'void_protocols_game.dart';

class VoidProtocolsScreen extends StatefulWidget {
  const VoidProtocolsScreen({super.key});
  @override
  State<VoidProtocolsScreen> createState() => _VoidProtocolsScreenState();
}

class _VoidProtocolsScreenState extends State<VoidProtocolsScreen> with SingleTickerProviderStateMixin {
  final VoidProtocolsController _controller = VoidProtocolsController();
  late Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1000000.0;
    _lastTick = elapsed;
    if (dt > 0 && dt < 0.1) _controller.step(dt);
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (_controller.projectile != null || _controller.levelComplete) return;
    final playerPx = Offset(
      _controller.level.playerFractional.dx * canvasSize.width,
      _controller.level.playerFractional.dy * canvasSize.height,
    );
    final dx = details.localPosition.dx - playerPx.dx;
    final dy = details.localPosition.dy - playerPx.dy;
    final angle = atan2(-dy, dx) * (180 / pi);
    _controller.angleDegrees = angle.clamp(-89, 89);
    _controller.notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(children: [
            Column(children: [
              _topBar(),
              _objectiveBar(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                    _controller.setCanvasSize(canvasSize);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: GestureDetector(
                        onPanUpdate: (d) => _onPanUpdate(d, canvasSize),
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFF060614), border: Border.all(color: GacomColors.border)),
                          child: Stack(children: [
                            CustomPaint(size: canvasSize, painter: _VoidPainter(controller: _controller)),
                            if (_controller.shotFailed)
                              Positioned(bottom: 12, left: 0, right: 0, child: Center(
                                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
                                  child: const Text('Shot missed — adjust and try again', style: TextStyle(color: GacomColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                              )),
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              _controls(),
            ]),
            _overlays(),
          ]),
        ),
      ),
    );
  }

  Widget _overlays() {
    if (_controller.allComplete) {
      return Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32), padding: const EdgeInsets.all(28),
            decoration: GacomDecorations.glassCard(context, radius: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD700), size: 48),
              const SizedBox(height: 16),
              const Text('ENTROPY STABILIZED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 8),
              Text('All stages cleared — final score: ${_controller.score}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                  onPressed: _controller.restartGame,
                  child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ]),
            ]),
          ),
        ),
      );
    }
    if (_controller.levelComplete) {
      return Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32), padding: const EdgeInsets.all(24),
            decoration: GacomDecorations.glassCard(context, radius: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 40),
              const SizedBox(height: 12),
              const Text('STAGE CLEARED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
              const SizedBox(height: 6),
              Text('${_controller.attemptsThisLevel} attempt${_controller.attemptsThisLevel == 1 ? '' : 's'}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                onPressed: _controller.nextLevel,
                child: Text(_controller.levelIndex >= voidLevels.length - 1 ? 'FINISH' : 'NEXT STAGE', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(children: [
      GestureDetector(onTap: () => Navigator.pop(context),
        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18))),
      const SizedBox(width: 12),
      Text('STAGE ${(_controller.levelIndex + 1).toString().padLeft(2, '0')}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 14)),
      const Spacer(),
      const Icon(Icons.star_rounded, color: GacomColors.deepOrange, size: 16),
      const SizedBox(width: 4),
      Text('${_controller.score}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
      const SizedBox(width: 16),
      Text('ATTEMPTS: ${_controller.attemptsThisLevel}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
    ]),
  );

  Widget _objectiveBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFF0E1A33), borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.flag_rounded, color: GacomColors.accentCyan, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(_controller.level.objective, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12))),
    ]),
  );

  Widget _controls() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      if (_controller.level.polarityMatters)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(spacing: 8, children: List.generate(_controller.level.wells.length, (i) {
            final well = _controller.level.wells[i];
            return GestureDetector(
              onTap: () => _controller.togglePolarity(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: well.positive ? const Color(0xFFA855F7).withOpacity(0.2) : const Color(0xFFEF4444).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: well.positive ? const Color(0xFFA855F7) : const Color(0xFFEF4444)),
                ),
                child: Text('G${i + 1}: ${well.positive ? "ATTRACT (+)" : "REPEL (-)"}',
                  style: TextStyle(color: well.positive ? const Color(0xFFC084FC) : const Color(0xFFF87171), fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            );
          })),
        ),
      Row(children: [
        _angleButton(-5),
        const SizedBox(width: 8),
        _angleButton(5),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _controller.projectile == null && !_controller.levelComplete ? _controller.fire : null,
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            child: const Text('FIRE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Angle: ${_controller.angleDegrees.round()}° — drag on the field to aim', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
    ]),
  );

  Widget _angleButton(double delta) => GestureDetector(
    onTap: () => _controller.adjustAngle(delta),
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
      child: Center(child: Text(delta > 0 ? '+${delta.round()}°' : '${delta.round()}°', style: const TextStyle(color: GacomColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w800))),
    ),
  );
}

class _VoidPainter extends CustomPainter {
  final VoidProtocolsController controller;
  _VoidPainter({required this.controller});

  Offset _px(Offset fractional, Size size) => Offset(fractional.dx * size.width, fractional.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final level = controller.level;

    for (final well in level.wells) {
      final center = _px(well.fractionalPosition, size);
      final radius = well.radius * size.width;
      final color = well.positive ? const Color(0xFFA855F7) : const Color(0xFFEF4444);
      canvas.drawCircle(center, radius, Paint()..color = color.withOpacity(0.12));
      final dashPaint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, dashPaint);
    }

    final targetPx = _px(level.targetFractional, size);
    final targetColor = controller.levelComplete ? GacomColors.success : GacomColors.accentCyan;
    canvas.drawCircle(targetPx, level.targetRadius, Paint()..color = targetColor.withOpacity(0.25));
    canvas.drawCircle(targetPx, level.targetRadius, Paint()..color = targetColor..style = PaintingStyle.stroke..strokeWidth = 2);

    final playerPx = _px(level.playerFractional, size);
    canvas.drawCircle(playerPx, 11, Paint()..color = const Color(0xFF38BDF8));

    if (controller.projectile == null && !controller.levelComplete) {
      final rad = (-controller.angleDegrees) * (pi / 180);
      final aimEnd = playerPx + Offset(cos(rad), sin(rad)) * 55;
      canvas.drawLine(playerPx, aimEnd, Paint()..color = const Color(0xFFFACC15)..strokeWidth = 2);
    }

    final p = controller.projectile;
    if (p != null) {
      for (int i = 0; i < p.trail.length; i++) {
        final t = i / p.trail.length;
        canvas.drawCircle(p.trail[i], 2.5 * t, Paint()..color = const Color(0xFFFACC15).withOpacity(t * 0.6));
      }
      canvas.drawCircle(p.position, 5, Paint()..color = const Color(0xFFFACC15));
    }
  }

  @override
  bool shouldRepaint(_VoidPainter oldDelegate) => true;
}
