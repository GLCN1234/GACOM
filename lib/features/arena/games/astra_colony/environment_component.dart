import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Ground, path, and atmospheric detail for the colony scene. Pure Canvas
/// drawing — no external art files, so nothing here can throw a missing-
/// asset error. Rendered behind everything else via a low priority.
class EnvironmentComponent extends PositionComponent {
  EnvironmentComponent({required Vector2 worldSize})
      : super(position: Vector2.zero(), size: worldSize, priority: -10);

  @override
  void render(Canvas canvas) {
    // Atmospheric sky gradient.
    final skyRect = Rect.fromLTWH(0, 0, size.x, size.y);
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0B0F1A), Color(0xFF11172A), Color(0xFF161C33)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, sky);

    // Ground plane.
    final groundTop = size.y * 0.35;
    final groundRect = Rect.fromLTWH(0, groundTop, size.x, size.y - groundTop);
    final ground = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1C2438), Color(0xFF141A2B)],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, ground);

    // A lit walking path leading toward the Solar Array.
    final pathPaint = Paint()..color = const Color(0xFF2A3452);
    final pathGlow = Paint()
      ..color = const Color(0xFF3DD6FF).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(size.x * 0.28, size.y)
      ..lineTo(size.x * 0.55, groundTop + 20)
      ..lineTo(size.x * 0.7, groundTop + 20)
      ..lineTo(size.x * 0.5, size.y);
    canvas.drawPath(path, pathPaint);
    canvas.drawLine(Offset(size.x * 0.55, groundTop + 20), Offset(size.x * 0.7, groundTop + 20), pathGlow);

    // Scattered decorative colony debris/crates — small readable shapes,
    // just enough to sell "this is a place", not literal asset props.
    final crate = Paint()..color = const Color(0xFF3A4260);
    _drawCrate(canvas, crate, Offset(size.x * 0.15, size.y * 0.78), 18);
    _drawCrate(canvas, crate, Offset(size.x * 0.82, size.y * 0.65), 14);
    _drawCrate(canvas, crate, Offset(size.x * 0.1, size.y * 0.5), 12);

    // Faint distant colony silhouettes on the horizon for depth.
    final horizon = Paint()..color = const Color(0xFF1A2038).withOpacity(0.8);
    _drawSilhouetteBuilding(canvas, horizon, Offset(size.x * 0.12, groundTop), 30, 55);
    _drawSilhouetteBuilding(canvas, horizon, Offset(size.x * 0.85, groundTop), 26, 40);
    _drawSilhouetteBuilding(canvas, horizon, Offset(size.x * 0.95, groundTop), 20, 65);
  }

  void _drawCrate(Canvas canvas, Paint paint, Offset center, double s) {
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: s, height: s), const Radius.circular(3));
    canvas.drawRRect(rect, paint);
    final line = Paint()..color = Colors.black.withOpacity(0.3)..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - s / 2, center.dy), Offset(center.dx + s / 2, center.dy), line);
  }

  void _drawSilhouetteBuilding(Canvas canvas, Paint paint, Offset baseCenter, double w, double h) {
    final rect = Rect.fromLTWH(baseCenter.dx - w / 2, baseCenter.dy - h, w, h);
    canvas.drawRect(rect, paint);
  }
}
