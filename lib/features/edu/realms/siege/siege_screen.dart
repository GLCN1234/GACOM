import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_kits.dart';
import '../realm_shell.dart';
import 'siege_logic.dart';
import 'siege_painter.dart';
import 'siege_skins.dart';

const String siegeStory =
    'The marchers come for your gate, and every one of them carries a number. Your weapons are not swords, they are operations. '
    'A marcher only falls to a number that goes into it exactly, so take them apart before they reach the wall.';

const String siegeHowTo =
    'TAP a weapon at the bottom to arm it, then TAP a marcher. If your divisor goes into the marcher\'s number exactly, the number is divided and the marcher is cut down, and it falls for good when it reaches 1. '
    'So a marcher carrying 30 takes a divide by 2, then a divide by 3, then a divide by 5, in any order. '
    'Swing with a divisor that does not go in and that weapon goes cold for a moment while the marcher speeds up. '
    'Every marcher that reaches the gate costs you a shield. Hold the gate as long as you can, and you get a shield back every third wave.';

/// Gate Siege: the maths is the weapon, not a question in front of it.
class SiegeScreen extends StatelessWidget {
  const SiegeScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    GameKit.ensureLoaded();
    final SiegeSkin skin = SiegeSkin.equipped();
    return RealmShell(
      gameName: 'Gate Siege',
      gameId: 'siege',
      title: 'Gate Siege',
      story: siegeStory,
      howTo: siegeHowTo,
      icon: Icons.shield_rounded,
      accent: skin.accent,
      background: skin.ground,
      config: config,
      joystick: false,
      actions: const <RealmAction>[],
      create: (RealmContent content) => SiegeLogic(content),
      painter: (RealmLogic logic, Listenable repaint) => SiegePainter(logic as SiegeLogic, repaint: repaint),
      hud: (BuildContext context, RealmLogic logic, VoidCallback refresh) {
        final SiegeLogic g = logic as SiegeLogic;
        final bool compact = MediaQuery.of(context).size.height < 440;
        return Positioned(
          left: 10,
          right: 10,
          bottom: compact ? 6 : 14,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            if (g.noteT > 0 && g.note.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: skin.accent.withValues(alpha: 0.8)),
                ),
                child: Text(
                  g.note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < g.weapons.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _WeaponButton(
                        label: '÷ ${g.weapons[i].k}',
                        armed: g.armed == i,
                        ready: g.actionReady(i),
                        accent: skin.accent,
                        compact: compact,
                        onTap: () {
                          g.arm(i);
                          refresh();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ]),
        );
      },
    );
  }
}

/// One weapon on the belt. Big, labelled and always on screen, because the
/// player should never have to hunt for the controls.
class _WeaponButton extends StatelessWidget {
  const _WeaponButton({
    required this.label,
    required this.armed,
    required this.ready,
    required this.accent,
    required this.compact,
    required this.onTap,
  });

  final String label;
  final bool armed;
  final double ready;
  final Color accent;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool cold = ready < 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: cold ? null : onTap,
      child: Container(
        height: compact ? 44 : 58,
        decoration: BoxDecoration(
          color: armed ? accent.withValues(alpha: 0.26) : Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: armed ? accent : Colors.white30, width: armed ? 2.2 : 1.2),
        ),
        child: Stack(children: <Widget>[
          if (cold)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                child: LinearProgressIndicator(
                  value: ready,
                  minHeight: 4,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A80)),
                ),
              ),
            ),
          Center(
            child: Text(
              label,
              style: TextStyle(
                color: cold ? Colors.white38 : Colors.white,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w800,
                fontSize: compact ? 17 : 21,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
