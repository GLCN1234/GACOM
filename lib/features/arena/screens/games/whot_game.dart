import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';

/// Whot — the real Nigerian card game. 5 suits (Circle, Triangle, Cross,
/// Square, Star) plus wild "Whot" cards. Special numbers: 1 Hold On
/// (skip opponent), 2 Pick Two, 8 Suspension (skip), 14 General Market
/// (opponent draws 1), 20 Whot (wild, name the next suit).
class WhotGame extends StatefulWidget {
  const WhotGame({super.key});
  @override State<WhotGame> createState() => _WhotGameState();
}

class WhotCard {
  final String suit; // Circle, Triangle, Cross, Square, Star, Whot
  final int number;
  const WhotCard(this.suit, this.number);
  @override String toString() => suit == 'Whot' ? 'Whot 20' : '$number $suit';
}

class _WhotGameState extends State<WhotGame> {
  static const _suits = ['Circle', 'Triangle', 'Cross', 'Square', 'Star'];
  static const _suitIcons = {
    'Circle': Icons.circle_outlined, 'Triangle': Icons.change_history_rounded,
    'Cross': Icons.add_rounded, 'Square': Icons.crop_square_rounded,
    'Star': Icons.star_border_rounded, 'Whot': Icons.all_inclusive_rounded,
  };
  static const _suitColors = {
    'Circle': Color(0xFF3D8BFF), 'Triangle': Color(0xFF34D399),
    'Cross': Color(0xFFE85B8A), 'Square': Color(0xFFF5C518),
    'Star': Color(0xFF8B5CF6), 'Whot': Color(0xFFFF6A00),
  };

  List<WhotCard> deck = [], playerHand = [], aiHand = [], discard = [];
  String? calledSuit; // set after a Whot(20) is played
  bool playerTurn = true, over = false;
  String status = 'Your turn';
  int pScore = 0, aScore = 0;

  @override void initState() { super.initState(); _reset(); }

  List<WhotCard> _buildDeck() {
    final d = <WhotCard>[];
    for (final s in _suits) {
      final numbers = s == 'Star' ? [1,2,3,4,5,7,8] : [1,2,3,4,5,7,8,9,10,11,12,13,14];
      for (final n in numbers) d.add(WhotCard(s, n));
    }
    for (int i = 0; i < 5; i++) d.add(const WhotCard('Whot', 20));
    return d..shuffle();
  }

  void _reset() {
    deck = _buildDeck();
    playerHand = List.generate(6, (_) => deck.removeLast());
    aiHand = List.generate(6, (_) => deck.removeLast());
    discard = [deck.removeLast()];
    while (discard.last.suit == 'Whot') { deck.insert(0, discard.removeLast()); discard.add(deck.removeLast()); }
    calledSuit = null; playerTurn = true; over = false; status = 'Your turn';
    setState((){});
  }

  bool _canPlay(WhotCard c) {
    final top = discard.last;
    final activeSuit = calledSuit ?? top.suit;
    return c.suit == 'Whot' || c.suit == activeSuit || c.number == top.number;
  }

  void _drawIfEmpty() {
    if (deck.isEmpty) {
      final keep = discard.removeLast();
      deck = List.from(discard)..shuffle();
      discard = [keep];
    }
  }

  void _playerPlay(WhotCard c) {
    if (!playerTurn || over || !_canPlay(c)) return;
    setState(() {
      playerHand.remove(c);
      discard.add(c);
      calledSuit = null;
    });
    SoundService.instance.playCardFlip();
    _handleSpecial(c, isPlayer: true);
  }

  void _playerDraw() {
    if (!playerTurn || over) return;
    _drawIfEmpty();
    if (deck.isEmpty) return;
    setState(() { playerHand.add(deck.removeLast()); playerTurn = false; status = 'AI thinking...'; });
    SoundService.instance.playCardFlip();
    Future.delayed(const Duration(milliseconds: 500), _aiPlay);
  }

