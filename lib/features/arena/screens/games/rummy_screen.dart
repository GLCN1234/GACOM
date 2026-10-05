import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../widgets/playing_card.dart';

/// A group of cards on the table: a set (same rank, different suits)
/// or a run (same suit, consecutive ranks). Runs are kept in sequence
/// order, with an Ace either first (low) or last (high).
class Meld {
  final bool isSet;
  List<PlayingCard> cards;
  Meld(this.isSet, this.cards);
}

class AiSummary {
  final bool tookDiscard;
  final PlayingCard? drawn;
  final int melded;
  final int laidOff;
  final PlayingCard? discarded;
  const AiSummary(this.tookDiscard, this.drawn, this.melded, this.laidOff, this.discarded);
}

class Rummy {
  static int value(PlayingCard c) => c.rank >= 10 ? 10 : c.rank; // Ace = 1
  static int handValue(List<PlayingCard> h) {
    int t = 0;
    for (final c in h) { t += value(c); }
    return t;
  }

  static bool isValidSet(List<PlayingCard> cs) {
    if (cs.length < 3 || cs.length > 4) return false;
    final r = cs.first.rank;
    final suits = <Suit>{};
    for (final c in cs) {
      if (c.rank != r) return false;
      if (!suits.add(c.suit)) return false;
    }
    return true;
  }

  /// The run in sequence order, or null. Ace may be low (A-2-3) or high
  /// (Q-K-A) but a run cannot wrap around (K-A-2 is not a run).
  static List<PlayingCard>? asRun(List<PlayingCard> cs) {
    if (cs.length < 3) return null;
    final suit = cs.first.suit;
    for (final c in cs) {
      if (c.suit != suit) return null;
    }
    for (final aceHigh in const [false, true]) {
      int v(PlayingCard c) => (c.rank == 1 && aceHigh) ? 14 : c.rank;
      final sorted = List<PlayingCard>.from(cs)..sort((a, b) => v(a).compareTo(v(b)));
      bool ok = true;
      for (int i = 1; i < sorted.length; i++) {
        if (v(sorted[i]) != v(sorted[i - 1]) + 1) {
          ok = false;
          break;
        }
      }
      if (ok) return sorted;
    }
    return null;
  }

  static int _vAt(Meld m, int i) {
    final c = m.cards[i];
    if (c.rank == 1) return i == 0 ? 1 : 14;
    return c.rank;
  }

  /// 0 = the card extends the run at the start, 1 = at the end, -1 = no.
  static int runExtendPos(Meld m, PlayingCard c) {
    if (c.suit != m.cards.first.suit) return -1;
    final low = _vAt(m, 0);
    final high = _vAt(m, m.cards.length - 1);
    if (low > 1 && c.rank == low - 1) return 0;
    if (high < 14) {
      final nv = high + 1;
      if (nv == 14 ? c.rank == 1 : c.rank == nv) return 1;
    }
    return -1;
  }

  static bool canLayOff(Meld m, PlayingCard c) {
    if (m.isSet) {
      if (m.cards.length >= 4) return false;
      if (c.rank != m.cards.first.rank) return false;
      return !m.cards.any((x) => x.suit == c.suit);
    }
    return runExtendPos(m, c) != -1;
  }

  static void layOff(Meld m, PlayingCard c) {
    if (m.isSet) {
      m.cards.add(c);
      return;
    }
    final pos = runExtendPos(m, c);
    if (pos == 0) {
      m.cards.insert(0, c);
    } else if (pos == 1) {
      m.cards.add(c);
    }
  }

  /// Every valid meld that can be formed from [hand], as lists of hand indices.
  static List<List<int>> candidateMelds(List<PlayingCard> hand) {
    final out = <List<int>>[];
    for (int rank = 1; rank <= 13; rank++) {
      final idx = <int>[for (int i = 0; i < hand.length; i++) if (hand[i].rank == rank) i];
      if (idx.length < 3) continue;
      for (int a = 0; a < idx.length; a++) {
        for (int b = a + 1; b < idx.length; b++) {
          for (int c = b + 1; c < idx.length; c++) {
            out.add([idx[a], idx[b], idx[c]]);
            for (int d = c + 1; d < idx.length; d++) {
              out.add([idx[a], idx[b], idx[c], idx[d]]);
            }
          }
        }
      }
    }
    for (final suit in Suit.values) {
      final byRank = <int, int>{};
      for (int i = 0; i < hand.length; i++) {
        if (hand[i].suit == suit) { byRank[hand[i].rank] = i; }
      }
      for (int start = 1; start <= 14; start++) {
        final seq = <int>[];
        for (int v = start; v <= 14; v++) {
          final rank = v == 14 ? 1 : v;
          final idx = byRank[rank];
          if (idx == null || seq.contains(idx)) break;
          seq.add(idx);
          if (seq.length >= 3) { out.add(List<int>.from(seq)); }
        }
      }
    }
    return out;
  }

