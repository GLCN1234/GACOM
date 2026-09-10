import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import 'level_map_screen.dart';

/// Colony Siege — answer correctly to earn resources, then actively CHOOSE
/// which building to construct and where. Reach the target colony value
/// before you run out of questions. Real strategic choice, not autopilot.
class ColonySiegeScreen extends StatefulWidget {
  const ColonySiegeScreen({super.key, this.subject = 'logic'});
  final String subject;

  @override
  State<ColonySiegeScreen> createState() => _ColonySiegeScreenState();
}

class _Building {
  final String id, name, glb, emoji;
  final int cost, unlockLevel;
  const _Building(this.id, this.name, this.glb, this.emoji, this.cost, this.unlockLevel);
}

const _roster = [
  _Building('Solar_panel', 'Solar Array', 'colony/colony_Solar_panel.glb', '☀️', 15, 1),
  _Building('Farm', 'Farm Module', 'colony/colony_Farm.glb', '🌾', 20, 1),
  _Building('Home_colonists', 'Colonist Bay', 'colony/colony_Home_colonists.glb', '👥', 25, 1),
  _Building('Resource_warehouse', 'Warehouse', 'colony/colony_Resource_warehouse.glb', '📦', 35, 4),
  _Building('Research_center', 'Research Lab', 'colony/colony_Research_center.glb', '🔬', 40, 4),
  _Building('Drone_control_center', 'Drone Control', 'colony/colony_Drone_control_center.glb', '🛰️', 45, 4),
  _Building('Reactor', 'Reactor Core', 'colony/colony_Reactor.glb', '☢️', 60, 9),
  _Building('Geothermal_generator', 'Geo Generator', 'colony/colony_Geothermal_generator.glb', '⚡', 70, 9),
  _Building('Machine_building_plant', 'Factory', 'colony/colony_Machine_building_plant.glb', '🏭', 75, 9),
  _Building('Decontamination_section', 'Decon Bay', 'colony/colony_Decontamination_section.glb', '🧪', 90, 14),
  _Building('Section', 'Habitat Section', 'colony/colony_Section.glb', '🔷', 100, 14),
];

