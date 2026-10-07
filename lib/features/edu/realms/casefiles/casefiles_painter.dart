import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'casefiles_logic.dart';

/// Draws the town of Case Files: a warm cartoon top-down map.
class CaseFilesPainter extends CustomPainter {
  final CaseFilesLogic logic;
  CaseFilesPainter(this.logic, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const Color _grass = Color(0xFF8DC26F);
  static const Color _grassDark = Color(0xFF79B05D);
  static const Color _paving = Color(0xFFE8D2A6);
  static const Color _pavingLine = Color(0xFFD2B887);
  static const Color _water = Color(0xFF4FB3D9);

  static final List<Offset> _trees = _makeTrees();
  static const List<Offset> _lamps = <Offset>[
    Offset(350, 262), Offset(700, 262), Offset(1050, 262),
    Offset(350, 653), Offset(700, 653), Offset(1050, 653),
    Offset(120, 455), Offset(1280, 455), Offset(525, 455), Offset(875, 455),
  ];
  static const List<Offset> _villagerBase = <Offset>[
    Offset(300, 330), Offset(980, 560), Offset(560, 590), Offset(1150, 340), Offset(220, 560), Offset(760, 330),
  ];

  static List<Offset> _makeTrees() {
    final List<Offset> t = <Offset>[];
    for (int i = 0; i < 16; i++) {
      t.add(Offset(40.0 + i * 88 + realmUnit(i, 1, 7) * 24, 36.0 + realmUnit(i, 2, 7) * 14));
    }
    const List<double> gaps = <double>[296, 404, 646, 754, 996, 1104];
    for (final double gx in gaps) {
      for (int j = 0; j < 3; j++) {
        t.add(Offset(gx, 110.0 + j * 62 + realmUnit(j, gx.toInt(), 3) * 10));
        t.add(Offset(gx, 700.0 + j * 62 + realmUnit(j, gx.toInt(), 4) * 10));
      }
    }
    for (int j = 0; j < 8; j++) {
      t.add(Offset(18, 100.0 + j * 100 + realmUnit(j, 5, 5) * 20));
      t.add(Offset(1382, 100.0 + j * 100 + realmUnit(j, 6, 5) * 20));
    }
    return t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double z = logic.zoomFor(size);
    final Offset cam = logic.cameraFor(size);
    final double tm = logic.time;
    final Rect view = Rect.fromCenter(center: cam, width: size.width / z, height: size.height / z).inflate(70);

    _p.color = _grassDark;
    canvas.drawRect(Offset.zero & size, _p);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(z, z);
    canvas.translate(-cam.dx, -cam.dy);

    _ground(canvas, view, tm);
    for (final CasePlace pl in casePlaces) {
      if (view.overlaps(Rect.fromLTRB(pl.l - 20, pl.t - 40, pl.r + 20, pl.b + 40))) _building(canvas, pl, tm);
    }
    _props(canvas, view, tm);
    _villagers(canvas, view, tm);
    _target(canvas, tm);
    RealmDraw.person(canvas, logic.px, logic.py - 18, phase: logic.walkPhase, moving: logic.moving, facing: logic.facing);
    for (final CasePlace pl in casePlaces) {
      if (view.overlaps(Rect.fromLTRB(pl.l - 20, pl.t - 40, pl.r + 20, pl.b + 40))) _marker(canvas, pl, tm);
    }
    canvas.restore();

    if (logic.toastT > 0 && logic.toast.isNotEmpty) {
      RealmDraw.label(canvas, logic.toast, Offset(size.width / 2, size.height - 215), size: 13.5, maxWidth: size.width - 140 < 280 ? size.width - 140 : 280.0);
    }
  }

  // ---- ground ------------------------------------------------------------

  void _ground(Canvas canvas, Rect view, double tm) {
    // grass stripes
    _p.color = _grass;
    canvas.drawRect(const Rect.fromLTRB(0, 0, caseWorldW, 900), _p);
    _p.color = _grassDark.withValues(alpha: 0.35);
    for (int i = 0; i < 14; i++) {
      final double y = 40.0 + i * 64;
      if (y > view.bottom || y < view.top - 30) continue;
      canvas.drawRect(Rect.fromLTWH(0, y, caseWorldW, 22), _p);
    }
    // river
    _p.color = _water;
    canvas.drawRect(Rect.fromLTRB(view.left - 50, 900, view.right + 50, view.bottom + 60 > 1000 ? view.bottom + 60 : 1000.0), _p);
    _p.color = const Color(0xFFD7B98A);
    canvas.drawRect(Rect.fromLTRB(0, 893, caseWorldW, 904), _p);
    _s.strokeWidth = 2.5;
    _s.color = Colors.white.withValues(alpha: 0.5);
    for (int i = 0; i < 18; i++) {
      final double wx = i * 82.0 + sin(tm * 0.8 + i) * 12;
      final double wy = 925.0 + (i % 3) * 22;
      if (wx < view.left - 40 || wx > view.right + 40) continue;
      final Path w = Path()
        ..moveTo(wx, wy)
        ..quadraticBezierTo(wx + 10, wy - 6, wx + 20, wy)
        ..quadraticBezierTo(wx + 30, wy + 6, wx + 40, wy);
      canvas.drawPath(w, _s);
    }
    // streets
    _p.color = _paving;
    canvas.drawRect(const Rect.fromLTRB(0, 250, caseWorldW, 665), _p);
    canvas.drawRect(const Rect.fromLTRB(0, 835, caseWorldW, 895), _p);
    const List<double> lanes = <double>[350, 700, 1050];
    for (final double lx in lanes) {
      canvas.drawRect(Rect.fromLTRB(lx - 46, 0, lx + 46, 900), _p);
    }
    canvas.drawRect(const Rect.fromLTRB(0, 0, caseWorldW, 62), _p);
    // cobbles
    _s.strokeWidth = 1.5;
    _s.color = _pavingLine;
    for (double y = 270; y < 665; y += 36) {
      if (y < view.top || y > view.bottom) continue;
      canvas.drawLine(Offset(0, y), Offset(caseWorldW, y), _s);
    }
    for (double x = 20; x < caseWorldW; x += 48) {
      if (x < view.left || x > view.right) continue;
      for (double y = 270; y < 665; y += 72) {
        canvas.drawLine(Offset(x + (((y - 270) ~/ 72) % 2) * 24, y), Offset(x + (((y - 270) ~/ 72) % 2) * 24, y + 36), _s);
      }
    }
    // fountain
    _p.color = const Color(0xFFB9A07A);
    canvas.drawCircle(const Offset(700, 457), 44, _p);
    _p.color = _water;
    canvas.drawCircle(const Offset(700, 457), 36, _p);
    _p.color = const Color(0xFFCFC4B0);
    canvas.drawCircle(const Offset(700, 455), 8, _p);
    _s.strokeWidth = 2;
    _s.color = Colors.white.withValues(alpha: 0.75);
    for (int i = 0; i < 6; i++) {
      final double a = i * pi / 3 + tm;
      canvas.drawLine(Offset(700 + cos(a) * 9, 452 + sin(a) * 4), Offset(700 + cos(a) * 20, 447 + sin(a) * 9), _s);
    }
  }

  // ---- buildings ---------------------------------------------------------

  void _building(Canvas canvas, CasePlace pl, double tm) {
    final Color roof = Color(pl.color);
    final Rect body = Rect.fromLTRB(pl.l, pl.t, pl.r, pl.b);
    final bool top = pl.doorY > pl.b;
    _p.color = Colors.black.withValues(alpha: 0.22);
    canvas.drawRRect(RRect.fromRectAndRadius(body.shift(const Offset(9, 11)), const Radius.circular(14)), _p);
    _p.color = realmDarken(roof, 0.22);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(14)), _p);
    final Rect rf = body.deflate(8);
    _p.color = roof;
    canvas.drawRRect(RRect.fromRectAndRadius(rf, const Radius.circular(10)), _p);
    // shingles
    _s.strokeWidth = 1.4;
    _s.color = Colors.black.withValues(alpha: 0.12);
    for (double y = rf.top + 12; y < rf.bottom - 4; y += 14) {
      canvas.drawLine(Offset(rf.left + 6, y), Offset(rf.right - 6, y), _s);
    }
    // ridge
    final double cy = (rf.top + rf.bottom) / 2;
    _p.color = realmLighten(roof, 0.12);
    canvas.drawRect(Rect.fromLTRB(rf.left + 4, cy - 5, rf.right - 4, cy + 5), _p);
    // chimney
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRect(Rect.fromLTWH(rf.right - 34, top ? rf.top + 14 : rf.bottom - 38, 16, 22), _p);
    _p.color = const Color(0xFF5D4037);
    canvas.drawRect(Rect.fromLTWH(rf.right - 31, top ? rf.top + 17 : rf.bottom - 35, 10, 16), _p);
    // door and awning
    final double dcx = (pl.l + pl.r) / 2;
    final double ay = top ? pl.b - 6 : pl.t - 10;
    for (int i = 0; i < 6; i++) {
      _p.color = i.isEven ? Colors.white : realmDarken(roof, 0.05);
      canvas.drawRect(Rect.fromLTWH(dcx - 36 + i * 12, ay, 12, 16), _p);
    }
    _p.color = const Color(0xFF5D4037);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(dcx, top ? pl.b + 12 : pl.t - 18), width: 22, height: 14), const Radius.circular(4)), _p);
    // doormat
    _p.color = const Color(0xFFB71C1C).withValues(alpha: 0.8);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(pl.doorX, pl.doorY), width: 34, height: 14), const Radius.circular(5)), _p);
    // emblem
    _emblem(canvas, pl.id, Offset(dcx, cy), tm);
    // name
    final double ly = top ? pl.t - 26 : pl.b + 6;
    RealmDraw.label(canvas, pl.name, Offset(dcx, ly), size: 13, maxWidth: 150);
  }

  void _emblem(Canvas canvas, int id, Offset c, double tm) {
    _p.color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(c, 31, _p);
    _s.strokeWidth = 3;
    _s.color = const Color(0xFF3E2723);
    _p.color = const Color(0xFF3E2723);
    switch (id) {
      case 0:
        {
          canvas.drawLine(c.translate(0, -14), c.translate(0, 14), _s);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(c.dx - 22, c.dy - 14, c.dx - 2, c.dy + 14), const Radius.circular(3)), _s);
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(c.dx + 2, c.dy - 14, c.dx + 22, c.dy + 14), const Radius.circular(3)), _s);
          break;
        }
      case 1:
        {
          for (int i = 0; i < 4; i++) {
            _p.color = i.isEven ? const Color(0xFFE53935) : Colors.white;
            canvas.drawRect(Rect.fromLTWH(c.dx - 20 + i * 10, c.dy - 14, 10, 12), _p);
          }
          _p.color = const Color(0xFF3E2723);
          canvas.drawRect(Rect.fromLTWH(c.dx - 18, c.dy - 2, 36, 5), _p);
          canvas.drawLine(c.translate(-16, 3), c.translate(-16, 15), _s);
          canvas.drawLine(c.translate(16, 3), c.translate(16, 15), _s);
          break;
        }
      case 2:
        {
          canvas.drawLine(c.translate(0, -14), c.translate(0, 15), _s);
          canvas.drawCircle(c.translate(0, -17), 4, _s);
          canvas.drawLine(c.translate(-9, -6), c.translate(9, -6), _s);
          canvas.drawArc(Rect.fromCenter(center: c.translate(0, 2), width: 34, height: 26), 0.2, pi - 0.4, false, _s);
          break;
        }
      case 3:
        {
          _p.color = const Color(0xFFD32F2F);
          canvas.drawRect(Rect.fromCenter(center: c, width: 12, height: 34), _p);
          canvas.drawRect(Rect.fromCenter(center: c, width: 34, height: 12), _p);
          break;
        }
      case 4:
        {
          final Path bell = Path()
            ..moveTo(c.dx - 15, c.dy + 11)
            ..quadraticBezierTo(c.dx - 13, c.dy - 18, c.dx, c.dy - 18)
            ..quadraticBezierTo(c.dx + 13, c.dy - 18, c.dx + 15, c.dy + 11)
            ..close();
          _p.color = const Color(0xFFF9A825);
          canvas.drawPath(bell, _p);
          _p.color = const Color(0xFF3E2723);
          canvas.drawCircle(c.translate(0, 15), 4, _p);
          break;
        }
      case 5:
        {
          canvas.drawCircle(c, 12, _s);
          for (int i = 0; i < 8; i++) {
            final double a = i * pi / 4 + tm * 0.6;
            canvas.drawLine(Offset(c.dx + cos(a) * 12, c.dy + sin(a) * 12), Offset(c.dx + cos(a) * 20, c.dy + sin(a) * 20), _s);
          }
          canvas.drawCircle(c, 4, _p);
          break;
        }
      case 6:
        {
          _p.color = const Color(0xFFD08A3C);
          canvas.drawOval(Rect.fromCenter(center: c, width: 40, height: 26), _p);
          _s.strokeWidth = 2.5;
          _s.color = const Color(0xFF9A5B1D);
          canvas.drawLine(c.translate(-8, -9), c.translate(-4, 9), _s);
          canvas.drawLine(c.translate(2, -11), c.translate(6, 11), _s);
          canvas.drawLine(c.translate(12, -8), c.translate(15, 7), _s);
          break;
        }
      default:
        {
          canvas.drawCircle(c, 19, _s);
          final double h = tm * 0.5;
          canvas.drawLine(c, Offset(c.dx + cos(h) * 11, c.dy + sin(h) * 11), _s);
          canvas.drawLine(c, Offset(c.dx + cos(h * 12) * 15, c.dy + sin(h * 12) * 15), _s);
          break;
        }
    }
  }

  // ---- props -------------------------------------------------------------

  void _props(Canvas canvas, Rect view, double tm) {
    for (final Offset t in _trees) {
      if (!view.contains(t)) continue;
      RealmDraw.shadow(canvas, t.dx, t.dy + 14, 34);
      _p.color = const Color(0xFF6D4C41);
      canvas.drawRect(Rect.fromLTWH(t.dx - 3, t.dy, 6, 14), _p);
      final int v = (t.dx.toInt() + t.dy.toInt()) % 3;
      _p.color = v == 0 ? const Color(0xFF2E7D32) : (v == 1 ? const Color(0xFF388E3C) : const Color(0xFF43A047));
      canvas.drawCircle(Offset(t.dx, t.dy - 6), 16, _p);
      _p.color = Colors.white.withValues(alpha: 0.14);
      canvas.drawCircle(Offset(t.dx - 5, t.dy - 11), 7, _p);
    }
    for (final Offset l in _lamps) {
      if (!view.contains(l)) continue;
      RealmDraw.glow(canvas, l.translate(0, -26), 26, const Color(0xFFFFE082), alpha: 0.2 + 0.05 * sin(tm * 2 + l.dx));
      _p.color = const Color(0xFF37474F);
      canvas.drawRect(Rect.fromLTWH(l.dx - 2, l.dy - 28, 4, 30), _p);
      _p.color = const Color(0xFFFFD54F);
      canvas.drawCircle(l.translate(0, -30), 5, _p);
    }
    // pier and boats at the harbour
    if (view.bottom > 830) {
      _p.color = const Color(0xFF8D6E63);
      canvas.drawRect(const Rect.fromLTRB(1200, 893, 1250, 985), _p);
      _s.strokeWidth = 1.5;
      _s.color = const Color(0xFF5D4037);
      for (double y = 900; y < 985; y += 12) {
        canvas.drawLine(Offset(1200, y), Offset(1250, y), _s);
      }
      _boat(canvas, 1160, 950 + sin(tm * 1.3) * 3, const Color(0xFFE53935));
      _boat(canvas, 1300, 960 + sin(tm * 1.1 + 1) * 3, const Color(0xFFFFA726));
      _boat(canvas, 520, 955 + sin(tm * 0.9 + 2) * 3, const Color(0xFF7E57C2));
    }
  }

  void _boat(Canvas canvas, double x, double y, Color c) {
    final Path hull = Path()
      ..moveTo(x - 24, y)
      ..lineTo(x + 24, y)
      ..lineTo(x + 16, y + 12)
      ..lineTo(x - 16, y + 12)
      ..close();
    _p.color = c;
    canvas.drawPath(hull, _p);
    _s.strokeWidth = 2;
    _s.color = const Color(0xFF5D4037);
    canvas.drawLine(Offset(x, y), Offset(x, y - 26), _s);
    _p.color = Colors.white;
    final Path sail = Path()
      ..moveTo(x + 2, y - 24)
      ..lineTo(x + 18, y - 4)
      ..lineTo(x + 2, y - 4)
      ..close();
    canvas.drawPath(sail, _p);
  }

  void _villagers(Canvas canvas, Rect view, double tm) {
    for (int i = 0; i < _villagerBase.length; i++) {
      final Offset b = _villagerBase[i];
      final double x = b.dx + sin(tm * 0.35 + i * 2.1) * 70;
      final double y = b.dy + cos(tm * 0.27 + i) * 18;
      if (!view.contains(Offset(x, y))) continue;
      final double vx = cos(tm * 0.35 + i * 2.1);
      RealmDraw.person(canvas, x, y - 18, phase: tm * 6 + i, moving: true, facing: vx >= 0 ? 1 : -1, shirt: realmLighten(Color(casePlaces[i].color), 0.1), pants: const Color(0xFF455A64), hair: const Color(0xFF4E342E), scale: 0.9);
    }
  }

  void _target(Canvas canvas, double tm) {
    if (!logic.hasTarget) return;
    final double pulse = 10 + 3 * sin(tm * 8);
    _s.strokeWidth = 3;
    _s.color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(logic.tx, logic.ty), pulse, _s);
    _p.color = const Color(0xFFFF6A00).withValues(alpha: 0.5);
    canvas.drawCircle(Offset(logic.tx, logic.ty), 5, _p);
  }

  void _marker(Canvas canvas, CasePlace pl, double tm) {
    final bool done = logic.revealed[pl.id];
    final bool here = logic.atDoor == pl.id;
    final Offset d = Offset(pl.doorX, pl.doorY);
    if (here && !done) {
      _s.strokeWidth = 3;
      _s.color = const Color(0xFFFFCA28).withValues(alpha: 0.9);
      canvas.drawCircle(d, 24 + 3 * sin(tm * 6), _s);
    }
    final bool top = pl.doorY > pl.b;
    final Offset m = Offset(pl.doorX + 44, top ? pl.doorY + 6 : pl.doorY - 6);
    _p.color = done ? const Color(0xFF2E7D32) : const Color(0xFFF9A825);
    canvas.drawCircle(m, 11, _p);
    _s.strokeWidth = 2.6;
    _s.color = Colors.white;
    if (done) {
      final Path ck = Path()
        ..moveTo(m.dx - 5, m.dy)
        ..lineTo(m.dx - 1, m.dy + 4)
        ..lineTo(m.dx + 6, m.dy - 5);
      canvas.drawPath(ck, _s);
    } else {
      RealmDraw.text(canvas, '?', m, 15, Colors.white, maxWidth: 20, maxLines: 1);
    }
  }

  @override
  bool shouldRepaint(covariant CaseFilesPainter oldDelegate) => true;
}
