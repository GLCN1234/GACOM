import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import '../../../../core/services/sound_service.dart';
import '../../../../core/services/game_score_service.dart';
import 'package:flutter/material.dart';

/// Chrono-Spire: The Cellular Siege — a top-down twin-stick shooter.
/// The Chemistry mechanic: payloads (Acid/Thermal/Electro) actually
/// react — hitting an enemy with Acid, then Thermal within a short
/// window, triggers a real exothermic AOE explosion, the "spray acid
/// then thermal for a combo" concept made into a felt rule. The
/// Biology mechanic: every bio-beast has one visible weak point —
/// nervous (slows it) or respiratory (disables its attack) — so
/// targeting anatomy is a real decision, not flavor text.
class ChronoSpireGame extends FlameGame with HasCollisionDetection, DragCallbacks {
  int score = 0;
  int wave = 1;
  double health = 100;
  bool gameOver = false;
  int currentPayload = 0; // 0=Acid, 1=Thermal, 2=Electro
  double dodgeCooldown = 0;
  static const dodgeCooldownMax = 6.0;
  static const dodgeDuration = 0.5;
  double _dodgeTimer = 0;
  bool _invincible = false;

  final ValueNotifier<int> scoreNotifier = ValueNotifier(0);
  final ValueNotifier<int> waveNotifier = ValueNotifier(1);
  final ValueNotifier<double> healthNotifier = ValueNotifier(100);
  final ValueNotifier<bool> gameOverNotifier = ValueNotifier(false);
  final ValueNotifier<int> payloadNotifier = ValueNotifier(0);
  final ValueNotifier<double> dodgeCooldownNotifier = ValueNotifier(0);
  final ValueNotifier<int> fireRateBuffNotifier = ValueNotifier(0); // stacks, from genetic nodes

  static const payloadColors = [Color(0xFF34D399), Color(0xFFFF9500), Color(0xFFA78BFA)];
  static const payloadNames = ['ACID', 'THERMAL', 'ELECTRO'];

  late BioDroneComponent player;
  late JoystickComponent joystick;
  double _spawnTimer = 0;
  double _waveTimer = 0;
  static const _waveDuration = 20.0;
  int _fireRateStacks = 0;

  @override
  Color backgroundColor() => const Color(0xFF0A1208);

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

    player = BioDroneComponent()..position = size / 2;

    addAll([joystick, player]);
  }

  double get fireRateMultiplier => 1.0 + (_fireRateStacks * 0.15).clamp(0, 0.6);

  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver) return;

    if (_dodgeTimer > 0) {
      _dodgeTimer -= dt;
      if (_dodgeTimer <= 0) _invincible = false;
    }

    if (!joystick.delta.isZero()) {
      final speedMult = _invincible ? 2.2 : 1.0;
      player.position += joystick.relativeDelta * player.speed * speedMult * dt;
      player.position.clamp(Vector2.zero(), size);
    }

    _spawnTimer += dt;
    final spawnInterval = max(0.4, 1.8 - (wave * 0.12));
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

    if (dodgeCooldown > 0) {
      dodgeCooldown -= dt;
      dodgeCooldownNotifier.value = dodgeCooldown.clamp(0, dodgeCooldownMax);
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
    final weakPoint = rng.nextBool() ? WeakPointType.nervous : WeakPointType.respiratory;
    add(BioBeastComponent(startHealth: 22 + (wave * 4), weakPoint: weakPoint)..position = pos);
  }

  void cyclePayload() {
    currentPayload = (currentPayload + 1) % 3;
    payloadNotifier.value = currentPayload;
    SoundService.instance.playTap();
  }

  void activateDodge() {
    if (dodgeCooldown > 0 || gameOver) return;
    dodgeCooldown = dodgeCooldownMax;
    _dodgeTimer = dodgeDuration;
    _invincible = true;
    SoundService.instance.playCorrect();
  }

  void collectGeneticNode() {
    _fireRateStacks = (_fireRateStacks + 1).clamp(0, 4);
    fireRateBuffNotifier.value = _fireRateStacks;
    addScore(5);
    SoundService.instance.playCorrect();
  }

  void addScore(int points) {
    score += points;
    scoreNotifier.value = score;
  }

  void takeDamage(double amount) {
    if (gameOver || _invincible) return;
    health -= amount;
    healthNotifier.value = health.clamp(0, 100);
    SoundService.instance.playWrong();
    if (health <= 0) {
      gameOver = true;
      gameOverNotifier.value = true;
      SoundService.instance.playLose();
      GameScoreService.save(gameName: 'Chrono-Spire', score: score);
      pauseEngine();
    }
  }
}

