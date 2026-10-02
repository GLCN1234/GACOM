import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';

/// Void Protocols: Entropy Breach — rebuilt as a real physics
/// trajectory puzzle, not a twin-stick shooter. The player sets a
/// launch angle, fires a single shot, and that shot is genuinely
/// pulled or pushed by each gravity well on screen (real inverse-
/// square force, same as the actual physics), curving around
/// obstacles to reach the target. This is deliberate, one-shot-at-a-
/// time aiming — the opposite pace of Chrono-Spire's real-time dodge
/// combat, on purpose.
class GravWell {
  final Offset fractionalPosition; // 0-1, scaled to canvas at runtime
  final double radius;
  final double strength;
  bool positive;
  GravWell({required this.fractionalPosition, required this.radius, required this.strength, this.positive = true});
}

class VoidLevel {
  final Offset playerFractional;
  final Offset targetFractional;
  final double targetRadius;
  final List<GravWell> wells;
  final String objective;
  final bool polarityMatters;
  VoidLevel({
    required this.playerFractional,
    required this.targetFractional,
    required this.objective,
    this.targetRadius = 22,
    this.wells = const [],
    this.polarityMatters = false,
  });
}

final List<VoidLevel> voidLevels = [
  VoidLevel(
    playerFractional: const Offset(0.12, 0.85),
    targetFractional: const Offset(0.85, 0.15),
    objective: 'Line up a direct shot to the anomaly.',
    wells: [],
  ),
  VoidLevel(
    playerFractional: const Offset(0.12, 0.85),
    targetFractional: const Offset(0.82, 0.18),
    objective: 'A containment field blocks the direct line. Curve around it using Grav-Well G1.',
    wells: [GravWell(fractionalPosition: const Offset(0.5, 0.5), radius: 0.09, strength: 1.0)],
  ),
  VoidLevel(
    playerFractional: const Offset(0.12, 0.88),
    targetFractional: const Offset(0.5, 0.1),
    objective: 'Two wells, both attractive. Thread the gap between them.',
    wells: [
      GravWell(fractionalPosition: const Offset(0.3, 0.5), radius: 0.07, strength: 0.8),
      GravWell(fractionalPosition: const Offset(0.6, 0.45), radius: 0.07, strength: 0.8),
    ],
  ),
  VoidLevel(
    playerFractional: const Offset(0.1, 0.5),
    targetFractional: const Offset(0.88, 0.5),
    objective: 'Switch the well to NEGATIVE polarity to repel your shot around it, not into it.',
    wells: [GravWell(fractionalPosition: const Offset(0.5, 0.5), radius: 0.1, strength: 1.3, positive: true)],
    polarityMatters: true,
  ),
  VoidLevel(
    playerFractional: const Offset(0.12, 0.9),
    targetFractional: const Offset(0.15, 0.1),
    objective: 'One strong well. A wide looping arc will bring your shot back around to the target.',
    wells: [GravWell(fractionalPosition: const Offset(0.5, 0.5), radius: 0.1, strength: 1.8)],
  ),
  VoidLevel(
    playerFractional: const Offset(0.1, 0.9),
    targetFractional: const Offset(0.9, 0.1),
    objective: 'Final breach. Three wells — read the field before you fire.',
    wells: [
      GravWell(fractionalPosition: const Offset(0.3, 0.6), radius: 0.07, strength: 0.9),
      GravWell(fractionalPosition: const Offset(0.6, 0.3), radius: 0.07, strength: -0.9, positive: false),
      GravWell(fractionalPosition: const Offset(0.75, 0.65), radius: 0.06, strength: 0.7),
    ],
    polarityMatters: true,
  ),
];

class Projectile {
  Offset position;
  Offset velocity;
  final List<Offset> trail = [];
  Projectile({required this.position, required this.velocity});
}

class VoidProtocolsController extends ChangeNotifier {
  int levelIndex = 0;
  double angleDegrees = 45;
  int attemptsThisLevel = 0;
  int score = 0;
  bool levelComplete = false;
  bool allComplete = false;
  bool shotFailed = false;
  Projectile? projectile;
  late Size canvasSize;

  VoidLevel get level => voidLevels[levelIndex];

  void setCanvasSize(Size size) => canvasSize = size;

  Offset _toPixels(Offset fractional) => Offset(fractional.dx * canvasSize.width, fractional.dy * canvasSize.height);

  void adjustAngle(double delta) {
    angleDegrees = (angleDegrees + delta).clamp(-89, 89);
    notifyListeners();
  }

  void togglePolarity(int wellIndex) {
    level.wells[wellIndex].positive = !level.wells[wellIndex].positive;
    SoundService.instance.playTap();
    notifyListeners();
  }

  void fire() {
    if (projectile != null) return;
    shotFailed = false;
    attemptsThisLevel++;
    final start = _toPixels(level.playerFractional);
    final rad = (-angleDegrees) * (pi / 180);
    const speed = 260.0;
    projectile = Projectile(position: start, velocity: Offset(cos(rad), sin(rad)) * speed);
    SoundService.instance.playShoot();
    notifyListeners();
  }

  /// One physics step — real force from every well on screen, applied
  /// to the in-flight projectile. This is the actual mechanic, not
  /// flavor text: the shot's path depends entirely on this math.
  void step(double dt) {
    final p = projectile;
    if (p == null || levelComplete) return;

    for (final well in level.wells) {
      final wellPx = _toPixels(well.fractionalPosition);
      final dx = wellPx.dx - p.position.dx;
      final dy = wellPx.dy - p.position.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq > 400) {
        final dist = sqrt(distSq);
        final force = (well.strength * 42000) / distSq;
        final sign = well.positive ? 1.0 : -1.0;
        p.velocity += Offset(dx / dist, dy / dist) * force * sign * dt;
      }
    }

    p.position += p.velocity * dt;
    p.trail.add(p.position);
    if (p.trail.length > 40) p.trail.removeAt(0);

    final targetPx = _toPixels(level.targetFractional);
    if ((p.position - targetPx).distance < level.targetRadius) {
      _onLevelWin();
      return;
    }

    final margin = 40;
    if (p.position.dx < -margin || p.position.dx > canvasSize.width + margin ||
        p.position.dy < -margin || p.position.dy > canvasSize.height + margin) {
      _onShotFailed();
    }
  }

  void _onShotFailed() {
    projectile = null;
    shotFailed = true;
    SoundService.instance.playWrong();
    notifyListeners();
  }

  void _onLevelWin() {
    levelComplete = true;
    final points = max(5, 20 - (attemptsThisLevel - 1) * 5);
    score += points;
    SoundService.instance.playWin();
    notifyListeners();
  }

  void nextLevel() {
    if (levelIndex >= voidLevels.length - 1) {
      allComplete = true;
      GameScoreService.save(gameName: 'Void Protocols', score: score);
      notifyListeners();
      return;
    }
    levelIndex++;
    angleDegrees = 45;
    attemptsThisLevel = 0;
    levelComplete = false;
    shotFailed = false;
    projectile = null;
    notifyListeners();
  }

  void restartShot() {
    projectile = null;
    shotFailed = false;
    notifyListeners();
  }

  void restartGame() {
    levelIndex = 0;
    angleDegrees = 45;
    attemptsThisLevel = 0;
    score = 0;
    levelComplete = false;
    allComplete = false;
    shotFailed = false;
    projectile = null;
    notifyListeners();
  }
}
