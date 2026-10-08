import 'package:flutter/material.dart';
import 'how_to_model.dart';

/// How-to guide for Signal Ridge.
const Map<String, GameHowTo> howToSignal = <String, GameHowTo>{
  'signal': GameHowTo(
    name: 'Signal Ridge',
    icon: Icons.cell_tower_rounded,
    color: Color(0xFFFF8A3D),
    goal: 'Reconnect the mountain villages by switching on every signal tower, using programs, circuits and careful debugging.',
    steps: <TutorialStep>[
      TutorialStep(title: 'Pick a ridge', text: 'The map shows six ridges in a row. Press START to open the next puzzle. Each ridge teaches a new idea and finishes with a signal key question.', demo: DemoKind.tap, actor: Icons.touch_app_rounded, target: Icons.cell_tower_rounded),
      TutorialStep(title: 'Build a program', text: 'Tap a block in the palette to add it to your program. Tap a placed block to select it, then use DELETE to remove it. Blocks inside a REPEAT or IF go where the blinking cursor is.', demo: DemoKind.tap, actor: Icons.touch_app_rounded, target: Icons.view_agenda_rounded),
      TutorialStep(title: 'Press RUN', text: 'The relay bot follows your blocks one by one and the current block lights up. Use 1x or 2x for speed, or STEP to go one block at a time. If it crashes, the footprints show where it went.', demo: DemoKind.watch, actor: Icons.smart_toy_rounded, target: Icons.cell_tower_rounded),
      TutorialStep(title: 'Use loops and decisions', text: 'REPEAT runs blocks several times, so a short program can do a long job. IF WALL AHEAD lets the bot choose between two paths. Fewer blocks earn more stars.', demo: DemoKind.choose, actor: Icons.repeat_rounded, target: Icons.call_split_rounded),
      TutorialStep(title: 'Circuits and bugs', text: 'In the circuit ridge, work out each gate to predict the lamp, then flip switches to light it with as few ON as possible. In the debug ridge, tap the faulty block and choose the right fix.', demo: DemoKind.move, actor: Icons.toggle_on_rounded, target: Icons.lightbulb_rounded),
      TutorialStep(title: 'Stuck? Ask for help', text: 'HINT shows the next block or the faulty area but limits that ridge to one star. After a few failed tries you can see a solution, and after four you can skip the ridge. You always keep moving.', demo: DemoKind.tap, actor: Icons.touch_app_rounded, target: Icons.lightbulb_rounded),
    ],
  ),
};
