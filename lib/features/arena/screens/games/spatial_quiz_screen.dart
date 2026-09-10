import 'package:flame/game.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../edu/edu_progress_recorder.dart';
import '../../games/astra_colony/spatial_quiz_game.dart';
import '../../games/astra_colony/virtual_joystick_widget.dart';

/// Generic replacement for the old popup-quiz pattern. Accepts ANY list of
/// {question, options, answer} maps — the exact shape already stored in
/// institution_curricula.generated_questions — and plays through them
/// continuously as a walk-to-the-correct-terminal world, with a real
/// checkpoint only every [batchSize] questions.
class SpatialQuizScreen extends StatefulWidget {
  const SpatialQuizScreen({super.key, this.subject = 'general', this.questions, this.batchSize = 5, this.title = 'FIELD TRIAL'});
  final String subject;
  final List<Map<String, dynamic>>? questions;
  final int batchSize;
  final String title;

  @override
  State<SpatialQuizScreen> createState() => _SpatialQuizScreenState();
}

const _fallbackQuestions = [
  {'question': 'What is the capital of Nigeria?', 'options': ['A. Lagos', 'B. Abuja', 'C. Kano', 'D. Ibadan'], 'answer': 'B. Abuja'},
  {'question': 'What is 12 × 8?', 'options': ['A. 84', 'B. 92', 'C. 96', 'D. 104'], 'answer': 'C. 96'},
  {'question': 'What gas do plants absorb from the air?', 'options': ['A. Oxygen', 'B. Nitrogen', 'C. Carbon Dioxide', 'D. Hydrogen'], 'answer': 'C. Carbon Dioxide'},
  {'question': 'Who wrote "Things Fall Apart"?', 'options': ['A. Wole Soyinka', 'B. Chinua Achebe', 'C. Chimamanda Adichie', 'D. Ben Okri'], 'answer': 'B. Chinua Achebe'},
  {'question': 'What is the powerhouse of the cell?', 'options': ['A. Nucleus', 'B. Mitochondria', 'C. Ribosome', 'D. Golgi Body'], 'answer': 'B. Mitochondria'},
  {'question': 'What is the square root of 144?', 'options': ['A. 10', 'B. 11', 'C. 12', 'D. 14'], 'answer': 'C. 12'},
  {'question': 'What is the largest ocean on Earth?', 'options': ['A. Atlantic', 'B. Indian', 'C. Pacific', 'D. Arctic'], 'answer': 'C. Pacific'},
  {'question': 'How many continents are there?', 'options': ['A. 5', 'B. 6', 'C. 7', 'D. 8'], 'answer': 'C. 7'},
];

enum _Phase { intro, playing, checkpoint }

class _SpatialQuizScreenState extends State<SpatialQuizScreen> {
  _Phase _phase = _Phase.intro;
  late SpatialQuizGame _game;
  String _questionText = '';
  int _questionIndexInBatch = 0;
  int _score = 0;
  int _streak = 0;
  bool _wrongPulse = false;
  int _checkpointScore = 0, _checkpointCorrect = 0, _checkpointTotal = 0;

  @override
  void initState() {
    super.initState();
    final questions = (widget.questions != null && widget.questions!.isNotEmpty) ? widget.questions! : _fallbackQuestions;
    _game = SpatialQuizGame(
      questions: questions,
      batchSize: widget.batchSize,
      onQuestionChanged: (index, text, total) { if (mounted) setState(() { _questionIndexInBatch = index; _questionText = text; }); },
      onAnswerResult: (correct, score, streak) {
        if (!mounted) return;
        setState(() { _score = score; _streak = streak; });
        HapticFeedback.mediumImpact();
        EduProgressRecorder.recordSession(subject: widget.subject, xpEarned: correct ? 10 : 0, questionsAnswered: 1, correctAnswers: correct ? 1 : 0);
        if (!correct) {
          setState(() => _wrongPulse = true);
          Future.delayed(const Duration(milliseconds: 350), () { if (mounted) setState(() => _wrongPulse = false); });
        }
      },
      onBatchComplete: (score, correct, total) {
        if (!mounted) return;
        setState(() { _checkpointScore = score; _checkpointCorrect = correct; _checkpointTotal = total; _phase = _Phase.checkpoint; });
      },
    );
  }

  void _onJoystickDirection(Offset dir) => _game.setMoveDirection(Vector2(dir.dx, dir.dy));

  void _continue() {
    setState(() => _phase = _Phase.playing);
    _game.continueAfterCheckpoint();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.intro) return _introScreen();

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      body: Stack(children: [
        GameWidget(game: _game),
        Positioned(top: 0, left: 0, right: 0, child: SafeArea(bottom: false, child: _topHud())),
        if (_phase == _Phase.playing) Positioned(left: 20, bottom: 28, child: VirtualJoystickWidget(onDirectionChanged: _onJoystickDirection)),
        if (_phase == _Phase.checkpoint) _checkpointOverlay(),
      ]),
    );
  }

  Widget _topHud() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
    child: Column(children: [
      Row(children: [
        _pill('🔥 STREAK $_streak', GacomColors.deepOrange),
        const Spacer(),
        _pill('SCORE $_score', GacomColors.accentCyan),
      ]),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _wrongPulse ? GacomColors.error : Colors.white.withOpacity(0.12), width: _wrongPulse ? 1.5 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('QUESTION ${_questionIndexInBatch + 1} / ${widget.batchSize}', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 10, color: GacomColors.accentCyan, letterSpacing: 1)),
          const SizedBox(height: 3),
          Text(_questionText, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
        ]),
      ),
    ]),
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.4))),
    child: Text(text, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: color)),
  );

  Widget _checkpointOverlay() => Positioned.fill(child: Container(
    color: Colors.black.withOpacity(0.82),
    child: Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('⚡', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      const Text('CHECKPOINT', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.success)),
      const SizedBox(height: 6),
      Text('$_checkpointCorrect / $_checkpointTotal correct  ·  Score $_checkpointScore', style: const TextStyle(color: GacomColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: _continue,
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('CONTINUE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white, letterSpacing: 1)))),
    ]))),
  ));

  Widget _introScreen() => Scaffold(
    backgroundColor: GacomColors.obsidian,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
      const SizedBox(height: 16),
      const Text('Walk to the terminal with the correct answer. Get it right, the next question spawns instantly. '
        'Get it wrong, just try another terminal — no penalty, no popup.',
        style: TextStyle(color: GacomColors.textSecondary, fontSize: 15, height: 1.5)),
      const SizedBox(height: 28),
      SizedBox(width: double.infinity, child: ElevatedButton(
        onPressed: () => setState(() => _phase = _Phase.playing),
        style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('START', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white, letterSpacing: 1)))),
    ]))));
}
