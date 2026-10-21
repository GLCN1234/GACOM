import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'okada_logic.dart';

/// Okada Run, seen from above and behind: a road that scrolls down while the
/// rider holds a fixed spot near the bottom.
class OkadaPainter extends CustomPainter {
  final OkadaLogic g;
  OkadaPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();

  double _scale(Size s) => s.width / (okRoadW + 56);
  double _riderY(Size s) => s.height * 0.74;

  @override
  void paint(Canvas canvas, Size size) {
    final double sc = _scale(size);
    final double ry = _riderY(size);
    final double roadLeft = (size.width - okRoadW * sc) / 2;

    double sx(double roadX) => roadLeft + roadX * sc;
    double sy(double worldY) => ry - (worldY - g.dist) * sc;

    // Verge.
    _p.shader = null;
    _p.color = const Color(0xFF14180F);
    canvas.drawRect(Offset.zero & size, _p);
    _verge(canvas, size, sc, roadLeft, sy);

    // Road.
    _p.color = g.skin.road;
    canvas.drawRect(Rect.fromLTRB(roadLeft, 0, roadLeft + okRoadW * sc, size.height), _p);
    _p.color = g.skin.kerb;
    canvas.drawRect(Rect.fromLTWH(roadLeft - 6 * sc, 0, 6 * sc, size.height), _p);
    canvas.drawRect(Rect.fromLTWH(roadLeft + okRoadW * sc, 0, 6 * sc, size.height), _p);

    _laneLines(canvas, size, sc, sx, sy);
    _props(canvas, sc, sx, sy);
    _gates(canvas, size, sc, sx, sy);
    _rider(canvas, sc, sx(g.x), ry);
    _speedLines(canvas, size);
    _flashes(canvas, size);
  }

  /// Palms and kiosks either side, placed from a repeatable hash so the ride
  /// looks like a road and not an empty strip.
  void _verge(Canvas canvas, Size size, double sc, double roadLeft, double Function(double) sy) {
    final int from = ((g.dist - 200) / 150).floor();
    final int to = ((g.dist + size.height / sc + 200) / 150).ceil();
    for (int i = from; i <= to; i++) {
      final double wy = i * 150.0;
      final double y = sy(wy);
      if (y < -80 || y > size.height + 80) continue;
      for (int side = 0; side < 2; side++) {
        final double u = realmUnit(i, side, 5);
        if (u < 0.34) continue;
        final double off = (14 + u * 26) * sc;
        final double px = side == 0 ? roadLeft - off : roadLeft + okRoadW * sc + off;
        if (u > 0.72) {
          _kiosk(canvas, px, y, sc, realmUnit(i, side, 9));
        } else {
          _palm(canvas, px, y, sc, u);
        }
      }
    }
  }

  void _palm(Canvas canvas, double x, double y, double sc, double u) {
    _p.color = const Color(0xFF4E342E);
    canvas.drawRect(Rect.fromLTWH(x - 1.6 * sc, y - 22 * sc, 3.2 * sc, 22 * sc), _p);
    _p.color = Color.lerp(const Color(0xFF2E7D32), const Color(0xFF66BB6A), u)!;
    for (int k = 0; k < 5; k++) {
      final double a = -pi / 2 + (k - 2) * 0.55;
      final Offset tip = Offset(x + cos(a) * 15 * sc, y - 22 * sc + sin(a) * 12 * sc);
      canvas.drawPath(
        Path()
          ..moveTo(x, y - 22 * sc)
          ..quadraticBezierTo((x + tip.dx) / 2, tip.dy - 5 * sc, tip.dx, tip.dy)
          ..quadraticBezierTo((x + tip.dx) / 2, tip.dy + 2 * sc, x, y - 20 * sc)
          ..close(),
        _p,
      );
    }
  }

