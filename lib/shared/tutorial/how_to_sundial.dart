import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for Sundial City.
const Map<String, GameHowTo> howToSundial = <String, GameHowTo>{
  'sundial': GameHowTo(
    name: 'Sundial City',
    icon: Icons.history_edu_rounded,
    color: Color(0xFFF6B93B),
    goal: 'Give the silent city its voice back by repairing the sentences inside each building, before the rumours take over the square.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Walk the square', text: 'Drag to walk, or tap a building to head to its door. The gold arrow and the bar at the top always tell you where to go next.', demo: DemoKind.drag, actor: Icons.person_rounded, target: Icons.home_work_rounded),
      TutorialStep(title: 'Move with the keyboard', text: 'On a computer, walk with W A S D or the arrow keys. Press Space to use the FIX button.', demo: DemoKind.keys, keys: <String>['W', 'A', 'S', 'D'], actor: Icons.person_rounded, target: Icons.home_work_rounded, pcOnly: true),
      TutorialStep(title: 'Press FIX at a door', text: 'Stand on the doormat of a building and press FIX. Each building has its own job: put a letter in order, mend street signs, find a lie, punctuate or choose a meaning.', demo: DemoKind.tap, actor: Icons.person_rounded, target: Icons.edit_note_rounded),
      TutorialStep(title: 'Work with the words', text: 'Tap sentences to number them, drop word tiles into gaps, or tap the sentence that cannot be true. If you slip, the right answer is shown and you may try again, but your voice drops a little.', demo: DemoKind.choose, actor: Icons.person_rounded, target: Icons.spellcheck_rounded),
      TutorialStep(title: 'Stop the rumours', text: 'Every half minute of walking a grey rumour settles on a building and may spread to its neighbour. Fix a building to clear its rumour for good. If five buildings whisper at once, the square falls quiet.', demo: DemoKind.watch, actor: Icons.hearing_rounded, target: Icons.record_voice_over_rounded),
      TutorialStep(title: 'Ring the bell', text: 'When the other five buildings speak, the Town Hall opens. Build your argument from a claim, evidence and reasoning to ring the bell and finish.', demo: DemoKind.move, actor: Icons.gavel_rounded, target: Icons.notifications_active_rounded),
    ],
  ),
};