enum WeakPointType { nervous, respiratory }

/// The player's bio-drone — rounded and organic, distinct from Void
/// Protocols' angular drone, still fully non-humanoid.
class BioDroneComponent extends PositionComponent
    with HasGameRef<ChronoSpireGame>, CollisionCallbacks {
  double speed = 220;
  double _fireCooldown = 0;
  static const _baseFireRate = 0.28;

  BioDroneComponent() : super(size: Vector2.all(30), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFFE2E8F0);
    final glow = Paint()
      ..color = gameRef.payloadColors[gameRef.currentPayload].withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(const Rect.fromLTWH(2, 6, 26, 20), paint);
    canvas.drawOval(const Rect.fromLTWH(2, 6, 26, 20), glow);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _fireCooldown -= dt;
    final rate = _baseFireRate / gameRef.fireRateMultiplier;
    if (_fireCooldown <= 0) {
      final target = _findNearestEnemy();
      if (target != null) {
        _fireCooldown = rate;
        final dir = (target.position - position).normalized();
        gameRef.add(PayloadComponent(direction: dir, payloadType: gameRef.currentPayload)
          ..position = position.clone());
        SoundService.instance.playShoot();
      }
    }
  }

  BioBeastComponent? _findNearestEnemy() {
    BioBeastComponent? nearest;
    double nearestDist = double.infinity;
    for (final e in gameRef.children.whereType<BioBeastComponent>()) {
      final d = e.position.distanceToSquared(position);
      if (d < nearestDist) { nearestDist = d; nearest = e; }
    }
    return nearest;
  }
}

class PayloadComponent extends CircleComponent
    with HasGameRef<ChronoSpireGame>, CollisionCallbacks {
  final Vector2 direction;
  final int payloadType;
  static const _speed = 460.0;
  double _life = 1.4;

  PayloadComponent({required this.direction, required this.payloadType})
      : super(radius: 4, paint: Paint()..color = ChronoSpireGame.payloadColors[payloadType]);

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
    if (other is BioBeastComponent) {
      final hitWeakPoint = other.isHitOnWeakPoint(absoluteCenter);
      other.takeDamage(10, payloadType, hitWeakPoint, this);
      removeFromParent();
    }
  }
}