  /// The split of [hand] into non-overlapping melds that covers the
  /// most card value, as lists of hand indices.
  static List<List<int>> bestMelds(List<PlayingCard> hand) {
    final cands = candidateMelds(hand);
    final masks = <int>[];
    final vals = <int>[];
    for (final c in cands) {
      int m = 0;
      int v = 0;
      for (final i in c) {
        m |= (1 << i);
        v += value(hand[i]);
      }
      masks.add(m);
      vals.add(v);
    }
    final memo = <int, int>{};
    final choice = <int, int>{};
    int solve(int free) {
      if (free == 0) return 0;
      final cached = memo[free];
      if (cached != null) return cached;
      int low = 0;
      while (((free >> low) & 1) == 0) { low++; }
      int best = solve(free & ~(1 << low));
      int bestIdx = -1;
      for (int k = 0; k < masks.length; k++) {
        final m = masks[k];
        if ((m & (1 << low)) != 0 && (m & free) == m) {
          final v = vals[k] + solve(free & ~m);
          if (v > best) {
            best = v;
            bestIdx = k;
          }
        }
      }
      memo[free] = best;
      choice[free] = bestIdx;
      return best;
    }
    final all = (1 << hand.length) - 1;
    solve(all);
    final result = <List<int>>[];
    int free = all;
    while (free != 0) {
      int low = 0;
      while (((free >> low) & 1) == 0) { low++; }
      final k = choice[free] ?? -1;
      if (k == -1) {
        free &= ~(1 << low);
      } else {
        result.add(cands[k]);
        free &= ~masks[k];
      }
    }
    return result;
  }

  static int meldedValue(List<PlayingCard> hand) {
    int t = 0;
    for (final m in bestMelds(hand)) {
      for (final i in m) { t += value(hand[i]); }
    }
    return t;
  }

  static int _dist(PlayingCard a, PlayingCard b) {
    int d = (a.rank - b.rank).abs();
    if (a.rank == 1) { d = min(d, (14 - b.rank).abs()); }
    if (b.rank == 1) { d = min(d, (14 - a.rank).abs()); }
    return d;
  }

  /// The card least likely to help: few partners and a high value.
  static PlayingCard chooseDiscard(List<PlayingCard> hand, PlayingCard? avoid) {
    PlayingCard best = hand.first;
    int bestKey = 1 << 30;
    for (final c in hand) {
      if (avoid != null && hand.length > 1 && c == avoid) continue;
      int partners = 0;
      for (final o in hand) {
        if (o == c) continue;
        if (o.rank == c.rank) { partners += 3; }
        if (o.suit == c.suit) {
          final d = _dist(c, o);
          if (d == 1) { partners += 2; }
          if (d == 2) { partners += 1; }
        }
      }
      final key = partners * 10 - value(c);
      if (key < bestKey) {
        bestKey = key;
        best = c;
      }
    }
    return best;
  }
}

class RummyGame {
  final Random rng;
  List<PlayingCard> stock = <PlayingCard>[];
  List<PlayingCard> discard = <PlayingCard>[];
  List<PlayingCard> hand = <PlayingCard>[];
  List<PlayingCard> aiHand = <PlayingCard>[];
  List<Meld> myMelds = <Meld>[];
  List<Meld> aiMelds = <Meld>[];
  int winner = 0; // 0 none, 1 human, 2 AI, 3 draw
  int turns = 0;

  RummyGame(this.rng) {
    final deck = buildDeck()..shuffle(rng);
    for (int i = 0; i < 10; i++) {
      hand.add(deck.removeLast());
      aiHand.add(deck.removeLast());
    }
    discard.add(deck.removeLast());
    stock = deck;
  }

  PlayingCard? drawStock() {
    if (stock.isEmpty) {
      if (discard.length <= 1) return null;
      final top = discard.removeLast();
      stock = List<PlayingCard>.from(discard)..shuffle(rng);
      discard = [top];
    }
    return stock.removeLast();
  }

