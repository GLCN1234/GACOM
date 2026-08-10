import 'package:flutter/material.dart';
import '../edu_progress_recorder.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/theme_kit.dart';
import '../widgets/progress_collector_widget.dart';

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
  bool _showingStoryIntro = true;
  String _topic = '';
  String _subject = '';
  String _worldTheme = '';
  String _storyIntro = '';

  static const _levels = ['foundation', 'beginner', 'intermediate', 'advanced', 'challenge'];
  static const _levelLabels = ['Foundation', 'Beginner', 'Intermediate', 'Advanced', 'Boss Battle'];
  static const _levelColors = [0xFF34D399, 0xFF3D8BFF, 0xFFFF8A33, 0xFFE85B8A, 0xFFFF6A00];
  static const _levelIcons = [Icons.filter_1_rounded, Icons.filter_2_rounded, Icons.filter_3_rounded, Icons.filter_4_rounded, Icons.local_fire_department_rounded];
  static const _passMark = 0.8;
  static const _questionsPerSession = 10;

  int _currentLevelIdx = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final row = await SupabaseService.client
          .from('institution_curricula')
          .select('topic,subject,class_level,generated_questions,total_questions,world_theme,story_intro')
          .eq('id', widget.curriculumId)
          .single();
      final qs = List<Map<String,dynamic>>.from(row['generated_questions'] as List? ?? []);
      if (mounted) setState(() {
        _allQuestions = qs;
        _topic = row['topic'] as String? ?? '';
        _subject = row['subject'] as String? ?? '';
        _worldTheme = row['world_theme'] as String? ?? 'Adventure';
        _storyIntro = row['story_intro'] as String? ?? 'Your quest into $_topic begins now!';
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _loadLevel() {
    final levelKey = _levels[_currentLevelIdx];
    final pool = _allQuestions.where((q) => q['level'] == levelKey).toList();
    pool.shuffle();
    _levelQuestions = pool.take(_questionsPerSession).toList();
    _qIdx = 0; _score = 0; _correct = 0;
    _selected = null; _answered = false;
    _levelComplete = false;
  }

  Color get _levelColor => Color(_levelColors[_currentLevelIdx]);
  String get _levelLabel => _levelLabels[_currentLevelIdx];
  bool get _isBossLevel => _currentLevelIdx == _levels.length - 1;
  ThemeKit get _kit => themeKitFor(_worldTheme);
  String? get _latestChapterBeat {
    for (int i = _levelQuestions.length - 1; i >= 0; i--) {
      final beat = _levelQuestions[i]['chapter_update'] as String?;
      if (beat != null && beat.isNotEmpty) return beat;
    }
    return null;
  }

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final q = _levelQuestions[_qIdx];
    final correct = opt.trim().toLowerCase() == (q['answer'] as String? ?? '').trim().toLowerCase();
    if (correct) { _score += 10; _correct++; }
    setState(() { _selected = opt; _answered = true; });
    Future.delayed(const Duration(milliseconds: 2600), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_qIdx >= _levelQuestions.length - 1) {
      final pct = _correct / _levelQuestions.length;
      if (pct >= _passMark) {
        if (_currentLevelIdx >= _levels.length - 1) {
          setState(() => _gameComplete = true);
          _saveCompletion(pct);
        } else {
          setState(() { _levelComplete = true; });
        }
      } else {
        setState(() { _loadLevel(); });
      }
      return;
    }
    setState(() { _qIdx++; _selected = null; _answered = false; });
  }

  Future<void> _saveCompletion(double finalAccuracy) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('student_curriculum_progress').upsert({
        'student_id': uid,
        'curriculum_id': widget.curriculumId,
        'final_accuracy': (finalAccuracy * 100).round(),
        'completed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id,curriculum_id');
    } catch (_) {}
    // Feed this completed topic into the student's overall academic
    // profile — XP, accuracy, and streak — alongside built-in game results.
    final topicQuestionCount = _levelQuestions.length * 5;
    await EduProgressRecorder.recordSession(
      subject: EduProgressRecorder.subjectIdFromLabel(_subject),
      xpEarned: topicQuestionCount * 10,
      questionsAnswered: topicQuestionCount,
      correctAnswers: (finalAccuracy * topicQuestionCount).round(),
    );
  }

  void _advanceLevel() {
    setState(() {
      _currentLevelIdx++;
      _loadLevel();
      _levelComplete = false;
    });
  }

  void _beginAdventure() {
    setState(() {
      _showingStoryIntro = false;
      _loadLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_allQuestions.isEmpty) return _buildNoQuestions();
    if (_showingStoryIntro) return _buildStoryIntro();
    if (_gameComplete) return _buildGameComplete();
    if (_levelComplete) return _buildLevelComplete();
    if (_levelQuestions.isEmpty) return _buildNoQuestions();
    return _buildGame();
  }

  Widget _buildStoryIntro() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(30)),
        child: Text(_worldTheme.toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.deepOrange, letterSpacing: 1.5))),
      const SizedBox(height: 24),
      const Icon(Icons.auto_stories_rounded, size: 56, color: GacomColors.accentCyan),
      const SizedBox(height: 20),
      Text(_topic, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
        child: Text(_storyIntro, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.6), textAlign: TextAlign.center)),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _beginAdventure,
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: const Text('BEGIN ADVENTURE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
    ]))),
  );

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
        title: Text(_isBossLevel ? '⚔ BOSS BATTLE' : _topic, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
        backgroundColor: _isBossLevel ? GacomColors.deepOrange.withOpacity(0.15) : null,
        actions: [
          IconButton(icon: Icon(_ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: _ttsEnabled ? GacomColors.accentCyan : GacomColors.textMuted),
            onPressed: () => setState(() => _ttsEnabled = !_ttsEnabled)),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('$_score pts', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.deepOrange)))),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        Row(children: List.generate(_levels.length, (i) => Expanded(child: Container(height: 3, margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(color: i < _currentLevelIdx ? GacomColors.success : i == _currentLevelIdx ? _levelColor : GacomColors.elevatedCard, borderRadius: BorderRadius.circular(2)))))),
        const SizedBox(height: 12),

        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
          child: Text(_worldTheme.toUpperCase(), style: const TextStyle(color: GacomColors.accentCyan, fontSize: 9, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, letterSpacing: 1))),
        const SizedBox(height: 14),
        ProgressCollectorWidget(kit: _kit, current: _correct, target: _questionsPerSession),
        const SizedBox(height: 14),
        const SizedBox(height: 10),

        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: _levelColor.withOpacity(0.3))),
          child: Text(q['question'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.textPrimary, height: 1.4))),
        const SizedBox(height: 16),

        if (qType == 'true_false') ...[
          _tfOption('True', q), const SizedBox(height: 10), _tfOption('False', q),
        ] else if (qType == 'fill_blank' || qType == 'calculation') ...[
          _textAnswer(q, steps, isCorrect),
        ] else ...[
          ...options.map((opt) => _mcOption(opt, q)),
        ],

        if (_answered) ...[
          const SizedBox(height: 12),
          _buildNarrativeResult(isCorrect, q, steps),
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
      ],
    ]);
  }

  Widget _buildNarrativeResult(bool isCorrect, Map<String,dynamic> q, List<String> steps) {
    final narrative = isCorrect
        ? (q['narrative_success'] as String? ?? 'Correct! Well done.')
        : (q['narrative_failure'] as String? ?? 'Not quite — try again next time.');
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: isCorrect ? GacomColors.success.withOpacity(0.08) : GacomColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: isCorrect ? GacomColors.success : GacomColors.error)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(isCorrect ? Icons.auto_awesome_rounded : Icons.replay_rounded, color: isCorrect ? GacomColors.success : GacomColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(narrative, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: isCorrect ? GacomColors.success : GacomColors.error, height: 1.3))),
        ]),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 18, height: 18, decoration: BoxDecoration(color: _levelColor.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(child: Text('${e.key + 1}', style: TextStyle(color: _levelColor, fontSize: 9, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 8),
              Expanded(child: Text(e.value as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontFamily: 'Rajdhani', height: 1.3))),
            ]))),
        ],
        if (q['concept'] != null) ...[
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.school_outlined, size: 12, color: GacomColors.textMuted),
              const SizedBox(width: 6),
              Expanded(child: Text(q['concept'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic))),
            ])),
        ],
      ]));
  }

  Widget _buildLevelComplete() {
    final pct = (_correct / _levelQuestions.length * 100).round();
    final nextLevel = _levelLabels[_currentLevelIdx + 1];
    final nextIsBoss = _currentLevelIdx + 1 == _levels.length - 1;
    return Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_levelIcons[_currentLevelIdx], size: 64, color: _levelColor),
      const SizedBox(height: 16),
      Text('$_levelLabel Complete!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: _levelColor)),
      const SizedBox(height: 8),
      Text('You scored $pct%', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 16)),
      const SizedBox(height: 20),
      ProgressCollectorWidget(kit: _kit, current: _questionsPerSession, target: _questionsPerSession, chapterBeat: _latestChapterBeat),
      const SizedBox(height: 20),
      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
        child: Column(children: [
          Icon(nextIsBoss ? Icons.local_fire_department_rounded : Icons.lock_open_rounded, color: nextIsBoss ? GacomColors.deepOrange : GacomColors.success, size: 28),
          const SizedBox(height: 8),
          Text(nextIsBoss ? '$nextLevel Awaits!' : '$nextLevel Unlocked!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: nextIsBoss ? GacomColors.deepOrange : GacomColors.success)),
          const SizedBox(height: 4),
          Text(nextIsBoss ? 'Face the final challenge of this adventure' : 'Ready for harder questions', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        ])),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _advanceLevel,
        style: ElevatedButton.styleFrom(backgroundColor: _levelColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(nextIsBoss ? 'ENTER BOSS BATTLE' : 'CONTINUE TO $nextLevel', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
    ]))));
  }

  Widget _buildGameComplete() => Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.emoji_events_rounded, size: 72, color: GacomColors.deepOrange),
    const SizedBox(height: 16),
    const Text('Adventure Complete!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: GacomColors.deepOrange)),
    const SizedBox(height: 8),
    Text(_topic, style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
    const SizedBox(height: 4),
    Text(_worldTheme, style: const TextStyle(color: GacomColors.accentCyan, fontSize: 12)),
    const SizedBox(height: 8),
    const Text('You defeated the Boss Battle and mastered all 5 stages', style: TextStyle(color: GacomColors.textSecondary, fontSize: 13)),
    const SizedBox(height: 32),
    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(_levels.length, (i) => Column(children: [
      Icon(i == _levels.length - 1 ? Icons.emoji_events_rounded : _levelIcons[i], color: GacomColors.success, size: 26),
      const SizedBox(height: 4),
      Text(_levelLabels[i], style: const TextStyle(color: GacomColors.success, fontSize: 9), textAlign: TextAlign.center),
    ]))),
    const SizedBox(height: 32),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { setState(() { _currentLevelIdx = 0; _loadLevel(); _gameComplete = false; }); },
      style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      child: const Text('REPLAY ADVENTURE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)))),
    const SizedBox(height: 12),
    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Subjects', style: TextStyle(color: GacomColors.textMuted))),
  ]))));

  Widget _buildNoQuestions() => Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.hourglass_empty_rounded, size: 48, color: GacomColors.textMuted),
    const SizedBox(height: 12),
    const Text('Adventure Being Written', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
    const SizedBox(height: 8),
    const Text('The AI is crafting a full 300-question adventure for this topic.\nCheck back in a few minutes.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
  ]))));
}
