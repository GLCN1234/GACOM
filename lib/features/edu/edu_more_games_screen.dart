import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../arena/widgets/game_logo.dart';

/// The classic Edu games. They stay fully playable; Odyssey is the main
/// experience and these live here as optional extras.
class EduMoreGamesScreen extends StatelessWidget {
  const EduMoreGamesScreen({super.key});

  static const List<Map<String, Object>> _games = <Map<String, Object>>[
    {'name': 'Signal Run', 'desc': 'Switch lanes, dodge obstacles, catch the right answer.', 'icon': Icons.directions_run_rounded, 'route': '/arena/practice/endlessrunner'},
    {'name': 'Drone Breach', 'desc': 'Shoot down the drone carrying the correct answer.', 'icon': Icons.gps_fixed_rounded, 'route': '/arena/practice/dronebreach'},
    {'name': 'Signal Match', 'desc': 'Swipe through the correct answer as it arcs across the screen.', 'icon': Icons.gesture_rounded, 'route': '/arena/practice/signalmatch'},
    {'name': 'Vault Break', 'desc': 'Rotate the dial to line up the correct answer.', 'icon': Icons.rotate_right_rounded, 'route': '/arena/practice/vaultbreak'},
    {'name': 'Colony Siege', 'desc': 'Build and defend with what you know.', 'icon': Icons.view_in_ar_rounded, 'route': '/arena/practice/colonybuilder'},
    {'name': 'Arena Gauntlet', 'desc': 'Duel through rounds of questions.', 'icon': Icons.shield_rounded, 'route': '/arena/practice/weaponduel'},
    {'name': 'Speed Math', 'desc': 'Quick sums against the clock.', 'icon': Icons.bolt_rounded, 'route': '/arena/practice/speedmath'},
    {'name': 'Word Scramble', 'desc': 'Unscramble the word before time runs out.', 'icon': Icons.spellcheck_rounded, 'route': '/arena/practice/wordscramble'},
    {'name': 'Chess', 'desc': 'Play against Ryan.', 'icon': Icons.extension_rounded, 'route': '/arena/practice/chess'},
    {'name': 'Trivia', 'desc': 'General knowledge, one question at a time.', 'icon': Icons.quiz_outlined, 'route': '/arena/practice/trivia'},
    {'name': 'Number Duel', 'desc': 'Race Ryan to solve problems first.', 'icon': Icons.timer_rounded, 'route': '/arena/practice/numberduel'},
    {'name': 'Hangman', 'desc': 'Guess the word, one letter at a time.', 'icon': Icons.abc_rounded, 'route': '/arena/practice/hangman'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('MORE GAMES')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text('Optional extras. For the full experience, try Odyssey.',
              style: TextStyle(color: GacomColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          for (final Map<String, Object> g in _games)
            GestureDetector(
              onTap: () => context.push(g['route'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: GacomColors.cardDark, borderRadius: BorderRadius.circular(14), border: Border.all(color: GacomColors.border)),
                child: Row(children: <Widget>[
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: GameLogo(name: g['name'] as String, radius: 12, fallback: Icon(g['icon'] as IconData, color: GacomColors.deepOrange, size: 28)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text(g['name'] as String, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: GacomColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(g['desc'] as String, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
