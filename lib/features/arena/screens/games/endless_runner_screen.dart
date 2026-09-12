import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';
import 'level_map_screen.dart';

const _bg = Color(0xFF0B0B0F);
const _panel = Color(0xFF1A1A22);
const _accent = Color(0xFF3DD6FF);
const _danger = Color(0xFFFF5A5F);
const _gold = Color(0xFFFFC940);

/// A genuine endless runner — the exact known genre (Subway Surfers-style
/// lane switching), not an invented mechanic. Three lanes, one correct
/// answer lane per gate, swipe to switch, run through the right one.
/// Continuous and smooth: gates keep coming, no popups, no pauses.
class EndlessRunnerScreen extends StatefulWidget {
  const EndlessRunnerScreen({super.key, this.subject = 'general', this.questions});
  final String subject;
  final List<Map<String, dynamic>>? questions;

  @override
  State<EndlessRunnerScreen> createState() => _EndlessRunnerScreenState();
}

const _fallbackQuestions = [
  {'question': 'What is 12 × 8?', 'options': ['96', '84', '108', '92']},
  {'question': 'Capital of Nigeria?', 'options': ['Abuja', 'Lagos', 'Kano', 'Ibadan']},
  {'question': 'What gas do plants absorb?', 'options': ['Carbon Dioxide', 'Oxygen', 'Nitrogen', 'Hydrogen']},
  {'question': 'Who wrote "Things Fall Apart"?', 'options': ['Chinua Achebe', 'Wole Soyinka', 'Chimamanda Adichie', 'Ben Okri']},
  {'question': 'Square root of 144?', 'options': ['12', '11', '14', '10']},
  {'question': 'Largest ocean on Earth?', 'options': ['Pacific', 'Atlantic', 'Indian', 'Arctic']},
  {'question': 'What is 9 + 16?', 'options': ['25', '23', '27', '24']},
  {'question': 'Powerhouse of the cell?', 'options': ['Mitochondria', 'Nucleus', 'Ribosome', 'Golgi Body']},
];

class _Gate {
  _Gate({required this.lanes, required this.correctLane});
  final List<String> lanes; // exactly 3, one per lane
  final int correctLane;
  double y = -0.25; // 0 = top, 1 = player's row, in screen-fraction units
  bool resolved = false;
  bool? wasCorrect; // set once resolved, drives pass/fail visual feedback
  int? resolvedPlayerLane; // which lane the player was actually in at resolution — captured once, not read live, since the player may move lanes again before this gate scrolls off screen
}

enum _Phase { levelMap, intro, playing, complete }

class _EndlessRunnerScreenState extends State<EndlessRunnerScreen> {
  _Phase _phase = _Phase.levelMap;
  int? _level;
  String _difficulty = 'Easy';
  int _targetCorrect = 10;
  double _gateSpeed = 0.28; // screen-fractions per second

  int _lane = 1;
  int _lives = 3;
  int _score = 0;
  int _correctCount = 0;
  final List<_Gate> _gates = [];
  Timer? _timer;
  late List<Map<String, dynamic>> _questionPool;
  int _questionCursor = 0;

  static const double _tickSeconds = 1 / 60;
  static const double _playerRowY = 0.86;

  void _selectLevel(int level, String difficulty) {
    setState(() {
      _level = level;
      _difficulty = difficulty;
      _targetCorrect = 8 + level;
      _gateSpeed = difficulty == 'Easy' ? 0.22 : difficulty == 'Medium' ? 0.30 : 0.4;
      _phase = _Phase.intro;
    });
  }

