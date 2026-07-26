import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class TriviaSoloScreen extends StatefulWidget {
  const TriviaSoloScreen({super.key});
  @override State<TriviaSoloScreen> createState() => _TriviaSoloState();
}

class _TriviaSoloState extends State<TriviaSoloScreen> {
  static const _questions = [
    {'q': 'What is the capital of Nigeria?', 'a': 'Abuja', 'opts': ['Lagos', 'Abuja', 'Kano', 'Ibadan']},
    {'q': 'What does CPU stand for?', 'a': 'Central Processing Unit', 'opts': ['Central Processing Unit', 'Computer Power Unit', 'Core Processing Utility', 'Control Panel Unit']},
    {'q': 'Which planet is closest to the Sun?', 'a': 'Mercury', 'opts': ['Venus', 'Earth', 'Mercury', 'Mars']},
    {'q': 'What is 12 × 12?', 'a': '144', 'opts': ['124', '132', '144', '148']},
    {'q': 'Who invented the telephone?', 'a': 'Alexander Graham Bell', 'opts': ['Thomas Edison', 'Nikola Tesla', 'Alexander Graham Bell', 'Guglielmo Marconi']},
    {'q': 'What is the chemical symbol for water?', 'a': 'H₂O', 'opts': ['HO', 'H₂O', 'H₂O₂', 'OH']},
    {'q': 'What is the largest continent?', 'a': 'Asia', 'opts': ['Africa', 'Asia', 'Europe', 'Australia']},
    {'q': 'How many sides does a hexagon have?', 'a': '6', 'opts': ['5', '6', '7', '8']},
    {'q': 'What is the speed of light (approx)?', 'a': '300,000 km/s', 'opts': ['150,000 km/s', '300,000 km/s', '500,000 km/s', '1,000,000 km/s']},
    {'q': 'Who wrote "Things Fall Apart"?', 'a': 'Chinua Achebe', 'opts': ['Wole Soyinka', 'Chinua Achebe', 'Chimamanda Adichie', 'Ben Okri']},
  ];

  late List<Map<String, dynamic>> _shuffled;
  int _idx = 0, _score = 0, _timeLeft = 15;
  String? _selected;
  bool _answered = false, _done = false;
  Timer? _timer;

  @override void initState() { super.initState(); _shuffled = [..._questions]..shuffle(); _startTimer(); }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  void _startTimer() {
    _timer?.cancel();
    _timeLeft = 15;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_timeLeft <= 1) { _answered = true; _nextQ(); }
      else setState(() => _timeLeft--);
    });
  }

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    _timer?.cancel();
    final correct = opt == _shuffled[_idx]['a'];
    if (correct) _score += 10 + _timeLeft;
    setState(() { _selected = opt; _answered = true; });
    Future.delayed(const Duration(milliseconds: 1000), _nextQ);
  }

  void _nextQ() {
    if (_idx >= _shuffled.length - 1) { setState(() => _done = true); return; }
    setState(() { _idx++; _selected = null; _answered = false; });
    _startTimer();
  }

  void _reset() { setState(() { _shuffled = [..._questions]..shuffle(); _idx = 0; _score = 0; _selected = null; _answered = false; _done = false; }); _startTimer(); }

  @override
  Widget build(BuildContext ctx) {
    if (_done) return Scaffold(backgroundColor: GacomColors.obsidian,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎯 Quiz Complete!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 12),
        Text('Score: $_score / ${_shuffled.length * 25}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: GacomColors.deepOrange)),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _reset, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
      ])));

    final q = _shuffled[_idx];
    final opts = List<String>.from(q['opts'] as List);
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('TRIVIA VS RYAN (FREE)'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('Score: $_score', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.deepOrange)))),
      ]),
      body: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Q ${_idx + 1}/${_shuffled.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _timeLeft <= 5 ? GacomColors.error.withOpacity(0.15) : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50)),
            child: Text('⏱ ${_timeLeft}s', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: _timeLeft <= 5 ? GacomColors.error : GacomColors.textPrimary))),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (_idx + 1) / _shuffled.length, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange))),
        const SizedBox(height: 24),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
          child: Text(q['q'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary, height: 1.4))),
        const SizedBox(height: 20),
        ...opts.map((opt) {
          Color borderColor = GacomColors.border;
          Color bgColor = GacomColors.cardDark;
          if (_answered && _selected == opt) {
            borderColor = opt == q['a'] ? GacomColors.success : GacomColors.error;
            bgColor = opt == q['a'] ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1);
          } else if (_answered && opt == q['a']) {
            borderColor = GacomColors.success; bgColor = GacomColors.success.withOpacity(0.08);
          }
          return GestureDetector(
            onTap: () => _answer(opt),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: 1.2)),
              child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15, color: GacomColors.textPrimary))),
          );
        }),
      ])),
    );
  }
}
