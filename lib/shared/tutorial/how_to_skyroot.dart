import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for Skyroot Frontier.
const Map<String, GameHowTo> howToSkyroot = <String, GameHowTo>{
  'skyroot': GameHowTo(
    name: 'Skyroot Frontier',
    icon: Icons.forest_rounded,
    color: Color(0xFF4BD37B),
    goal: 'Heal a failing forest canopy before the rains fail.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Climb the tree', text: 'Drag to climb the trunk and walk along the branches and vines. Collect seed pods on the way for bonus points.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.park_rounded, dx: 0.3, dy: -1),
      TutorialStep(title: 'Move with the keyboard', text: 'On a computer, climb with W A S D or the arrow keys. Press space to TEND.', demo: DemoKind.keys, keys: <String>['W', 'A', 'S', 'D'], actor: Icons.person_rounded, target: Icons.park_rounded, pcOnly: true),
      TutorialStep(title: 'Watch the blight', text: 'Grey blight creeps up from the roots, layer by layer. The bars on the right edge show each layer. Healed layers bloom and slow the spread.', demo: DemoKind.watch, actor: Icons.warning_amber_rounded, target: Icons.forest_rounded),
      TutorialStep(title: 'Tend a station', text: 'Each layer has one station. Walk up to it and press TEND. You will test water, sort the nutrient cycle, order a food chain or match adaptations.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.eco_rounded),
      TutorialStep(title: 'Follow the green arrow', text: 'The arrow and the top line tell you which layer to tend next. A layer that turns grey again can be tended again for a smaller reward.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.flag_rounded, dx: 0.5, dy: -0.8),
      TutorialStep(title: 'Face the Blight Boss', text: 'After the four layers bloom, climb to the Crown. Answer five questions to push the blight back one fifth at a time. You have three leaves, and a wrong answer costs one.', demo: DemoKind.choose, actor: Icons.person_rounded, target: Icons.warning_amber_rounded),
    ],
  ),
};
