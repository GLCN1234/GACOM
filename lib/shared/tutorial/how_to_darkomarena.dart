import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for the Darkom Arena (realtime player versus player).
const Map<String, GameHowTo> howToDarkomArena = <String, GameHowTo>{
  'darkomarena': GameHowTo(
    name: 'Darkom Arena',
    icon: Icons.sports_mma_rounded,
    color: Color(0xFFFF2E93),
    goal: 'Win two rounds. Beat your rival in a duel, or be the last one standing in a squad match.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Pick a weapon and get ready', text: 'Choose one of the six weapons in the lobby, then tap READY. Everyone has the same health and the same damage, so skins only change how you look. Your weapon is locked when the round starts.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.check_circle_rounded),
      TutorialStep(title: 'Move and use cover', text: 'Drag anywhere to run. On a computer use W A S D. The glowing blocks are solid, so hide behind them to dodge bolts and axes.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.flag_rounded),
      TutorialStep(title: 'Attack, special and dash', text: 'ATTACK swings your weapon at the nearest rival. SPECIAL is a strong move that needs a short rest. DASH makes you untouchable for a moment. On a computer press SPACE, E and SHIFT. Red circles on the ground are warnings.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
      TutorialStep(title: 'Win the match', text: 'Drop your rival to zero health to win the round. The first to win two rounds wins the match. Leaving a match counts as a forfeit, and if a round drags on the grid overloads and drains everyone.', demo: DemoKind.watch, actor: Icons.person_rounded, target: Icons.emoji_events_rounded),
    ],
  ),
};
