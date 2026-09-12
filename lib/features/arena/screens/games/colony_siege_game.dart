import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';
import 'level_map_screen.dart';

const _amber = Color(0xFFFFA940);
const _rust = Color(0xFFB8541F);
const _iron = Color(0xFF17171A);
const _ironPanel = Color(0xFF232326);
const _ironBorder = Color(0xFF4A4A50);
const _green = Color(0xFF3DDC84);

/// A genuine resource-management strategy game — no walking, no
/// collecting, no world at all. Multiple building slots run
/// simultaneously, each producing energy per second once built. The
/// actual decision, every time: which building is worth its cost RIGHT
/// NOW given what you can already afford and how much time is left. This
/// is a different genre from every other Colony Siege attempt, not a
/// reskin of "gather numbers to a target."
class BuildingType {
  const BuildingType(this.id, this.name, this.icon, this.cost, this.ratePerSecond);
  final String id, name, icon;
  final int cost;
  final double ratePerSecond;
}

const _catalogue = [
  BuildingType('solar', 'Solar Array', '☀️', 20, 1.5),
  BuildingType('farm', 'Farm Module', '🌾', 40, 3.5),
  BuildingType('lab', 'Research Lab', '🔬', 80, 8.0),
  BuildingType('reactor', 'Reactor Core', '⚡', 150, 16.0),
];

enum _SlotState { empty, constructing, active }

class _Slot {
  _SlotState state = _SlotState.empty;
  BuildingType? building;
  double constructionProgress = 0;
}

class ColonySiegeScreen extends StatefulWidget {
  const ColonySiegeScreen({super.key, this.subject = 'logic'});
  final String subject;

  @override
  State<ColonySiegeScreen> createState() => _ColonySiegeScreenState();
}

enum _Phase { levelMap, intro, playing, complete }

class _ColonySiegeScreenState extends State<ColonySiegeScreen> {
  static const int _slotCount = 6;
  static const double _tickSeconds = 0.1;
  static const double _constructionSeconds = 2.0;
  static const int _timeLimitSeconds = 90;

  _Phase _phase = _Phase.levelMap;
  int? _level;
  String _difficulty = 'Easy';
  int _target = 150;
  double _resources = 0;
  double _lifetimeEarned = 0;
  double _timeLeft = _timeLimitSeconds.toDouble();
  late List<_Slot> _slots;
  Timer? _timer;
  bool _won = false;

  void _selectLevel(int level, String difficulty) {
    setState(() { _level = level; _difficulty = difficulty; _target = 150 + level * 30; _phase = _Phase.intro; });
  }

