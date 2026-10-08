import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'signal_boards.dart';
import 'signal_logic.dart';

/// Draws Signal Ridge: the mountain backdrop, the route map, the bot board
/// and the circuit diagram.
class SignalPainter extends CustomPainter {
  final SignalLogic g;
  SignalPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  static const Color _ink = Color(0xFF14161C);
  static const Color _wireOn = Color(0xFFFFB347);
  static const Color _wireOff = Color(0xFF3E6EA8);
  static const Color _wireUnknown = Color(0xFF4B5060);

  @override
  void paint(Canvas canvas, Size size) {
    _backdrop(canvas, size);
    if (g.phase == 0) {
      _map(canvas, size);
    } else if (g.kind == 1) {
      _circuit(canvas, size);
    } else {
      _board(canvas, size);
    }
  }

  @override
  bool shouldRepaint(covariant SignalPainter oldDelegate) => true;

  // ---- backdrop ------------------------------------------------------------

  double _ridgeY(double x, double base, double amp, double freq, double phase) {
    final double a = 1 - sin(x * freq + phase).abs();
    final double b = 1 - sin(x * freq * 2.17 + phase * 1.7).abs();
    return base - amp * (0.65 * a + 0.35 * b);
  }

  void _backdrop(Canvas canvas, Size size) {
    final bool fog = g.stage == 5;
    final Rect all = Offset.zero & size;
    final List<Color> sky = fog
        ? const <Color>[Color(0xFF8C98AA), Color(0xFFC9D0DA), Color(0xFFE9ECF1)]
        : const <Color>[Color(0xFF160E33), Color(0xFF4A2468), Color(0xFFD2573A), Color(0xFFFFA45C)];
    final List<double> stops = fog ? const <double>[0.0, 0.6, 1.0] : const <double>[0.0, 0.38, 0.72, 1.0];
    canvas.drawRect(
      all,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height * 0.62), sky, stops),
    );
    if (!fog) {
      final Paint sp = Paint();
      for (int i = 0; i < 44; i++) {
        final double x = realmUnit(i, 1, 3) * size.width;
        final double y = realmUnit(i, 2, 3) * size.height * 0.36;
        final double tw = 0.5 + 0.5 * sin(g.time * 2 + i);
        sp.color = Colors.white.withValues(alpha: 0.2 + 0.6 * tw);
        canvas.drawCircle(Offset(x, y), 0.8 + realmUnit(i, 3, 3) * 1.1, sp);
      }
      final Offset sun = Offset(size.width * 0.76, size.height * 0.4);
      RealmDraw.glow(canvas, sun, 70, const Color(0xFFFFB066), alpha: 0.12);
      RealmDraw.glow(canvas, sun, 46, const Color(0xFFFFC27A), alpha: 0.22);
      RealmDraw.glow(canvas, sun, 30, const Color(0xFFFFE0A8), alpha: 0.9);
    }
    final List<Color> cols = fog
        ? const <Color>[Color(0xFFAEB8C6), Color(0xFF93A0B2), Color(0xFF7D8A9D)]
        : const <Color>[Color(0xFF3A2A5E), Color(0xFF2A1E48), Color(0xFF1C1432)];
    const List<double> bases = <double>[0.50, 0.60, 0.70];
    const List<double> amps = <double>[0.16, 0.13, 0.10];
    const List<double> freqs = <double>[0.011, 0.017, 0.026];
    const List<double> par = <double>[0.25, 0.5, 0.9];
    for (int l = 0; l < 3; l++) {
      final double scroll = g.panX * par[l] + g.time * par[l] * 2;
      final Path path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width + 8; x += 8) {
        path.lineTo(x, _ridgeY(x + scroll, size.height * bases[l], size.height * amps[l], freqs[l], l * 1.9));
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, Paint()..color = cols[l]);
    }
    if (!fog) {
      final Paint tp = Paint()..color = const Color(0xFF120C24);
      for (double x = 14; x < size.width; x += 38) {
        final double s = g.panX * 0.9 + g.time * 1.8;
        final double y = _ridgeY(x + s, size.height * 0.70, size.height * 0.10, 0.026, 3 * 1.9);
        final double hgt = 10 + realmUnit(x.toInt(), 5, 5) * 8;
        final Path t = Path()
          ..moveTo(x, y - hgt)
          ..lineTo(x - hgt * 0.38, y + 1)
          ..lineTo(x + hgt * 0.38, y + 1)
          ..close();
        canvas.drawPath(t, tp);
      }
    }
  }

  // ---- shared shapes -----------------------------------------------------------

  Path _starPath(Offset c, double r) {
    final Path p = Path();
    for (int i = 0; i < 10; i++) {
      final double rr = i.isEven ? r : r * 0.45;
      final double a = -pi / 2 + i * pi / 5;
      final Offset o = Offset(c.dx + cos(a) * rr, c.dy + sin(a) * rr);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    p.close();
    return p;
  }

  void _stars(Canvas canvas, Offset c, int n, double r) {
    for (int i = 0; i < 3; i++) {
      final Offset o = Offset(c.dx + (i - 1) * r * 2.3, c.dy);
      canvas.drawPath(_starPath(o, r), Paint()..color = i < n ? sgGold : const Color(0x55FFFFFF));
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint, double dash, double gap) {
    for (final ui.PathMetric m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final double e = min(d + dash, m.length);
        canvas.drawPath(m.extractPath(d, e), paint);
        d += dash + gap;
      }
    }
  }

  void _rings(Canvas canvas, Offset c, double r, double phase, double alpha, Color color) {
    for (int k = 0; k < 2; k++) {
      double f = phase + k * 0.5;
      f = f - f.floorToDouble();
      canvas.drawCircle(
        c,
        r * (0.35 + 0.9 * f),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: alpha * (1 - f)),
      );
    }
  }

  void _house(Canvas canvas, Offset c, double s, bool lit) {
    canvas.drawRect(Rect.fromCenter(center: c, width: s * 1.3, height: s), Paint()..color = const Color(0xFF3B2F3F));
    final Path roof = Path()
      ..moveTo(c.dx - s * 0.85, c.dy - s * 0.5)
      ..lineTo(c.dx, c.dy - s * 1.2)
      ..lineTo(c.dx + s * 0.85, c.dy - s * 0.5)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF6B3F4C));
    canvas.drawRect(
      Rect.fromCenter(center: c + Offset(0, s * 0.05), width: s * 0.38, height: s * 0.38),
      Paint()..color = lit ? const Color(0xFFFFE082) : const Color(0xFF1B1626),
    );
  }

  // ---- map -------------------------------------------------------------------------

  void _map(Canvas canvas, Size size) {
    final Rect a = g.arena(size);
    final double w = min(a.width, 460.0);
    final Rect r = Rect.fromLTWH(a.center.dx - w / 2, a.top, w, a.height);
    const List<double> fx = <double>[0.20, 0.68, 0.30, 0.72, 0.28, 0.62];
    const List<double> fy = <double>[0.86, 0.72, 0.57, 0.42, 0.26, 0.09];
    final List<Offset> nodes = <Offset>[
      for (int i = 0; i < 6; i++) Offset(r.left + r.width * fx[i], r.top + r.height * fy[i]),
    ];
    for (int i = 0; i < 5; i++) {
      final Offset p = nodes[i];
      final Offset q = nodes[i + 1];
      final double my = (p.dy + q.dy) / 2;
      final Path path = Path()
        ..moveTo(p.dx, p.dy)
        ..cubicTo(p.dx, my, q.dx, my, q.dx, q.dy);
      final bool done = g.doneBy[i];
      if (done) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = sgAccentColor.withValues(alpha: 0.2),
        );
      }
      _dashed(
        canvas,
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3.4
          ..color = done ? sgAccentColor : Colors.white.withValues(alpha: 0.35),
        9,
        7,
      );
    }
    for (int i = 0; i < 6; i++) {
      final Offset n = nodes[i];
      final bool done = g.doneBy[i];
      final bool current = i == g.stage && !done;
      final bool boss = i == 5;
      final double nr = boss ? 22.0 : 17.0;
      final bool leftSide = fx[i] < 0.5;
      final double side = leftSide ? 1.0 : -1.0;
      _house(canvas, n + Offset(-side * 30, 6), 11, done);
      _house(canvas, n + Offset(-side * 44, 10), 8, done);
      if (done) {
        _rings(canvas, n, 40, g.time * 0.6 + i * 0.2, 0.6, sgAccentColor);
        RealmDraw.glow(canvas, n, nr + 10, sgAccentColor, alpha: 0.3);
      }
      if (current) {
        final double pulse = 4 + 4 * sin(g.time * 4);
        canvas.drawCircle(
          n,
          nr + 6 + pulse,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..color = Colors.white.withValues(alpha: 0.8),
        );
      }
      canvas.drawCircle(n, nr, Paint()..color = done ? sgAccentColor : (current ? _ink : const Color(0xFF2A2D38)));
      canvas.drawCircle(
        n,
        nr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = done || current ? Colors.white : Colors.white30,
      );
      RealmDraw.text(canvas, '${i + 1}', n, boss ? 22.0 : 18.0, done ? _ink : Colors.white, maxWidth: 40);
      if (boss && !done) {
        final Paint cp = Paint()..color = const Color(0xFF59606E);
        final Offset cc = n + const Offset(0, -34);
        canvas.drawCircle(cc + const Offset(-14, 4), 11, cp);
        canvas.drawCircle(cc + const Offset(0, -2), 14, cp);
        canvas.drawCircle(cc + const Offset(15, 4), 10, cp);
        canvas.drawRect(Rect.fromLTWH(cc.dx - 20, cc.dy + 4, 40, 8), cp);
      }
      final Offset label = n + Offset(side * 70, 0);
      RealmDraw.text(canvas, sgStageNames[i], label, 13, Colors.white, maxWidth: 110);
      if (done) {
        _stars(canvas, label + const Offset(0, 17), g.starsBy[i], 6);
      } else {
        RealmDraw.text(canvas, i == 3 ? 'Circuits' : (i == 4 ? 'Debugging' : (i == 5 ? 'Boss' : 'Program')), label + const Offset(0, 16), 11, Colors.white54, bold: false, maxWidth: 110);
      }
    }
  }

  // ---- board -------------------------------------------------------------------------

  void _board(Canvas canvas, Size size) {
    final SBoard? b = g.board;
    if (b == null) return;
    final Rect a = g.arena(size);
    final double cs = min(min(a.width / b.w, a.height / b.h), 56.0);
    final double ox = a.center.dx - cs * b.w / 2;
    final double oy = a.center.dy - cs * b.h / 2;
    final Rect gr = Rect.fromLTWH(ox, oy, cs * b.w, cs * b.h);
    final bool fog = b.fog;
    final List<double> pose = g.botPose();
    final int bx = pose[0].round();
    final int by = pose[1].round();
    bool vis(int x, int y) => !fog || ((x - bx).abs() <= 1 && (y - by).abs() <= 1);
    bool mem(int x, int y) => fog && g.explored.contains(y * b.w + x);
    Offset cc(num x, num y) => Offset(ox + (x + 0.5) * cs, oy + (y + 0.5) * cs);
    final int litMask = g.litShown;

    canvas.drawRRect(
      RRect.fromRectAndRadius(gr.inflate(7).shift(const Offset(0, 4)), const Radius.circular(12)),
      Paint()
        ..color = const Color(0x77000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(RRect.fromRectAndRadius(gr.inflate(6), const Radius.circular(12)), Paint()..color = const Color(0xFF3A2A1C));

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(gr, const Radius.circular(6)));
    final Paint tile = Paint();
    for (int y = 0; y < b.h; y++) {
      for (int x = 0; x < b.w; x++) {
        final Rect cell = Rect.fromLTWH(ox + x * cs, oy + y * cs, cs + 0.5, cs + 0.5);
        final bool shown = vis(x, y) || mem(x, y);
        Color base;
        if (fog) {
          base = shown ? ((x + y).isEven ? const Color(0xFF8FA39B) : const Color(0xFF879B93)) : ((x + y).isEven ? const Color(0xFFDDE3EA) : const Color(0xFFD3DAE3));
        } else {
          base = (x + y).isEven ? const Color(0xFF5E8A47) : const Color(0xFF55803F);
        }
        base = Color.lerp(base, Colors.white, realmUnit(x, y, 1) * 0.06) ?? base;
        tile.color = base;
        canvas.drawRect(cell, tile);
        if (fog && !shown) {
          final double sw = sin(g.time * 0.8 + x * 1.3 + y * 0.7);
          canvas.drawCircle(cell.center + Offset(sw * cs * 0.12, 0), cs * 0.3, Paint()..color = Colors.white.withValues(alpha: 0.35));
        }
      }
    }
    final Paint gl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x14000000);
    for (int x = 0; x <= b.w; x++) {
      canvas.drawLine(Offset(ox + x * cs, oy), Offset(ox + x * cs, oy + b.h * cs), gl);
    }
    for (int y = 0; y <= b.h; y++) {
      canvas.drawLine(Offset(ox, oy + y * cs), Offset(ox + b.w * cs, oy + y * cs), gl);
    }

    // start pad
    final Offset sc = cc(b.sx, b.sy);
    canvas.drawCircle(sc, cs * 0.42, Paint()..color = Colors.white.withValues(alpha: 0.12));
    canvas.drawCircle(
      sc,
      cs * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.5),
    );

    // footprints
    _trail(canvas, b, cc, cs);

    // rocks
    for (int y = 0; y < b.h; y++) {
      for (int x = 0; x < b.w; x++) {
        if (!b.rock[y][x]) continue;
        if (!(vis(x, y) || mem(x, y))) continue;
        _rock(canvas, cc(x, y), cs, realmHash(x, y, 7));
      }
    }

    // towers
    for (int i = 0; i < b.towers.length; i++) {
      final SCell t = b.towers[i];
      final bool lit = (litMask >> i) & 1 == 1;
      if (!(vis(t.x, t.y) || mem(t.x, t.y) || lit)) continue;
      final Offset c = cc(t.x, t.y);
      if (g.kind == 2 && !lit) {
        _dashed(
          canvas,
          Path()..addOval(Rect.fromCircle(center: c, radius: cs * 0.44)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = sgAccentColor,
          5,
          4,
        );
      }
      final double litAt = i < g.litAt.length ? g.litAt[i] : -1;
      if (lit) {
        RealmDraw.glow(canvas, c, cs * 0.7, sgAccentColor, alpha: 0.28);
        _rings(canvas, c, cs, g.time * 0.7 + i * 0.33, 0.55, sgAccentColor);
        if (litAt >= 0) {
          final double age = g.time - litAt;
          if (age < 0.9) {
            final double f = age / 0.9;
            canvas.drawCircle(
              c,
              cs * (0.3 + 1.6 * f),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3.4
                ..color = const Color(0xFFFFE082).withValues(alpha: 0.8 * (1 - f)),
            );
          }
        }
      }
      if (g.pulseTower == i && !lit && g.time - g.pulseAt < 3.2) {
        double f = (g.time - g.pulseAt) * 1.2;
        f = f - f.floorToDouble();
        canvas.drawCircle(
          c,
          cs * (0.4 + 0.8 * f),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFFF5252).withValues(alpha: 0.9 * (1 - f)),
        );
      }
      _tower(canvas, c, cs, lit);
      final Offset bd = c + Offset(cs * 0.28, cs * 0.3);
      canvas.drawCircle(bd, cs * 0.15, Paint()..color = _ink);
      RealmDraw.text(canvas, '${i + 1}', bd, max(8.0, cs * 0.2), Colors.white, maxWidth: 20, maxLines: 1);
    }

    // crash marker
    if (g.ghostCrash != 0 && (g.runState == 3 || g.runState == 0)) {
      final int mx = g.ghostCx.clamp(0, b.w - 1).toInt();
      final int my = g.ghostCy.clamp(0, b.h - 1).toInt();
      final Offset c = cc(mx, my);
      final double pulse = 1 + 0.12 * sin(g.time * 8);
      final Path burst = Path();
      for (int i = 0; i < 12; i++) {
        final double rr = (i.isEven ? 0.46 : 0.26) * cs * pulse;
        final double ang = i * pi / 6;
        final Offset o = Offset(c.dx + cos(ang) * rr, c.dy + sin(ang) * rr);
        if (i == 0) {
          burst.moveTo(o.dx, o.dy);
        } else {
          burst.lineTo(o.dx, o.dy);
        }
      }
      burst.close();
      canvas.drawPath(burst, Paint()..color = const Color(0xFFFF5252).withValues(alpha: 0.85));
      RealmDraw.text(canvas, '!', c, max(10.0, cs * 0.4), Colors.white, maxWidth: 20, maxLines: 1);
    }

    // bot
    _bot(canvas, cc(pose[0], pose[1]), cs, pose[2]);

    // fog memory
    if (fog) {
      final Paint mp = Paint()..color = const Color(0xFFDDE3EA).withValues(alpha: 0.45);
      for (int y = 0; y < b.h; y++) {
        for (int x = 0; x < b.w; x++) {
          if (!vis(x, y) && mem(x, y)) {
            canvas.drawRect(Rect.fromLTWH(ox + x * cs, oy + y * cs, cs + 0.5, cs + 0.5), mp);
          }
        }
      }
    }
    canvas.restore();
    canvas.drawRRect(
      RRect.fromRectAndRadius(gr.inflate(2), const Radius.circular(8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF5B432B),
    );
  }

  void _trail(Canvas canvas, SBoard b, Offset Function(num, num) cc, double cs) {
    final List<Offset> pts = <Offset>[];
    final SSim? s = g.sim;
    if ((g.runState == 1 || g.runState == 2) && s != null) {
      pts.add(cc(b.sx, b.sy));
      for (int i = 0; i < g.runIdx && i < s.steps.length; i++) {
        if (s.steps[i].event == evMove) pts.add(cc(s.steps[i].x, s.steps[i].y));
      }
    } else if (g.ghost.isNotEmpty) {
      for (final SCell c in g.ghost) {
        pts.add(cc(c.x, c.y));
      }
    }
    if (pts.length < 2) return;
    final Path path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    final bool live = g.runState == 1 || g.runState == 2;
    final Color col = live ? const Color(0xFFFFF3C4) : const Color(0xFFFFD0C0);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cs * 0.14
        ..color = col.withValues(alpha: 0.5),
    );
    final Paint dp = Paint()..color = col.withValues(alpha: 0.85);
    for (final Offset p in pts) {
      canvas.drawCircle(p, cs * 0.07, dp);
    }
  }

  void _rock(Canvas canvas, Offset c, double cs, int h) {
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, cs * 0.32), width: cs * 0.86, height: cs * 0.24), Paint()..color = const Color(0x44000000));
    final Rect boulder = Rect.fromCenter(center: c + Offset(0, cs * 0.2), width: cs * 0.82, height: cs * 0.5);
    canvas.drawOval(boulder, Paint()..color = const Color(0xFF7C7F8A));
    canvas.drawOval(boulder.deflate(cs * 0.06).shift(Offset(-cs * 0.04, -cs * 0.05)), Paint()..color = const Color(0xFF9A9DA8));
    if (h % 3 == 0) {
      canvas.drawCircle(c + Offset(cs * 0.1, cs * 0.12), cs * 0.07, Paint()..color = const Color(0xFF666977));
      return;
    }
    final Paint trunk = Paint()..color = const Color(0xFF5A3B22);
    canvas.drawRect(Rect.fromCenter(center: c + Offset(0, cs * 0.02), width: cs * 0.08, height: cs * 0.18), trunk);
    final Paint pine = Paint()..color = h % 2 == 0 ? const Color(0xFF1F5E3B) : const Color(0xFF256B43);
    for (int k = 0; k < 3; k++) {
      final double y0 = c.dy - cs * (0.38 - k * 0.14);
      final double hw = cs * (0.17 + k * 0.07);
      final Path t = Path()
        ..moveTo(c.dx, y0 - cs * 0.15)
        ..lineTo(c.dx - hw, y0 + cs * 0.08)
        ..lineTo(c.dx + hw, y0 + cs * 0.08)
        ..close();
      canvas.drawPath(t, pine);
    }
  }

  void _tower(Canvas canvas, Offset c, double cs, bool lit) {
    final double top = c.dy - cs * 0.4;
    final double bot = c.dy + cs * 0.36;
    final Color metal = lit ? const Color(0xFFFFE9C4) : const Color(0xFFB6BAC6);
    final Paint leg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(1.6, cs * 0.06)
      ..color = metal;
    final double bw = cs * 0.22;
    canvas.drawRect(Rect.fromLTRB(c.dx - cs * 0.3, bot - cs * 0.04, c.dx + cs * 0.3, bot + cs * 0.06), Paint()..color = const Color(0xFF4A4F5C));
    canvas.drawLine(Offset(c.dx - bw, bot), Offset(c.dx, top + cs * 0.06), leg);
    canvas.drawLine(Offset(c.dx + bw, bot), Offset(c.dx, top + cs * 0.06), leg);
    final Paint br = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, cs * 0.035)
      ..color = metal;
    for (int k = 0; k < 3; k++) {
      final double f = 0.2 + k * 0.25;
      final double y = bot - (bot - top - cs * 0.06) * f;
      final double hw = bw * (1 - f);
      canvas.drawLine(Offset(c.dx - hw, y), Offset(c.dx + hw, y), br);
      final double f2 = f + 0.25;
      final double y2 = bot - (bot - top - cs * 0.06) * f2;
      final double hw2 = bw * (1 - f2);
      canvas.drawLine(Offset(c.dx - hw, y), Offset(c.dx + hw2, y2), br);
    }
    final Color tip = lit ? const Color(0xFFFFD54F) : const Color(0xFFFF5252);
    final double blink = lit ? 1.0 : 0.5 + 0.5 * sin(g.time * 5);
    canvas.drawCircle(Offset(c.dx, top), cs * 0.08, Paint()..color = tip.withValues(alpha: blink));
    if (lit) RealmDraw.glow(canvas, Offset(c.dx, top), cs * 0.2, tip, alpha: 0.5);
  }

  void _bot(Canvas canvas, Offset c, double cs, double ang) {
    final double u = cs;
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, u * 0.34), width: u * 0.7, height: u * 0.2), Paint()..color = const Color(0x66000000));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(ang);
    final Paint wp = Paint()..color = const Color(0xFF20232C);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-u * 0.36, -u * 0.26, u * 0.12, u * 0.52), Radius.circular(u * 0.05)), wp);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(u * 0.24, -u * 0.26, u * 0.12, u * 0.52), Radius.circular(u * 0.05)), wp);
    final RRect body = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: u * 0.5, height: u * 0.56), Radius.circular(u * 0.12));
    canvas.drawRRect(body, Paint()..color = sgAccentColor);
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.4, u * 0.04)
        ..color = const Color(0xFF9C4B14),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-u * 0.17, -u * 0.23, u * 0.34, u * 0.15), Radius.circular(u * 0.05)),
      Paint()..color = _ink,
    );
    final Paint eye = Paint()..color = const Color(0xFF7CF5FF);
    canvas.drawCircle(Offset(-u * 0.065, -u * 0.155), u * 0.03, eye);
    canvas.drawCircle(Offset(u * 0.065, -u * 0.155), u * 0.03, eye);
    final Path tri = Path()
      ..moveTo(0, -u * 0.44)
      ..lineTo(-u * 0.11, -u * 0.31)
      ..lineTo(u * 0.11, -u * 0.31)
      ..close();
    canvas.drawPath(tri, Paint()..color = Colors.white);
    canvas.restore();
    final Offset base = c + Offset(u * 0.04, -u * 0.04);
    final Offset tipPos = c + Offset(u * 0.14, -u * 0.5);
    canvas.drawLine(
      base,
      tipPos,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(1.4, u * 0.04)
        ..color = const Color(0xFFE6E6EA),
    );
    final double blink = 0.55 + 0.45 * sin(g.time * 6);
    canvas.drawCircle(tipPos, u * 0.06, Paint()..color = const Color(0xFFFF5252).withValues(alpha: blink));
    RealmDraw.glow(canvas, tipPos, u * 0.14, const Color(0xFFFF5252), alpha: 0.25 * blink);
  }

  // ---- circuit ---------------------------------------------------------------------------

  void _circuit(Canvas canvas, Size size) {
    final SCircuit? c = g.circ;
    if (c == null) return;
    final Rect r = g.circuitRect(size);
    final RRect card = RRect.fromRectAndRadius(r.deflate(2), const Radius.circular(16));
    canvas.drawRRect(card, Paint()..color = const Color(0xD00F1119));
    canvas.drawRRect(
      card,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = sgAccentColor.withValues(alpha: 0.6),
    );
    final List<Offset> pos = sgCircuitLayout(c, r.deflate(6));
    final List<bool> vals = c.eval(g.sw);
    final int n = c.nodes;
    bool known(int node) => g.reveal && !(g.partial && node == n - 1);
    final String title = g.bSub < 2 ? 'PREDICT ${g.bSub + 1} OF 2' : 'MAKE THE LAMP LIGHT';
    RealmDraw.text(canvas, title, Offset(r.left + 80, r.top + 15), 12, sgAccentColor, maxWidth: 150, maxLines: 1);

    void wire(Offset from, Offset to, int node) {
      final double mx = (from.dx + to.dx) / 2;
      final Path p = Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(mx, from.dy)
        ..lineTo(mx, to.dy)
        ..lineTo(to.dx, to.dy);
      Color col = _wireUnknown;
      if (known(node)) {
        col = vals[node] ? _wireOn : _wireOff;
        if (vals[node]) {
          canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..color = _wireOn.withValues(alpha: 0.25),
          );
        }
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3
          ..color = col,
      );
    }

    Offset outPoint(int node) => node < c.k ? pos[node] + const Offset(17, 0) : pos[node] + const Offset(24, 0);
    for (int gi = 0; gi < c.gates.length; gi++) {
      final SGate gt = c.gates[gi];
      final int id = c.k + gi;
      if (gt.b >= 0) {
        wire(outPoint(gt.a), pos[id] + const Offset(-24, -7), gt.a);
        wire(outPoint(gt.b), pos[id] + const Offset(-24, 7), gt.b);
      } else {
        wire(outPoint(gt.a), pos[id] + const Offset(-24, 0), gt.a);
      }
    }
    wire(outPoint(n - 1), pos[n] + const Offset(-20, 0), n - 1);

    // gates
    for (int gi = 0; gi < c.gates.length; gi++) {
      final int id = c.k + gi;
      final Rect box = Rect.fromCenter(center: pos[id], width: 48, height: 30);
      final RRect rr = RRect.fromRectAndRadius(box, const Radius.circular(8));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFF202636));
      Color border = _wireUnknown;
      if (known(id)) border = vals[id] ? _wireOn : _wireOff;
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = border,
      );
      RealmDraw.text(canvas, sgGateNames[c.gates[gi].type], pos[id], 13, Colors.white, maxWidth: 46, maxLines: 1);
    }

    // switches
    for (int i = 0; i < c.k; i++) {
      final bool on = i < g.sw.length && g.sw[i];
      final Offset p = pos[i];
      if (on) RealmDraw.glow(canvas, p, 26, sgAccentColor, alpha: 0.3);
      canvas.drawCircle(p, 17, Paint()..color = on ? sgAccentColor : const Color(0xFF232734));
      canvas.drawCircle(
        p,
        17,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = on ? Colors.white : const Color(0xFF8A90A5),
      );
      RealmDraw.text(canvas, c.nodeName(i), p, 16, on ? _ink : Colors.white, maxWidth: 24, maxLines: 1);
      RealmDraw.text(canvas, on ? 'ON' : 'OFF', p + const Offset(0, 28), 11, on ? sgAccentColor : Colors.white54, maxWidth: 30, maxLines: 1);
    }

    // lamp
    final Offset lp = pos[n];
    final bool lampKnown = known(n - 1);
    final bool lampOn = lampKnown && vals[n - 1];
    if (lampOn) {
      RealmDraw.glow(canvas, lp, 44, const Color(0xFFFFD54F), alpha: 0.25);
      RealmDraw.glow(canvas, lp, 30, const Color(0xFFFFE082), alpha: 0.35);
    }
    canvas.drawCircle(lp, 19, Paint()..color = lampOn ? const Color(0xFFFFE082) : const Color(0xFF2C3040));
    canvas.drawCircle(
      lp,
      19,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = lampOn ? Colors.white : const Color(0xFF8A90A5),
    );
    if (!lampKnown) {
      RealmDraw.text(canvas, '?', lp, 20, Colors.white70, maxWidth: 24, maxLines: 1);
    } else if (!lampOn) {
      RealmDraw.text(canvas, 'OFF', lp, 11, Colors.white54, maxWidth: 30, maxLines: 1);
    }
    RealmDraw.text(canvas, 'LAMP', lp + const Offset(0, 32), 12, Colors.white, maxWidth: 50, maxLines: 1);
  }
}
