import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A collectible power cell with a visible numeric value, sitting in the
/// world. Walking over it picks it up automatically — no popup, no
/// buttons. The player carries it (shown in the HUD) to the Reactor
/// Console and deposits it there. This IS the math: choosing which cells
/// to collect and deposit to hit the required total.
class PowerCellComponent extends PositionComponent {
  PowerCellComponent({required Vector2 position, required this.value})
      : super(position: position, size: Vector2(34, 34), anchor: Anchor.center);

  final int value;
  bool collected = false;

  @override
  void render(Canvas canvas) {
    if (collected) return;
    final center = Offset(size.x / 2, size.y / 2);

    final glow = Paint()
      ..color = const Color(0xFF3DD6FF).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, size.x / 2 + 5, glow);

    canvas.drawCircle(center, size.x / 2, Paint()..color = const Color(0xFF1C2438));
    canvas.drawCircle(center, size.x / 2, Paint()
      ..color = const Color(0xFF3DD6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    final tp = TextPainter(
      text: TextSpan(text: '$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }
}
