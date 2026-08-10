import 'package:flutter/material.dart';
import '../../../edu/edu_progress_recorder.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Physics step-by-step trainer — covers WAEC/NECO physics topics.
/// Each question shows the formula, the working, and explains the concept.
class PhysicsGame extends StatefulWidget {
  const PhysicsGame({super.key});
  @override State<PhysicsGame> createState() => _PhysicsGameState();
}

class _PhysicsGameState extends State<PhysicsGame> {
  int _score = 0, _qIdx = 0;
  final _ctrl = TextEditingController();
  bool _answered = false;
  bool _showHint = false;
  String _feedback = '';

  static const _questions = [
    // Motion
    {'topic': 'Motion & Speed', 'display': 'A car travels 120 km in 2 hours.\nWhat is its speed in km/h?', 'answer': '60',
     'formula': 'Speed = Distance ÷ Time',
     'hint': 'Speed = 120 ÷ 2 = 60 km/h',
     'steps': ['Formula: Speed = Distance ÷ Time', 'Speed = 120 km ÷ 2 h', 'Speed = 60 km/h'],
     'concept': 'Speed measures how fast an object moves. Distance divided by the time taken.'},
    // Force
    {'topic': 'Force (Newton\'s 2nd Law)', 'display': 'A force of 20 N acts on a 4 kg object.\nWhat is the acceleration?', 'answer': '5',
     'formula': 'F = ma  →  a = F ÷ m',
     'hint': 'a = F ÷ m = 20 ÷ 4 = 5 m/s²',
     'steps': ['Formula: F = ma', 'Rearrange: a = F ÷ m', 'a = 20 ÷ 4 = 5 m/s²'],
     'concept': 'Newton\'s 2nd Law: Force = mass × acceleration. The more force, the more acceleration.'},
    // Energy
    {'topic': 'Kinetic Energy', 'display': 'A 2 kg ball moves at 4 m/s.\nWhat is its kinetic energy in joules?', 'answer': '16',
     'formula': 'KE = ½mv²',
     'hint': 'KE = ½ × 2 × (4)² = 1 × 16 = 16 J',
     'steps': ['Formula: KE = ½mv²', 'KE = ½ × 2 × 4²', 'KE = 1 × 16 = 16 J'],
     'concept': 'Kinetic energy is the energy of motion. Depends on both mass and speed squared.'},
    // Pressure
    {'topic': 'Pressure', 'display': 'A force of 50 N acts on an area of 10 m².\nWhat is the pressure in Pa?', 'answer': '5',
     'formula': 'P = F ÷ A',
     'hint': 'P = 50 ÷ 10 = 5 Pa',
     'steps': ['Formula: Pressure = Force ÷ Area', 'P = 50 N ÷ 10 m²', 'P = 5 Pa (Pascals)'],
     'concept': 'Pressure = Force per unit area. Smaller area means greater pressure for the same force.'},
    // Work
    {'topic': 'Work Done', 'display': 'A force of 10 N moves an object 5 m.\nHow much work is done in joules?', 'answer': '50',
     'formula': 'W = F × d',
     'hint': 'W = 10 × 5 = 50 J',
     'steps': ['Formula: Work = Force × Distance', 'W = 10 N × 5 m', 'W = 50 Joules'],
     'concept': 'Work is done when a force causes movement. The direction of force and movement must match.'},
    // Ohm's Law
    {'topic': 'Electricity (Ohm\'s Law)', 'display': 'A 12 V battery drives a current through a 4 Ω resistor.\nWhat is the current in amperes?', 'answer': '3',
     'formula': 'V = IR  →  I = V ÷ R',
     'hint': 'I = V ÷ R = 12 ÷ 4 = 3 A',
     'steps': ['Formula: V = IR', 'Rearrange: I = V ÷ R', 'I = 12 ÷ 4 = 3 A'],
     'concept': 'Ohm\'s Law: Voltage = Current × Resistance. Higher resistance means less current flows.'},
    // Waves
    {'topic': 'Waves', 'display': 'A wave has frequency 5 Hz and wavelength 2 m.\nWhat is its speed in m/s?', 'answer': '10',
     'formula': 'v = fλ  (speed = frequency × wavelength)',
     'hint': 'v = 5 × 2 = 10 m/s',
     'steps': ['Formula: v = f × λ', 'v = 5 Hz × 2 m', 'v = 10 m/s'],
     'concept': 'Wave speed = frequency × wavelength. All electromagnetic waves travel at 3×10⁸ m/s in vacuum.'},
    // Density
    {'topic': 'Density', 'display': 'An object has mass 200 g and volume 50 cm³.\nWhat is its density in g/cm³?', 'answer': '4',
     'formula': 'ρ = m ÷ V',
     'hint': 'ρ = 200 ÷ 50 = 4 g/cm³',
     'steps': ['Formula: Density = Mass ÷ Volume', 'ρ = 200 g ÷ 50 cm³', 'ρ = 4 g/cm³'],
     'concept': 'Density tells us how much mass is packed into a given volume. Water is 1 g/cm³.'},
    // Gravity
    {'topic': 'Gravitational Force', 'display': 'A 5 kg object is on Earth (g = 10 m/s²).\nWhat is its weight in newtons?', 'answer': '50',
     'formula': 'W = mg',
     'hint': 'W = 5 × 10 = 50 N',
     'steps': ['Formula: Weight = mass × g', 'W = 5 kg × 10 m/s²', 'W = 50 N'],
     'concept': 'Weight is the gravitational force on an object. On the Moon (g=1.6), the same object would weigh only 8 N.'},
    // Power
    {'topic': 'Power', 'display': 'A machine does 500 J of work in 10 seconds.\nWhat is its power in watts?', 'answer': '50',
     'formula': 'P = W ÷ t',
     'hint': 'P = 500 ÷ 10 = 50 W',
     'steps': ['Formula: Power = Work ÷ Time', 'P = 500 J ÷ 10 s', 'P = 50 Watts'],
     'concept': 'Power measures how quickly work is done. 1 Watt = 1 Joule per second.'},
  ];

