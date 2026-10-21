import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_kits.dart';
import '../realm_shell.dart';
import 'current_logic.dart';
import 'current_painter.dart';
import 'current_skins.dart';

const String currentStory =
    'The river carries words. On the bank is a sentence with a hole in it, and somewhere in the water is the word that fills it. '
    'Swim out, read fast, and catch the right one before the current takes it past you.';

const String currentHowTo =
    'DRAG anywhere to swim. The sentence sits at the top and the possible words float down the river on their own. '
    'Swim into the word that fits and it is yours. Swim into the wrong one and you lose a heart, and letting all of them float past counts as a miss. '
    'Logs and drums in the water also cost a heart. Press DIVE to pass under everything for a moment, and SPRINT for a burst of speed to reach a word going by.';

/// Word Current: reading and swimming are the same action.
class CurrentScreen extends StatelessWidget {
  const CurrentScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    GameKit.ensureLoaded();
    final CurrentSkin skin = CurrentSkin.equipped();
    return RealmShell(
      gameName: 'Word Current',
      gameId: 'current',
      title: 'Word Current',
      story: currentStory,
      howTo: currentHowTo,
      icon: Icons.waves_rounded,
      accent: skin.accent,
      background: skin.deep,
      config: config,
      actions: const <RealmAction>[
        RealmAction(0, Icons.fast_forward_rounded, 'SPRINT'),
        RealmAction(1, Icons.download_rounded, 'DIVE'),
      ],
      create: (RealmContent content) => CurrentLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => CurrentPainter(logic as CurrentLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final CurrentLogic g = logic as CurrentLogic;
        final bool compact = MediaQuery.of(context).size.height < 440;
        final question = g.round;
        return Positioned(
          left: compact ? 110 : 12,
          right: compact ? 120 : 12,
          top: compact ? 44 : 92,
          child: IgnorePointer(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              if (question != null)
                Container(
                  padding: EdgeInsets.fromLTRB(10, compact ? 6 : 9, 10, compact ? 6 : 9),
                  decoration: BoxDecoration(
                    color: const Color(0xCC00151D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: skin.accent.withValues(alpha: 0.7)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(
                      'ON THE BANK',
                      style: TextStyle(color: skin.accent, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      question.text,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 15, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                  ]),
                ),
              if (g.noteT > 0 && g.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.74),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: g.note == 'Caught it' ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80)),
                    ),
                    child: Text(
                      g.note,
                      style: TextStyle(
                        color: g.note == 'Caught it' ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
