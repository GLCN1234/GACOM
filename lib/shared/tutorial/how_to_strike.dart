import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guides for the four Strike games. They replace the older guides for the same keys.
const Map<String, GameHowTo> howToStrike = <String, GameHowTo>{
  'sundial': GameHowTo(
    name: 'Sundial City',
    icon: Icons.history_edu_rounded,
    color: Color(0xFFF6B93B),
    goal: 'Shoot the wraith carrying the right answer before the others catch you.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Run', text: 'Drag your finger anywhere to run. On a computer, use W A S D or the arrow keys.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.blur_on_rounded),
      TutorialStep(title: 'Read the question', text: 'The question is at the top. Every wraith carries a lettered answer: A, B, C or D.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.blur_on_rounded),
      TutorialStep(title: 'Shoot the right one', text: 'Tap a wraith to fire at it, or tap its answer in the question box. The FIRE button shoots the nearest one.', demo: DemoKind.tap, actor: Icons.my_location_rounded, target: Icons.blur_on_rounded),
      TutorialStep(title: 'Stay alive', text: 'Wraiths chase you. Touching one costs a heart, and so does a wrong shot. Tap DASH to slip away.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
    ],
  ),
  'signal': GameHowTo(
    name: 'Signal Ridge',
    icon: Icons.cell_tower_rounded,
    color: Color(0xFFFF8A3D),
    goal: 'Shoot the jammer carrying the right answer while dodging their fire.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Run', text: 'Drag your finger anywhere to run. On a computer, use W A S D or the arrow keys.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.cell_tower_rounded),
      TutorialStep(title: 'Read the question', text: 'The question is at the top. Each jammer carries a lettered answer.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.cell_tower_rounded),
      TutorialStep(title: 'Dodge the red shots', text: 'Jammers keep their distance and shoot at you. Keep moving, and tap DASH to slip through a shot.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
      TutorialStep(title: 'Shoot the right one', text: 'Tap a jammer to fire at it, or tap its answer in the question box. A wrong shot costs a heart.', demo: DemoKind.tap, actor: Icons.my_location_rounded, target: Icons.cell_tower_rounded),
    ],
  ),
  'skyroot': GameHowTo(
    name: 'Skyroot Frontier',
    icon: Icons.forest_rounded,
    color: Color(0xFF4BD37B),
    goal: 'Pop the pod carrying the right answer before the others burst on you.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Run', text: 'Drag your finger anywhere to run. On a computer, use W A S D or the arrow keys.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.forest_rounded),
      TutorialStep(title: 'Read the question', text: 'The question is at the top. Each pod carries a lettered answer and drifts around.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.forest_rounded),
      TutorialStep(title: 'Do not get touched', text: 'A pod that touches you bursts and costs a heart. Move away, or tap DASH.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
      TutorialStep(title: 'Pop the right one', text: 'Tap a pod to fire at it, or tap its answer in the question box. A wrong pod costs a heart.', demo: DemoKind.tap, actor: Icons.my_location_rounded, target: Icons.forest_rounded),
    ],
  ),
  'casefiles': GameHowTo(
    name: 'Case Files',
    icon: Icons.manage_search_rounded,
    color: Color(0xFFE5483A),
    goal: 'Chase down the suspect carrying the right answer.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Run', text: 'Drag your finger anywhere to run. On a computer, use W A S D or the arrow keys.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.person_search_rounded),
      TutorialStep(title: 'Read the question', text: 'The question is at the top. Each suspect carries a lettered answer and runs away from you.', demo: DemoKind.watch, actor: Icons.help_outline_rounded, target: Icons.person_search_rounded),
      TutorialStep(title: 'Catch up', text: 'Suspects are slower than you. Close in, and tap DASH for a burst of speed.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.bolt_rounded),
      TutorialStep(title: 'Take the right one down', text: 'Tap a suspect to fire at it, or tap its answer in the question box. A wrong shot costs a heart.', demo: DemoKind.tap, actor: Icons.my_location_rounded, target: Icons.person_search_rounded),
    ],
  ),
};
