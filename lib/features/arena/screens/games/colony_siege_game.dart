import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/colony_siege_game.dart';
import '../../games/astra_colony/industrial_gauge.dart';
import 'level_map_screen.dart';

const _amber = Color(0xFFFFA940);
const _rust = Color(0xFFB8541F);
const _iron = Color(0xFF17171A);
const _ironPanel = Color(0xFF232326);
const _ironBorder = Color(0xFF4A4A50);

/// Colony Siege v4 — a genuinely different ARRANGEMENT, not just a
/// different theme: no joystick, no top HUD bar, no corner action button.
/// Tap a pod to send your unit for it. Tap a dock tray card to select it.
/// Tap the Reactor to dispatch delivery. Status lives as a floating label
/// on the Reactor itself, not a global panel.
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
  List<int> _dock = [];
  int? _selectedDockIndex;
  int _received = 0;
  bool _overloadFlash = false;

  void _selectLevel(int level, String difficulty) {
    final target = 10 + level * 3;
    setState(() { _level = level; _difficulty = difficulty; _requiredTotal = target; _phase = _Phase.intro; });
  }

  void _beginLevel() {
    _game = ColonySiegeGame(
      requiredTotal: _requiredTotal,
      onDockChanged: (dock) { if (mounted) setState(() { _dock = dock; _selectedDockIndex = null; }); },
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
        LevelMapScreen.unlockNext('colony_siege_v4', _level!);
        setState(() => _phase = _Phase.complete);
      },
    );
    setState(() { _dock = []; _selectedDockIndex = null; _received = 0; _phase = _Phase.playing; });
  }

  void _selectDock(int index) {
    setState(() => _selectedDockIndex = index);
    _game.selectDockPod(index);
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.levelMap) return LevelMapScreen(gameKey: 'colony_siege_v4', title: 'Colony Siege', onPlayLevel: _selectLevel);
    if (_phase == _Phase.intro) return _introScreen();
    if (_phase == _Phase.complete) return _completeScreen();

    return Scaffold(
      backgroundColor: _iron,
      body: SafeArea(child: Column(children: [
        // Minimal top corners only — no bar spanning the screen.
        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 6), child: Row(children: [
          GestureDetector(onTap: () => setState(() => _phase = _Phase.levelMap),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 13),
              SizedBox(width: 4),
              Text('BASE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white70, letterSpacing: 1)),
            ])),
          const Spacer(),
          IndustrialGauge(current: _received, target: _requiredTotal, size: 52, overload: _overloadFlash),
        ])),
        // The play space — nearly the entire screen, per the blueprint.
        Expanded(child: GameWidget(game: _game)),
        // Bottom dock tray — the ONLY interaction surface besides the
        // world itself. Replaces both the old joystick and action button.
        _dockTray(),
      ])),
    );
  }

  Widget _dockTray() => Container(
    height: 96,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: const BoxDecoration(color: _ironPanel, border: Border(top: BorderSide(color: _ironBorder, width: 2))),
    child: _dock.isEmpty
      ? const Center(child: Text('Tap a fuel pod in the field to collect it', style: TextStyle(color: Colors.white38, fontSize: 12)))
      : ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _dock.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final selected = _selectedDockIndex == i;
            return GestureDetector(
              onTap: () => _selectDock(i),
              child: Container(
                width: 64,
                decoration: BoxDecoration(
                  color: selected ? _rust : _ironPanel,
                  border: Border.all(color: selected ? _amber : _ironBorder, width: selected ? 2.5 : 1.5),
                  boxShadow: selected ? [BoxShadow(color: _amber.withOpacity(0.4), blurRadius: 8)] : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.propane_tank_rounded, color: _amber, size: 20),
                  const SizedBox(height: 4),
                  Text('${_dock[i]}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                ]),
              ),
            );
          },
        ),
  );

  Widget _introScreen() => Scaffold(
    backgroundColor: _iron,
    appBar: AppBar(backgroundColor: _iron, title: Text('LEVEL $_level · $_difficulty', style: const TextStyle(color: _amber, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800))),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('POWER THE REACTOR', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: _amber, letterSpacing: 1)),
      const SizedBox(height: 16),
      Text('The Reactor needs exactly $_requiredTotal units. Tap a fuel pod to send your unit to collect it. '
        'Tap a pod in your dock tray to select it, then tap the Reactor to dispatch delivery.',
        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ironPanel, border: Border.all(color: _ironBorder, width: 2)),
        child: const Row(children: [
          Icon(Icons.touch_app_rounded, color: _amber, size: 20), SizedBox(width: 10),
          Expanded(child: Text('No joystick — tap the field to move, tap pods to collect, tap the dock tray then the Reactor to deliver.', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: GestureDetector(
        onTap: _beginLevel,
        child: Container(padding: const EdgeInsets.symmetric(vertical: 16), alignment: Alignment.center,
          decoration: BoxDecoration(color: _rust, border: Border.all(color: _amber, width: 2)),
          child: const Text('BEGIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 2))),
      )),
    ]))));

  Widget _completeScreen() => Scaffold(
    backgroundColor: _iron,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.bolt_rounded, color: _amber, size: 48),
      const SizedBox(height: 12),
      const Text('REACTOR POWERED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: _amber, letterSpacing: 1)),
      const SizedBox(height: 8),
      Text('Level $_level complete.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ironPanel, border: Border.all(color: _ironBorder, width: 2)),
        child: Text('+${20 + _level! * 2} XP', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: _amber))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: () => setState(() => _phase = _Phase.levelMap), style: OutlinedButton.styleFrom(side: const BorderSide(color: _ironBorder)),
          child: const Text('LEVEL MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
        const SizedBox(width: 12),
        GestureDetector(onTap: () => _selectLevel((_level! + 1).clamp(1, 20), LevelMapScreen.difficultyFor((_level! + 1).clamp(1, 20))),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: _rust, border: Border.all(color: _amber, width: 2)),
            child: const Text('NEXT LEVEL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)))),
      ]),
    ]))),
  );
}
