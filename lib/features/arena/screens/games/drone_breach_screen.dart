import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';

const _bg = Color(0xFF0B0B0F);
const _panel = Color(0xFF1A1A22);
const _accent = Color(0xFF3DD6FF);
const _danger = Color(0xFFFF5A5F);
const _gold = Color(0xFFFFC940);
const _green = Color(0xFF3DDC84);

/// A generic subject block: topic name + real generated_questions
/// (question/options/answer schema).
class TopicBlock {
  const TopicBlock({required this.topicName, required this.questions});
  final String topicName;
  final List<Map<String, dynamic>> questions;
}

/// Drone Breach — a runner-shooter in the Into the Dead 2 mould. The
/// world scrolls continuously toward you; rogue drones approach carrying
/// answer options. TAP the correct one to shoot it down — the core verb
/// is aim-and-shoot, not swipe-to-dodge, deliberately different from
/// Signal Run's lane-switching. Let one reach you unshot, or shoot the
/// wrong one, and you take a hit. One continuous run, no levels.
class DroneBreachScreen extends StatefulWidget {
  const DroneBreachScreen({super.key, this.subject = 'general', this.topics});
  final String subject;
  final List<TopicBlock>? topics;

  @override
  State<DroneBreachScreen> createState() => _DroneBreachScreenState();
}

const _fallbackTopics = [
  TopicBlock(topicName: 'General Knowledge', questions: [
    {'question': 'What is 12 × 8?', 'options': ['96', '84', '108', '92'], 'answer': '96'},
    {'question': 'Capital of Nigeria?', 'options': ['Abuja', 'Lagos', 'Kano', 'Ibadan'], 'answer': 'Abuja'},
    {'question': 'What gas do plants absorb?', 'options': ['Carbon Dioxide', 'Oxygen', 'Nitrogen', 'Hydrogen'], 'answer': 'Carbon Dioxide'},
    {'question': 'Who wrote "Things Fall Apart"?', 'options': ['Chinua Achebe', 'Wole Soyinka', 'Chimamanda Adichie', 'Ben Okri'], 'answer': 'Chinua Achebe'},
    {'question': 'Square root of 144?', 'options': ['12', '11', '14', '10'], 'answer': '12'},
    {'question': 'Largest ocean on Earth?', 'options': ['Pacific', 'Atlantic', 'Indian', 'Arctic'], 'answer': 'Pacific'},
    {'question': 'What is 9 + 16?', 'options': ['25', '23', '27', '24'], 'answer': '25'},
    {'question': 'Powerhouse of the cell?', 'options': ['Mitochondria', 'Nucleus', 'Ribosome', 'Golgi Body'], 'answer': 'Mitochondria'},
  ]),
];

class _Drone {
  _Drone({required this.lane, required this.label, required this.isTarget});
  final int lane;
  final String label;
  final bool isTarget; // true = the correct answer for the current question
  double y = -0.15;
  bool destroyed = false;
  bool? shotCorrectly; // null = not yet shot
}

enum _Phase { intro, playing, gameOver }

class _DroneBreachScreenState extends State<DroneBreachScreen> {
  static const double _tickSeconds = 1 / 60;
  static const double _dangerRowY = 0.82;
  static const double _baseSpeed = 0.20;

  List<TopicBlock> get _topics => (widget.topics != null && widget.topics!.isNotEmpty) ? widget.topics! : _fallbackTopics;

  _Phase _phase = _Phase.intro;
  int _lives = 3;
  int _score = 0;
  int _correctCount = 0;
  double _elapsed = 0;
  double _timeSinceLastWave = 999;
  int _topicIndex = 0;
  int _questionCursor = 0;
  String? _missionBanner;
  Timer? _bannerTimer;

  final List<_Drone> _drones = [];
  Timer? _timer;

  double get _speed => _baseSpeed + (_elapsed / 45).clamp(0, 0.22);
  double get _waveInterval => (2.4 - (_elapsed / 60).clamp(0, 1.0)).clamp(1.4, 2.4);

