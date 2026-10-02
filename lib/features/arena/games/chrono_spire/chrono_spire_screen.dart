import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../../core/theme/app_theme.dart';
import 'chrono_spire_game.dart';

class ChronoSpireScreen extends StatefulWidget {
  const ChronoSpireScreen({super.key});
  @override
  State<ChronoSpireScreen> createState() => _ChronoSpireScreenState();
}

class _ChronoSpireScreenState extends State<ChronoSpireScreen> {
  late ChronoSpireGame _game;

  @override
  void initState() {
    super.initState();
    _game = ChronoSpireGame();
  }

  void _restart() {
    setState(() => _game = ChronoSpireGame());
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
              ValueListenableBuilder<int>(
                valueListenable: _game.fireRateBuffNotifier,
                builder: (_, stacks, __) => stacks > 0
                  ? Align(alignment: Alignment.centerLeft, child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded, color: Color(0xFF34D399), size: 14),
                      const SizedBox(width: 4),
                      Text('FIRE RATE +${(stacks * 15).clamp(0, 60)}% (genetic synthesis)', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w700)),
                    ]))
                  : const SizedBox.shrink(),
              ),
            ]),
          ),

          // Bottom-right action buttons: payload switch + dodge roll
          Positioned(
            bottom: 24, right: 24,
            child: Column(children: [
              ValueListenableBuilder<double>(
                valueListenable: _game.dodgeCooldownNotifier,
                builder: (_, cd, __) => GestureDetector(
                  onTap: cd <= 0 ? _game.activateDodge : null,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cd <= 0 ? GacomColors.deepOrange : Colors.white.withOpacity(0.1),
                    ),
                    child: cd > 0
                      ? Center(child: Text(cd.ceil().toString(), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18)))
                      : const Icon(Icons.directions_run_rounded, color: Colors.white, size: 26),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<int>(
                valueListenable: _game.payloadNotifier,
                builder: (_, payload, __) => GestureDetector(
                  onTap: _game.cyclePayload,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ChronoSpireGame.payloadColors[payload],
                    ),
                    child: Center(child: Text(ChronoSpireGame.payloadNames[payload][0],
                      style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 20))),
                  ),
                ),
              ),
            ]),
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
                      const Icon(Icons.coronavirus_rounded, color: GacomColors.error, size: 48),
                      const SizedBox(height: 16),
                      const Text('HOST OVERWHELMED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
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