  void _kiosk(Canvas canvas, double x, double y, double sc, double u) {
    final double w = 20 * sc;
    final double h = 14 * sc;
    _p.color = Color.lerp(const Color(0xFF455A64), const Color(0xFF6D4C41), u)!;
    canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: w, height: h), _p);
    _p.color = Color.lerp(const Color(0xFFFFB300), const Color(0xFF29B6F6), u)!;
    canvas.drawRect(Rect.fromLTWH(x - w / 2, y - h / 2, w, 3 * sc), _p);
  }

  void _laneLines(Canvas canvas, Size size, double sc, double Function(double) sx, double Function(double) sy) {
    _p.color = Colors.white24;
    const double dash = 46;
    final int from = ((g.dist - 120) / dash).floor();
    final int to = ((g.dist + size.height / sc + 120) / dash).ceil();
    for (int lane = 1; lane < okLanes; lane++) {
      final double x = sx(okRoadW * lane / okLanes);
      for (int i = from; i <= to; i++) {
        final double y = sy(i * dash);
        canvas.drawRect(Rect.fromLTWH(x - 1.2 * sc, y, 2.4 * sc, 22 * sc), _p);
      }
    }
  }

  void _props(Canvas canvas, double sc, double Function(double) sx, double Function(double) sy) {
    for (final OkProp p in g.props) {
      if (p.used && p.kind == 'fuel') continue;
      final double x = sx(okLaneX(p.lane));
      final double y = sy(p.y);
      switch (p.kind) {
        case 'car':
          if (p.used) break;
          _p.color = const Color(0xFF1A237E);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 26 * sc, height: 44 * sc), Radius.circular(6 * sc)), _p);
          _p.color = const Color(0xFF90CAF9);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y - 8 * sc), width: 18 * sc, height: 12 * sc), Radius.circular(3 * sc)), _p);
          _p.color = const Color(0xFFFF8A80);
          canvas.drawRect(Rect.fromCenter(center: Offset(x, y + 20 * sc), width: 18 * sc, height: 3 * sc), _p);
          break;
        case 'pothole':
          if (p.used) break;
          _p.color = const Color(0xFF0C0C0E);
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 30 * sc, height: 16 * sc), _p);
          _p.color = Colors.white10;
          canvas.drawOval(Rect.fromCenter(center: Offset(x, y - 1.5 * sc), width: 24 * sc, height: 10 * sc), _p);
          break;
        default:
          RealmDraw.glow(canvas, Offset(x, y), 14 * sc, const Color(0xFFFFD54F), alpha: 0.25);
          _p.color = const Color(0xFFFFC107);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, y), width: 14 * sc, height: 18 * sc), Radius.circular(3 * sc)), _p);
          _p.color = const Color(0xFF3E2723);
          canvas.drawRect(Rect.fromCenter(center: Offset(x, y - 10 * sc), width: 5 * sc, height: 4 * sc), _p);
      }
    }
  }

  /// The gantry: one sign per lane, carrying one answer.
  void _gates(Canvas canvas, Size size, double sc, double Function(double) sx, double Function(double) sy) {
    for (final OkGate gate in g.gates) {
      final double y = sy(gate.y);
      if (y < -120 || y > size.height + 60) continue;

      _p.color = const Color(0xFF263238);
      canvas.drawRect(Rect.fromLTRB(sx(0) - 6 * sc, y - 3 * sc, sx(okRoadW) + 6 * sc, y + 3 * sc), _p);
      for (final double px in <double>[sx(0) - 5 * sc, sx(okRoadW) + 2 * sc]) {
        canvas.drawRect(Rect.fromLTWH(px, y, 4 * sc, 30 * sc), _p);
      }

      for (int lane = 0; lane < okLanes; lane++) {
        final double cx = sx(okLaneX(lane));
        final double w = (okRoadW / okLanes - 8) * sc;
        final double h = 30 * sc;
        final Rect r = Rect.fromCenter(center: Offset(cx, y - h / 2 - 3 * sc), width: w, height: h);
        Color face = g.skin.sign;
        if (gate.passed) {
          final bool isAnswer = lane == gate.correctLane;
          face = isAnswer ? const Color(0xFF1B5E20) : const Color(0xFF4E1414);
        }
        _p.color = face;
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(5 * sc)), _p);
        _p.color = Colors.white.withValues(alpha: 0.85);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(1.4 * sc), Radius.circular(4 * sc)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * sc
            ..color = Colors.white.withValues(alpha: 0.85),
        );
        RealmDraw.text(
          canvas,
          gate.signs[lane],
          r.center,
          okCl(h * 0.34, 9.0, 17.0),
          Colors.white,
          maxWidth: w - 8 * sc,
          maxLines: 2,
        );
      }
    }
  }

  void _rider(Canvas canvas, double sc, double x, double y) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(sc);
    canvas.rotate(g.lean * 0.22);

    // Exhaust, from the equipped skin.
    if (g.skin.exhaust != 'none') {
      final double t = g.time * 9;
      for (int i = 0; i < 6; i++) {
        double f = t * 0.1 + i / 6.0;
        f = f - f.floorToDouble();
        final double py = 22 + f * 26;
        final double r = 6 * (1 - f) + 1.5;
        Color c;
        switch (g.skin.exhaust) {
          case 'flame':
            c = Color.lerp(const Color(0xFFFF5722), const Color(0xFFFFEB3B), 1 - f)!;
            break;
          case 'sparks':
            c = const Color(0xFFFFF176);
            break;
          default:
            c = const Color(0xFF90A4AE);
        }
        RealmDraw.glow(canvas, Offset((realmUnit(i, 1, 2) - 0.5) * 7, py), r, c, alpha: 0.5 * (1 - f));
      }
    }

    RealmDraw.shadow(canvas, 0, 20, 30);
    // Wheels.
    _p.color = const Color(0xFF121214);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 16), width: 8, height: 16), const Radius.circular(4)), _p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -14), width: 7, height: 14), const Radius.circular(3.5)), _p);
    // Body.
    _p.color = g.skin.bike;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 2), width: 15, height: 28), const Radius.circular(6)), _p);
    _p.color = realmLighten(g.skin.bike, 0.18);
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, -4), width: 13, height: 4), _p);
    // Handlebars.
    _p.color = const Color(0xFF263238);
    canvas.drawRect(Rect.fromCenter(center: const Offset(0, -11), width: 22, height: 3), _p);
    // Rider: the hero's own shirt colour, so the character carries across games.
    final HeroLook look = HeroLook.current;
    _p.color = look.shirt;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, 1), width: 17, height: 18), const Radius.circular(7)), _p);
    _p.color = look.skin;
    canvas.drawCircle(const Offset(-9, 0), 2.6, _p);
    canvas.drawCircle(const Offset(9, 0), 2.6, _p);
    // Helmet.
    _p.color = g.skin.helmet;
    canvas.drawCircle(const Offset(0, -6), 7, _p);
    _p.color = const Color(0xFF1A1A22);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -8.5), width: 11, height: 4.5), const Radius.circular(2)), _p);
    // Headlight.
    _p.color = const Color(0xFFFFF59D);
    canvas.drawCircle(const Offset(0, -17), 2.6, _p);
    canvas.restore();
  }

  void _speedLines(Canvas canvas, Size size) {
    final double f = okCl((g.speed - OkadaLogic.baseSpeed) / 320, 0.0, 1.0);
    if (f <= 0.02) return;
    final Paint sp = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 + 0.14 * f)
      ..strokeWidth = 2;
    for (int i = 0; i < 14; i++) {
      final double u = realmUnit(i, (g.dist / 90).floor(), 4);
      final double x = u * size.width;
      final double y = ((realmUnit(i, 3, 8) + g.time * (1.4 + f)) % 1.0) * size.height;
      canvas.drawLine(Offset(x, y), Offset(x, y + 30 + 60 * f), sp);
    }
  }

  void _flashes(Canvas canvas, Size size) {
    if (g.hitFlash > 0) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.26 * okCl(g.hitFlash / 0.55, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
    if (g.goodFlash > 0) {
      _p.color = const Color(0xFF00E676).withValues(alpha: 0.14 * okCl(g.goodFlash / 0.5, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
  }

  @override
  bool shouldRepaint(OkadaPainter old) => true;
}
