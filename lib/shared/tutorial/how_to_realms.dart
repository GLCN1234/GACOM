import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guides for Odyssey and the five Realms.
const Map<String, GameHowTo> howToRealms = <String, GameHowTo>{
  'odyssey': GameHowTo(
    name: 'Odyssey',
    icon: Icons.explore_rounded,
    color: Color(0xFF00897B),
    goal: 'Roam a big map, collect coins and answer questions to earn knowledge points.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Roam the map', text: 'Put your finger anywhere and drag. Your hero walks the way you drag. Every region of the map is a different subject.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.explore_rounded),
      TutorialStep(title: 'Move with the keyboard', text: 'On a computer you can walk with W A S D or the arrow keys. Space makes you dash.', demo: DemoKind.keys, keys: <String>['W', 'A', 'S', 'D'], actor: Icons.person_rounded, target: Icons.star_rounded, pcOnly: true),
      TutorialStep(title: 'Pick up coins and stars', text: 'Touch coins to collect them. Life stars give your hearts back, so grab one when you are hurt.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.star_rounded, dx: 1, dy: -0.3),
      TutorialStep(title: 'Answer to score', text: 'Touch a challenge orb and a question appears. Pick the right answer to earn points. A wrong answer costs you a heart.', demo: DemoKind.choose, actor: Icons.person_rounded, target: Icons.help_outline_rounded),
      TutorialStep(title: 'Rest when you want', text: 'Tap REST for 1, 3 or 5 minutes of free roaming with no pressure. When the rest ends, one checkpoint question must be answered to carry on.', demo: DemoKind.watch, actor: Icons.person_rounded, target: Icons.timer_rounded),
    ],
  ),
  'biome': GameHowTo(
    name: 'Biome',
    icon: Icons.pets_rounded,
    color: Color(0xFF7CB342),
    goal: 'Meet wild creatures, win battles with your knowledge, tame them and build a team.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Walk the land', text: 'Drag to walk. The ground changes colour with the subject of each biome.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.pets_rounded),
      TutorialStep(title: 'Move with the keyboard', text: 'On a computer, walk with W A S D or the arrow keys.', demo: DemoKind.keys, keys: <String>['W', 'A', 'S', 'D'], actor: Icons.person_rounded, target: Icons.pets_rounded, pcOnly: true),
      TutorialStep(title: 'Start a battle', text: 'Walk into a wild creature to start a battle. Every attack is a question, so pick the right answer to hit it.', demo: DemoKind.choose, actor: Icons.pets_rounded, target: Icons.bolt_rounded),
      TutorialStep(title: 'Fight, Tame or Run', text: 'FIGHT hurts the creature. TAME uses an orb and works best once its health is half or less. RUN escapes the battle.', demo: DemoKind.tap, actor: Icons.pets_rounded, target: Icons.radio_button_checked_rounded),
      TutorialStep(title: 'Heal at campfires', text: 'Collect orbs and coins as you walk. Rest at a campfire to heal your team. If your whole team faints, the run ends.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.local_fire_department_rounded),
    ],
  ),
  'windward': GameHowTo(
    name: 'Windward',
    icon: Icons.sailing_rounded,
    color: Color(0xFF0288D1),
    goal: 'Sail between islands, buy and sell cargo, and make as much gold as you can in one season.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Steer the ship', text: 'Drag on the screen. The ship turns toward where you point.', demo: DemoKind.drag, actor: Icons.sailing_rounded, target: Icons.flag_rounded),
      TutorialStep(title: 'Use the wind', text: 'You sail fastest with the wind behind you. Never sail straight into the wind, it is the red wedge. Tap TRIM for a short burst of speed.', demo: DemoKind.tap, actor: Icons.sailing_rounded, target: Icons.air_rounded),
      TutorialStep(title: 'Dock at a port', text: 'Sail up to a port and tap ANCHOR to dock. Avoid reefs, rocks and storm clouds on the way.', demo: DemoKind.tap, actor: Icons.sailing_rounded, target: Icons.anchor_rounded),
      TutorialStep(title: 'Trade with the harbour master', text: 'At the quay you answer a question to buy or sell. A right answer gets a better price and a wrong answer a worse one.', demo: DemoKind.choose, actor: Icons.sailing_rounded, target: Icons.monetization_on_rounded),
      TutorialStep(title: 'Deliver contracts', text: 'Take a contract, load the cargo and follow the gold arrow to the island that needs it. The season lasts 12 minutes.', demo: DemoKind.drag, actor: Icons.sailing_rounded, target: Icons.local_shipping_rounded),
    ],
  ),
  'delve': GameHowTo(
    name: 'Delve',
    icon: Icons.flashlight_on_rounded,
    color: Color(0xFF6A1B9A),
    goal: 'Go as deep as you can in a dark cave before your torch burns out.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Walk in the dark', text: 'Drag to walk. You can only see what your torch lights up.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.flashlight_on_rounded),
      TutorialStep(title: 'Move with the keyboard', text: 'On a computer, walk with W A S D or the arrow keys. Space makes you sprint.', demo: DemoKind.keys, keys: <String>['W', 'A', 'S', 'D'], actor: Icons.person_rounded, target: Icons.flashlight_on_rounded, pcOnly: true),
      TutorialStep(title: 'Feed the torch', text: 'Your torch shrinks as it burns. Pick up fuel flasks to make it bigger again.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.local_fire_department_rounded),
      TutorialStep(title: 'Open rune doors', text: 'Walk up to a glowing rune door and answer its question. Right opens the door, wrong fires a trap.', demo: DemoKind.choose, actor: Icons.person_rounded, target: Icons.lock_open_rounded),
      TutorialStep(title: 'Sprint and descend', text: 'Shadows run from light but chase you in the dark. Tap SPRINT for a short burst, then reach the stairs to go deeper.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
    ],
  ),
  'casefiles': GameHowTo(
    name: 'Case Files',
    icon: Icons.manage_search_rounded,
    color: Color(0xFFC0392B),
    goal: 'Collect clues around town and work out who did it before the day runs out.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Walk the town', text: 'Drag to walk, or tap a building to walk to its door.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.home_rounded),
      TutorialStep(title: 'Move with the keyboard', text: 'On a computer, walk with W A S D or the arrow keys.', demo: DemoKind.keys, keys: <String>['W', 'A', 'S', 'D'], actor: Icons.person_rounded, target: Icons.home_rounded, pcOnly: true),
      TutorialStep(title: 'Inspect for clues', text: 'At a door, press INSPECT and answer the question to win a clue. Each inspection costs one of your 12 hours.', demo: DemoKind.choose, actor: Icons.person_rounded, target: Icons.search_rounded),
      TutorialStep(title: 'Use the notebook', text: 'Open the notebook to mark who could be guilty and who is cleared. Clues help you rule suspects out.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.menu_book_rounded),
      TutorialStep(title: 'Make your accusation', text: 'When you are sure, accuse a suspect. You can solve up to 3 cases in one run.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.gavel_rounded),
    ],
  ),
  'frontier': GameHowTo(
    name: 'Frontier',
    icon: Icons.holiday_village_rounded,
    color: Color(0xFFEF6C00),
    goal: 'Grow a new town and keep it alive for 30 days.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Pick a tile', text: 'Tap a tile on the map to see what can be built there.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.grid_view_rounded),
      TutorialStep(title: 'Build', text: 'Tap a building in the bar below to build it. It costs wood, stone or coins. Tap a built tile to upgrade it.', demo: DemoKind.move, actor: Icons.home_rounded, target: Icons.grid_view_rounded),
      TutorialStep(title: 'Answer the council', text: 'Each dusk the council asks a question. Answer it to earn a blessing, or skip it.', demo: DemoKind.choose, actor: Icons.person_rounded, target: Icons.groups_rounded),
      TutorialStep(title: 'Research', text: 'Spend knowledge in Research, but you must prove each idea with a correct answer.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.science_rounded),
      TutorialStep(title: 'Defend the town', text: 'Raiders come every 5th day. Build towers and walls before they arrive and survive to day 30.', demo: DemoKind.watch, actor: Icons.shield_rounded, target: Icons.holiday_village_rounded),
    ],
  ),
};
