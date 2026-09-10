import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'player_component.dart';
import 'environment_component.dart';
import 'power_cell_component.dart';
import 'reactor_core_component.dart';

/// General-purpose Colony Siege engine, reused across all 20 levels with a
/// difficulty-scaled [requiredTotal]. Fuel pods (reusing the same
/// collectible component as Field Trial's power cells — value-bearing
/// glowing orbs) sit in the world; walking over one collects it. Near the
/// Reactor Core, depositing held pods adds their sum toward the target —
/// hit it exactly to power the reactor, overshoot it and the reactor
/// vents steam, blowing the pods back out into the world to retry. No
/// popup anywhere in this flow.
class ColonySiegeGame extends FlameGame {
  ColonySiegeGame({
    required this.requiredTotal,
    required this.onNearReactorChanged,
    required this.onHeldPodsChanged,
    required this.onReceivedChanged,
    required this.onOverload,
    required this.onLevelComplete,
  });

  final int requiredTotal;
  final void Function(bool isNear) onNearReactorChanged;
  final void Function(List<int> held) onHeldPodsChanged;
  final void Function(int total) onReceivedChanged;
  final void Function() onOverload;
  final void Function() onLevelComplete;

  late final PlayerComponent player;
  late final ReactorCoreComponent reactor;
  final List<PowerCellComponent> _pods = [];
  final List<int> _heldPods = [];
  int _received = 0;
  bool _wasNear = false;
  bool _done = false;

  static const double _pickupRadius = 26;
  static const double _reactorRadius = 66;

  List<int> get _podValues {
    final half1 = (requiredTotal * 0.6).round();
    final half2 = requiredTotal - half1;
    return [half1, half2, requiredTotal + 11, requiredTotal + 6];
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final worldSize = size.clone();
    add(EnvironmentComponent(worldSize: worldSize));
    reactor = ReactorCoreComponent(position: Vector2(worldSize.x * 0.6, worldSize.y * 0.32));
    player = PlayerComponent(startPosition: Vector2(worldSize.x * 0.3, worldSize.y * 0.85), worldBounds: worldSize);
    add(reactor);
    _spawnPods(worldSize);
    add(player);
  }

  void _spawnPods(Vector2 worldSize) {
    for (final p in List<PowerCellComponent>.from(_pods)) {
      remove(p);
    }
    _pods.clear();
    final positions = [
      Vector2(worldSize.x * 0.18, worldSize.y * 0.6),
      Vector2(worldSize.x * 0.75, worldSize.y * 0.78),
      Vector2(worldSize.x * 0.45, worldSize.y * 0.55),
      Vector2(worldSize.x * 0.85, worldSize.y * 0.45),
    ];
    final values = _podValues;
    for (var i = 0; i < values.length; i++) {
      final pod = PowerCellComponent(position: positions[i], value: values[i]);
      _pods.add(pod);
      add(pod);
    }
  }

  void setMoveDirection(Vector2 direction) {
    if (!isLoaded) return;
    player.moveDirection = direction;
  }

  void deliverHeldPods() {
    if (_heldPods.isEmpty || _done) return;
    final sum = _heldPods.fold<int>(0, (a, b) => a + b);
    _heldPods.clear();
    onHeldPodsChanged(List.unmodifiable(_heldPods));
    _received += sum;

    if (_received == requiredTotal) {
      _done = true;
      reactor.powered = true;
      onReceivedChanged(_received);
      onLevelComplete();
    } else if (_received > requiredTotal) {
      _received = 0;
      onReceivedChanged(0);
      onOverload();
      _spawnPods(size.clone());
    } else {
      onReceivedChanged(_received);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded || _done) return;

    for (final pod in _pods) {
      if (pod.collected) continue;
      if ((player.position - pod.position).length < _pickupRadius) {
        pod.collected = true;
        remove(pod);
        _heldPods.add(pod.value);
        onHeldPodsChanged(List.unmodifiable(_heldPods));
      }
    }

    final isNear = (player.position - reactor.position).length < _reactorRadius;
    if (isNear != _wasNear) {
      _wasNear = isNear;
      onNearReactorChanged(isNear);
    }
  }
}
