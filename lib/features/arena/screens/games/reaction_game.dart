import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../services/arena_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REACTION TAP GAME
// ─────────────────────────────────────────────────────────────────────────────
class ReactionGame extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myId;
  final Future<void> Function(String winnerId) onWinner;
  const ReactionGame({super.key, required this.match, required this.myId, required this.onWinner});
  @override
  State<ReactionGame> createState() => _ReactionGameState();
}

class _ReactionGameState extends State<ReactionGame> {
  int _myWins = 0, _oppWins = 0, _round = 1;
  bool _waiting = true, _active = false, _tapped = false, _gameOver = false;
  int? _reactionMs;
  Timer? _showTimer;
  DateTime? _showTime;
  StreamSubscription? _sub;
  int _moveNumber = 0;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _isCreator = widget.match['creator_id'] == widget.myId;
    _subscribeState();
    _startRound();
  }

  @override
  void dispose() { _showTimer?.cancel(); _sub?.cancel(); super.dispose(); }

  void _subscribeState() {
    _sub = SupabaseService.client.from('arena_matches').stream(primaryKey: ['id']).eq('id', widget.match['id']).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final state = rows.first['game_state'] as Map? ?? {};
        setState(() {
          _myWins = (state[_isCreator ? 'creator_wins' : 'opponent_wins'] as int?) ?? _myWins;
          _oppWins = (state[_isCreator ? 'opponent_wins' : 'creator_wins'] as int?) ?? _oppWins;
          _round = (state['round'] as int?) ?? _round;
        });
        if (_myWins >= 3 && !_gameOver) { setState(() => _gameOver = true); widget.onWinner(widget.myId); }
        if (_oppWins >= 3 && !_gameOver) {
          setState(() => _gameOver = true);
          widget.onWinner(_isCreator ? widget.match['opponent_id'] as String : widget.match['creator_id'] as String);
        }
      }
    });
  }

  void _startRound() {
    setState(() { _waiting = true; _active = false; _tapped = false; _reactionMs = null; });
    final delay = Duration(milliseconds: 2000 + Random().nextInt(3000));
    _showTimer = Timer(delay, () {
      if (!mounted || _gameOver) return;
      setState(() { _waiting = false; _active = true; _showTime = DateTime.now(); });
      // Auto-fail if no tap in 3 seconds
      _showTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted || _tapped) return;
        _onMiss();
      });
    });
  }

  Future<void> _onTap() async {
    if (!_active || _tapped || _gameOver) return;
    HapticFeedback.heavyImpact();
    final ms = DateTime.now().difference(_showTime!).inMilliseconds;
    setState(() { _tapped = true; _active = false; _reactionMs = ms; _myWins++; });
    _moveNumber++;

    final state = widget.match['game_state'] as Map? ?? {};
    final newMyWins = _myWins;
    await ArenaService.updateGameState(widget.match['id'], {
      ...state,
      _isCreator ? 'creator_wins' : 'opponent_wins': newMyWins,
      'round': _round + 1,
    });
    await ArenaService.submitMove(widget.match['id'], {'round': _round, 'reaction_ms': ms}, _moveNumber);

    if (newMyWins >= 3) { setState(() => _gameOver = true); await widget.onWinner(widget.myId); return; }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _round++);
    _startRound();
  }

  Future<void> _onMiss() async {
    if (_tapped || _gameOver) return;
    setState(() { _tapped = true; _active = false; });
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _round++);
    _startRound();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _RScore('You', _myWins, GacomColors.deepOrange),
          Text('Round $_round / 5', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.txtMuted(context))),
          _RScore('Them', _oppWins, GacomColors.info),
        ]),
        const SizedBox(height: 32),
        Expanded(child: Center(child: GestureDetector(
          onTap: _onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 220, height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _waiting
                  ? GacomColors.surface(context)
                  : _active
                      ? GacomColors.deepOrange
                      : _reactionMs != null
                          ? GacomColors.success
                          : GacomColors.surface(context),
              border: Border.all(
                color: _active ? GacomColors.deepOrange : GacomColors.borderColor(context),
                width: _active ? 3 : 1,
              ),
              boxShadow: _active ? [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.5), blurRadius: 40, spreadRadius: 10)] : [],
            ),
            child: Center(child: _waiting
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.hourglass_top_rounded, color: GacomColors.txtMuted(context), size: 48),
                    const SizedBox(height: 12),
                    Text('Get ready...', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: GacomColors.txtMuted(context))),
                  ])
                : _active
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('TAP!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 48, color: Colors.white)),
                        Text('NOW!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 32, color: Colors.white70)),
                      ])
                    : _reactionMs != null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 48),
                            const SizedBox(height: 8),
                            Text('${_reactionMs}ms', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 28, color: Colors.white)),
                            const Text('Nice!', style: TextStyle(fontFamily: 'Rajdhani', fontSize: 16, color: Colors.white70)),
                          ])
                        : const Icon(Icons.close_rounded, color: GacomColors.error, size: 64)),
          ),
        ))),
        const SizedBox(height: 16),
        Text('Tap the circle the moment it turns orange!', style: TextStyle(fontSize: 13, color: GacomColors.txtMuted(context)), textAlign: TextAlign.center),
      ]),
    );
  }
}

