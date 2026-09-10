import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'player_component.dart';
import 'solar_array_component.dart';
import 'environment_component.dart';
import 'power_cell_component.dart';

/// The "Arrival" mission world. Power cells are scattered in the world
/// with visible values; walking over one collects it automatically. Near
/// the Reactor Console (by the Solar Array), depositing held cells adds
/// their sum toward the required total — hit it exactly to succeed,
/// overshoot it and the console overloads and resets. The math IS the
/// walking, choosing, and depositing — never a popup with buttons.
class AstraColonyGame extends FlameGame {
  AstraColonyGame({
    required this.onNearConsoleChanged,
    required this.onHeldCellsChanged,
    required this.onReceivedTotalChanged,
    required this.onOverload,
    required this.onMissionComplete,
    required this.requiredTotal,
  });

  final void Function(bool isNear) onNearConsoleChanged;
  final void Function(List<int> held) onHeldCellsChanged;
  final void Function(int total) onReceivedTotalChanged;
  final void Function() onOverload;
  final void Function() onMissionComplete;
  final int requiredTotal;

  late final PlayerComponent player;
  late final SolarArrayComponent solarArray;
  final List<PowerCellComponent> _cells = [];
  final List<int> _heldCells = [];
  int _receivedTotal = 0;
  bool _wasNearConsole = false;
  bool _missionDone = false;

  static const double _pickupRadius = 26;
  static const double _consoleRadius = 64;

  // Two cells that combine to exactly the required total, plus two
  // decoys that would overshoot it if deposited — genuine spatial choice.
  List<int> get _cellValues {
    final half1 = (requiredTotal * 0.6).round();
    final half2 = requiredTotal - half1;
    return [half1, half2, requiredTotal + 9, requiredTotal + 4];
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final worldSize = size.clone();
    add(EnvironmentComponent(worldSize: worldSize));
    solarArray = SolarArrayComponent(position: Vector2(worldSize.x * 0.6, worldSize.y * 0.32));
    player = PlayerComponent(startPosition: Vector2(worldSize.x * 0.3, worldSize.y * 0.85), worldBounds: worldSize);
    add(solarArray);
    _spawnCells(worldSize);
    add(player);
  }

  void _spawnCells(Vector2 worldSize) {
    for (final c in List<PowerCellComponent>.from(_cells)) {
      remove(c);
    }
    _cells.clear();
    final positions = [
      Vector2(worldSize.x * 0.18, worldSize.y * 0.6),
      Vector2(worldSize.x * 0.75, worldSize.y * 0.78),
      Vector2(worldSize.x * 0.45, worldSize.y * 0.55),
      Vector2(worldSize.x * 0.85, worldSize.y * 0.45),
    ];
    for (var i = 0; i < _cellValues.length; i++) {
      final cell = PowerCellComponent(position: positions[i], value: _cellValues[i]);
      _cells.add(cell);
      add(cell);
    }
  }

  void setMoveDirection(Vector2 direction) {
    if (!isLoaded) return;
    player.moveDirection = direction;
  }

  /// Deposits everything currently held. Called by the hosting screen when
  /// the player taps DEPOSIT while near the console.
  void depositHeldCells() {
    if (_heldCells.isEmpty || _missionDone) return;
    final sum = _heldCells.fold<int>(0, (a, b) => a + b);
    _heldCells.clear();
    onHeldCellsChanged(List.unmodifiable(_heldCells));
    _receivedTotal += sum;

    if (_receivedTotal == requiredTotal) {
      _missionDone = true;
      solarArray.repaired = true;
      onReceivedTotalChanged(_receivedTotal);
      onMissionComplete();
    } else if (_receivedTotal > requiredTotal) {
      _receivedTotal = 0;
      onReceivedTotalChanged(0);
      onOverload();
      _spawnCells(size.clone());
    } else {
      onReceivedTotalChanged(_receivedTotal);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded || _missionDone) return;

    // Auto-pickup: walking over an uncollected cell picks it up.
    for (final cell in _cells) {
      if (cell.collected) continue;
      if ((player.position - cell.position).length < _pickupRadius) {
        cell.collected = true;
        remove(cell);
        _heldCells.add(cell.value);
        onHeldCellsChanged(List.unmodifiable(_heldCells));
      }
    }

    final isNear = (player.position - solarArray.position).length < _consoleRadius;
    if (isNear != _wasNearConsole) {
      _wasNearConsole = isNear;
      onNearConsoleChanged(isNear);
    }
  }
}
