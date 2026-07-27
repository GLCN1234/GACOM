import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Step-by-step algebra game — teaches students HOW to solve equations
/// rather than just testing if they know the answer. Each step is
/// explained, hints are available, and mistakes show the correct method.
class AlgebraGame extends StatefulWidget {
  const AlgebraGame({super.key});
  @override State<AlgebraGame> createState() => _AlgebraGameState();
}

class _AlgebraGameState extends State<AlgebraGame> {
  int _score = 0, _streak = 0, _qIdx = 0;
  final _ctrl = TextEditingController();
  String _feedback = '';
  bool _answered = false;
  bool _showHint = false;

  static const _questions = [
    // Linear equations
    {'type': 'linear', 'display': '2x = 8', 'answer': '4',
     'hint': 'Divide both sides by 2: x = 8 ÷ 2',
     'steps': ['Start: 2x = 8', 'Divide both sides by 2', 'x = 8 ÷ 2 = 4'],
     'topic': 'Linear Equations'},
    {'type': 'linear', 'display': '3x + 6 = 15', 'answer': '3',
     'hint': 'Step 1: Subtract 6 from both sides → 3x = 9. Step 2: Divide by 3.',
     'steps': ['3x + 6 = 15', 'Subtract 6: 3x = 9', 'Divide by 3: x = 3'],
     'topic': 'Linear Equations'},
    {'type': 'linear', 'display': '5x - 10 = 20', 'answer': '6',
     'hint': 'Add 10 to both sides first, then divide by 5.',
     'steps': ['5x - 10 = 20', 'Add 10: 5x = 30', 'Divide by 5: x = 6'],
     'topic': 'Linear Equations'},
    // Quadratic — find positive root
    {'type': 'quadratic', 'display': 'x² = 25  (positive root)', 'answer': '5',
     'hint': 'Take the square root of both sides: x = √25',
     'steps': ['x² = 25', 'Square root both sides', 'x = √25 = 5'],
     'topic': 'Quadratic Equations'},
    {'type': 'quadratic', 'display': 'x² - 9 = 0  (positive root)', 'answer': '3',
     'hint': 'Add 9 to both sides: x² = 9, then x = √9',
     'steps': ['x² - 9 = 0', 'Add 9: x² = 9', 'x = √9 = 3'],
     'topic': 'Quadratic Equations'},
    // Simultaneous — find x
    {'type': 'simultaneous', 'display': '2x + y = 7\nx - y = 1\nFind x', 'answer': '8/3',
     'hint': 'Add the equations: 3x = 8, so x = 8/3 ≈ 2.67. Type 8/3',
     'steps': ['Add equations: 3x + 0y = 8', '3x = 8', 'x = 8/3'],
     'topic': 'Simultaneous Equations'},
    {'type': 'simultaneous', 'display': 'x + y = 5\nx - y = 1\nFind x', 'answer': '3',
     'hint': 'Add both equations: 2x = 6, so x = 3',
     'steps': ['Add: 2x = 6', 'x = 3', 'Substitute: y = 2'],
     'topic': 'Simultaneous Equations'},
    // Factorisation
    {'type': 'factorise', 'display': 'x² + 5x + 6 = 0\nSmaller root?', 'answer': '-3',
     'hint': 'Find two numbers that multiply to 6 and add to 5: they are 2 and 3. So (x+2)(x+3)=0, roots are -2 and -3.',
     'steps': ['Find factors of 6 that sum to 5', '2 × 3 = 6, 2 + 3 = 5', '(x+2)(x+3)=0 → x=-2 or x=-3'],
     'topic': 'Factorisation'},
    {'type': 'factorise', 'display': 'x² - 7x + 12 = 0\nSmaller root?', 'answer': '3',
     'hint': 'Find factors of 12 that sum to -7: they are -3 and -4.',
     'steps': ['-3 × -4 = 12, -3 + -4 = -7', '(x-3)(x-4)=0', 'x = 3 or x = 4'],
     'topic': 'Factorisation'},
    // Algebraic fractions
    {'type': 'fraction', 'display': 'x/3 = 4', 'answer': '12',
     'hint': 'Multiply both sides by 3: x = 4 × 3',
     'steps': ['x/3 = 4', 'Multiply both sides by 3', 'x = 12'],
     'topic': 'Algebraic Fractions'},
  ];

