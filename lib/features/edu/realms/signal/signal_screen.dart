import 'package:flutter/material.dart';
import '../realm_kit.dart';
import '../realm_shell.dart';
import 'signal_logic.dart';
import 'signal_painter.dart';
import 'signal_panels.dart';

/// Signal Ridge: a programming puzzle game. Build block programs for a relay
/// bot, solve logic circuits and debug broken programs to bring the signal
/// back to six mountain villages.
class SignalScreen extends StatelessWidget {
  const SignalScreen({super.key, this.config = const RealmConfig()});
  final RealmConfig config;

  @override
  Widget build(BuildContext context) {
    return RealmShell(
      gameName: 'Signal Ridge',
      gameId: 'signal',
      title: 'Signal Ridge',
      story: 'A storm has knocked out every signal tower along Signal Ridge, and six mountain villages are cut off. Program the relay bot, wire the lamp circuits and fix broken programs to reconnect them, one village at a time.',
      howTo: 'Tap blocks to build a program, then press RUN and watch the bot switch on every tower with as few blocks as you can. Use HINT if you get stuck.',
      icon: Icons.cell_tower_rounded,
      accent: sgAccentColor,
      config: config,
      create: (RealmContent c) => SignalLogic(c),
      painter: (RealmLogic l, Listenable repaint) => SignalPainter(l as SignalLogic, repaint: repaint),
      hud: signalHud,
      joystick: false,
      duelSeconds: 420,
      background: const Color(0xFF160E33),
    );
  }
}
