import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'player_component.dart';
import 'solar_array_component.dart';

/// The "Arrival" mission world: a small, non-scrolling colony area (kept
/// deliberately simple for this first playable slice — camera-follow and
/// a larger scrolling map are natural next steps once this is validated).
/// Tap anywhere to walk there; tap near the Solar Array to walk to it and
/// trigger the repair sequence once you arrive.
class AstraColonyGame extends FlameGame with TapCallbacks {
  AstraColonyGame({required this.onReachSolarArray});

  final VoidCallback onReachSolarArray;
  late final PlayerComponent player;
  late final SolarArrayComponent solarArray;

  static const double _interactionRadius = 46;

  @override
  Color backgroundColor() => const Color(0xFF0B0B0F);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    solarArray = SolarArrayComponent(position: Vector2(size.x * 0.6, size.y * 0.3));
    player = PlayerComponent(startPosition: Vector2(size.x * 0.3, size.y * 0.7));
    add(solarArray);
    add(player);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final tapPos = event.localPosition;
    final distToArray = (tapPos - solarArray.position).length;

    if (distToArray < _interactionRadius && !solarArray.repaired) {
      player.targetPosition = solarArray.position.clone();
      player.onArrive = onReachSolarArray;
    } else {
      player.targetPosition = tapPos.clone();
      player.onArrive = null;
    }
  }
}
