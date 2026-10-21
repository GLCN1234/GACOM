import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'current_logic.dart';
import 'current_skins.dart';

/// Draws Word Current: the river, the banks, the words coming down and the
/// swimmer.
class CurrentPainter extends CustomPainter {
  final CurrentLogic g;
  final Paint _p = Paint();

  CurrentPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final CurrentSkin skin = g.skin;
    final double w = size.width;
    final double h = size.height;

    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[skin.deep, skin.water, skin.deep],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, _p);
    _p.shader = null;

    _banks(canvas, size, skin);
    _surface(canvas, size, skin);

    for (final WcDebris d in g.debris) {
      _debris(canvas, Offset(d.x * w, d.y * h), w, d);
    }
    for (final WcTile t in g.tiles) {
      _tile(canvas, t, size, skin);
    }
    _swimmer(canvas, Offset(g.x * w, g.y * h), w, skin);

    if (g.hitFlash > 0) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.24 * wcCl(g.hitFlash / 0.5, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
    if (g.goodFlash > 0) {
      _p.color = const Color(0xFF00E676).withValues(alpha: 0.13 * wcCl(g.goodFlash / 0.4, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
  }

  void _banks(Canvas canvas, Size size, CurrentSkin skin) {
    final double w = size.width;
    final double h = size.height;
    final double bw = w * 0.05;
    _p.color = skin.bank;
    canvas.drawRect(Rect.fromLTWH(0, 0, bw, h), _p);
    canvas.drawRect(Rect.fromLTWH(w - bw, 0, bw, h), _p);
    _p.color = realmLighten(skin.bank, 0.10);
    for (int i = 0; i < 16; i++) {
      final double y = ((realmUnit(i, 1, 3) + g.time * 0.02) % 1.0) * h;
      final double r = 3 + realmUnit(i, 2, 4) * 5;
      canvas.drawCircle(Offset(realmUnit(i, 5, 6) * bw, y), r, _p);
      canvas.drawCircle(Offset(w - realmUnit(i, 7, 8) * bw, y + 30), r, _p);
    }
  }

  /// Moving water: bands that scroll with the flow, plus the surface the skin
  /// chose.
  void _surface(Canvas canvas, Size size, CurrentSkin skin) {
    final double w = size.width;
    final double h = size.height;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.06);
    for (int i = 0; i < 22; i++) {
      final double y = ((realmUnit(i, 11, 2) + g.time * (0.05 + g.flow * 0.3)) % 1.0) * h;
      final double x0 = realmUnit(i, 3, 12) * w;
      final Path p = Path()..moveTo(x0, y);
      p.quadraticBezierTo(x0 + 22, y - 5, x0 + 44, y);
      canvas.drawPath(p, line);
    }
    if (skin.surface == 'foam') {
      _p.color = Colors.white.withValues(alpha: 0.10);
      for (int i = 0; i < 14; i++) {
        final double y = ((realmUnit(i, 21, 5) + g.time * (0.08 + g.flow * 0.4)) % 1.0) * h;
        canvas.drawCircle(Offset(realmUnit(i, 9, 13) * w, y), 4 + realmUnit(i, 4, 7) * 7, _p);
      }
    } else if (skin.surface == 'lily') {
      for (int i = 0; i < 9; i++) {
        final double y = ((realmUnit(i, 31, 6) + g.time * (0.04 + g.flow * 0.25)) % 1.0) * h;
        final Offset c = Offset(realmUnit(i, 6, 17) * w, y);
        _p.color = const Color(0xFF2E7D32).withValues(alpha: 0.5);
        canvas.drawCircle(c, 11, _p);
        _p.color = const Color(0xFF81C784).withValues(alpha: 0.5);
        canvas.drawCircle(c, 7, _p);
      }
    }
  }

  void _debris(Canvas canvas, Offset c, double w, WcDebris d) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(d.spin * (0.4 + g.time * 0.3));
    if (d.drum) {
      _p.color = const Color(0xFF37474F);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * 0.10, height: w * 0.13), Radius.circular(w * 0.02)), _p);
      _p.color = const Color(0xFFFFB300);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w * 0.10, height: w * 0.02), _p);
    } else {
      _p.color = const Color(0xFF4E342E);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * 0.20, height: w * 0.055), Radius.circular(w * 0.027)), _p);
      _p.color = const Color(0xFF6D4C41);
      canvas.drawCircle(Offset(w * 0.085, 0), w * 0.025, _p);
    }
    canvas.restore();
  }

  void _tile(Canvas canvas, WcTile t, Size size, CurrentSkin skin) {
    final double w = size.width;
    final double h = size.height;
    final Offset c = Offset(t.x * w, t.y * h);
    final double tw = w * 0.21;
    final double th = h * 0.075;
    final double pop = t.pop > 0 ? wcCl(t.pop / 0.4, 0.0, 1.0) : 0.0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (pop > 0) canvas.scale(1 + pop * 0.3);
    final Rect r = Rect.fromCenter(center: Offset.zero, width: tw, height: th);
    _p.color = t.gone ? const Color(0xFF1B5E20) : skin.tile;
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(th * 0.3)), _p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(th * 0.3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = t.gone ? const Color(0xFF69F0AE) : skin.accent.withValues(alpha: 0.9),
    );
    // A float on each side, so a word reads as something carried by the water.
    _p.color = const Color(0xFFEF6C00);
    canvas.drawCircle(Offset(-tw / 2, 0), th * 0.2, _p);
    canvas.drawCircle(Offset(tw / 2, 0), th * 0.2, _p);
    RealmDraw.text(canvas, t.text, Offset.zero, wcCl(th * 0.40, 10.0, 17.0), Colors.white, maxWidth: tw - 10, maxLines: 2);
    canvas.restore();
  }

  void _swimmer(Canvas canvas, Offset c, double w, CurrentSkin skin) {
    final double r = w * 0.055;
    final double kick = sin(g.bob) * 0.5;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    if (g.diving) canvas.scale(0.8);

    // Wake.
    _p.color = Colors.white.withValues(alpha: g.diving ? 0.05 : 0.14);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, r * 0.9), width: r * 2.4, height: r * 0.8), _p);

    final HeroLook look = HeroLook.current;
    // Arms, mid stroke.
    final Paint arm = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.3
      ..color = look.skin;
    canvas.drawLine(Offset(-r * 0.5, 0), Offset(-r * 1.1, -r * 0.5 * kick), arm);
    canvas.drawLine(Offset(r * 0.5, 0), Offset(r * 1.1, r * 0.5 * kick), arm);
    // Body: a swim ring in the skin's colour, which is what a shop item changes.
    _p.color = skin.swimmer;
    canvas.drawCircle(Offset.zero, r * 0.92, _p);
    _p.color = realmDarken(skin.swimmer, 0.18);
    canvas.drawCircle(Offset.zero, r * 0.62, _p);
    _p.color = look.shirt;
    canvas.drawCircle(Offset.zero, r * 0.46, _p);
    _p.color = look.skin;
    canvas.drawCircle(Offset(0, -r * 0.1), r * 0.3, _p);
    _p.color = look.hair;
    canvas.drawArc(Rect.fromCircle(center: Offset(0, -r * 0.1), radius: r * 0.3), pi, pi, true, _p);
    if (g.diving) {
      _p.color = Colors.white.withValues(alpha: 0.18);
      canvas.drawCircle(Offset.zero, r * 1.5, _p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CurrentPainter old) => true;
}
