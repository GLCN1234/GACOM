import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The Cadet Commander. Moves continuously in [moveDirection] (set every
/// frame from the virtual joystick), clamped to stay inside [worldBounds].
/// Plain vector math only — no Flame effects/animation package dependency.
class PlayerComponent extends PositionComponent {
  PlayerComponent({required Vector2 startPosition, required this.worldBounds})
      : super(position: startPosition, size: Vector2(30, 30), anchor: Anchor.center);

  final Vector2 worldBounds;
  Vector2 moveDirection = Vector2.zero();
  static const double speed = 140; // pixels per second
  static const double _deadzone = 0.12;

  @override
  void update(double dt) {
    super.update(dt);
    if (moveDirection.length <= _deadzone) return;
    final normalized = moveDirection.normalized();
    position += normalized * speed * dt;
    position.x = position.x.clamp(size.x / 2, worldBounds.x - size.x / 2);
    position.y = position.y.clamp(size.y / 2, worldBounds.y - size.y / 2);
  }

  @override
  void render(Canvas canvas) {
    // Placeholder mark standing in for real character art — a glowing
    // core with a directional facing notch, at least reads as "a unit"
    // rather than a bare debug shape.
    final center = Offset(size.x / 2, size.y / 2);
    final glow = Paint()
      ..color = const Color(0xFF3DD6FF).withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, size.x / 2 + 4, glow);

    final body = Paint()..color = const Color(0xFFFF6B1A);
    canvas.drawCircle(center, size.x / 2, body);

    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size.x / 2, outline);

    if (moveDirection.length > _deadzone) {
      final dir = moveDirection.normalized();
      final tip = center + Offset(dir.x, dir.y) * (size.x / 2 + 6);
      final facing = Paint()..color = const Color(0xFF3DD6FF);
      canvas.drawCircle(tip, 3, facing);
    }
  }
}
