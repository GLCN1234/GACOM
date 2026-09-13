import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';

// Gold/brass heist-vault palette — a third distinct visual identity.
const _bg = Color(0xFF14100A);
const _brass = Color(0xFFC9A24B);
const _brassDark = Color(0xFF8A6D2F);
const _panel = Color(0xFF221B10);
const _danger = Color(0xFFFF5A5F);
const _green = Color(0xFF3DDC84);

class TopicBlock {
  const TopicBlock({required this.topicName, required this.questions});
  final String topicName;
  final List<Map<String, dynamic>> questions;
}

/// Vault Break — a rotational dial puzzle. Drag anywhere on the dial to
/// turn it; whichever segment lands at the top pointer is your tentative
/// pick. Hold the CONFIRM button to lock it in. Wrong lock costs a life;
/// turning freely costs nothing — deliberately slower, more thoughtful
/// pacing than Signal Run/Drone Breach/Signal Match's fast reflex action,
/// and a genuinely different gesture: continuous rotation, not a swipe,
/// tap, or slice.
class VaultBreakScreen extends StatefulWidget {
  const VaultBreakScreen({super.key, this.subject = 'general', this.topics});
  final String subject;
  final List<TopicBlock>? topics;

  @override
  State<VaultBreakScreen> createState() => _VaultBreakScreenState();
}

const _fallbackTopics = [
  TopicBlock(topicName: 'General Knowledge', questions: [
    {'question': 'What is 12 × 8?', 'options': ['96', '84', '108'], 'answer': '96'},
    {'question': 'Capital of Nigeria?', 'options': ['Abuja', 'Lagos', 'Kano'], 'answer': 'Abuja'},
    {'question': 'What gas do plants absorb?', 'options': ['Carbon Dioxide', 'Oxygen', 'Nitrogen'], 'answer': 'Carbon Dioxide'},
    {'question': 'Who wrote "Things Fall Apart"?', 'options': ['Chinua Achebe', 'Wole Soyinka', 'Ben Okri'], 'answer': 'Chinua Achebe'},
    {'question': 'Square root of 144?', 'options': ['12', '11', '14'], 'answer': '12'},
    {'question': 'Largest ocean on Earth?', 'options': ['Pacific', 'Atlantic', 'Indian'], 'answer': 'Pacific'},
    {'question': 'What is 9 + 16?', 'options': ['25', '23', '27'], 'answer': '25'},
    {'question': 'Powerhouse of the cell?', 'options': ['Mitochondria', 'Nucleus', 'Ribosome'], 'answer': 'Mitochondria'},
  ]),
];

enum _Phase { intro, playing, gameOver }

class _VaultBreakScreenState extends State<VaultBreakScreen> {
  static const double _topReference = -pi / 2; // "up" in atan2 screen coords

  List<TopicBlock> get _topics => (widget.topics != null && widget.topics!.isNotEmpty) ? widget.topics! : _fallbackTopics;

  _Phase _phase = _Phase.intro;
  int _lives = 3;
  int _score = 0;
  int _correctCount = 0;
  int _topicIndex = 0;
  int _questionCursor = 0;
  String? _missionBanner;
  Timer? _bannerTimer;

  List<String> _segments = [];
  String _correctAnswer = '';
  double _rotation = 0;
  double? _lastTouchAngle;
  bool _resolving = false;
  String? _flashLabel; // brief correct/wrong feedback text

  void _begin() {
    _lives = 3;
    _score = 0;
    _correctCount = 0;
    _topicIndex = 0;
    _questionCursor = 0;
    _rotation = 0;
    _resolving = false;
    setState(() => _phase = _Phase.playing);
    _loadQuestion();
    _flashBanner(_topics[0].topicName);
  }

