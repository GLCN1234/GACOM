import 'package:flame/game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/astra_colony_game.dart';
import '../../games/astra_colony/virtual_joystick_widget.dart';

/// Mission 1: "Arrival" — Quizzy: The Last Colony. Power cells are
/// physical, collectible objects in the world. There is no quiz popup
/// anywhere in this screen — the math is walking, choosing which cells to
/// collect, and depositing them at the console.
class AstraColonyScreen extends StatefulWidget {
  const AstraColonyScreen({super.key, this.subject = 'math'});
  final String subject;

  @override
  State<AstraColonyScreen> createState() => _AstraColonyScreenState();
}

enum _MissionPhase { intro, playing, complete }

class _AstraColonyScreenState extends State<AstraColonyScreen> {
  static const int _requiredTotal = 15;

  _MissionPhase _phase = _MissionPhase.intro;
  late AstraColonyGame _game;
  bool _isNearConsole = false;
  bool _overloadFlash = false;
  List<int> _heldCells = [];
  int _receivedTotal = 0;

  @override
  void initState() {
    super.initState();
    _game = AstraColonyGame(
      requiredTotal: _requiredTotal,
      onNearConsoleChanged: (near) { if (mounted) setState(() => _isNearConsole = near); },
      onHeldCellsChanged: (held) { if (mounted) setState(() => _heldCells = held); },
      onReceivedTotalChanged: (total) { if (mounted) setState(() => _receivedTotal = total); },
      onOverload: () {
        if (!mounted) return;
        HapticFeedback.heavyImpact();
        setState(() => _overloadFlash = true);
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) setState(() => _overloadFlash = false);
        });
      },
      onMissionComplete: () {
        if (!mounted) return;
        HapticFeedback.mediumImpact();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 25, questionsAnswered: 1, correctAnswers: 1);
        setState(() => _phase = _MissionPhase.complete);
      },
    );
  }

  void _onJoystickDirection(Offset dir) => _game.setMoveDirection(Vector2(dir.dx, dir.dy));
  void _deposit() { if (_heldCells.isNotEmpty) _game.depositHeldCells(); }

  @override
  Widget build(BuildContext context) {
    if (_phase == _MissionPhase.intro) return _introScreen();
    if (_phase == _MissionPhase.complete) return _completeScreen();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Stack(children: [
        GameWidget(game: _game),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: _topHud())),
        Positioned(left: 20, bottom: 28, child: VirtualJoystickWidget(onDirectionChanged: _onJoystickDirection)),
        Positioned(right: 24, bottom: 40, child: _actionButton()),
      ]),
    );
  }

  // ── Top HUD ──────────────────────────────────────────────────────────
  Widget _topHud() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Column(children: [
      Row(children: [
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
        _glassPanel(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('⚡ ${_receivedTotal >= _requiredTotal ? "100%" : "12%"}',
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: _receivedTotal >= _requiredTotal ? GacomColors.success : GacomColors.error)),
          const SizedBox(width: 10),
          const Icon(Icons.settings_rounded, color: Colors.white70, size: 18),
        ])),
      ]),
      const SizedBox(height: 8),
      // Persistent, non-blocking console gauge — visible at all times,
      // the world keeps moving behind it. No popup, ever.
      _glassPanel(borderColor: _overloadFlash ? GacomColors.error : null, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.settings_input_component_rounded, color: GacomColors.accentCyan, size: 13),
          const SizedBox(width: 5),
          Text(_overloadFlash ? 'OVERLOAD — CELLS RESET' : 'REACTOR: $_receivedTotal / $_requiredTotal UNITS',
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: _overloadFlash ? GacomColors.error : GacomColors.accentCyan, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 4),
        SizedBox(width: 160, child: ClipRRect(borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: (_receivedTotal / _requiredTotal).clamp(0, 1), minHeight: 5, backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(_overloadFlash ? GacomColors.error : GacomColors.accentCyan)))),
      ])),
    ]),
  );

  Widget _glassPanel({required Widget child, Color? borderColor}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.12), width: borderColor != null ? 1.5 : 1),
    ),
    child: child,
  );

  // ── Held cells + context action button ──────────────────────────────
  Widget _actionButton() {
    final holding = _heldCells.isNotEmpty;
    final canDeposit = holding && _isNearConsole;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (holding) Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('HOLDING ', style: TextStyle(color: Colors.white70, fontSize: 10)),
          ..._heldCells.map((v) => Container(margin: const EdgeInsets.only(left: 3), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF3DD6FF).withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            child: Text('$v', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Color(0xFF3DD6FF))))),
        ]),
      ),
      AnimatedOpacity(
        opacity: canDeposit ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: !canDeposit,
          child: GestureDetector(
            onTap: _deposit,
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
                Text('DEPOSIT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.5)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MISSION 1', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 2)),
      const SizedBox(height: 8),
      const Text('ARRIVAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: GacomColors.textPrimary)),
      const SizedBox(height: 20),
      const Text(
        'The Solar Array needs 15 more units to reach reactor capacity. Power cells are scattered nearby — '
        'collect the right ones and deposit them at the array. Overshoot the target and the console overloads.',
        style: TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
        child: const Row(children: [
          Icon(Icons.gamepad_rounded, color: GacomColors.deepOrange, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Walk over a cell to collect it. Get close to the array and tap DEPOSIT.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))),
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
