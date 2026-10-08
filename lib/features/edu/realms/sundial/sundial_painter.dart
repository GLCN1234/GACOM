import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'sundial_logic.dart';

/// Draws Sundial City: a warm top-down square with a sundial plaza, a bell
/// tower whose shadow turns with the day, six distinct buildings, whispers
/// and speech bubbles.
class SundialPainter extends CustomPainter {
  final SundialLogic logic;
  SundialPainter(this.logic, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static const Color _grass = Color(0xFF9BC46B);
  static const Color _grassDark = Color(0xFF86B058);
  static const Color _paving = Color(0xFFE9D8AE);
  static const Color _pavingLine = Color(0xFFD3BD8C);
  static const Color _plaza = Color(0xFFF2E5C0);
  static const Color _gold = Color(0xFFF6B93B);
  static const Color _greyRed = Color(0xFFB5545F);
  static const Color _greyMark = Color(0xFF9A9AA3);

  static const List<String> _roman = <String>['XII', 'I', 'II', 'III', 'IIII', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];
  static const List<Offset> _folk = <Offset>[
    Offset(760, 560), Offset(1050, 760), Offset(640, 720), Offset(1180, 560),
    Offset(900, 880), Offset(900, 450), Offset(430, 650), Offset(1370, 650),
  ];
  static const List<Color> _folkShirt = <Color>[
    Color(0xFFE53935), Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFFB8C00),
    Color(0xFF8E24AA), Color(0xFF00ACC1), Color(0xFFF4511E), Color(0xFF3949AB),
  ];
  static final List<Offset> _trees = _makeTrees();

  static List<Offset> _makeTrees() {
    final List<Offset> t = <Offset>[];
    for (int j = 0; j < 11; j++) {
      t.add(Offset(46 + realmUnit(j, 1, 9) * 16, 90.0 + j * 112));
      t.add(Offset(1754 - realmUnit(j, 2, 9) * 16, 90.0 + j * 112));
    }
    for (int i = 0; i < 14; i++) {
      t.add(Offset(120.0 + i * 120, 1262 + realmUnit(i, 3, 9) * 4));
    }
    const List<double> gaps = <double>[470, 580, 690, 1110, 1220, 1330];
    for (final double gx in gaps) {
      for (int j = 0; j < 3; j++) {
        t.add(Offset(gx + realmUnit(j, gx.toInt(), 5) * 14, 120.0 + j * 62));
        t.add(Offset(gx + realmUnit(j, gx.toInt(), 6) * 14, 1030.0 + j * 62));
      }
    }
    return t;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double z = logic.zoomFor(size);
    final Offset cam = logic.cameraFor(size);
    final double tm = logic.time;
    final Rect view = Rect.fromCenter(center: cam, width: size.width / z, height: size.height / z).inflate(120);

    _p.color = _grassDark;
    canvas.drawRect(Offset.zero & size, _p);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(z, z);
    canvas.translate(-cam.dx, -cam.dy);

    _ground(canvas, view, tm);
    _dial(canvas, tm);
    _props(canvas, view, tm);
    for (final SdBuilding b in sdBuildings) {
      if (view.overlaps(Rect.fromLTRB(b.l - 30, b.t - 60, b.r + 30, b.b + 60))) _building(canvas, b, tm);
    }
    _folkDraw(canvas, view, tm);
    final bool towerFirst = logic.py >= sdTower.dy - 6;
    if (towerFirst) _tower(canvas, tm);
    _target(canvas, tm);
    RealmDraw.person(canvas, logic.px, logic.py - 18, phase: logic.walkPhase, moving: logic.moving, facing: logic.facing, hero: true);
    if (!towerFirst) _tower(canvas, tm);
    for (final SdBuilding b in sdBuildings) {
      if (!view.overlaps(Rect.fromLTRB(b.l - 30, b.t - 90, b.r + 30, b.b + 90))) continue;
      _whisperFx(canvas, b, tm);
      _fixedFx(canvas, b, tm);
      _marker(canvas, b, tm);
      _bubble(canvas, b);
    }
    canvas.restore();

    // evening and night tint
    final double dark = pow((1 - logic.light).clamp(0.0, 1.0).toDouble(), 1.5).toDouble();
    if (dark > 0.01) {
      _p.color = const Color(0xFF0B1030).withValues(alpha: 0.36 * dark);
      canvas.drawRect(Offset.zero & size, _p);
    }
    _warningRing(canvas, size, tm);
    if (logic.toastT > 0 && logic.toast.isNotEmpty) {
      RealmDraw.label(canvas, logic.toast, Offset(size.width / 2, size.height - 215), size: 13.5, maxWidth: size.width - 140 < 280 ? size.width - 140 : 280.0);
    }
  }

