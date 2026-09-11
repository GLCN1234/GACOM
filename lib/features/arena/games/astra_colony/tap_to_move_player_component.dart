import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A tap-to-move unit. Distinct from the joystick-driven PlayerComponent
/// used elsewhere — Colony Siege's control scheme is tactical
/// point-and-dispatch, not direct steering, so it gets its own movement
/// component rather than sharing one.
class TapToMovePlayerComponent extends PositionComponent {
  TapToMovePlayerComponent({required Vector2 startPosition, required this.worldBounds})
      : super(position: startPosition, size: Vector2(26, 26), anchor: Anchor.center);

  final Vector2 worldBounds;
  Vector2? targetPosition;
  VoidCallback? onArrive;
  static const double speed = 150;

  @override
  void update(double dt) {
    super.update(dt);
    final target = targetPosition;
    if (target == null) return;
    final diff = target - position;
    final dist = diff.length;
    if (dist < 5) {
      position = target;
      targetPosition = null;
      final cb = onArrive;
      onArrive = null;
      cb?.call();
    } else {
      position += (diff / dist) * speed * dt;
      position.x = position.x.clamp(size.x / 2, worldBounds.x - size.x / 2);
      position.y = position.y.clamp(size.y / 2, worldBounds.y - size.y / 2);
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    // A diamond silhouette — reads as an RTS/tactical unit marker,
    // deliberately different from the round orb used by joystick games.
    final path = Path()
      ..moveTo(center.dx, 2)
      ..lineTo(size.x - 2, center.dy)
      ..lineTo(center.dx, size.y - 2)
      ..lineTo(2, center.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFA940));
    canvas.drawPath(path, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);

    if (targetPosition != null) {
      final glow = Paint()
        ..color = const Color(0xFFFFA940).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, size.x / 2 + 3, glow);
    }
  }
}
