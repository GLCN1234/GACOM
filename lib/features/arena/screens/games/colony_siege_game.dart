import 'package:flame/game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/colony_siege_game.dart';
import '../../games/astra_colony/virtual_joystick_widget.dart';
import 'level_map_screen.dart';

/// Colony Siege, fully rebuilt: pick a level from the map (1-20, Easy/
/// Medium/Hard, difficulty-scaled reactor targets), then collect fuel
/// pods scattered in the world and deliver them to the Reactor Core.
/// Exact match powers it; overshoot vents steam and resets the pods.
/// No popup, no multiple-choice card, anywhere in this flow.
class ColonySiegeScreen extends StatefulWidget {
  const ColonySiegeScreen({super.key, this.subject = 'logic'});
  final String subject;

  @override
  State<ColonySiegeScreen> createState() => _ColonySiegeScreenState();
}

enum _Phase { levelMap, intro, playing, complete }

class _ColonySiegeScreenState extends State<ColonySiegeScreen> {
  _Phase _phase = _Phase.levelMap;
  int? _level;
  String _difficulty = 'Easy';
  int _requiredTotal = 15;
  late ColonySiegeGame _game;
  bool _isNearReactor = false;
  bool _overloadFlash = false;
  List<int> _heldPods = [];
  int _received = 0;

  void _selectLevel(int level, String difficulty) {
    final target = 10 + level * 3; // scales from ~13 at level 1 to ~70 at level 20
    setState(() { _level = level; _difficulty = difficulty; _requiredTotal = target; _phase = _Phase.intro; });
  }

  void _beginLevel() {
    _game = ColonySiegeGame(
      requiredTotal: _requiredTotal,
      onNearReactorChanged: (near) { if (mounted) setState(() => _isNearReactor = near); },
      onHeldPodsChanged: (held) { if (mounted) setState(() => _heldPods = held); },
      onReceivedChanged: (total) { if (mounted) setState(() => _received = total); },
      onOverload: () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() => _overloadFlash = true);
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
        Future.delayed(const Duration(milliseconds: 700), () { if (mounted) setState(() => _overloadFlash = false); });
      },
      onLevelComplete: () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 20 + _level! * 2, questionsAnswered: 1, correctAnswers: 1);
        LevelMapScreen.unlockNext('colony_siege_v2', _level!);
        setState(() => _phase = _Phase.complete);
      },
    );
    setState(() { _isNearReactor = false; _heldPods = []; _received = 0; _phase = _Phase.playing; });
  }

  void _onJoystickDirection(Offset dir) => _game.setMoveDirection(Vector2(dir.dx, dir.dy));
  void _deliver() { if (_heldPods.isNotEmpty) _game.deliverHeldPods(); }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.levelMap) return LevelMapScreen(gameKey: 'colony_siege_v2', title: 'Colony Siege', onPlayLevel: _selectLevel);
    if (_phase == _Phase.intro) return _introScreen();
    if (_phase == _Phase.complete) return _completeScreen();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Stack(children: [
        GameWidget(game: _game),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: _topHud())),
        Positioned(left: 20, bottom: 28, child: VirtualJoystickWidget(onDirectionChanged: _onJoystickDirection)),
        Positioned(right: 24, bottom: 40, child: _actionArea()),
      ]),
    );
  }

  Widget _topHud() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Column(children: [
      Row(children: [
        _pill('LEVEL $_level · $_difficulty', GacomColors.deepOrange),
        const Spacer(),
        _pill(_received >= _requiredTotal ? '⚡ POWERED' : '⚡ ${_received}/${_requiredTotal}', _received >= _requiredTotal ? GacomColors.success : GacomColors.accentCyan),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _overloadFlash ? GacomColors.error : Colors.white.withOpacity(0.12), width: _overloadFlash ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bolt_rounded, color: GacomColors.accentCyan, size: 13),
          const SizedBox(width: 5),
          Text(_overloadFlash ? 'REACTOR OVERLOAD — PODS RESET' : 'REACTOR TARGET: $_requiredTotal UNITS',
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: _overloadFlash ? GacomColors.error : GacomColors.accentCyan, letterSpacing: 0.5)),
        ]),
      ),
    ]),
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(text, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: color)),
  );

  Widget _actionArea() {
    final holding = _heldPods.isNotEmpty;
    final canDeliver = holding && _isNearReactor;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (holding) Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('CARRYING ', style: TextStyle(color: Colors.white70, fontSize: 10)),
          ..._heldPods.map((v) => Container(margin: const EdgeInsets.only(left: 3), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF3DD6FF).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Text('$v', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF3DD6FF))))),
        ]),
      ),
      AnimatedOpacity(
        opacity: canDeliver ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !canDeliver,
          child: GestureDetector(
            onTap: _deliver,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: GacomColors.deepOrange,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.5), blurRadius: 12)],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('DELIVER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: Text('LEVEL $_level · $_difficulty')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('POWER THE REACTOR', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
      const SizedBox(height: 16),
      Text('The Reactor Core needs exactly $_requiredTotal units. Fuel pods are scattered nearby — collect the right combination '
        'and deliver them. Overshoot the target and the reactor vents steam, resetting the pods.',
        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
        child: const Row(children: [
          Icon(Icons.gamepad_rounded, color: GacomColors.deepOrange, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Walk over a pod to collect it. Get close to the reactor and tap DELIVER.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _beginLevel,
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('BEGIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 1)))),
    ]))));

  Widget _completeScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⚡', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('REACTOR POWERED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: GacomColors.success)),
      const SizedBox(height: 8),
      Text('Level $_level complete. Energy surges through the colony.', textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12)),
        child: Text('+${20 + _level! * 2} XP', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.deepOrange))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: () => setState(() => _phase = _Phase.levelMap), style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border)),
          child: const Text('LEVEL MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
        const SizedBox(width: 12),
        ElevatedButton(onPressed: () => _selectLevel((_level! + 1).clamp(1, 20), LevelMapScreen.difficultyFor((_level! + 1).clamp(1, 20))),
          style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('NEXT LEVEL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    ]))),
  );
}
