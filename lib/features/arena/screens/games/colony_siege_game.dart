import 'package:flame/game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/colony_siege_game.dart';
import '../../games/astra_colony/virtual_joystick_widget.dart';
import 'level_map_screen.dart';

/// Colony Siege v3: collect fuel pods, physically bring them to the
/// Transporter and LOAD it (distinct from collecting), then LAUNCH it —
/// the Transporter drives itself to the Reactor and delivers on arrival.
/// A genuinely different rhythm from Field Trial's instant-deposit, not a
/// reskin of it.
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
  bool _isNearTransporter = false;
  bool _isDriving = false;
  bool _overloadFlash = false;
  List<int> _heldPods = [];
  int _transporterLoad = 0;
  int _received = 0;

  void _selectLevel(int level, String difficulty) {
    final target = 10 + level * 3;
    setState(() { _level = level; _difficulty = difficulty; _requiredTotal = target; _phase = _Phase.intro; });
  }

  void _beginLevel() {
    _game = ColonySiegeGame(
      requiredTotal: _requiredTotal,
      onNearTransporterChanged: (near) { if (mounted) setState(() => _isNearTransporter = near); },
      onHeldPodsChanged: (held) { if (mounted) setState(() => _heldPods = held); },
      onTransporterLoadChanged: (load) { if (mounted) setState(() => _transporterLoad = load); },
      onTransporterDrivingChanged: (driving) { if (mounted) setState(() => _isDriving = driving); },
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
        LevelMapScreen.unlockNext('colony_siege_v3', _level!);
        setState(() => _phase = _Phase.complete);
      },
    );
    setState(() { _isNearTransporter = false; _isDriving = false; _heldPods = []; _transporterLoad = 0; _received = 0; _phase = _Phase.playing; });
  }

  void _onJoystickDirection(Offset dir) => _game.setMoveDirection(Vector2(dir.dx, dir.dy));
  void _load() => _game.loadTransporter();
  void _launch() => _game.launchTransporter();

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.levelMap) return LevelMapScreen(gameKey: 'colony_siege_v3', title: 'Colony Siege', onPlayLevel: _selectLevel);
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
          Icon(_isDriving ? Icons.local_shipping_rounded : Icons.bolt_rounded, color: _isDriving ? GacomColors.accentCyan : GacomColors.accentCyan, size: 13),
          const SizedBox(width: 5),
          Text(
            _overloadFlash ? 'REACTOR OVERLOAD — PODS RESET'
              : _isDriving ? 'TRANSPORTER EN ROUTE…'
              : 'REACTOR TARGET: $_requiredTotal UNITS',
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
    final canLoad = holding && _isNearTransporter && !_isDriving;
    final canLaunch = _transporterLoad > 0 && _isNearTransporter && !_isDriving;

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (holding) _chipRow('CARRYING', _heldPods, const Color(0xFF3DD6FF)),
      if (_transporterLoad > 0) Padding(padding: const EdgeInsets.only(bottom: 10), child: _pill('TRANSPORTER: $_transporterLoad', GacomColors.deepOrange)),
      if (canLoad) Padding(padding: const EdgeInsets.only(bottom: 8), child: _actionButton('LOAD', Icons.upload_rounded, _load)),
      if (canLaunch) _actionButton('LAUNCH', Icons.send_rounded, _launch),
    ]);
  }

  Widget _chipRow(String label, List<int> values, Color color) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label ', style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ...values.map((v) => Container(margin: const EdgeInsets.only(left: 3), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
        child: Text('$v', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: color)))),
    ]),
  );

  Widget _actionButton(String label, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: GacomColors.deepOrange,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.5), blurRadius: 12)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
      ]),
    ),
  );

  Widget _introScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: Text('LEVEL $_level · $_difficulty')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('POWER THE REACTOR', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
      const SizedBox(height: 16),
      Text('The Reactor Core needs exactly $_requiredTotal units. Collect fuel pods, bring them to the Transporter and LOAD it, '
        'then LAUNCH it — it drives itself to the Reactor. Overshoot the target and it vents steam, resetting the pods.',
        style: const TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
        child: const Row(children: [
          Icon(Icons.gamepad_rounded, color: GacomColors.deepOrange, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Collect pods → walk to the Transporter → LOAD → LAUNCH.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))),
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
