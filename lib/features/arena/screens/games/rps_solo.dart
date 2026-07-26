import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

// ── RPS solo vs AI (Ryan) ────────────────────────────────────────────────────
class RpsSoloScreen extends StatefulWidget {
  const RpsSoloScreen({super.key});
  @override State<RpsSoloScreen> createState() => _RpsSoloState();
}
class _RpsSoloState extends State<RpsSoloScreen> {
  static const _choices = [
    {'id': 'rock',     'emoji': '🪨', 'label': 'Rock'},
    {'id': 'paper',    'emoji': '📄', 'label': 'Paper'},
    {'id': 'scissors', 'emoji': '✂️', 'label': 'Scissors'},
  ];
  int _myWins = 0, _aiWins = 0, _round = 1;
  String? _myPick, _aiPick, _result;
  bool _revealed = false;

  String _beats(String a) {
    if (a == 'rock') return 'scissors';
    if (a == 'paper') return 'rock';
    return 'paper';
  }

  void _pick(String choice) {
    if (_revealed) return;
    HapticFeedback.lightImpact();
    final ai = _choices[Random().nextInt(3)]['id'] as String;
    String result;
    if (choice == ai) result = 'Draw!';
    else if (_beats(choice) == ai) { _myWins++; result = 'You win this round! 🎉'; }
    else { _aiWins++; result = 'Ryan wins this round!'; }
    setState(() { _myPick = choice; _aiPick = ai; _result = result; _revealed = true; });
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() { _myPick = null; _aiPick = null; _result = null; _revealed = false; _round++; });
    });
  }

  bool get _gameOver => _myWins >= 3 || _aiWins >= 3;
  String get _finalResult => _myWins >= 3 ? 'You beat Ryan! 🏆' : 'Ryan wins! Better luck next time.';

  void _reset() => setState(() { _myWins = 0; _aiWins = 0; _round = 1; _myPick = null; _aiPick = null; _result = null; _revealed = false; });

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('RPS VS RYAN (FREE)')),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _ScoreBox(label: 'You', score: _myWins, color: GacomColors.deepOrange),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text('Round $_round / Best of 5', style: const TextStyle(color: GacomColors.textMuted, fontSize: 12))),
        _ScoreBox(label: 'Ryan', score: _aiWins, color: GacomColors.accentCyan),
      ]),
      const SizedBox(height: 32),
      if (_gameOver) ...[
        Text(_finalResult, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: GacomColors.textPrimary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _reset, style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('PLAY AGAIN', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white))),
      ] else ...[
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _PickDisplay(emoji: _myPick == null ? '❓' : _choices.firstWhere((c) => c['id'] == _myPick)['emoji'] as String, label: 'You'),
          const Text('VS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 20, color: GacomColors.textMuted)),
          _PickDisplay(emoji: _revealed ? (_choices.firstWhere((c) => c['id'] == _aiPick)['emoji'] as String) : '🤔', label: 'Ryan'),
        ]),
        const SizedBox(height: 16),
        if (_result != null) Text(_result!, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 18, color: _result!.contains('You win') ? GacomColors.success : _result! == 'Draw!' ? GacomColors.textSecondary : GacomColors.error), textAlign: TextAlign.center),
        const Spacer(),
        const Text('Choose your move:', style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: _choices.map((c) =>
          GestureDetector(onTap: () => _pick(c['id'] as String),
            child: Container(width: 90, height: 90, decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: GacomColors.border)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(c['emoji'] as String, style: const TextStyle(fontSize: 36)),
                Text(c['label'] as String, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600)),
              ])))).toList()),
        const SizedBox(height: 24),
      ],
    ])),
  );
}

class _ScoreBox extends StatelessWidget {
  final String label; final int score; final Color color;
  const _ScoreBox({required this.label, required this.score, required this.color});
  @override Widget build(BuildContext ctx) => Column(children: [
    Text('$score', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 32, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: GacomColors.textMuted)),
  ]);
}

class _PickDisplay extends StatelessWidget {
  final String emoji, label;
  const _PickDisplay({required this.emoji, required this.label});
  @override Widget build(BuildContext ctx) => Column(children: [
    Container(width: 80, height: 80, decoration: BoxDecoration(color: GacomColors.elevatedCard, borderRadius: BorderRadius.circular(20)),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 40)))),
    const SizedBox(height: 6),
    Text(label, style: const TextStyle(fontSize: 12, color: GacomColors.textMuted)),
  ]);
}
