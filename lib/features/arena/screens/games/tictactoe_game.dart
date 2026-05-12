import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../../services/arena_service.dart';

class TicTacToeGame extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myId;
  final Future<void> Function(String winnerId) onWinner;
  const TicTacToeGame({super.key, required this.match, required this.myId, required this.onWinner});
  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  List<String> _board = List.filled(9, '');
  int _moveNumber = 0;
  StreamSubscription? _sub;
  bool _gameOver = false;

  bool get _isMyTurn => widget.match['current_turn'] == widget.myId;
  bool get _isCreator => widget.match['creator_id'] == widget.myId;
  String get _mySymbol => _isCreator ? 'X' : 'O';
  String get _oppSymbol => _isCreator ? 'O' : 'X';

  @override
  void initState() {
    super.initState();
    final state = widget.match['game_state'] as Map? ?? {};
    if (state['board'] != null) _board = List<String>.from(state['board']);
    _subscribeState();
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  void _subscribeState() {
    _sub = SupabaseService.client.from('arena_matches').stream(primaryKey: ['id']).eq('id', widget.match['id']).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final state = rows.first['game_state'] as Map? ?? {};
        if (state['board'] != null) setState(() => _board = List<String>.from(state['board']));
      }
    });
  }

  String? _checkWinner() {
    const wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
    for (final w in wins) {
      if (_board[w[0]].isNotEmpty && _board[w[0]] == _board[w[1]] && _board[w[1]] == _board[w[2]]) return _board[w[0]];
    }
    if (_board.every((c) => c.isNotEmpty)) return 'draw';
    return null;
  }

  Future<void> _tap(int idx) async {
    if (!_isMyTurn || _board[idx].isNotEmpty || _gameOver) return;
    HapticFeedback.lightImpact();
    final newBoard = List<String>.from(_board)..[idx] = _mySymbol;
    setState(() { _board = newBoard; _moveNumber++; });

    final opponentId = _isCreator ? widget.match['opponent_id'] : widget.match['creator_id'];
    await ArenaService.updateGameState(widget.match['id'], {'board': newBoard}, nextTurn: opponentId as String);
    await ArenaService.submitMove(widget.match['id'], {'index': idx, 'symbol': _mySymbol}, _moveNumber);

    final winner = _checkWinner();
    if (winner != null && !_gameOver) {
      setState(() => _gameOver = true);
      if (winner == 'draw') {
        await _handleDraw();
      } else {
        await widget.onWinner(widget.myId);
      }
    }
  }

  Future<void> _handleDraw() async {
    await ArenaService.refundStake(widget.match['creator_id'] as String, widget.match['stake_amount'] as int);
    await ArenaService.refundStake(widget.match['opponent_id'] as String, widget.match['stake_amount'] as int);
    await SupabaseService.client.from('arena_matches').update({'status': 'completed'}).eq('id', widget.match['id']);
    if (mounted) showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text("It's a Draw!", style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: GacomColors.warning, fontSize: 22)),
        content: const Text('Stakes have been refunded to both players.', style: TextStyle(color: GacomColors.textSecondary)),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text(_isMyTurn ? 'Your turn — tap a cell' : 'Opponent is thinking...', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: _isMyTurn ? GacomColors.deepOrange : GacomColors.txtMuted(context))),
        const SizedBox(height: 24),
        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: 9,
          itemBuilder: (_, i) {
            final cell = _board[i];
            final isX = cell == 'X';
            final isO = cell == 'O';
            return GestureDetector(
              onTap: () => _tap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: cell.isEmpty ? GacomColors.surface(context) : (isX ? GacomColors.deepOrange.withOpacity(0.08) : GacomColors.info.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cell.isEmpty ? GacomColors.borderColor(context) : (isX ? GacomColors.deepOrange : GacomColors.info), width: cell.isEmpty ? 0.5 : 1.5),
                ),
                child: Center(child: AnimatedScale(
                  scale: cell.isEmpty ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.elasticOut,
                  child: Text(cell, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 44, color: isX ? GacomColors.deepOrange : GacomColors.info)),
                )),
              ),
            );
          },
        )))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Legend(_mySymbol, 'You', GacomColors.deepOrange),
          const SizedBox(width: 24),
          _Legend(_oppSymbol, 'Opponent', GacomColors.info),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final String symbol, label;
  final Color color;
  const _Legend(this.symbol, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(symbol, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: color)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 13, color: GacomColors.txtSecondary(context))),
  ]);
}
