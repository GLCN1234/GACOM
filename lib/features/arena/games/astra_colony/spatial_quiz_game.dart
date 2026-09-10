import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'player_component.dart';
import 'environment_component.dart';
import 'answer_terminal_component.dart';

/// Generic engine: takes ANY list of {question, options, answer} objects
/// (the exact shape already stored in institution_curricula.
/// generated_questions) and presents each one as 4 physical terminals in
/// the world. Walk to the correct terminal to advance — instantly, no
/// popup, no per-question "complete" screen. A real checkpoint only
/// appears after [batchSize] questions, keeping the flow continuous.
class SpatialQuizGame extends FlameGame {
  SpatialQuizGame({
    required List<Map<String, dynamic>> questions,
    required this.onQuestionChanged,
    required this.onAnswerResult,
    required this.onBatchComplete,
    this.batchSize = 5,
  }) : _questions = List<Map<String, dynamic>>.from(questions)..shuffle();

  final List<Map<String, dynamic>> _questions;
  final int batchSize;

  /// (questionIndexInBatch, questionText, totalInBatch)
  final void Function(int index, String questionText, int totalInBatch) onQuestionChanged;
  /// (wasCorrect, runningScore, streak)
  final void Function(bool correct, int score, int streak) onAnswerResult;
  final void Function(int score, int correctCount, int totalInBatch) onBatchComplete;

  late final PlayerComponent player;
  final List<AnswerTerminalComponent> _terminals = [];

  int _cursor = 0;
  int _questionsInBatch = 0;
  int _score = 0;
  int _streak = 0;
  int _correctInBatch = 0;
  bool _resolving = false;
  bool _paused = false;

  static const double _pickupRadius = 34;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final worldSize = size.clone();
    add(EnvironmentComponent(worldSize: worldSize));
    player = PlayerComponent(startPosition: Vector2(worldSize.x * 0.5, worldSize.y * 0.88), worldBounds: worldSize);
    add(player);
    _spawnQuestion(worldSize);
  }

  void setMoveDirection(Vector2 direction) {
    if (!isLoaded) return;
    player.moveDirection = direction;
  }

  void _spawnQuestion(Vector2 worldSize) {
    for (final t in List<AnswerTerminalComponent>.from(_terminals)) {
      remove(t);
    }
    _terminals.clear();

    if (_questions.isEmpty) return;
    final q = _questions[_cursor % _questions.length];
    _cursor++;

    final options = List<String>.from(q['options'] as List? ?? const []);
    final answer = q['answer'] as String? ?? '';
    final questionText = q['question'] as String? ?? '';

    onQuestionChanged(_questionsInBatch, questionText, batchSize);

    final positions = [
      Vector2(worldSize.x * 0.26, worldSize.y * 0.42),
      Vector2(worldSize.x * 0.74, worldSize.y * 0.42),
      Vector2(worldSize.x * 0.26, worldSize.y * 0.6),
      Vector2(worldSize.x * 0.74, worldSize.y * 0.6),
    ];
    final shuffled = List<String>.from(options)..shuffle();
    for (var i = 0; i < shuffled.length && i < positions.length; i++) {
      final terminal = AnswerTerminalComponent(position: positions[i], label: shuffled[i], isCorrect: shuffled[i] == answer);
      _terminals.add(terminal);
      add(terminal);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded || _paused || _resolving || _terminals.isEmpty) return;

    for (final terminal in _terminals) {
      if (terminal.locked) continue;
      if ((player.position - terminal.position).length < _pickupRadius) {
        _resolveTerminal(terminal);
        break;
      }
    }
  }

  void _resolveTerminal(AnswerTerminalComponent terminal) {
    if (terminal.isCorrect) {
      _resolving = true;
      terminal.locked = true;
      _score += 10 + (_streak * 2);
      _streak++;
      _correctInBatch++;
      _questionsInBatch++;
      onAnswerResult(true, _score, _streak);

      Future.delayed(const Duration(milliseconds: 450), () {
        _resolving = false;
        if (_questionsInBatch >= batchSize) {
          _paused = true;
          onBatchComplete(_score, _correctInBatch, batchSize);
        } else {
          _spawnQuestion(size.clone());
        }
      });
    } else {
      terminal.flashWrong();
      _streak = 0;
      onAnswerResult(false, _score, _streak);
    }
  }

  /// Called by the hosting screen after showing the checkpoint, to resume
  /// with a fresh batch.
  void continueAfterCheckpoint() {
    _questionsInBatch = 0;
    _correctInBatch = 0;
    _paused = false;
    _spawnQuestion(size.clone());
  }
}
