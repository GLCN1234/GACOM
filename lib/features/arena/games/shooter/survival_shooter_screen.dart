import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../../core/theme/app_theme.dart';
import 'shooter_game.dart';

class SurvivalShooterScreen extends StatefulWidget {
  const SurvivalShooterScreen({super.key});
  @override
  State<SurvivalShooterScreen> createState() => _SurvivalShooterScreenState();
}

class _SurvivalShooterScreenState extends State<SurvivalShooterScreen> {
  late final ShooterGame _game;

  @override
  void initState() {
    super.initState();
    _game = ShooterGame();
  }

  void _restart() {
    setState(() => _game = ShooterGame());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: SafeArea(
        child: Stack(children: [
          GameWidget(game: _game),

          // Top HUD: health bar, score, wave
          Positioned(
            top: 12, left: 16, right: 16,
            child: Row(children: [
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
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
                      const Icon(Icons.sports_martial_arts_rounded, color: GacomColors.error, size: 48),
                      const SizedBox(height: 16),
                      const Text('YOU WERE OVERWHELMED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
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
