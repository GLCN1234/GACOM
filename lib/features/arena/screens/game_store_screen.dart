import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class GameStoreScreen extends StatelessWidget {
  const GameStoreScreen({super.key});

  static const _gacomGames = [
    {'name': 'Chess', 'desc': 'Pure strategy, 1v1', 'icon': Icons.extension_rounded},
    {'name': 'Tic-Tac-Toe', 'desc': 'Quick and simple — now with a Ryan practice mode', 'icon': Icons.grid_3x3_rounded},
    {'name': 'RPS Battle', 'desc': 'Best of 5, rock paper scissors', 'icon': Icons.front_hand_rounded},
    {'name': 'Trivia', 'desc': '10 questions, race the clock', 'icon': Icons.quiz_rounded},
    {'name': 'Reaction', 'desc': 'Tap fastest, pure reflexes', 'icon': Icons.bolt_rounded},
    {'name': 'Survival Shooter', 'desc': 'Move, auto-fire, survive the waves', 'icon': Icons.gps_fixed_rounded, 'route': '/arena/store/survival', 'badge': 'NEW'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('GAME STORE')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('GACOM GAMES', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          ..._gacomGames.map((g) => GestureDetector(
            onTap: g['route'] != null ? () => context.push(g['route'] as String) : null,
            child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: GacomDecorations.glassCard(context, radius: 16),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: GacomColors.deepOrange.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(g['icon'] as IconData, color: GacomColors.deepOrange, size: 22)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 15, color: GacomColors.textPrimary)),
                Text(g['desc'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: ((g['badge'] as String?) == 'NEW' ? GacomColors.electricBlue : GacomColors.success).withOpacity(0.12), borderRadius: BorderRadius.circular(50)),
                child: Text((g['badge'] as String?) ?? 'LIVE', style: TextStyle(color: (g['badge'] as String?) == 'NEW' ? GacomColors.electricBlue : GacomColors.success, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 10))),
            ]),
          ))),

          const SizedBox(height: 24),
          const Text('COMING FROM DEVELOPERS', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: GacomColors.textMuted, letterSpacing: 1)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: GacomDecorations.glassCard(context, radius: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.rocket_launch_outlined, color: GacomColors.electricBlue, size: 28),
              const SizedBox(height: 12),
              const Text('Built a game? Get it on GACOM.', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 17, color: GacomColors.textPrimary)),
              const SizedBox(height: 6),
              const Text('Submit your game for review. Our team looks at every submission — approved games get added to the Arena for our whole player base to compete on.',
                style: TextStyle(color: GacomColors.textSecondary, fontSize: 13, height: 1.4)),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: GacomColors.electricBlue, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
                onPressed: () => context.push('/arena/store/submit'),
                child: const Text('SUBMIT YOUR GAME', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
              )),
            ]),
          ),
        ],
      ),
    );
  }
}
