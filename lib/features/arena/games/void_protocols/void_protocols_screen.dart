import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../../core/theme/app_theme.dart';
import 'void_protocols_game.dart';

class VoidProtocolsScreen extends StatefulWidget {
  const VoidProtocolsScreen({super.key});
  @override
  State<VoidProtocolsScreen> createState() => _VoidProtocolsScreenState();
}

class _VoidProtocolsScreenState extends State<VoidProtocolsScreen> {
  late VoidProtocolsGame _game;

  @override
  void initState() {
    super.initState();
    _game = VoidProtocolsGame();
  }

  void _restart() {
    setState(() => _game = VoidProtocolsGame());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: Stack(children: [
          GameWidget(game: _game),

          // Top HUD
          Positioned(
            top: 12, left: 16, right: 16,
            child: Column(children: [
              Row(children: [
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18))),
                const SizedBox(width: 12),
                Expanded(child: ValueListenableBuilder<double>(
                  valueListenable: _game.healthNotifier,
                  builder: (_, health, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: LinearProgressIndicator(
                      value: (health / 100).clamp(0, 1),
                      minHeight: 10,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(health > 30 ? GacomColors.success : GacomColors.error),
                    ),
                  ),
                )),
                const SizedBox(width: 16),
                ValueListenableBuilder<int>(
                  valueListenable: _game.waveNotifier,
                  builder: (_, wave, __) => Text('WAVE $wave', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder<int>(
                  valueListenable: _game.scoreNotifier,
                  builder: (_, score, __) => Row(children: [
                    const Icon(Icons.star_rounded, color: GacomColors.deepOrange, size: 16),
                    const SizedBox(width: 4),
                    Text('$score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _game.shieldActiveNotifier,
                builder: (_, shielded, __) => shielded
                  ? const Align(alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_rounded, color: Color(0xFFFFD700), size: 14),
                      SizedBox(width: 4),
                      Text('SHIELD ACTIVE — next hit absorbed', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w700)),
                    ]))
                  : const SizedBox.shrink(),
              ),
            ]),
          ),

          // Bottom-right action buttons: frequency switch + temporal freeze
          Positioned(
            bottom: 24, right: 24,
            child: Column(children: [
              ValueListenableBuilder<double>(
                valueListenable: _game.freezeCooldownNotifier,
                builder: (_, cd, __) => GestureDetector(
                  onTap: cd <= 0 ? _game.activateFreeze : null,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cd <= 0 ? GacomColors.deepOrange : Colors.white.withOpacity(0.1),
                    ),
                    child: cd > 0
                      ? Center(child: Text(cd.ceil().toString(), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)))
                      : const Icon(Icons.ac_unit_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<int>(
                valueListenable: _game.frequencyNotifier,
                builder: (_, freq, __) => GestureDetector(
                  onTap: _game.cycleFrequency,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: VoidProtocolsGame.frequencyColors[freq],
                    ),
                    child: Center(child: Text(VoidProtocolsGame.frequencyNames[freq][0],
                      style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 20))),
                  ),
                ),
              ),
            ]),
          ),

          // Vector-alignment puzzle overlay — the Math/CS interlude
          ValueListenableBuilder<bool>(
            valueListenable: _game.puzzleActiveNotifier,
            builder: (_, active, __) => active
              ? _VectorAlignPuzzle(onResolved: (success) => _game.resolvePuzzle(success))
              : const SizedBox.shrink(),
          ),

          // Game over overlay
          ValueListenableBuilder<bool>(
            valueListenable: _game.gameOverNotifier,
            builder: (_, isOver, __) {
              if (!isOver) return const SizedBox.shrink();
              return Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(28),
                    decoration: GacomDecorations.glassCard(context, radius: 24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.blur_on_rounded, color: GacomColors.error, size: 48),
                      const SizedBox(height: 16),
                      const Text('CONTAINMENT BREACH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text('Final score: ${_game.score} · Reached wave ${_game.wave}', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 24),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                          onPressed: _restart,
                          child: const Text('TRY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

/// The Math/CS interlude: rotate a dial to match a target angle within
/// tolerance before time runs out. A real, if simple, vector/angle
/// exercise — not flavor text over a generic minigame.
class _VectorAlignPuzzle extends StatefulWidget {
  final void Function(bool success) onResolved;
  const _VectorAlignPuzzle({required this.onResolved});
  @override State<_VectorAlignPuzzle> createState() => _VectorAlignPuzzleState();
}

class _VectorAlignPuzzleState extends State<_VectorAlignPuzzle> {
  late double _targetAngle;
  double _currentAngle = 0;
  double _timeLeft = 6.0;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _targetAngle = Random().nextDouble() * 2 * pi;
    _tick();
  }

  void _tick() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || _resolved) return;
      setState(() => _timeLeft -= 0.1);
      if (_timeLeft <= 0) {
        _resolve();
      } else {
        _tick();
      }
    });
  }

  void _resolve() {
    if (_resolved) return;
    _resolved = true;
    final diff = (_currentAngle - _targetAngle).abs() % (2 * pi);
    final within = diff < 0.26 || diff > (2 * pi - 0.26); // ~15 degrees tolerance
    widget.onResolved(within);
  }

  void _onPanUpdate(DragUpdateDetails details, Offset center) {
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    setState(() => _currentAngle = atan2(dy, dx));
  }

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withOpacity(0.85),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('POWER NODE OVERRIDE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Align the vector to the target angle', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: 180, height: 180,
            child: GestureDetector(
              onPanUpdate: (d) => _onPanUpdate(d, const Offset(90, 90)),
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _DialPainter(targetAngle: _targetAngle, currentAngle: _currentAngle),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: LinearProgressIndicator(
              value: (_timeLeft / 6.0).clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange),
            ),
          ),
        ]),
      ),
    ),
  );
}

class _DialPainter extends CustomPainter {
  final double targetAngle, currentAngle;
  _DialPainter({required this.targetAngle, required this.currentAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);

    // Target marker
    final targetPoint = center + Offset(cos(targetAngle), sin(targetAngle)) * radius;
    canvas.drawCircle(targetPoint, 8, Paint()..color = const Color(0xFFFFD700));

    // Current pointer
    final currentPoint = center + Offset(cos(currentAngle), sin(currentAngle)) * radius;
    canvas.drawLine(center, currentPoint, Paint()
      ..color = GacomColors.deepOrange
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(currentPoint, 7, Paint()..color = GacomColors.deepOrange);
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) => true;
}