  /// Lays the cards at [idxs] of the human hand down as a new meld.
  bool meldFromHand(List<int> idxs) {
    final cards = <PlayingCard>[for (final i in idxs) hand[i]];
    if (Rummy.isValidSet(cards)) {
      myMelds.add(Meld(true, cards));
    } else {
      final run = Rummy.asRun(cards);
      if (run == null) return false;
      myMelds.add(Meld(false, run));
    }
    for (final c in cards) { hand.remove(c); }
    return true;
  }

  bool _wantsDiscard(List<PlayingCard> h, PlayingCard top, List<Meld> table) {
    for (final m in table) {
      if (Rummy.canLayOff(m, top)) return true;
    }
    return Rummy.meldedValue([...h, top]) > Rummy.meldedValue(h);
  }

  /// A complete AI turn: draw, lay down melds, lay off, discard.
  AiSummary aiTurn({bool forHuman = false}) {
    final h = forHuman ? hand : aiHand;
    final own = forHuman ? myMelds : aiMelds;
    final other = forHuman ? aiMelds : myMelds;
    turns++;
    PlayingCard? drawn;
    bool took = false;
    if (discard.isNotEmpty && _wantsDiscard(h, discard.last, [...own, ...other])) {
      drawn = discard.removeLast();
      took = true;
    } else {
      drawn = drawStock();
    }
    if (drawn == null) {
      winner = 3;
      return const AiSummary(false, null, 0, 0, null);
    }
    h.add(drawn);
    final plan = Rummy.bestMelds(h);
    final groups = <List<PlayingCard>>[for (final idxs in plan) [for (final i in idxs) h[i]]];
    int melded = 0;
    for (final g in groups) {
      final isSet = Rummy.isValidSet(g);
      own.add(Meld(isSet, isSet ? g : Rummy.asRun(g)!));
      for (final c in g) { h.remove(c); }
      melded += g.length;
    }
    int laid = 0;
    bool progress = true;
    while (progress) {
      progress = false;
      for (final c in List<PlayingCard>.from(h)) {
        for (final m in [...own, ...other]) {
          if (Rummy.canLayOff(m, c)) {
            Rummy.layOff(m, c);
            h.remove(c);
            laid++;
            progress = true;
            break;
          }
        }
      }
    }
    if (h.isEmpty) {
      winner = forHuman ? 1 : 2;
      return AiSummary(took, drawn, melded, laid, null);
    }
    final d = Rummy.chooseDiscard(h, took ? drawn : null);
    h.remove(d);
    discard.add(d);
    if (h.isEmpty) { winner = forHuman ? 1 : 2; }
    return AiSummary(took, drawn, melded, laid, d);
  }
}

class RummyScreen extends StatefulWidget {
  const RummyScreen({super.key});
  @override
  State<RummyScreen> createState() => _RummyScreenState();
}

class _RummyScreenState extends State<RummyScreen> {
  final Random _rng = Random();
  RummyGame? _g;
  int _phase = 0; // 0 draw, 1 act, 2 AI turn, 3 over
  final Set<int> _sel = <int>{};
  String _msg = '';
  bool _bySuit = true;
  bool _saved = false;
  bool _stalemate = false;
  int _epoch = 0;

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  void _start() {
    setState(() {
      _epoch++;
      _g = RummyGame(_rng);
      _phase = 0;
      _sel.clear();
      _saved = false;
      _stalemate = false;
      _msg = 'Your turn - draw a card';
      _sortHand();
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _g = null;
      _phase = 0;
      _sel.clear();
    });
  }

  void _sortHand() {
    final g = _g;
    if (g == null) return;
    g.hand.sort((a, b) {
      if (_bySuit) {
        final s = a.suit.index.compareTo(b.suit.index);
        return s != 0 ? s : a.rank.compareTo(b.rank);
      }
      final r = a.rank.compareTo(b.rank);
      return r != 0 ? r : a.suit.index.compareTo(b.suit.index);
    });
  }

  void _drawFrom(bool fromDiscard) {
    final g = _g;
    if (g == null || _phase != 0) return;
    PlayingCard? c;
    if (fromDiscard) {
      if (g.discard.isEmpty) return;
      c = g.discard.removeLast();
    } else {
      c = g.drawStock();
    }
    if (c == null) {
      _finish(3);
      return;
    }
    SoundService.instance.playCardFlip();
    setState(() {
      g.hand.add(c!);
      _sortHand();
      _sel.clear();
      _phase = 1;
      _msg = 'Meld, lay off, then discard one card';
    });
  }