  // ---- ground and plaza --------------------------------------------------

  void _ground(Canvas canvas, Rect view, double tm) {
    _p.color = _grass;
    canvas.drawRect(const Rect.fromLTRB(0, 0, sdWorldW, sdWorldH), _p);
    _p.color = _grassDark.withValues(alpha: 0.4);
    for (int i = 0; i < 22; i++) {
      final double y = 20.0 + i * 62;
      if (y > view.bottom || y < view.top - 30) continue;
      canvas.drawRect(Rect.fromLTWH(0, y, sdWorldW, 22), _p);
    }
    // roads
    _p.color = _paving;
    canvas.drawRect(const Rect.fromLTRB(0, 590, sdWorldW, 710), _p);
    const List<double> lanes = <double>[265, 900, 1535];
    for (final double lx in lanes) {
      canvas.drawRect(Rect.fromLTRB(lx - 50, 296, lx + 50, 1004), _p);
    }
    _s.strokeWidth = 1.5;
    _s.color = _pavingLine;
    for (double x = 0; x < sdWorldW; x += 44) {
      if (x < view.left - 44 || x > view.right) continue;
      canvas.drawLine(Offset(x, 590), Offset(x, 710), _s);
    }
    for (final double lx in lanes) {
      if (lx + 60 < view.left || lx - 60 > view.right) continue;
      for (double y = 296; y < 1004; y += 44) {
        if (y < view.top - 44 || y > view.bottom) continue;
        canvas.drawLine(Offset(lx - 50, y), Offset(lx + 50, y), _s);
      }
    }
    // plaza
    _p.color = _plaza;
    canvas.drawCircle(sdTower, 272, _p);
    _s.strokeWidth = 7;
    _s.color = _pavingLine;
    canvas.drawCircle(sdTower, 272, _s);
    _s.strokeWidth = 2;
    _s.color = _pavingLine.withValues(alpha: 0.7);
    canvas.drawCircle(sdTower, 180, _s);
  }

  /// The dial of the sundial and the shadow of the bell tower.
  void _dial(Canvas canvas, double tm) {
    final Offset c = sdTower;
    _s.strokeWidth = 4;
    _s.color = const Color(0xFF8D6E4A);
    canvas.drawCircle(c, 214, _s);
    final Offset dir = logic.shadowDir;
    final double ang = atan2(dir.dy, dir.dx);
    int hour = (((ang + pi / 2) / (pi / 6)).round()) % 12;
    if (hour < 0) hour += 12;
    for (int i = 0; i < 12; i++) {
      final double a = -pi / 2 + i * pi / 6;
      final Offset d = Offset(cos(a), sin(a));
      _s.strokeWidth = i % 3 == 0 ? 5 : 3;
      _s.color = const Color(0xFF8D6E4A);
      canvas.drawLine(c + d * 196, c + d * 214, _s);
      final bool on = i == hour;
      if (on) RealmDraw.glow(canvas, c + d * 242, 22, _gold, alpha: 0.4);
      RealmDraw.text(canvas, _roman[i], c + d * 242, i % 3 == 0 ? 17 : 14, on ? const Color(0xFF9A5B00) : const Color(0xFF6D5A3C), maxWidth: 50, maxLines: 1);
    }
    // shadow of the tower on the plaza
    final double len = logic.shadowLen;
    final Offset n = Offset(-dir.dy, dir.dx);
    final Offset tip = c + dir * len;
    final Path sh = Path()
      ..moveTo(c.dx + n.dx * 22, c.dy + n.dy * 22)
      ..lineTo(tip.dx + n.dx * 5, tip.dy + n.dy * 5)
      ..lineTo(tip.dx - n.dx * 5, tip.dy - n.dy * 5)
      ..lineTo(c.dx - n.dx * 22, c.dy - n.dy * 22)
      ..close();
    _p.color = Colors.black.withValues(alpha: 0.14 + 0.16 * logic.light);
    canvas.drawPath(sh, _p);
    _p.color = _gold.withValues(alpha: 0.9);
    canvas.drawCircle(tip, 5, _p);
  }

