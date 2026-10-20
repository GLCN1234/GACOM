import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'strike_logic.dart';

double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

const List<Color> strikeColors = <Color>[
  Color(0xFF29D6F0),
  Color(0xFFFFA726),
  Color(0xFF9CCC65),
  Color(0xFFF06292),
  Color(0xFFBA68C8),
];

/// Draws the Strike arena: floor, enemies carrying lettered answers, the hero and shots.
class StrikePainter extends CustomPainter {
  final StrikeLogic g;
  final Paint _p = Paint();
  final Paint _line = Paint()..style = PaintingStyle.stroke;

  StrikePainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  static const String _letters = 'ABCDE';

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = StrikeLogic.camX(g.px, w);
    final double cy = StrikeLogic.camY(g.py, h);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _p..color = g.skin.floor);
    canvas.save();
    canvas.translate(-cx, -cy);
    _floor(canvas, cx, cy, w, h);
    _props(canvas, cx, cy, w, h);
    for (final StrikeBurst b in g.bursts) {
      _burst(canvas, b);
    }
    for (final StrikeDrone d in g.drones) {
      if (d.alive) _drone(canvas, d);
    }
    _hero(canvas);
    for (final StrikeBullet b in g.bullets) {
      _bullet(canvas, b);
    }
    canvas.restore();
    _offscreen(canvas, size, cx, cy);
    if (g.flash > 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _p..color = const Color(0xFFFF1744).withOpacity(_cl(g.flash * 0.9, 0.0, 0.35)));
    }
    if (g.phase == 1) {
      RealmDraw.text(canvas, g.message, Offset(w / 2, h * 0.62), 20, g.lastOk ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80), maxWidth: w * 0.8, maxLines: 2);
    }
  }

  void _floor(Canvas canvas, double cx, double cy, double w, double h) {
    const double step = 120;
    _line
      ..color = g.skin.grid
      ..strokeWidth = 1.5;
    final double x0 = (cx / step).floor() * step;
    final double y0 = (cy / step).floor() * step;
    for (double x = x0; x <= cx + w + step; x += step) {
      if (x < 0 || x > StrikeLogic.worldSize) continue;
      canvas.drawLine(Offset(x, max(0.0, cy)), Offset(x, min(StrikeLogic.worldSize, cy + h)), _line);
    }
    for (double y = y0; y <= cy + h + step; y += step) {
      if (y < 0 || y > StrikeLogic.worldSize) continue;
      canvas.drawLine(Offset(max(0.0, cx), y), Offset(min(StrikeLogic.worldSize, cx + w), y), _line);
    }
    _line
      ..color = g.skin.accent.withOpacity(0.55)
      ..strokeWidth = 5;
    canvas.drawRect(const Rect.fromLTWH(0, 0, StrikeLogic.worldSize, StrikeLogic.worldSize), _line);
  }

  void _props(Canvas canvas, double cx, double cy, double w, double h) {
    // Scenery fixed to the world, so running past it shows how far you moved.
    const double cell = 190;
    final int i0 = (cx / cell).floor() - 1;
    final int i1 = ((cx + w) / cell).floor() + 1;
    final int j0 = (cy / cell).floor() - 1;
    final int j1 = ((cy + h) / cell).floor() + 1;
    for (int i = i0; i <= i1; i++) {
      for (int j = j0; j <= j1; j++) {
        final int hs = realmHash(i, j, 7);
        if (hs % 3 != 0) continue;
        final double x = i * cell + (hs % 97) / 97 * cell;
        final double y = j * cell + ((hs >> 7) % 89) / 89 * cell;
        if (x < 0 || y < 0 || x > StrikeLogic.worldSize || y > StrikeLogic.worldSize) continue;
        final double r = 10 + (hs % 5) * 5.0;
        _p.color = g.skin.accent.withOpacity(0.10);
        canvas.drawCircle(Offset(x, y), r * 1.6, _p);
        _p.color = g.skin.grid.withOpacity(0.9);
        canvas.drawCircle(Offset(x, y), r, _p);
      }
    }
  }

  void _hero(Canvas canvas) {
    final HeroLook look = HeroLook.current;
    if (g.inv > 0 && (g.time * 14).floor() % 2 == 0) return;
    RealmDraw.shadow(canvas, g.px, g.py + 2, 30);
    RealmDraw.person(canvas, g.px, g.py, phase: g.time * 9, moving: g.moving, facing: g.face, shirt: look.shirt, pants: look.pants, skin: look.skin, hair: look.hair, hero: true, hairStyle: look.hairStyle);
    // Weapon pointing where you last aimed.
    final Offset a = Offset(g.px, g.py - 22);
    final Offset b = a + Offset(cos(g.aim), sin(g.aim)) * 30;
    _line
      ..color = const Color(0xFF263238)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, _line);
    _line
      ..color = g.skin.accent
      ..strokeWidth = 3;
    canvas.drawLine(a, b, _line);
    _line.strokeCap = StrokeCap.butt;
    if (g.dashT > 0) {
      RealmDraw.glow(canvas, Offset(g.px, g.py - 18), 40, g.skin.accent, alpha: 0.35);
    }
  }

  void _drone(Canvas canvas, StrikeDrone d) {
    final Color c = strikeColors[d.index % strikeColors.length];
    final bool reveal = g.phase == 1 && d.correct;
    final Offset o = Offset(d.x, d.y + sin(g.time * 3 + d.wob) * 3);
    RealmDraw.shadow(canvas, d.x, d.y + 30, 34);
    RealmDraw.glow(canvas, o, 46, reveal ? const Color(0xFF69F0AE) : c, alpha: reveal ? 0.5 : 0.22);
    _p.color = g.skin.foe;
    canvas.drawCircle(o, StrikeLogic.droneRadius, _p);
    _p.color = realmDarken(g.skin.foe, 0.2);
    canvas.drawCircle(o + const Offset(0, 5), StrikeLogic.droneRadius - 8, _p);
    _line
      ..color = c
      ..strokeWidth = 4;
    canvas.drawCircle(o, StrikeLogic.droneRadius + 2, _line);
    // Little wings so it reads as a creature, not a ball.
    final double flap = sin(g.time * 18 + d.wob) * 5;
    _p.color = c.withOpacity(0.55);
    canvas.drawOval(Rect.fromCenter(center: o + Offset(-StrikeLogic.droneRadius - 6, -4 + flap), width: 16, height: 8), _p);
    canvas.drawOval(Rect.fromCenter(center: o + Offset(StrikeLogic.droneRadius + 6, -4 - flap), width: 16, height: 8), _p);
    RealmDraw.text(canvas, _letters[d.index % _letters.length], o, 22, Colors.white, maxWidth: 40, maxLines: 1);
    if (g.lock == d.index && g.phase == 0) {
      _line
        ..color = Colors.white
        ..strokeWidth = 2;
      canvas.drawCircle(o, StrikeLogic.droneRadius + 12, _line);
      canvas.drawLine(o + const Offset(-StrikeLogic.droneRadius - 18, 0), o + const Offset(-StrikeLogic.droneRadius - 6, 0), _line);
      canvas.drawLine(o + const Offset(StrikeLogic.droneRadius + 6, 0), o + const Offset(StrikeLogic.droneRadius + 18, 0), _line);
    }
    final String full = g.q!.options[d.index % g.q!.options.length];
    if (full.length <= 14 || reveal) {
      RealmDraw.label(canvas, full, o + const Offset(0, 34), size: 12, maxWidth: 150);
    }
  }

  void _bullet(Canvas canvas, StrikeBullet b) {
    if (b.foe) {
      _p.color = const Color(0xFFFF5252);
      canvas.drawCircle(Offset(b.x, b.y), 6, _p);
      _p.color = const Color(0x55FF5252);
      canvas.drawCircle(Offset(b.x, b.y), 11, _p);
    } else {
      final double m = sqrt(b.vx * b.vx + b.vy * b.vy);
      final Offset t = Offset(b.vx / m, b.vy / m) * 18;
      _line
        ..color = const Color(0xFFFFF176)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(b.x, b.y), Offset(b.x, b.y) - t, _line);
      _line.strokeCap = StrokeCap.butt;
    }
  }

  void _burst(Canvas canvas, StrikeBurst b) {
    final double k = _cl(b.t / 0.6, 0.0, 1.0);
    _line
      ..color = b.color.withOpacity(1 - k)
      ..strokeWidth = 6 * (1 - k) + 1;
    canvas.drawCircle(Offset(b.x, b.y), 14 + 70 * k, _line);
    _p.color = b.color.withOpacity((1 - k) * 0.35);
    canvas.drawCircle(Offset(b.x, b.y), 10 + 40 * k, _p);
  }

  /// Small lettered markers at the screen edge for enemies you cannot see yet.
  void _offscreen(Canvas canvas, Size size, double cx, double cy) {
    for (final StrikeDrone d in g.drones) {
      if (!d.alive) continue;
      final double sx = d.x - cx;
      final double sy = d.y - cy;
      if (sx >= 0 && sx <= size.width && sy >= 0 && sy <= size.height) continue;
      final double ex = sx < 24 ? 24 : (sx > size.width - 24 ? size.width - 24 : sx);
      final double ey = sy < 70 ? 70 : (sy > size.height - 24 ? size.height - 24 : sy);
      final Color c = strikeColors[d.index % strikeColors.length];
      _p.color = c.withOpacity(0.9);
      canvas.drawCircle(Offset(ex, ey), 14, _p);
      RealmDraw.text(canvas, _letters[d.index % _letters.length], Offset(ex, ey), 14, Colors.black, maxWidth: 24, maxLines: 1);
    }
  }

  @override
  bool shouldRepaint(covariant StrikePainter old) => true;
}