  void _toggle(int i) {
    if (_phase != 1) return;
    setState(() {
      if (!_sel.remove(i)) { _sel.add(i); }
    });
  }

  List<PlayingCard> _selectedCards() {
    final g = _g!;
    final idx = _sel.toList()..sort();
    return [for (final i in idx) g.hand[i]];
  }

  bool get _canMeld {
    if (_phase != 1 || _sel.length < 3) return false;
    final cards = _selectedCards();
    return Rummy.isValidSet(cards) || Rummy.asRun(cards) != null;
  }

  void _meld() {
    final g = _g;
    if (g == null || !_canMeld) return;
    final idx = _sel.toList()..sort();
    final ok = g.meldFromHand(idx);
    if (!ok) return;
    SoundService.instance.playCorrect();
    setState(() {
      _sel.clear();
      _msg = 'Meld laid down';
    });
    _checkOut();
  }

  void _layOffOnto(Meld m) {
    final g = _g;
    if (g == null || _phase != 1 || _sel.isEmpty) return;
    final remaining = _selectedCards();
    int placed = 0;
    bool progress = true;
    while (progress && remaining.isNotEmpty) {
      progress = false;
      for (final c in List<PlayingCard>.from(remaining)) {
        if (Rummy.canLayOff(m, c)) {
          Rummy.layOff(m, c);
          remaining.remove(c);
          g.hand.remove(c);
          placed++;
          progress = true;
        }
      }
    }
    setState(() {
      _sel.clear();
      _msg = placed > 0 ? 'Laid off $placed card${placed > 1 ? 's' : ''}' : 'Those cards do not fit that meld';
    });
    if (placed > 0) {
      SoundService.instance.playCorrect();
      _checkOut();
    }
  }

  void _checkOut() {
    final g = _g;
    if (g != null && g.hand.isEmpty) { _finish(1); }
  }

  void _discardSelected() {
    final g = _g;
    if (g == null || _phase != 1 || _sel.length != 1) return;
    final card = g.hand[_sel.first];
    g.hand.remove(card);
    g.discard.add(card);
    SoundService.instance.playCardFlip();
    setState(() => _sel.clear());
    if (g.hand.isEmpty) {
      _finish(1);
      return;
    }
    _aiPlay();
  }