  void _flashBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _missionBanner = text);
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _missionBanner = null);
    });
  }

  void _loadQuestion() {
    final topic = _topics[_topicIndex];
    if (topic.questions.isEmpty) return;
    final q = topic.questions[_questionCursor % topic.questions.length];
    final rawOptions = List<String>.from(q['options'] as List? ?? const []);
    final answer = q['answer'] as String? ?? (rawOptions.isNotEmpty ? rawOptions.first : '');
    final options = List<String>.from(rawOptions)..shuffle();
    setState(() {
      _segments = options;
      _correctAnswer = answer;
      _rotation = 0;
    });

    _questionCursor++;
    if (_questionCursor >= topic.questions.length) {
      _questionCursor = 0;
      _topicIndex = (_topicIndex + 1) % _topics.length;
      _flashBanner(_topics[_topicIndex].topicName);
    }
  }

  double _normalizeAngle(double a) {
    while (a > pi) a -= 2 * pi;
    while (a < -pi) a += 2 * pi;
    return a;
  }

  void _onPanStart(DragStartDetails details, Offset center) {
    final d = details.localPosition - center;
    _lastTouchAngle = atan2(d.dy, d.dx);
  }

  void _onPanUpdate(DragUpdateDetails details, Offset center) {
    if (_lastTouchAngle == null) return;
    final d = details.localPosition - center;
    final currentAngle = atan2(d.dy, d.dx);
    final delta = _normalizeAngle(currentAngle - _lastTouchAngle!);
    _lastTouchAngle = currentAngle;
    setState(() => _rotation += delta);
  }

  int get _selectedIndex {
    if (_segments.isEmpty) return 0;
    final step = 2 * pi / _segments.length;
    double best = double.infinity;
    int bestIndex = 0;
    for (int i = 0; i < _segments.length; i++) {
      final segAngle = _normalizeAngle(i * step + _rotation - _topReference);
      final dist = segAngle.abs();
      if (dist < best) { best = dist; bestIndex = i; }
    }
    return bestIndex;
  }

  void _confirm() {
    if (_resolving || _segments.isEmpty) return;
    final picked = _segments[_selectedIndex];
    final correct = picked == _correctAnswer;
    _resolving = true;
    HapticFeedback.mediumImpact();
    EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: correct ? 10 : 0, questionsAnswered: 1, correctAnswers: correct ? 1 : 0);

    setState(() => _flashLabel = correct ? 'UNLOCKED' : 'JAMMED');

    if (correct) {
      _score += 25;
      _correctCount++;
    } else {
      _lives--;
      HapticFeedback.heavyImpact();
    }

    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _flashLabel = null);
      _resolving = false;
      if (_lives <= 0) {
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: _score ~/ 5, questionsAnswered: 1, correctAnswers: 1);
        setState(() => _phase = _Phase.gameOver);
      } else {
        _loadQuestion();
      }
    });
  }

  @override
  void dispose() { _bannerTimer?.cancel(); super.dispose(); }

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
          Text('$_correctCount unlocked', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: _brass)),
          const SizedBox(width: 14),
          Text('SCORE $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _brass)),
        ])),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth, h = constraints.maxHeight;
            final center = Offset(w / 2, h / 2 - 20);
            final radius = min(w, h) * 0.32;
            return Stack(children: [
              GestureDetector(
                onPanStart: (d) => _onPanStart(d, center),
                onPanUpdate: (d) => _onPanUpdate(d, center),
                child: SizedBox(width: w, height: h, child: CustomPaint(painter: _DialPainter(segments: _segments, rotation: _rotation, selectedIndex: _selectedIndex, center: center, radius: radius))),
              ),
              for (int i = 0; i < _segments.length; i++) _segmentLabel(i, center, radius),
              // Fixed pointer at the top of the dial.
              Positioned(left: center.dx - 10, top: center.dy - radius - 26, child: const Icon(Icons.arrow_drop_down_rounded, color: _brass, size: 34)),
              if (_flashLabel != null) Positioned(left: 0, right: 0, top: center.dy - 14, child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(color: _flashLabel == 'UNLOCKED' ? _green : _danger, borderRadius: BorderRadius.circular(20)),
                child: Text(_flashLabel!, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black)),
              ))),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
                top: _missionBanner != null ? 4 : -60, left: 16, right: 16,
                child: _missionBanner == null ? const SizedBox.shrink() : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: _brass, borderRadius: BorderRadius.circular(10)),
                  child: Text('NEW MISSION: ${_missionBanner!.toUpperCase()}', textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black)),
                ),
              ),
            ]);
          }),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 20), child: SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _resolving ? null : _confirm,
          style: ElevatedButton.styleFrom(backgroundColor: _brass, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('CONFIRM', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 2)),
        ))),
      ])),
    );
  }

  Widget _segmentLabel(int i, Offset center, double radius) {
    final step = 2 * pi / _segments.length;
    final angle = i * step + _rotation;
    final pos = center + Offset(cos(angle), sin(angle)) * radius;
    final selected = i == _selectedIndex;
    return Positioned(
      left: pos.dx - 44, top: pos.dy - 24,
      child: IgnorePointer(child: Container(width: 88, padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(color: selected ? _brass : _panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: _brassDark, width: 1.5)),
        child: Text(_segments[i], textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: selected ? Colors.black : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800)))),
    );
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: const Text('VAULT BREAK')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('TURN THE DIAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _brass)),
      const SizedBox(height: 16),
      const Text('Drag anywhere to rotate the vault dial. Line up the correct answer with the pointer at the top, '
        'then tap CONFIRM to lock it in. Confirm the wrong one and the vault jams — you lose a life. Take your time, there\'s no clock.',
        style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, border: Border.all(color: _brassDark), borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.rotate_right_rounded, color: _brass, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Rotate freely, no penalty. Only a wrong CONFIRM costs you.', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _brass, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('BEGIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 2)))),
    ]))));

  Widget _gameOverScreen() => Scaffold(
    backgroundColor: _bg,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.lock_rounded, color: _danger, size: 48),
      const SizedBox(height: 12),
      const Text('VAULT SEALED', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: Colors.white)),
      const SizedBox(height: 8),
      Text('Score $_score · $_correctCount unlocked', style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _brass, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('TRY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 1)))),
    ]))),
  );
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.segments, required this.rotation, required this.selectedIndex, required this.center, required this.radius});
  final List<String> segments;
  final double rotation;
  final int selectedIndex;
  final Offset center;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(center, radius + 30, Paint()..color = const Color(0xFF221B10));
    canvas.drawCircle(center, radius + 30, Paint()..color = _brassDark..style = PaintingStyle.stroke..strokeWidth = 4);
    canvas.drawCircle(center, radius - 40, Paint()..color = const Color(0xFF14100A));

    if (segments.isEmpty) return;
    final step = 2 * pi / segments.length;
    for (int i = 0; i < segments.length; i++) {
      final angle = i * step + rotation;
      final p1 = center + Offset(cos(angle), sin(angle)) * (radius - 40);
      final p2 = center + Offset(cos(angle), sin(angle)) * (radius + 30);
      canvas.drawLine(p1, p2, Paint()..color = _brassDark..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) => true;
}
