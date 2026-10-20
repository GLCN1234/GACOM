import 'package:flutter/material.dart';

/// How the drones behave. Each skin uses a different one so the four games
/// feel different to play, not just look different.
enum StrikeBehaviour { chase, shoot, drift, flee }

/// The look, story and enemy behaviour of one Strike game.
class StrikeSkin {
  final String gameId;
  final String name;
  final String story;
  final String howTo;
  final IconData icon;
  final Color accent;
  final Color floor;
  final Color grid;
  final Color foe;
  final String foeName;
  final StrikeBehaviour behaviour;
  const StrikeSkin({
    required this.gameId,
    required this.name,
    required this.story,
    required this.howTo,
    required this.icon,
    required this.accent,
    required this.floor,
    required this.grid,
    required this.foe,
    required this.foeName,
    required this.behaviour,
  });

  static const StrikeSkin sundial = StrikeSkin(
    gameId: 'sundial',
    name: 'Sundial City',
    story: 'Static wraiths swallowed the voice of Sundial City. Each wave they carry the possible answers. Only one wraith holds the true word. Shoot it, and the city speaks again.',
    howTo: 'Drag to run. Read the question at the top. Every wraith carries a lettered answer. TAP the wraith you think is right to fire at it, or press FIRE for the nearest one. Wraiths chase you, so keep moving and use DASH to escape. Wrong shot: you lose a heart.',
    icon: Icons.history_edu_rounded,
    accent: Color(0xFFF6B93B),
    floor: Color(0xFF1B1710),
    grid: Color(0xFF2E2718),
    foe: Color(0xFF8E8A99),
    foeName: 'wraith',
    behaviour: StrikeBehaviour.chase,
  );

  static const StrikeSkin signal = StrikeSkin(
    gameId: 'signal',
    name: 'Signal Ridge',
    story: 'Jammer drones circle the ridge and shoot at anyone who climbs. One of them carries the true signal. Find it before the relay dies.',
    howTo: 'Drag to run. Read the question at the top. Each jammer carries a lettered answer and shoots at you from a distance, so dodge the red shots. TAP the jammer you think is right, or press FIRE. DASH slips through incoming fire. Wrong shot: you lose a heart.',
    icon: Icons.cell_tower_rounded,
    accent: Color(0xFFFF8A3D),
    floor: Color(0xFF14181F),
    grid: Color(0xFF1F2733),
    foe: Color(0xFFFF5A4D),
    foeName: 'jammer',
    behaviour: StrikeBehaviour.shoot,
  );

  static const StrikeSkin skyroot = StrikeSkin(
    gameId: 'skyroot',
    name: 'Skyroot Frontier',
    story: 'Spore pods drift through the canopy and the forest is failing. One pod holds the cure. Pop the right one before the others burst on you.',
    howTo: 'Drag to run. Read the question at the top. Every pod carries a lettered answer and drifts about. If a pod touches you it bursts and costs a heart. TAP the pod you think is right, or press FIRE. DASH to slip away from pods.',
    icon: Icons.forest_rounded,
    accent: Color(0xFF4BD37B),
    floor: Color(0xFF0F1D14),
    grid: Color(0xFF173222),
    foe: Color(0xFF9CCC65),
    foeName: 'pod',
    behaviour: StrikeBehaviour.drift,
  );

  static const StrikeSkin casefiles = StrikeSkin(
    gameId: 'casefiles',
    name: 'Case Files',
    story: 'The suspects run when they see you. One of them is telling the truth. Chase them down the night streets, and take down the one with the right answer.',
    howTo: 'Drag to run. Read the question at the top. Every suspect carries a lettered answer and runs away from you. Close in, then TAP the suspect you think is right, or press FIRE. DASH to catch up. Wrong shot: you lose a heart.',
    icon: Icons.manage_search_rounded,
    accent: Color(0xFFE5483A),
    floor: Color(0xFF14111A),
    grid: Color(0xFF211B2B),
    foe: Color(0xFFB39DDB),
    foeName: 'suspect',
    behaviour: StrikeBehaviour.flee,
  );
}
