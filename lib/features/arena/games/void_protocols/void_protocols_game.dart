import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import 'package:flutter/material.dart';

/// Void Protocols: Entropy Breach — a top-down physics shooter. The
/// Physics mechanic: beams carry one of three frequencies (Red/Blue/
/// Green); a Paradox Entity only takes full damage from a beam that
/// matches its own frequency, chip damage otherwise — the actual
/// "match the frequency phase to land critical damage" concept from
/// the design doc, made into a real, playable rule rather than flavor
/// text. The Math/CS mechanic: periodic "power nodes" pause the fight
/// for a short vector-alignment puzzle (rotate to a target angle).
class VoidProtocolsGame extends FlameGame with HasCollisionDetection, DragCallbacks {
  int score = 0;
  int wave = 1;
  double health = 100;
  bool gameOver = false;
  int currentFrequency = 0; // 0=Red, 1=Blue, 2=Green
  double freezeCooldown = 0;
  static const freezeCooldownMax = 8.0;
  static const freezeDuration = 3.0;

  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> waveNotifier = ValueNotifier(1);
  final ValueNotifier<double> healthNotifier = ValueNotifier(100);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier(false);
  final ValueNotifier<int> frequencyNotifier = ValueNotifier(0);
  final ValueNotifier<double> freezeCooldownNotifier = ValueNotifier(0);
  final ValueNotifier<bool> puzzleActiveNotifier = ValueNotifier(false);
  final ValueNotifier<bool> shieldActiveNotifier = ValueNotifier(false);

  static const frequencyColors = [Color(0xFFFF453A), Color(0xFF3D8BFF), Color(0xFF34D399)];
  static const frequencyNames = ['RED', 'BLUE', 'GREEN'];

  late DroneComponent player;
  late JoystickComponent joystick;
  double _spawnTimer = 0;
  double _waveTimer = 0;
  double _nodeTimer = 0;
  static const _waveDuration = 20.0;
  static const _nodeInterval = 25.0;
  bool _shieldUp = false;

  @override
  Color backgroundColor() => const Color(0xFF060614);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final knobPaint = Paint()..color = Colors.white.withOpacity(0.8);
    final backgroundPaint = Paint()..color = Colors.white.withOpacity(0.2);

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 50, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 32, bottom: 32),
    );

    player = DroneComponent()..position = size / 2;

    addAll([joystick, player]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver || puzzleActiveNotifier.value) return;

    if (!joystick.delta.isZero()) {
      player.position += joystick.relativeDelta * player.speed * dt;
      player.position.clamp(Vector2.zero(), size);
    }

    _spawnTimer += dt;
    final spawnInterval = max(0.5, 2.2 - (wave * 0.15));
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnEnemy();
    }

    _waveTimer += dt;
    if (_waveTimer >= _waveDuration) {
      _waveTimer = 0;
      wave++;
      waveNotifier.value = wave;
    }

    _nodeTimer += dt;
    if (_nodeTimer >= _nodeInterval && !children.whereType<PowerNodeComponent>().isNotEmpty) {
      _nodeTimer = 0;
      _spawnPowerNode();
    }

    if (freezeCooldown > 0) {
      freezeCooldown -= dt;
      freezeCooldownNotifier.value = freezeCooldown.clamp(0, freezeCooldownMax);
    }
  }

  void _spawnEnemy() {
    final rng = Random();
    final edge = rng.nextInt(4);
    late Vector2 pos;
    switch (edge) {
      case 0: pos = Vector2(rng.nextDouble() * size.x, -30); break;
      case 1: pos = Vector2(size.x + 30, rng.nextDouble() * size.y); break;
      case 2: pos = Vector2(rng.nextDouble() * size.x, size.y + 30); break;
      default: pos = Vector2(-30, rng.nextDouble() * size.y); break;
    }
    final freq = rng.nextInt(3);
    add(ParadoxEntityComponent(startHealth: 24 + (wave * 4), frequency: freq)..position = pos);
  }

  void _spawnPowerNode() {
    final rng = Random();
    final pos = Vector2(
      40 + rng.nextDouble() * (size.x - 80),
      40 + rng.nextDouble() * (size.y - 80),
    );
    add(PowerNodeComponent()..position = pos);
  }

  void cycleFrequency() {
    currentFrequency = (currentFrequency + 1) % 3;
    frequencyNotifier.value = currentFrequency;
    SoundService.instance.playTap();
  }

  void activateFreeze() {
    if (freezeCooldown > 0 || gameOver) return;
    freezeCooldown = freezeCooldownMax;
    for (final e in children.whereType<ParadoxEntityComponent>()) {
      e.frozenTimer = freezeDuration;
    }
    SoundService.instance.playCorrect();
  }

  void triggerPuzzle() {
    puzzleActiveNotifier.value = true;
  }

  void resolvePuzzle(bool success) {
    puzzleActiveNotifier.value = false;
    if (success) {
      _shieldUp = true;
      shieldActiveNotifier.value = true;
      addScore(50);
      SoundService.instance.playWin();
    }
  }

  void addScore(int points) {
    score += points;
    scoreNotifier.value = score;
  }

  void takeDamage(double amount) {
    if (gameOver) return;
    if (_shieldUp) {
      _shieldUp = false;
      shieldActiveNotifier.value = false;
      SoundService.instance.playCorrect();
      return;
    }
    health -= amount;
    healthNotifier.value = health.clamp(0, 100);
    SoundService.instance.playWrong();
    if (health <= 0) {
      gameOver = true;
      gameOverNotifier.value = true;
      SoundService.instance.playLose();
      GameScoreService.save(gameName: 'Void Protocols', score: score);
      pauseEngine();
    }
  }
}

