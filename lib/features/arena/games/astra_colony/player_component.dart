import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The Cadet Commander. Moves toward [targetPosition] at a fixed speed,
/// set by tapping anywhere in the world. Deliberately implemented with
/// plain vector math in [update] rather than Flame's effects package, to
/// keep this on the most stable, predictable part of the Flame API.
class PlayerComponent extends PositionComponent {
  PlayerComponent({required Vector2 startPosition})
      : super(position: startPosition, size: Vector2(28, 28), anchor: Anchor.center);

  Vector2? targetPosition;
  VoidCallback? onArrive;
  static const double speed = 130; // pixels per second

  @override
  void update(double dt) {
    super.update(dt);
    final target = targetPosition;
    if (target == null) return;
    final diff = target - position;
    final dist = diff.length;
    if (dist < 4) {
      position = target;
      targetPosition = null;
      final cb = onArrive;
      onArrive = null;
      cb?.call();
    } else {
      final dir = diff / dist;
      position += dir * speed * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    // Simple placeholder mark — a solid circle with a directional notch —
    // stands in for real character sprite art until that asset exists.
    final body = Paint()..color = const Color(0xFFFF6B1A);
    final outline = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(center, size.x / 2, body);
    canvas.drawCircle(center, size.x / 2, outline);
  }
}
