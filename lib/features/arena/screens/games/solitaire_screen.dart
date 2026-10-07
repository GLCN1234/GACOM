import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/playing_card.dart';
import '../../../../core/services/duel_session.dart';

class SCard {
  final PlayingCard card;
  bool up;
  SCard(this.card, this.up);
  SCard copy() => SCard(card, up);
}

class SolState {
  List<List<SCard>> tab;
  List<SCard> stock;
  List<SCard> waste;
  List<List<PlayingCard>> found; // indexed by Suit.index
  int score;
  int moves;
  SolState(this.tab, this.stock, this.waste, this.found, this.score, this.moves);

  SolState clone() => SolState(
    [for (final col in tab) [for (final c in col) c.copy()]],
    [for (final c in stock) c.copy()],
    [for (final c in waste) c.copy()],
    [for (final f in found) List<PlayingCard>.from(f)],
    score,
    moves,
  );
}

/// Klondike rules. Every move function checks the move first and only
/// changes the state when it is legal, returning true on success.
class Sol {
  static SolState deal(Random rng) {
    final deck = buildDeck()..shuffle(rng);
    final tab = <List<SCard>>[];
    int k = 0;
    for (int i = 0; i < 7; i++) {
      final col = <SCard>[];
      for (int j = 0; j <= i; j++) { col.add(SCard(deck[k++], j == i)); }
      tab.add(col);
    }
    final stock = <SCard>[for (int i = k; i < deck.length; i++) SCard(deck[i], false)];
    return SolState(tab, stock, <SCard>[], [for (int i = 0; i < 4; i++) <PlayingCard>[]], 0, 0);
  }

  static bool fitsTableau(PlayingCard c, List<SCard> col) {
    if (col.isEmpty) return c.rank == 13;
    final t = col.last.card;
    return t.isRed != c.isRed && t.rank == c.rank + 1;
  }

  static bool fitsFoundation(PlayingCard c, SolState s) {
    final pile = s.found[c.suit.index];
    return pile.isEmpty ? c.rank == 1 : pile.last.rank == c.rank - 1;
  }

  static void _flip(SolState s, int col) {
    if (s.tab[col].isNotEmpty && !s.tab[col].last.up) {
      s.tab[col].last.up = true;
      s.score += 5;
    }
  }

  static bool draw(SolState s, int n) {
    if (s.stock.isNotEmpty) {
      final take = min(n, s.stock.length);
      for (int i = 0; i < take; i++) {
        final c = s.stock.removeLast();
        c.up = true;
        s.waste.add(c);
      }
      return true;
    }
    if (s.waste.isNotEmpty) {
      final back = s.waste.reversed.toList();
      s.waste = <SCard>[];
      for (final c in back) { c.up = false; }
      s.stock = back;
      return true;
    }
    return false;
  }

  static bool wasteToTableau(SolState s, int to) {
    if (s.waste.isEmpty) return false;
    final c = s.waste.last;
    if (!fitsTableau(c.card, s.tab[to])) return false;
    s.waste.removeLast();
    s.tab[to].add(c);
    s.score += 5;
    return true;
  }

  static bool wasteToFoundation(SolState s) {
    if (s.waste.isEmpty) return false;
    final c = s.waste.last;
    if (!fitsFoundation(c.card, s)) return false;
    s.waste.removeLast();
    s.found[c.card.suit.index].add(c.card);
    s.score += 10;
    return true;
  }

  static bool tableauToTableau(SolState s, int from, int idx, int to) {
    if (from == to) return false;
    final col = s.tab[from];
    if (idx < 0 || idx >= col.length || !col[idx].up) return false;
    if (!fitsTableau(col[idx].card, s.tab[to])) return false;
    final moving = col.sublist(idx);
    col.removeRange(idx, col.length);
    s.tab[to].addAll(moving);
    _flip(s, from);
    return true;
  }

  static bool tableauToFoundation(SolState s, int from) {
    final col = s.tab[from];
    if (col.isEmpty || !col.last.up) return false;
    final c = col.last;
    if (!fitsFoundation(c.card, s)) return false;
    col.removeLast();
    s.found[c.card.suit.index].add(c.card);
    s.score += 10;
    _flip(s, from);
    return true;
  }

  static bool foundationToTableau(SolState s, int suit, int to) {
    final pile = s.found[suit];
    if (pile.isEmpty) return false;
    final c = pile.last;
    if (!fitsTableau(c, s.tab[to])) return false;
    pile.removeLast();
    s.tab[to].add(SCard(c, true));
    s.score = max(0, s.score - 15);
    return true;
  }

  static bool autoStep(SolState s) {
    if (wasteToFoundation(s)) return true;
    for (int c = 0; c < 7; c++) {
      if (tableauToFoundation(s, c)) return true;
    }
    return false;
  }

  static bool isWon(SolState s) => s.found.every((f) => f.length == 13);
}

