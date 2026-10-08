import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'ember_chart.dart';
import 'ember_logic.dart';

/// Draws the night-sea chart table of Ember Archipelago.
class EmberPainter extends CustomPainter {
  final EmberLogic g;
  EmberPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  static const Color accent = Color(0xFF2ED3E6);
  static const Color brass = Color(0xFF9C7A45);
  static const Color negColor = Color(0xFFFF9E80);
  static const Color posColor = Color(0xFF9AF0FF);
  static const Color flame = Color(0xFFFFE082);

  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final Map<String, TextPainter> _tpCache = <String, TextPainter>{};

  TextPainter _tp(String text, double size, Color color) {
    final String key = '$text|${size.toStringAsFixed(1)}|${color.value}';
    final TextPainter? hit = _tpCache[key];
    if (hit != null) return hit;
    if (_tpCache.length > 400) _tpCache.clear();
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani', height: 1.0)),
      textDirection: TextDirection.ltr,
    )..layout();
    _tpCache[key] = tp;
    return tp;
  }

  void _text(Canvas c, String s, Offset center, double size, Color color) {
    final TextPainter tp = _tp(s, size, color);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  void _dash(Canvas c, Offset a, Offset b, Paint p, double dash, double gap, double shift) {
    final Offset d = b - a;
    final double len = d.distance;
    if (len < 0.5) return;
    final Offset u = d / len;
    double pos = -(shift % (dash + gap));
    while (pos < len) {
      final double s = max(0.0, pos);
      final double e = min(len, pos + dash);
      if (e > s) c.drawLine(a + u * s, a + u * e, p);
      pos += dash + gap;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final EmberLayout lay = g.layoutFor(size);
    final double t = g.time;
    _sky(canvas, size, t);
    _board(canvas, lay);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(lay.board.deflate(2), const Radius.circular(10)));
    _shimmer(canvas, lay, t);
    _gridLines(canvas, lay);
    _reefs(canvas, lay, t);
    _home(canvas, lay);
    _islands(canvas, lay, t);
    _route(canvas, lay, t);
    _boat(canvas, lay, t);
    _marks(canvas, lay, t);
    canvas.restore();
    _axisLabels(canvas, lay);
  }

  @override
  bool shouldRepaint(EmberPainter old) => true;

  // ---- sky and board ------------------------------------------------------

  void _sky(Canvas canvas, Size size, double t) {
    final Rect r = Offset.zero & size;
    final Paint bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF030813), Color(0xFF071A33), Color(0xFF0A2A3C)],
      ).createShader(r);
    canvas.drawRect(r, bg);
    for (int i = 0; i < 90; i++) {
      final double x = realmUnit(i, 11, 3) * size.width;
      final double y = realmUnit(i, 12, 3) * size.height;
      final double tw = 0.5 + 0.5 * sin(t * (0.8 + realmUnit(i, 13, 3) * 1.6) + i);
      final double rad = 0.5 + realmUnit(i, 14, 3) * 1.2;
      _p.color = Colors.white.withValues(alpha: 0.12 + 0.6 * tw * (0.4 + 0.6 * realmUnit(i, 15, 3)));
      canvas.drawCircle(Offset(x, y), rad, _p);
    }
  }

  void _board(Canvas canvas, EmberLayout lay) {
    final RRect rr = RRect.fromRectAndRadius(lay.board, const Radius.circular(12));
    _p.color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRRect(rr.shift(const Offset(0, 4)), _p);
    final Paint water = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFF0E3550), Color(0xFF082238), Color(0xFF0A2E48)],
      ).createShader(lay.board);
    canvas.drawRRect(rr, water);
    _s.color = brass;
    _s.strokeWidth = 3;
    canvas.drawRRect(rr, _s);
    _s.color = const Color(0xFFD9B873).withValues(alpha: 0.5);
    _s.strokeWidth = 1;
    canvas.drawRRect(rr.deflate(3), _s);
  }

  void _shimmer(Canvas canvas, EmberLayout lay, double t) {
    final Rect gr = lay.gridRect;
    _s.strokeWidth = 1.2;
    for (int i = 0; i < 70; i++) {
      final double u = realmUnit(i, 21, 5);
      final double v = realmUnit(i, 22, 5);
      final double ph = t * (0.4 + realmUnit(i, 23, 5) * 0.5) + i * 1.7;
      final double x = gr.left - 10 + u * (gr.width + 20) + sin(ph) * 4;
      final double y = gr.top + v * gr.height;
      final double a = 0.03 + 0.10 * (0.5 + 0.5 * sin(ph * 1.3));
      final double len = 7 + 12 * realmUnit(i, 24, 5);
      _s.color = const Color(0xFF7FE9F5).withValues(alpha: a);
      canvas.drawLine(Offset(x, y), Offset(x + len, y + sin(ph) * 1.2), _s);
    }
  }

  void _gridLines(Canvas canvas, EmberLayout lay) {
    for (int k = emberLo; k <= emberHi; k++) {
      final bool axis = k == 0;
      _s.color = Colors.white.withValues(alpha: axis ? 0.42 : 0.11);
      _s.strokeWidth = axis ? 1.8 : 0.8;
      canvas.drawLine(lay.pos(k, -6), lay.pos(k, 6), _s);
      canvas.drawLine(lay.pos(-6, k), lay.pos(6, k), _s);
    }
    _p.color = Colors.white.withValues(alpha: 0.22);
    for (int x = emberLo; x <= emberHi; x++) {
      for (int y = emberLo; y <= emberHi; y++) {
        canvas.drawCircle(lay.pos(x, y), 1.3, _p);
      }
    }
    // Axis names near the ends of the axes.
    _text(canvas, 'x', lay.pos(5.55, 0.42), max(10.0, lay.cell * 0.5), const Color(0xCCFFFFFF));
    _text(canvas, 'y', lay.pos(0.42, 5.55), max(10.0, lay.cell * 0.5), const Color(0xCCFFFFFF));
  }

  void _axisLabels(Canvas canvas, EmberLayout lay) {
    final double fs = (lay.cell * 0.46).clamp(8.5, 13.0).toDouble();
    for (int k = emberLo; k <= emberHi; k++) {
      final Color c = k < 0 ? negColor : (k > 0 ? posColor : Colors.white);
      _text(canvas, '$k', Offset(lay.pos(k, -6).dx, lay.gridRect.bottom + 10), fs, c);
      _text(canvas, '$k', Offset(lay.origin.dx - 10, lay.pos(-6, k).dy), fs, c);
    }
  }

  // ---- reefs --------------------------------------------------------------

  void _reefs(Canvas canvas, EmberLayout lay, double t) {
    final List<EP> cells = g.chart.reefCells;
    final int badLeg = g.phase == emPlot ? g.firstBadLeg : -1;
    final EP? badCell = (badLeg >= 0 && badLeg < g.legReefs.length) ? g.legReefs[badLeg] : null;
    for (final EP c in cells) {
      final Rect r = Rect.fromPoints(lay.pos(c.x, c.y + 1), lay.pos(c.x + 1, c.y));
      _p.color = const Color(0xFF2A2230);
      canvas.drawRect(r, _p);
      canvas.save();
      canvas.clipRect(r);
      _s.strokeWidth = 1;
      _s.color = const Color(0xFFE5735A).withValues(alpha: 0.30);
      final double step = max(4.5, lay.cell * 0.22);
      for (double d = -r.height; d < r.width; d += step) {
        canvas.drawLine(Offset(r.left + d, r.bottom), Offset(r.left + d + r.height, r.top), _s);
      }
      canvas.restore();
      for (int j = 0; j < 3; j++) {
        final double ux = 0.22 + 0.56 * realmUnit(c.x + 7, c.y + 9, j + 1);
        final double uy = 0.22 + 0.56 * realmUnit(c.y + 5, c.x + 3, j + 4);
        final Offset ctr = Offset(r.left + ux * r.width, r.top + uy * r.height);
        final double rr = r.width * (0.12 + 0.10 * realmUnit(c.x, c.y, j + 20));
        final Path pth = Path();
        for (int k = 0; k < 6; k++) {
          final double a = k * pi / 3 + realmUnit(c.x + 11, c.y + 11, j * 7 + k) * 0.6;
          final double rad = rr * (0.75 + 0.5 * realmUnit(c.y + 3, c.x + 5, j * 11 + k));
          final Offset o = ctr + Offset(cos(a) * rad, sin(a) * rad);
          if (k == 0) {
            pth.moveTo(o.dx, o.dy);
          } else {
            pth.lineTo(o.dx, o.dy);
          }
        }
        pth.close();
        _p.color = const Color(0xFF4A4458);
        canvas.drawPath(pth, _p);
        _s.strokeWidth = 1;
        _s.color = const Color(0xFF8A82A0).withValues(alpha: 0.7);
        canvas.drawPath(pth, _s);
      }
      final double foam = 0.25 + 0.2 * sin(t * 2 + c.x * 1.3 + c.y * 0.7);
      _s.strokeWidth = 1.2;
      _s.color = const Color(0xFFFF8A65).withValues(alpha: 0.55);
      canvas.drawRect(r.deflate(0.6), _s);
      _s.color = Colors.white.withValues(alpha: foam * 0.5);
      canvas.drawRect(r.inflate(1.2), _s);
      if (badCell != null && badCell == c) {
        _s.strokeWidth = 2.4;
        _s.color = const Color(0xFFFF5252).withValues(alpha: 0.6 + 0.4 * sin(t * 8));
        canvas.drawRect(r.inflate(1), _s);
      }
    }
  }

  void _home(Canvas canvas, EmberLayout lay) {
    final Offset c = lay.posOf(g.chart.start);
    final double u = lay.cell;
    _p.color = const Color(0xFF6B4A2B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(0, u * 0.22), width: u * 0.9, height: u * 0.22), const Radius.circular(2)), _p);
    _s.strokeWidth = 1.6;
    _s.color = brass;
    canvas.drawCircle(c, u * 0.3, _s);
    _text(canvas, 'HOME', c + Offset(0, u * 0.62), max(7.5, u * 0.34), const Color(0xFFD9B873));
  }

  // ---- islands and beacons ------------------------------------------------

  void _islands(Canvas canvas, EmberLayout lay, double t) {
    final double u = lay.cell;
    final int targetIsland = g.order.island;
    for (int i = 0; i < g.chart.islands.length; i++) {
      final Offset c = lay.posOf(g.chart.islands[i]);
      final bool lit = i < g.lit.length && g.lit[i];
      final double r = u * 0.42;
      _s.strokeWidth = 1.4;
      _s.color = Colors.white.withValues(alpha: 0.16 + 0.06 * sin(t * 1.5 + i));
      canvas.drawCircle(c, r * (1.28 + 0.04 * sin(t * 1.5 + i)), _s);
      _p.color = const Color(0xFFC9B27A);
      canvas.drawCircle(c, r, _p);
      _p.color = const Color(0xFF2F7D4F);
      canvas.drawCircle(c + Offset(-r * 0.1, r * 0.1), r * 0.78, _p);
      _p.color = const Color(0xFF1F5E3A);
      canvas.drawCircle(c + Offset(-r * 0.42, r * 0.34), r * 0.28, _p);
      canvas.drawCircle(c + Offset(r * 0.38, r * 0.4), r * 0.22, _p);
      // beacon tower
      final Offset base = c + Offset(0, r * 0.45);
      final double tw = r * 0.5;
      final double th = r * 1.15;
      final Rect tower = Rect.fromLTWH(base.dx - tw / 2, base.dy - th, tw, th);
      _p.color = lit ? const Color(0xFFEDE6D6) : const Color(0xFF6B7280);
      canvas.drawRect(tower, _p);
      _p.color = lit ? const Color(0xFFD9534F) : const Color(0xFF3B4150);
      canvas.drawRect(Rect.fromLTWH(tower.left, tower.top + th * 0.36, tw, th * 0.22), _p);
      final Offset top = Offset(base.dx, tower.top - r * 0.12);
      if (lit) {
        final double fl = 0.9 + 0.1 * sin(t * 7 + i * 2);
        final Rect gr = Rect.fromCircle(center: top, radius: u * 1.9 * fl);
        final Paint glow = Paint()
          ..shader = const RadialGradient(colors: <Color>[Color(0x88FFE082), Color(0x00FFE082)]).createShader(gr);
        canvas.drawCircle(top, u * 1.9 * fl, glow);
        final double ang = t * 0.9 + i * 1.3;
        final Rect cr = Rect.fromCircle(center: top, radius: u * 3.4);
        final Paint cone = Paint()
          ..shader = const RadialGradient(colors: <Color>[Color(0x66FFE082), Color(0x00FFE082)]).createShader(cr);
        for (int s = 0; s < 2; s++) {
          canvas.drawArc(cr, ang + s * pi - 0.2, 0.4, true, cone);
        }
        _p.color = flame;
        canvas.drawCircle(top, r * 0.3, _p);
        _p.color = Colors.white.withValues(alpha: 0.9);
        canvas.drawCircle(top, r * 0.14, _p);
      } else {
        _p.color = const Color(0xFF232733);
        canvas.drawCircle(top, r * 0.3, _p);
        _p.color = const Color(0xFFB5472F).withValues(alpha: 0.35 + 0.25 * sin(t * 2 + i));
        canvas.drawCircle(top, r * 0.1, _p);
      }
      final double since = t - g.litAt[i];
      if (since >= 0 && since < 1.8) {
        _s.strokeWidth = 2.4;
        _s.color = flame.withValues(alpha: (1 - since / 1.8) * 0.8);
        canvas.drawCircle(top, u * (0.5 + since * 2.6), _s);
      }
      if (g.hintOn && !lit && i == targetIsland && (g.phase == emPlot || g.phase == emSail)) {
        final double pr = u * (0.85 + 0.08 * sin(t * 4));
        _s.strokeWidth = 2.4;
        _s.color = accent.withValues(alpha: 0.9);
        final int segs = 16;
        for (int k = 0; k < segs; k++) {
          final double a0 = k * 2 * pi / segs + t * 0.8;
          canvas.drawArc(Rect.fromCircle(center: c, radius: pr), a0, pi / segs * 1.1, false, _s);
        }
      }
      // the exact grid point of the island
      _s.strokeWidth = 1.4;
      _s.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(c, 2.4, _s);
    }
  }

  // ---- route and boat -----------------------------------------------------

  void _route(Canvas canvas, EmberLayout lay, double t) {
    final double u = lay.cell;
    final double wp = max(7.0, u * 0.32);
    if (g.phase == emSail) {
      Offset from = lay.pos(g.boatPos.dx, g.boatPos.dy);
      _s.strokeWidth = 1.8;
      _s.color = Colors.white.withValues(alpha: 0.4);
      for (int i = 0; i < g.sailPath.length - 1; i++) {
        if (g.sailCum[i + 1] <= g.sailDist) continue;
        final Offset b = lay.posOf(g.sailPath[i + 1]);
        _dash(canvas, from, b, _s, 7, 6, t * 14);
        _p.color = Colors.white.withValues(alpha: 0.4);
        canvas.drawCircle(b, wp * 0.6, _p);
        from = b;
      }
      return;
    }
    if (g.phase != emPlot) return;
    if (g.route.isNotEmpty) {
      _s.strokeWidth = 1.4;
      _s.color = accent.withValues(alpha: 0.5);
      canvas.drawCircle(lay.posOf(g.boat), u * 0.62, _s);
    }
    EP prev = g.boat;
    for (int i = 0; i < g.route.length; i++) {
      final EP q = g.route[i];
      final Offset a = lay.posOf(prev);
      final Offset b = lay.posOf(q);
      final bool bad = i < g.legReefs.length && g.legReefs[i] != null;
      _s.strokeWidth = (bad ? 3.4 : 2.6) + 3;
      _s.color = Colors.black.withValues(alpha: 0.35);
      canvas.drawLine(a, b, _s);
      _s.strokeWidth = bad ? 3.0 : 2.2;
      _s.color = bad ? const Color(0xFFFF5252) : const Color(0xFFE8FBFF);
      _dash(canvas, a, b, _s, 8, 6, t * 16);
      if (u >= 14) {
        final Offset mid = (a + b) / 2;
        final Offset d = b - a;
        final double len = d.distance;
        final Offset nrm = len < 1 ? const Offset(0, -1) : Offset(-d.dy / len, d.dx / len);
        final Offset at = mid + nrm * (u * 0.34 + 4);
        final TextPainter tp = _tp(prev.distanceTo(q).toStringAsFixed(1), max(9.0, min(13.0, u * 0.42)), Colors.white);
        final Rect pill = Rect.fromCenter(center: at, width: tp.width + 8, height: tp.height + 4);
        _p.color = (bad ? const Color(0xFF7A1F1F) : const Color(0xFF06222F)).withValues(alpha: 0.85);
        canvas.drawRRect(RRect.fromRectAndRadius(pill, const Radius.circular(6)), _p);
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }
      if (bad) {
        final EP? hit = g.legReefs[i];
        if (hit != null) {
          final Offset hc = lay.pos(hit.x + 0.5, hit.y + 0.5);
          final double xs = u * 0.28;
          _s.strokeWidth = 3;
          _s.color = const Color(0xFFFF5252);
          canvas.drawLine(hc + Offset(-xs, -xs), hc + Offset(xs, xs), _s);
          canvas.drawLine(hc + Offset(-xs, xs), hc + Offset(xs, -xs), _s);
        }
      }
      prev = q;
    }
    for (int i = 0; i < g.route.length; i++) {
      final Offset b = lay.posOf(g.route[i]);
      final bool bad = i < g.legReefs.length && g.legReefs[i] != null;
      if (i == g.route.length - 1) {
        _s.strokeWidth = 1.6;
        _s.color = (bad ? const Color(0xFFFF5252) : accent).withValues(alpha: 0.6);
        canvas.drawCircle(b, wp * (1.35 + 0.15 * sin(t * 5)), _s);
      }
      _p.color = bad ? const Color(0xFFFF5252) : accent;
      canvas.drawCircle(b, wp, _p);
      _s.strokeWidth = 1.5;
      _s.color = Colors.white;
      canvas.drawCircle(b, wp, _s);
      _text(canvas, '${i + 1}', b, wp * 1.15, const Color(0xFF04202A));
    }
  }

  void _boat(Canvas canvas, EmberLayout lay, double t) {
    final Offset c = lay.pos(g.boatPos.dx, g.boatPos.dy);
    final bool sailing = g.phase == emSail;
    if (sailing && g.wake.length > 1) {
      for (int i = 1; i < g.wake.length; i++) {
        final double f = i / g.wake.length;
        _s.strokeWidth = 1 + 4 * f;
        _s.color = Colors.white.withValues(alpha: 0.5 * f);
        canvas.drawLine(lay.pos(g.wake[i - 1].dx, g.wake[i - 1].dy), lay.pos(g.wake[i].dx, g.wake[i].dy), _s);
      }
    }
    final double s = max(lay.cell * 0.46, 8.0);
    final double bob = sailing ? sin(t * 9) * 0.8 : sin(t * 2) * 1.3;
    canvas.save();
    canvas.translate(c.dx, c.dy + bob);
    canvas.rotate(-g.boatHeading);
    _p.color = Colors.black.withValues(alpha: 0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset(0, s * 0.18), width: s * 2.0, height: s * 1.1), _p);
    // lantern light ahead
    final Rect lr = Rect.fromCircle(center: Offset(s * 0.8, 0), radius: lay.cell * 2.2);
    final Paint lightCone = Paint()
      ..shader = const RadialGradient(colors: <Color>[Color(0x55FFD54F), Color(0x00FFD54F)]).createShader(lr);
    canvas.drawArc(lr, -0.45, 0.9, true, lightCone);
    if (sailing) {
      _s.strokeWidth = 1.6;
      _s.color = Colors.white.withValues(alpha: 0.5);
      canvas.drawLine(Offset(-s * 0.7, -s * 0.3), Offset(-s * 1.9, -s * 0.9), _s);
      canvas.drawLine(Offset(-s * 0.7, s * 0.3), Offset(-s * 1.9, s * 0.9), _s);
    }
    final Path hull = Path()
      ..moveTo(s * 1.0, 0)
      ..quadraticBezierTo(s * 0.4, -s * 0.6, -s * 0.7, -s * 0.45)
      ..lineTo(-s * 0.7, s * 0.45)
      ..quadraticBezierTo(s * 0.4, s * 0.6, s * 1.0, 0)
      ..close();
    _p.color = const Color(0xFF8D5A32);
    canvas.drawPath(hull, _p);
    _s.strokeWidth = 1.4;
    _s.color = const Color(0xFF3E2A18);
    canvas.drawPath(hull, _s);
    _p.color = const Color(0xFFB07A4A);
    canvas.drawOval(Rect.fromCenter(center: Offset(-s * 0.05, 0), width: s * 1.2, height: s * 0.62), _p);
    final double wob = sin(t * 1.7) * 0.06;
    final Path sail = Path()
      ..moveTo(s * 0.15, 0)
      ..lineTo(-s * 0.6, -s * (0.3 + wob))
      ..lineTo(-s * 0.55, s * (0.3 - wob))
      ..close();
    _p.color = const Color(0xFFF4EBD6).withValues(alpha: 0.95);
    canvas.drawPath(sail, _p);
    _p.color = const Color(0xFF3E2A18);
    canvas.drawCircle(Offset(s * 0.15, 0), s * 0.07, _p);
    final double fl = 0.8 + 0.2 * sin(t * 9);
    final Rect gl = Rect.fromCircle(center: Offset(s * 0.8, 0), radius: s * 1.5 * fl);
    final Paint lantern = Paint()
      ..shader = const RadialGradient(colors: <Color>[Color(0xCCFFD54F), Color(0x00FFD54F)]).createShader(gl);
    canvas.drawCircle(Offset(s * 0.8, 0), s * 1.5 * fl, lantern);
    _p.color = const Color(0xFFFFF3C4);
    canvas.drawCircle(Offset(s * 0.8, 0), s * 0.16, _p);
    canvas.restore();
  }

  void _marks(Canvas canvas, EmberLayout lay, double t) {
    final Offset? m = g.offMark;
    if (m != null && t < g.offMarkUntil) {
      final Offset c = lay.pos(m.dx, m.dy);
      final double f = ((g.offMarkUntil - t) / 1.6).clamp(0.0, 1.0).toDouble();
      _s.strokeWidth = 3;
      _s.color = const Color(0xFFFF5252).withValues(alpha: f);
      canvas.drawCircle(c, lay.cell * (0.5 + (1 - f) * 0.6), _s);
      final double xs = lay.cell * 0.22;
      canvas.drawLine(c + Offset(-xs, -xs), c + Offset(xs, xs), _s);
      canvas.drawLine(c + Offset(-xs, xs), c + Offset(xs, -xs), _s);
    }
  }
}
