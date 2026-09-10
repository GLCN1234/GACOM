import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';

/// Colony Builder — answer a question correctly, unlock placing one building
/// on your grid. Fill the colony before you run out of questions. Every
/// placed building can be tapped to open a real, interactive 3D model.
class ColonyBuilderScreen extends StatefulWidget {
  const ColonyBuilderScreen({super.key, this.subject = 'logic', this.questions});
  final String subject;
  /// Optional: pass real curriculum questions (e.g. from
  /// institution_curricula.generated_questions) to play with actual school
  /// content instead of the built-in general-knowledge set.
  final List<Map<String, dynamic>>? questions;

  @override
  State<ColonyBuilderScreen> createState() => _ColonyBuilderScreenState();
}

class _Building {
  final String id, name, glb, emoji;
  const _Building(this.id, this.name, this.glb, this.emoji);
}

const _buildings = [
  _Building('Main_house', 'Colony Home', 'colony/colony_Main_house.glb', '🏠'),
  _Building('Farm', 'Farm Module', 'colony/colony_Farm.glb', '🌾'),
  _Building('Reactor', 'Reactor Core', 'colony/colony_Reactor.glb', '☢️'),
  _Building('Solar_panel', 'Solar Array', 'colony/colony_Solar_panel.glb', '☀️'),
  _Building('Research_center', 'Research Lab', 'colony/colony_Research_center.glb', '🔬'),
  _Building('Resource_warehouse', 'Warehouse', 'colony/colony_Resource_warehouse.glb', '📦'),
  _Building('Drone_control_center', 'Drone Control', 'colony/colony_Drone_control_center.glb', '🛰️'),
  _Building('Geothermal_generator', 'Geo Generator', 'colony/colony_Geothermal_generator.glb', '⚡'),
  _Building('Machine_building_plant', 'Factory', 'colony/colony_Machine_building_plant.glb', '🏭'),
  _Building('Decontamination_section', 'Decon Bay', 'colony/colony_Decontamination_section.glb', '🧪'),
  _Building('Home_colonists', 'Colonist Bay', 'colony/colony_Home_colonists.glb', '👥'),
  _Building('Section', 'Habitat Section', 'colony/colony_Section.glb', '🔷'),
];

const _fallbackQuestions = [
  {'q': 'What is the powerhouse of the cell?', 'a': 'Mitochondria', 'opts': ['Nucleus', 'Mitochondria', 'Ribosome', 'Golgi Body']},
  {'q': 'What planet is known as the Red Planet?', 'a': 'Mars', 'opts': ['Venus', 'Mars', 'Jupiter', 'Saturn']},
  {'q': 'What is 15% of 200?', 'a': '30', 'opts': ['20', '25', '30', '35']},
  {'q': 'Who wrote "Things Fall Apart"?', 'a': 'Chinua Achebe', 'opts': ['Wole Soyinka', 'Chinua Achebe', 'Chimamanda Adichie', 'Ben Okri']},
  {'q': 'What gas do plants absorb from the air?', 'a': 'Carbon Dioxide', 'opts': ['Oxygen', 'Nitrogen', 'Carbon Dioxide', 'Hydrogen']},
  {'q': 'What is the capital of Nigeria?', 'a': 'Abuja', 'opts': ['Lagos', 'Abuja', 'Kano', 'Port Harcourt']},
  {'q': 'What is the boiling point of water at sea level?', 'a': '100°C', 'opts': ['90°C', '100°C', '110°C', '120°C']},
  {'q': 'How many continents are there?', 'a': '7', 'opts': ['5', '6', '7', '8']},
  {'q': 'What does "www" stand for?', 'a': 'World Wide Web', 'opts': ['World Wide Web', 'World Web Wide', 'Wide World Web', 'Web World Wide']},
  {'q': 'What is the square root of 144?', 'a': '12', 'opts': ['10', '11', '12', '14']},
  {'q': 'Which organ pumps blood through the body?', 'a': 'Heart', 'opts': ['Lungs', 'Heart', 'Liver', 'Kidney']},
  {'q': 'What is the largest ocean on Earth?', 'a': 'Pacific Ocean', 'opts': ['Atlantic Ocean', 'Indian Ocean', 'Pacific Ocean', 'Arctic Ocean']},
];

