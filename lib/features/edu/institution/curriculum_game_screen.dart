import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class CurriculumGameScreen extends StatefulWidget {
  final String curriculumId;
  const CurriculumGameScreen({super.key, required this.curriculumId});
  @override State<CurriculumGameScreen> createState() => _CurriculumGameState();
}

class _CurriculumGameState extends State<CurriculumGameScreen> {
  List<Map<String,dynamic>> _allQuestions = [];
  List<Map<String,dynamic>> _levelQuestions = [];
  int _qIdx = 0;
  int _score = 0;
  int _correct = 0;
  String? _selected;
  bool _answered = false;
  bool _loading = true;
  bool _ttsEnabled = true;
  bool _levelComplete = false;
  bool _gameComplete = false;
  String _topic = '';
  String _subject = '';

  // Progressive level system
  static const _levels = ['foundation', 'beginner', 'intermediate', 'advanced', 'challenge'];
  static const _levelLabels = ['Foundation', 'Beginner', 'Intermediate', 'Advanced', 'Challenge'];
  static const _levelColors = [0xFF34D399, 0xFF3D8BFF, 0xFFFF8A33, 0xFFE85B8A, 0xFFFF6A00];
  static const _levelIcons = [
    Icons.filter_1_rounded,
    Icons.filter_2_rounded,
    Icons.filter_3_rounded,
    Icons.filter_4_rounded,
    Icons.filter_5_rounded,
  ];
  static const _passMark = 0.8; // 80% to advance level
  static const _questionsPerSession = 10; // show 10 at a time from the bank

