import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'player_component.dart';
import 'environment_component.dart';
import 'power_cell_component.dart';
import 'reactor_core_component.dart';
import 'transporter_component.dart';

/// Colony Siege v3: collecting pods, LOADING them onto a Transporter (a
/// distinct step from collection), and LAUNCHING it — the Transporter
/// then physically drives itself across the world and delivers
/// automatically on arrival, rather than the player instantly depositing
/// on tap. This is the genuinely different verb loop the brief called
/// for: collect → load → launch → watch it arrive, not collect → deposit.
class ColonySiegeGame extends FlameGame {
  ColonySiegeGame({
    required this.requiredTotal,
    required this.onNearTransporterChanged,
    required this.onHeldPodsChanged,
    required this.onTransporterLoadChanged,
    required this.onTransporterDrivingChanged,
    required this.onReceivedChanged,
    required this.onOverload,
    required this.onLevelComplete,
  });

  final int requiredTotal;
  final void Function(bool isNear) onNearTransporterChanged;
  final void Function(List<int> held) onHeldPodsChanged;
  final void Function(int loaded) onTransporterLoadChanged;
  final void Function(bool driving) onTransporterDrivingChanged;
  final void Function(int total) onReceivedChanged;
  final void Function() onOverload;
  final void Function() onLevelComplete;

  late final PlayerComponent player;
  late final ReactorCoreComponent reactor;
  late final TransporterComponent transporter;
  late final Vector2 _dockPosition;
  final List<PowerCellComponent> _pods = [];
  final List<int> _heldPods = [];
  int _received = 0;
  bool _wasNearTransporter = false;
  bool _wasDriving = false;
  bool _done = false;

  static const double _pickupRadius = 26;
  static const double _transporterRadius = 50;

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
    reactor = ReactorCoreComponent(position: Vector2(worldSize.x * 0.6, worldSize.y * 0.22));
    _dockPosition = Vector2(worldSize.x * 0.6, worldSize.y * 0.55);
    transporter = TransporterComponent(position: _dockPosition.clone());
    player = PlayerComponent(startPosition: Vector2(worldSize.x * 0.3, worldSize.y * 0.85), worldBounds: worldSize);
    add(reactor);
    add(transporter);
    _spawnPods(worldSize);
    add(player);
  }

  void _spawnPods(Vector2 worldSize) {
    for (final p in List<PowerCellComponent>.from(_pods)) {
      remove(p);
    }
    _pods.clear();
    final positions = [
      Vector2(worldSize.x * 0.16, worldSize.y * 0.62),
      Vector2(worldSize.x * 0.82, worldSize.y * 0.8),
      Vector2(worldSize.x * 0.35, worldSize.y * 0.5),
      Vector2(worldSize.x * 0.88, worldSize.y * 0.45),
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

  /// Transfers everything currently held into the Transporter — a
  /// distinct action from collecting, requiring the player to physically
  /// bring pods back to the dock.
  void loadTransporter() {
    if (_heldPods.isEmpty || transporter.driving || _done) return;
    final sum = _heldPods.fold<int>(0, (a, b) => a + b);
    _heldPods.clear();
    onHeldPodsChanged(List.unmodifiable(_heldPods));
    transporter.loadedValue += sum;
    onTransporterLoadChanged(transporter.loadedValue);
  }

  /// Sends the Transporter driving toward the Reactor. Delivery is
  /// resolved automatically on arrival, not on this call.
  void launchTransporter() {
    if (transporter.loadedValue <= 0 || transporter.driving || _done) return;
    transporter.launchTowards(reactor.position);
    onTransporterDrivingChanged(true);
  }

  void _resolveArrival() {
    final delivered = transporter.loadedValue;
    transporter.loadedValue = 0;
    transporter.position = _dockPosition.clone();
    onTransporterLoadChanged(0);
    onTransporterDrivingChanged(false);
    _received += delivered;

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

    final isNear = (player.position - transporter.position).length < _transporterRadius;
    if (isNear != _wasNearTransporter) {
      _wasNearTransporter = isNear;
      onNearTransporterChanged(isNear);
    }

    if (_wasDriving && !transporter.driving && transporter.hasArrived) {
      _wasDriving = false;
      _resolveArrival();
    } else if (transporter.driving) {
      _wasDriving = true;
    }
  }
}