  void _props(Canvas canvas, Rect view, double tm) {
    final double night = 1 - logic.light;
    for (final Offset t in _trees) {
      if (!view.contains(t)) continue;
      RealmDraw.shadow(canvas, t.dx, t.dy + 14, 34);
      _p.color = const Color(0xFF6D4C41);
      canvas.drawRect(Rect.fromLTWH(t.dx - 3, t.dy, 6, 14), _p);
      final int v = (t.dx.toInt() + t.dy.toInt()) % 3;
      _p.color = v == 0 ? const Color(0xFF2E7D32) : (v == 1 ? const Color(0xFF388E3C) : const Color(0xFF43A047));
      canvas.drawCircle(Offset(t.dx, t.dy - 6), 17, _p);
      _p.color = Colors.white.withValues(alpha: 0.14);
      canvas.drawCircle(Offset(t.dx - 5, t.dy - 11), 7, _p);
    }
    for (int i = 0; i < 8; i++) {
      final double a = i * pi / 4 + pi / 8;
      final Offset l = sdTower + Offset(cos(a) * 292, sin(a) * 292);
      if (!view.contains(l)) continue;
      RealmDraw.glow(canvas, l.translate(0, -26), 26 + 10 * night, const Color(0xFFFFE082), alpha: 0.12 + 0.4 * night);
      _p.color = const Color(0xFF37474F);
      canvas.drawRect(Rect.fromLTWH(l.dx - 2, l.dy - 28, 4, 30), _p);
      _p.color = const Color(0xFFFFD54F);
      canvas.drawCircle(l.translate(0, -30), 5, _p);
    }
  }

  void _folkDraw(Canvas canvas, Rect view, double tm) {
    final double v = (logic.voice / 100).clamp(0.0, 1.0).toDouble();
    for (int i = 0; i < _folk.length; i++) {
      final Offset b = _folk[i];
      final double x = b.dx + sin(tm * 0.3 + i * 2.1) * 40;
      final double y = b.dy + cos(tm * 0.22 + i) * 14;
      if (!view.contains(Offset(x, y))) continue;
      final Color shirt = Color.lerp(const Color(0xFF8E8E93), _folkShirt[i], v) ?? _folkShirt[i];
      RealmDraw.person(canvas, x, y - 18, phase: tm * 5 + i, moving: true, facing: cos(tm * 0.3 + i * 2.1) >= 0 ? 1 : -1, shirt: shirt, pants: const Color(0xFF455A64), hair: const Color(0xFF4E342E), scale: 0.9);
    }
  }

  // ---- bell tower --------------------------------------------------------

