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

/// A genuine continuous endless runner — no levels, no level map, no
/// "clear level 1 to unlock level 2". One run: you keep going, it keeps
/// getting faster, until you crash. While running, you dodge obstacles
/// and collect +/- number tokens toward a running MISSION target that
/// resets and grows harder every time you reach it — addition and
/// subtraction embedded directly in continuous movement, not a discrete
/// question stopping the run.
class EndlessRunnerScreen extends StatefulWidget {
  const EndlessRunnerScreen({super.key, this.subject = 'math'});
  final String subject;

  @override
  State<EndlessRunnerScreen> createState() => _EndlessRunnerScreenState();
}

enum _ItemType { obstacle, token }

class _RunnerItem {
  _RunnerItem({required this.type, required this.lane, this.value = 0});
  final _ItemType type;
  final int lane;
  final int value;
  double y = -0.12;
  bool consumed = false;
  bool? hitResult; // true = good outcome, false = bad, for brief flash feedback
}

enum _Phase { intro, playing, gameOver }

class _EndlessRunnerScreenState extends State<EndlessRunnerScreen> {
  static const double _tickSeconds = 1 / 60;
  static const double _playerRowY = 0.86;
  static const double _baseSpeed = 0.26;

  _Phase _phase = _Phase.intro;
  int _lane = 1;
  int _lives = 3;
  int _score = 0;
  double _elapsed = 0;
  int _missionTarget = 15;
  int _tally = 0;
  double _timeSinceLastSpawn = 999;
  double _bestMissionReached = 0;

  final List<_RunnerItem> _items = [];
  Timer? _timer;
  final _rng = Random();

  double get _speed => _baseSpeed + (_elapsed / 40).clamp(0, 0.35);
  double get _spawnInterval => (1.0 - (_elapsed / 90).clamp(0, 0.5)).clamp(0.5, 1.0);

  void _begin() {
    _lane = 1;
    _lives = 3;
    _score = 0;
    _elapsed = 0;
    _missionTarget = 15;
    _tally = 0;
    _bestMissionReached = 0;
    _items.clear();
    _timeSinceLastSpawn = 999;
    setState(() => _phase = _Phase.playing);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: (_tickSeconds * 1000).round()), _tick);
  }

  void _tick(Timer t) {
    if (!mounted) return;
    setState(() {
      _elapsed += _tickSeconds;
      _timeSinceLastSpawn += _tickSeconds;
      if (_timeSinceLastSpawn >= _spawnInterval) {
        _timeSinceLastSpawn = 0;
        _spawnItem();
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

  void _spawnItem() {
    final lane = _rng.nextInt(3);
    if (_rng.nextDouble() < 0.28) {
      _items.add(_RunnerItem(type: _ItemType.obstacle, lane: lane));
    } else {
      final values = [2, 3, 5, -2, -3];
      final value = values[_rng.nextInt(values.length)];
      _items.add(_RunnerItem(type: _ItemType.token, lane: lane, value: value));
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
  }

  void _changeLane(int delta) {
    if (_phase != _Phase.playing) return;
    setState(() => _lane = (_lane + delta).clamp(0, 2));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

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
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('MISSION: REACH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
            Text('$_tally / $_missionTarget', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: _tally < 0 ? _danger : _accent)),
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
    final positive = item.value > 0;
    return Positioned(
      left: laneX[item.lane] - 20, top: item.y * h - 20,
      child: Container(width: 40, height: 40,
        decoration: BoxDecoration(shape: BoxShape.circle, color: (positive ? _green : _danger).withOpacity(item.hitResult != null ? 0.9 : 0.6),
          border: Border.all(color: positive ? _green : _danger, width: 1.5)),
        child: Center(child: Text('${positive ? '+' : ''}${item.value}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white)))),
    );
  }

  Widget _introScreen() => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: const Text('SIGNAL RUN')),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('KEEP RUNNING', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: _accent)),
      const SizedBox(height: 16),
      const Text('One continuous run — no levels. Dodge obstacles, collect +/- tokens toward your mission target. '
        'Hit the target and a bigger one appears immediately. It keeps getting faster. Survive as long as you can.',
        style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.swipe_rounded, color: _accent, size: 20), SizedBox(width: 10),
          Expanded(child: Text('Swipe or tap arrows to switch lanes. Red blocks hurt. Circles add or subtract from your mission.', style: TextStyle(color: Colors.white60, fontSize: 12))),
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
      Text('Score $_score · Best mission reached: ${_bestMissionReached.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _begin,
        style: ElevatedButton.styleFrom(backgroundColor: _accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('RUN AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black, letterSpacing: 1)))),
    ]))),
  );
}
