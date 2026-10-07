import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import '../../widgets/how_to_play_overlay.dart';
import '../../../../core/services/duel_session.dart';

const List<Color> kCcColors = [Color(0xFFE53935), Color(0xFFFBC02D), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF212121)];
const List<String> kCcColorNames = ['Red', 'Yellow', 'Green', 'Blue'];

/// color 0-3 are red, yellow, green, blue; 4 is wild.
/// kind 0-9 are numbers, 10 skip, 11 reverse, 12 draw two, 13 wild, 14 wild draw four.
class CcCard {
  final int color;
  final int kind;
  final int id;
  const CcCard(this.color, this.kind, this.id);
  bool get isWild => kind >= 13;
  bool get isNumber => kind <= 9;
  int get points => isNumber ? kind : (isWild ? 50 : 20);

  String get label {
    if (kind <= 9) return '$kind';
    switch (kind) {
      case 10:
        return 'Skip';
      case 11:
        return 'Reverse';
      case 12:
        return '+2';
      case 13:
        return 'Wild';
      default:
        return 'Wild +4';
    }
  }

  String get fullName => isWild ? label : '${kCcColorNames[color]} $label';
}

List<CcCard> buildCcDeck() {
  final out = <CcCard>[];
  int id = 0;
  for (int c = 0; c < 4; c++) {
    out.add(CcCard(c, 0, id++));
    for (int k = 1; k <= 12; k++) {
      out.add(CcCard(c, k, id++));
      out.add(CcCard(c, k, id++));
    }
  }
  for (int i = 0; i < 4; i++) {
    out.add(CcCard(4, 13, id++));
    out.add(CcCard(4, 14, id++));
  }
  return out;
}

class CcEvent {
  final int victim; // player who had to draw or was skipped, or -1
  final int drew;
  final bool skipped;
  const CcEvent(this.victim, this.drew, this.skipped);
}

class ColorClashEngine {
  final Random rng;
  final int n;
  final List<List<CcCard>> hands = <List<CcCard>>[];
  final List<CcCard> drawPile = <CcCard>[];
  final List<CcCard> discard = <CcCard>[];
  int current = 0;
  int dir = 1;
  int activeColor = 0;
  int winner = -1;

  ColorClashEngine(this.rng, this.n) {
    drawPile.addAll(buildCcDeck());
    drawPile.shuffle(rng);
    for (int p = 0; p < n; p++) { hands.add(<CcCard>[]); }
    for (int i = 0; i < 7; i++) {
      for (int p = 0; p < n; p++) { hands[p].add(drawPile.removeLast()); }
    }
    CcCard c = drawPile.removeLast();
    while (!c.isNumber) {
      drawPile.insert(0, c);
      c = drawPile.removeLast();
    }
    discard.add(c);
    activeColor = c.color;
  }

  CcCard get top => discard.last;

  int step(int from, int steps) => (((from + dir * steps) % n) + n) % n;

  bool canPlay(CcCard c, List<CcCard> hand) {
    if (c.kind == 13) return true;
    if (c.kind == 14) {
      for (final h in hand) {
        if (h.color == activeColor) return false;
      }
      return true;
    }
    return c.color == activeColor || c.kind == top.kind;
  }

  List<CcCard> playable(int p) => [for (final c in hands[p]) if (canPlay(c, hands[p])) c];

  void _reshuffle() {
    if (discard.length <= 1) return;
    final t = discard.removeLast();
    drawPile.addAll(discard);
    discard.clear();
    drawPile.shuffle(rng);
    discard.add(t);
  }

  CcCard? drawOne(int p) {
    if (drawPile.isEmpty) { _reshuffle(); }
    if (drawPile.isEmpty) return null;
    final c = drawPile.removeLast();
    hands[p].add(c);
    return c;
  }

  int _drawInto(int p, int k) {
    int got = 0;
    for (int i = 0; i < k; i++) {
      if (drawOne(p) != null) { got++; }
    }
    return got;
  }