  void _begin() {
    _lives = 3;
    _score = 0;
    _correctCount = 0;
    _elapsed = 0;
    _topicIndex = 0;
    _questionCursor = 0;
    _drones.clear();
    _timeSinceLastWave = 999;
    setState(() => _phase = _Phase.playing);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (_tickSeconds * 1000).round()), _tick);
    _flashBanner(_topics[0].topicName);
  }

  void _flashBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _missionBanner = text);
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _missionBanner = null);
    });
  }

  void _tick(Timer t) {
    if (!mounted) return;
    setState(() {
      _elapsed += _tickSeconds;
      _timeSinceLastWave += _tickSeconds;
      if (_timeSinceLastWave >= _waveInterval && _drones.every((d) => d.destroyed)) {
        _timeSinceLastWave = 0;
        _spawnWave();
      }

      for (final drone in _drones) {
        drone.y += _speed * _tickSeconds;
        if (!drone.destroyed && drone.y >= _dangerRowY) {
          _droneBreached(drone);
        }
      }
      _drones.removeWhere((d) => d.y > 1.05);

      if (_lives <= 0) {
        _timer?.cancel();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: _score ~/ 5, questionsAnswered: 1, correctAnswers: 1);
        _phase = _Phase.gameOver;
      }
    });
  }

  void _spawnWave() {
    final topic = _topics[_topicIndex];
    if (topic.questions.isEmpty) return;
    final q = topic.questions[_questionCursor % topic.questions.length];
    final rawOptions = List<String>.from(q['options'] as List? ?? const []);
    final answer = q['answer'] as String? ?? (rawOptions.isNotEmpty ? rawOptions.first : '');
    final wrongPool = rawOptions.where((o) => o != answer).toList()..shuffle();
    final picks = <String>[answer, ...wrongPool.take(2)];
    picks.shuffle();

    final lanes = [0, 1, 2]..shuffle();
    for (int i = 0; i < picks.length && i < lanes.length; i++) {
      _drones.add(_Drone(lane: lanes[i], label: picks[i], isTarget: picks[i] == answer));
    }

    _questionCursor++;
    if (_questionCursor >= topic.questions.length) {
      _questionCursor = 0;
      _topicIndex = (_topicIndex + 1) % _topics.length;
      _flashBanner(_topics[_topicIndex].topicName);
    }
  }

  void _droneBreached(_Drone drone) {
    drone.destroyed = true;
    if (drone.isTarget) {
      // The correct answer got past you unshot — a real miss.
      _lives--;
      HapticFeedback.heavyImpact();
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
    }
  }

  void _shoot(_Drone drone) {
    if (_phase != _Phase.playing || drone.destroyed) return;
    HapticFeedback.mediumImpact();
    drone.destroyed = true;
    drone.shotCorrectly = drone.isTarget;
    if (drone.isTarget) {
      _score += 20;
      _correctCount++;
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 10, questionsAnswered: 1, correctAnswers: 1);
    } else {
      _lives--;
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
      HapticFeedback.heavyImpact();
    }
    setState(() {});
  }

  @override
  void dispose() { _timer?.cancel(); _bannerTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) return _introScreen();
    if (_phase == _Phase.gameOver) return _gameOverScreen();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
          Row(children: List.generate(3, (i) => Icon(i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _danger, size: 18))),
          const Spacer(),
          Text('$_correctCount hit', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: _accent)),
          const SizedBox(width: 14),
          Text('SCORE $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _gold)),
        ])),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            final laneX = [w * 1 / 6, w * 3 / 6, w * 5 / 6];
            return Stack(children: [
              for (final x in [w / 3, 2 * w / 3])
                Positioned(left: x, top: 0, bottom: 0, child: Container(width: 1, color: Colors.white10)),
              for (final drone in _drones) _droneWidget(drone, laneX, h),
              // Player's turret, fixed at the bottom center — the shooter,
              // not a lane-bound runner.
              Positioned(bottom: 24, left: w / 2 - 18, child: Container(width: 36, height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withOpacity(0.15), border: Border.all(color: _accent, width: 2)),
                child: const Icon(Icons.gps_fixed_rounded, color: _accent, size: 18))),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
                top: _missionBanner != null ? 12 : -60, left: 16, right: 16,
                child: _missionBanner == null ? const SizedBox.shrink() : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: _gold.withOpacity(0.5), blurRadius: 10)]),
                  child: Text('NEW MISSION: ${_missionBanner!.toUpperCase()}', textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black)),
                ),
              ),
            ]);
          }),
        ),
      ])),
    );
  }

  Widget _droneWidget(_Drone drone, List<double> laneX, double h) {
    Color borderColor = Colors.white24;
    Color fillColor = _panel;
    if (drone.shotCorrectly != null) {
      borderColor = drone.shotCorrectly! ? _green : _danger;
      fillColor = (drone.shotCorrectly! ? _green : _danger).withOpacity(0.25);
    }
    return Positioned(
      left: laneX[drone.lane] - 48, top: drone.y * h - 24,
      child: GestureDetector(
        onTap: () => _shoot(drone),
        child: Container(width: 96, padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: fillColor, border: Border.all(color: borderColor, width: 2), borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.smart_toy_rounded, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(drone.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ])),
      ),
    );
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: const Text('DRONE BREACH')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('HOLD THE LINE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _accent)),
      const SizedBox(height: 16),
      const Text('Rogue drones approach carrying answers. TAP the one carrying the correct answer to shoot it down. '
        'Shoot the wrong one, or let the correct one reach you unshot, and you take a hit. One continuous run — no levels.',
        style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.gps_fixed_rounded, color: _accent, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Tap to shoot. Aim for the correct answer before it reaches your line.', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('ENGAGE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 2)))),
    ]))));

  Widget _gameOverScreen() => Scaffold(
    backgroundColor: _bg,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.heart_broken_rounded, color: _danger, size: 48),
      const SizedBox(height: 12),
      const Text('LINE BREACHED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: _danger)),
      const SizedBox(height: 8),
      Text('Score $_score · $_correctCount correct', style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('ENGAGE AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 1)))),
    ]))),
  );
}
