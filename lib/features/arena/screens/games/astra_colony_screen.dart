import 'package:flame/game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/astra_colony_game.dart';
import '../../games/astra_colony/virtual_joystick_widget.dart';

/// Mission 1: "Arrival" — Quizzy: The Last Colony. Joystick-driven
/// exploration, a context-sensitive interact prompt, and a math puzzle
/// framed as an in-world console readout rather than a quiz card.
class AstraColonyScreen extends StatefulWidget {
  const AstraColonyScreen({super.key, this.subject = 'math'});
  final String subject;

  @override
  State<AstraColonyScreen> createState() => _AstraColonyScreenState();
}

enum _MissionPhase { intro, playing, repairConsole, complete }

class _AstraColonyScreenState extends State<AstraColonyScreen> {
  _MissionPhase _phase = _MissionPhase.intro;
  late AstraColonyGame _game;
  bool _wrongFlash = false;
  bool _isNearSolarArray = false;
  bool _solarArrayRepaired = false;

  // Panel A is already online. The reactor needs a fixed total. The player
  // determines the MISSING amount Panel B must contribute — matches the
  // brief's addition/subtraction example exactly, framed as a decision
  // about the world's state, not "what is 27 + 15?".
  static const int _panelAOutput = 27, _reactorRequirement = 42;
  static const int _missingAmount = _reactorRequirement - _panelAOutput; // 15

  @override
  void initState() {
    super.initState();
    _game = AstraColonyGame(onProximityChanged: (near) {
      if (mounted) setState(() => _isNearSolarArray = near);
    });
  }

  void _onJoystickDirection(Offset dir) => _game.setMoveDirection(Vector2(dir.dx, dir.dy));

  void _openConsole() => setState(() => _phase = _MissionPhase.repairConsole);

  void _submitAnswer(int value) {
    HapticFeedback.mediumImpact();
    if (value == _missingAmount) {
      _game.solarArray.repaired = true;
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 25, questionsAnswered: 1, correctAnswers: 1);
      setState(() { _solarArrayRepaired = true; _phase = _MissionPhase.complete; });
    } else {
      setState(() => _wrongFlash = true);
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongFlash = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _MissionPhase.intro) return _introScreen();
    if (_phase == _MissionPhase.complete) return _completeScreen();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Stack(children: [
        GameWidget(game: _game),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: _topHud())),
        if (_phase == _MissionPhase.playing) ...[
          Positioned(left: 20, bottom: 28, child: VirtualJoystickWidget(onDirectionChanged: _onJoystickDirection)),
          Positioned(right: 24, bottom: 40, child: _interactButton()),
        ],
        if (_phase == _MissionPhase.repairConsole) _consolePanel(),
      ]),
    );
  }

  // ── Top HUD: portrait/level/XP left, mission tracker center, resources right ──
  Widget _topHud() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _glassPanel(child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: GacomColors.deepOrange.withOpacity(0.25), border: Border.all(color: GacomColors.deepOrange, width: 1.5)),
            child: const Center(child: Icon(Icons.person_rounded, color: GacomColors.deepOrange, size: 18))),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('COMMANDER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white, letterSpacing: 0.5)),
            SizedBox(width: 72, child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: 0.15, minHeight: 4, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(GacomColors.accentCyan)))),
          ]),
        ])),
        const Spacer(),
        _glassPanel(child: Row(children: [
          _resourcePip('⚡', _solarArrayRepaired ? '100%' : '12%', _solarArrayRepaired ? GacomColors.success : GacomColors.error),
          const SizedBox(width: 10),
          const Icon(Icons.settings_rounded, color: Colors.white70, size: 18),
        ])),
      ]),
      const SizedBox(height: 8),
      _glassPanel(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('MISSION 1 · ARRIVAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.deepOrange, letterSpacing: 1)),
        Text(_solarArrayRepaired ? 'Solar Array restored' : 'Restore the Solar Array', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ])),
    ]),
  );

  Widget _resourcePip(String icon, String value, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(icon, style: const TextStyle(fontSize: 13)),
    const SizedBox(width: 3),
    Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: color)),
  ]);

  Widget _glassPanel({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.12)),
    ),
    child: child,
  );

  Widget _interactButton() => AnimatedOpacity(
    opacity: _isNearSolarArray ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: IgnorePointer(
      ignoring: !_isNearSolarArray,
      child: GestureDetector(
        onTap: _openConsole,
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
            Text('INTERACT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
          ]),
        ),
      ),
    ),
  );

  // ── Diegetic math console — a glass panel, world stays visible behind it ──
  Widget _consolePanel() => Positioned.fill(child: Container(
    color: Colors.black.withOpacity(0.4),
    child: Center(child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(28),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _wrongFlash ? GacomColors.error : GacomColors.accentCyan, width: 1.5),
        boxShadow: [BoxShadow(color: (_wrongFlash ? GacomColors.error : GacomColors.accentCyan).withOpacity(0.25), blurRadius: 16)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.settings_input_component_rounded, color: GacomColors.accentCyan, size: 16),
          SizedBox(width: 6),
          Text('REACTOR LINK CONSOLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.accentCyan, letterSpacing: 1)),
        ]),
        const SizedBox(height: 14),
        _consoleReadout('PANEL A — ONLINE', '$_panelAOutput units', GacomColors.success),
        _consoleReadout('REACTOR REQUIREMENT', '$_reactorRequirement units', Colors.white70),
        const Divider(color: Colors.white24, height: 22),
        const Text('Panel B is offline. How many more units must it contribute\nto reach the reactor requirement?',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: {_missingAmount, _missingAmount + 4, _missingAmount - 6, _missingAmount + 9}.map((v) => GestureDetector(
          onTap: () => _submitAnswer(v),
          child: Container(width: 70, height: 48, alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
            child: Text('$v', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white))),
        )).toList()),
        if (_wrongFlash) const Padding(padding: EdgeInsets.only(top: 12), child: Text('⚠ Link rejected — recalculate.', style: TextStyle(color: GacomColors.error, fontSize: 12))),
      ]),
    )),
  ));

  Widget _consoleReadout(String label, String value, Color valueColor) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5)),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: valueColor)),
    ]));

  Widget _introScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MISSION 1', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 2)),
      const SizedBox(height: 8),
      const Text('ARRIVAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: GacomColors.textPrimary)),
      const SizedBox(height: 20),
      const Text(
        'You are the Cadet Commander of the Astra Recovery Initiative. This colony has been dark for months. '
        'Power: 12%. The Solar Array is damaged — restore it to bring the colony back online.',
        style: TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
        child: const Row(children: [
          Icon(Icons.gamepad_rounded, color: GacomColors.deepOrange, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Use the joystick to walk. Get close to the Solar Array to INTERACT.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => setState(() => _phase = _MissionPhase.playing),
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('BEGIN MISSION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 1)))),
    ]))));

  Widget _completeScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('⚡', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      const Text('POWER RESTORED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: GacomColors.success)),
      const SizedBox(height: 8),
      const Text('The Solar Array hums to life. Lights flicker on across the colony for the first time in months.',
        textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textSecondary, fontSize: 14, height: 1.5)),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12)),
        child: const Column(children: [
          Text('+25 XP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.deepOrange)),
          SizedBox(height: 4),
          Text('Mission 2 — Rebuild — unlocked', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border), padding: const EdgeInsets.symmetric(vertical: 14)),
        child: const Text('RETURN TO COLONY MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary)))),
    ]))),
  );
}