  void pass() {
    current = step(current, 1);
  }

  /// Plays [c] from the current player's hand ([chosen] is the colour for a wild).
  CcEvent play(CcCard c, int chosen) {
    final hand = hands[current];
    hand.remove(c);
    discard.add(c);
    activeColor = c.isWild ? chosen : c.color;
    if (hand.isEmpty) {
      winner = current;
      return const CcEvent(-1, 0, false);
    }
    if (c.kind == 11 && n > 2) { dir = -dir; }
    final victim = step(current, 1);
    if (c.kind == 10 || (c.kind == 11 && n == 2)) {
      current = step(victim, 1);
      return CcEvent(victim, 0, true);
    }
    if (c.kind == 12 || c.kind == 14) {
      final got = _drawInto(victim, c.kind == 12 ? 2 : 4);
      current = step(victim, 1);
      return CcEvent(victim, got, true);
    }
    current = victim;
    return const CcEvent(-1, 0, false);
  }

  int handPoints(int p) {
    int t = 0;
    for (final c in hands[p]) { t += c.points; }
    return t;
  }

  /// The colour that appears most in [hand] (ignoring wilds).
  int bestColor(List<CcCard> hand) {
    final counts = List<int>.filled(4, 0);
    for (final c in hand) {
      if (!c.isWild) { counts[c.color]++; }
    }
    int best = rng.nextInt(4);
    int bestN = -1;
    for (int i = 0; i < 4; i++) {
      if (counts[i] > bestN) {
        bestN = counts[i];
        best = i;
      }
    }
    return best;
  }

  /// A reasonable AI choice among the playable cards.
  CcCard chooseAi(int p) {
    final options = playable(p);
    final hand = hands[p];
    final nextCount = hands[step(p, 1)].length;
    CcCard best = options.first;
    double bestScore = -1e9;
    for (final c in options) {
      double s = rng.nextDouble();
      if (c.kind == 14) { s -= 40; }
      if (c.kind == 13) { s -= 20; }
      if (nextCount <= 2 && (c.kind == 10 || c.kind == 11 || c.kind == 12 || c.kind == 14)) { s += 60; }
      if (c.kind >= 10 && c.kind <= 12) { s += 8; }
      s += c.points * 0.3;
      if (!c.isWild) {
        int same = 0;
        for (final o in hand) {
          if (o != c && o.color == c.color) { same++; }
        }
        s += same * 2.0;
      }
      if (s > bestScore) {
        bestScore = s;
        best = c;
      }
    }
    return best;
  }
}

class ColorClashScreen extends StatefulWidget {
  const ColorClashScreen({super.key});
  @override
  State<ColorClashScreen> createState() => _ColorClashScreenState();
}

class _ColorClashScreenState extends State<ColorClashScreen> {
  final Random _rng = duelRandom();
  ColorClashEngine? _g;
  int _opps = 2;
  bool _busy = false;
  bool _over = false;
  bool _saved = false;
  String _msg = '';
  CcCard? _drawn;
  int _epoch = 0;

  bool _dead(int epoch) => !mounted || epoch != _epoch;

  String _name(int p) => p == 0 ? 'You' : 'AI $p';

  void _sortHand(ColorClashEngine g) {
    g.hands[0].sort((a, b) {
      final c = a.color.compareTo(b.color);
      return c != 0 ? c : a.kind.compareTo(b.kind);
    });
  }

  void _start() {
    final g = ColorClashEngine(_rng, _opps + 1);
    _sortHand(g);
    setState(() {
      _epoch++;
      _g = g;
      _busy = false;
      _over = false;
      _saved = false;
      _drawn = null;
      _msg = 'Your turn';
    });
  }

  void _toSetup() {
    setState(() {
      _epoch++;
      _g = null;
      _over = false;
    });
  }

