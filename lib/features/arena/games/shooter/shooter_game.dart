import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

/// A top-down survival shooter: joystick to move, auto-fires at the
/// nearest enemy. No networking at all — this is the free, fully local
/// single-player mode. The same PlayerComponent/BulletComponent/
/// EnemyComponent classes are reused for the (separate, not-yet-built)
/// real-time duel mode, which will sync state over Supabase Realtime
/// Broadcast rather than anything in this file.
class ShooterGame extends FlameGame
    with HasCollisionDetection, DragCallbacks {
  int score = 0;
  int wave = 1;
  double health = 100;
  bool gameOver = false;

  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> waveNotifier = ValueNotifier(1);
  final ValueNotifier<double> healthNotifier = ValueNotifier(100);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier(false);

  late PlayerComponent player;
  late JoystickComponent joystick;
  double _spawnTimer = 0;
  double _waveTimer = 0;
  static const _waveDuration = 20.0; // seconds per wave, gets harder each wave

  @override
  Color backgroundColor() => const Color(0xFF0B0B0F);

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

    player = PlayerComponent()..position = size / 2;

    addAll([joystick, player]);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver) return;

    // Move player from joystick input
    if (!joystick.delta.isZero()) {
      player.position += joystick.relativeDelta * player.speed * dt;
      player.position.clamp(Vector2.zero(), size);
    }

    // Spawn enemies over time, faster/tougher each wave
    _spawnTimer += dt;
    final spawnInterval = max(0.4, 2.0 - (wave * 0.15));
    if (_spawnTimer >= spawnInterval) {
      _spawnTimer = 0;
      _spawnEnemy();
    }

    // Wave progression
    _waveTimer += dt;
    if (_waveTimer >= _waveDuration) {
      _waveTimer = 0;
      wave++;
      waveNotifier.value = wave;
    }
  }

  void _spawnEnemy() {
    // Spawn just outside the visible screen, on a random edge
    final rng = Random();
    final edge = rng.nextInt(4);
    late Vector2 pos;
    switch (edge) {
      case 0: pos = Vector2(rng.nextDouble() * size.x, -30); break;
      case 1: pos = Vector2(size.x + 30, rng.nextDouble() * size.y); break;
      case 2: pos = Vector2(rng.nextDouble() * size.x, size.y + 30); break;
      default: pos = Vector2(-30, rng.nextDouble() * size.y); break;
    }
    add(EnemyComponent(startHealth: 20 + (wave * 5))..position = pos);
  }

  void addScore(int points) {
    score += points;
    scoreNotifier.value = score;
  }

  void takeDamage(double amount) {
    if (gameOver) return;
    health -= amount;
    healthNotifier.value = health.clamp(0, 100);
    if (health <= 0) {
      gameOver = true;
      gameOverNotifier.value = true;
      pauseEngine();
    }
  }
}

class PlayerComponent extends CircleComponent
    with HasGameRef<ShooterGame>, CollisionCallbacks {
  double speed = 200;
  double _fireCooldown = 0;
  static const _fireRate = 0.35; // seconds between shots

  PlayerComponent()
      : super(radius: 16, paint: Paint()..color = const Color(0xFFFF9500));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
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
        gameRef.add(BulletComponent(direction: dir)..position = position.clone());
      }
    }
  }

  EnemyComponent? _findNearestEnemy() {
    EnemyComponent? nearest;
    double nearestDist = double.infinity;
    for (final e in gameRef.children.whereType<EnemyComponent>()) {
      final d = e.position.distanceToSquared(position);
      if (d < nearestDist) { nearestDist = d; nearest = e; }
    }
    return nearest;
  }
}

class BulletComponent extends CircleComponent
    with HasGameRef<ShooterGame>, CollisionCallbacks {
  final Vector2 direction;
  static const _speed = 420.0;
  double _life = 1.5; // seconds before despawning, in case it never hits anything

  BulletComponent({required this.direction})
      : super(radius: 4, paint: Paint()..color = const Color(0xFF3D8BFF));

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
    if (other is EnemyComponent) {
      other.takeDamage(10);
      removeFromParent();
    }
  }
}

class EnemyComponent extends CircleComponent
    with HasGameRef<ShooterGame>, CollisionCallbacks {
  double health;
  final double maxHealth;
  static const _speed = 60.0;

  EnemyComponent({required double startHealth})
      : health = startHealth,
        maxHealth = startHealth,
        super(radius: 14, paint: Paint()..color = const Color(0xFFFF453A));

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    final dir = (gameRef.player.position - position).normalized();
    position += dir * _speed * dt;
  }

  void takeDamage(double amount) {
    health -= amount;
    if (health <= 0) {
      gameRef.addScore(10);
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is PlayerComponent) {
      gameRef.takeDamage(15);
      removeFromParent();
    }
  }
}
