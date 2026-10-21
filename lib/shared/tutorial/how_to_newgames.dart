import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// Tutorials for the five games where the learning is the action itself:
/// Okada Run, Gate Siege, Word Current, Set Piece and Market Run.
const Map<String, GameHowTo> howToNewGames = <String, GameHowTo>{
  'okada': GameHowTo(
    name: 'Okada Run',
    icon: Icons.two_wheeler_rounded,
    color: Color(0xFFFFC233),
    goal: 'Ride through the lane whose sign carries the right answer.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Steer', text: 'Drag your finger left and right to move across the lanes. You never stop riding. On a computer, use A and D or the arrow keys.', demo: DemoKind.drag, actor: Icons.two_wheeler_rounded, target: Icons.signpost_rounded, dx: 1),
      TutorialStep(title: 'Read the signs', text: 'The question sits at the top of the screen. Three signs hang over the three lanes ahead, one answer on each.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.signpost_rounded),
      TutorialStep(title: 'Ride through the right one', text: 'Go under the sign you believe is right. Right lane and you speed up and win a can of fuel. Wrong lane costs a heart and kills your speed.', demo: DemoKind.drag, actor: Icons.two_wheeler_rounded, target: Icons.check_circle_rounded, dx: -1),
      TutorialStep(title: 'Watch the road', text: 'Danger cars and potholes cost a heart too. Collect fuel cans, then press BOOST to burn one for speed, or BRAKE if a junction comes up too fast.', demo: DemoKind.tap, actor: Icons.local_fire_department_rounded, target: Icons.local_gas_station_rounded),
    ],
  ),
  'siege': GameHowTo(
    name: 'Gate Siege',
    icon: Icons.shield_rounded,
    color: Color(0xFFFFCA28),
    goal: 'Cut every marcher down to 1 before it reaches your gate.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Every marcher is a number', text: 'The attackers walk down towards your gate, and each one carries a number on its shield.', demo: DemoKind.watch, actor: Icons.groups_rounded, target: Icons.shield_rounded),
      TutorialStep(title: 'Arm a weapon', text: 'Your weapons are divisions. Tap one at the bottom of the screen to arm it.', demo: DemoKind.tap, actor: Icons.hardware_rounded, target: Icons.calculate_rounded),
      TutorialStep(title: 'Then tap a marcher', text: 'If your divisor goes into its number exactly, the number is divided. A marcher carrying 30 takes a divide by 2, then 3, then 5, in any order, and falls when it reaches 1.', demo: DemoKind.move, actor: Icons.calculate_rounded, target: Icons.groups_rounded),
      TutorialStep(title: 'A wrong swing costs you', text: 'Swing with a divisor that does not go in and that weapon goes cold for a moment while the marcher speeds up. Every marcher that reaches the gate costs a shield.', demo: DemoKind.watch, actor: Icons.ac_unit_rounded, target: Icons.shield_rounded),
    ],
  ),
  'current': GameHowTo(
    name: 'Word Current',
    icon: Icons.waves_rounded,
    color: Color(0xFF4FC3F7),
    goal: 'Swim into the word that finishes the sentence on the bank.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Swim', text: 'Drag your finger to swim across the river. The current never stops. On a computer, use W A S D or the arrow keys.', demo: DemoKind.drag, actor: Icons.pool_rounded, target: Icons.waves_rounded, dx: 1),
      TutorialStep(title: 'Read the bank', text: 'The sentence is at the top of the screen with a word missing. The words that might fill it come floating down the river.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.text_fields_rounded),
      TutorialStep(title: 'Catch the right word', text: 'Swim into the word that fits. The wrong word costs a heart, and letting every word float past counts as a miss.', demo: DemoKind.drag, actor: Icons.pool_rounded, target: Icons.check_circle_rounded, dx: -1),
      TutorialStep(title: 'Mind the logs', text: 'Logs and drums in the water cost a heart. Press DIVE to pass under everything for a moment, and SPRINT to reach a word that is getting away.', demo: DemoKind.tap, actor: Icons.download_rounded, target: Icons.water_drop_rounded),
    ],
  ),
  'pitch': GameHowTo(
    name: 'Set Piece',
    icon: Icons.sports_soccer_rounded,
    color: Color(0xFF7CFFA0),
    goal: 'Put the ball in the goal zone painted with the right answer.',
    steps: <TutorialStep>[
      TutorialStep(title: 'The goal is the answer sheet', text: 'The goalmouth is split into zones and each zone carries one answer. The question is at the bottom of the screen.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.sports_soccer_rounded),
      TutorialStep(title: 'Drag to aim', text: 'Drag back and upfield to aim. A line shows where the ball is heading, and the further you drag the harder you hit it.', demo: DemoKind.drag, actor: Icons.sports_soccer_rounded, target: Icons.my_location_rounded, dy: -1),
      TutorialStep(title: 'Let go to shoot', text: 'Release and the ball flies. Drag to the side to bend it: a low straight shot is blocked by the wall, so curve it or hit it harder.', demo: DemoKind.swipe, actor: Icons.sports_soccer_rounded, target: Icons.groups_rounded, dy: -1),
      TutorialStep(title: 'Beat the keeper too', text: 'The right zone always counts as a right answer. Beat the keeper as well and it is a goal. A wrong zone costs a heart, and so does running the shot clock down.', demo: DemoKind.watch, actor: Icons.sports_handball_rounded, target: Icons.timer_rounded),
    ],
  ),
  'market': GameHowTo(
    name: 'Market Run',
    icon: Icons.storefront_rounded,
    color: Color(0xFFFFD166),
    goal: 'Trade through one market day and come out with a profit.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Walk the market', text: 'Drag your finger to walk. There are no questions in this game at all: the money is the question.', demo: DemoKind.drag, actor: Icons.directions_walk_rounded, target: Icons.storefront_rounded, dx: 1),
      TutorialStep(title: 'Buy low', text: 'Every stall board shows what the stall charges and what customers pay today. Stand at a stall, press TRADE, and buy when the stall price is under the selling price.', demo: DemoKind.tap, actor: Icons.shopping_basket_rounded, target: Icons.sell_rounded),
      TutorialStep(title: 'Serve your counter', text: 'Customers come to your own counter on their own. Stand there and press TRADE to serve the one waiting.', demo: DemoKind.move, actor: Icons.directions_walk_rounded, target: Icons.person_rounded),
      TutorialStep(title: 'Count the change', text: 'Tap notes to make their change. The screen shows what you have handed over, never what you owe, so work out the subtraction yourself. Wrong change comes out of your profit.', demo: DemoKind.tap, actor: Icons.payments_rounded, target: Icons.calculate_rounded),
    ],
  ),
};