  void _afterTurn() {
    final g = _g;
    if (g == null || _over) return;
    if (g.current == 0) {
      setState(() {
        _busy = false;
        _drawn = null;
        _msg = g.playable(0).isEmpty ? 'No playable card - draw one' : 'Your turn';
      });
    } else {
      _aiTurn();
    }
  }

  String _describe(int p, CcCard c, CcEvent ev, int chosen) {
    final b = StringBuffer('${_name(p)} played ${c.fullName}');
    if (c.isWild) { b.write(' and chose ${kCcColorNames[chosen]}'); }
    if (ev.victim >= 0) {
      if (ev.drew > 0) {
        b.write('. ${_name(ev.victim)} draws ${ev.drew} and loses a turn');
      } else {
        b.write('. ${_name(ev.victim)} is skipped');
      }
    }
    return b.toString();
  }

  Future<void> _doPlay(int p, CcCard c, int chosen) async {
    final g = _g!;
    final epoch = _epoch;
    final ev = g.play(c, chosen);
    if (p == 0) { _sortHand(g); }
    SoundService.instance.playCardFlip();
    setState(() {
      _busy = true;
      _drawn = null;
      _msg = _describe(p, c, ev, chosen);
    });
    if (g.winner >= 0) {
      _finish(g);
      return;
    }
    await Future.delayed(const Duration(milliseconds: 900));
    if (_dead(epoch)) return;
    _afterTurn();
  }

  Future<void> _aiTurn() async {
    final g = _g!;
    final epoch = _epoch;
    final p = g.current;
    setState(() {
      _busy = true;
      _msg = '${_name(p)} is thinking...';
    });
    await Future.delayed(const Duration(milliseconds: 900));
    if (_dead(epoch)) return;
    if (g.playable(p).isNotEmpty) {
      final c = g.chooseAi(p);
      final chosen = c.isWild ? g.bestColor([for (final h in g.hands[p]) if (h != c) h]) : c.color;
      await _doPlay(p, c, chosen);
      return;
    }
    final drew = g.drawOne(p);
    setState(() => _msg = '${_name(p)} draws a card');
    SoundService.instance.playCardFlip();
    await Future.delayed(const Duration(milliseconds: 700));
    if (_dead(epoch)) return;
    if (drew != null && g.canPlay(drew, g.hands[p])) {
      final chosen = drew.isWild ? g.bestColor([for (final h in g.hands[p]) if (h != drew) h]) : drew.color;
      await _doPlay(p, drew, chosen);
    } else {
      g.pass();
      _afterTurn();
    }
  }

