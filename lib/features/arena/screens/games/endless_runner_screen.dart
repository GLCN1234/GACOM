import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../edu/edu_progress_recorder.dart';

const _bg = Color(0xFF0B0B0F);
const _panel = Color(0xFF1A1A22);
const _accent = Color(0xFF3DD6FF);
const _danger = Color(0xFFFF5A5F);
const _gold = Color(0xFFFFC940);
const _green = Color(0xFF3DDC84);

/// One ordered block of curriculum content: a topic name plus its real
/// generated_questions (question/options/answer schema). Pass a list of
/// these to chain topics together in ONE continuous run — when a topic's
/// questions are exhausted, a non-blocking mission banner announces the
/// next topic and the run keeps going without stopping.
class TopicBlock {
  const TopicBlock({required this.topicName, required this.questions});
  final String topicName;
  final List<Map<String, dynamic>> questions;
}

/// Signal Run — continuous endless runner, generalized to any subject.
/// Two modes, chosen automatically:
///  - Answer Mode (pass [topics]): tokens show real answer text, one
///    correct option per wave among decoys, works for ANY subject.
///  - Arithmetic Mode (default, no topics passed): tokens are +/- numbers
///    feeding a running mission tally — the original math-specific mode.
/// Either way: no levels, no popups, one run until you crash.
class EndlessRunnerScreen extends StatefulWidget {
  const EndlessRunnerScreen({super.key, this.subject = 'math', this.topics});
  final String subject;
  final List<TopicBlock>? topics;

  @override
  State<EndlessRunnerScreen> createState() => _EndlessRunnerScreenState();
}

enum _ItemType { obstacle, numberToken, answerToken }

class _RunnerItem {
  _RunnerItem({required this.type, required this.lane, this.value = 0, this.label, this.isCorrectAnswer = false});
  final _ItemType type;
  final int lane;
  final int value; // arithmetic mode only
  final String? label; // answer mode only
  final bool isCorrectAnswer; // answer mode only
  double y = -0.12;
  bool consumed = false;
  bool? hitResult;
}

enum _Phase { intro, playing, gameOver }

class _EndlessRunnerScreenState extends State<EndlessRunnerScreen> {
  static const double _tickSeconds = 1 / 60;
  static const double _playerRowY = 0.86;
  static const double _baseSpeed = 0.26;

  bool get _answerMode => widget.topics != null && widget.topics!.isNotEmpty;

  _Phase _phase = _Phase.intro;
  int _lane = 1;
  int _lives = 3;
  int _score = 0;
  int _correctCount = 0;
  double _elapsed = 0;
  double _timeSinceLastSpawn = 999;
  bool _nextSpawnIsWave = true;

  // arithmetic mode state
  int _missionTarget = 15;
  int _tally = 0;
  double _bestMissionReached = 0;

  // answer mode state
  int _topicIndex = 0;
  int _questionCursor = 0;
  String? _missionBanner;
  Timer? _bannerTimer;

  final List<_RunnerItem> _items = [];
  Timer? _timer;
  final _rng = Random();

  double get _speed => _baseSpeed + (_elapsed / 40).clamp(0, 0.35);
  double get _spawnInterval => (1.0 - (_elapsed / 90).clamp(0, 0.5)).clamp(0.5, 1.0);