  int _currentLevelIdx = 0;
  int _sessionAttempts = 0; // how many times student retried this level

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final row = await SupabaseService.client
          .from('institution_curricula')
          .select('topic,subject,class_level,generated_questions,total_questions')
          .eq('id', widget.curriculumId)
          .single();
      final qs = List<Map<String,dynamic>>.from(row['generated_questions'] as List? ?? []);
      if (mounted) setState(() {
        _allQuestions = qs;
        _topic = row['topic'] as String? ?? '';
        _subject = row['subject'] as String? ?? '';
        _loading = false;
        _loadLevel();
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _loadLevel() {
    final levelKey = _levels[_currentLevelIdx];
    final pool = _allQuestions.where((q) => q['level'] == levelKey).toList();
    pool.shuffle();
    // Pick 10 random questions from the level's pool of 60
    _levelQuestions = pool.take(_questionsPerSession).toList();
    _qIdx = 0; _score = 0; _correct = 0;
    _selected = null; _answered = false;
    _levelComplete = false;
  }

  Color get _levelColor => Color(_levelColors[_currentLevelIdx]);
  String get _levelLabel => _levelLabels[_currentLevelIdx];

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final q = _levelQuestions[_qIdx];
    final correct = opt.trim().toLowerCase() == (q['answer'] as String? ?? '').trim().toLowerCase();
    if (correct) { _score += 10; _correct++; }
    setState(() { _selected = opt; _answered = true; });
    Future.delayed(const Duration(milliseconds: 2200), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_qIdx >= _levelQuestions.length - 1) {
      // Session complete — check pass mark
      final pct = _correct / _levelQuestions.length;
      if (pct >= _passMark) {
        // Passed — advance or complete
        if (_currentLevelIdx >= _levels.length - 1) {
          setState(() => _gameComplete = true);
        } else {
          setState(() { _levelComplete = true; });
        }
      } else {
        // Failed — reload same level with different questions
        _sessionAttempts++;
        setState(() { _loadLevel(); });
      }
      return;
    }
    setState(() { _qIdx++; _selected = null; _answered = false; });
  }

  void _advanceLevel() {
    setState(() {
      _currentLevelIdx++;
      _sessionAttempts = 0;
      _loadLevel();
      _levelComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_allQuestions.isEmpty) return _buildNoQuestions();
    if (_gameComplete) return _buildGameComplete();
    if (_levelComplete) return _buildLevelComplete();
    if (_levelQuestions.isEmpty) return _buildNoQuestions();
    return _buildGame();
  }

  Widget _buildGame() {
    final q = _levelQuestions[_qIdx];
    final qType = q['type'] as String? ?? 'multiple_choice';
    final options = List<String>.from(q['options'] as List? ?? []);
    final steps = List<String>.from(q['steps'] as List? ?? []);
    final isCorrect = _answered && _selected != null &&
        _selected!.trim().toLowerCase() == (q['answer'] as String? ?? '').trim().toLowerCase();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(_topic, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: Icon(_ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: _ttsEnabled ? GacomColors.accentCyan : GacomColors.textMuted),
            onPressed: () => setState(() => _ttsEnabled = !_ttsEnabled)),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('$_score pts', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.deepOrange)))),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Level indicator + progress
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _levelColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_levelIcons[_currentLevelIdx], color: _levelColor, size: 14),
              const SizedBox(width: 5),
              Text(_levelLabel, style: TextStyle(color: _levelColor, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12)),
            ])),
          const SizedBox(width: 10),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_qIdx + 1) / _levelQuestions.length, backgroundColor: GacomColors.elevatedCard, valueColor: AlwaysStoppedAnimation(_levelColor), minHeight: 6))),
          const SizedBox(width: 10),
          Text('${_qIdx + 1}/${_levelQuestions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        // Level path
        Row(children: List.generate(_levels.length, (i) => Expanded(child: Container(height: 3, margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(color: i < _currentLevelIdx ? GacomColors.success : i == _currentLevelIdx ? _levelColor : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(2)))))),
        const SizedBox(height: 16),

        // Question type badge
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(8)),
          child: Text(qType.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: GacomColors.textMuted, fontSize: 9, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, letterSpacing: 1))),
        const SizedBox(height: 10),

        // Question
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: _levelColor.withOpacity(0.3))),
          child: Text(q['question'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.textPrimary, height: 1.4))),
        const SizedBox(height: 16),

        // Answer UI based on question type
        if (qType == 'true_false') ...[
          _tfOption('True', q), const SizedBox(height: 10), _tfOption('False', q),
        ] else if (qType == 'fill_blank' || qType == 'calculation') ...[
          _textAnswer(q, steps, isCorrect),
        ] else ...[
          // multiple_choice and spot_the_error
          ...options.map((opt) => _mcOption(opt, q)),
        ],

        // AI explanation after answering
        if (_answered) ...[
          const SizedBox(height: 12),
          _buildExplanation(steps, q, isCorrect),
        ],
        const SizedBox(height: 40),
      ])),
    );
  }

  Widget _mcOption(String opt, Map<String,dynamic> q) {
    final isCorrect = opt.trim().toLowerCase() == (q['answer'] as String? ?? '').trim().toLowerCase();
    Color bg = GacomColors.cardDark; Color border = GacomColors.border;
    if (_answered) {
      if (opt == _selected) { bg = isCorrect ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1); border = isCorrect ? GacomColors.success : GacomColors.error; }
      else if (isCorrect) { bg = GacomColors.success.withOpacity(0.06); border = GacomColors.success; }
    }
    return GestureDetector(onTap: () => _answer(opt),
      child: AnimatedContainer(duration: const Duration(milliseconds: 150), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: _answered && (opt == _selected || isCorrect) ? 1.5 : 1)),
        child: Row(children: [
          Expanded(child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14, color: GacomColors.textPrimary))),
          if (_answered && opt == _selected) Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? GacomColors.success : GacomColors.error, size: 18),
          if (_answered && opt != _selected && isCorrect) const Icon(Icons.check_circle_outlined, color: GacomColors.success, size: 18),
        ])));
  }

  Widget _tfOption(String opt, Map<String,dynamic> q) {
    final isCorrect = opt.toLowerCase() == (q['answer'] as String? ?? '').toLowerCase();
    final isSelected = _selected == opt;
    Color bg = GacomColors.cardDark; Color border = GacomColors.border;
    if (_answered && isSelected) { bg = isCorrect ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1); border = isCorrect ? GacomColors.success : GacomColors.error; }
    else if (_answered && isCorrect) { bg = GacomColors.success.withOpacity(0.06); border = GacomColors.success; }
    return GestureDetector(onTap: () => _answer(opt),
      child: AnimatedContainer(duration: const Duration(milliseconds: 150), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: 1.2)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(opt == 'True' ? Icons.check_rounded : Icons.close_rounded, color: _answered ? (isCorrect ? GacomColors.success : GacomColors.error) : GacomColors.textMuted, size: 20),
          const SizedBox(width: 10),
          Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: GacomColors.textPrimary)),
        ])));
  }

  Widget _textAnswer(Map<String,dynamic> q, List<String> steps, bool isCorrect) {
    final ctrl = TextEditingController();
    return Column(children: [
      if (!_answered) ...[
        TextField(controller: ctrl, style: const TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 20), textAlign: TextAlign.center,
          decoration: InputDecoration(hintText: 'Type your answer', hintStyle: const TextStyle(color: GacomColors.textMuted), filled: true, fillColor: GacomColors.elevatedCard, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: GacomColors.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _levelColor, width: 1.5)))),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => _answer(ctrl.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: _levelColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('CHECK', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
      ] else ...[
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isCorrect ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: isCorrect ? GacomColors.success : GacomColors.error)),
          child: Row(children: [
            Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? GacomColors.success : GacomColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('${isCorrect ? "Correct!" : "Answer: ${q['answer']}"}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: isCorrect ? GacomColors.success : GacomColors.error))),
          ])),
      ],
    ]);
  }

  Widget _buildExplanation(List<String> steps, Map<String,dynamic> q, bool isCorrect) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.smart_toy_outlined, color: GacomColors.accentCyan, size: 15),
        const SizedBox(width: 8),
        const Text('AI Explanation', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.accentCyan)),
        const Spacer(),
        if (_ttsEnabled) const Icon(Icons.volume_up_rounded, size: 13, color: GacomColors.textMuted),
      ]),
      const SizedBox(height: 8),
      ...steps.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 18, height: 18, decoration: BoxDecoration(color: _levelColor.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(child: Text('${e.key + 1}', style: TextStyle(color: _levelColor, fontSize: 9, fontWeight: FontWeight.w800)))),
          const SizedBox(width: 8),
          Expanded(child: Text(e.value as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontFamily: 'Rajdhani', height: 1.3))),
        ]))),
      if (q['concept'] != null) ...[
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _levelColor.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
          child: Text(q['concept'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic, height: 1.3))),
      ],
    ]));

  Widget _buildLevelComplete() {
    final pct = (_correct / _levelQuestions.length * 100).round();
    final nextLevel = _levelLabels[_currentLevelIdx + 1];
    return Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_levelIcons[_currentLevelIdx], size: 64, color: _levelColor),
      const SizedBox(height: 16),
      Text('$_levelLabel Complete!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: _levelColor)),
      const SizedBox(height: 8),
      Text('You scored $pct%', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 16)),
      const SizedBox(height: 24),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
        child: Column(children: [
          const Icon(Icons.lock_open_rounded, color: GacomColors.success, size: 28),
          const SizedBox(height: 8),
          Text('$nextLevel Unlocked!', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: GacomColors.success)),
          const SizedBox(height: 4),
          Text('Ready for harder questions', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        ])),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _advanceLevel,
        style: ElevatedButton.styleFrom(backgroundColor: _levelColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text('CONTINUE TO $nextLevel', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
    ]))));
  }

  Widget _buildGameComplete() => Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.emoji_events_rounded, size: 72, color: GacomColors.deepOrange),
    const SizedBox(height: 16),
    const Text('Topic Mastered!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.deepOrange)),
    const SizedBox(height: 8),
    Text(_topic, style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
    const SizedBox(height: 8),
    const Text('You completed all 5 difficulty levels', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
    const SizedBox(height: 32),
    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(_levels.length, (i) => Column(children: [
      Icon(_levelIcons[i], color: GacomColors.success, size: 28),
      const SizedBox(height: 4),
      Text(_levelLabels[i], style: const TextStyle(color: GacomColors.success, fontSize: 10)),
    ]))),
    const SizedBox(height: 32),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { setState(() { _currentLevelIdx = 0; _sessionAttempts = 0; _loadLevel(); _gameComplete = false; }); },
      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: const Text('REPLAY FROM FOUNDATION', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
    const SizedBox(height: 12),
    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Subjects', style: TextStyle(color: GacomColors.textMuted))),
  ]))));

  Widget _buildNoQuestions() => Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.hourglass_empty_rounded, size: 48, color: GacomColors.textMuted),
    const SizedBox(height: 12),
    const Text('Games Being Generated', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
    const SizedBox(height: 8),
    const Text('The AI is creating 300 questions for this topic.\nCheck back in a few minutes.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
  ]))));
}
