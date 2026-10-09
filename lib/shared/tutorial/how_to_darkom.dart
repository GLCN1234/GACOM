import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for Darkom City.
const Map<String, GameHowTo> howToDarkom = <String, GameHowTo>{
  'darkom': GameHowTo(
    name: 'Darkom City',
    icon: Icons.location_city_rounded,
    color: Color(0xFFFF2E93),
    goal: 'Finish three contracts in each district, then beat your own Echo and reach the extraction gate.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Move through the city', text: 'Put your finger anywhere and drag. Your hero runs the way you drag. On a computer use W A S D. Buildings and crates are solid, so use them as cover.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.flag_rounded),
      TutorialStep(title: 'Fight with ATTACK', text: 'Tap ATTACK. Your weapon aims at the nearest enemy by itself, or straight ahead if nobody is close. On a computer press SPACE.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.flash_on_rounded),
      TutorialStep(title: 'Six weapons, six styles', text: 'Tap SWAP to change weapon. The sword slashes, the dagger stabs fast, the hammer smashes, the axe flies and returns, the staff fires bolts that use mana, and the shield blocks. Tap ATTACK twice with the shield to guard and then bash.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.swap_horiz_rounded),
      TutorialStep(title: 'Special and dash', text: 'SPECIAL is a strong move that needs a short rest before you can use it again. DASH is a quick burst that cannot be hurt. Watch the red warnings on the ground and dash through them.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
      TutorialStep(title: 'Follow your contracts', text: 'The bar at the top says what to do next, and the arrow and the minimap flag point to it. Contracts are clearing shades, carrying a shard, escorting a courier, hunting a bounty and holding a zone.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.assignment_rounded, dx: 1, dy: -0.3),
      TutorialStep(title: 'Face your Echo', text: 'After the contracts, walk to the glowing arena. Your Echo uses your own weapon and your own habits. Learn its warnings, then win and reach the extraction gate. You have three lives.', demo: DemoKind.watch, actor: Icons.person_rounded, target: Icons.bolt_rounded),
    ],
  ),
};