  void _begin() {
    _lane = 1;
    _lives = 3;
    _score = 0;
    _correctCount = 0;
    _elapsed = 0;
    _missionTarget = 15;
    _tally = 0;
    _bestMissionReached = 0;
    _topicIndex = 0;
    _questionCursor = 0;
    _missionBanner = _answerMode ? widget.topics![0].topicName : null;
    _items.clear();
    _timeSinceLastSpawn = 999;
    _nextSpawnIsWave = true;
    setState(() => _phase = _Phase.playing);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (_tickSeconds * 1000).round()), _tick);
    if (_answerMode) _flashBanner(widget.topics![0].topicName);
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
      _timeSinceLastSpawn += _tickSeconds;
      if (_timeSinceLastSpawn >= _spawnInterval) {
        _timeSinceLastSpawn = 0;
        _spawnNext();
      }

      for (final item in _items) {
        if (item.consumed) continue;
        item.y += _speed * _tickSeconds;
        if (item.y >= _playerRowY) {
          _resolveItem(item);
        }
      }
      _items.removeWhere((i) => i.consumed && i.y > 1.05);

      if (_lives <= 0) {
        _timer?.cancel();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: _score ~/ 5, questionsAnswered: 1, correctAnswers: 1);
        _phase = _Phase.gameOver;
      }
    });
  }

  void _spawnNext() {
    if (_nextSpawnIsWave) {
      if (_answerMode) {
        _spawnAnswerWave();
      } else {
        _spawnNumberToken();
      }
    } else {
      _spawnObstacle();
    }
    _nextSpawnIsWave = !_nextSpawnIsWave;
  }

  void _spawnObstacle() {
    _items.add(_RunnerItem(type: _ItemType.obstacle, lane: _rng.nextInt(3)));
  }

  void _spawnNumberToken() {
    final lane = _rng.nextInt(3);
    final values = [2, 3, 5, -2, -3];
    final value = values[_rng.nextInt(values.length)];
    _items.add(_RunnerItem(type: _ItemType.numberToken, lane: lane, value: value));
  }

  void _spawnAnswerWave() {
    final topic = widget.topics![_topicIndex];
    if (topic.questions.isEmpty) return;
    final q = topic.questions[_questionCursor % topic.questions.length];
    final rawOptions = List<String>.from(q['options'] as List? ?? const []);
    final answer = q['answer'] as String? ?? (rawOptions.isNotEmpty ? rawOptions.first : '');
    final wrongPool = rawOptions.where((o) => o != answer).toList()..shuffle();
    final picks = <String>[answer, ...wrongPool.take(2)];
    picks.shuffle();

    for (int lane = 0; lane < picks.length && lane < 3; lane++) {
      _items.add(_RunnerItem(type: _ItemType.answerToken, lane: lane, label: picks[lane], isCorrectAnswer: picks[lane] == answer));
    }

    _questionCursor++;
    if (_questionCursor >= topic.questions.length) {
      _questionCursor = 0;
      _topicIndex = (_topicIndex + 1) % widget.topics!.length;
      _flashBanner(widget.topics![_topicIndex].topicName);
    }
  }

  void _resolveItem(_RunnerItem item) {
    item.consumed = true;
    final hit = item.lane == _lane;

    if (item.type == _ItemType.obstacle) {
      if (hit) {
        item.hitResult = false;
        _lives--;
        HapticFeedback.heavyImpact();
      }
      return;
    }

    if (item.type == _ItemType.numberToken) {
      if (hit) {
        item.hitResult = true;
        _tally += item.value;
        _score += item.value > 0 ? item.value : 1;
        HapticFeedback.selectionClick();
        if (_tally >= _missionTarget) {
          _score += 50;
          _bestMissionReached = _missionTarget.toDouble();
          _missionTarget += 8 + _rng.nextInt(8);
          _tally = 0;
          EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 15, questionsAnswered: 1, correctAnswers: 1);
        }
      }
      return;
    }

    // answerToken
    if (hit) {
      item.hitResult = item.isCorrectAnswer;
      if (item.isCorrectAnswer) {
        _score += 15;
        _correctCount++;
        HapticFeedback.selectionClick();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 10, questionsAnswered: 1, correctAnswers: 1);
      } else {
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: 0, questionsAnswered: 1, correctAnswers: 0);
      }
    }
  }

  void _changeLane(int delta) {
    if (_phase != _Phase.playing) return;
    setState(() => _lane = (_lane + delta).clamp(0, 2));
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
          Text('SCORE $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _gold)),
        ])),
        if (!_answerMode) Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('MISSION: REACH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
            Text('$_tally / $_missionTarget', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: _tally < 0 ? _danger : _accent)),
          ]),
        ),
        if (_answerMode) Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('CORRECT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
            Text('$_correctCount', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: _accent)),
          ]),
        ),
        const SizedBox(height: 10),
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
                for (final item in _items) _itemWidget(item, laneX, h),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 130), curve: Curves.easeOut,
                  left: laneX[_lane] - 16, top: _playerRowY * h - 16,
                  child: Container(width: 32, height: 32, decoration: BoxDecoration(shape: BoxShape.circle, color: _accent,
                    boxShadow: [BoxShadow(color: _accent.withOpacity(0.6), blurRadius: 10)])),
                ),
                // Non-blocking mission banner — slides in, auto-dismisses,
                // the run keeps scrolling underneath the whole time.
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
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          GestureDetector(onTap: () => _changeLane(-1), child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18))),
          GestureDetector(onTap: () => _changeLane(1), child: Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: _panel, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18))),
        ])),
      ])),
    );
  }

  Widget _itemWidget(_RunnerItem item, List<double> laneX, double h) {
    if (item.type == _ItemType.obstacle) {
      return Positioned(
        left: laneX[item.lane] - 26, top: item.y * h - 18,
        child: Container(width: 52, height: 36, decoration: BoxDecoration(
          color: item.hitResult == false ? _danger.withOpacity(0.5) : _danger.withOpacity(0.25),
          border: Border.all(color: _danger, width: 2), borderRadius: BorderRadius.circular(6)),
          child: const Center(child: Icon(Icons.warning_rounded, color: Colors.white, size: 18))),
      );
    }

    if (item.type == _ItemType.numberToken) {
      final positive = item.value > 0;
      return Positioned(
        left: laneX[item.lane] - 20, top: item.y * h - 20,
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: (positive ? _green : _danger).withOpacity(item.hitResult != null ? 0.9 : 0.6),
            border: Border.all(color: positive ? _green : _danger, width: 1.5)),
          child: Center(child: Text('${positive ? '+' : ''}${item.value}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)))),
      );
    }

    // answerToken
    final resolvedColor = item.hitResult == null ? Colors.white24 : (item.isCorrectAnswer ? _green : _danger);
    return Positioned(
      left: laneX[item.lane] - 46, top: item.y * h - 22,
      child: Container(width: 92, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: _panel, border: Border.all(color: resolvedColor, width: 1.5), borderRadius: BorderRadius.circular(8)),
        child: Text(item.label ?? '', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
    );
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: const Text('SIGNAL RUN')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('KEEP RUNNING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _accent)),
      const SizedBox(height: 16),
      Text(_answerMode
        ? 'One continuous run across ${widget.topics!.length} topic(s) — no levels. Dodge obstacles, catch the correct answer in each wave. '
          'When a topic runs out, a new mission banner announces the next one — the run never stops.'
        : 'One continuous run — no levels. Dodge obstacles, collect +/- tokens toward your mission target. Hit the target and a bigger one appears immediately.',
        style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.swipe_rounded, color: _accent, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Swipe or tap arrows to switch lanes. Red blocks hurt. Catch the right answer to score.', style: TextStyle(color: Colors.white60, fontSize: 12))),
        ])),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('RUN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 2)))),
    ]))));

  Widget _gameOverScreen() => Scaffold(
    backgroundColor: _bg,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.heart_broken_rounded, color: _danger, size: 48),
      const SizedBox(height: 12),
      const Text('RUN OVER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: _danger)),
      const SizedBox(height: 8),
      Text(_answerMode ? 'Score $_score · $_correctCount correct' : 'Score $_score · Best mission reached: ${_bestMissionReached.toInt()}',
        style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('RUN AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 1)))),
    ]))),
  );
}
