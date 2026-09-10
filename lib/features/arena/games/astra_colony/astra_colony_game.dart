import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'player_component.dart';
import 'solar_array_component.dart';
import 'environment_component.dart';

/// The "Arrival" mission world. The player walks freely via a virtual
/// joystick; getting close to the Solar Array surfaces a context-sensitive
/// INTERACT prompt (handled by the hosting screen) instead of the old
/// tap-to-walk-and-auto-trigger pattern.
class AstraColonyGame extends FlameGame {
  AstraColonyGame({required this.onProximityChanged});

  /// Called only when "near the Solar Array" actually changes, not every
  /// frame — avoids spamming the hosting widget's setState.
  final void Function(bool isNear) onProximityChanged;

  late final PlayerComponent player;
  late final SolarArrayComponent solarArray;
  bool _wasNear = false;

  static const double _interactionRadius = 60;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final worldSize = size.clone();
    add(EnvironmentComponent(worldSize: worldSize));
    solarArray = SolarArrayComponent(position: Vector2(worldSize.x * 0.6, worldSize.y * 0.32));
    player = PlayerComponent(startPosition: Vector2(worldSize.x * 0.3, worldSize.y * 0.78), worldBounds: worldSize);
    add(solarArray);
    add(player);
  }

  void setMoveDirection(Vector2 direction) {
    // Guard: the joystick can send input before Flame's async onLoad()
    // has finished setting up `player` — this is the same class of bug
    // that caused an earlier LateInitializationError crash. isLoaded is
    // Flame's own built-in readiness flag.
    if (!isLoaded) return;
    player.moveDirection = direction;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final isNear = (player.position - solarArray.position).length < _interactionRadius && !solarArray.repaired;
    if (isNear != _wasNear) {
      _wasNear = isNear;
      onProximityChanged(isNear);
    }
  }
}
