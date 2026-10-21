import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'siege_logic.dart';
import 'siege_skins.dart';

/// Draws Gate Siege: the road down to your gate, the marchers and their
/// numbers, and the gate itself.
class SiegePainter extends CustomPainter {
  final SiegeLogic g;
  final Paint _p = Paint();

  SiegePainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final SiegeSkin skin = g.skin;
    final double w = size.width;
    final double h = size.height;

    _p.shader = null;
    _p.color = skin.ground;
    canvas.drawRect(Offset.zero & size, _p);
    _ground(canvas, size, skin);
    _gate(canvas, size, skin);

    for (final SgMarcher m in g.marchers) {
      _marcher(canvas, m, Offset(m.x * w, m.y * h), w, skin);
    }

    if (g.hitFlash > 0) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.24 * sgCl(g.hitFlash / 0.5, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
    if (g.goodFlash > 0) {
      _p.color = const Color(0xFF00E676).withValues(alpha: 0.12 * sgCl(g.goodFlash / 0.35, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
  }

  void _ground(Canvas canvas, Size size, SiegeSkin skin) {
    final double w = size.width;
    final double h = size.height;
    // The approach road, narrowing into the distance.
    final Path road = Path()
      ..moveTo(w * 0.30, 0)
      ..lineTo(w * 0.70, 0)
      ..lineTo(w, h * sgGateY)
      ..lineTo(0, h * sgGateY)
      ..close();
    _p.color = realmLighten(skin.ground, 0.05);
    canvas.drawPath(road, _p);

    // Lane markers for the four columns, to show where marchers come down.
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.07);
    for (int i = 0; i < 4; i++) {
      final double f = (i + 0.5) / 4.0;
      canvas.drawLine(Offset(w * (0.30 + 0.40 * f), 0), Offset(w * f, h * sgGateY), line);
    }

    // Torches along the walls, flickering off the clock.
    for (int i = 0; i < 2; i++) {
      final double tx = i == 0 ? w * 0.06 : w * 0.94;
      final double ty = h * (sgGateY - 0.10);
      final double flick = 0.6 + 0.4 * sin(g.time * 7 + i * 2.1);
      RealmDraw.glow(canvas, Offset(tx, ty), 26 * flick, skin.accent, alpha: 0.16);
      _p.color = const Color(0xFF3E2723);
      canvas.drawRect(Rect.fromCenter(center: Offset(tx, ty + 10), width: 4, height: 22), _p);
      _p.color = Color.lerp(const Color(0xFFFF7043), const Color(0xFFFFE082), flick)!;
      canvas.drawCircle(Offset(tx, ty), 6 * (0.85 + 0.15 * flick), _p);
    }
  }

  void _gate(Canvas canvas, Size size, SiegeSkin skin) {
    final double w = size.width;
    final double h = size.height;
    final double top = h * sgGateY;

    _p.color = skin.wall;
    canvas.drawRect(Rect.fromLTRB(0, top, w, h), _p);
    _p.color = realmDarken(skin.wall, 0.10);
    for (int row = 0; row < 3; row++) {
      final double y = top + 10 + row * 18;
      for (int i = 0; i < 9; i++) {
        final double x = (i + (row.isEven ? 0 : 0.5)) * (w / 8);
        canvas.drawRect(Rect.fromLTWH(x + 2, y, w / 8 - 5, 13), _p);
      }
    }
    // Battlements.
    _p.color = realmLighten(skin.wall, 0.08);
    for (int i = 0; i < 8; i++) {
      final double x = i * (w / 8);
      canvas.drawRect(Rect.fromLTWH(x + 3, top - 9, w / 8 - 6, 10), _p);
    }
    // The banner, which is what a shop skin changes most visibly.
    final double bx = w / 2;
    final Path banner = Path()
      ..moveTo(bx - 16, top + 4)
      ..lineTo(bx + 16, top + 4)
      ..lineTo(bx + 16, top + 40)
      ..lineTo(bx, top + 31)
      ..lineTo(bx - 16, top + 40)
      ..close();
    _p.color = skin.banner;
    canvas.drawPath(banner, _p);
    _p.color = Colors.white.withValues(alpha: 0.85);
    RealmDraw.text(canvas, 'G', Offset(bx, top + 18), 16, Colors.white, maxWidth: 30, maxLines: 1);

    // Gate health as shields along the wall.
    for (int i = 0; i < SiegeLogic.gateMax; i++) {
      final double x = w * 0.5 + (i - (SiegeLogic.gateMax - 1) / 2) * 26;
      final bool alive = i < g.gate;
      _p.color = alive ? skin.accent : Colors.white12;
      canvas.drawCircle(Offset(x, h - 16), 6, _p);
    }
  }

  void _marcher(Canvas canvas, SgMarcher m, Offset c, double w, SiegeSkin skin) {
    final double r = w * 0.072;
    final double dying = m.dieT > 0 ? sgCl(m.dieT / 0.42, 0.0, 1.0) : 1.0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (m.dieT > 0) {
      canvas.scale(0.6 + 0.4 * dying);
      canvas.rotate((1 - dying) * 0.7);
    }
    if (m.hitT > 0) {
      canvas.translate(sin(m.hitT * 60) * 3, 0);
    }

    RealmDraw.shadow(canvas, 0, r * 0.95, r * 1.6);
    // Body: a hooded marcher carrying its number on a shield.
    _p.color = skin.marcher;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, r * 0.12), width: r * 1.25, height: r * 1.5), Radius.circular(r * 0.35)), _p);
    _p.color = realmDarken(skin.marcher, 0.12);
    canvas.drawCircle(Offset(0, -r * 0.78), r * 0.46, _p);
    _p.color = skin.marcherTrim;
    canvas.drawRect(Rect.fromCenter(center: Offset(0, -r * 0.3), width: r * 1.25, height: r * 0.16), _p);

    // The shield with the number. This is the thing the player reads.
    final Rect shield = Rect.fromCenter(center: Offset(0, r * 0.2), width: r * 1.5, height: r * 1.2);
    _p.color = const Color(0xF2101218);
    canvas.drawRRect(RRect.fromRectAndRadius(shield, Radius.circular(r * 0.26)), _p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(shield, Radius.circular(r * 0.26)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = m.hitT > 0 ? const Color(0xFF69F0AE) : skin.accent,
    );
    RealmDraw.text(canvas, '${m.value}', shield.center, r * 0.72, Colors.white, maxWidth: shield.width - 4, maxLines: 1);

    // What it started as, so the player can see the factorisation happening.
    if (m.value != m.startValue) {
      RealmDraw.text(canvas, 'was ${m.startValue}', Offset(0, r * 1.15), r * 0.33, Colors.white60, maxWidth: r * 2.4, maxLines: 1);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SiegePainter old) => true;
}