  void _handleSpecial(WhotCard c, {required bool isPlayer}) {
    if (playerHand.isEmpty || aiHand.isEmpty) { _endGame(); return; }

    if (c.suit == 'Whot') {
      if (isPlayer) {
        _pickSuitDialog();
        return; // suit picker continues the flow
      } else {
        calledSuit = _suits[Random().nextInt(_suits.length)];
      }
    }

    void proceed() {
      switch (c.number) {
        case 1: // Hold On — same player goes again
          setState(() { playerTurn = isPlayer; status = isPlayer ? 'Hold On! Go again' : 'AI holds on...'; });
          if (!isPlayer) Future.delayed(const Duration(milliseconds: 500), _aiPlay);
          return;
        case 2: // Pick Two
          _drawIfEmpty();
          final target = isPlayer ? aiHand : playerHand;
          for (int i = 0; i < 2 && deck.isNotEmpty; i++) target.add(deck.removeLast());
          setState(() { playerTurn = !isPlayer; status = isPlayer ? 'AI picks 2 — your turn' : 'You pick 2 — AI\'s turn'; });
          break;
        case 8: // Suspension — skip opponent
          setState(() { playerTurn = isPlayer; status = isPlayer ? 'Opponent suspended! Go again' : 'You are suspended — AI goes again'; });
          if (!isPlayer) { Future.delayed(const Duration(milliseconds: 500), _aiPlay); return; }
          break;
        case 14: // General Market — opponent draws 1
          _drawIfEmpty();
          final target = isPlayer ? aiHand : playerHand;
          if (deck.isNotEmpty) target.add(deck.removeLast());
          setState(() { playerTurn = !isPlayer; status = isPlayer ? 'AI draws from the market' : 'You draw from the market'; });
          break;
        default:
          setState(() { playerTurn = !isPlayer; status = isPlayer ? 'AI thinking...' : 'Your turn'; });
      }
      if (playerHand.isEmpty || aiHand.isEmpty) { _endGame(); return; }
      if (!playerTurn) Future.delayed(const Duration(milliseconds: 600), _aiPlay);
    }
    proceed();
  }

  void _pickSuitDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      backgroundColor: GacomColors.cardDark,
      title: const Text('Call a suit', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      content: Wrap(spacing: 10, runSpacing: 10, children: _suits.map((s) => GestureDetector(
        onTap: () {
          Navigator.pop(context);
          setState(() { calledSuit = s; playerTurn = false; status = 'You called $s — AI thinking...'; });
          if (playerHand.isEmpty) { _endGame(); return; }
          Future.delayed(const Duration(milliseconds: 600), _aiPlay);
        },
        child: Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _suitColors[s]!.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: _suitColors[s]!)),
          child: Icon(_suitIcons[s], color: _suitColors[s], size: 28)),
      )).toList()),
    ));
  }

  void _aiPlay() {
    if (over) return;
    final playable = aiHand.where(_canPlay).toList();
    if (playable.isEmpty) {
      _drawIfEmpty();
      if (deck.isNotEmpty) { setState(() => aiHand.add(deck.removeLast())); }
      SoundService.instance.playCardFlip();
      setState(() { playerTurn = true; status = 'Your turn'; });
      return;
    }
    // Prefer a non-Whot card so wilds are saved for when genuinely stuck.
    final choice = playable.firstWhere((c) => c.suit != 'Whot', orElse: () => playable.first);
    setState(() { aiHand.remove(choice); discard.add(choice); calledSuit = null; });
    SoundService.instance.playCardFlip();
    _handleSpecial(choice, isPlayer: false);
  }

  void _endGame() {
    setState(() { over = true; });
    if (playerHand.isEmpty) { pScore++; status = 'You win!'; SoundService.instance.playWin(); }
    else { aScore++; status = 'AI wins!'; SoundService.instance.playLose(); }
  }

  Widget _cardWidget(WhotCard c, {bool small = false, VoidCallback? onTap}) {
    final color = _suitColors[c.suit]!;
    final w = small ? 52.0 : 64.0, h = small ? 72.0 : 88.0;
    return GestureDetector(onTap: onTap,
      child: Container(width: w, height: h, margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(10), border: Border.all(color: color, width: 2)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_suitIcons[c.suit], color: color, size: small ? 20 : 26),
          const SizedBox(height: 4),
          Text(c.suit == 'Whot' ? 'WHOT' : '${c.number}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: small ? 12 : 15, color: GacomColors.textPrimary)),
        ]),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final top = discard.last;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('WHOT'), actions: [
        Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: Text('You $pScore — AI $aScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 13, color: GacomColors.textSecondary)))),
      ]),
      body: Column(children: [
        const SizedBox(height: 8),
        Text('AI hand: ${aiHand.length} cards', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.all(12), child: Text(status, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary), textAlign: TextAlign.center)),
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _cardWidget(top),
          if (calledSuit != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Called: $calledSuit', style: TextStyle(color: _suitColors[calledSuit], fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13))),
          const SizedBox(height: 16),
          GestureDetector(onTap: _playerDraw, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.border)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_circle_outline_rounded, color: GacomColors.textMuted, size: 16),
              const SizedBox(width: 6),
              Text('DRAW (${deck.length} left)', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textSecondary)),
            ]))),
        ]))),
        if (over) Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity,
          child: ElevatedButton(onPressed: _reset, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('NEW GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))))),
        SizedBox(height: 100, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8),
          children: playerHand.map((c) => _cardWidget(c, small: true, onTap: () => _playerPlay(c))).toList())),
        const SizedBox(height: 12),
      ]),
    );
  }
}