class _RScore extends StatelessWidget {
  final String label; final int wins; final Color color;
  const _RScore(this.label, this.wins, this.color);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$wins', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 40, color: color)),
    Text(label, style: TextStyle(fontSize: 12, color: GacomColors.txtSecondary(context))),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// CHESS GAME (using chess.dart logic — board only, moves synced via Supabase)
// ─────────────────────────────────────────────────────────────────────────────
class ChessGame extends StatefulWidget {
  final Map<String, dynamic> match;
  final String myId;
  final Future<void> Function(String winnerId) onWinner;
  const ChessGame({super.key, required this.match, required this.myId, required this.onWinner});
  @override
  State<ChessGame> createState() => _ChessGameState();
}

class _ChessGameState extends State<ChessGame> {
  // Simplified chess representation using FEN-like board array
  // Each square: '' (empty), or piece code: 'wP','wR','wN','wB','wQ','wK','bP','bR','bN','bB','bQ','bK'
  List<String> _board = [];
  String? _selected; // selected square like 'e2'
  bool _isWhite = true; // creator plays white
  List<String> _legalMoves = [];
  String _status = 'active';
  StreamSubscription? _sub;
  int _moveNumber = 0;

  bool get _isCreator => widget.match['creator_id'] == widget.myId;
  bool get _myTurn => widget.match['current_turn'] == widget.myId;

  static const _files = ['a','b','c','d','e','f','g','h'];

