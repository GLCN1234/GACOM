import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// A cargo Transporter. Distinct from the player and from instant
/// deposit — pods get LOADED into it (a separate step from collecting
/// them), then it physically drives itself to the Reactor once LAUNCHED,
/// arriving after a real travel time rather than delivering instantly.
class TransporterComponent extends PositionComponent {
  TransporterComponent({required Vector2 position})
      : super(position: position, size: Vector2(46, 30), anchor: Anchor.center);

  int loadedValue = 0;
  bool driving = false;
  Vector2? _destination;
  static const double _driveSpeed = 90;

  void launchTowards(Vector2 destination) {
    _destination = destination.clone();
    driving = true;
  }

  bool get hasArrived => _destination != null && (position - _destination!).length < 6;

  @override
  void update(double dt) {
    super.update(dt);
    if (!driving || _destination == null) return;
    final diff = _destination! - position;
    final dist = diff.length;
    if (dist < 6) {
      driving = false;
      return;
    }
    position += (diff / dist) * _driveSpeed * dt;
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final bodyColor = loadedValue > 0 ? const Color(0xFFFFC940) : const Color(0xFF3A4260);

    // Simple vehicle silhouette: body + two wheels — reads as "a vehicle"
    // rather than a generic box, still pure Canvas.
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(4, 4, size.x - 8, size.y - 12), const Radius.circular(6));
    canvas.drawRRect(body, Paint()..color = bodyColor.withOpacity(driving ? 1 : 0.85));
    canvas.drawRRect(body, Paint()..color = Colors.white.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final wheelPaint = Paint()..color = const Color(0xFF14192B);
    canvas.drawCircle(Offset(size.x * 0.28, size.y - 5), 4, wheelPaint);
    canvas.drawCircle(Offset(size.x * 0.72, size.y - 5), 4, wheelPaint);

    if (driving) {
      final trail = Paint()
        ..color = const Color(0xFF3DD6FF).withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(center, size.x * 0.5, trail);
    }

    if (loadedValue > 0) {
      final tp = TextPainter(
        text: TextSpan(text: '$loadedValue', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 - 3));
    }
  }
}