  void _beginLevel() {
    _slots = List.generate(_slotCount, (_) => _Slot());
    _resources = 25; // enough to afford the cheapest building (Solar Array, cost 20) immediately
    _lifetimeEarned = 0;
    _timeLeft = _timeLimitSeconds.toDouble();
    setState(() => _phase = _Phase.playing);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (_tickSeconds * 1000).round()), _tick);
  }

  void _tick(Timer t) {
    if (!mounted) return;
    setState(() {
      _timeLeft -= _tickSeconds;
      for (final slot in _slots) {
        if (slot.state == _SlotState.constructing) {
          slot.constructionProgress += _tickSeconds / _constructionSeconds;
          if (slot.constructionProgress >= 1) {
            slot.constructionProgress = 1;
            slot.state = _SlotState.active;
          }
        } else if (slot.state == _SlotState.active) {
          final earned = slot.building!.ratePerSecond * _tickSeconds;
          _resources += earned;
          _lifetimeEarned += earned;
        }
      }

      if (_lifetimeEarned >= _target) {
        _won = true;
        _timer?.cancel();
        HapticFeedback.mediumImpact();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 20 + _level! * 2, questionsAnswered: 1, correctAnswers: 1);
        LevelMapScreen.unlockNext('colony_siege_v5', _level!);
        _phase = _Phase.complete;
      } else if (_timeLeft <= 0) {
        _won = false;
        _timer?.cancel();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
        _phase = _Phase.complete;
      }
    });
  }

  void _tapSlot(int index) {
    final slot = _slots[index];
    if (slot.state != _SlotState.empty) return;
    _showBuildPicker(index);
  }

  void _build(int index, BuildingType type) {
    if (_resources < type.cost) return;
    HapticFeedback.lightImpact();
    setState(() {
      _resources -= type.cost;
      _slots[index].state = _SlotState.constructing;
      _slots[index].building = type;
      _slots[index].constructionProgress = 0;
    });
    Navigator.of(context).pop();
  }

  void _showBuildPicker(int index) {
    showModalBottomSheet(context: context, backgroundColor: _ironPanel, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('BUILD', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _amber, letterSpacing: 2)),
        const SizedBox(height: 12),
        ..._catalogue.map((b) {
          final affordable = _resources >= b.cost;
          final payback = (b.cost / b.ratePerSecond).round();
          return GestureDetector(
            onTap: affordable ? () => _build(index, b) : null,
            child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: affordable ? _iron : _iron.withOpacity(0.4), border: Border.all(color: affordable ? _ironBorder : _ironBorder.withOpacity(0.4))),
              child: Row(children: [
                Text(b.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.name, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: affordable ? Colors.white : Colors.white38)),
                  Text('${b.ratePerSecond}/s · pays back in ~${payback}s', style: TextStyle(fontSize: 11, color: affordable ? Colors.white60 : Colors.white24)),
                ])),
                Text('${b.cost}⚡', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: affordable ? _amber : Colors.white24)),
              ])),
          );
        }),
      ])));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.levelMap) return LevelMapScreen(gameKey: 'colony_siege_v5', title: 'Colony Siege', onPlayLevel: _selectLevel);
    if (_phase == _Phase.intro) return _introScreen();
    if (_phase == _Phase.complete) return _completeScreen();

    return Scaffold(
      backgroundColor: _iron,
      appBar: AppBar(backgroundColor: _iron, title: Text('LEVEL $_level · $_difficulty', style: const TextStyle(color: _amber, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800))),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          _statCard('ENERGY', '${_resources.floor()}', _amber),
          const SizedBox(width: 10),
          _statCard('EARNED', '${_lifetimeEarned.floor()} / $_target', _green),
          const SizedBox(width: 10),
          _statCard('TIME', '${_timeLeft.ceil()}s', _timeLeft < 15 ? const Color(0xFFFF5A5F) : Colors.white70),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (_lifetimeEarned / _target).clamp(0, 1), minHeight: 8, backgroundColor: _ironPanel, valueColor: const AlwaysStoppedAnimation(_green)))),
        const SizedBox(height: 16),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85),
          itemCount: _slotCount,
          itemBuilder: (_, i) => _slotCard(i),
        ))),
      ])),
    );
  }

  Widget _statCard(String label, String value, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: _ironPanel, border: Border.all(color: _ironBorder)),
    child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: color)),
    ]),
  ));

  Widget _slotCard(int index) {
    final slot = _slots[index];
    Widget content;
    if (slot.state == _SlotState.empty) {
      content = const Icon(Icons.add_rounded, color: Colors.white24, size: 28);
    } else if (slot.state == _SlotState.constructing) {
      content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(slot.building!.icon, style: const TextStyle(fontSize: 22, color: Colors.white38)),
        const SizedBox(height: 6),
        SizedBox(width: 40, child: ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: slot.constructionProgress, minHeight: 4, backgroundColor: _iron, valueColor: const AlwaysStoppedAnimation(_amber)))),
      ]);
    } else {
      content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(slot.building!.icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 4),
        Text('+${slot.building!.ratePerSecond}/s', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 10, color: _green)),
      ]);
    }
    return GestureDetector(
      onTap: () => _tapSlot(index),
      child: Container(
        decoration: BoxDecoration(color: _ironPanel, border: Border.all(color: slot.state == _SlotState.active ? _amber.withOpacity(0.6) : _ironBorder, width: slot.state == _SlotState.active ? 2 : 1.5)),
        child: Center(child: content),
      ),
    );
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: _iron,
    appBar: AppBar(backgroundColor: _iron, title: Text('LEVEL $_level · $_difficulty', style: const TextStyle(color: _amber, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800))),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('MANAGE THE COLONY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: _amber, letterSpacing: 1)),
      const SizedBox(height: 16),
      Text('Earn $_target total energy in $_timeLimitSeconds seconds. You start with 25 energy — enough for one Solar Array. '
        'Cheaper buildings pay off fast but earn less; expensive ones cost more upfront but earn more per second. Choose wisely, time is limited.',
        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ironPanel, border: Border.all(color: _ironBorder, width: 2)),
        child: const Row(children: [
          Icon(Icons.query_stats_rounded, color: _amber, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Tap an empty slot to build. Every building keeps earning until time runs out.', style: TextStyle(color: Colors.white60, fontSize: 12))),
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
      Icon(_won ? Icons.bolt_rounded : Icons.timer_off_rounded, color: _won ? _amber : Colors.white38, size: 48),
      const SizedBox(height: 12),
      Text(_won ? 'COLONY THRIVING' : 'TIME EXPIRED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: _won ? _amber : Colors.white70, letterSpacing: 1)),
      const SizedBox(height: 8),
      Text(_won ? 'Level $_level complete — $_target energy earned.' : 'Earned ${_lifetimeEarned.floor()} of $_target energy.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5)),
      const SizedBox(height: 20),
      if (_won) Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _ironPanel, border: Border.all(color: _ironBorder, width: 2)),
        child: Text('+${20 + _level! * 2} XP', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: _amber))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: () => setState(() => _phase = _Phase.levelMap), style: OutlinedButton.styleFrom(side: const BorderSide(color: _ironBorder)),
          child: const Text('LEVEL MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
        const SizedBox(width: 12),
        GestureDetector(onTap: _won ? () => _selectLevel((_level! + 1).clamp(1, 20), LevelMapScreen.difficultyFor((_level! + 1).clamp(1, 20))) : () => _selectLevel(_level!, _difficulty),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: _rust, border: Border.all(color: _amber, width: 2)),
            child: Text(_won ? 'NEXT LEVEL' : 'RETRY', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)))),
      ]),
    ]))),
  );
}
