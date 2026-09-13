import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/topic_block.dart';

// A distinct, vibrant palette — warm sunset gradient, not the dark
// cyan/panel look used by Signal Run or Drone Breach.
const _bgTop = Color(0xFF2A0E4A);
const _bgBottom = Color(0xFF7B1E5C);
const _gemColors = [Color(0xFFFF6B9D), Color(0xFFFFC85C), Color(0xFF5CE1E6), Color(0xFFB08CFF)];
const _danger = Color(0xFFFF4757);
const _green = Color(0xFF3DDC84);

/// Signal Match — a swipe-to-slice game in the Fruit Ninja mould.
/// Answer gems launch upward and arc back down across the whole open
/// play space (no lanes, no fixed targets). Swipe your finger THROUGH
/// the correct gem to slice it. This is a third, genuinely distinct
/// gesture from Signal Run's swipe-to-switch-lane and Drone Breach's
/// tap-to-shoot — a continuous swipe path checked against target
/// positions, not a discrete tap or a directional flick.
class SignalMatchScreen extends StatefulWidget {
  const SignalMatchScreen({super.key, this.subject = 'general', this.topics});
  final String subject;
  final List<TopicBlock>? topics;

  @override
  State<SignalMatchScreen> createState() => _SignalMatchScreenState();
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

class _Gem {
  _Gem({required this.label, required this.isTarget, required this.x, required this.vy, required this.color});
  final String label;
  final bool isTarget;
  final double x; // fixed horizontal position, 0..1 of screen width
  double y = 1.05; // starts just below screen, 0 = top, 1 = bottom
  double vy; // negative = moving up
  final Color color;
  bool sliced = false;
  bool? sliceCorrect;
}

enum _Phase { intro, playing, gameOver }

class _SignalMatchScreenState extends State<SignalMatchScreen> {
  static const double _tickSeconds = 1 / 60;
  static const double _gravity = 1.7; // screen-heights per second^2

  List<TopicBlock> get _topics => (widget.topics != null && widget.topics!.isNotEmpty) ? widget.topics! : _fallbackTopics;

  _Phase _phase = _Phase.intro;
  int _lives = 3;
  int _score = 0;
  int _correctCount = 0;
  double _elapsed = 0;
  int _topicIndex = 0;
  int _questionCursor = 0;
  String? _missionBanner;
  String _currentQuestion = '';
  Timer? _bannerTimer;

  final List<_Gem> _gems = [];
  final List<Offset> _trail = [];
  Timer? _timer;
  final _rng = Random();
  bool _waveActive = false;

  void _begin() {
    _lives = 3;
    _score = 0;
    _correctCount = 0;
    _elapsed = 0;
    _topicIndex = 0;
    _questionCursor = 0;
    _gems.clear();
    _waveActive = false;
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

      for (final gem in _gems) {
        gem.vy += _gravity * _tickSeconds;
        gem.y += gem.vy * _tickSeconds;
      }

      // A gem that falls back past the bottom, unsliced, is a miss — only
      // penalised if it was the correct one, same rule as Drone Breach.
      for (final gem in _gems) {
        if (!gem.sliced && gem.y > 1.08) {
          gem.sliced = true;
          if (gem.isTarget) {
            _lives--;
            HapticFeedback.heavyImpact();
            EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
          }
        }
      }
      _gems.removeWhere((g) => g.sliced && g.y > 1.3);

      if (_gems.isEmpty && _waveActive) _waveActive = false;
      if (!_waveActive) {
        _waveActive = true;
        _spawnWave();
      }

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
    _currentQuestion = q['question'] as String? ?? '';

    final xs = [0.22, 0.5, 0.78]..shuffle();
    for (int i = 0; i < picks.length && i < xs.length; i++) {
      _gems.add(_Gem(
        label: picks[i],
        isTarget: picks[i] == answer,
        x: xs[i],
        vy: -1.05 - _rng.nextDouble() * 0.2,
        color: _gemColors[_rng.nextInt(_gemColors.length)],
      ));
    }

    _questionCursor++;
    if (_questionCursor >= topic.questions.length) {
      _questionCursor = 0;
      _topicIndex = (_topicIndex + 1) % _topics.length;
      _flashBanner(_topics[_topicIndex].topicName);
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    _trail.add(details.localPosition);
    if (_trail.length > 10) _trail.removeAt(0);

    for (final gem in _gems) {
      if (gem.sliced) continue;
      final gemPos = Offset(gem.x * size.width, gem.y * size.height);
      if ((details.localPosition - gemPos).distance < 40) {
        _slice(gem);
      }
    }
    setState(() {});
  }

  void _slice(_Gem gem) {
    gem.sliced = true;
    gem.sliceCorrect = gem.isTarget;
    HapticFeedback.mediumImpact();
    if (gem.isTarget) {
      _score += 20;
      _correctCount++;
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 10, questionsAnswered: 1, correctAnswers: 1);
    } else {
      _lives--;
      HapticFeedback.heavyImpact();
      EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
    }
  }

