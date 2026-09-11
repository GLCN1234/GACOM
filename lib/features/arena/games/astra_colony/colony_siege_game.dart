import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'tap_to_move_player_component.dart';
import 'environment_component.dart';
import 'power_cell_component.dart';
import 'reactor_core_component.dart';

/// Colony Siege v4: tactical point-and-dispatch, not steering. Tap a fuel
/// pod to send your unit to collect it into the dock tray; tap a tray
/// slot to select it; tap the Reactor to dispatch your unit to deliver
/// it. No joystick, no corner HUD — status lives as a diegetic label
/// floating above the Reactor itself.
class ColonySiegeGame extends FlameGame with TapCallbacks {
  ColonySiegeGame({
    required this.requiredTotal,
    required this.onDockChanged,
    required this.onReceivedChanged,
    required this.onOverload,
    required this.onLevelComplete,
  });

  final int requiredTotal;
  final void Function(List<int> dock) onDockChanged;
  final void Function(int total) onReceivedChanged;
  final void Function() onOverload;
  final void Function() onLevelComplete;

  late final TapToMovePlayerComponent player;
  late final ReactorCoreComponent reactor;
  final List<PowerCellComponent> _pods = [];
  final List<int> _dock = [];
  int? _selectedDockIndex;
  int _received = 0;
  bool _done = false;

  static const double _tapHitRadius = 28;

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
    reactor = ReactorCoreComponent(position: Vector2(worldSize.x * 0.55, worldSize.y * 0.25));
    _updateReactorLabel();
    player = TapToMovePlayerComponent(startPosition: Vector2(worldSize.x * 0.3, worldSize.y * 0.8), worldBounds: worldSize);
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
      Vector2(worldSize.x * 0.18, worldSize.y * 0.55),
      Vector2(worldSize.x * 0.8, worldSize.y * 0.7),
      Vector2(worldSize.x * 0.4, worldSize.y * 0.45),
      Vector2(worldSize.x * 0.82, worldSize.y * 0.35),
    ];
    final values = _podValues;
    for (var i = 0; i < values.length; i++) {
      final pod = PowerCellComponent(position: positions[i], value: values[i]);
      _pods.add(pod);
      add(pod);
    }
  }

  void _updateReactorLabel() {
    reactor.needsLabel = _done ? 'POWERED' : 'NEEDS: ${requiredTotal - _received}';
  }

  /// Called by the hosting screen when a dock tray card is tapped.
  void selectDockPod(int index) {
    if (index < 0 || index >= _dock.length) return;
    _selectedDockIndex = index;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (!isLoaded || _done) return;
    final tapPos = event.localPosition;

    // 1. Tapped an uncollected pod → walk there, collect on arrival.
    for (final pod in _pods) {
      if (pod.collected) continue;
      if ((tapPos - pod.position).length < _tapHitRadius) {
        player.targetPosition = pod.position.clone();
        player.onArrive = () {
          pod.collected = true;
          remove(pod);
          _dock.add(pod.value);
          onDockChanged(List.unmodifiable(_dock));
        };
        return;
      }
    }

    // 2. Tapped the Reactor with a dock pod selected → walk there, deliver on arrival.
    if ((tapPos - reactor.position).length < _tapHitRadius + 16 && _selectedDockIndex != null) {
      final index = _selectedDockIndex!;
      player.targetPosition = reactor.position.clone();
      player.onArrive = () => _deliverDockPod(index);
      return;
    }

    // 3. Otherwise, plain tap-to-move on open floor.
    player.targetPosition = tapPos.clone();
    player.onArrive = null;
  }

  void _deliverDockPod(int index) {
    if (index < 0 || index >= _dock.length) return;
    final value = _dock.removeAt(index);
    _selectedDockIndex = null;
    onDockChanged(List.unmodifiable(_dock));
    _received += value;

    if (_received == requiredTotal) {
      _done = true;
      reactor.powered = true;
      _updateReactorLabel();
      onReceivedChanged(_received);
      onLevelComplete();
    } else if (_received > requiredTotal) {
      _received = 0;
      _updateReactorLabel();
      onReceivedChanged(0);
      onOverload();
      _spawnPods(size.clone());
    } else {
      _updateReactorLabel();
      onReceivedChanged(_received);
    }
  }
}
