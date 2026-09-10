import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/astra_colony_game.dart';

/// Mission 1: "Arrival" — the first real Quizzy: The Last Colony slice.
/// Tap to walk the Cadet Commander to the damaged Solar Array; the repair
/// puzzle at the console IS the math, not a quiz interrupting the game.
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
  int? _selectedAnswer;
  bool _wrongFlash = false;
  // Tracked separately from Flame's internal component state — never read
  // _game.solarArray.repaired directly from a Flutter build() call, since
  // that field is only set inside Flame's async onLoad() and may not be
  // initialized yet on an early frame (this caused a LateInitializationError).
  bool _solarArrayRepaired = false;

  // The puzzle: two damaged panels' readouts. The correct action is their
  // sum — this IS the addition being taught, framed as routing power
  // through the console, not "what is 27 + 15?".
  static const int _panelA = 27, _panelB = 15;
  static const int _correctTotal = _panelA + _panelB;

  @override
  void initState() {
    super.initState();
    _game = AstraColonyGame(onReachSolarArray: () {
      if (mounted) setState(() => _phase = _MissionPhase.repairConsole);
    });
  }

  void _submitAnswer(int value) {
    HapticFeedback.mediumImpact();
    if (value == _correctTotal) {
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
        Positioned(top: 0, left: 0, right: 0, child: _hud()),
        if (_phase == _MissionPhase.repairConsole) _repairConsoleOverlay(),
      ]),
    );
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
        'You are the Cadet Commander of the Astra Recovery Initiative. This colony has been dark for months. '
        'Power: 12%. The Solar Array is damaged — restore it to bring the colony back online.',
        style: TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.border)),
        child: const Row(children: [
          Icon(Icons.touch_app_rounded, color: GacomColors.deepOrange, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Tap anywhere to walk. Tap the Solar Array to reach it.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => setState(() => _phase = _MissionPhase.playing),
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('BEGIN MISSION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 1)))),
    ]))));

  Widget _hud() => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [GacomColors.obsidian.withOpacity(0.9), Colors.transparent])),
    child: Row(children: [
      Text(_solarArrayRepaired ? '⚡ POWER: RESTORED' : '⚡ POWER: 12%',
        style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: _solarArrayRepaired ? GacomColors.success : GacomColors.error)),
      const Spacer(),
      const Text('MISSION 1 · ARRIVAL', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
    ]),
  );

  Widget _repairConsoleOverlay() {
    final options = <int>{_correctTotal, _correctTotal + 5, _correctTotal - 8, _correctTotal + 12}.toList()..shuffle();
    return Positioned.fill(child: Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(28),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _wrongFlash ? GacomColors.error : GacomColors.deepOrange, width: 1.5),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SOLAR ARRAY — REPAIR CONSOLE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.deepOrange, letterSpacing: 1)),
          const SizedBox(height: 14),
          _consoleLine('Panel A output', '$_panelA units'),
          _consoleLine('Panel B output', '$_panelB units'),
          const Divider(color: GacomColors.border, height: 24),
          const Text('Route the correct TOTAL power to the reactor:', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: options.map((v) => GestureDetector(
            onTap: () => _submitAnswer(v),
            child: Container(width: 76, height: 52, alignment: Alignment.center,
              decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.border)),
              child: Text('$v', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary))),
          )).toList()),
          if (_wrongFlash) const Padding(padding: EdgeInsets.only(top: 12), child: Text('⚠ Incorrect routing — try again.', style: TextStyle(color: GacomColors.error, fontSize: 12))),
        ]),
      )),
    ));
  }

  Widget _consoleLine(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
      Text(value, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textPrimary)),
    ]));

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