  @override
  void dispose() { _timer?.cancel(); _bannerTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) return _introScreen();
    if (_phase == _Phase.gameOver) return _gameOverScreen();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
            Row(children: List.generate(3, (i) => Icon(i < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _danger, size: 18))),
            const Spacer(),
            Text('$_correctCount sliced', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)),
            const SizedBox(width: 14),
            Text('SCORE $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFFFC85C))),
          ])),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(_currentQuestion, textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanUpdate: (d) => _onPanUpdate(d, size),
                onPanEnd: (_) => setState(() => _trail.clear()),
                child: Stack(children: [
                  Positioned.fill(child: Container(color: Colors.transparent)),
                  CustomPaint(size: size, painter: _TrailPainter(_trail)),
                  for (final gem in _gems) _gemWidget(gem, size),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
                    top: _missionBanner != null ? 12 : -60, left: 16, right: 16,
                    child: _missionBanner == null ? const SizedBox.shrink() : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)]),
                      child: Text('NEW MISSION: ${_missionBanner!.toUpperCase()}', textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2A0E4A))),
                    ),
                  ),
                ]),
              );
            }),
          ),
        ])),
      ),
    );
  }

  Widget _gemWidget(_Gem gem, Size size) {
    final cx = gem.x * size.width, cy = gem.y * size.height;
    Color color = gem.color;
    if (gem.sliced) color = gem.sliceCorrect == true ? _green : (gem.sliceCorrect == false ? _danger : gem.color.withOpacity(0.3));
    return Positioned(
      left: cx - 44, top: cy - 34,
      child: Transform.rotate(angle: gem.sliced ? 0.4 : 0, child: Container(width: 88, height: 68,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 12)]),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(gem.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
      )),
    );
  }

  Widget _introScreen() => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])),
      child: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SIGNAL MATCH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 30, color: Colors.white)),
        const SizedBox(height: 16),
        const Text('Answer gems launch up and arc back down across the whole screen. Swipe your finger through the correct one to slice it. '
          'Slice the wrong one, or let the correct one fall unsliced, and you take a hit.',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
        const SizedBox(height: 28),
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.gesture_rounded, color: Colors.white, size: 20), SizedBox(width: 10),
            Expanded(child: Text('Swipe through gems anywhere on screen — no lanes, no taps.', style: TextStyle(color: Colors.white70, fontSize: 12))),
          ])),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _begin,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC85C), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('SLICE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2A0E4A), letterSpacing: 2)))),
      ]))),
    ),
  );

  Widget _gameOverScreen() => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bgTop, _bgBottom])),
      child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.heart_broken_rounded, color: _danger, size: 48),
        const SizedBox(height: 12),
        const Text('OUT OF LIVES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white)),
        const SizedBox(height: 8),
        Text('Score $_score · $_correctCount sliced correctly', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _begin,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFC85C), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('SLICE AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2A0E4A), letterSpacing: 1)))),
      ]))),
    ),
  );
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    for (int i = 1; i < points.length; i++) {
      final opacity = i / points.length;
      canvas.drawLine(points[i - 1], points[i], Paint()
        ..color = Colors.white.withOpacity(opacity * 0.7)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => true;
}
