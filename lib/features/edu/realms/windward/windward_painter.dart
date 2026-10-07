import 'dart:math';
import 'package:flutter/material.dart';
import '../../odyssey/odyssey_questions.dart';
import '../realm_kit.dart';
import 'windward_logic.dart';

class WindwardPainter extends CustomPainter {
  final WindwardLogic logic;
  WindwardPainter(this.logic, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Path _path = Path();
  final Map<int, Path> _islandPaths = <int, Path>{};

  static const Color _seaA = Color(0xFF1565A0);
  static const Color _seaB = Color(0xFF0F3552);

  @override
  bool shouldRepaint(covariant WindwardPainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final WindwardLogic l = logic;
    final double w = size.width;
    final double h = size.height;
    final double ox = w / 2 - l.shipX;
    final double oy = h / 2 - l.shipY;

    _fill.color = Color.lerp(_seaA, _seaB, l.stormMix * 0.8) ?? _seaA;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);

    _waves(canvas, l, w, h, ox, oy);

    final int cx0 = ((-ox - 300.0) / windwardCellSize).floor();
    final int cx1 = ((w - ox + 300.0) / windwardCellSize).floor();
    final int cy0 = ((-oy - 300.0) / windwardCellSize).floor();
    final int cy1 = ((h - oy + 300.0) / windwardCellSize).floor();

    for (int cx = cx0; cx <= cx1; cx++) {
      for (int cy = cy0; cy <= cy1; cy++) {
        final WindwardPort? p = l.portAt(cx, cy);
        if (p != null) _island(canvas, l, p, ox, oy);
      }
    }
    for (int cx = cx0; cx <= cx1; cx++) {
      for (int cy = cy0; cy <= cy1; cy++) {
        final WindwardCell cell = l.cellAt(cx, cy);
        for (final WindwardReef r in cell.reefs) {
          _reef(canvas, l, r, ox, oy, w, h);
        }
      }
    }
    for (int cx = cx0; cx <= cx1; cx++) {
      for (int cy = cy0; cy <= cy1; cy++) {
        final WindwardPort? p = l.portAt(cx, cy);
        if (p != null) _portLabel(canvas, l, p, ox, oy, h);
      }
    }

    _wake(canvas, l, ox, oy);
    _noGo(canvas, l, w, h);
    _ship(canvas, l, w / 2, h / 2);
    _storms(canvas, l, ox, oy, w, h);
    _dusk(canvas, l, w, h);
    _windBadge(canvas, l, w / 2, h / 2 - 92.0);
    _compass(canvas, l, w - 46.0, 178.0);
    _contractArrow(canvas, l, w, h, ox, oy);
    _prompts(canvas, l, w, h);
  }

  // ---- sea ----------------------------------------------------------------

  void _waves(Canvas canvas, WindwardLogic l, double w, double h, double ox, double oy) {
    const double sp = 84.0;
    final int i0 = ((-ox) / sp).floor() - 1;
    final int i1 = ((w - ox) / sp).ceil() + 1;
    final int j0 = ((-oy) / sp).floor() - 1;
    final int j1 = ((h - oy) / sp).ceil() + 1;
    final double wx = cos(l.windDir);
    final double wy = sin(l.windDir);
    _line.strokeWidth = 1.6;
    for (int i = i0; i <= i1; i++) {
      for (int j = j0; j <= j1; j++) {
        final int hh = realmHash(i, j, 7);
        final double u1 = (hh % 1000) / 1000.0;
        final double u2 = ((hh ~/ 1000) % 1000) / 1000.0;
        final double ph = l.time * (1.1 + 0.5 * l.windStr) + (hh % 628) / 100.0;
        final double drift = sin(ph) * 6.0;
        final double sx = (i + 0.15 + 0.7 * u1) * sp + ox + wx * drift;
        final double sy = (j + 0.15 + 0.7 * u2) * sp + oy + wy * drift;
        final double a = 0.10 + 0.12 * (0.5 + 0.5 * sin(ph * 0.8));
        _line.color = Colors.white.withValues(alpha: a);
        _path.reset();
        _path.moveTo(sx - 10, sy);
        _path.quadraticBezierTo(sx - 5, sy - 4, sx, sy);
        _path.quadraticBezierTo(sx + 5, sy + 4, sx + 10, sy);
        canvas.drawPath(_path, _line);
      }
    }
  }