  @override
  void initState() {
    super.initState();
    _isWhite = _isCreator;
    _initBoard();
    _subscribeState();
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  void _initBoard() {
    final state = widget.match['game_state'] as Map? ?? {};
    if (state['board'] != null) {
      setState(() => _board = List<String>.from(state['board']));
    } else {
      _board = List.filled(64, '');
      // Set up starting position
      const backRank = ['R','N','B','Q','K','B','N','R'];
      for (int i = 0; i < 8; i++) {
        _board[i] = 'b${backRank[i]}';        // black back rank
        _board[8 + i] = 'bP';                 // black pawns
        _board[48 + i] = 'wP';                // white pawns
        _board[56 + i] = 'w${backRank[i]}';   // white back rank
      }
    }
  }

  void _subscribeState() {
    _sub = SupabaseService.client.from('arena_matches').stream(primaryKey: ['id']).eq('id', widget.match['id']).listen((rows) {
      if (rows.isNotEmpty && mounted) {
        final state = rows.first['game_state'] as Map? ?? {};
        if (state['board'] != null) setState(() => _board = List<String>.from(state['board']));
        _status = rows.first['status'] as String? ?? 'active';
      }
    });
  }

  int _sqIndex(String sq) {
    final f = _files.indexOf(sq[0]);
    final r = int.parse(sq[1]) - 1;
    return (7 - r) * 8 + f;
  }

  String _sqName(int idx) {
    final f = _files[idx % 8];
    final r = 8 - (idx ~/ 8);
    return '$f$r';
  }

  bool _isMyPiece(String piece) => _isWhite ? piece.startsWith('w') : piece.startsWith('b');

  List<String> _getMoves(int fromIdx) {
    final piece = _board[fromIdx];
    if (piece.isEmpty) return [];
    final moves = <String>[];
    final type = piece[1];
    final isWhitePiece = piece.startsWith('w');
    final dir = isWhitePiece ? -1 : 1; // up for white, down for black

    void addIfValid(int toIdx) {
      if (toIdx < 0 || toIdx >= 64) return;
      final target = _board[toIdx];
      if (target.isEmpty || (isWhitePiece ? target.startsWith('b') : target.startsWith('w'))) moves.add(_sqName(toIdx));
    }

    void slide(List<int> dirs) {
      for (final d in dirs) {
        var cur = fromIdx + d;
        while (cur >= 0 && cur < 64) {
          final fromFile = fromIdx % 8;
          final curFile = cur % 8;
          if ((d == 1 || d == -1) && (curFile - fromFile).abs() > 1) break;
          if (_board[cur].isEmpty) { moves.add(_sqName(cur)); cur += d; }
          else { addIfValid(cur); break; }
        }
      }
    }

    switch (type) {
      case 'P':
        final step = fromIdx + dir * 8;
        if (step >= 0 && step < 64 && _board[step].isEmpty) {
          moves.add(_sqName(step));
          final startRank = isWhitePiece ? 6 : 1;
          final doubleStep = fromIdx + dir * 16;
          if ((fromIdx ~/ 8) == startRank && _board[doubleStep].isEmpty) moves.add(_sqName(doubleStep));
        }
        for (final side in [-1, 1]) {
          final cap = fromIdx + dir * 8 + side;
          if (cap >= 0 && cap < 64) {
            final t = _board[cap];
            if (t.isNotEmpty && (isWhitePiece ? t.startsWith('b') : t.startsWith('w'))) moves.add(_sqName(cap));
          }
        }
        break;
      case 'R': slide([-8, 8, -1, 1]); break;
      case 'B': slide([-9, -7, 7, 9]); break;
      case 'Q': slide([-8, 8, -1, 1, -9, -7, 7, 9]); break;
      case 'N':
        for (final d in [-17, -15, -10, -6, 6, 10, 15, 17]) addIfValid(fromIdx + d);
        break;
      case 'K':
        for (final d in [-9, -8, -7, -1, 1, 7, 8, 9]) addIfValid(fromIdx + d);
        break;
    }
    return moves;
  }

  Future<void> _onSquareTap(int idx) async {
    if (!_myTurn || _status != 'active') return;
    final sq = _sqName(idx);
    final piece = _board[idx];

    if (_selected == null) {
      if (piece.isEmpty || !_isMyPiece(piece)) return;
      setState(() { _selected = sq; _legalMoves = _getMoves(idx); });
    } else {
      if (_legalMoves.contains(sq)) {
        // Make move
        HapticFeedback.mediumImpact();
        final newBoard = List<String>.from(_board);
        final fromIdx = _sqIndex(_selected!);
        final captured = newBoard[idx];
        newBoard[idx] = newBoard[fromIdx];
        newBoard[fromIdx] = '';
        // Pawn promotion
        if (newBoard[idx] == 'wP' && idx < 8) newBoard[idx] = 'wQ';
        if (newBoard[idx] == 'bP' && idx >= 56) newBoard[idx] = 'bQ';

        setState(() { _board = newBoard; _selected = null; _legalMoves = []; _moveNumber++; });

        final opponentId = _isCreator ? widget.match['opponent_id'] : widget.match['creator_id'];
        await ArenaService.updateGameState(widget.match['id'], {'board': newBoard}, nextTurn: opponentId as String);
        await ArenaService.submitMove(widget.match['id'], {'from': _selected, 'to': sq, 'captured': captured}, _moveNumber);

        // Check if king was captured
        if (captured == 'wK') { await widget.onWinner(_isCreator ? widget.match['opponent_id'] as String : widget.myId); }
        if (captured == 'bK') { await widget.onWinner(_isCreator ? widget.myId : widget.match['opponent_id'] as String); }
      } else {
        // Reselect or deselect
        if (piece.isNotEmpty && _isMyPiece(piece)) {
          setState(() { _selected = sq; _legalMoves = _getMoves(idx); });
        } else {
          setState(() { _selected = null; _legalMoves = []; });
        }
      }
    }
  }

  static const _pieceEmoji = {
    'wK': '♔', 'wQ': '♕', 'wR': '♖', 'wB': '♗', 'wN': '♘', 'wP': '♙',
    'bK': '♚', 'bQ': '♛', 'bR': '♜', 'bB': '♝', 'bN': '♞', 'bP': '♟',
  };

  @override
  Widget build(BuildContext context) {
    // Flip board for black player
    final displayBoard = _isWhite ? _board : _board.reversed.toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(_isWhite ? 'You play White ♔' : 'You play Black ♚', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 14, color: GacomColors.txtPrimary(context))),
          Text(_myTurn ? 'YOUR TURN' : 'Waiting...', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: _myTurn ? GacomColors.deepOrange : GacomColors.txtMuted(context))),
        ]),
      ),
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: AspectRatio(aspectRatio: 1, child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
          itemCount: 64,
          itemBuilder: (_, displayIdx) {
            final boardIdx = _isWhite ? displayIdx : 63 - displayIdx;
            final sq = _sqName(boardIdx);
            final piece = displayBoard[displayIdx];
            final row = displayIdx ~/ 8;
            final col = displayIdx % 8;
            final isLight = (row + col) % 2 == 0;
            final isSelected = _selected == sq;
            final isLegal = _legalMoves.contains(sq);
            Color squareColor = isLight ? const Color(0xFFF0D9B5) : const Color(0xFFB58863);
            if (isSelected) squareColor = GacomColors.deepOrange.withOpacity(0.6);
            if (isLegal) squareColor = GacomColors.success.withOpacity(0.5);

            return GestureDetector(
              onTap: () => _onSquareTap(boardIdx),
              child: Container(
                color: squareColor,
                child: Stack(children: [
                  if (isLegal && piece.isEmpty) Center(child: Container(width: 14, height: 14, decoration: BoxDecoration(color: GacomColors.success.withOpacity(0.7), shape: BoxShape.circle))),
                  if (piece.isNotEmpty) Center(child: Text(_pieceEmoji[piece] ?? '', style: const TextStyle(fontSize: 22))),
                ]),
              ),
            );
          },
        )),
      )),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton.icon(
            onPressed: () async { await widget.onWinner(_isCreator ? widget.match['opponent_id'] as String : widget.match['creator_id'] as String); },
            icon: const Icon(Icons.flag_rounded, size: 16, color: GacomColors.error),
            label: const Text('Resign', style: TextStyle(color: GacomColors.error, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ]);
  }
}
