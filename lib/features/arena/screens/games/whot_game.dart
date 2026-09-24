import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';

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
    Future.delayed(const Duration(milliseconds: 500), (){if(mounted)_aiPlay();});
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
          if (!isPlayer) Future.delayed(const Duration(milliseconds: 500), (){if(mounted)_aiPlay();});
          return;
        case 2: // Pick Two
          _drawIfEmpty();
          final target = isPlayer ? aiHand : playerHand;
          for (int i = 0; i < 2 && deck.isNotEmpty; i++) target.add(deck.removeLast());
          setState(() { playerTurn = !isPlayer; status = isPlayer ? 'AI picks 2 — your turn' : 'You pick 2 — AI\'s turn'; });
          break;
        case 8: // Suspension — skip opponent
          setState(() { playerTurn = isPlayer; status = isPlayer ? 'Opponent suspended! Go again' : 'You are suspended — AI goes again'; });
          if (!isPlayer) { Future.delayed(const Duration(milliseconds: 500), (){if(mounted)_aiPlay();}); return; }
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
      if (!playerTurn) Future.delayed(const Duration(milliseconds: 600), (){if(mounted)_aiPlay();});
    }
    proceed();
  }

  void _pickSuitDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (dialogContext) => SimpleDialog(
      backgroundColor: GacomColors.cardDark,
      title: const Text('Call a suit', style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800)),
      children: _suits.map((s) => SimpleDialogOption(
        onPressed: () => _onSuitChosen(dialogContext, s),
        child: Row(children: [
          Icon(_suitIcons[s] ?? Icons.circle_outlined, color: _suitColors[s] ?? GacomColors.deepOrange, size: 26),
          const SizedBox(width: 12),
          Text(s, style: TextStyle(color: _suitColors[s] ?? GacomColors.deepOrange, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      )).toList(),
    ));
  }

  void _onSuitChosen(BuildContext dialogContext, String s) {
    Navigator.of(dialogContext).pop();
    if (!mounted) return;
    setState(() { calledSuit = s; playerTurn = false; status = 'You called $s — AI thinking...'; });
    if (playerHand.isEmpty) { _endGame(); return; }
    Future.delayed(const Duration(milliseconds: 600), (){if(mounted)_aiPlay();});
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
    if (playerHand.isEmpty) { pScore++; status = 'You win!'; SoundService.instance.playWin(); GameScoreService.save(gameName: 'Whot', score: 1, won: true); }
    else { aScore++; status = 'AI wins!'; SoundService.instance.playLose(); GameScoreService.save(gameName: 'Whot', score: 0, won: false); }
  }

  Widget _cardWidget(WhotCard c, {bool small = false, VoidCallback? onTap, bool playable = true, bool faceDown = false}) {
    final color = _suitColors[c.suit] ?? GacomColors.deepOrange;
    final w = small ? 56.0 : 70.0, h = small ? 78.0 : 96.0;
    if (faceDown) {
      return Container(width: w, height: h, margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2A1A00), Color(0xFF4A2E00)]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: GacomColors.deepOrange.withOpacity(0.4), width: 1.5),
        ),
        child: Center(child: Icon(Icons.all_inclusive_rounded, color: GacomColors.deepOrange.withOpacity(0.5), size: small ? 18 : 22)));
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: playable ? 1.0 : 0.45,
      child: GestureDetector(onTap: playable ? onTap : null,
        child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          width: w, height: h, margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.22), GacomColors.cardDark]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: playable ? color : GacomColors.border, width: playable ? 2 : 1),
            boxShadow: playable ? [BoxShadow(color: color.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)] : null,
          ),
          child: Stack(children: [
            Positioned(top: 4, left: 6, child: Text(c.suit == 'Whot' ? '20' : '${c.number}', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: small ? 11 : 13, color: color))),
            Center(child: Icon(_suitIcons[c.suit], color: color, size: small ? 24 : 30)),
            if (c.suit == 'Whot') Positioned(bottom: 4, left: 0, right: 0, child: Text('WHOT', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w900, fontSize: small ? 9 : 10, color: color, letterSpacing: 1))),
          ]),
        ),
      ),
    );
  }

  Widget _aiHandFan() => SizedBox(height: 50, child: Center(
    child: SizedBox(width: min(aiHand.length * 22.0 + 30, 260), child: Stack(
      children: List.generate(aiHand.length, (i) => Positioned(left: i * 22.0,
        child: Transform.rotate(angle: (i - aiHand.length / 2) * 0.05, child: _cardWidget(aiHand[i], small: true, faceDown: true)))),
    )),
  ));

  @override
  Widget build(BuildContext context) {
    final top = discard.last;
    final activeSuit = calledSuit ?? top.suit;
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('WHOT'), actions: [
        Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(50)),
          child: Text('YOU $pScore — AI $aScore', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.deepOrange))),
      ]),
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.2, colors: [Color(0xFF0F2818), Color(0xFF0A0A0F)])),
        child: Column(children: [
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.smart_toy_rounded, color: GacomColors.textMuted, size: 16),
            const SizedBox(width: 6),
            Text('AI — ${aiHand.length} cards', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textMuted)),
          ]),
          _aiHandFan(),
          const SizedBox(height: 8),
          AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: GacomColors.cardDark.withOpacity(0.6), borderRadius: BorderRadius.circular(50)),
            child: Text(status, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textPrimary))),
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Discard pile stack effect
            SizedBox(width: 90, height: 110, child: Stack(alignment: Alignment.center, children: [
              if (discard.length > 1) Positioned(top: 6, child: Transform.rotate(angle: -0.08, child: Opacity(opacity: 0.3, child: _cardWidget(discard[discard.length - 2])))),
              _cardWidget(top),
            ])),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_suitIcons[activeSuit], color: _suitColors[activeSuit], size: 16),
              const SizedBox(width: 6),
              Text(calledSuit != null ? 'Called: $activeSuit' : activeSuit, style: TextStyle(color: _suitColors[activeSuit], fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
            const SizedBox(height: 18),
            GestureDetector(onTap: _playerDraw, child: Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(50), border: Border.all(color: GacomColors.deepOrange.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_circle_outline_rounded, color: GacomColors.deepOrange, size: 18),
                const SizedBox(width: 6),
                Text('DRAW  •  ${deck.length} left', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, color: GacomColors.textSecondary)),
              ]))),
          ]))),
          if (over) Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity,
            child: ElevatedButton(onPressed: _reset, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              child: const Text('NEW GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white))))),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(color: GacomColors.cardDark.withOpacity(0.4), border: Border(top: BorderSide(color: GacomColors.border.withOpacity(0.4)))),
            child: SizedBox(height: 110, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8),
              children: playerHand.map((c) => _cardWidget(c, onTap: () => _playerPlay(c), playable: _canPlay(c))).toList())),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}
