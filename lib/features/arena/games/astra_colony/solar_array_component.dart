import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A damaged Solar Array sitting in the colony world. Visually dim/grey
/// until repaired, then glows — a real environmental state change, not
/// just a UI flag.
class SolarArrayComponent extends PositionComponent {
  SolarArrayComponent({required Vector2 position})
      : super(position: position, size: Vector2(64, 48), anchor: Anchor.center);

  bool repaired = false;

  @override
  void render(Canvas canvas) {
    final base = Paint()..color = repaired ? const Color(0xFFFFC940) : const Color(0xFF4A4A55);
    final panelBorder = Paint()
      ..color = repaired ? Colors.white : const Color(0xFF6B6B78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(6));
    canvas.drawRRect(rect, base);
    canvas.drawRRect(rect, panelBorder);

    // Panel grid lines — simple, no external art required.
    final gridPaint = Paint()
      ..color = (repaired ? Colors.white : Colors.black).withOpacity(0.25)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final x = size.x / 4 * i;
      canvas.drawLine(Offset(x, 4), Offset(x, size.y - 4), gridPaint);
    }

    if (repaired) {
      // A soft glow ring to sell "powered on" without needing a sprite.
      final glow = Paint()
        ..color = const Color(0xFFFFC940).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawRRect(rect.inflate(6), glow);
    }
  }
}
