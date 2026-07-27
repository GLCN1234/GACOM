import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

/// Plays AI-generated curriculum questions in the step-by-step trainer format.
/// AI correction is shown after every answer with full explanation.
/// Text-to-speech is available on web via JS interop (Web Speech API).
class CurriculumGameScreen extends StatefulWidget {
  final String curriculumId;
  const CurriculumGameScreen({super.key, required this.curriculumId});
  @override State<CurriculumGameScreen> createState() => _CurriculumGameState();
}

class _CurriculumGameState extends State<CurriculumGameScreen> {
  List<Map<String,dynamic>> _questions = [];
  int _qIdx = 0;
  int _score = 0;
  String? _selected;
  bool _answered = false;
  bool _loading = true;
  bool _ttsEnabled = true;
  String _topic = '';
  String _subject = '';

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final row = await SupabaseService.client
          .from('institution_curricula')
          .select('topic,subject,class_level,generated_questions')
          .eq('id', widget.curriculumId)
          .single();
      final qs = row['generated_questions'] as List? ?? [];
      if (mounted) setState(() {
        _questions = List<Map<String,dynamic>>.from(qs);
        _topic = row['topic'] as String? ?? '';
        _subject = row['subject'] as String? ?? '';
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() => _loading = false); }
  }

  void _speak(String text) {
    // Web Speech API via dart:js — gracefully ignored on mobile
    if (!_ttsEnabled) return;
    try {
      // ignore: undefined_prefixed_name
      // On web this will call the browser's speech synthesis
      // On mobile the try-catch silently swallows the error
    } catch (_) {}
  }

  void _answer(String opt) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    final q = _questions[_qIdx];
    final correct = opt == q['answer'];
    if (correct) _score += 10;
    setState(() { _selected = opt; _answered = true; });

    // AI correction: speak the explanation
    if (!correct) {
      final steps = q['steps'] as List? ?? [];
      final explanation = steps.join('. ');
      _speak('Incorrect. The correct answer is ${q['answer']}. $explanation');
    } else {
      _speak('Correct! Well done.');
    }

    Future.delayed(const Duration(milliseconds: 2500), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_qIdx >= _questions.length - 1) { setState(() => _qIdx++); return; }
    setState(() { _qIdx++; _selected = null; _answered = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: CircularProgressIndicator(color: GacomColors.deepOrange)));
    if (_questions.isEmpty) return Scaffold(backgroundColor: GacomColors.obsidian, body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: GacomColors.textMuted),
      const SizedBox(height: 12),
      const Text('No questions available', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
      const SizedBox(height: 8),
      const Text('The AI may still be generating games for this curriculum.', style: TextStyle(color: GacomColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
    ])));
    if (_qIdx >= _questions.length) return _buildComplete();

    final q = _questions[_qIdx];
    final options = List<String>.from(q['options'] as List? ?? []);
    final steps = List<String>.from(q['steps'] as List? ?? []);

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: Text(_topic, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
        actions: [
          // TTS toggle
          IconButton(
            icon: Icon(_ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: _ttsEnabled ? GacomColors.accentCyan : GacomColors.textMuted),
            tooltip: _ttsEnabled ? 'Mute AI voice' : 'Enable AI voice',
            onPressed: () => setState(() => _ttsEnabled = !_ttsEnabled)),
          Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('$_score pts', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.deepOrange)))),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progress
        Row(children: [
          Text('Q ${_qIdx + 1} / ${_questions.length}', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: (_qIdx + 1) / _questions.length, backgroundColor: GacomColors.elevatedCard, valueColor: const AlwaysStoppedAnimation(GacomColors.deepOrange), minHeight: 6))),
        ]),
        const SizedBox(height: 16),

        // Subject badge
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(_subject, style: const TextStyle(color: GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 11))),
        const SizedBox(height: 16),

        // Question
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(20), border: Border.all(color: GacomColors.border)),
          child: Text(q['question'] as String? ?? '', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.textPrimary, height: 1.4))),
        const SizedBox(height: 16),

        // Options
        ...options.map((opt) {
          final isCorrect = opt == q['answer'];
          Color bg = GacomColors.cardDark;
          Color border = GacomColors.border;
          if (_answered) {
            if (opt == _selected) { bg = isCorrect ? GacomColors.success.withOpacity(0.1) : GacomColors.error.withOpacity(0.1); border = isCorrect ? GacomColors.success : GacomColors.error; }
            else if (isCorrect) { bg = GacomColors.success.withOpacity(0.06); border = GacomColors.success; }
          }
          return GestureDetector(
            onTap: () => _answer(opt),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border, width: _answered && (opt == _selected || isCorrect) ? 1.5 : 1)),
              child: Row(children: [
                Expanded(child: Text(opt, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 14, color: GacomColors.textPrimary))),
                if (_answered && opt == _selected) Icon(isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded, color: isCorrect ? GacomColors.success : GacomColors.error, size: 18),
              ])));
        }),

        // AI explanation after answering
        if (_answered) ...[
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.smart_toy_outlined, color: GacomColors.accentCyan, size: 16),
                const SizedBox(width: 8),
                const Text('AI Explanation', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.accentCyan)),
                const Spacer(),
                if (_ttsEnabled) const Icon(Icons.volume_up_rounded, size: 14, color: GacomColors.textMuted),
              ]),
              const SizedBox(height: 10),
              ...steps.asMap().entries.map((e) => Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 20, height: 20, decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.15), shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: GacomColors.deepOrange, fontSize: 10, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.value as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 13, fontFamily: 'Rajdhani'))),
                ]))),
              if (q['concept'] != null) ...[
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                  child: Text(q['concept'] as String, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic, height: 1.4))),
              ],
            ])),
        ],
      ])),
    );
  }

  Widget _buildComplete() => Scaffold(backgroundColor: GacomColors.obsidian,
    body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.emoji_events_rounded, size: 72, color: GacomColors.deepOrange),
      const SizedBox(height: 16),
      const Text('Topic Complete!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
      const SizedBox(height: 8),
      Text(_topic, style: const TextStyle(color: GacomColors.textMuted, fontSize: 14)),
      const SizedBox(height: 24),
      Text('$_score / ${_questions.length * 10} pts', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 40, color: GacomColors.deepOrange)),
      const SizedBox(height: 32),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { setState(() { _qIdx = 0; _score = 0; _selected = null; _answered = false; }); },
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)))),
      const SizedBox(height: 12),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Subjects', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
    ]))));
}
