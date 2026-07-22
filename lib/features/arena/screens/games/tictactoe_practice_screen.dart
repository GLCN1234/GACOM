import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

/// Free practice match against a local AI opponent — no wallet, no stake,
/// no Supabase writes at all. The multiplayer TicTacToeGame widget is
/// tightly wired to a live arena_matches row (realtime sync, current_turn,
/// submitMove); reusing it here would mean faking a fake opponent's DB
/// writes, which is far more fragile than just running the game locally.
class TicTacToePracticeScreen extends StatefulWidget {
  const TicTacToePracticeScreen({super.key});
  @override
  State<TicTacToePracticeScreen> createState() => _TicTacToePracticeScreenState();
}

class _TicTacToePracticeScreenState extends State<TicTacToePracticeScreen> {
  List<String> _board = List.filled(9, '');
  bool _myTurn = true; // human is always X and goes first
  bool _gameOver = false;
  String? _resultText;
  int _wins = 0, _losses = 0, _draws = 0;

  static const _wins8 = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];

  String? _checkWinner(List<String> b) {
    for (final w in _wins8) {
      if (b[w[0]].isNotEmpty && b[w[0]] == b[w[1]] && b[w[1]] == b[w[2]]) return b[w[0]];
    }
    if (b.every((c) => c.isNotEmpty)) return 'draw';
    return null;
  }

  void _tap(int idx) {
    if (!_myTurn || _board[idx].isNotEmpty || _gameOver) return;
    HapticFeedback.lightImpact();
    setState(() { _board[idx] = 'X'; _myTurn = false; });

    final winner = _checkWinner(_board);
    if (winner != null) { _finish(winner); return; }

    // Small delay so the AI's move doesn't feel instant/robotic
    Future.delayed(const Duration(milliseconds: 450), _aiMove);
  }

  void _aiMove() {
    if (!mounted || _gameOver) return;
    final move = _bestMove(_board);
    if (move == -1) return;
    setState(() { _board[move] = 'O'; _myTurn = true; });
    final winner = _checkWinner(_board);
    if (winner != null) _finish(winner);
  }

  void _finish(String winner) {
    setState(() {
      _gameOver = true;
      if (winner == 'draw') { _draws++; _resultText = "It's a draw!"; }
      else if (winner == 'X') { _wins++; _resultText = 'You win! 🎉'; }
      else { _losses++; _resultText = 'Ryan wins this one.'; }
    });
  }

  void _reset() {
    setState(() { _board = List.filled(9, ''); _myTurn = true; _gameOver = false; _resultText = null; });
  }

  // ── Minimax: unbeatable AI. Best a human can do is force a draw. ─────────
  int _bestMove(List<String> board) {
    int bestScore = -1000, bestIdx = -1;
    for (int i = 0; i < 9; i++) {
      if (board[i].isEmpty) {
        board[i] = 'O';
        final score = _minimax(board, 0, false);
        board[i] = '';
        if (score > bestScore) { bestScore = score; bestIdx = i; }
      }
    }
    return bestIdx;
  }

  int _minimax(List<String> board, int depth, bool isMaximizing) {
    final result = _checkWinner(board);
    if (result == 'O') return 10 - depth;
    if (result == 'X') return depth - 10;
    if (result == 'draw') return 0;

    if (isMaximizing) {
      int best = -1000;
      for (int i = 0; i < 9; i++) {
        if (board[i].isEmpty) {
          board[i] = 'O';
          best = max(best, _minimax(board, depth + 1, false));
          board[i] = '';
        }
      }
      return best;
    } else {
      int best = 1000;
      for (int i = 0; i < 9; i++) {
        if (board[i].isEmpty) {
          board[i] = 'X';
          best = min(best, _minimax(board, depth + 1, true));
          board[i] = '';
        }
      }
      return best;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(
        title: const Text('PRACTICE VS RYAN'),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 16), child: Center(
            child: Text('W $_wins · L $_losses · D $_draws', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 12, color: GacomColors.textMuted)))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: GacomColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
            child: const Text('FREE PRACTICE — no stake, no wallet involved', style: TextStyle(color: GacomColors.info, fontSize: 11, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600))),
          const SizedBox(height: 16),
          Text(
            _gameOver ? _resultText! : (_myTurn ? 'Your turn — tap a cell' : 'Ryan is thinking...'),
            style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16,
              color: _gameOver ? GacomColors.warning : (_myTurn ? GacomColors.deepOrange : GacomColors.txtMuted(context))),
          ),
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
            Text('X', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.deepOrange)),
            const SizedBox(width: 6), const Text('You', style: TextStyle(fontSize: 13, color: GacomColors.textSecondary)),
            const SizedBox(width: 24),
            Text('O', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.info)),
            const SizedBox(width: 6), const Text('Ryan', style: TextStyle(fontSize: 13, color: GacomColors.textSecondary)),
          ]),
          if (_gameOver) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _reset,
              child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            )),
          ],
        ]),
      ),
    );
  }
}
