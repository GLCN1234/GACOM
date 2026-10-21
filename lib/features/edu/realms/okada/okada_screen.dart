import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_kits.dart';
import '../realm_shell.dart';
import 'okada_logic.dart';
import 'okada_painter.dart';
import 'okada_skins.dart';

const String okadaStory =
    'Lagos is awake and the road is yours. Every junction hangs three signs over three lanes, and only one of them is right. '
    'Ride through the right one and the road opens up. Ride through the wrong one and the traffic swallows you.';

const String okadaHowTo =
    'DRAG anywhere to steer left and right. You never stop and you never read a question panel: the question sits at the top and the three answers hang over the three lanes. '
    'Ride under the sign you think is right. Right lane and you speed up and earn fuel. Wrong lane and you lose a heart and slow down. '
    'Dodge the danger cars and potholes, pick up fuel cans, and press BOOST to burn a can for speed. BRAKE slows you when a junction comes up too fast.';

/// Okada Run: the endless ride that replaced Ember Archipelago.
class OkadaScreen extends StatelessWidget {
  const OkadaScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    GameKit.ensureLoaded();
    final OkadaSkin skin = OkadaSkin.equipped();
    return RealmShell(
      gameName: 'Okada Run',
      gameId: 'okada',
      title: 'Okada Run',
      story: okadaStory,
      howTo: okadaHowTo,
      icon: Icons.two_wheeler_rounded,
      accent: skin.accent,
      background: const Color(0xFF14180F),
      config: config,
      actions: const <RealmAction>[
        RealmAction(0, Icons.local_fire_department_rounded, 'BOOST'),
        RealmAction(1, Icons.pan_tool_rounded, 'BRAKE'),
      ],
      create: (RealmContent content) => OkadaLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => OkadaPainter(logic as OkadaLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final OkadaLogic g = logic as OkadaLogic;
        final bool compact = MediaQuery.of(context).size.height < 440;
        final question = g.q;
        return Positioned(
          left: compact ? 110 : 12,
          right: compact ? 120 : 12,
          top: compact ? 44 : 92,
          child: IgnorePointer(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: <Widget>[
              if (question != null)
                Container(
                  padding: EdgeInsets.fromLTRB(10, compact ? 6 : 9, 10, compact ? 6 : 9),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: skin.accent.withValues(alpha: 0.7)),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(
                      'NEXT JUNCTION',
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
              if (g.lastLineT > 0 && g.lastLine.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: g.lastLine == 'Right lane' ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80)),
                    ),
                    child: Text(
                      g.lastLine,
                      style: TextStyle(
                        color: g.lastLine == 'Right lane' ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80),
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