const _easyQ = [
  {'q': 'What is 12 + 15?', 'a': '27', 'opts': ['25', '27', '29', '30']},
  {'q': 'What is the capital of Nigeria?', 'a': 'Abuja', 'opts': ['Lagos', 'Abuja', 'Kano', 'Ibadan']},
  {'q': 'What planet do we live on?', 'a': 'Earth', 'opts': ['Mars', 'Earth', 'Venus', 'Jupiter']},
  {'q': 'What is 5 × 6?', 'a': '30', 'opts': ['25', '28', '30', '35']},
  {'q': 'How many days in a week?', 'a': '7', 'opts': ['5', '6', '7', '8']},
  {'q': 'What color is the sky on a clear day?', 'a': 'Blue', 'opts': ['Green', 'Blue', 'Red', 'Yellow']},
  {'q': 'What is 20 - 8?', 'a': '12', 'opts': ['10', '11', '12', '14']},
  {'q': 'Which animal is known as "man\'s best friend"?', 'a': 'Dog', 'opts': ['Cat', 'Dog', 'Horse', 'Bird']},
];
const _mediumQ = [
  {'q': 'What is the powerhouse of the cell?', 'a': 'Mitochondria', 'opts': ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi Body']},
  {'q': 'What is 15% of 200?', 'a': '30', 'opts': ['20', '25', '30', '35']},
  {'q': 'Who wrote "Things Fall Apart"?', 'a': 'Chinua Achebe', 'opts': ['Wole Soyinka', 'Chinua Achebe', 'Chimamanda Adichie', 'Ben Okri']},
  {'q': 'What gas do plants absorb from the air?', 'a': 'Carbon Dioxide', 'opts': ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen']},
  {'q': 'What is the square root of 144?', 'a': '12', 'opts': ['10', '11', '12', '14']},
  {'q': 'What is the largest ocean on Earth?', 'a': 'Pacific Ocean', 'opts': ['Atlantic Ocean', 'Indian Ocean', 'Pacific Ocean', 'Arctic Ocean']},
  {'q': 'What does "www" stand for?', 'a': 'World Wide Web', 'opts': ['World Wide Web', 'World Web Wide', 'Wide World Web', 'Web World Wide']},
  {'q': 'Which organ pumps blood through the body?', 'a': 'Heart', 'opts': ['Lungs', 'Heart', 'Liver', 'Kidney']},
];
const _hardQ = [
  {'q': 'What is the chemical symbol for gold?', 'a': 'Au', 'opts': ['Ag', 'Au', 'Gd', 'Go']},
  {'q': 'What is 17 × 13?', 'a': '221', 'opts': ['211', '221', '231', '241']},
  {'q': 'Who developed the theory of relativity?', 'a': 'Albert Einstein', 'opts': ['Isaac Newton', 'Albert Einstein', 'Niels Bohr', 'Galileo Galilei']},
  {'q': 'What is the derivative of x²?', 'a': '2x', 'opts': ['x', '2x', 'x²', '2x²']},
  {'q': 'Which African country was formerly called Abyssinia?', 'a': 'Ethiopia', 'opts': ['Kenya', 'Ethiopia', 'Sudan', 'Somalia']},
  {'q': 'What is the SI unit of electric current?', 'a': 'Ampere', 'opts': ['Volt', 'Watt', 'Ampere', 'Ohm']},
  {'q': 'What is the value of π to 2 decimal places?', 'a': '3.14', 'opts': ['3.12', '3.14', '3.16', '3.18']},
  {'q': 'Who was the first Secretary-General of the United Nations?', 'a': 'Trygve Lie', 'opts': ['Kofi Annan', 'Trygve Lie', 'U Thant', 'Dag Hammarskjöld']},
];

class _ColonySiegeScreenState extends State<ColonySiegeScreen> {
  int? _level;
  String _difficulty = 'Easy';
  late List<Map<String, dynamic>> _questions;
  int _qIdx = 0, _resources = 0, _colonyValue = 0, _target = 0, _questionBudget = 15;
  final List<_Building> _placed = [];
  String? _selected;
  bool _answered = false, _levelOver = false, _won = false;
  final _rand = Random();
  Timer? _timer;
  int _timeLeft = 12;

  void _startLevel(int level, String difficulty) {
    final bank = difficulty == 'Easy' ? _easyQ : difficulty == 'Medium' ? _mediumQ : _hardQ;
    setState(() {
      _level = level; _difficulty = difficulty;
      _questions = ([..._easyQ, ...bank, ...bank]..shuffle());
      _qIdx = 0; _resources = 0; _colonyValue = 0; _placed.clear();
      _target = 80 + (level - 1) * 15;
      _questionBudget = 15;
      _selected = null; _answered = false; _levelOver = false; _won = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 12;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_timeLeft <= 1) { setState(() => _answered = true); _timer?.cancel(); _nextQuestion(auto: true); }
      else setState(() => _timeLeft--);
    });
  }

  List<_Building> get _unlockedRoster => _roster.where((b) => b.unlockLevel <= (_level ?? 1)).toList();

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    _timer?.cancel();
    final correct = opt == _questions[_qIdx]['a'];
    setState(() { _selected = opt; _answered = true; });
    if (correct) _resources += 15 + _timeLeft;

    EduProgressRecorder.recordSession(
      subject: widget.subject, xpEarned: correct ? 10 : 0,
      questionsAnswered: 1, correctAnswers: correct ? 1 : 0,
    );
    Future.delayed(const Duration(milliseconds: 700), () => _nextQuestion());
  }

  void _nextQuestion({bool auto = false}) {
    if (_colonyValue >= _target) { setState(() { _levelOver = true; _won = true; }); return; }
    _questionBudget--;
    if (_questionBudget <= 0) { setState(() { _levelOver = true; _won = _colonyValue >= _target; }); return; }
    setState(() { _qIdx = (_qIdx + 1) % _questions.length; _selected = null; _answered = false; });
    _startTimer();
  }

  void _build(_Building b) {
    if (_resources < b.cost) return;
    HapticFeedback.mediumImpact();
    setState(() { _resources -= b.cost; _colonyValue += b.cost; _placed.add(b); });
    if (_colonyValue >= _target) {
      _timer?.cancel();
      LevelMapScreen.unlockNext('colony_siege', _level!);
      setState(() { _levelOver = true; _won = true; });
    }
  }

  void _viewBuilding(_Building b) {
    showModalBottomSheet(context: context, backgroundColor: GacomColors.cardDark, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(height: 380, child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('${b.emoji} ${b.name}',
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary))),
        Expanded(child: ModelViewer(backgroundColor: GacomColors.obsidian,
          src: Uri.base.resolve('assets/assets/models_3d/${b.glb}').toString(),
          alt: b.name, ar: false, autoRotate: true, cameraControls: true, disableZoom: false)),
      ])));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_level == null) {
      return LevelMapScreen(gameKey: 'colony_siege', title: 'Colony Siege', onPlayLevel: _startLevel);
    }

    if (_levelOver) return Scaffold(backgroundColor: GacomColors.obsidian,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_won ? '🏗️ Colony Complete!' : '⏳ Out of Time', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 24, color: _won ? GacomColors.success : GacomColors.error)),
        const SizedBox(height: 8),
        Text('Colony value: $_colonyValue / $_target', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: GacomColors.deepOrange)),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          OutlinedButton(onPressed: () => setState(() => _level = null), style: OutlinedButton.styleFrom(side: const BorderSide(color: GacomColors.border)),
            child: const Text('LEVEL MAP', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.textPrimary))),
          const SizedBox(width: 12),
          if (_won) ElevatedButton(onPressed: () => _startLevel(_level! + 1 > 20 ? _level! : _level! + 1, LevelMapScreen.difficultyFor(_level! + 1 > 20 ? _level! : _level! + 1)),
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('NEXT LEVEL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)))
          else ElevatedButton(onPressed: () => _startLevel(_level!, _difficulty), style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('RETRY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
        ]),
      ])));

    final q = _questions[_qIdx];
    final opts = List<String>.from(q['opts'] as List);

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: Text('LEVEL $_level · $_difficulty'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('⏱ $_questionBudget left',
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textMuted)))),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Resources + colony progress
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('RESOURCES', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              Text('⚡ $_resources', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.deepOrange)),
            ]))),
          const SizedBox(width: 10),
          Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('COLONY VALUE', style: TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700)),
              Text('$_colonyValue / $_target', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.success)),
            ]))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_colonyValue / _target).clamp(0, 1), backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.success))),
        const SizedBox(height: 16),

        // Build bar — real player choice, spend resources when YOU want
        const Text('BUILD (tap to construct)', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.textMuted, letterSpacing: 1)),
        const SizedBox(height: 8),
        SizedBox(height: 74, child: ListView(scrollDirection: Axis.horizontal, children: _unlockedRoster.map((b) {
          final affordable = _resources >= b.cost;
          return GestureDetector(onTap: affordable ? () => _build(b) : null,
            child: Container(width: 84, margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: affordable ? GacomColors.deepOrange.withOpacity(0.12) : GacomColors.cardDark, borderRadius: BorderRadius.circular(12), border: Border.all(color: affordable ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(b.emoji, style: const TextStyle(fontSize: 20)),
                Text(b.name, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: GacomColors.textPrimary)),
                Text('⚡${b.cost}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: affordable ? GacomColors.deepOrange : GacomColors.textMuted)),
              ])));
        }).toList())),
        const SizedBox(height: 16),

        // Placed buildings — tap for real 3D view
        if (_placed.isNotEmpty) ...[
          const Text('YOUR COLONY (tap to view in 3D)', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _placed.map((b) => GestureDetector(onTap: () => _viewBuilding(b),
            child: Container(width: 46, height: 46, decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: GacomColors.border)),
              child: Center(child: Text(b.emoji, style: const TextStyle(fontSize: 20)))))).toList()),
          const SizedBox(height: 16),
        ],

        // Question
        Row(children: [
          Text('Q ${16 - _questionBudget}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _timeLeft <= 4 ? GacomColors.error.withOpacity(0.15) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50)),
            child: Text('⏱ ${_timeLeft}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: _timeLeft <= 4 ? GacomColors.error : GacomColors.textPrimary))),
        ]),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
          child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary, height: 1.4))),
        const SizedBox(height: 12),
        ...opts.map((opt) {
          Color borderColor = GacomColors.border, bgColor = GacomColors.cardDark;
          if (_answered && _selected == opt) {
            borderColor = opt == q['a'] ? GacomColors.success : GacomColors.error;
            bgColor = opt == q['a'] ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1);
          } else if (_answered && opt == q['a']) {
            borderColor = GacomColors.success; bgColor = GacomColors.success.withOpacity(0.08);
          }
          return GestureDetector(onTap: () => _answer(opt),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor, width: 1.2)),
              child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14, color: GacomColors.textPrimary))));
        }),
      ])),
    );
  }
}
