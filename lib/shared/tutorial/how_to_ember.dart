import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for Ember Archipelago.
const Map<String, GameHowTo> howToEmber = <String, GameHowTo>{
  'ember': GameHowTo(
    name: 'Ember Archipelago',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFF2ED3E6),
    goal: 'Sail between the islands and relight all five beacons.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Read the order', text: 'Each order names an island by its coordinates, such as (4, 3). The first number is across (x), the second is up (y). Negative numbers are left and down.', demo: DemoKind.watch, actor: Icons.menu_book_rounded, target: Icons.place_rounded),
      TutorialStep(title: 'Plot your route', text: 'Tap grid points on the chart to add waypoints. Each leg shows its fuel cost, which is its length on the grid. Tap your last waypoint again to remove it.', demo: DemoKind.tap, actor: Icons.touch_app_rounded, target: Icons.timeline_rounded),
      TutorialStep(title: 'Avoid the reefs', text: 'A leg that crosses a reef is refused and shown in red. Press UNDO and go around. Your tank holds a fixed amount of fuel, so a shorter route is better.', demo: DemoKind.move, actor: Icons.sailing_rounded, target: Icons.flag_rounded),
      TutorialStep(title: 'Press SAIL', text: 'When the route is green and fits your fuel, press SAIL. Your boat follows the waypoints. Reach the island named in the order, not just any island.', demo: DemoKind.tap, actor: Icons.sailing_rounded, target: Icons.place_rounded),
      TutorialStep(title: 'Do the harbour job', text: 'At the harbour you mix cargo in a ratio, mend a sail with fractions, turn a lamp through an angle, or find the best price. A wrong try costs 2 fuel and you get one more try.', demo: DemoKind.choose, actor: Icons.build_rounded, target: Icons.local_fire_department_rounded),
      TutorialStep(title: 'Face the Night Tide', text: 'After five beacons burn, the tide rises. Add and remove ballast with positive and negative numbers so the water ends on the safe mark.', demo: DemoKind.watch, actor: Icons.waves_rounded, target: Icons.flag_rounded),
    ],
  ),
};