  void _beginLevel() {
    _questionPool = (widget.questions != null && widget.questions!.isNotEmpty)
        ? (List<Map<String, dynamic>>.from(widget.questions!)..shuffle())
        : ([..._fallbackQuestions]..shuffle());
    _questionCursor = 0;
    _lane = 1;
    _lives = 3;
    _score = 0;
    _correctCount = 0;
    _gates.clear();
    _spawnGate();
    setState(() => _phase = _Phase.playing);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (_tickSeconds * 1000).round()), _tick);
  }

  void _spawnGate() {
    if (_questionPool.isEmpty) return;
    final q = _questionPool[_questionCursor % _questionPool.length];
    _questionCursor++;

    final rawOptions = List<String>.from(q['options'] as List? ?? const []);
    final answer = q['answer'] as String?;
    final correctText = answer ?? rawOptions.first;
    final wrongPool = rawOptions.where((o) => o != correctText).toList()..shuffle();
    final picks = <String>[correctText, ...wrongPool.take(2)];
    picks.shuffle();
    final correctLane = picks.indexOf(correctText);

    _gates.add(_Gate(lanes: picks, correctLane: correctLane));
  }

  void _tick(Timer t) {
    if (!mounted) return;
    setState(() {
      for (final gate in _gates) {
        if (gate.resolved) continue;
        gate.y += _gateSpeed * _tickSeconds;
        if (gate.y >= _playerRowY) {
          gate.resolved = true;
          _resolveGate(gate);
        }
      }
      _gates.removeWhere((g) => g.resolved && g.y > 1.05);

      if (_gates.isEmpty || _gates.last.y > 0.32) {
        _spawnGate();
      }
    });
  }

  void _resolveGate(_Gate gate) {
    final correct = _lane == gate.correctLane;
    gate.wasCorrect = correct;
    gate.resolvedPlayerLane = _lane;
    HapticFeedback.mediumImpact();
    EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: correct ? 10 : 0, questionsAnswered: 1, correctAnswers: correct ? 1 : 0);
    if (correct) {
      _score += 10;
      _correctCount++;
      if (_correctCount >= _targetCorrect) {
        _timer?.cancel();
        LevelMapScreen.unlockNext('endless_runner', _level!);
        _phase = _Phase.complete;
      }
    } else {
      _lives--;
      if (_lives <= 0) {
        _timer?.cancel();
        _phase = _Phase.complete;
      }
    }
  }

  void _changeLane(int delta) {
    if (_phase != _Phase.playing) return;
    setState(() => _lane = (_lane + delta).clamp(0, 2));
  }

  Color _gateColor(_Gate gate, int lane) {
    if (!gate.resolved) return _panel;
    if (lane == gate.resolvedPlayerLane) {
      return gate.wasCorrect == true ? const Color(0xFF1B3B2E) : const Color(0xFF3B1B1F);
    }
    return _panel.withOpacity(0.5);
  }

  Color _gateBorderColor(_Gate gate, int lane) {
    if (!gate.resolved) return Colors.white24;
    if (lane == gate.correctLane) return const Color(0xFF3DDC84);
    if (lane == gate.resolvedPlayerLane) return _danger;
    return Colors.white12;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.levelMap) return LevelMapScreen(gameKey: 'endless_runner', title: 'Signal Run', onPlayLevel: _selectLevel);
    if (_phase == _Phase.intro) return _introScreen();
    if (_phase == _Phase.complete) return _completeScreen();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
          Row(children: List.generate(3, (i) => Icon(i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _danger, size: 18))),
          const Spacer(),
          Text('$_correctCount / $_targetCorrect', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _accent)),
          const SizedBox(width: 14),
          Text('SCORE $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _gold)),
        ])),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v > 150) _changeLane(1);
              if (v < -150) _changeLane(-1);
            },
            child: LayoutBuilder(builder: (context, constraints) {
              final w = constraints.maxWidth, h = constraints.maxHeight;
              final laneX = [w * 1 / 6, w * 3 / 6, w * 5 / 6];
              return Stack(children: [
                for (final x in [w / 3, 2 * w / 3])
                  Positioned(left: x, top: 0, bottom: 0, child: Container(width: 1, color: Colors.white10)),
                for (final gate in _gates)
                  for (int lane = 0; lane < 3; lane++)
                    Positioned(
                      left: laneX[lane] - 46, top: gate.y * h - 22,
                      child: Container(width: 92, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: _gateColor(gate, lane),
                          border: Border.all(color: _gateBorderColor(gate, lane), width: gate.resolved && lane == _lane ? 2.5 : 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(gate.lanes[lane], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                    ),
                if (_gates.any((g) => !g.resolved))
                  Positioned(top: 8, left: 16, right: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                    child: Text(_questionPool[(_questionCursor - 1) % _questionPool.length]['question'] as String,
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12)))),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 150), curve: Curves.easeOut,
                  left: laneX[_lane] - 16, top: _playerRowY * h - 16,
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: _accent,
                    boxShadow: [BoxShadow(color: _accent.withOpacity(0.6), blurRadius: 10)])),
                ),
              ]);
            }),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          GestureDetector(onTap: () => _changeLane(-1), child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18))),
          GestureDetector(onTap: () => _changeLane(1), child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18))),
        ])),
      ])),
    );
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: Text('LEVEL $_level · $_difficulty')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SIGNAL RUN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _accent)),
      const SizedBox(height: 16),
      Text('Get $_targetCorrect correct before you run out of lives. Swipe or tap the arrows to switch lanes — run through the lane with the right answer as the gate reaches you.',
        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.swipe_rounded, color: _accent, size: 20), SizedBox(width: 10),
          Expanded(child: Text('3 lanes, one correct answer. Swipe left/right. Keep running.', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _beginLevel,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('RUN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 2)))),
    ]))));

  Widget _completeScreen() {
    final won = _correctCount >= _targetCorrect;
    return Scaffold(
      backgroundColor: _bg,
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(won ? Icons.emoji_events_rounded : Icons.heart_broken_rounded, color: won ? _gold : _danger, size: 48),
        const SizedBox(height: 12),
        Text(won ? 'LEVEL CLEAR' : 'OUT OF LIVES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: won ? _gold : _danger)),
        const SizedBox(height: 8),
        Text('$_correctCount / $_targetCorrect correct · Score $_score', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(onPressed: () => setState(() => _phase = _Phase.levelMap), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
            child: const Text('LEVEL MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: won ? () => _selectLevel((_level! + 1).clamp(1, 20), LevelMapScreen.difficultyFor((_level! + 1).clamp(1, 20))) : () => _selectLevel(_level!, _difficulty),
            style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(won ? 'NEXT LEVEL' : 'RETRY', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.black))),
        ]),
      ]))),
    );
  }
}
