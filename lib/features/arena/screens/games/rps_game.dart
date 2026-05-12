import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../../services/arena_service.dart';

class RpsGame extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myId;
  final Future<void> Function(String winnerId) onWinner;
  const RpsGame({super.key, required this.match, required this.myId, required this.onWinner});
  @override
  State<RpsGame> createState() => _RpsGameState();
}

class _RpsGameState extends State<RpsGame> {
  int _myWins = 0, _oppWins = 0, _round = 1;
  String? _myPick, _oppPick;
  bool _waiting = false, _gameOver = false;
  StreamSubscription? _sub;
  int _moveNumber = 0;

  static const _choices = [
    {'id': 'rock', 'emoji': '🪨', 'label': 'Rock'},
    {'id': 'paper', 'emoji': '📄', 'label': 'Paper'},
    {'id': 'scissors', 'emoji': '✂️', 'label': 'Scissors'},
  ];

  bool get _isCreator => widget.match['creator_id'] == widget.myId;

  @override
  void initState() {
    super.initState();
    final state = widget.match['game_state'] as Map? ?? {};
    _myWins = (state[_isCreator ? 'creator_wins' : 'opponent_wins'] as int?) ?? 0;
    _oppWins = (state[_isCreator ? 'opponent_wins' : 'creator_wins'] as int?) ?? 0;
    _round = (state['round'] as int?) ?? 1;
    _subscribeState();
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  void _subscribeState() {
    _sub = SupabaseService.client.from('arena_matches').stream(primaryKey: ['id']).eq('id', widget.match['id']).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final state = rows.first['game_state'] as Map? ?? {};
        final creatorPick = state['creator_pick'] as String?;
        final opponentPick = state['opponent_pick'] as String?;
        // Both picks in — reveal
        if (creatorPick != null && opponentPick != null) {
          final myPick = _isCreator ? creatorPick : opponentPick;
          final oppPick = _isCreator ? opponentPick : creatorPick;
          setState(() { _myPick = myPick; _oppPick = oppPick; _waiting = false; });
          _resolveRound(myPick, oppPick, state);
        }
      }
    });
  }

  String _beats(String a) { if (a == 'rock') return 'scissors'; if (a == 'paper') return 'rock'; return 'paper'; }

  Future<void> _resolveRound(String myPick, String oppPick, Map state) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final iWin = _beats(myPick) == oppPick;
    final isDraw = myPick == oppPick;
    if (iWin) setState(() => _myWins++);
    else if (!isDraw) setState(() => _oppWins++);

    await Future.delayed(const Duration(seconds: 1));
    if (_myWins >= 3 && !_gameOver) {
      setState(() => _gameOver = true);
      await widget.onWinner(widget.myId);
    } else if (_oppWins >= 3 && !_gameOver) {
      setState(() => _gameOver = true);
      final oppId = _isCreator ? widget.match['opponent_id'] : widget.match['creator_id'];
      await widget.onWinner(oppId as String);
    } else {
      setState(() { _round++; _myPick = null; _oppPick = null; });
      await ArenaService.updateGameState(widget.match['id'], {'round': _round, 'creator_wins': _isCreator ? _myWins : _oppWins, 'opponent_wins': _isCreator ? _oppWins : _myWins});
    }
  }

  Future<void> _pick(String choice) async {
    if (_myPick != null || _waiting || _gameOver) return;
    HapticFeedback.mediumImpact();
    setState(() { _myPick = choice; _waiting = true; });
    _moveNumber++;

    final state = widget.match['game_state'] as Map? ?? {};
    final newState = {...state, _isCreator ? 'creator_pick' : 'opponent_pick': choice};
    await ArenaService.updateGameState(widget.match['id'], newState);
    await ArenaService.submitMove(widget.match['id'], {'round': _round, 'pick': choice}, _moveNumber);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Score
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _ScoreBox('You', _myWins, GacomColors.deepOrange),
          Column(children: [
            Text('ROUND $_round / 5', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.txtMuted(context))),
            const Text('Best of 5', style: TextStyle(fontSize: 11, color: GacomColors.textMuted)),
          ]),
          _ScoreBox('Opponent', _oppWins, GacomColors.info),
        ]),
        const SizedBox(height: 24),

        // Reveal area
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _PickReveal(_myPick, 'You', GacomColors.deepOrange),
          Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.txtMuted(context))),
          _PickReveal(_oppPick, 'Them', GacomColors.info),
        ]),
        const SizedBox(height: 32),

        Text(_myPick == null ? 'Make your pick!' : _oppPick == null ? 'Waiting for opponent...' : '', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: _myPick == null ? GacomColors.deepOrange : GacomColors.txtMuted(context))),
        const SizedBox(height: 20),

        // Choices
        if (_myPick == null) Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _choices.map((c) => GestureDetector(
            onTap: () => _pick(c['id'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GacomColors.surface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: GacomColors.borderColor(context), width: 0.5),
                boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.05), blurRadius: 12)],
              ),
              child: Column(children: [
                Text(c['emoji'] as String, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(c['label'] as String, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.txtPrimary(context))),
              ]),
            ),
          )).toList(),
        ),
      ]),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  const _ScoreBox(this.label, this.score, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$score', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 40, color: color)),
    Text(label, style: TextStyle(fontSize: 12, color: GacomColors.txtSecondary(context))),
  ]);
}

class _PickReveal extends StatelessWidget {
  final String? pick;
  final String label;
  final Color color;
  const _PickReveal(this.pick, this.label, this.color);
  static const _emojis = {'rock': '🪨', 'paper': '📄', 'scissors': '✂️'};
  @override
  Widget build(BuildContext context) => Column(children: [
    AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: pick != null ? color.withOpacity(0.1) : GacomColors.surface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pick != null ? color : GacomColors.borderColor(context), width: pick != null ? 1.5 : 0.5),
      ),
      child: Center(child: pick != null
          ? Text(_emojis[pick] ?? '?', style: const TextStyle(fontSize: 36))
          : Icon(Icons.help_outline_rounded, color: GacomColors.txtMuted(context), size: 32)),
    ),
    const SizedBox(height: 6),
    Text(label, style: TextStyle(fontSize: 12, color: GacomColors.txtSecondary(context))),
  ]);
}
