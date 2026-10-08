import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'skyroot_logic.dart';

class _SLeaf {
  final double x, y, s, rot, u;
  final int layer;
  const _SLeaf(this.x, this.y, this.s, this.rot, this.u, this.layer);
}

/// Draws the giant tree of Skyroot Frontier in side view.
class SkyrootPainter extends CustomPainter {
  final SkyrootLogic g;
  SkyrootPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const Color _accent = Color(0xFF4BD37B);
  static const Color _grey = Color(0xFF77736B);

  static final List<_SLeaf> _leaves = _makeLeaves();
  static final Path _leafPath = Path()
    ..moveTo(0, -1)
    ..quadraticBezierTo(1.0, -0.2, 0, 1)
    ..quadraticBezierTo(-1.0, -0.2, 0, -1)
    ..close();

  static List<_SLeaf> _makeLeaves() {
    final List<_SLeaf> out = <_SLeaf>[];
    for (int si = 0; si < skySegs.length; si++) {
      final SkySeg s = skySegs[si];
      if (s.kind == 0) continue;
      final double dx = s.bx - s.ax;
      final double dy = s.by - s.ay;
      final double len = sqrt(dx * dx + dy * dy);
      final int cnt = s.kind == 1 ? (len / 8).round() : (len / 20).round();
      for (int j = 0; j < cnt; j++) {
        final double t = realmUnit(si, j, 1);
        final double ox = (realmUnit(si, j, 2) - 0.5) * (s.kind == 1 ? 96 : 50);
        final double oy = (realmUnit(si, j, 3) - 0.5) * (s.kind == 1 ? 74 : 30);
        final double x = s.ax + dx * t + ox;
        final double y = s.ay + dy * t + oy;
        out.add(_SLeaf(x, y, 13 + realmUnit(si, j, 4) * 15, realmUnit(si, j, 5) * 6.283, realmUnit(si, j, 6), skyLayerOf(y)));
      }
    }
    for (int j = 0; j < 280; j++) {
      final double y = 60 + realmUnit(j, 5, 1) * 3300;
      final double spread = y < 1350 ? 820 : (y < 2100 ? 560 : 300);
      final double x = 450 + (realmUnit(j, 7, 3) - 0.5) * spread;
      if (y > 3380) continue;
      out.add(_SLeaf(x, y, 14 + realmUnit(j, 8, 4) * 18, realmUnit(j, 9, 5) * 6.283, realmUnit(j, 10, 6), skyLayerOf(y)));
    }
    return out;
  }

  double _half(double y) {
    final double t = ((y - 260) / 3190).clamp(0.0, 1.0).toDouble();
    double w = 54 + 30 * t;
    if (y > 3250) w += (y - 3250) * 0.25;
    return w;
  }

  Color _wood(int layer) {
    const List<Color> base = <Color>[Color(0xFF4E3626), Color(0xFF5A3E28), Color(0xFF63452B), Color(0xFF6E4E30), Color(0xFF7A5634)];
    return Color.lerp(base[layer], _grey, (g.shown[layer] / 100 * 0.9).clamp(0.0, 1.0).toDouble())!;
  }

  Color _leafColor(_SLeaf l) {
    final double b = (g.shown[l.layer] / 100 * 1.15).clamp(0.0, 1.0).toDouble();
    Color healthy = Color.lerp(const Color(0xFF2F9E5A), const Color(0xFF8BDC6A), l.u)!;
    healthy = Color.lerp(healthy, const Color(0xFFB4F08D), g.bloom[l.layer] * 0.35)!;
    final Color sick = Color.lerp(const Color(0xFF8C8672), const Color(0xFF6B5B45), l.u)!;
    return Color.lerp(healthy, sick, b)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double z = _zoom(size);
    final double vw = size.width / z;
    final double vh = size.height / z;
    double cx = g.camX;
    double cy = g.camY;
    if (vw < skyW) {
      cx = cx.clamp(vw / 2, skyW - vw / 2).toDouble();
    } else {
      cx = skyW / 2;
    }
    if (vh < skyH) {
      cy = cy.clamp(vh / 2, skyH - vh / 2).toDouble();
    } else {
      cy = skyH / 2;
    }
    final Rect view = Rect.fromLTRB(cx - vw / 2, cy - vh / 2, cx + vw / 2, cy + vh / 2);
    final double tm = g.time;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(z, z);
    canvas.translate(-cx, -cy);

    _background(canvas, view);
    _farTrees(canvas, view, cx, tm);
    _shafts(canvas, view, cx, tm);
    _river(canvas, view, tm);
    final Paint wood = _woodPaint();
    _trunk(canvas, view, wood);
    _roots(canvas, wood);
    _fungi(canvas, view);
    for (final SkySeg s in skySegs) {
      if (s.kind == 1 && _near(view, s)) _branch(canvas, s, wood);
    }
    for (final SkySeg s in skySegs) {
      if (s.kind == 2 && _near(view, s)) _vine(canvas, s, tm);
    }
    _stationsBack(canvas, view, tm);
    _leavesDraw(canvas, view, tm);
    _animals(canvas, view, tm);
    _pods(canvas, view, tm);
    _bossDraw(canvas, view, tm);
    _marker(canvas, tm);
    _ranger(canvas);
    _birds(canvas, view, tm);
    _falling(canvas, view, tm);
    canvas.restore();

    _vignette(canvas, size);
    _blightBars(canvas, size);
  }

