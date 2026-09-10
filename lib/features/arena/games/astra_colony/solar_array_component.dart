import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A damaged Solar Array sitting in the colony world. Dim and grey until
/// repaired, then glows — a real environmental state change, with enough
/// Canvas detail (struts, base, panel grid) to read as a structure rather
/// than a plain box.
class SolarArrayComponent extends PositionComponent {
  SolarArrayComponent({required Vector2 position})
      : super(position: position, size: Vector2(74, 56), anchor: Anchor.center);

  bool repaired = false;

  @override
  void render(Canvas canvas) {
    final panelColor = repaired ? const Color(0xFFFFC940) : const Color(0xFF4A4A55);
    final borderColor = repaired ? Colors.white : const Color(0xFF6B6B78);

    // Support struts beneath the panel.
    final strutPaint = Paint()..color = const Color(0xFF2A3452);
    canvas.drawRect(Rect.fromLTWH(size.x * 0.15, size.y * 0.78, 5, size.y * 0.3), strutPaint);
    canvas.drawRect(Rect.fromLTWH(size.x * 0.8, size.y * 0.78, 5, size.y * 0.3), strutPaint);

    // Base plate.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(size.x * 0.05, size.y * 0.9, size.x * 0.9, 8), const Radius.circular(3)),
      Paint()..color = const Color(0xFF232B45),
    );

    // Main panel.
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y * 0.78), const Radius.circular(6));
    canvas.drawRRect(rect, Paint()..color = panelColor);
    canvas.drawRRect(rect, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Panel grid lines.
    final gridPaint = Paint()
      ..color = (repaired ? Colors.white : Colors.black).withOpacity(0.25)
      ..strokeWidth = 1;
    for (int i = 1; i < 4; i++) {
      final x = size.x / 4 * i;
      canvas.drawLine(Offset(x, 4), Offset(x, size.y * 0.78 - 4), gridPaint);
    }
    canvas.drawLine(Offset(4, size.y * 0.39), Offset(size.x - 4, size.y * 0.39), gridPaint);

    if (repaired) {
      final glow = Paint()
        ..color = const Color(0xFFFFC940).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      canvas.drawRRect(rect.inflate(6), glow);
    }
  }
}
