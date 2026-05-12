import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../services/arena_service.dart';

class TriviaGame extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myId;
  final Future<void> Function(String winnerId) onWinner;
  const TriviaGame({super.key, required this.match, required this.myId, required this.onWinner});
  @override
  State<TriviaGame> createState() => _TriviaGameState();
}

class _TriviaGameState extends State<TriviaGame> {
  List<Map<String, dynamic>> _questions = [];
  int _current = 0, _myScore = 0, _oppScore = 0;
  String? _selected;
  bool _loading = true, _answered = false, _gameOver = false;
  int _timeLeft = 15;
  Timer? _questionTimer;
  StreamSubscription? _sub;
  int _moveNumber = 0;

  bool get _isCreator => widget.match['creator_id'] == widget.myId;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _subscribeState();
  }

  @override
  void dispose() { _questionTimer?.cancel(); _sub?.cancel(); super.dispose(); }

  Future<void> _loadQuestions() async {
    final state = widget.match['game_state'] as Map? ?? {};
    if (state['questions'] != null) {
      setState(() { _questions = List<Map<String, dynamic>>.from(state['questions']); _loading = false; });
      _startTimer();
      return;
    }
    // Creator fetches and saves questions
    if (_isCreator) {
      final qs = await ArenaService.fetchTriviaQuestions();
      await ArenaService.updateGameState(widget.match['id'], {'questions': qs, 'creator_score': 0, 'opponent_score': 0});
      if (mounted) setState(() { _questions = qs; _loading = false; });
      _startTimer();
    } else {
      // Opponent waits for creator to save questions
      await Future.delayed(const Duration(seconds: 2));
      final data = await SupabaseService.client.from('arena_matches').select('game_state').eq('id', widget.match['id']).single();
      final state2 = data['game_state'] as Map? ?? {};
      if (state2['questions'] != null && mounted) {
        setState(() { _questions = List<Map<String, dynamic>>.from(state2['questions']); _loading = false; });
        _startTimer();
      }
    }
  }

  void _subscribeState() {
    _sub = SupabaseService.client.from('arena_matches').stream(primaryKey: ['id']).eq('id', widget.match['id']).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final state = rows.first['game_state'] as Map? ?? {};
        setState(() {
          _myScore = (state[_isCreator ? 'creator_score' : 'opponent_score'] as int?) ?? _myScore;
          _oppScore = (state[_isCreator ? 'opponent_score' : 'creator_score'] as int?) ?? _oppScore;
          if (state['questions'] != null && _questions.isEmpty) {
            _questions = List<Map<String, dynamic>>.from(state['questions']);
            _loading = false;
            _startTimer();
          }
        });
      }
    });
  }

  void _startTimer() {
    _questionTimer?.cancel();
    setState(() { _timeLeft = 15; _answered = false; _selected = null; });
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_timeLeft > 0) { setState(() => _timeLeft--); }
      else { t.cancel(); _nextQuestion(); }
    });
  }

  Future<void> _answer(String choice) async {
    if (_answered || _gameOver) return;
    HapticFeedback.lightImpact();
    _questionTimer?.cancel();
    final q = _questions[_current];
    final correct = choice == q['correct_answer'];
    setState(() { _selected = choice; _answered = true; if (correct) _myScore++; });
    _moveNumber++;

    final state = widget.match['game_state'] as Map? ?? {};
    await ArenaService.updateGameState(widget.match['id'], {...state, _isCreator ? 'creator_score' : 'opponent_score': _myScore});
    await ArenaService.submitMove(widget.match['id'], {'question': _current, 'answer': choice, 'correct': correct}, _moveNumber);

    await Future.delayed(const Duration(milliseconds: 1200));
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_gameOver) return;
    if (_current >= _questions.length - 1) { _endGame(); return; }
    setState(() => _current++);
    _startTimer();
  }

  Future<void> _endGame() async {
    if (_gameOver) return;
    setState(() => _gameOver = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (_myScore > _oppScore) {
      await widget.onWinner(widget.myId);
    } else if (_oppScore > _myScore) {
      final oppId = _isCreator ? widget.match['opponent_id'] : widget.match['creator_id'];
      await widget.onWinner(oppId as String);
    } else {
      // Draw — refund
      await ArenaService.refundStake(widget.match['creator_id'] as String, widget.match['stake_amount'] as int);
      await ArenaService.refundStake(widget.match['opponent_id'] as String, widget.match['stake_amount'] as int);
      await SupabaseService.client.from('arena_matches').update({'status': 'completed'}).eq('id', widget.match['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: GacomColors.deepOrange));
    if (_questions.isEmpty) return Center(child: Text('Loading questions...', style: TextStyle(color: GacomColors.txtMuted(context))));

    final q = _questions[_current];
    final opts = [
      {'key': 'a', 'text': q['option_a']},
      {'key': 'b', 'text': q['option_b']},
      {'key': 'c', 'text': q['option_c']},
      {'key': 'd', 'text': q['option_d']},
    ];
    final correct = q['correct_answer'] as String;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Score + progress
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Q${_current + 1}/${_questions.length}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.txtMuted(context))),
          Row(children: [
            Text('You: $_myScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.deepOrange)),
            const Text('  ·  ', style: TextStyle(color: GacomColors.textMuted)),
            Text('Them: $_oppScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.info)),
          ]),
          // Timer
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _timeLeft <= 5 ? GacomColors.error.withOpacity(0.12) : GacomColors.deepOrange.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _timeLeft <= 5 ? GacomColors.error : GacomColors.deepOrange, width: 1.5),
            ),
            child: Center(child: Text('$_timeLeft', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: _timeLeft <= 5 ? GacomColors.error : GacomColors.deepOrange))),
          ),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: (_current + 1) / _questions.length, backgroundColor: GacomColors.borderColor(context), color: GacomColors.deepOrange, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 20),

        // Question
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: GacomColors.surface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.borderColor(context), width: 0.5)),
          child: Text(q['question'] as String, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 17, color: GacomColors.txtPrimary(context), height: 1.4)),
        ),
        const SizedBox(height: 16),

        // Options
        ...opts.map((opt) {
          final key = opt['key'] as String;
          final text = opt['text'] as String;
          final isSelected = _selected == key;
          final isCorrect = _answered && key == correct;
          final isWrong = _answered && isSelected && key != correct;
          Color borderColor = GacomColors.borderColor(context);
          Color bgColor = GacomColors.surface(context);
          Color textColor = GacomColors.txtPrimary(context);
          if (isCorrect) { borderColor = GacomColors.success; bgColor = GacomColors.success.withOpacity(0.08); textColor = GacomColors.success; }
          if (isWrong) { borderColor = GacomColors.error; bgColor = GacomColors.error.withOpacity(0.08); textColor = GacomColors.error; }
          if (isSelected && !isWrong && !isCorrect) { borderColor = GacomColors.deepOrange; bgColor = GacomColors.deepOrange.withOpacity(0.08); }

          return GestureDetector(
            onTap: () => _answer(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor, width: isCorrect || isWrong ? 1.5 : 0.5)),
              child: Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: borderColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Center(child: Text(key.toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: borderColor)))),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
                if (isCorrect) const Icon(Icons.check_circle_rounded, color: GacomColors.success, size: 18),
                if (isWrong) const Icon(Icons.cancel_rounded, color: GacomColors.error, size: 18),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}