  // ---- islands ------------------------------------------------------------

  Path _blob(WindwardPort p) {
    final Path? hit = _islandPaths[p.key];
    if (hit != null) return hit;
    const int n = 16;
    final List<Offset> pts = <Offset>[];
    for (int i = 0; i < n; i++) {
      final double a = i * 2 * pi / n;
      final double r = p.radius * (0.84 + 0.16 * realmUnit(p.key, i, 5));
      pts.add(Offset(cos(a) * r, sin(a) * r));
    }
    final Path path = Path();
    final Offset m0 = Offset((pts[n - 1].dx + pts[0].dx) / 2, (pts[n - 1].dy + pts[0].dy) / 2);
    path.moveTo(m0.dx, m0.dy);
    for (int i = 0; i < n; i++) {
      final Offset a = pts[i];
      final Offset b = pts[(i + 1) % n];
      path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    }
    path.close();
    if (_islandPaths.length > 40) _islandPaths.clear();
    _islandPaths[p.key] = path;
    return path;
  }

  void _island(Canvas canvas, WindwardLogic l, WindwardPort p, double ox, double oy) {
    final double sx = p.x + ox;
    final double sy = p.y + oy;
    final Offset c = Offset(sx, sy);
    final OdySubject subj = l.content.subject(p.subjectId);
    final double pulse = 0.5 + 0.5 * sin(l.time * 2.0 + p.radius);

    _fill.color = const Color(0xFF4DD0E1).withValues(alpha: 0.20);
    canvas.drawCircle(c, p.radius + 78.0, _fill);
    _fill.color = const Color(0xFF80DEEA).withValues(alpha: 0.22);
    canvas.drawCircle(c, p.radius + 38.0, _fill);
    _line.strokeWidth = 2.0 + pulse * 1.5;
    _line.color = Colors.white.withValues(alpha: 0.35 + 0.2 * pulse);
    canvas.drawCircle(c, p.radius * 1.02 + 6.0 + pulse * 3.0, _line);

    final Path blob = _blob(p);
    canvas.save();
    canvas.translate(sx, sy);
    _fill.color = const Color(0xFFEBD9A4);
    canvas.save();
    canvas.scale(1.1, 1.1);
    canvas.drawPath(blob, _fill);
    canvas.restore();
    final Color land = Color.lerp(const Color(0xFF4C9A4A), subj.color, 0.5) ?? subj.color;
    _fill.color = land;
    canvas.drawPath(blob, _fill);
    _fill.color = realmLighten(land, 0.08);
    canvas.drawCircle(Offset(-p.radius * 0.12, -p.radius * 0.1), p.radius * 0.5, _fill);
    // trees
    for (int i = 0; i < 6; i++) {
      final double a = realmUnit(p.key, i, 21) * 2 * pi;
      final double d = p.radius * (0.2 + 0.5 * realmUnit(p.key, i, 22));
      final double tx = cos(a) * d;
      final double ty = sin(a) * d;
      _fill.color = realmDarken(land, 0.14);
      canvas.drawCircle(Offset(tx, ty), 5.5 + 3.0 * realmUnit(p.key, i, 23), _fill);
      _fill.color = realmLighten(land, 0.18);
      canvas.drawCircle(Offset(tx - 1.5, ty - 1.5), 2.6, _fill);
    }
    // pier toward the dock side
    canvas.save();
    canvas.rotate(p.dockAngle);
    _fill.color = const Color(0xFF6D4C41);
    canvas.drawRect(Rect.fromLTRB(p.radius * 0.78, -4.5, p.radius + 30.0, 4.5), _fill);
    _fill.color = const Color(0xFF8D6E63);
    canvas.drawRect(Rect.fromLTRB(p.radius + 22.0, -9.0, p.radius + 32.0, 9.0), _fill);
    canvas.restore();
    // flag in the subject colour
    _line.strokeWidth = 2.4;
    _line.color = Colors.white;
    canvas.drawLine(const Offset(0, 6), const Offset(0, -26), _line);
    final double flap = sin(l.time * 4.0 + p.radius) * 2.0;
    _path.reset();
    _path.moveTo(1, -26);
    _path.lineTo(17, -21 + flap);
    _path.lineTo(1, -15);
    _path.close();
    _fill.color = realmLighten(subj.color, 0.1);
    canvas.drawPath(_path, _fill);
    canvas.restore();

    if (l.portInRange == p) {
      _line.strokeWidth = 3.0;
      _line.color = const Color(0xFF69F0AE).withValues(alpha: 0.45 + 0.4 * pulse);
      canvas.drawCircle(c, p.dockRadius, _line);
    }
    final WindwardContract? ac = l.active;
    if (ac != null && ac.toKey == p.key) {
      final double by = sy - p.radius - 22.0 - pulse * 5.0;
      _fill.color = const Color(0xFFFFD54F);
      canvas.drawCircle(Offset(sx, by), 11.0, _fill);
      RealmDraw.text(canvas, '!', Offset(sx, by), 16, const Color(0xFF3E2723), maxWidth: 20, maxLines: 1);
    }
  }