  Map<String,dynamic> get _q => _questions[_qIdx % _questions.length];

  void _check() {
    final ans = _ctrl.text.trim();
    if (ans.isEmpty) return;
    HapticFeedback.lightImpact();
    final correct = ans == _q['answer'];
    setState(() {
      _answered = true;
      if (correct) {
        _score += 10 + _streak * 2;
        _streak++;
        _feedback = 'Correct! +${10 + (_streak-1)*2} pts';
      } else {
        _streak = 0;
        _feedback = 'Answer: ${_q['answer']}';
      }
    });
    Future.delayed(const Duration(milliseconds: 1800), _next);
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      _qIdx++;
      _ctrl.clear();
      _answered = false;
      _showHint = false;
      _feedback = '';
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
      appBar: AppBar(
        title: const Text('ALGEBRA TRAINER', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
        actions: [Padding(padding: const EdgeInsets.only(right: 12),
          child: Center(child: Text('Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange))))],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Topic badge
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(q['topic'] as String, style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12))),
        const SizedBox(height: 16),

        // Question card
        Container(width: double.infinity, padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Column(children: [
            Text('Solve:', style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            Text(q['display'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary, height: 1.5), textAlign: TextAlign.center),
          ])),
        const SizedBox(height: 20),

        // Step-by-step solution (shown after answering)
        if (_answered) ...[
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isCorrect ? GacomColors.success.withOpacity(0.08) : GacomColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: isCorrect ? GacomColors.success : GacomColors.error, width: 1.2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isCorrect ? Icons.check_circle_rounded : Icons.info_rounded, color: isCorrect ? GacomColors.success : GacomColors.error, size: 18),
                const SizedBox(width: 8),
                Text(_feedback, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: isCorrect ? GacomColors.success : GacomColors.error)),
              ]),
              const SizedBox(height: 12),
              const Text('Solution steps:', style: TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...steps.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 22, height: 22, decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 11, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))),
                ]))),
            ])),
          const SizedBox(height: 16),
        ] else ...[
          // Hint
          if (_showHint)
            Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: GacomColors.accentCyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: GacomColors.accentCyan.withOpacity(0.3))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline_rounded, color: GacomColors.accentCyan, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(q['hint'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4))),
              ])),

          // Answer input
          TextField(controller: _ctrl, keyboardType: TextInputType.text, onSubmitted: (_) => _check(),
            style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 24),
            textAlign: TextAlign.center,
            decoration: InputDecoration(hintText: 'Your answer', hintStyle: const TextStyle(color: GacomColors.textMuted),
              filled: true, fillColor: GacomColors.elevatedCard,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.deepOrange, width: 1.5)))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => setState(() => _showHint = !_showHint),
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
              label: Text(_showHint ? 'Hide hint' : 'Show hint', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(foregroundColor: GacomColors.accentCyan, side: const BorderSide(color: GacomColors.accentCyan), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _check,
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('CHECK', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
          ]),
        ],

        const SizedBox(height: 24),
        // Progress
        Row(children: [
          Text('Q ${(_qIdx % _questions.length) + 1}/${_questions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_qIdx % _questions.length + 1) / _questions.length, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange), minHeight: 6))),
          const SizedBox(width: 12),
          if (_streak > 1) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: GacomColors.error.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department_rounded, size: 12, color: GacomColors.error),
              const SizedBox(width: 3),
              Text('$_streak', style: const TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12)),
            ])),
        ]),
      ])),
    );
  }
}
