import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for the Darkom Neon Plaza (the open hub).
const Map<String, GameHowTo> howToDarkomHub = <String, GameHowTo>{
  'darkomhub': GameHowTo(
    name: 'Neon Plaza',
    icon: Icons.groups_rounded,
    color: Color(0xFF00E5FF),
    goal: 'Meet other players, chat kindly, team up with your house and walk into the gates to play.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Walk around the plaza', text: 'Put your finger anywhere and drag to walk. On a computer use W A S D or the arrow keys. Buildings, stalls and the fountain are solid.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.flag_rounded),
      TutorialStep(title: 'Walk into a gate', text: 'Stand on a glowing pad and tap ENTER. The Story Gate starts the story, the Arena Gate is for 1v1 duels, the Squad Hall is for house squads, the Locker changes your look and the Notice Board has the rules.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.login_rounded),
      TutorialStep(title: 'Talk and wave', text: 'Tap CHAT to write to the hub or your house, or tap a quick phrase. Tap EMOTE to wave, laugh or dance. Tap another player to challenge them, block them or report them. Voice is optional and starts muted.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.chat_bubble_rounded),
      TutorialStep(title: 'Team up with your house', text: 'In the Squad Hall, create a squad or join one from your house. Up to 4 players can join, and the host taps START to begin the match together.', demo: DemoKind.watch, actor: Icons.person_rounded, target: Icons.groups_rounded),
    ],
  ),
};
