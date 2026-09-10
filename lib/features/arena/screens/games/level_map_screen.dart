import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reusable 20-level map for any game. Levels 1-7 Easy, 8-14 Medium, 15-20
/// Hard. Progress persists locally per [gameKey] so Colony Siege and Arena
/// Gauntlet (and any future game) each track their own unlocked level.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key, required this.gameKey, required this.title, required this.onPlayLevel});
  final String gameKey;
  final String title;
  final void Function(int level, String difficulty) onPlayLevel;

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  int _unlocked = 1;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _unlocked = prefs.getInt('level_unlocked_${widget.gameKey}') ?? 1);
  }

  static String difficultyFor(int level) => level <= 7 ? 'Easy' : level <= 14 ? 'Medium' : 'Hard';
  static Color colorFor(String difficulty) => difficulty == 'Easy' ? GacomColors.success : difficulty == 'Medium' ? GacomColors.info : GacomColors.error;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: Text(widget.title.toUpperCase())),
    body: ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 20,
      itemBuilder: (_, i) {
        final level = i + 1;
        final locked = level > _unlocked;
        final difficulty = difficultyFor(level);
        final color = colorFor(difficulty);
        final isBoundary = level == 1 || level == 8 || level == 15;
        return Column(children: [
          if (isBoundary) Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(difficulty.toUpperCase(), style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: color, letterSpacing: 1.5)),
          ),
          GestureDetector(
            onTap: locked ? null : () => widget.onPlayLevel(level, difficulty),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: locked ? GacomColors.cardDark.withOpacity(0.5) : GacomColors.cardDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: locked ? GacomColors.border : color.withOpacity(0.5)),
              ),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(
                    color: locked ? GacomColors.elevatedCard : color.withOpacity(0.15), shape: BoxShape.circle),
                  child: Center(child: locked
                    ? const Icon(Icons.lock_rounded, color: GacomColors.textMuted, size: 18)
                    : Text('$level', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16, color: color)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Level $level', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, color: locked ? GacomColors.textMuted : GacomColors.textPrimary)),
                  Text(difficulty, style: TextStyle(fontSize: 11, color: locked ? GacomColors.textMuted : color)),
                ])),
                if (!locked) Icon(Icons.play_circle_fill_rounded, color: color, size: 28),
              ]),
            ),
          ),
        ]);
      },
    ),
  );

  /// Call after a level is completed successfully to unlock the next one.
  static Future<void> unlockNext(String gameKey, int completedLevel) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('level_unlocked_$gameKey') ?? 1;
    if (completedLevel + 1 > current) {
      await prefs.setInt('level_unlocked_$gameKey', completedLevel + 1);
    }
  }
}