  double _zoom(Size size) {
    double z = size.height / 840;
    if (size.width / z < 380) z = size.width / 380;
    return z;
  }

  bool _near(Rect view, SkySeg s) {
    final double top = min(s.ay, s.by) - 60;
    final double bot = max(s.ay, s.by) + 60;
    return bot >= view.top && top <= view.bottom;
  }

  // ---- background ---------------------------------------------------------

  void _background(Canvas canvas, Rect view) {
    final Rect r = Rect.fromLTRB(view.left - 20, max(0.0, view.top - 20), view.right + 20, min(skyH, view.bottom + 20));
    final Paint p = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF9FD8C0), Color(0xFF6FBF8E), Color(0xFF3E9467), Color(0xFF2A7650), Color(0xFF1E5A3E), Color(0xFF0F3A33)],
        stops: <double>[0.0, 0.167, 0.375, 0.583, 0.792, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 10, skyH));
    canvas.drawRect(r, p);
    // sky above the top of the world
    if (view.top < 0) {
      _p.color = const Color(0xFF9FD8C0);
      canvas.drawRect(Rect.fromLTRB(view.left - 20, view.top - 20, view.right + 20, 5), _p);
    }
    // grey wash per layer
    for (int i = 0; i < 5; i++) {
      final double t = skyLayerTop[i];
      final double b = i == 0 ? skyH : skyLayerTop[i - 1];
      if (b < view.top || t > view.bottom) continue;
      final double a = (g.shown[i] / 100 * 0.5).clamp(0.0, 0.5).toDouble();
      if (a < 0.01) continue;
      _p.color = const Color(0xFF6E6A5C).withValues(alpha: a);
      canvas.drawRect(Rect.fromLTRB(view.left - 20, t, view.right + 20, b), _p);
    }
  }

  void _farTrees(Canvas canvas, Rect view, double cx, double tm) {
    final double shift = (cx - 450) * 0.45;
    const List<double> xs = <double>[-90, 80, 230, 690, 820, 980];
    for (int i = 0; i < xs.length; i++) {
      final double w = 46 + realmUnit(i, 1, 9) * 36;
      _p.color = const Color(0xFF0F4A33).withValues(alpha: 0.28);
      canvas.drawRect(Rect.fromLTWH(xs[i] + shift - w / 2, view.top - 10, w, view.height + 20), _p);
    }
    // distant leaf blobs
    final double shift2 = (cx - 450) * 0.6;
    for (int i = 0; i < 14; i++) {
      final double y = 100 + i * 250.0 + realmUnit(i, 2, 9) * 90;
      if (y < view.top - 120 || y > view.bottom + 120) continue;
      final double x = -50 + realmUnit(i, 3, 9) * 1000 + shift2 + sin(tm * 0.2 + i) * 8;
      final Color c = Color.lerp(const Color(0xFF2C8F5A), _grey, (g.shown[skyLayerOf(y)] / 100).clamp(0.0, 1.0).toDouble())!;
      _p.color = c.withValues(alpha: 0.22);
      canvas.drawCircle(Offset(x, y), 70 + realmUnit(i, 4, 9) * 50, _p);
    }
    // clouds in the sky above the crown
    final double shift3 = (cx - 450) * 0.8;
    if (view.top < 150) {
      for (int i = 0; i < 4; i++) {
        final double x = 100 + i * 260.0 + shift3 + sin(tm * 0.1 + i) * 14;
        final double y = 30 + (i % 2) * 40.0;
        _p.color = Colors.white.withValues(alpha: 0.5);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 150, height: 34), _p);
        canvas.drawOval(Rect.fromCenter(center: Offset(x + 30, y - 14), width: 90, height: 34), _p);
      }
    }
  }

  void _shafts(Canvas canvas, Rect view, double cx, double tm) {
    if (view.top > 1700) return;
    final double clean = 1 - 0.85 * ((g.shown[3] + g.shown[4]) / 200).clamp(0.0, 1.0).toDouble();
    final double shift = (cx - 450) * 0.25;
    for (int i = 0; i < 5; i++) {
      final double x0 = 60 + i * 190.0 + sin(tm * 0.3 + i * 1.7) * 30 + shift;
      final double w0 = 40 + 14 * sin(tm * 0.5 + i);
      final Path path = Path()
        ..moveTo(x0, 0)
        ..lineTo(x0 + w0, 0)
        ..lineTo(x0 + 220 + w0 + 60, 1700)
        ..lineTo(x0 + 220, 1700)
        ..close();
      final Paint p = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[const Color(0xFFFFF4B0).withValues(alpha: 0.22 * clean), const Color(0xFFFFF4B0).withValues(alpha: 0.0)],
        ).createShader(const Rect.fromLTWH(0, 0, 10, 1700));
      canvas.drawPath(path, p);
    }
  }

  // ---- river, trunk, roots ------------------------------------------------------

  void _river(Canvas canvas, Rect view, double tm) {
    if (view.bottom < 3430) return;
    final double m = (g.shown[0] / 100).clamp(0.0, 1.0).toDouble();
    // bank
    _p.color = Color.lerp(const Color(0xFF4A3524), const Color(0xFF3A3028), m)!;
    canvas.drawRect(Rect.fromLTRB(view.left - 20, 3436, view.right + 20, 3476), _p);
    _p.color = Color.lerp(const Color(0xFF3F9A4B), _grey, m)!;
    canvas.drawRect(Rect.fromLTRB(view.left - 20, 3430, view.right + 20, 3444), _p);
    // water
    final Color top = Color.lerp(const Color(0xFF3FA7C9), const Color(0xFF7A7650), m)!;
    final Color bot = Color.lerp(const Color(0xFF1F6F8F), const Color(0xFF4F4A36), m)!;
    final Paint wp = Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[top, bot]).createShader(const Rect.fromLTWH(0, 3470, 10, 130));
    canvas.drawRect(Rect.fromLTRB(view.left - 20, 3470, view.right + 20, skyH + 40), wp);
    _s.strokeWidth = 2;
    _s.color = Colors.white.withValues(alpha: 0.28 * (1 - m * 0.6));
    for (int k = 0; k < 5; k++) {
      final Path path = Path();
      final double y0 = 3486 + k * 24.0;
      bool first = true;
      for (double x = view.left - 20; x <= view.right + 20; x += 24) {
        final double y = y0 + sin(x * 0.03 + tm * 1.4 + k) * 3;
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, _s);
    }
    // stones on the bank
    for (int i = 0; i < 9; i++) {
      final double x = 40 + i * 105.0 + realmUnit(i, 1, 3) * 30;
      _p.color = Color.lerp(const Color(0xFF8A8A84), const Color(0xFF6A675F), m)!;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 3470), width: 28 + realmUnit(i, 2, 3) * 16, height: 12), _p);
    }
  }

  Paint _woodPaint() {
    final List<Color> cols = <Color>[_wood(4), _wood(4), _wood(3), _wood(2), _wood(1), _wood(0), _wood(0)];
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: cols,
        stops: const <double>[0.0, 0.083, 0.27, 0.479, 0.6875, 0.896, 1.0],
      ).createShader(const Rect.fromLTWH(0, 0, 10, skyH));
  }

  void _trunk(Canvas canvas, Rect view, Paint wood) {
    final double y0 = max(260.0, (view.top - 60).floorToDouble());
    final double y1 = min(3480.0, (view.bottom + 60).ceilToDouble());
    if (y1 <= y0) return;
    final Path tp = Path();
    bool first = true;
    for (double y = y0; y <= y1; y += 40) {
      final double x = 450 - _half(y) + sin(y * 0.015) * 3;
      if (first) {
        tp.moveTo(x, y);
        first = false;
      } else {
        tp.lineTo(x, y);
      }
    }
    for (double y = y1; y >= y0; y -= 40) {
      tp.lineTo(450 + _half(y) + sin(y * 0.017 + 1) * 3, y);
    }
    tp.close();
    canvas.drawPath(tp, wood);
    // shading on the right side
    _p.color = Colors.black.withValues(alpha: 0.12);
    final Path sh = Path();
    first = true;
    for (double y = y0; y <= y1; y += 40) {
      final double x = 450 + _half(y) * 0.35;
      if (first) {
        sh.moveTo(x, y);
        first = false;
      } else {
        sh.lineTo(x, y);
      }
    }
    for (double y = y1; y >= y0; y -= 40) {
      sh.lineTo(450 + _half(y) + sin(y * 0.017 + 1) * 3, y);
    }
    sh.close();
    canvas.drawPath(sh, _p);
    // bark lines
    _s.strokeWidth = 2.2;
    for (int k = 0; k < 9; k++) {
      final double f = -0.8 + k * 0.2;
      final Path bp = Path();
      bool bf = true;
      for (double y = y0; y <= y1; y += 40) {
        final double x = 450 + f * _half(y) + sin(y * 0.02 + k * 2) * 4;
        if (bf) {
          bp.moveTo(x, y);
          bf = false;
        } else {
          bp.lineTo(x, y);
        }
      }
      _s.color = Colors.black.withValues(alpha: 0.16);
      canvas.drawPath(bp, _s);
    }
  }

  void _roots(Canvas canvas, Paint wood) {
    for (int i = 0; i < 7; i++) {
      final double side = i < 4 ? -1.0 : 1.0;
      final double k = (i < 4 ? i : i - 4).toDouble();
      final double sx = 450 + side * (30 + k * 14);
      final double ex = 450 + side * (110 + k * 55);
      final Path path = Path()
        ..moveTo(sx, 3350)
        ..quadraticBezierTo(sx + side * 40, 3420, ex, 3462 + k * 3);
      _s.shader = wood.shader;
      _s.strokeWidth = 20 - k * 3;
      _s.color = Colors.white;
      canvas.drawPath(path, _s);
      _s.shader = null;
    }
  }

  void _branch(Canvas canvas, SkySeg s, Paint wood) {
    final double dx = s.bx - s.ax;
    final double dy = s.by - s.ay;
    final double len = sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final double nx = -dy / len;
    final double ny = dx / len;
    final double r0 = s.r * 1.15;
    final double r1 = s.r * 0.55;
    final Path path = Path()
      ..moveTo(s.ax + nx * r0, s.ay + ny * r0)
      ..lineTo(s.bx + nx * r1, s.by + ny * r1)
      ..lineTo(s.bx - nx * r1, s.by - ny * r1)
      ..lineTo(s.ax - nx * r0, s.ay - ny * r0)
      ..close();
    canvas.drawPath(path, wood);
    canvas.drawCircle(Offset(s.bx, s.by), r1, wood);
    _s.strokeWidth = 3;
    _s.color = Colors.white.withValues(alpha: 0.12);
    canvas.drawLine(Offset(s.ax - nx * r0 * 0.7, s.ay - ny * r0 * 0.7), Offset(s.bx - nx * r1 * 0.7, s.by - ny * r1 * 0.7), _s);
  }

  void _vine(Canvas canvas, SkySeg s, double tm) {
    final double my = (s.ay + s.by) / 2;
    final double m = (g.shown[skyLayerOf(my)] / 100).clamp(0.0, 1.0).toDouble();
    final Color c = Color.lerp(const Color(0xFF3F9A4B), const Color(0xFF7F7A62), m)!;
    final double sway = sin(tm * 0.9 + s.ax * 0.05) * 5;
    final Path path = Path()
      ..moveTo(s.ax, s.ay)
      ..quadraticBezierTo((s.ax + s.bx) / 2 + 10 + sway, my, s.bx, s.by);
    _s.strokeWidth = 5;
    _s.color = c;
    canvas.drawPath(path, _s);
    _s.strokeWidth = 1.6;
    _s.color = Colors.white.withValues(alpha: 0.2);
    canvas.drawPath(path, _s);
  }

  // ---- decor ---------------------------------------------------------------------

  void _fungi(Canvas canvas, Rect view) {
    // shelf fungi and moss on the trunk of the forest floor
    for (int i = 0; i < 8; i++) {
      final double y = 2160 + i * 80.0;
      if (y < view.top - 30 || y > view.bottom + 30) continue;
      final double side = i.isEven ? -1.0 : 1.0;
      final double x = 450 + side * (_half(y) - 4);
      final int layer = skyLayerOf(y);
      final double m = (g.shown[layer] / 100).clamp(0.0, 1.0).toDouble();
      _p.color = Color.lerp(const Color(0xFFE08A3C), const Color(0xFF9A8F80), m)!;
      canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 40, height: 22), side < 0 ? pi / 2 : -pi / 2, pi, true, _p);
      _p.color = Colors.black.withValues(alpha: 0.18);
      canvas.drawArc(Rect.fromCenter(center: Offset(x, y + 3), width: 36, height: 14), side < 0 ? pi / 2 : -pi / 2, pi, true, _p);
    }
    // moss patches
    for (int i = 0; i < 10; i++) {
      final double y = 2200 + i * 130.0;
      if (y < view.top - 30 || y > view.bottom + 30) continue;
      final double x = 450 + (realmUnit(i, 3, 4) - 0.5) * 70;
      final int layer = skyLayerOf(y);
      final double m = (g.shown[layer] / 100).clamp(0.0, 1.0).toDouble();
      _p.color = Color.lerp(const Color(0xFF3C8D4A), const Color(0xFF7C7A66), m)!.withValues(alpha: 0.7);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 36, height: 16), _p);
    }
  }

  void _leavesDraw(Canvas canvas, Rect view, double tm) {
    final Rect v = view.inflate(40);
    for (final _SLeaf l in _leaves) {
      if (l.y < v.top || l.y > v.bottom || l.x < v.left || l.x > v.right) continue;
      final double b = (g.shown[l.layer] / 100).clamp(0.0, 1.0).toDouble();
      final double sz = l.s * (1 - 0.25 * b);
      final double sway = sin(tm * 1.1 + l.u * 9) * 0.12;
      canvas.save();
      canvas.translate(l.x, l.y);
      canvas.rotate(l.rot + sway);
      canvas.scale(sz * 0.55, sz);
      _p.color = _leafColor(l);
      canvas.drawPath(_leafPath, _p);
      canvas.restore();
      if (g.bloom[l.layer] > 0.3 && l.u > 0.86) {
        const List<Color> fc = <Color>[Color(0xFFFF8FB1), Color(0xFFFFD54F), Color(0xFFFFFFFF), Color(0xFFFF9A5A)];
        final Color c = fc[(l.u * 100).floor() % 4];
        final double r = 4.5 * g.bloom[l.layer];
        _p.color = c;
        for (int k = 0; k < 5; k++) {
          final double a = k * 1.2566 + l.rot;
          canvas.drawCircle(Offset(l.x + cos(a) * r, l.y + sin(a) * r), r * 0.7, _p);
        }
        _p.color = const Color(0xFFFFEB3B);
        canvas.drawCircle(Offset(l.x, l.y), r * 0.5, _p);
      }
    }
  }

  // ---- stations ----------------------------------------------------------------------

  void _stationsBack(Canvas canvas, Rect view, double tm) {
    for (int i = 0; i < 4; i++) {
      final Offset p = skyStations[i];
      if (p.dy < view.top - 80 || p.dy > view.bottom + 80) continue;
      final bool show = g.nearIdx == i || g.objIdx == i;
      final double b = (g.shown[i] / 100).clamp(0.0, 1.0).toDouble();
      switch (i) {
        case 0: {
          // water test stand: post with a strip board and a vial
          _p.color = const Color(0xFF6B4A2E);
          canvas.drawRect(Rect.fromLTWH(p.dx - 3, p.dy - 52, 6, 52), _p);
          _p.color = const Color(0xFFF5F0DC);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 17, p.dy - 70, 34, 30), const Radius.circular(4)), _p);
          const List<Color> bars = <Color>[Color(0xFFE57373), Color(0xFFFFD54F), Color(0xFF64B5F6)];
          for (int k = 0; k < 3; k++) {
            _p.color = bars[k];
            canvas.drawRect(Rect.fromLTWH(p.dx - 13, p.dy - 66 + k * 9, 26 * (0.4 + 0.5 * ((k + 1) * 0.3 + b * 0.3).clamp(0.0, 1.0)), 6), _p);
          }
          _p.color = Color.lerp(const Color(0xFF4FC3F7), const Color(0xFF8D7B54), b)!.withValues(alpha: 0.9);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx + 12, p.dy - 22, 11, 22), const Radius.circular(4)), _p);
          break;
        }
        case 1: {
          // log with mushrooms and a cycle ring
          _p.color = const Color(0xFF5A3E28);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 24, p.dy - 16, 48, 16), const Radius.circular(8)), _p);
          _p.color = const Color(0xFF8A6A48);
          canvas.drawOval(Rect.fromCenter(center: Offset(p.dx + 24, p.dy - 8), width: 10, height: 16), _p);
          for (int k = 0; k < 3; k++) {
            final double mx = p.dx - 14 + k * 14.0;
            final double mh = 10 + k * 3.0;
            _p.color = const Color(0xFFF2E8D0);
            canvas.drawRect(Rect.fromLTWH(mx - 2, p.dy - 16 - mh, 4, mh), _p);
            _p.color = Color.lerp(const Color(0xFFE5543C), const Color(0xFFA99C8A), b)!;
            canvas.drawArc(Rect.fromCenter(center: Offset(mx, p.dy - 16 - mh), width: 18, height: 14), pi, pi, true, _p);
          }
          _s.strokeWidth = 3;
          _s.color = const Color(0xFFB7F0C8).withValues(alpha: 0.8);
          canvas.drawArc(Rect.fromCenter(center: Offset(p.dx, p.dy - 62), width: 30, height: 30), tm * 1.5, 4.2, false, _s);
          break;
        }
        case 2: {
          // wooden board with a small web of dots
          _p.color = const Color(0xFF6B4A2E);
          canvas.drawRect(Rect.fromLTWH(p.dx - 3, p.dy - 50, 6, 50), _p);
          _p.color = const Color(0xFFD9C6A0);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 24, p.dy - 76, 48, 32), const Radius.circular(5)), _p);
          const List<Offset> dots = <Offset>[Offset(-14, -50), Offset(-2, -64), Offset(12, -52), Offset(0, -48)];
          _s.strokeWidth = 2;
          _s.color = const Color(0xFF5A3E28);
          for (int k = 0; k < dots.length - 1; k++) {
            canvas.drawLine(p + dots[k], p + dots[k + 1], _s);
          }
          for (int k = 0; k < dots.length; k++) {
            _p.color = k == 0 ? const Color(0xFF3F9A4B) : const Color(0xFFC0392B);
            canvas.drawCircle(p + dots[k], 4, _p);
          }
          break;
        }
        default: {
          // hanging sign with a leaf and a feather
          _s.strokeWidth = 2;
          _s.color = const Color(0xFF5A3E28);
          canvas.drawLine(p + const Offset(-14, -80), p + const Offset(-14, -58), _s);
          canvas.drawLine(p + const Offset(14, -80), p + const Offset(14, -58), _s);
          _p.color = const Color(0xFFD9C6A0);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: p + const Offset(0, -46), width: 52, height: 26), const Radius.circular(5)), _p);
          canvas.save();
          canvas.translate(p.dx - 12, p.dy - 46);
          canvas.rotate(-0.5);
          canvas.scale(6, 11);
          _p.color = const Color(0xFF3F9A4B);
          canvas.drawPath(_leafPath, _p);
          canvas.restore();
          _s.strokeWidth = 2.4;
          _s.color = const Color(0xFFB2542C);
          canvas.drawLine(p + const Offset(8, -38), p + const Offset(18, -54), _s);
          break;
        }
      }
      if (show && !g.modal) {
        RealmDraw.label(canvas, skyStationNames[i], Offset(p.dx, p.dy + 22), size: 12, maxWidth: 140);
      }
    }
    if (g.nearIdx == 4 && !g.modal) {
      final Offset p = skyStations[4];
      RealmDraw.label(canvas, skyStationNames[4], Offset(p.dx, p.dy + 22), size: 12, maxWidth: 140);
    }
  }

  void _bossDraw(Canvas canvas, Rect view, double tm) {
    final Offset c = const Offset(590, 258);
    if (c.dy < view.top - 120 || c.dy > view.bottom + 120) return;
    if (g.bossWon) {
      final double a = 0.28 + 0.1 * sin(tm * 2);
      RealmDraw.glow(canvas, c, 120, const Color(0xFFFFF59D), alpha: a);
      RealmDraw.glow(canvas, c, 70, const Color(0xFFFFFFFF), alpha: a);
      return;
    }
    final double b = (g.shown[4] / 100).clamp(0.0, 1.0).toDouble();
    final double r = 20 + b * 34 + (g.bossActive ? 3 * sin(tm * 6) : 0);
    for (int i = 0; i < 9; i++) {
      final double a = i * 0.698 + tm * 0.4;
      final double l1 = r + 14 + 8 * sin(tm * 2 + i);
      final Path path = Path()
        ..moveTo(c.dx + cos(a) * r * 0.6, c.dy + sin(a) * r * 0.6)
        ..quadraticBezierTo(c.dx + cos(a + 0.5) * (r + 8), c.dy + sin(a + 0.5) * (r + 8), c.dx + cos(a + 0.2) * l1, c.dy + sin(a + 0.2) * l1);
      _s.strokeWidth = 4;
      _s.color = const Color(0xFF3A3540).withValues(alpha: 0.85);
      canvas.drawPath(path, _s);
    }
    final Paint bp = Paint()
      ..shader = const RadialGradient(colors: <Color>[Color(0xFF5E5A66), Color(0xFF241F29)]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, bp);
    final bool awake = g.bossActive;
    _p.color = awake ? const Color(0xFFFFEB3B) : const Color(0xFF8D8A60);
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.1), 3.2 + (awake ? 1 : 0), _p);
    canvas.drawCircle(c + Offset(r * 0.3, -r * 0.1), 3.2 + (awake ? 1 : 0), _p);
    for (int i = 0; i < 6; i++) {
      final double u = (tm * 0.25 + i / 6) % 1;
      _p.color = const Color(0xFF6E6A5C).withValues(alpha: 0.5 * (1 - u));
      canvas.drawCircle(Offset(c.dx + sin(i * 2.1 + tm) * (r + 10), c.dy - u * 70), 3, _p);
    }
  }

  void _marker(Canvas canvas, double tm) {
    if (g.modal || g.over) return;
    final Offset p = skyStations[g.objIdx];
    final double pulse = 0.5 + 0.5 * sin(tm * 4);
    _p.color = _accent.withValues(alpha: 0.10 + 0.10 * pulse);
    canvas.drawCircle(p, 28 + 8 * pulse, _p);
    _s.strokeWidth = 3;
    _s.color = _accent.withValues(alpha: 0.9);
    canvas.drawCircle(p, 34 + 8 * pulse, _s);
    final double ay = p.dy - 100 - 6 * pulse;
    final Path tri = Path()
      ..moveTo(p.dx, ay + 14)
      ..lineTo(p.dx - 10, ay)
      ..lineTo(p.dx + 10, ay)
      ..close();
    _p.color = _accent;
    canvas.drawPath(tri, _p);
    _s.strokeWidth = 1.6;
    _s.color = Colors.white;
    canvas.drawPath(tri, _s);
  }

  // ---- animals, pods ----------------------------------------------------------------

  void _animals(Canvas canvas, Rect view, double tm) {
    // layer 0: mudskipper and jumping fish
    final double b0 = g.bloom[0];
    if (b0 > 0.3 && view.bottom > 3380) {
      final double hop = max(0.0, sin(tm * 2.2)) * 5 * b0;
      final Offset m = Offset(340, 3396 - hop);
      _p.color = const Color(0xFF6B7F4A);
      canvas.drawOval(Rect.fromCenter(center: m, width: 26, height: 10), _p);
      canvas.drawCircle(m + const Offset(11, -5), 4.5, _p);
      _p.color = Colors.white;
      canvas.drawCircle(m + const Offset(12, -8), 2, _p);
      _p.color = Colors.black;
      canvas.drawCircle(m + const Offset(12.5, -8), 1, _p);
      _p.color = const Color(0xFF6B7F4A);
      final Path tail = Path()
        ..moveTo(m.dx - 12, m.dy)
        ..lineTo(m.dx - 22, m.dy - 5)
        ..lineTo(m.dx - 22, m.dy + 4)
        ..close();
      canvas.drawPath(tail, _p);
      for (int k = 0; k < 2; k++) {
        final double u = (tm * 0.45 + k * 0.5) % 1;
        if (u < 0.4) {
          final double s = u / 0.4;
          final Offset f = Offset(520 + k * 170 + s * 60, 3490 - sin(s * pi) * 52);
          _p.color = const Color(0xFFCFD8DC);
          canvas.drawOval(Rect.fromCenter(center: f, width: 18, height: 8), _p);
          final Path ft = Path()
            ..moveTo(f.dx - 8, f.dy)
            ..lineTo(f.dx - 14, f.dy - 4)
            ..lineTo(f.dx - 14, f.dy + 4)
            ..close();
          canvas.drawPath(ft, _p);
        }
      }
    }
    // layer 1: pangolin
    final double b1 = g.bloom[1];
    if (b1 > 0.3 && view.top < 2700 && view.bottom > 2600) {
      final Offset c = Offset(572, 2652 + sin(tm * 1.5) * 0.8);
      _p.color = const Color(0xFF8A6A48);
      canvas.drawOval(Rect.fromCenter(center: c, width: 34, height: 18), _p);
      _s.strokeWidth = 1.6;
      _s.color = const Color(0xFF5A3E28);
      for (int k = -1; k <= 1; k++) {
        canvas.drawArc(Rect.fromCenter(center: c + Offset(k * 8.0, 0), width: 12, height: 14), pi, pi, false, _s);
      }
      _p.color = const Color(0xFFA68562);
      canvas.drawOval(Rect.fromCenter(center: c + const Offset(19, 3), width: 14, height: 9), _p);
      _p.color = Colors.black;
      canvas.drawCircle(c + const Offset(22, 1), 1.2, _p);
      _s.strokeWidth = 5;
      _s.color = const Color(0xFF8A6A48);
      canvas.drawLine(c + const Offset(-14, 2), c + const Offset(-30, 8), _s);
    }
    // layer 2: bat hanging under the branch
    final double b2 = g.bloom[2];
    if (b2 > 0.3 && view.top < 1900 && view.bottom > 1780) {
      final Offset c = Offset(325, 1832 + sin(tm * 1.2) * 1.2);
      _p.color = const Color(0xFF4A3C5A);
      canvas.drawOval(Rect.fromCenter(center: c, width: 12, height: 18), _p);
      final Path w = Path()
        ..moveTo(c.dx - 5, c.dy - 4)
        ..lineTo(c.dx - 16, c.dy + 4)
        ..lineTo(c.dx - 6, c.dy + 8)
        ..close()
        ..moveTo(c.dx + 5, c.dy - 4)
        ..lineTo(c.dx + 16, c.dy + 4)
        ..lineTo(c.dx + 6, c.dy + 8)
        ..close();
      canvas.drawPath(w, _p);
      _p.color = const Color(0xFFFFEB3B);
      canvas.drawCircle(c + const Offset(-2, 2), 1.1, _p);
      canvas.drawCircle(c + const Offset(2, 2), 1.1, _p);
    }
    // layer 3: hornbill on the canopy branch
    final double b3 = g.bloom[3];
    if (b3 > 0.3 && view.top < 1100 && view.bottom > 960) {
      final Offset c = Offset(645, 1016 + sin(tm * 2) * 0.8);
      _p.color = const Color(0xFF2B2B33);
      canvas.drawOval(Rect.fromCenter(center: c, width: 30, height: 18), _p);
      _p.color = Colors.white;
      canvas.drawOval(Rect.fromCenter(center: c + const Offset(2, 5), width: 18, height: 8), _p);
      _p.color = const Color(0xFF2B2B33);
      canvas.drawCircle(c + const Offset(14, -6), 6, _p);
      _p.color = const Color(0xFFFFC107);
      final Path beak = Path()
        ..moveTo(c.dx + 17, c.dy - 9)
        ..quadraticBezierTo(c.dx + 36, c.dy - 8, c.dx + 30, c.dy + 2)
        ..lineTo(c.dx + 18, c.dy - 3)
        ..close();
      canvas.drawPath(beak, _p);
      _p.color = Colors.white;
      canvas.drawCircle(c + const Offset(15, -7), 1.6, _p);
    }
    // layer 4: a turaco near the crown branch
    final double b4 = g.bloom[4];
    if ((b4 > 0.3 || g.bossWon) && view.top < 450 && view.bottom > 250) {
      final Offset c = Offset(300, 405 + sin(tm * 2.4) * 1.2);
      _p.color = const Color(0xFF2E7D8C);
      canvas.drawOval(Rect.fromCenter(center: c, width: 26, height: 14), _p);
      _p.color = const Color(0xFFD32F2F);
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + 8, c.dy - 10)
          ..lineTo(c.dx + 12, c.dy - 20)
          ..lineTo(c.dx + 16, c.dy - 8)
          ..close(),
        _p,
      );
      _p.color = const Color(0xFF2E7D8C);
      canvas.drawCircle(c + const Offset(12, -4), 5, _p);
      _p.color = Colors.white;
      canvas.drawCircle(c + const Offset(14, -5), 1.4, _p);
    }
  }

  void _pods(Canvas canvas, Rect view, double tm) {
    for (int i = 0; i < skyPodSpots.length; i++) {
      if (g.podTaken[i]) continue;
      final Offset p = skyPodSpots[i];
      if (p.dy < view.top - 30 || p.dy > view.bottom + 30) continue;
      final double bob = sin(tm * 2.2 + i) * 2;
      _s.strokeWidth = 1.5;
      _s.color = const Color(0xFF5A3E28);
      canvas.drawLine(Offset(p.dx, p.dy - 16), Offset(p.dx, p.dy - 6 + bob), _s);
      RealmDraw.glow(canvas, Offset(p.dx, p.dy + bob), 14, const Color(0xFFFFE082), alpha: 0.28 + 0.1 * sin(tm * 3 + i));
      _p.color = const Color(0xFF9BC53D);
      canvas.drawOval(Rect.fromCenter(center: Offset(p.dx, p.dy + bob), width: 9, height: 15), _p);
      _p.color = const Color(0xFFD7E88A);
      canvas.drawOval(Rect.fromCenter(center: Offset(p.dx - 1.5, p.dy - 2 + bob), width: 3, height: 7), _p);
    }
  }

  // ---- ranger ------------------------------------------------------------------------

  void _ranger(Canvas canvas) {
    final double x = g.pos.dx;
    final double y = g.pos.dy;
    if (g.onLedge) {
      RealmDraw.person(canvas, x, y - 10, phase: g.climbPhase, moving: g.moving, facing: g.facing, hero: true);
      return;
    }
    final HeroLook look = HeroLook.current;
    final double sw = g.moving ? sin(g.climbPhase) : 0.0;
    canvas.save();
    canvas.translate(x, y - 6);
    final Paint st = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // legs, feet pressing against the bark
    st.strokeWidth = 6;
    st.color = realmDarken(look.pants, 0.06);
    canvas.drawLine(const Offset(-4, 7), Offset(-6, 21 + sw * 5), st);
    st.color = look.pants;
    canvas.drawLine(const Offset(4, 7), Offset(6, 21 - sw * 5), st);
    _p.color = Colors.white;
    canvas.drawCircle(Offset(-6, 22 + sw * 5), 3.2, _p);
    canvas.drawCircle(Offset(6, 22 - sw * 5), 3.2, _p);
    // arms reaching up
    st.strokeWidth = 5;
    st.color = look.skin;
    canvas.drawLine(const Offset(-8, -4), Offset(-12, -19 - sw * 6), st);
    canvas.drawLine(const Offset(8, -4), Offset(12, -19 + sw * 6), st);
    canvas.drawCircle(Offset(-12, -20 - sw * 6), 3, _p..color = look.skin);
    canvas.drawCircle(Offset(12, -20 + sw * 6), 3, _p..color = look.skin);
    // back of the torso
    _p.color = look.shirt;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-9, -8, 18, 20), const Radius.circular(7)), _p);
    _p.color = realmLighten(look.shirt, 0.15);
    canvas.drawRect(const Rect.fromLTWH(-9, 1, 18, 3), _p);
    // satchel strap
    st.strokeWidth = 2.4;
    st.color = const Color(0xFF8D6E63);
    canvas.drawLine(const Offset(-8, -7), const Offset(8, 10), st);
    // head seen from behind
    _p.color = look.skin;
    canvas.drawCircle(const Offset(0, -17), 9.5, _p);
    _p.color = look.hair;
    final double hr = look.hairStyle == 'afro' ? 13.0 : 10.2;
    canvas.drawCircle(Offset(0, look.hairStyle == 'afro' ? -19.0 : -17.5), hr, _p);
    canvas.restore();
  }

  // ---- ambient ----------------------------------------------------------------------

  void _birds(Canvas canvas, Rect view, double tm) {
    for (int i = 0; i < 5; i++) {
      final double x = ((tm * (34 + i * 6) + i * 260) % 1200) - 150;
      final double y = 280 + i * 230.0 + sin(tm * 1.6 + i) * 16;
      if (y < view.top - 30 || y > view.bottom + 30 || x < view.left - 30 || x > view.right + 30) continue;
      final double flap = sin(tm * 9 + i * 2) * 5;
      _s.strokeWidth = 2.2;
      _s.color = const Color(0xFF1F2A30).withValues(alpha: 0.75);
      final Path path = Path()
        ..moveTo(x - 9, y - flap)
        ..quadraticBezierTo(x - 4, y - 4, x, y)
        ..quadraticBezierTo(x + 4, y - 4, x + 9, y - flap);
      canvas.drawPath(path, _s);
    }
  }

  void _falling(Canvas canvas, Rect view, double tm) {
    for (int k = 0; k < 16; k++) {
      final double ph = (tm * (0.06 + (k % 4) * 0.015) + k / 16) % 1;
      final double y = view.top - 20 + ph * (view.height + 40);
      final double x = view.left + realmUnit(k, 11, 2) * view.width + sin(tm * 1.3 + k) * 26;
      final int layer = skyLayerOf(y);
      final double b = (g.shown[layer] / 100).clamp(0.0, 1.0).toDouble();
      final Color c = Color.lerp(const Color(0xFF6CC56A), const Color(0xFF8A7B58), b)!;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(tm * 1.5 + k);
      canvas.scale(4.2, 8);
      _p.color = c.withValues(alpha: 0.85);
      canvas.drawPath(_leafPath, _p);
      canvas.restore();
    }
  }

  void _vignette(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.32)],
        stops: const <double>[0.6, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, p);
  }

  // ---- blight bars on the right edge -----------------------------------------------

  void _blightBars(Canvas canvas, Size size) {
    final double left = size.width - 112;
    const double top = 128;
    final Rect box = Rect.fromLTWH(left, top, 104, 5 * 22 + 34);
    _p.color = Colors.black.withValues(alpha: 0.42);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)), _p);
    RealmDraw.text(canvas, 'BLIGHT', Offset(left + 52, top + 11), 10, Colors.white70, maxWidth: 90, maxLines: 1);
    final int cur = skyLayerOf(g.pos.dy);
    for (int row = 0; row < 5; row++) {
      final int i = 4 - row;
      final double y = top + 24 + row * 22.0;
      final bool isCur = i == cur;
      RealmDraw.text(canvas, skyLayerShort[i], Offset(left + 14, y + 6), 10, isCur ? Colors.white : Colors.white60, maxWidth: 24, maxLines: 1);
      final Rect bar = Rect.fromLTWH(left + 28, y, 68, 12);
      _p.color = Colors.white.withValues(alpha: 0.14);
      canvas.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(6)), _p);
      final double v = (g.shown[i] / 100).clamp(0.0, 1.0).toDouble();
      Color c;
      if (v < 0.5) {
        c = Color.lerp(_accent, const Color(0xFF9E8B5A), v / 0.5)!;
      } else {
        c = Color.lerp(const Color(0xFF9E8B5A), const Color(0xFFC0392B), (v - 0.5) / 0.5)!;
      }
      if (v > 0.01) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, max(8.0, bar.width * v), bar.height), const Radius.circular(6)), _p..color = c);
      }
      if (isCur) {
        _s.strokeWidth = 1.6;
        _s.color = Colors.white;
        canvas.drawRRect(RRect.fromRectAndRadius(bar.inflate(1), const Radius.circular(7)), _s);
      }
      if (i < 4 && g.tended[i]) {
        _p.color = Colors.white;
        canvas.drawCircle(Offset(bar.left + 6, bar.center.dy), 2.2, _p);
      }
    }
    RealmDraw.text(canvas, skyLayerNames[cur].toUpperCase(), Offset(left + 52, top + 5 * 22 + 26), 9.5, Colors.white70, maxWidth: 100, maxLines: 1);
  }

  @override
  bool shouldRepaint(SkyrootPainter old) => true;
}
