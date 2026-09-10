import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// The Reactor Core — the delivery target for fuel pods. Dim and inert
/// until powered, then solidifies and glows. Visually distinct from the
/// Solar Array (used by the Astra Colony story mission) since this is the
/// general-purpose Colony Siege delivery point, reused across all 20
/// levels with different targets.
class ReactorCoreComponent extends PositionComponent {
  ReactorCoreComponent({required Vector2 position})
      : super(position: position, size: Vector2(84, 70), anchor: Anchor.center);

  bool powered = false;

  @override
  void render(Canvas canvas) {
    final core = powered ? const Color(0xFF3DD6FF) : const Color(0xFF3A4260);
    final ring = powered ? Colors.white : const Color(0xFF565F80);

    // Outer housing.
    final housing = RRect.fromRectAndRadius(Rect.fromLTWH(0, 8, size.x, size.y - 8), const Radius.circular(10));
    canvas.drawRRect(housing, Paint()..color = const Color(0xFF1C2438));
    canvas.drawRRect(housing, Paint()..color = ring.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Inner core.
    final center = Offset(size.x / 2, size.y / 2 + 6);
    canvas.drawCircle(center, size.x * 0.26, Paint()..color = core.withOpacity(powered ? 0.9 : 0.5));
    canvas.drawCircle(center, size.x * 0.26, Paint()..color = ring..style = PaintingStyle.stroke..strokeWidth = 2);

    if (powered) {
      final glow = Paint()
        ..color = const Color(0xFF3DD6FF).withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(center, size.x * 0.34, glow);
    }

    // Support struts.
    final strut = Paint()..color = const Color(0xFF2A3452);
    canvas.drawRect(Rect.fromLTWH(size.x * 0.1, size.y - 8, 6, 8), strut);
    canvas.drawRect(Rect.fromLTWH(size.x * 0.85, size.y - 8, 6, 8), strut);
  }
}
