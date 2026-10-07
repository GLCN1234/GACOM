import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'frontier_logic.dart';

/// Draws the settlement top-down in a cozy style, using only canvas primitives.
/// Sprites are drawn in unit coordinates: one tile is 1 by 1.
class FrontierPainter extends CustomPainter {
  final FrontierLogic logic;
  FrontierPainter(this.logic, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Path _path = Path();

  static const List<Color> _grass = <Color>[
    Color(0xFF86C04E),
    Color(0xFF7DB84A),
    Color(0xFF79B246),
    Color(0xFF74AC43),
    Color(0xFF82BC4C),
  ];
  static const List<Color> _shirts = <Color>[
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFFFFB74D),
    Color(0xFF81C784),
    Color(0xFFBA68C8),
    Color(0xFFFFF176),
  ];
  static const List<Color> _roofs = <Color>[Color(0xFFC0572B), Color(0xFF3F7CAC), Color(0xFF7B4FA3)];

  // ---- small drawing helpers ----------------------------------------------

  void _rect(Canvas c, double x, double y, double w, double h, Color col) {
    _fill.color = col;
    c.drawRect(Rect.fromLTWH(x, y, w, h), _fill);
  }

  void _rr(Canvas c, double x, double y, double w, double h, double r, Color col) {
    _fill.color = col;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), _fill);
  }

  void _circ(Canvas c, double x, double y, double r, Color col) {
    _fill.color = col;
    c.drawCircle(Offset(x, y), r, _fill);
  }

  void _oval(Canvas c, double cx, double cy, double w, double h, Color col) {
    _fill.color = col;
    c.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), _fill);
  }

  void _ln(Canvas c, double x1, double y1, double x2, double y2, double w, Color col) {
    _stroke.strokeWidth = w;
    _stroke.color = col;
    c.drawLine(Offset(x1, y1), Offset(x2, y2), _stroke);
  }

  void _tri(Canvas c, double x1, double y1, double x2, double y2, double x3, double y3, Color col) {
    _path.reset();
    _path.moveTo(x1, y1);
    _path.lineTo(x2, y2);
    _path.lineTo(x3, y3);
    _path.close();
    _fill.color = col;
    c.drawPath(_path, _fill);
  }

  // ---- main ---------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    logic.lastSize = size;
    final double ts = logic.tileSizeFor(size);
    final Offset o = logic.originFor(size);
    final double mapW = ts * kFrontierSize;
    final double t = logic.time;

    _fill.color = const Color(0xFF15241A);
    canvas.drawRect(Offset.zero & size, _fill);
    _fill.color = const Color(0xFF3B2A1B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 6, o.dy - 6, mapW + 12, mapW + 12), const Radius.circular(12)), _fill);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(o.dx, o.dy, mapW, mapW));
    for (int y = 0; y < kFrontierSize; y++) {
      for (int x = 0; x < kFrontierSize; x++) {
        canvas.save();
        canvas.translate(o.dx + x * ts, o.dy + y * ts);
        canvas.scale(ts, ts);
        _tile(canvas, x, y, t);
        canvas.restore();
      }
    }

    _drawSelection(canvas, o, ts, t);
    _drawSettlers(canvas, o, ts);
    _drawRaid(canvas, o, ts);
    _drawPopups(canvas, o, ts);

    // night
    final double p = logic.dayT / kFrontierDayLen;
    if (p > 0.7) {
      final double a = (p - 0.7) / 0.3;
      final bool raidNight = logic.day % 5 == 0;
      _fill.color = (raidNight ? const Color(0xFF3A0A16) : const Color(0xFF0B1A4A)).withValues(alpha: a * (raidNight ? 0.5 : 0.4));
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, mapW, mapW), _fill);
    }
    canvas.restore();

    _drawSunTrack(canvas, o, mapW, p);

    if (logic.toastT > 0 && logic.toast.isNotEmpty) {
      RealmDraw.label(canvas, logic.toast, Offset(size.width / 2, o.dy + 8), size: 13, maxWidth: size.width - 70);
    }
  }

  @override
  bool shouldRepaint(covariant FrontierPainter oldDelegate) => true;

  // ---- tiles ----------------------------------------------------------------

  void _tile(Canvas c, int x, int y, double t) {
    final int i = y * kFrontierSize + x;
    final int terr = logic.terrain[i];
    final int d = logic.deco[i];
    final double sh = logic.shade[i];
    switch (terr) {
      case 1:
        _forest(c, d, t);
        break;
      case 2:
        _hills(c, d);
        break;
      case 3:
        _water(c, x, y, d, t);
        break;
      case 4:
        _fertile(c, d, t);
        break;
      default:
        _meadow(c, d, sh);
        break;
    }
    final int b = logic.bType[i];
    if (b >= 0) {
      _building(c, b, logic.bLevel[i], x, y, i, t);
    }
  }

  void _meadow(Canvas c, int d, double sh) {
    int k = (sh * 5).floor();
    if (k > 4) k = 4;
    _rect(c, 0, 0, 1, 1, _grass[k]);
    if (d % 3 == 0) {
      final double ax = 0.2 + (d % 7) * 0.08;
      final double ay = 0.3 + (d % 5) * 0.1;
      _ln(c, ax, ay, ax - 0.03, ay - 0.1, 0.03, const Color(0xFF5E9A35));
      _ln(c, ax + 0.06, ay, ax + 0.07, ay - 0.09, 0.03, const Color(0xFF5E9A35));
    }
    if (d < 12) {
      final Color fc = d % 3 == 0 ? Colors.white : (d % 3 == 1 ? const Color(0xFFFFF176) : const Color(0xFFF48FB1));
      _circ(c, 0.25 + (d % 6) * 0.1, 0.7 - (d % 4) * 0.08, 0.04, fc);
    }
  }

  void _forest(Canvas c, int d, double t) {
    _rect(c, 0, 0, 1, 1, const Color(0xFF5F9A3E));
    final int n = 3 + (d % 2);
    for (int k = 0; k < n; k++) {
      final double tx = 0.2 + 0.3 * (k % 3) + ((d + k * 13) % 10) * 0.012;
      final double ty = 0.38 + 0.2 * (k ~/ 2) + (k % 2) * 0.1;
      final double sway = sin(t * 1.5 + d + k) * 0.015;
      _oval(c, tx, ty + 0.2, 0.22, 0.07, const Color(0x33000000));
      _rect(c, tx - 0.03, ty + 0.02, 0.06, 0.18, const Color(0xFF6D4C30));
      _circ(c, tx + sway, ty - 0.08, 0.17, const Color(0xFF2F7D32));
      _circ(c, tx + sway - 0.04, ty - 0.12, 0.1, const Color(0xFF4CAF50));
    }
  }

  void _hills(Canvas c, int d) {
    _rect(c, 0, 0, 1, 1, const Color(0xFF8FA05A));
    _oval(c, 0.5, 0.66, 0.96, 0.62, const Color(0xFF8E8678));
    _oval(c, 0.46, 0.58, 0.7, 0.4, const Color(0xFFA39B8C));
    _circ(c, 0.28 + (d % 5) * 0.08, 0.72, 0.06, const Color(0xFFB9B9B9));
    _circ(c, 0.66, 0.5 + (d % 3) * 0.05, 0.05, const Color(0xFFCFCFCF));
    _circ(c, 0.5, 0.82, 0.04, const Color(0xFF9E9E9E));
  }

  void _water(Canvas c, int x, int y, int d, double t) {
    _rect(c, 0, 0, 1, 1, const Color(0xFF3FA7D6));
    _rect(c, 0, ((d % 4) * 0.2), 1, 0.25, const Color(0xFF4DB3E0));
    for (int k = 0; k < 2; k++) {
      final double off = sin(t * 1.2 + d * 0.3 + k * 2) * 0.1;
      _ln(c, 0.2 + off, 0.3 + 0.4 * k, 0.55 + off, 0.3 + 0.4 * k, 0.035, const Color(0x55FFFFFF));
    }
    const Color sand = Color(0xFFE6D3A3);
    if (!_isWater(x, y - 1)) _rect(c, 0, 0, 1, 0.07, sand);
    if (!_isWater(x, y + 1)) _rect(c, 0, 0.93, 1, 0.07, sand);
    if (!_isWater(x - 1, y)) _rect(c, 0, 0, 0.07, 1, sand);
    if (!_isWater(x + 1, y)) _rect(c, 0.93, 0, 0.07, 1, sand);
  }

  bool _isWater(int x, int y) {
    if (x < 0 || y < 0 || x >= kFrontierSize || y >= kFrontierSize) return true;
    return logic.terrain[y * kFrontierSize + x] == 3;
  }

  void _fertile(Canvas c, int d, double t) {
    _rect(c, 0, 0, 1, 1, const Color(0xFF7B5A3C));
    for (int r = 0; r < 3; r++) {
      final double ry = 0.12 + r * 0.3;
      _rect(c, 0.04, ry, 0.92, 0.12, const Color(0xFF68482C));
      for (int k = 0; k < 4; k++) {
        final double sway = sin(t * 2 + k + r) * 0.01;
        _circ(c, 0.17 + k * 0.22 + sway, ry + 0.02, 0.035, const Color(0xFF7CB342));
      }
    }
  }

  bool _isWall(int x, int y) {
    if (x < 0 || y < 0 || x >= kFrontierSize || y >= kFrontierSize) return false;
    return logic.bType[y * kFrontierSize + x] == 7;
  }

  // ---- buildings ------------------------------------------------------------

  void _building(Canvas c, int type, int lv, int x, int y, int i, double t) {
    _oval(c, 0.5, 0.9, 0.78, 0.14, const Color(0x44000000));
    switch (type) {
      case 0:
        _farm(c, lv, t);
        break;
      case 1:
        _lumber(c, lv, t);
        break;
      case 2:
        _quarry(c, lv, t);
        break;
      case 3:
        _house(c, lv, t, i);
        break;
      case 4:
        _school(c, lv, t);
        break;
      case 5:
        _well(c, lv, t);
        break;
      case 6:
        _tower(c, lv, t);
        break;
      case 7:
        _wall(c, lv, x, y);
        break;
      default:
        _hall(c, t);
        break;
    }
    if (type != kFrontierHall) {
      for (int k = 0; k < lv; k++) {
        _circ(c, 0.12 + k * 0.1, 0.94, 0.045, const Color(0xFF3E2C1C));
        _circ(c, 0.12 + k * 0.1, 0.94, 0.03, const Color(0xFFFFD54F));
      }
    }
  }

  void _smoke(Canvas c, double x, double y, double t, int seed) {
    for (int k = 0; k < 3; k++) {
      final double ph = ((t * 0.5 + k / 3.0 + seed * 0.13) % 1.0);
      _circ(c, x + sin(ph * 6 + k) * 0.03, y - ph * 0.3, 0.025 + ph * 0.035, Colors.white.withValues(alpha: (1 - ph) * 0.55));
    }
  }

  void _farm(Canvas c, int lv, double t) {
    _rr(c, 0.05, 0.38, 0.9, 0.56, 0.04, const Color(0xFFA1763F));
    for (int r = 0; r < 3; r++) {
      _rect(c, 0.08, 0.5 + r * 0.14, 0.84, 0.04, const Color(0xFF86602F));
    }
    for (int k = 0; k < 6; k++) {
      final double x = 0.14 + 0.14 * k;
      final double sway = sin(t * 2 + k) * 0.03;
      _ln(c, x, 0.9, x + sway, 0.56, 0.035, const Color(0xFFE6C34A));
      _circ(c, x + sway, 0.55, 0.04, const Color(0xFFF2D75B));
    }
    _rect(c, 0.08, 0.12, 0.36, 0.26, const Color(0xFFB3412F));
    _tri(c, 0.04, 0.14, 0.26, -0.02, 0.48, 0.14, const Color(0xFF6D2A20));
    _rect(c, 0.2, 0.22, 0.12, 0.16, const Color(0xFFF1E3C8));
    if (lv >= 2) {
      _rect(c, 0.62, 0.1, 0.14, 0.3, const Color(0xFFB0BEC5));
      _circ(c, 0.69, 0.1, 0.09, const Color(0xFF90A4AE));
    }
    if (lv >= 3) {
      _ln(c, 0.88, 0.2, 0.88, 0.42, 0.03, const Color(0xFF6D4C30));
      _ln(c, 0.8, 0.27, 0.96, 0.27, 0.03, const Color(0xFF6D4C30));
      _circ(c, 0.88, 0.18, 0.04, const Color(0xFFF2B785));
    }
  }

  void _lumber(Canvas c, int lv, double t) {
    _rect(c, 0.08, 0.32, 0.5, 0.46, const Color(0xFF8D5A36));
    for (int k = 0; k < 3; k++) {
      _rect(c, 0.08, 0.42 + k * 0.12, 0.5, 0.025, const Color(0xFF6D4326));
    }
    _tri(c, 0.02, 0.34, 0.33, 0.08, 0.64, 0.34, const Color(0xFF4E342E));
    _rect(c, 0.26, 0.55, 0.14, 0.23, const Color(0xFF3E2723));
    final List<double> lx = <double>[0.72, 0.86, 0.79, 0.72, 0.86];
    final List<double> ly = <double>[0.8, 0.8, 0.68, 0.56, 0.56];
    final int n = lv >= 3 ? 5 : (lv == 2 ? 4 : 3);
    for (int k = 0; k < n; k++) {
      _circ(c, lx[k], ly[k], 0.07, const Color(0xFF6D4326));
      _circ(c, lx[k], ly[k], 0.045, const Color(0xFFC8A06A));
    }
    final double a = sin(t * 4) * 0.5;
    _ln(c, 0.1, 0.84, 0.1 + sin(a) * 0.2, 0.84 - cos(a) * 0.2, 0.04, const Color(0xFF3E2723));
    if (lv >= 3) _smoke(c, 0.5, 0.1, t, 2);
  }

  void _quarry(Canvas c, int lv, double t) {
    _tri(c, 0.06, 0.88, 0.34, 0.3, 0.62, 0.88, const Color(0xFF9AA0A6));
    _tri(c, 0.4, 0.88, 0.66, 0.2, 0.94, 0.88, const Color(0xFF78808A));
    _tri(c, 0.34, 0.3, 0.44, 0.5, 0.26, 0.5, const Color(0xFFCFD8DC));
    _tri(c, 0.66, 0.2, 0.76, 0.42, 0.58, 0.42, const Color(0xFFB0BEC5));
    final double a = sin(t * 5) * 0.6 - 0.3;
    _ln(c, 0.16, 0.8, 0.16 + sin(a) * 0.22, 0.8 - cos(a) * 0.22, 0.04, const Color(0xFF5D4037));
    _rect(c, 0.62, 0.72, 0.3, 0.14, const Color(0xFF6D4C30));
    _circ(c, 0.68, 0.88, 0.04, const Color(0xFF263238));
    _circ(c, 0.86, 0.88, 0.04, const Color(0xFF263238));
    if (lv >= 2) {
      _circ(c, 0.7, 0.72, 0.05, const Color(0xFFB0BEC5));
      _circ(c, 0.8, 0.7, 0.05, const Color(0xFF90A4AE));
    }
    if (lv >= 3) {
      final double ph = (t * 0.8) % 1.0;
      _circ(c, 0.3, 0.7 - ph * 0.3, 0.03 + ph * 0.03, Colors.white.withValues(alpha: (1 - ph) * 0.6));
    }
  }

  void _house(Canvas c, int lv, double t, int seed) {
    final Color roof = _roofs[(lv - 1) % 3];
    _rect(c, 0.16, 0.45, 0.68, 0.42, lv >= 3 ? const Color(0xFFF5E6CF) : const Color(0xFFFFE0B2));
    _tri(c, 0.08, 0.47, 0.5, 0.1, 0.92, 0.47, roof);
    _rect(c, 0.42, 0.6, 0.16, 0.27, const Color(0xFF6D4326));
    _rect(c, 0.2, 0.55, 0.14, 0.14, const Color(0xFF81D4FA));
    if (lv >= 2) _rect(c, 0.66, 0.55, 0.14, 0.14, const Color(0xFF81D4FA));
    _rect(c, 0.68, 0.14, 0.08, 0.2, const Color(0xFF8D6E63));
    if (lv >= 3) {
      _circ(c, 0.26, 0.82, 0.04, const Color(0xFFF48FB1));
      _circ(c, 0.74, 0.82, 0.04, const Color(0xFFFFF176));
    }
    _smoke(c, 0.72, 0.14, t, seed % 7);
  }

  void _school(Canvas c, int lv, double t) {
    _rect(c, 0.1, 0.42, 0.8, 0.46, const Color(0xFFE8DCC0));
    _tri(c, 0.05, 0.44, 0.5, 0.1, 0.95, 0.44, const Color(0xFF3F51B5));
    for (int k = 0; k < 4; k++) {
      _rect(c, 0.16 + k * 0.2, 0.48, 0.05, 0.38, Colors.white);
    }
    _rr(c, 0.42, 0.6, 0.16, 0.28, 0.06, const Color(0xFF5D4037));
    final double sw = sin(t * 3) * 0.03;
    _circ(c, 0.5 + sw, 0.28, 0.05, const Color(0xFFFFD54F));
    _rect(c, 0.46, 0.22, 0.08, 0.02, const Color(0xFF8D6E63));
    if (lv >= 2) {
      _ln(c, 0.1, 0.42, 0.1, 0.1, 0.03, const Color(0xFF5D4037));
      final double fw = sin(t * 4) * 0.03;
      _tri(c, 0.1, 0.1, 0.28 + fw, 0.16, 0.1, 0.22, const Color(0xFF42A5F5));
    }
    if (lv >= 3) {
      _circ(c, 0.8, 0.6, 0.045, const Color(0xFFFFD54F));
      _rect(c, 0.74, 0.62, 0.12, 0.08, const Color(0xFF90CAF9));
    }
  }

  void _well(Canvas c, int lv, double t) {
    _oval(c, 0.5, 0.72, 0.62, 0.34, const Color(0xFF8A8A8A));
    _oval(c, 0.5, 0.7, 0.46, 0.22, const Color(0xFF2E86C1));
    _oval(c, 0.46, 0.68, 0.16, 0.06, const Color(0x66FFFFFF));
    _ln(c, 0.22, 0.7, 0.22, 0.3, 0.04, const Color(0xFF6D4326));
    _ln(c, 0.78, 0.7, 0.78, 0.3, 0.04, const Color(0xFF6D4326));
    _tri(c, 0.12, 0.34, 0.5, 0.08, 0.88, 0.34, lv >= 2 ? const Color(0xFF1E88E5) : const Color(0xFF8D5A36));
    final double bob = sin(t * 2) * 0.05;
    _ln(c, 0.5, 0.3, 0.5, 0.5 + bob, 0.02, const Color(0xFFD7CCC8));
    _rect(c, 0.46, 0.5 + bob, 0.08, 0.08, const Color(0xFF6D4326));
    if (lv >= 3) _circ(c, 0.5, 0.2, 0.04, const Color(0xFF4FC3F7));
  }

  void _tower(Canvas c, int lv, double t) {
    _rect(c, 0.3, 0.3, 0.4, 0.58, const Color(0xFF9A9A9A));
    for (int k = 0; k < 4; k++) {
      _rect(c, 0.3, 0.38 + k * 0.13, 0.4, 0.02, const Color(0xFF7C7C7C));
    }
    _rect(c, 0.2, 0.2, 0.6, 0.12, const Color(0xFF8D5A36));
    for (int k = 0; k < 3; k++) {
      _rect(c, 0.22 + k * 0.22, 0.14, 0.12, 0.08, const Color(0xFF8D5A36));
    }
    _rect(c, 0.44, 0.52, 0.12, 0.2, const Color(0xFF3E2723));
    _ln(c, 0.5, 0.2, 0.5, -0.02, 0.03, const Color(0xFF5D4037));
    final double fw = sin(t * 5) * 0.04;
    _tri(c, 0.5, -0.02, 0.5 + 0.22 + fw, 0.05, 0.5, 0.12, lv >= 3 ? const Color(0xFFFFD54F) : const Color(0xFFE53935));
    if (lv >= 2) {
      _rect(c, 0.2, 0.4, 0.1, 0.48, const Color(0xFF8C8C8C));
    }
    if (lv >= 3) {
      _rect(c, 0.7, 0.4, 0.1, 0.48, const Color(0xFF8C8C8C));
    }
  }

  void _wall(Canvas c, int lv, int x, int y) {
    const Color stone = Color(0xFF9E9E9E);
    const Color dark = Color(0xFF757575);
    if (_isWall(x + 1, y)) _rect(c, 0.5, 0.4, 0.5, 0.45, stone);
    if (_isWall(x - 1, y)) _rect(c, 0.0, 0.4, 0.5, 0.45, stone);
    if (_isWall(x, y - 1)) _rect(c, 0.3, 0.0, 0.4, 0.5, stone);
    if (_isWall(x, y + 1)) _rect(c, 0.3, 0.5, 0.4, 0.5, stone);
    _rect(c, 0.26, 0.3, 0.48, 0.58, stone);
    for (int k = 0; k < 3; k++) {
      _rect(c, 0.26 + k * 0.18, 0.22, 0.12, 0.1, stone);
    }
    _rect(c, 0.26, 0.5, 0.48, 0.02, dark);
    _rect(c, 0.26, 0.68, 0.48, 0.02, dark);
    if (lv >= 2) {
      _tri(c, 0.3, 0.22, 0.34, 0.08, 0.38, 0.22, const Color(0xFF5D4037));
      _tri(c, 0.62, 0.22, 0.66, 0.08, 0.70, 0.22, const Color(0xFF5D4037));
    }
    if (lv >= 3) {
      _rect(c, 0.26, 0.3, 0.48, 0.05, const Color(0xFFFFD54F));
    }
  }

  void _hall(Canvas c, double t) {
    _rect(c, 0.06, 0.4, 0.88, 0.48, const Color(0xFFD7C4A3));
    _rect(c, 0.06, 0.4, 0.88, 0.05, const Color(0xFFB9A582));
    _tri(c, 0.0, 0.42, 0.5, 0.04, 1.0, 0.42, const Color(0xFFB5651D));
    _tri(c, 0.2, 0.42, 0.5, 0.14, 0.8, 0.42, const Color(0xFFD08A3C));
    _rr(c, 0.4, 0.58, 0.2, 0.3, 0.08, const Color(0xFF5D4037));
    _rect(c, 0.14, 0.54, 0.14, 0.14, const Color(0xFF81D4FA));
    _rect(c, 0.72, 0.54, 0.14, 0.14, const Color(0xFF81D4FA));
    _ln(c, 0.5, 0.04, 0.5, -0.08, 0.03, const Color(0xFF5D4037));
    final double fw = sin(t * 4) * 0.04;
    _tri(c, 0.5, -0.08, 0.74 + fw, -0.02, 0.5, 0.04, const Color(0xFFE53935));
  }

  // ---- overlays -------------------------------------------------------------

  void _drawSelection(Canvas canvas, Offset o, double ts, double t) {
    if (logic.sel < 0) return;
    final Rect r = Rect.fromLTWH(o.dx + logic.selX * ts + 1, o.dy + logic.selY * ts + 1, ts - 2, ts - 2);
    _fill.color = const Color(0xFFFFF176).withValues(alpha: 0.18);
    canvas.drawRect(r, _fill);
    _stroke.strokeWidth = 2.5;
    _stroke.color = Colors.white.withValues(alpha: 0.7 + 0.3 * sin(t * 6));
    canvas.drawRect(r, _stroke);
  }

  void _drawSettlers(Canvas canvas, Offset o, double ts) {
    final double sc = ts * 0.6 / 50.0;
    for (int k = 0; k < logic.settlers.length; k++) {
      final FrontierSettler s = logic.settlers[k];
      final double px = o.dx + s.x * ts;
      final double py = o.dy + s.y * ts - 18 * sc;
      RealmDraw.person(canvas, px, py, phase: s.phase, moving: s.wait <= 0, facing: s.facing, shirt: _shirts[s.look % 6], scale: sc);
    }
  }

  void _drawRaid(Canvas canvas, Offset o, double ts) {
    if (logic.raidFx <= 0) return;
    final double p = 1.0 - logic.raidFx / 4.0;
    final int n = logic.raidFxCount;
    final double sc = ts * 0.62 / 50.0;
    final double hx = o.dx + 7.5 * ts;
    final double hy = o.dy + 7.9 * ts;
    for (int k = 0; k < n; k++) {
      final double ang = k * 2 * pi / n + 0.4;
      final double sx = hx + cos(ang) * ts * 9;
      final double sy = hy + sin(ang) * ts * 9;
      double f;
      if (logic.raidFxWon) {
        f = 0.7 * sin(p * pi);
      } else {
        f = p < 0.8 ? p / 0.8 * 0.95 : 0.95;
      }
      final double px = sx + (hx - sx) * f;
      final double py = sy + (hy - sy) * f - 18 * sc;
      RealmDraw.person(canvas, px, py, phase: p * 40 + k, moving: true, facing: px > hx ? -1.0 : 1.0, shirt: const Color(0xFFB71C1C), pants: const Color(0xFF212121), scale: sc);
    }
    if (!logic.raidFxWon && p < 0.35) {
      _fill.color = const Color(0xFFFF1744).withValues(alpha: 0.25 * (1 - p / 0.35));
      canvas.drawRect(Rect.fromLTWH(o.dx, o.dy, ts * kFrontierSize, ts * kFrontierSize), _fill);
    }
  }

  void _drawPopups(Canvas canvas, Offset o, double ts) {
    for (int k = 0; k < logic.popups.length; k++) {
      final FrontierPopup pp = logic.popups[k];
      final double a = 1.0 - pp.age / 1.7;
      if (a <= 0) continue;
      Color col;
      switch (pp.kind) {
        case 0:
          col = const Color(0xFFC5E1A5);
          break;
        case 1:
          col = const Color(0xFFD7B899);
          break;
        case 2:
          col = const Color(0xFFCFD8DC);
          break;
        case 4:
          col = const Color(0xFF81D4FA);
          break;
        default:
          col = const Color(0xFFFFE082);
          break;
      }
      final Offset at = Offset(o.dx + (pp.x + 0.5) * ts, o.dy + (pp.y + 0.15) * ts - pp.age * 16);
      RealmDraw.text(canvas, pp.text, at, 13, col.withValues(alpha: a), maxWidth: 80, maxLines: 1);
    }
  }

  void _drawSunTrack(Canvas canvas, Offset o, double mapW, double p) {
    final double y = o.dy - 18;
    _fill.color = Colors.white.withValues(alpha: 0.16);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, y - 3, mapW, 6), const Radius.circular(3)), _fill);
    _fill.color = const Color(0xFFFFD54F).withValues(alpha: 0.7);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, y - 3, mapW * p, 6), const Radius.circular(3)), _fill);
    final bool night = p > 0.75;
    _fill.color = night ? const Color(0xFFCFD8DC) : const Color(0xFFFFC107);
    canvas.drawCircle(Offset(o.dx + mapW * p, y), 8, _fill);
    if (night) {
      _fill.color = const Color(0xFF15241A);
      canvas.drawCircle(Offset(o.dx + mapW * p + 3, y - 2), 6, _fill);
    }
    if (logic.day % 5 == 0) {
      RealmDraw.text(canvas, 'RAID TONIGHT', Offset(o.dx + mapW - 56, y - 14), 12, const Color(0xFFFF8A80), maxWidth: 120, maxLines: 1);
    }
  }
}