  void _portLabel(Canvas canvas, WindwardLogic l, WindwardPort p, double ox, double oy, double h) {
    final double sx = p.x + ox;
    final double sy = p.y + oy + p.radius + 22.0;
    if (sy < 96.0 || sy > h + 20.0) return;
    final OdySubject subj = l.content.subject(p.subjectId);
    final RRect r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(sx, sy), width: 132, height: 34), const Radius.circular(10));
    _fill.color = realmDarken(subj.color, 0.12).withValues(alpha: 0.88);
    canvas.drawRRect(r, _fill);
    _line.strokeWidth = 1.2;
    _line.color = Colors.white.withValues(alpha: 0.6);
    canvas.drawRRect(r, _line);
    RealmDraw.text(canvas, p.name, Offset(sx, sy - 7), 13, Colors.white, maxWidth: 124, maxLines: 1);
    RealmDraw.text(canvas, subj.label, Offset(sx, sy + 8), 10.5, Colors.white70, bold: false, maxWidth: 124, maxLines: 1);
    if (l.portInRange == p) {
      RealmDraw.label(canvas, 'Tap ANCHOR to dock', Offset(sx, sy + 22), size: 12, maxWidth: 180);
    }
  }

  void _reef(Canvas canvas, WindwardLogic l, WindwardReef r, double ox, double oy, double w, double h) {
    final double sx = r.x + ox;
    final double sy = r.y + oy;
    if (sx < -60 || sx > w + 60 || sy < -60 || sy > h + 60) return;
    final Offset c = Offset(sx, sy);
    final double pulse = 0.5 + 0.5 * sin(l.time * 2.4 + r.phase);
    if (r.rock) {
      _fill.color = const Color(0xFF263238).withValues(alpha: 0.35);
      canvas.drawCircle(c, r.r * 1.5, _fill);
      _fill.color = const Color(0xFF4A5560);
      canvas.drawCircle(c, r.r, _fill);
      _fill.color = const Color(0xFF78909C);
      canvas.drawCircle(c + Offset(-r.r * 0.25, -r.r * 0.3), r.r * 0.5, _fill);
      _fill.color = const Color(0xFF37424A);
      canvas.drawCircle(c + Offset(r.r * 0.5, r.r * 0.35), r.r * 0.38, _fill);
    } else {
      _fill.color = const Color(0xFF26A69A).withValues(alpha: 0.38);
      canvas.drawCircle(c, r.r * 1.7, _fill);
      _fill.color = const Color(0xFF6D4C41);
      canvas.drawCircle(c, r.r, _fill);
      _fill.color = const Color(0xFFA1887F);
      canvas.drawCircle(c + Offset(-r.r * 0.3, -r.r * 0.2), r.r * 0.45, _fill);
      _fill.color = const Color(0xFF8D6E63);
      canvas.drawCircle(c + Offset(r.r * 0.45, r.r * 0.3), r.r * 0.4, _fill);
    }
    _line.strokeWidth = 2.0;
    _line.color = Colors.white.withValues(alpha: 0.35 + 0.35 * pulse);
    canvas.drawCircle(c, r.r + 3.0 + pulse * 3.0, _line);
  }

  // ---- ship ---------------------------------------------------------------

  void _wake(Canvas canvas, WindwardLogic l, double ox, double oy) {
    for (int i = 0; i < WindwardLogic.wakeSize; i++) {
      final double age = l.wakeAge[i];
      if (age > 1.8) continue;
      final double t = age / 1.8;
      _fill.color = Colors.white.withValues(alpha: (1.0 - t) * 0.32);
      canvas.drawCircle(Offset(l.wakeX[i] + ox, l.wakeY[i] + oy), 3.0 + t * 8.0, _fill);
    }
  }

  void _noGo(Canvas canvas, WindwardLogic l, double w, double h) {
    if (l.anchored) return;
    final double up = l.windDir + pi;
    final Rect r = Rect.fromCircle(center: Offset(w / 2, h / 2), radius: 78.0);
    _fill.color = const Color(0xFFFF5252).withValues(alpha: 0.10 + 0.08 * (l.intoWind < windwardNoGo * 1.4 ? 1.0 : 0.0));
    canvas.drawArc(r, up - windwardNoGo, windwardNoGo * 2, true, _fill);
  }

  void _ship(Canvas canvas, WindwardLogic l, double cx, double cy) {
    if (l.sunk) return;
    final double roll = sin(l.time * 2.2) * 0.03 * (1.0 + l.rough * 2.0);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(l.heading + roll);
    final double sc = 1.15;
    canvas.scale(sc, sc);

    // bow wave
    final double sp = windwardCl(l.speed / windwardBaseSpeed, 0.0, 1.4);
    if (sp > 0.05) {
      _fill.color = Colors.white.withValues(alpha: 0.35 + 0.3 * sp);
      _path.reset();
      _path.moveTo(28, 0);
      _path.lineTo(14, -10 - 6 * sp);
      _path.lineTo(18, 0);
      _path.lineTo(14, 10 + 6 * sp);
      _path.close();
      canvas.drawPath(_path, _fill);
    }
    if (l.trimT > 0) {
      _line.strokeWidth = 2.4;
      for (int i = 0; i < 3; i++) {
        _line.color = Colors.white.withValues(alpha: 0.45 - i * 0.1);
        canvas.drawLine(Offset(-26.0 - i * 9.0, -8.0 + i * 8.0), Offset(-44.0 - i * 9.0, -8.0 + i * 8.0), _line);
      }
    }

    // hull
    _fill.color = Colors.black.withValues(alpha: 0.22);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-1, 3), width: 56, height: 26), _fill);
    _path.reset();
    _path.moveTo(28, 0);
    _path.quadraticBezierTo(18, -11, -8, -11);
    _path.lineTo(-22, -9);
    _path.quadraticBezierTo(-27, 0, -22, 9);
    _path.lineTo(-8, 11);
    _path.quadraticBezierTo(18, 11, 28, 0);
    _path.close();
    _fill.color = const Color(0xFF7A4A28);
    canvas.drawPath(_path, _fill);
    _line.strokeWidth = 1.6;
    _line.color = const Color(0xFF3E2723);
    canvas.drawPath(_path, _line);
    _path.reset();
    _path.moveTo(22, 0);
    _path.quadraticBezierTo(15, -7, -6, -7);
    _path.lineTo(-18, -5.5);
    _path.quadraticBezierTo(-21, 0, -18, 5.5);
    _path.lineTo(-6, 7);
    _path.quadraticBezierTo(15, 7, 22, 0);
    _path.close();
    _fill.color = const Color(0xFFB98A55);
    canvas.drawPath(_path, _fill);

    // sail: the boom swings to the side the wind blows toward
    final double wl = windwardWrap(l.windDir - l.heading);
    final double side = sin(wl) >= 0 ? 1.0 : -1.0;
    final double open = 0.18 + 1.0 * (l.intoWind / pi);
    final double ang = pi - side * open;
    final double len = 30.0;
    final double tx = 4.0 + cos(ang) * len;
    final double ty = sin(ang) * len;
    final double bulge = 7.0 * (0.4 + 0.6 * windwardCl(l.windStr / 1.3, 0.0, 1.0)) * (l.intoWind < windwardNoGo ? 0.2 : 1.0);
    double px = -sin(ang);
    double py = cos(ang);
    if (px * cos(wl) + py * sin(wl) < 0) {
      px = -px;
      py = -py;
    }
    final double mx = (4.0 + tx) / 2 + px * bulge;
    final double my = ty / 2 + py * bulge;
    _path.reset();
    _path.moveTo(4, 0);
    _path.quadraticBezierTo(mx, my, tx, ty);
    _path.close();
    _fill.color = const Color(0xFFFFF8E1);
    canvas.drawPath(_path, _fill);
    _line.strokeWidth = 1.4;
    _line.color = const Color(0xFF8D6E63);
    canvas.drawLine(const Offset(4, 0), Offset(tx, ty), _line);
    _fill.color = const Color(0xFF5D4037);
    canvas.drawCircle(const Offset(4, 0), 3.2, _fill);
    // pennant showing the wind
    final double pw = windwardWrap(l.windDir - l.heading);
    _line.strokeWidth = 2.0;
    _line.color = const Color(0xFFFF7043);
    canvas.drawLine(const Offset(4, 0), Offset(4 + cos(pw) * 9.0, sin(pw) * 9.0), _line);

    if (l.hitCd > 0 && (l.hitCd * 10).floor() % 2 == 0) {
      _fill.color = const Color(0xFFFF1744).withValues(alpha: 0.45);
      canvas.drawCircle(Offset.zero, 26, _fill);
    }
    canvas.restore();

    if (l.anchored && l.harbour == null) {
      _line.strokeWidth = 2.0;
      _line.color = Colors.white.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(cx, cy), 34, _line);
      RealmDraw.label(canvas, 'ANCHORED', Offset(cx, cy + 38), size: 11, maxWidth: 100);
    }
  }

  // ---- weather ------------------------------------------------------------

  void _storms(Canvas canvas, WindwardLogic l, double ox, double oy, double w, double h) {
    for (int i = 0; i < l.stormCount; i++) {
      final WindwardStorm s = l.storms[i];
      if (s.r < 8) continue;
      final double sx = s.x + ox;
      final double sy = s.y + oy;
      if (sx + s.r < -20 || sx - s.r > w + 20 || sy + s.r < -20 || sy - s.r > h + 20) continue;
      final Offset c = Offset(sx, sy);
      _fill.color = const Color(0xFF1B2733).withValues(alpha: 0.30);
      canvas.drawCircle(c, s.r, _fill);
      for (int k = 0; k < 7; k++) {
        final double a = k * 0.9 + l.time * 0.05;
        final double d = s.r * 0.45;
        final double rr = s.r * (0.38 + 0.08 * sin(l.time * 0.6 + k));
        _fill.color = const Color(0xFF263544).withValues(alpha: 0.22);
        canvas.drawCircle(c + Offset(cos(a) * d, sin(a) * d), rr, _fill);
      }
      _line.strokeWidth = 2.0;
      _line.color = const Color(0xFFB0BEC5).withValues(alpha: 0.35);
      canvas.drawCircle(c, s.r, _line);
      // rain
      _line.strokeWidth = 1.4;
      _line.color = const Color(0xFFCFD8DC).withValues(alpha: 0.45);
      for (int k = 0; k < 16; k++) {
        final double a = realmUnit(i, k, 3) * 2 * pi;
        final double d = s.r * 0.8 * realmUnit(i, k, 4);
        final double fall = (l.time * 1.6 + realmUnit(i, k, 5)) % 1.0;
        final double px = sx + cos(a) * d - fall * 6.0;
        final double py = sy + sin(a) * d + fall * 22.0 - 10.0;
        canvas.drawLine(Offset(px, py), Offset(px - 3, py + 9), _line);
      }
      if (sin(l.time * 5.0 + i * 2.0) > 0.985) {
        _fill.color = Colors.white.withValues(alpha: 0.22);
        canvas.drawCircle(c, s.r * 0.8, _fill);
      }
    }
  }

  void _dusk(Canvas canvas, WindwardLogic l, double w, double h) {
    final double t = windwardCl(l.time / windwardRunSeconds, 0.0, 1.0);
    final double a = 0.22 * t * t;
    if (a < 0.01) return;
    _fill.color = const Color(0xFFFF7043).withValues(alpha: a);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _fill);
  }

  // ---- instruments --------------------------------------------------------

  void _arrow(Canvas canvas, Offset c, double angle, double len, double headSize, Color color) {
    final double ca = cos(angle);
    final double sa = sin(angle);
    _line.strokeWidth = 2.6;
    _line.color = color;
    canvas.drawLine(Offset(c.dx - ca * len, c.dy - sa * len), Offset(c.dx + ca * len * 0.6, c.dy + sa * len * 0.6), _line);
    final Offset tip = Offset(c.dx + ca * len, c.dy + sa * len);
    _path.reset();
    _path.moveTo(tip.dx, tip.dy);
    _path.lineTo(tip.dx - ca * headSize + sa * headSize * 0.6, tip.dy - sa * headSize - ca * headSize * 0.6);
    _path.lineTo(tip.dx - ca * headSize - sa * headSize * 0.6, tip.dy - sa * headSize + ca * headSize * 0.6);
    _path.close();
    _fill.color = color;
    canvas.drawPath(_path, _fill);
  }

  void _windBadge(Canvas canvas, WindwardLogic l, double cx, double cy) {
    final Offset c = Offset(cx, cy);
    _fill.color = Colors.black.withValues(alpha: 0.42);
    canvas.drawCircle(c, 25.0, _fill);
    _arrow(canvas, c, l.windDir, 8.0 + 8.0 * windwardCl(l.windStr / 1.5, 0.0, 1.0), 7.0, const Color(0xFF80D8FF));
    RealmDraw.text(canvas, '${l.windKnots} kn', Offset(cx, cy + 36), 12, Colors.white, maxWidth: 70, maxLines: 1);
  }

  void _compass(Canvas canvas, WindwardLogic l, double cx, double cy) {
    final Offset c = Offset(cx, cy);
    const double r = 30.0;
    _fill.color = Colors.black.withValues(alpha: 0.5);
    canvas.drawCircle(c, r, _fill);
    _line.strokeWidth = 1.6;
    _line.color = Colors.white.withValues(alpha: 0.55);
    canvas.drawCircle(c, r, _line);
    final double up = l.windDir + pi;
    _fill.color = const Color(0xFFFF5252).withValues(alpha: 0.35);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 2), up - windwardNoGo, windwardNoGo * 2, true, _fill);
    for (int i = 0; i < 4; i++) {
      final double a = i * pi / 2 - pi / 2;
      _line.strokeWidth = i == 0 ? 2.4 : 1.2;
      _line.color = i == 0 ? const Color(0xFFFF8A80) : Colors.white54;
      canvas.drawLine(Offset(cx + cos(a) * (r - 6), cy + sin(a) * (r - 6)), Offset(cx + cos(a) * r, cy + sin(a) * r), _line);
    }
    RealmDraw.text(canvas, 'N', Offset(cx, cy - r - 8), 11, const Color(0xFFFF8A80), maxWidth: 16, maxLines: 1);
    _arrow(canvas, c, l.windDir, 16.0, 6.0, const Color(0xFF80D8FF));
    // ship heading
    final double ha = l.heading;
    _path.reset();
    _path.moveTo(cx + cos(ha) * 13, cy + sin(ha) * 13);
    _path.lineTo(cx + cos(ha + 2.5) * 7, cy + sin(ha + 2.5) * 7);
    _path.lineTo(cx + cos(ha - 2.5) * 7, cy + sin(ha - 2.5) * 7);
    _path.close();
    _fill.color = Colors.white;
    canvas.drawPath(_path, _fill);
    final double left = windwardCl(windwardRunSeconds - l.time, 0.0, windwardRunSeconds);
    final int mins = (left / 60).floor();
    final int secs = (left % 60).floor();
    final String ss = secs < 10 ? '0$secs' : '$secs';
    RealmDraw.text(canvas, '$mins:$ss  Day ${l.day}', Offset(cx - 6, cy + r + 12), 11, Colors.white, maxWidth: 90, maxLines: 1);
  }

  void _contractArrow(Canvas canvas, WindwardLogic l, double w, double h, double ox, double oy) {
    final WindwardContract? c = l.active;
    if (c == null) return;
    final double dx = c.toX - l.shipX;
    final double dy = c.toY - l.shipY;
    final double dist = sqrt(dx * dx + dy * dy);
    final double sx = c.toX + ox;
    final double sy = c.toY + oy;
    const double left = 34.0;
    final double right = w - 34.0;
    const double top = 124.0;
    final double bottom = h - 70.0;
    if (sx > left && sx < right && sy > top && sy < bottom) return;
    final double cx = w / 2;
    final double cy = h / 2;
    double t = 1e9;
    if (dx > 0.001) {
      final double tt = (right - cx) / dx;
      if (tt < t) t = tt;
    } else if (dx < -0.001) {
      final double tt = (left - cx) / dx;
      if (tt < t) t = tt;
    }
    if (dy > 0.001) {
      final double tt = (bottom - cy) / dy;
      if (tt < t) t = tt;
    } else if (dy < -0.001) {
      final double tt = (top - cy) / dy;
      if (tt < t) t = tt;
    }
    if (t > 1e8) return;
    double ax = cx + dx * t;
    double ay = cy + dy * t;
    if (ax > w - 170.0 && ay > h - 190.0) ay = h - 190.0;
    final double ang = atan2(dy, dx);
    final Offset p = Offset(ax, ay);
    _fill.color = Colors.black.withValues(alpha: 0.5);
    canvas.drawCircle(p, 20.0, _fill);
    _arrow(canvas, p, ang, 12.0, 8.0, const Color(0xFFFFD54F));
    final double lx = windwardCl(ax, 70.0, w - 70.0);
    final double ly = ay < h / 2 ? ay + 32.0 : ay - 46.0;
    RealmDraw.label(canvas, '${c.toName}  ${(dist / 10).round()} nm', Offset(lx, ly), size: 11, maxWidth: 130);
  }

  void _prompts(Canvas canvas, WindwardLogic l, double w, double h) {
    if (l.toastT > 0 && l.toast.isNotEmpty) {
      RealmDraw.label(canvas, l.toast, Offset(w / 2 - 24.0, h * 0.27), size: 13.5, maxWidth: w - 120.0);
    }
    if (l.inStorm) {
      RealmDraw.label(canvas, 'Rough water', Offset(w / 2, h / 2 + 62.0), size: 11, maxWidth: 120);
    } else if (!l.anchored && l.intoWind < windwardNoGo && l.speed < 30) {
      RealmDraw.label(canvas, 'Head into the wind. Turn away to fill the sails.', Offset(w / 2, h / 2 + 62.0), size: 11, maxWidth: 200);
    }
  }
}