class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({super.key});
  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> {
  final Random _rng = duelRandom();
  SolState? _s;
  final List<SolState> _undo = <SolState>[];
  int _draw = 1;
  int _selKind = 0; // 0 none, 1 waste, 2 tableau, 3 foundation
  int _selCol = -1;
  int _selIdx = -1;
  bool _won = false;
  bool _saved = false;
  bool _auto = false;
  int _epoch = 0;

  void _clearSel() {
    _selKind = 0;
    _selCol = -1;
    _selIdx = -1;
  }

  void _deal() {
    setState(() {
      _epoch++;
      _s = Sol.deal(_rng);
      _undo.clear();
      _clearSel();
      _won = false;
      _saved = false;
      _auto = false;
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _s = null;
      _undo.clear();
      _clearSel();
      _auto = false;
    });
  }

  bool _attempt(bool Function(SolState) action) {
    final s = _s;
    if (s == null || _won) return false;
    final snap = s.clone();
    final ok = action(s);
    if (ok) {
      _undo.add(snap);
      if (_undo.length > 300) { _undo.removeAt(0); }
      s.moves++;
      SoundService.instance.playCardFlip();
      _clearSel();
      if (Sol.isWon(s)) { _win(s); }
    }
    setState(() {});
    return ok;
  }

  void _win(SolState s) {
    _won = true;
    if (!_saved) {
      _saved = true;
      GameScoreService.save(gameName: 'Solitaire', score: s.score + 100, won: true);
    }
    SoundService.instance.playWin();
  }

  void _undoMove() {
    if (_undo.isEmpty || _won) return;
    setState(() {
      _s = _undo.removeLast();
      _clearSel();
    });
  }

  bool get _canAuto {
    final s = _s;
    if (s == null || _won || _auto) return false;
    if (s.stock.isNotEmpty || s.waste.isNotEmpty) return false;
    for (final col in s.tab) {
      for (final c in col) {
        if (!c.up) return false;
      }
    }
    return true;
  }

  Future<void> _autoFinish() async {
    final epoch = _epoch;
    setState(() => _auto = true);
    while (mounted && epoch == _epoch && _s != null && !_won) {
      final s = _s!;
      final snap = s.clone();
      if (!Sol.autoStep(s)) break;
      _undo.add(snap);
      s.moves++;
      SoundService.instance.playCardFlip();
      if (Sol.isWon(s)) { _win(s); }
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 110));
    }
    if (mounted && epoch == _epoch) { setState(() => _auto = false); }
  }

  void _tapStock() {
    _attempt((s) => Sol.draw(s, _draw));
  }

  void _tapWaste() {
    final s = _s;
    if (s == null || s.waste.isEmpty || _won) return;
    if (_selKind == 1) {
      if (!_attempt((st) => Sol.wasteToFoundation(st))) { setState(_clearSel); }
    } else {
      setState(() {
        _selKind = 1;
        _selCol = -1;
        _selIdx = -1;
      });
    }
  }

  bool _moveSelectionTo(int col) {
    if (_selKind == 1) return _attempt((s) => Sol.wasteToTableau(s, col));
    if (_selKind == 2) return _attempt((s) => Sol.tableauToTableau(s, _selCol, _selIdx, col));
    if (_selKind == 3) return _attempt((s) => Sol.foundationToTableau(s, _selCol, col));
    return false;
  }

  void _tapTableau(int col, int idx) {
    final s = _s;
    if (s == null || _won) return;
    final card = s.tab[col][idx];
    if (!card.up) return;
    if (_selKind != 0) {
      if (_moveSelectionTo(col)) return;
      if (_selKind == 2 && _selCol == col && _selIdx == idx) {
        if (idx == s.tab[col].length - 1 && _attempt((st) => Sol.tableauToFoundation(st, col))) return;
        setState(_clearSel);
        return;
      }
    }
    setState(() {
      _selKind = 2;
      _selCol = col;
      _selIdx = idx;
    });
  }

  void _tapEmptyColumn(int col) {
    if (_selKind != 0) { _moveSelectionTo(col); }
  }

  void _tapFoundation(int f) {
    final s = _s;
    if (s == null || _won) return;
    if (_selKind == 1) {
      if (!_attempt((st) => Sol.wasteToFoundation(st))) { setState(_clearSel); }
    } else if (_selKind == 2) {
      final col = s.tab[_selCol];
      if (_selIdx == col.length - 1 && _attempt((st) => Sol.tableauToFoundation(st, _selCol))) return;
      setState(_clearSel);
    } else if (s.found[f].isNotEmpty) {
      setState(() {
        _selKind = 3;
        _selCol = f;
        _selIdx = -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    return HowToPlayOverlay(
      gameKey: 'solitaire',
      title: 'HOW TO PLAY SOLITAIRE',
      steps: const [
        HowToPlayStep(icon: Icons.flag_rounded, title: 'The goal', description: 'Build all four suits up from Ace to King in the four piles at the top right.'),
        HowToPlayStep(icon: Icons.swap_vert_rounded, title: 'Build down in alternating colours', description: 'On the table, place a card on one that is one rank higher and the opposite colour. Only a King can go in an empty column.'),
        HowToPlayStep(icon: Icons.touch_app_rounded, title: 'Tap to move', description: 'Tap a card, then tap where it should go. Tap the same card again to send it up to its suit pile.'),
        HowToPlayStep(icon: Icons.layers_rounded, title: 'The stock', description: 'Tap the stock to turn over new cards. When it runs out, tap it again to recycle the waste pile. UNDO takes back your last move.'),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF0B3D2A),
        appBar: AppBar(title: const Text('SOLITAIRE')),
        body: s == null ? _setup() : Stack(children: [_board(s), if (_won) _result(s)]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.filter_none_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('SOLITAIRE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Classic Klondike', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 24),
        const Text('CARDS PER DRAW', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final n in [1, 3])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => setState(() => _draw = n),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _draw == n ? GacomColors.deepOrange.withValues(alpha: 0.25) : Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _draw == n ? GacomColors.deepOrange : Colors.white24, width: 1.5),
                  ),
                  child: Text(n == 1 ? 'Draw 1' : 'Draw 3', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: _draw == n ? GacomColors.deepOrange : Colors.white)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: _deal,
            child: const Text('DEAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ),
  );

  Widget _slot(double cw, Widget child, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: cw, height: cw * 1.4, child: child),
  );

  Widget _emptySlot(double cw, {Widget? icon}) => Container(
    width: cw,
    height: cw * 1.4,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(cw * 0.1),
      border: Border.all(color: Colors.white24, width: 1.5),
      color: Colors.black12,
    ),
    child: Center(child: icon),
  );

  Widget _column(SolState s, int col, double cw) {
    final cards = s.tab[col];
    final ch = cw * 1.4;
    if (cards.isEmpty) {
      return GestureDetector(onTap: () => _tapEmptyColumn(col), child: _emptySlot(cw));
    }
    final down = cw * 0.18;
    final up = cw * 0.36;
    double y = 0;
    double lastTop = 0;
    final kids = <Widget>[];
    for (int i = 0; i < cards.length; i++) {
      final c = cards[i];
      lastTop = y;
      kids.add(Positioned(
        left: 0,
        top: y,
        child: PlayingCardView(
          card: c.card,
          faceUp: c.up,
          width: cw,
          selected: _selKind == 2 && _selCol == col && i >= _selIdx,
          onTap: () => _tapTableau(col, i),
        ),
      ));
      y += c.up ? up : down;
    }
    return SizedBox(width: cw, height: lastTop + ch, child: Stack(clipBehavior: Clip.none, children: kids));
  }

  Widget _board(SolState s) {
    return LayoutBuilder(builder: (context, cons) {
      const gap = 4.0;
      final cw = (cons.maxWidth - 16 - gap * 6) / 7;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('Score ${s.score}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(width: 14),
            Text('Moves ${s.moves}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const Spacer(),
            _mini('UNDO', _undo.isNotEmpty && !_auto ? _undoMove : null),
            const SizedBox(width: 6),
            if (_canAuto) _mini('AUTO', _autoFinish),
            if (_canAuto) const SizedBox(width: 6),
            _mini('NEW', _toSetup),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            s.stock.isNotEmpty
                ? _slot(cw, PlayingCardView(faceUp: false, width: cw), _tapStock)
                : _slot(cw, _emptySlot(cw, icon: const Icon(Icons.refresh_rounded, color: Colors.white54)), _tapStock),
            const SizedBox(width: gap),
            s.waste.isNotEmpty
                ? _slot(cw, PlayingCardView(card: s.waste.last.card, width: cw, selected: _selKind == 1), _tapWaste)
                : _slot(cw, _emptySlot(cw), null),
            const SizedBox(width: gap),
            SizedBox(width: cw),
            for (int f = 0; f < 4; f++) ...[
              const SizedBox(width: gap),
              _slot(
                cw,
                s.found[f].isNotEmpty
                    ? PlayingCardView(card: s.found[f].last, width: cw, selected: _selKind == 3 && _selCol == f)
                    : _emptySlot(cw, icon: SizedBox(width: cw * 0.45, height: cw * 0.45, child: CustomPaint(painter: SuitPainter(Suit.values[f], Colors.white24)))),
                () => _tapFoundation(f),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (int c = 0; c < 7; c++) ...[
              if (c > 0) const SizedBox(width: gap),
              _column(s, c, cw),
            ],
          ]),
        ]),
      );
    });
  }

  Widget _mini(String label, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: onTap == null ? Colors.black12 : Colors.black38, borderRadius: BorderRadius.circular(50), border: Border.all(color: Colors.white24)),
      child: Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: onTap == null ? Colors.white30 : Colors.white)),
    ),
  );

  Widget _result(SolState s) => Container(
    color: Colors.black.withValues(alpha: 0.8),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 52),
          const SizedBox(height: 12),
          const Text('YOU WIN!', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text('Score ${s.score + 100} in ${s.moves} moves', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _toSetup,
              child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    ),
  );
}