class _ColonyBuilderScreenState extends State<ColonyBuilderScreen> {
  static const _gridSize = 12; // 4x3
  late List<Map<String, dynamic>> _questions;
  late List<_Building?> _grid;
  int _idx = 0, _score = 0;
  String? _selected;
  bool _answered = false, _done = false;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _questions = (widget.questions != null && widget.questions!.isNotEmpty)
        ? (List<Map<String, dynamic>>.from(widget.questions!)..shuffle())
        : ([..._fallbackQuestions]..shuffle());
    if (_questions.length > _gridSize) _questions = _questions.sublist(0, _gridSize);
    _grid = List.filled(_gridSize, null);
  }

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final correct = opt == _questions[_idx]['a'];
    setState(() { _selected = opt; _answered = true; });
    if (correct) {
      _score += 10;
      final emptySlots = [for (int i = 0; i < _gridSize; i++) if (_grid[i] == null) i];
      if (emptySlots.isNotEmpty) {
        final slot = emptySlots[_rand.nextInt(emptySlots.length)];
        _grid[slot] = _buildings[_rand.nextInt(_buildings.length)];
      }
    }
    EduProgressRecorder.recordSession(
      subject: widget.subject, xpEarned: correct ? 10 : 0,
      questionsAnswered: 1, correctAnswers: correct ? 1 : 0,
    );
    Future.delayed(const Duration(milliseconds: 900), _next);
  }

  void _next() {
    if (_idx >= _questions.length - 1) { setState(() => _done = true); return; }
    setState(() { _idx++; _selected = null; _answered = false; });
  }

  void _reset() {
    setState(() {
      _questions = (widget.questions != null && widget.questions!.isNotEmpty)
          ? (List<Map<String, dynamic>>.from(widget.questions!)..shuffle())
          : ([..._fallbackQuestions]..shuffle());
      if (_questions.length > _gridSize) _questions = _questions.sublist(0, _gridSize);
      _grid = List.filled(_gridSize, null);
      _idx = 0; _score = 0; _selected = null; _answered = false; _done = false;
    });
  }

  void _viewBuilding(_Building b) {
    showModalBottomSheet(context: context, backgroundColor: GacomColors.cardDark, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(height: 420, child: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('${b.emoji} ${b.name}',
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.textPrimary))),
        Expanded(child: ModelViewer(
          backgroundColor: GacomColors.obsidian,
          src: Uri.base.resolve('assets/assets/models_3d/${b.glb}').toString(),
          alt: b.name, ar: false, autoRotate: true, cameraControls: true, disableZoom: false,
        )),
      ])));
  }

  @override
  Widget build(BuildContext context) {
    final filled = _grid.where((b) => b != null).length;

    if (_done) return Scaffold(backgroundColor: GacomColors.obsidian,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🏗️ Colony Complete!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 8),
        Text('$filled / $_gridSize buildings placed · Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: GacomColors.deepOrange)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _reset, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('NEW COLONY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
      ])));

    final q = _questions[_idx];
    final opts = List<String>.from(q['opts'] as List);

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('COLONY BUILDER'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('🏗️ $filled/$_gridSize',
          style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange)))),
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // The colony grid — tap any filled cell for the real 3D model
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: _gridSize,
            itemBuilder: (_, i) {
              final b = _grid[i];
              return GestureDetector(
                onTap: b != null ? () => _viewBuilding(b) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: b != null ? GacomColors.deepOrange.withOpacity(0.12) : GacomColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: b != null ? GacomColors.deepOrange.withOpacity(0.5) : GacomColors.border, style: b != null ? BorderStyle.solid : BorderStyle.solid),
                  ),
                  child: Center(child: b != null
                    ? Text(b.emoji, style: const TextStyle(fontSize: 26))
                    : const Icon(Icons.add_rounded, color: GacomColors.textMuted, size: 20)),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Q ${_idx + 1}/${_questions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_idx + 1) / _questions.length, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange))),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
            child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.textPrimary, height: 1.4))),
          const SizedBox(height: 16),
          ...opts.map((opt) {
            Color borderColor = GacomColors.border, bgColor = GacomColors.cardDark;
            if (_answered && _selected == opt) {
              borderColor = opt == q['a'] ? GacomColors.success : GacomColors.error;
              bgColor = opt == q['a'] ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1);
            } else if (_answered && opt == q['a']) {
              borderColor = GacomColors.success; bgColor = GacomColors.success.withOpacity(0.08);
            }
            return GestureDetector(onTap: () => _answer(opt),
              child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.2)),
                child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15, color: GacomColors.textPrimary))));
          }),
        ]),
      ),
    );
  }
}
