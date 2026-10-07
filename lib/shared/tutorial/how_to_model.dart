import 'package:flutter/material.dart';

/// What the little animated demo in a tutorial step shows.
enum DemoKind {
  /// A finger drags across the stage and the actor follows (steering, joysticks, aiming).
  drag,

  /// A finger taps the target (buttons, tapping things, tapping the screen).
  tap,

  /// A finger taps the actor, then taps the target and the actor moves there
  /// (pick a piece then a square, pick a card then a pile).
  move,

  /// A quick flick in a direction (swipe to slice, slide, throw).
  swipe,

  /// Keyboard keys light up and the actor moves (computer only).
  keys,

  /// A question with three answers, the right one gets picked.
  choose,

  /// Nothing to press: the actor and target just pulse (waiting, watching, turns).
  watch,
}

/// One screen of a tutorial.
class TutorialStep {
  final String title;
  final String text;
  final DemoKind demo;

  /// Icon drawn for the thing the player controls.
  final IconData actor;

  /// Icon drawn for the thing the player is going for.
  final IconData target;

  /// Direction for [DemoKind.swipe] and [DemoKind.drag] (x and y between -1 and 1).
  final double dx;
  final double dy;

  /// Key labels for [DemoKind.keys], for example ['W','A','S','D'] or ['SPACE'].
  final List<String> keys;

  /// Only shown on a computer with a keyboard.
  final bool pcOnly;

  const TutorialStep({
    required this.title,
    required this.text,
    required this.demo,
    this.actor = Icons.person_rounded,
    this.target = Icons.star_rounded,
    this.dx = 1,
    this.dy = 0,
    this.keys = const <String>[],
    this.pcOnly = false,
  });
}

/// The whole how-to for one game.
class GameHowTo {
  final String name;
  final IconData icon;
  final Color color;

  /// One line: what you are trying to do.
  final String goal;
  final List<TutorialStep> steps;
  const GameHowTo({
    required this.name,
    required this.icon,
    required this.color,
    required this.goal,
    required this.steps,
  });
}