/// The player's containment drone — a geometric, non-humanoid avatar
/// (a diamond, not a circle, to read distinctly from Survival
/// Shooter's player at a glance).
class DroneComponent extends PositionComponent
    with HasGameRef<VoidProtocolsGame>, CollisionCallbacks {
  double speed = 210;
  double _fireCooldown = 0;
  static const _fireRate = 0.3;

  DroneComponent() : super(size: Vector2.all(32), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFFE2E8F0);
    final glow = Paint()
      ..color = VoidProtocolsGame.frequencyColors[gameRef.currentFrequency].withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final path = Path()
      ..moveTo(16, 0)
      ..lineTo(32, 16)
      ..lineTo(16, 32)
      ..lineTo(0, 16)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(path, glow);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fireCooldown -= dt;
    if (_fireCooldown <= 0) {
      final target = _findNearestEnemy();
      if (target != null) {
        _fireCooldown = _fireRate;
        final dir = (target.position - position).normalized();
        gameRef.add(BeamComponent(direction: dir, frequency: gameRef.currentFrequency)
          ..position = position.clone());
        SoundService.instance.playShoot();
      }
    }
  }

  ParadoxEntityComponent? _findNearestEnemy() {
    ParadoxEntityComponent? nearest;
    double nearestDist = double.infinity;
    for (final e in gameRef.children.whereType<ParadoxEntityComponent>()) {
      final d = e.position.distanceToSquared(position);
      if (d < nearestDist) { nearestDist = d; nearest = e; }
    }
    return nearest;
  }
}

class BeamComponent extends CircleComponent
    with HasGameRef<VoidProtocolsGame>, CollisionCallbacks {
  final Vector2 direction;
  final int frequency;
  static const _speed = 440.0;
  double _life = 1.5;

  BeamComponent({required this.direction, required this.frequency})
      : super(radius: 4, paint: Paint()..color = VoidProtocolsGame.frequencyColors[frequency]);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += direction * _speed * dt;
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is ParadoxEntityComponent) {
      final matched = frequency == other.frequency;
      other.takeDamage(matched ? 25 : 5, matched);
      removeFromParent();
    }
  }
}

/// A "Paradox Entity" — crystalline, geometric, colored by its
/// frequency. Full damage only from a matching-frequency beam; chip
/// damage otherwise, so matching frequencies is a real, felt rule.
class ParadoxEntityComponent extends PositionComponent
    with HasGameRef<VoidProtocolsGame>, CollisionCallbacks {
  double health;
  final double maxHealth;
  final int frequency;
  double frozenTimer = 0;
  static const _speed = 55.0;

  ParadoxEntityComponent({required double startHealth, required this.frequency})
      : health = startHealth,
        maxHealth = startHealth,
        super(size: Vector2.all(28), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final color = VoidProtocolsGame.frequencyColors[frequency];
    final paint = Paint()..color = frozenTimer > 0 ? color.withOpacity(0.35) : color;
    final path = Path()
      ..moveTo(14, 0)
      ..lineTo(28, 14)
      ..lineTo(14, 28)
      ..lineTo(0, 14)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (frozenTimer > 0) { frozenTimer -= dt; return; }
    final dir = (gameRef.player.position - position).normalized();
    position += dir * _speed * dt;
  }

  void takeDamage(double amount, bool wasMatched) {
    health -= amount;
    if (wasMatched) SoundService.instance.playCorrect();
    if (health <= 0) {
      gameRef.addScore(wasMatched ? 15 : 8);
      SoundService.instance.playExplosion();
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is DroneComponent && frozenTimer <= 0) {
      gameRef.takeDamage(14);
      removeFromParent();
    }
  }
}

/// A "power node" — the Math/CS interlude trigger. Flying into it
/// pauses combat for a short vector-alignment puzzle (handled by the
/// screen's overlay, not drawn here).
class PowerNodeComponent extends PositionComponent
    with HasGameRef<VoidProtocolsGame>, CollisionCallbacks {
  double _pulse = 0;

  PowerNodeComponent() : super(size: Vector2.all(22), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 4;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = 1 + (sin(_pulse) * 0.15);
    final paint = Paint()..color = const Color(0xFFFFD700).withOpacity(0.85);
    canvas.drawCircle(Offset(11, 11), 11 * scale, paint);
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is DroneComponent) {
      gameRef.triggerPuzzle();
      removeFromParent();
    }
  }
}