  Map<String,dynamic> get _q => _questions[_qIdx % _questions.length];

  void _check() {
    if (_ctrl.text.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    final correct = _ctrl.text.trim() == _q['answer'];
    if (correct) _score += 10;
    setState(() { _answered = true; _feedback = correct ? 'Correct!' : 'Answer: ${_q['answer']}'; });
    EduProgressRecorder.recordSession(
      subject: 'physics',
      xpEarned: correct ? 10 : 0,
      questionsAnswered: 1,
      correctAnswers: correct ? 1 : 0,
    );
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() { _qIdx++; _ctrl.clear(); _answered = false; _showHint = false; _feedback = ''; });
    });
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    final steps = q['steps'] as List;
    final isCorrect = _answered && _ctrl.text.trim() == q['answer'];

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('PHYSICS TRAINER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange))))]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Topic + formula
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF00C2A8).withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF00C2A8).withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.science_outlined, color: Color(0xFF00C2A8), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(q['topic'] as String, style: const TextStyle(color: Color(0xFF00C2A8), fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
              Text(q['formula'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontFamily: 'Rajdhani')),
            ])),
          ])),
        const SizedBox(height: 16),

        // Question
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Text(q['display'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary, height: 1.5), textAlign: TextAlign.center)),
        const SizedBox(height: 16),

        // Concept box
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: GacomColors.textMuted),
            const SizedBox(width: 8),
            Expanded(child: Text(q['concept'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12, height: 1.4))),
          ])),
        const SizedBox(height: 16),

        // Answer or result
        if (_answered) ...[
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isCorrect ? GacomColors.success.withOpacity(0.08) : GacomColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: isCorrect ? GacomColors.success : GacomColors.error)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? GacomColors.success : GacomColors.error, size: 18),
                const SizedBox(width: 8),
                Text(_feedback, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: isCorrect ? GacomColors.success : GacomColors.error)),
              ]),
              const SizedBox(height: 10),
              ...steps.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 20, height: 20, decoration: BoxDecoration(color: const Color(0xFF00C2A8).withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Color(0xFF00C2A8), fontSize: 10, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani'))),
                ]))),
            ])),
        ] else ...[
          if (_showHint) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.lightbulb_outline_rounded, color: GacomColors.accentCyan, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(q['hint'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13))),
            ])),
          TextField(controller: _ctrl, keyboardType: TextInputType.number, onSubmitted: (_) => _check(),
            style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 24),
            textAlign: TextAlign.center,
            decoration: InputDecoration(hintText: 'Your answer', hintStyle: const TextStyle(color: GacomColors.textMuted),
              filled: true, fillColor: GacomColors.elevatedCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00C2A8), width: 1.5)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => setState(() => _showHint = !_showHint),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 14), label: Text(_showHint ? 'Hide hint' : 'Hint', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(foregroundColor: GacomColors.accentCyan, side: const BorderSide(color: GacomColors.accentCyan), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _check,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C2A8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('CHECK', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
          ]),
        ],
        const SizedBox(height: 24),
        Row(children: [
          Text('${_qIdx % _questions.length + 1}/${_questions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_qIdx % _questions.length + 1) / _questions.length, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(Color(0xFF00C2A8)), minHeight: 6))),
        ]),
      ])),
    );
  }
}