  void _tower(Canvas canvas, double tm) {
    final Offset c = sdTower;
    _p.color = const Color(0xFFB8AB92);
    canvas.drawCircle(c, 47, _p);
    _p.color = const Color(0xFFD9CDB5);
    canvas.drawCircle(c, 39, _p);
    // body
    final Rect body = Rect.fromLTRB(c.dx - 25, c.dy - 118, c.dx + 25, c.dy + 8);
    _p.color = const Color(0xFFC9BCA4);
    canvas.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(4)), _p);
    _p.color = Colors.black.withValues(alpha: 0.12);
    canvas.drawRect(Rect.fromLTRB(c.dx + 12, c.dy - 118, c.dx + 25, c.dy + 8), _p);
    _s.strokeWidth = 1.4;
    _s.color = Colors.black.withValues(alpha: 0.14);
    for (double y = c.dy - 106; y < c.dy + 6; y += 14) {
      canvas.drawLine(Offset(c.dx - 25, y), Offset(c.dx + 25, y), _s);
    }
    // belfry
    final Rect bel = Rect.fromLTRB(c.dx - 31, c.dy - 172, c.dx + 31, c.dy - 116);
    _p.color = const Color(0xFFD6C8AB);
    canvas.drawRRect(RRect.fromRectAndRadius(bel, const Radius.circular(4)), _p);
    final RRect arch = RRect.fromRectAndCorners(Rect.fromLTWH(c.dx - 17, c.dy - 164, 34, 44), topLeft: const Radius.circular(17), topRight: const Radius.circular(17));
    _p.color = const Color(0xFF3A2F26);
    canvas.drawRRect(arch, _p);
    // bell
    final double swing = logic.won ? sin(tm * 7) * 0.55 : sin(tm * 1.2) * 0.04;
    canvas.save();
    canvas.translate(c.dx, c.dy - 160);
    canvas.rotate(swing);
    final Path bell = Path()
      ..moveTo(-12, 30)
      ..quadraticBezierTo(-11, 4, 0, 4)
      ..quadraticBezierTo(11, 4, 12, 30)
      ..close();
    _p.color = const Color(0xFFF2B53A);
    canvas.drawPath(bell, _p);
    _p.color = const Color(0xFF5D4037);
    canvas.drawCircle(const Offset(0, 32), 3, _p);
    canvas.restore();
    // roof
    final Path roof = Path()
      ..moveTo(c.dx - 40, c.dy - 170)
      ..lineTo(c.dx + 40, c.dy - 170)
      ..lineTo(c.dx, c.dy - 218)
      ..close();
    _p.color = const Color(0xFFB5523B);
    canvas.drawPath(roof, _p);
    _p.color = _gold;
    canvas.drawCircle(Offset(c.dx, c.dy - 221), 5, _p);
    // sound waves when the bell rings
    if (logic.won) {
      for (int i = 0; i < 3; i++) {
        final double f = ((tm * 0.7) + i / 3) % 1.0;
        _s.strokeWidth = 4;
        _s.color = _gold.withValues(alpha: 0.7 * (1 - f));
        canvas.drawCircle(Offset(c.dx, c.dy - 150), 40 + f * 220, _s);
      }
    }
  }

  // ---- buildings ---------------------------------------------------------

  RRect _rr(Rect r, double rad) => RRect.fromRectAndRadius(r, Radius.circular(rad));

  void _building(Canvas canvas, SdBuilding b, double tm) {
    final Color base = Color(b.color);
    final Rect body = Rect.fromLTRB(b.l, b.t, b.r, b.b);
    final Offset sh = logic.shadowDir * (8 + 14 * (1 - logic.light));
    final bool open = logic.fixed[b.id];
    final bool locked = b.id == sdHall && !logic.hallOpen && !open;
    _p.color = Colors.black.withValues(alpha: 0.2);
    canvas.drawRRect(_rr(body.shift(sh), 14), _p);
    _p.color = realmDarken(base, 0.24);
    canvas.drawRRect(_rr(body, 14), _p);
    final Rect rf = body.deflate(9);
    _p.color = b.id == 1 ? const Color(0xFFD9C18F) : base;
    canvas.drawRRect(_rr(rf, 10), _p);
    if (b.id != 1) {
      _s.strokeWidth = 1.4;
      _s.color = Colors.black.withValues(alpha: 0.12);
      for (double y = rf.top + 12; y < rf.bottom - 4; y += 14) {
        canvas.drawLine(Offset(rf.left + 6, y), Offset(rf.right - 6, y), _s);
      }
    }
    switch (b.id) {
      case 0:
        _postDecor(canvas, b);
        break;
      case 1:
        _marketDecor(canvas, b, rf, tm);
        break;
      case 2:
        _courtDecor(canvas, b, rf);
        break;
      case 3:
        _schoolDecor(canvas, b, rf);
        break;
      case 4:
        _libraryDecor(canvas, b);
        break;
      default:
        _hallDecor(canvas, b, tm);
        break;
    }
    // front wall with windows and door
    final Rect fa = b.doorBelow ? Rect.fromLTRB(b.l + 10, b.b - 30, b.r - 10, b.b - 3) : Rect.fromLTRB(b.l + 10, b.t + 3, b.r - 10, b.t + 30);
    _p.color = realmDarken(base, 0.2);
    canvas.drawRRect(_rr(fa, 4), _p);
    final double night = 1 - logic.light;
    final int n = ((b.r - b.l - 40) / 56).floor();
    for (int i = 0; i < n; i++) {
      final double wx = fa.left + (i + 0.5) * fa.width / n;
      if ((wx - b.doorX).abs() < 34) continue;
      final Rect w = Rect.fromCenter(center: Offset(wx, fa.center.dy), width: 20, height: 15);
      if (open) {
        RealmDraw.glow(canvas, w.center, 22, const Color(0xFFFFE082), alpha: 0.18 + 0.3 * night);
        _p.color = const Color(0xFFFFE9A0);
      } else {
        _p.color = const Color(0xFF39414F);
      }
      canvas.drawRRect(_rr(w, 3), _p);
    }
    final Rect door = Rect.fromCenter(center: Offset(b.doorX, fa.center.dy), width: 30, height: 25);
    _p.color = locked ? const Color(0xFF2B2B33) : const Color(0xFF5D4037);
    canvas.drawRRect(_rr(door, 5), _p);
    // doormat
    _p.color = const Color(0xFFB71C1C).withValues(alpha: 0.8);
    canvas.drawRRect(_rr(Rect.fromCenter(center: Offset(b.doorX, b.doorY), width: 38, height: 14), 5), _p);
    if (locked) {
      _p.color = Colors.black.withValues(alpha: 0.22);
      canvas.drawRRect(_rr(rf, 10), _p);
    }
    // name
    final double ly = b.doorBelow ? b.t - 30 : b.b + 6;
    RealmDraw.label(canvas, b.name, Offset(b.cx, ly), size: 13, maxWidth: 160);
  }

  void _postDecor(Canvas canvas, SdBuilding b) {
    final Offset c = Offset(b.cx, b.cy - 6);
    _p.color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(Rect.fromCenter(center: c.translate(8, 32), width: 56, height: 14), _p);
    _p.color = const Color(0xFFB71C1C);
    canvas.drawRRect(_rr(Rect.fromCenter(center: c, width: 46, height: 58), 12), _p);
    _p.color = const Color(0xFFE53935);
    canvas.drawRRect(_rr(Rect.fromLTWH(c.dx - 18, c.dy - 22, 12, 46), 6), _p);
    _p.color = const Color(0xFF3E1B1B);
    canvas.drawRRect(_rr(Rect.fromCenter(center: c.translate(0, -8), width: 30, height: 7), 3), _p);
    _p.color = const Color(0xFF8E1212);
    canvas.drawOval(Rect.fromCenter(center: c.translate(0, -29), width: 52, height: 16), _p);
    RealmDraw.text(canvas, 'POST', c.translate(0, 14), 11, Colors.white, maxWidth: 40, maxLines: 1);
    // letters on the roof
    _p.color = Colors.white;
    for (int i = 0; i < 3; i++) {
      final Rect e = Rect.fromCenter(center: Offset(b.l + 54 + i * 34, b.cy - 20 + (i.isEven ? 0 : 10)), width: 24, height: 16);
      canvas.drawRRect(_rr(e, 2), _p);
      _s.strokeWidth = 1.4;
      _s.color = const Color(0xFFB71C1C);
      canvas.drawLine(e.topLeft + const Offset(1, 1), e.center, _s);
      canvas.drawLine(e.topRight + const Offset(-1, 1), e.center, _s);
    }
  }

  void _marketDecor(Canvas canvas, SdBuilding b, Rect rf, double tm) {
    const List<Color> cols = <Color>[Color(0xFFE53935), Color(0xFFF9A825), Color(0xFF1E88E5), Color(0xFF8E24AA)];
    final double w = rf.width / 4;
    for (int i = 0; i < 4; i++) {
      final Rect s = Rect.fromLTWH(rf.left + i * w + 4, rf.top + 6, w - 8, rf.height - 40);
      const int stripes = 6;
      for (int k = 0; k < stripes; k++) {
        _p.color = k.isEven ? Colors.white : cols[i];
        canvas.drawRect(Rect.fromLTWH(s.left + k * s.width / stripes, s.top, s.width / stripes + 0.5, s.height * 0.62), _p);
      }
      _p.color = realmDarken(cols[i], 0.1);
      canvas.drawRect(Rect.fromLTWH(s.left, s.top + s.height * 0.62, s.width, 4), _p);
      // counter and goods
      _p.color = const Color(0xFF8D6E63);
      canvas.drawRRect(_rr(Rect.fromLTWH(s.left + 2, s.top + s.height * 0.62 + 6, s.width - 4, s.height * 0.3), 4), _p);
      for (int g = 0; g < 4; g++) {
        _p.color = <Color>[const Color(0xFFFF7043), const Color(0xFFFFCA28), const Color(0xFF66BB6A), const Color(0xFFEF5350)][(g + i) % 4];
        canvas.drawCircle(Offset(s.left + 12 + g * (s.width - 24) / 3, s.top + s.height * 0.62 + 16), 5, _p);
      }
    }
  }

  void _courtDecor(Canvas canvas, SdBuilding b, Rect rf) {
    // columns on the roof edge facing the door
    final double cy = b.doorBelow ? rf.bottom - 40 : rf.top + 40;
    _p.color = const Color(0xFFEFEAE0);
    for (int i = 0; i < 6; i++) {
      final double x = rf.left + 18 + i * (rf.width - 36) / 5;
      canvas.drawRRect(_rr(Rect.fromCenter(center: Offset(x, cy), width: 12, height: 26), 3), _p);
    }
    // scales
    final Offset c = Offset(b.cx, b.cy - 12);
    _s.strokeWidth = 3;
    _s.color = const Color(0xFF4E342E);
    canvas.drawLine(c.translate(0, -26), c.translate(0, 26), _s);
    canvas.drawLine(c.translate(-30, -20), c.translate(30, -20), _s);
    canvas.drawLine(c.translate(-30, -20), c.translate(-40, 4), _s);
    canvas.drawLine(c.translate(-30, -20), c.translate(-20, 4), _s);
    canvas.drawLine(c.translate(30, -20), c.translate(20, 4), _s);
    canvas.drawLine(c.translate(30, -20), c.translate(40, 4), _s);
    _p.color = const Color(0xFFF2B53A);
    canvas.drawArc(Rect.fromCenter(center: c.translate(-30, 4), width: 24, height: 14), 0, pi, true, _p);
    canvas.drawArc(Rect.fromCenter(center: c.translate(30, 4), width: 24, height: 14), 0, pi, true, _p);
    canvas.drawCircle(c.translate(0, -26), 4, _p);
    canvas.drawRRect(_rr(Rect.fromCenter(center: c.translate(0, 28), width: 30, height: 8), 3), _p);
  }

  void _schoolDecor(Canvas canvas, SdBuilding b, Rect rf) {
    final Offset c = Offset(b.cx, b.cy - 8);
    _p.color = const Color(0xFF8D6E63);
    canvas.drawRRect(_rr(Rect.fromCenter(center: c, width: 110, height: 66), 6), _p);
    _p.color = const Color(0xFF2E5E3E);
    canvas.drawRRect(_rr(Rect.fromCenter(center: c, width: 100, height: 56), 4), _p);
    RealmDraw.text(canvas, 'ABC', c.translate(-8, -4), 24, Colors.white, maxWidth: 80, maxLines: 1);
    _p.color = const Color(0xFFFFE082);
    canvas.drawRect(Rect.fromLTWH(c.dx - 42, c.dy + 20, 22, 4), _p);
    // pencil
    canvas.save();
    canvas.translate(c.dx + 30, c.dy + 4);
    canvas.rotate(0.6);
    _p.color = const Color(0xFFF9A825);
    canvas.drawRect(const Rect.fromLTWH(-4, -24, 8, 40), _p);
    _p.color = const Color(0xFFFFCCBC);
    canvas.drawPath(Path()..moveTo(-4, 16)..lineTo(4, 16)..lineTo(0, 26)..close(), _p);
    _p.color = const Color(0xFFE57373);
    canvas.drawRect(const Rect.fromLTWH(-4, -30, 8, 6), _p);
    canvas.restore();
    // flag
    _s.strokeWidth = 2.4;
    _s.color = const Color(0xFF4E342E);
    canvas.drawLine(Offset(rf.right - 24, rf.top + 14), Offset(rf.right - 24, rf.top + 52), _s);
    _p.color = const Color(0xFFFFD54F);
    canvas.drawPath(Path()..moveTo(rf.right - 24, rf.top + 14)..lineTo(rf.right - 4, rf.top + 22)..lineTo(rf.right - 24, rf.top + 30)..close(), _p);
  }

  void _libraryDecor(Canvas canvas, SdBuilding b) {
    final Offset c = Offset(b.cx, b.cy - 10);
    const List<Color> cols = <Color>[Color(0xFF5E35B1), Color(0xFF00897B), Color(0xFFEF6C00), Color(0xFFC62828)];
    final List<double> ws = <double>[74, 64, 70, 58];
    for (int i = 0; i < 4; i++) {
      final Rect r = Rect.fromCenter(center: c.translate(i.isEven ? -3 : 4, 26 - i * 17), width: ws[i], height: 15);
      _p.color = cols[i];
      canvas.drawRRect(_rr(r, 3), _p);
      _p.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawRect(Rect.fromLTWH(r.left + 8, r.top + 5, 12, 5), _p);
    }
    // open book
    final Offset o = Offset(b.l + 54, b.cy);
    _p.color = const Color(0xFFFFF8E1);
    canvas.drawPath(Path()..moveTo(o.dx, o.dy - 8)..lineTo(o.dx - 26, o.dy - 14)..lineTo(o.dx - 26, o.dy + 12)..lineTo(o.dx, o.dy + 18)..close(), _p);
    canvas.drawPath(Path()..moveTo(o.dx, o.dy - 8)..lineTo(o.dx + 26, o.dy - 14)..lineTo(o.dx + 26, o.dy + 12)..lineTo(o.dx, o.dy + 18)..close(), _p);
    _s.strokeWidth = 1.4;
    _s.color = const Color(0xFF8D6E63);
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(Offset(o.dx - 22, o.dy - 6 + i * 6), Offset(o.dx - 4, o.dy - 2 + i * 6), _s);
      canvas.drawLine(Offset(o.dx + 22, o.dy - 6 + i * 6), Offset(o.dx + 4, o.dy - 2 + i * 6), _s);
    }
  }

  void _hallDecor(Canvas canvas, SdBuilding b, double tm) {
    final Offset c = Offset(b.cx, b.cy - 8);
    _p.color = const Color(0xFF3B5069);
    canvas.drawCircle(c, 62, _p);
    _p.color = const Color(0xFFE3B341);
    canvas.drawCircle(c, 56, _p);
    _p.color = const Color(0xFFF6D77A);
    canvas.drawCircle(c.translate(-8, -8), 34, _p);
    // clock face
    _p.color = Colors.white;
    canvas.drawCircle(c, 26, _p);
    _s.strokeWidth = 2;
    _s.color = const Color(0xFF3E2723);
    canvas.drawCircle(c, 26, _s);
    final double h = logic.dayF * 4 * pi;
    canvas.drawLine(c, Offset(c.dx + cos(h - pi / 2) * 14, c.dy + sin(h - pi / 2) * 14), _s);
    final double m = tm * 0.6;
    canvas.drawLine(c, Offset(c.dx + cos(m - pi / 2) * 21, c.dy + sin(m - pi / 2) * 21), _s);
    // bell on top
    final Path bell = Path()
      ..moveTo(c.dx - 9, c.dy - 52)
      ..quadraticBezierTo(c.dx - 8, c.dy - 70, c.dx, c.dy - 70)
      ..quadraticBezierTo(c.dx + 8, c.dy - 70, c.dx + 9, c.dy - 52)
      ..close();
    _p.color = const Color(0xFFF2B53A);
    canvas.drawPath(bell, _p);
    // columns
    _p.color = const Color(0xFFE9E4D8);
    for (int i = 0; i < 6; i++) {
      final double x = b.l + 40 + i * (b.r - b.l - 80) / 5;
      if ((x - c.dx).abs() < 66) continue;
      canvas.drawRRect(_rr(Rect.fromCenter(center: Offset(x, b.cy + 8), width: 14, height: 70), 4), _p);
    }
  }

  // ---- effects and markers ----------------------------------------------

  void _whisperFx(Canvas canvas, SdBuilding b, double tm) {
    if (!logic.whisper[b.id] || logic.fixed[b.id]) return;
    final Rect body = Rect.fromLTRB(b.l, b.t, b.r, b.b);
    _p.color = const Color(0xFF6D5560).withValues(alpha: 0.34);
    canvas.drawRRect(_rr(body.deflate(9), 10), _p);
    final Offset c = Offset(b.cx, b.cy);
    final double rx = (b.r - b.l) / 2 * 0.78;
    final double ry = (b.b - b.t) / 2 * 0.66;
    _s.strokeWidth = 3.2;
    for (int k = 0; k < 10; k++) {
      final double dirn = k.isEven ? 1 : -1;
      final double a = tm * 0.8 * dirn + k * 2 * pi / 10;
      final double rm = 1 + (k % 3) * 0.1;
      final Offset p0 = c + Offset(cos(a) * rx * rm, sin(a) * ry * rm);
      final Path sw = Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p0.dx + 11 * cos(a + 1.3), p0.dy + 11 * sin(a + 1.3), p0.dx + 6 * cos(a + 2.6), p0.dy + 6 * sin(a + 2.6))
        ..quadraticBezierTo(p0.dx + 2 * cos(a + 3.2), p0.dy + 2 * sin(a + 3.2), p0.dx + 3 * cos(a + 4), p0.dy + 3 * sin(a + 4));
      _s.color = (k % 3 == 0 ? _greyRed : _greyMark).withValues(alpha: 0.88);
      canvas.drawPath(sw, _s);
    }
    final double u = (logic.wAge[b.id] / sdSpreadAfter).clamp(0.0, 1.0).toDouble();
    _s.strokeWidth = 4;
    _s.color = const Color(0xFFE53935).withValues(alpha: (0.2 + 0.55 * u) * (0.6 + 0.4 * sin(tm * 5)));
    canvas.drawRRect(_rr(body.inflate(10 + 3 * sin(tm * 5)), 18), _s);
  }

  void _fixedFx(Canvas canvas, SdBuilding b, double tm) {
    if (!logic.fixed[b.id]) return;
    if (logic.bubbleT[b.id] <= 0) return;
    for (int i = 0; i < 4; i++) {
      final double f = ((tm * 0.8) + i / 4) % 1.0;
      final Offset p = Offset(b.l + (b.r - b.l) * (0.15 + 0.7 * ((i * 0.37) % 1.0)), b.cy - f * 70);
      _p.color = _gold.withValues(alpha: 0.9 * (1 - f));
      canvas.drawCircle(p, 4 * (1 - f) + 1, _p);
    }
  }

  void _target(Canvas canvas, double tm) {
    if (logic.hasTarget) {
      final double pulse = 10 + 3 * sin(tm * 8);
      _s.strokeWidth = 3;
      _s.color = Colors.white.withValues(alpha: 0.85);
      canvas.drawCircle(Offset(logic.tx, logic.ty), pulse, _s);
      _p.color = _gold.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(logic.tx, logic.ty), 5, _p);
    }
    final int t = logic.target;
    if (logic.phase != 0 || t < 0) return;
    final SdBuilding b = sdBuildings[t];
    final double pulse = 6 + 4 * sin(tm * 5);
    _s.strokeWidth = 4;
    _s.color = _gold.withValues(alpha: 0.95);
    canvas.drawRRect(_rr(Rect.fromLTRB(b.l, b.t, b.r, b.b).inflate(pulse), 18), _s);
    _s.strokeWidth = 2;
    _s.color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(b.doorX, b.doorY), 26 + 4 * sin(tm * 5), _s);
  }

  void _marker(Canvas canvas, SdBuilding b, double tm) {
    final Offset m = Offset(b.doorX + 48, b.doorBelow ? b.doorY + 4 : b.doorY - 4);
    final bool done = logic.fixed[b.id];
    final bool wh = logic.whisper[b.id] && !done;
    final bool locked = b.id == sdHall && !logic.hallOpen && !done;
    _p.color = done ? const Color(0xFF2E7D32) : (wh ? const Color(0xFFC62828) : (locked ? const Color(0xFF455A64) : const Color(0xFFF9A825)));
    canvas.drawCircle(m, 12, _p);
    _s.strokeWidth = 2.6;
    _s.color = Colors.white;
    if (done) {
      final Path ck = Path()
        ..moveTo(m.dx - 5, m.dy)
        ..lineTo(m.dx - 1, m.dy + 4)
        ..lineTo(m.dx + 6, m.dy - 5);
      canvas.drawPath(ck, _s);
    } else if (locked) {
      _p.color = Colors.white;
      canvas.drawRRect(_rr(Rect.fromCenter(center: m.translate(0, 2), width: 11, height: 9), 2), _p);
      canvas.drawArc(Rect.fromCenter(center: m.translate(0, -2), width: 8, height: 9), pi, pi, false, _s);
    } else {
      RealmDraw.text(canvas, wh ? '~' : '!', m, 16, Colors.white, maxWidth: 20, maxLines: 1);
    }
    // door prompt, as in the detective town
    if (logic.atDoor == b.id && logic.phase == 0) {
      _s.strokeWidth = 3;
      _s.color = _gold.withValues(alpha: 0.95);
      canvas.drawCircle(Offset(b.doorX, b.doorY), 26 + 3 * sin(tm * 6), _s);
      final String txt = done ? 'ALREADY SPEAKING' : (locked ? 'LOCKED: TOWN HALL' : 'FIX: ${b.name.toUpperCase()}');
      RealmDraw.label(canvas, txt, Offset(b.doorX, b.doorBelow ? b.doorY + 20 : b.doorY - 52), size: 13, maxWidth: 190);
    }
  }

  void _bubble(Canvas canvas, SdBuilding b) {
    if (!logic.fixed[b.id]) return;
    final double dx = logic.px - b.doorX;
    final double dy = logic.py - b.doorY;
    final bool near = dx * dx + dy * dy < 380 * 380;
    if (!near && logic.bubbleT[b.id] <= 0) return;
    final TextPainter tp = TextPainter(
      text: TextSpan(text: b.bubble, style: const TextStyle(color: Color(0xFF2B2418), fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani', height: 1.15)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
    )..layout(maxWidth: 170);
    final double w = tp.width + 20;
    final double h = tp.height + 14;
    final double cy = b.doorBelow ? b.doorY + 62 + h / 2 : b.doorY - 62 - h / 2;
    final Rect r = Rect.fromCenter(center: Offset(b.doorX, cy), width: w, height: h);
    _p.color = Colors.white.withValues(alpha: 0.96);
    canvas.drawRRect(_rr(r, 12), _p);
    final double ty = b.doorBelow ? r.top : r.bottom;
    final double tipY = b.doorBelow ? r.top - 12 : r.bottom + 12;
    canvas.drawPath(Path()..moveTo(b.doorX - 8, ty)..lineTo(b.doorX + 8, ty)..lineTo(b.doorX, tipY)..close(), _p);
    _s.strokeWidth = 2;
    _s.color = _gold;
    canvas.drawRRect(_rr(r, 12), _s);
    tp.paint(canvas, Offset(r.left + 10, r.top + 7));
  }

  void _warningRing(Canvas canvas, Size size, double tm) {
    final int n = logic.whisperCount;
    if (n < 3 || logic.phase == 3) return;
    final double pulse = 0.5 + 0.5 * sin(tm * (n >= 4 ? 7 : 4));
    final double a = (n >= 4 ? 0.55 : 0.32) * (0.5 + 0.5 * pulse);
    _s.strokeWidth = n >= 4 ? 12 : 8;
    _s.color = const Color(0xFFE53935).withValues(alpha: a);
    canvas.drawRRect(_rr((Offset.zero & size).deflate(3), 18), _s);
  }

  @override
  bool shouldRepaint(covariant SundialPainter oldDelegate) => true;
}