  Future<int?> _pickColor() {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GacomColors.cardDark,
        title: const Text('Choose a colour', style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
        content: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          for (int i = 0; i < 4; i++)
            GestureDetector(
              onTap: () => Navigator.pop(ctx, i),
              child: Container(width: 48, height: 48, decoration: BoxDecoration(color: kCcColors[i], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
            ),
        ]),
      ),
    );
  }

  Future<void> _onCard(CcCard c) async {
    final g = _g;
    if (g == null || _busy || _over || g.current != 0) return;
    if (_drawn != null && c != _drawn) {
      setState(() => _msg = 'You can only play the card you just drew, or pass');
      return;
    }
    if (!g.canPlay(c, g.hands[0])) {
      setState(() => _msg = c.kind == 14 ? 'Wild +4 only works if you have no card of the current colour' : 'That card does not match');
      SoundService.instance.playWrong();
      return;
    }
    int chosen = c.color;
    if (c.isWild) {
      final pick = await _pickColor();
      if (pick == null || !mounted) return;
      chosen = pick;
    }
    await _doPlay(0, c, chosen);
  }

  Future<void> _onDraw() async {
    final g = _g;
    if (g == null || _busy || _over || g.current != 0 || _drawn != null) return;
    if (g.playable(0).isNotEmpty) {
      setState(() => _msg = 'You have a playable card, so you must play');
      return;
    }
    final epoch = _epoch;
    final c = g.drawOne(0);
    _sortHand(g);
    SoundService.instance.playCardFlip();
    if (c != null && g.canPlay(c, g.hands[0])) {
      setState(() {
        _drawn = c;
        _msg = 'You drew a card you can play. Play it or pass';
      });
      return;
    }
    setState(() {
      _busy = true;
      _msg = c == null ? 'The draw pile is empty. Turn passes' : 'No playable card. Turn passes';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (_dead(epoch)) return;
    g.pass();
    _afterTurn();
  }

  void _onPass() {
    final g = _g;
    if (g == null || _busy || _drawn == null) return;
    g.pass();
    _afterTurn();
  }

  void _finish(ColorClashEngine g) {
    final won = g.winner == 0;
    if (!_saved) {
      _saved = true;
      int pts = 0;
      for (int p = 0; p < g.n; p++) { pts += g.handPoints(p); }
      GameScoreService.save(gameName: 'Color Clash', score: won ? pts + 50 : 0, won: won);
    }
    if (won) {
      SoundService.instance.playWin();
    } else {
      SoundService.instance.playLose();
    }
    setState(() {
      _over = true;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return HowToPlayOverlay(
      gameKey: 'color_clash',
      title: 'HOW TO PLAY COLOR CLASH',
      steps: const [
        HowToPlayStep(icon: Icons.style_rounded, title: 'Match the top card', description: 'Play a card that matches the colour or the number or symbol of the card on the pile. Tap a bright card to play it.'),
        HowToPlayStep(icon: Icons.bolt_rounded, title: 'Action cards', description: 'Skip jumps the next player. Reverse flips direction. +2 makes the next player draw two and lose their turn.'),
        HowToPlayStep(icon: Icons.palette_rounded, title: 'Wild cards', description: 'Wild lets you choose the colour. Wild +4 also makes the next player draw four, but you can only play it if you have no card of the current colour.'),
        HowToPlayStep(icon: Icons.emoji_events_rounded, title: 'Win', description: 'Cannot play? Draw a card. Be the first to empty your hand and you score the points left in everyone else hands. Your last card is called automatically.'),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFF14213D),
        appBar: AppBar(title: const Text('COLOR CLASH')),
        body: g == null ? _setup() : Stack(children: [_table(g), if (_over) _result(g)]),
      ),
    );
  }

  Widget _setup() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.style_rounded, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        const Text('COLOR CLASH', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: Colors.white)),
        const SizedBox(height: 6),
        const Text('Match colours, play action cards, empty your hand', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 24),
        const Text('OPPONENTS', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final n in [1, 2, 3])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: GestureDetector(
                onTap: () => setState(() => _opps = n),
                child: Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _opps == n ? GacomColors.deepOrange.withValues(alpha: 0.25) : Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _opps == n ? GacomColors.deepOrange : Colors.white24, width: 1.5),
                  ),
                  child: Text('$n', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 18, color: _opps == n ? GacomColors.deepOrange : Colors.white)),
                ),
              ),
            ),
        ]),
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

  Widget _cardView(CcCard? c, double w, {bool faceDown = false, bool playable = true, bool lifted = false, VoidCallback? onTap}) {
    final h = w * 1.5;
    Widget face;
    if (faceDown || c == null) {
      face = Container(
        decoration: BoxDecoration(color: const Color(0xFF212121), borderRadius: BorderRadius.circular(w * 0.12), border: Border.all(color: Colors.white, width: 2)),
        child: Center(child: Container(width: w * 0.7, height: h * 0.45, decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(w * 0.35)))),
      );
    } else {
      final bg = kCcColors[c.color];
      Widget symbol;
      if (c.kind == 10) {
        symbol = Icon(Icons.block_rounded, size: w * 0.55, color: Colors.white);
      } else if (c.kind == 11) {
        symbol = Icon(Icons.swap_horiz_rounded, size: w * 0.6, color: Colors.white);
      } else if (c.kind == 13) {
        symbol = SizedBox(width: w * 0.5, height: w * 0.5, child: CustomPaint(painter: _WildPainter()));
      } else {
        final text = c.kind == 12 ? '+2' : (c.kind == 14 ? '+4' : '${c.kind}');
        symbol = Text(text, style: TextStyle(fontSize: w * 0.5, fontWeight: FontWeight.w900, color: Colors.white, shadows: const [Shadow(color: Colors.black54, blurRadius: 3)]));
      }
      face = Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(w * 0.12), border: Border.all(color: Colors.white, width: 2)),
        child: Center(
          child: Container(
            width: w * 0.78,
            height: h * 0.62,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(w * 0.4)),
            child: Center(child: symbol),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: playable ? 1.0 : 0.45,
        child: Transform.translate(
          offset: Offset(0, lifted ? -10 : 0),
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(boxShadow: [BoxShadow(color: lifted ? const Color(0xAAFFD700) : Colors.black45, blurRadius: lifted ? 8 : 3, offset: const Offset(0, 2))], borderRadius: BorderRadius.circular(w * 0.12)),
            child: face,
          ),
        ),
      ),
    );
  }

  Widget _opponent(ColorClashEngine g, int p) {
    final active = g.current == p && !_over;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? GacomColors.deepOrange : Colors.white24, width: active ? 2 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_name(p), style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.style_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text('${g.hands[p].length}', style: TextStyle(color: g.hands[p].length == 1 ? const Color(0xFFFFD54F) : Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ]),
    );
  }

  Widget _table(ColorClashEngine g) {
    final hand = g.hands[0];
    final myTurn = g.current == 0 && !_busy && !_over;
    final canDraw = myTurn && _drawn == null && g.playable(0).isEmpty;
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int p = 1; p < g.n; p++)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: _opponent(g, p)),
          ]),
        ),
        Expanded(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Column(children: [
                  _cardView(null, 64, faceDown: true, onTap: canDraw ? _onDraw : null, lifted: canDraw),
                  const SizedBox(height: 4),
                  Text('${g.drawPile.length}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
                const SizedBox(width: 28),
                Column(children: [
                  _cardView(g.top, 64),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 12, height: 12, decoration: BoxDecoration(color: kCcColors[g.activeColor], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5))),
                    const SizedBox(width: 5),
                    Text(kCcColorNames[g.activeColor], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    if (g.n > 2) ...[
                      const SizedBox(width: 6),
                      Icon(g.dir == 1 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded, color: Colors.white70, size: 15),
                    ],
                  ]),
                ]),
              ]),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ]),
          ),
        ),
        if (_drawn != null && myTurn)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white24, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: _onPass,
              child: const Text('PASS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        SizedBox(
          height: 112,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            itemCount: hand.length,
            itemBuilder: (context, i) {
              final c = hand[i];
              final ok = myTurn && g.canPlay(c, hand) && (_drawn == null || c == _drawn);
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _cardView(c, 54, playable: ok || !myTurn, lifted: ok, onTap: () => _onCard(c)),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _result(ColorClashEngine g) {
    final won = g.winner == 0;
    int pts = 0;
    for (int p = 0; p < g.n; p++) { pts += g.handPoints(p); }
    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(26),
          decoration: GacomDecorations.glassCard(context, radius: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: won ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
            const SizedBox(height: 12),
            Text(won ? 'YOU WIN!' : '${_name(g.winner)} WINS', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
            const SizedBox(height: 6),
            Text(won ? 'You score ${pts + 50} points' : 'You were left holding ${g.handPoints(0)} points', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
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

class _WildPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(rect, i * pi / 2, pi / 2, true, Paint()..color = kCcColors[i]);
    }
    canvas.drawCircle(size.center(Offset.zero), size.width / 2, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WildPainter oldDelegate) => false;
}
