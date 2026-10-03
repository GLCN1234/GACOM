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
  bool _showHowToPlay = true;

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

          // Top-right action row: payload switch + dodge roll — moved
          // up here since the bottom-right is now the real aim stick,
          // used for manual firing, not auto-fire.
          Positioned(
            top: 86, right: 16,
            child: Row(children: [
              ValueListenableBuilder<int>(
                valueListenable: _game.payloadNotifier,
                builder: (_, payload, __) => GestureDetector(
                  onTap: _game.cyclePayload,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ChronoSpireGame.payloadColors[payload],
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                    ),
                    child: Center(child: Text(ChronoSpireGame.payloadNames[payload][0],
                      style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: 18))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<double>(
                valueListenable: _game.dodgeCooldownNotifier,
                builder: (_, cd, __) => GestureDetector(
                  onTap: cd <= 0 ? _game.activateDodge : null,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cd <= 0 ? GacomColors.deepOrange : Colors.white.withOpacity(0.1),
                    ),
                    child: cd > 0
                      ? Center(child: Text(cd.ceil().toString(), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)))
                      : const Icon(Icons.directions_run_rounded, color: Colors.white, size: 22),
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
          if (_showHowToPlay) _howToPlayOverlay(),
        ]),
      ),
    );
  }

  Widget _howToPlayOverlay() => Container(
    color: Colors.black.withOpacity(0.85),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(24),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HOW TO PLAY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
          const SizedBox(height: 16),
          _howToRow(Icons.control_camera_rounded, 'Left stick', 'Move your bio-drone around the arena'),
          _howToRow(Icons.gps_fixed_rounded, 'Right stick', 'Aim and fire — nothing shoots until you push this'),
          _howToRow(Icons.science_rounded, 'Payload button', 'Cycles Acid, Thermal, Electro — hit Acid then Thermal quickly for a bonus explosion'),
          _howToRow(Icons.directions_run_rounded, 'Dodge button', 'A short burst of speed and brief invincibility'),
          _howToRow(Icons.my_location_rounded, 'Weak points', 'The glowing dot on each enemy — gold slows them, blue stops their attack'),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => setState(() => _showHowToPlay = false),
            child: const Text('START', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          )),
        ]),
      ),
    ),
  );

  Widget _howToRow(IconData icon, String title, String desc) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: GacomColors.accentCyan, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
        Text(desc, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
      ])),
    ]),
  );
}