/// A "bio-beast" — organic blob shape, with one visible weak-point
/// node (colored by type) somewhere on its body. Tracks the last
/// payload type it was hit with and when, so a Thermal hit shortly
/// after an Acid hit can trigger the real exothermic combo.
class BioBeastComponent extends PositionComponent
    with HasGameRef<ChronoSpireGame>, CollisionCallbacks {
  double health;
  final double maxHealth;
  final WeakPointType weakPoint;
  double _slowTimer = 0;
  double _disableAttackTimer = 0;
  int? _lastPayloadType;
  double _lastPayloadTime = -10;
  late Vector2 _weakPointOffset;
  static const _speed = 50.0;
  static const _comboWindow = 1.2; // seconds — acid then thermal within this window combos

  BioBeastComponent({required double startHealth, required this.weakPoint})
      : health = startHealth,
        maxHealth = startHealth,
        super(size: Vector2.all(26), anchor: Anchor.center) {
    final rng = Random();
    final angle = rng.nextDouble() * 2 * pi;
    _weakPointOffset = Vector2(cos(angle), sin(angle)) * 8;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  bool isHitOnWeakPoint(Vector2 hitPoint) {
    final weakPointWorld = position + _weakPointOffset;
    return hitPoint.distanceTo(weakPointWorld) < 7;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final slowed = _slowTimer > 0;
    final paint = Paint()..color = slowed ? const Color(0xFF6B8E23).withOpacity(0.6) : const Color(0xFF6B8E23);
    canvas.drawOval(const Rect.fromLTWH(0, 0, 26, 24), paint);
    final wpColor = weakPoint == WeakPointType.nervous ? const Color(0xFFFFD700) : const Color(0xFF38BDF8);
    final center = Vector2(13, 12) + _weakPointOffset;
    canvas.drawCircle(Offset(center.x, center.y), 4, Paint()..color = wpColor);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_slowTimer > 0) _slowTimer -= dt;
    if (_disableAttackTimer > 0) _disableAttackTimer -= dt;
    final speedMult = _slowTimer > 0 ? 0.35 : 1.0;
    final dir = (gameRef.player.position - position).normalized();
    position += dir * _speed * speedMult * dt;
  }

  void takeDamage(double amount, int payloadType, bool hitWeakPoint, PayloadComponent source) {
    double totalDamage = amount;

    // The real Chemistry combo: Acid (0) then Thermal (1) within the
    // window triggers a bonus exothermic AOE explosion.
    final elapsed = DateTime.now().millisecondsSinceEpoch / 1000.0;
    if (_lastPayloadType == 0 && payloadType == 1 && (elapsed - _lastPayloadTime) < _comboWindow) {
      totalDamage += 30;
      _triggerExothermicExplosion();
    }
    _lastPayloadType = payloadType;
    _lastPayloadTime = elapsed;

    // The real Biology mechanic: hitting the visible weak point
    // applies a genuine, felt debuff matching that biological system.
    if (hitWeakPoint) {
      totalDamage += 8;
      if (weakPoint == WeakPointType.nervous) {
        _slowTimer = 2.5;
      } else {
        _disableAttackTimer = 2.5;
      }
      SoundService.instance.playCorrect();
    }

    health -= totalDamage;
    if (health <= 0) {
      gameRef.addScore(hitWeakPoint ? 18 : 12);
      SoundService.instance.playExplosion();
      if (Random().nextDouble() < 0.35) {
        gameRef.add(GeneticNodeComponent()..position = position.clone());
      }
      removeFromParent();
    }
  }

  void _triggerExothermicExplosion() {
    SoundService.instance.playExplosion();
    for (final e in gameRef.children.whereType<BioBeastComponent>().toList()) {
      if (e == this) continue;
      if (e.position.distanceTo(position) < 70) {
        e.health -= 15;
        if (e.health <= 0) {
          gameRef.addScore(12);
          e.removeFromParent();
        }
      }
    }
    gameRef.addScore(10);
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is BioDroneComponent && _disableAttackTimer <= 0) {
      gameRef.takeDamage(13);
      removeFromParent();
    }
  }
}

/// A genetic node — dropped by some defeated bio-beasts, stacks a
/// temporary fire-rate buff on pickup. The "Synthesis Harvesting"
/// mechanic from the design doc, as a real, working pickup.
class GeneticNodeComponent extends PositionComponent
    with HasGameRef<ChronoSpireGame>, CollisionCallbacks {
  double _pulse = 0;
  double _life = 6.0;

  GeneticNodeComponent() : super(size: Vector2.all(16), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulse += dt * 5;
    _life -= dt;
    if (_life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final scale = 1 + (sin(_pulse) * 0.2);
    canvas.drawCircle(Offset(8, 8), 8 * scale, Paint()..color = const Color(0xFF34D399).withOpacity(0.85));
  }

  @override
  void onCollisionStart(Set<Vector2> points, PositionComponent other) {
    super.onCollisionStart(points, other);
    if (other is BioDroneComponent) {
      gameRef.collectGeneticNode();
      removeFromParent();
    }
  }
}
