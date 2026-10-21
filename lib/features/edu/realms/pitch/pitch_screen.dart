import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_kits.dart';
import '../realm_shell.dart';
import 'pitch_logic.dart';
import 'pitch_painter.dart';
import 'pitch_skins.dart';

const String pitchStory =
    'One free kick, one question, one goal. The goalmouth is split into zones and every zone carries an answer. '
    'Bend the ball into the right one before the referee looks at his watch.';

const String pitchHowTo =
    'DRAG back and up to aim, then LET GO to shoot. Drag further for more power, and drag to the side to bend the ball around the wall. '
    'The question is at the top and the answers are painted across the goalmouth, so putting the ball in the right zone IS your answer. '
    'Right zone and it counts, and if you beat the keeper too it is a goal. Wrong zone costs a heart, and so does running the clock down. '
    'The wall blocks a low straight shot: curve it or hit it harder. SHOOT fires a straight one at the middle if you would rather not drag.';

/// Set Piece: the shot and the answer are one action.
class PitchScreen extends StatelessWidget {
  const PitchScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    GameKit.ensureLoaded();
    final PitchSkin skin = PitchSkin.equipped();
    return RealmShell(
      gameName: 'Set Piece',
      gameId: 'pitch',
      title: 'Set Piece',
      story: pitchStory,
      howTo: pitchHowTo,
      icon: Icons.sports_soccer_rounded,
      accent: skin.accent,
      background: skin.grass,
      config: config,
      actions: const <RealmAction>[
        RealmAction(0, Icons.sports_soccer_rounded, 'SHOOT'),
      ],
      create: (RealmContent content) => PitchLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => PitchPainter(logic as PitchLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final PitchLogic g = logic as PitchLogic;
        final bool compact = MediaQuery.of(context).size.height < 440;
        final question = g.round;
        final bool good = g.note.startsWith('GOAL') || g.note.startsWith('Right answer');
        return Positioned(
          left: 12,
          right: 12,
          bottom: compact ? 6 : 16,
          child: IgnorePointer(
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              if (g.noteT > 0 && g.note.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: good ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80)),
                  ),
                  child: Text(
                    g.note,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: good ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              if (question != null)
                Container(
                  margin: EdgeInsets.only(right: realmActionPadWidth(compact, 1.0)),
                  padding: EdgeInsets.fromLTRB(10, compact ? 6 : 9, 10, compact ? 6 : 9),
                  decoration: BoxDecoration(
                    color: const Color(0xCC06130A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: skin.accent.withValues(alpha: 0.7)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(
                      'AIM AT THE RIGHT ANSWER',
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
            ]),
          ),
        );
      },
    );
  }
}