  Future<void> _aiPlay() async {
    final g = _g;
    if (g == null) return;
    final epoch = _epoch;
    setState(() {
      _phase = 2;
      _msg = 'AI is thinking...';
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (_dead(epoch)) return;
    final s = g.aiTurn();
    if (g.winner == 3) {
      _finish(3);
      return;
    }
    final parts = <String>[s.tookDiscard ? 'AI took your discard' : 'AI drew from the stock'];
    if (s.melded > 0) { parts.add('melded ${s.melded}'); }
    if (s.laidOff > 0) { parts.add('laid off ${s.laidOff}'); }
    if (s.discarded != null) { parts.add('discarded ${s.discarded}'); }
    SoundService.instance.playCardFlip();
    setState(() => _msg = parts.join(', '));
    if (g.winner == 2) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (_dead(epoch)) return;
      _finish(2);
      return;
    }
    if (g.turns >= 40) {
      // A rare deadlock where neither side can go out: lowest hand wins.
      _stalemate = true;
      _finish(Rummy.handValue(g.hand) <= Rummy.handValue(g.aiHand) ? 1 : 2);
      return;
    }
    setState(() {
      _phase = 0;
      _sel.clear();
      _msg = '${parts.join(', ')}. Your turn - draw a card';
    });
  }

  void _finish(int winner) {
    final g = _g;
    if (g == null) return;
    g.winner = winner;
    if (!_saved) {
      _saved = true;
      final won = winner == 1 ? true : (winner == 2 ? false : null);
      final score = winner == 1 ? Rummy.handValue(g.aiHand) + 20 : 0;
      GameScoreService.save(gameName: 'Rummy', score: score, won: won);
    }
    if (winner == 1) {
      SoundService.instance.playWin();
    } else if (winner == 2) {
      SoundService.instance.playLose();
    }
    setState(() => _phase = 3);
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return HowToPlayOverlay(
      gameKey: 'rummy',
      title: 'HOW TO PLAY RUMMY',
      steps: const [
        HowToPlayStep(icon: Icons.layers_rounded, title: 'Draw', description: 'Each turn, draw the top card of the stock, or take the top card of the discard pile.'),
        HowToPlayStep(icon: Icons.view_agenda_rounded, title: 'Meld', description: 'Select 3 or more cards and tap MELD. A set is the same number in different suits. A run is 3 or more in a row in one suit (Ace can be low or high).'),
        HowToPlayStep(icon: Icons.add_circle_outline_rounded, title: 'Lay off', description: 'Select cards and tap a meld on the table (yours or the AI) to add cards that extend it.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Go out', description: 'End each turn by discarding one card. Get rid of all your cards first to win and score the points left in the AI hand.'),
      ],
      child: Scaffold(
        backgroundColor: GacomColors.obsidian,
        appBar: AppBar(title: const Text('RUMMY')),
        body: g == null ? _setup() : Stack(children: [_table(g), if (_phase == 3) _result(g)]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.style_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('RUMMY', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        const Text('Form sets and runs, then go out first', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: _start,
            child: const Text('DEAL', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(t, style: const TextStyle(color: GacomColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
  );

  Widget _meldRow(Meld m) {
    final target = _phase == 1 && _sel.isNotEmpty;
    return GestureDetector(
      onTap: target ? () => _layOffOnto(m) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: GacomColors.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: target ? GacomColors.deepOrange : GacomColors.border, width: target ? 2 : 1),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final c in m.cards) Padding(padding: const EdgeInsets.only(right: 2), child: PlayingCardView(card: c, width: 32)),
          ]),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback? onTap) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, disabledBackgroundColor: GacomColors.cardDark, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)),
  );

  Widget _table(RummyGame g) {
    final acting = _phase == 1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label('AI HAND (${g.aiHand.length} cards)'),
        Wrap(spacing: 2, runSpacing: 2, children: [for (int i = 0; i < g.aiHand.length; i++) PlayingCardView(faceUp: false, width: 22)]),
        const SizedBox(height: 10),
        _label('AI MELDS'),
        if (g.aiMelds.isEmpty) const Text('none yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        for (final m in g.aiMelds) _meldRow(m),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: [
            _label('STOCK (${g.stock.length})'),
            PlayingCardView(faceUp: false, width: 56, onTap: _phase == 0 ? () => _drawFrom(false) : null),
          ]),
          const SizedBox(width: 24),
          Column(children: [
            _label('DISCARD'),
            g.discard.isEmpty
                ? Container(width: 56, height: 78, decoration: BoxDecoration(border: Border.all(color: GacomColors.border), borderRadius: BorderRadius.circular(6)))
                : PlayingCardView(card: g.discard.last, width: 56, onTap: _phase == 0 ? () => _drawFrom(true) : null),
          ]),
        ]),
        const SizedBox(height: 6),
        Center(child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12))),
        const SizedBox(height: 10),
        _label('YOUR MELDS'),
        if (g.myMelds.isEmpty) const Text('none yet', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)),
        for (final m in g.myMelds) _meldRow(m),
        const SizedBox(height: 10),
        _label('YOUR HAND (${g.hand.length} cards)'),
        Wrap(spacing: 4, runSpacing: 6, children: [
          for (int i = 0; i < g.hand.length; i++)
            Transform.translate(
              offset: Offset(0, _sel.contains(i) ? -8 : 0),
              child: PlayingCardView(card: g.hand[i], width: 50, selected: _sel.contains(i), onTap: acting ? () => _toggle(i) : null),
            ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          _btn('MELD', _canMeld ? _meld : null),
          _btn('DISCARD', acting && _sel.length == 1 ? _discardSelected : null),
          _btn(_bySuit ? 'SORT: SUIT' : 'SORT: RANK', () => setState(() {
            _bySuit = !_bySuit;
            _sel.clear();
            _sortHand();
          })),
        ]),
      ]),
    );
  }

  Widget _result(RummyGame g) {
    final won = g.winner == 1;
    final draw = g.winner == 3;
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(26),
          decoration: GacomDecorations.glassCard(context, radius: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(won ? Icons.emoji_events_rounded : (draw ? Icons.sentiment_neutral_rounded : Icons.sentiment_dissatisfied_rounded), color: won ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
            const SizedBox(height: 12),
            Text(won ? (_stalemate ? 'YOU WIN ON POINTS' : 'YOU WENT OUT!') : (draw ? 'DRAW' : (_stalemate ? 'AI WINS ON POINTS' : 'AI WENT OUT')), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
            const SizedBox(height: 6),
            Text(won ? 'You score ${Rummy.handValue(g.aiHand)} points from the AI hand' : 'You were left with ${Rummy.handValue(g.hand)} points', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
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
}
