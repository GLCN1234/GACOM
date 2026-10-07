import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'biome_logic.dart';

double _cl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Ground colour for a subject: always a readable mid-dark tone of its hue,
/// never near-black (dark subject colours used to turn the map black).
Color _groundBase(Color c) {
  final HSLColor h = HSLColor.fromColor(c);
  return HSLColor.fromAHSL(1.0, h.hue, _cl(h.saturation, 0.3, 0.55), 0.27).toColor();
}

/// Scenery tint: bright enough to stand out from the ground.
Color _sceneTint(Color c) {
  final HSLColor h = HSLColor.fromColor(c);
  return HSLColor.fromAHSL(1.0, h.hue, _cl(h.saturation, 0.35, 0.7), 0.5).toColor();
}

// scenery kinds
const int _kTuft = 0;
const int _kBush = 1;
const int _kPond = 2;
const int _kEmber = 3;
const int _kFlower = 4;
const int _kCrystal = 5;
const int _kReed = 6;
const int _kShroom = 7;
const int _kStone = 8;

// one list of six kinds per theme
const List<List<int>> _themes = <List<int>>[
  <int>[_kTuft, _kTuft, _kBush, _kFlower, _kPond, _kTuft],
  <int>[_kEmber, _kEmber, _kStone, _kTuft, _kEmber, _kStone],
  <int>[_kCrystal, _kCrystal, _kTuft, _kPond, _kCrystal, _kStone],
  <int>[_kPond, _kReed, _kReed, _kBush, _kShroom, _kPond],
  <int>[_kShroom, _kShroom, _kTuft, _kFlower, _kBush, _kShroom],
];

class BiomePainter extends CustomPainter {
  final BiomeLogic g;
  static const double _tile = 120;

  static final Paint _p = Paint();
  static final Paint _s = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
  static final Path _path = Path();

  late final List<Color> _ground;
  late final List<int> _themeOf;

  BiomePainter(this.g, {required Listenable repaint}) : super(repaint: repaint) {
    final int n = g.content.subjectIds.length;
    final List<Color> gr = <Color>[];
    final List<int> th = <int>[];
    for (int i = 0; i < n; i++) {
      final String id = g.content.subjectIds[i];
      final Color d = _groundBase(g.content.subject(id).color);
      gr.add(d);
      gr.add(realmLighten(d, 0.035));
      gr.add(realmLighten(d, 0.07));
      int h = 0;
      for (final int c in id.codeUnits) {
        h = (h * 31 + c) & 0x7fffffff;
      }
      th.add(h % _themes.length);
    }
    _ground = gr;
    _themeOf = th;
  }

  @override
  bool shouldRepaint(covariant BiomePainter oldDelegate) => true;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWorld(canvas, size);
    final BiomeBattle? b = g.battle;
    if (b != null) {
      _paintBattle(canvas, size, b);
    } else if (g.toastT > 0) {
      RealmDraw.label(canvas, g.toast, Offset(size.width / 2, 104), size: 14, maxWidth: size.width - 70);
    }
  }

  // ---- world ------------------------------------------------------------------

  void _paintWorld(Canvas canvas, Size size) {
    final double cx = g.px - size.width / 2;
    final double cy = g.py - size.height / 2;
    canvas.save();
    canvas.translate(-cx, -cy);
    final int tx0 = (cx / _tile).floor() - 1;
    final int tx1 = ((cx + size.width) / _tile).ceil() + 1;
    final int ty0 = (cy / _tile).floor() - 1;
    final int ty1 = ((cy + size.height) / _tile).ceil() + 1;
    final int seed = g.content.seed;
    for (int ty = ty0; ty <= ty1; ty++) {
      for (int tx = tx0; tx <= tx1; tx++) {
        final int ri = g.regionIndexAt(tx * _tile + _tile / 2, ty * _tile + _tile / 2);
        final int h = realmHash(tx, ty, seed);
        _p.color = _ground[ri * 3 + (h % 3)];
        canvas.drawRect(Rect.fromLTWH(tx * _tile, ty * _tile, _tile + 1, _tile + 1), _p);
      }
    }
    for (int ty = ty0; ty <= ty1; ty++) {
      for (int tx = tx0; tx <= tx1; tx++) {
        final int ri = g.regionIndexAt(tx * _tile + _tile / 2, ty * _tile + _tile / 2);
        final Color sc = _sceneTint(g.content.subject(g.content.subjectIds[ri]).color);
        final List<int> th = _themes[_themeOf[ri]];
        for (int k = 0; k < 2; k++) {
          final int hh = realmHash(tx * 2 + k, ty, seed + 7);
          if (hh % 100 >= 52) continue;
          final double ix = tx * _tile + (hh >> 3) % 108 + 6;
          final double iy = ty * _tile + (hh >> 9) % 108 + 6;
          final int kind = th[(hh >> 15) % 6];
          _scenery(canvas, kind, ix, iy, sc, hh);
        }
      }
    }
    // pickups
    final double t = g.time;
    for (final BiomePickup pk in g.pickups) {
      if (pk.x < cx - 60 || pk.x > cx + size.width + 60 || pk.y < cy - 60 || pk.y > cy + size.height + 60) continue;
      _pickup(canvas, pk, t);
    }
    _campArrow(canvas);
    // creatures and player, roughly sorted by depth
    for (final BiomeCreature w in g.wilds) {
      if (w.y > g.py) continue;
      _wild(canvas, w, cx, cy, size);
    }
    _companion(canvas);
    RealmDraw.person(canvas, g.px, g.py, phase: g.walkPhase, moving: g.moving, facing: g.facing);
    for (final BiomeCreature w in g.wilds) {
      if (w.y <= g.py) continue;
      _wild(canvas, w, cx, cy, size);
    }
    canvas.restore();
  }

  void _companion(Canvas canvas) {
    if (g.team.isEmpty) return;
    final BiomeCreature c = g.active;
    drawCreature(canvas, c.shape, c.color, g.fx, g.fy + 14, 0.6, g.time * 4, g.facing, c.seed, 0, false);
  }

  void _wild(Canvas canvas, BiomeCreature w, double cx, double cy, Size size) {
    if (w.x < cx - 80 || w.x > cx + size.width + 80 || w.y < cy - 100 || w.y > cy + size.height + 80) return;
    drawCreature(canvas, w.shape, w.color, w.x, w.y + 14, w.elder ? 1.35 : 1.0, w.phase, w.facing, w.seed, 0, w.elder);
    RealmDraw.label(canvas, '${w.name}  Lv ${w.level}', Offset(w.x, w.y - (w.elder ? 62 : 46)), size: 11, maxWidth: 170);
    if (w.behavior == 2 && !w.elder) {
      final double dx = g.px - w.x;
      final double dy = g.py - w.y;
      if (dx * dx + dy * dy < 320 * 320) {
        RealmDraw.text(canvas, '!', Offset(w.x + 20, w.y - 30), 18, const Color(0xFFFF5252));
      }
    }
  }

  void _campArrow(Canvas canvas) {
    if (g.teamMaxHp <= 0 || g.teamHp / g.teamMaxHp > 0.7) return;
    BiomePickup? best;
    double bd = 1e18;
    for (final BiomePickup pk in g.pickups) {
      if (pk.type != 2) continue;
      final double dx = pk.x - g.px;
      final double dy = pk.y - g.py;
      final double d = dx * dx + dy * dy;
      if (d < bd) {
        bd = d;
        best = pk;
      }
    }
    if (best == null || bd < 220 * 220) return;
    final double ang = atan2(best.y - g.py, best.x - g.px);
    final double ax = g.px + cos(ang) * 72;
    final double ay = g.py + sin(ang) * 72;
    _path.reset();
    _path.moveTo(ax + cos(ang) * 12, ay + sin(ang) * 12);
    _path.lineTo(ax + cos(ang + 2.5) * 10, ay + sin(ang + 2.5) * 10);
    _path.lineTo(ax + cos(ang - 2.5) * 10, ay + sin(ang - 2.5) * 10);
    _path.close();
    _p.color = const Color(0xFFFFB300).withValues(alpha: 0.9);
    canvas.drawPath(_path, _p);
  }

  void _pickup(Canvas canvas, BiomePickup pk, double t) {
    final double bob = sin(t * 3 + pk.phase) * 3;
    if (pk.type == 0) {
      RealmDraw.shadow(canvas, pk.x, pk.y + 8, 22);
      RealmDraw.glow(canvas, Offset(pk.x, pk.y - 4 + bob), 20, const Color(0xFFB388FF), alpha: 0.3 + 0.1 * sin(t * 4 + pk.phase));
      _p.color = const Color(0xFF7C4DFF);
      canvas.drawCircle(Offset(pk.x, pk.y - 4 + bob), 11, _p);
      _p.color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(pk.x - 11, pk.y - 5 + bob, 22, 3), _p);
      _p.color = Colors.white.withValues(alpha: 0.7);
      canvas.drawCircle(Offset(pk.x - 4, pk.y - 9 + bob), 2.6, _p);
    } else if (pk.type == 1) {
      RealmDraw.shadow(canvas, pk.x, pk.y + 8, 16);
      _p.color = const Color(0xFFFFC107);
      canvas.drawCircle(Offset(pk.x, pk.y - 3 + bob), 8, _p);
      _p.color = const Color(0xFFFFE082);
      canvas.drawCircle(Offset(pk.x - 1.5, pk.y - 4.5 + bob), 4.5, _p);
    } else {
      RealmDraw.glow(canvas, Offset(pk.x, pk.y - 8), 48 + 5 * sin(t * 6), const Color(0xFFFF9100), alpha: 0.18);
      RealmDraw.shadow(canvas, pk.x, pk.y + 8, 40);
      _s.strokeWidth = 6;
      _s.color = const Color(0xFF5D4037);
      canvas.drawLine(Offset(pk.x - 14, pk.y + 6), Offset(pk.x + 12, pk.y - 2), _s);
      canvas.drawLine(Offset(pk.x + 14, pk.y + 6), Offset(pk.x - 12, pk.y - 2), _s);
      final double f = 1 + 0.18 * sin(t * 11 + pk.phase);
      _path.reset();
      _path.moveTo(pk.x, pk.y - 28 * f);
      _path.quadraticBezierTo(pk.x + 14, pk.y - 10, pk.x + 8, pk.y - 2);
      _path.lineTo(pk.x - 8, pk.y - 2);
      _path.quadraticBezierTo(pk.x - 14, pk.y - 10, pk.x, pk.y - 28 * f);
      _p.color = const Color(0xFFFF6D00);
      canvas.drawPath(_path, _p);
      _p.color = const Color(0xFFFFD54F);
      canvas.drawOval(Rect.fromCenter(center: Offset(pk.x, pk.y - 8), width: 9, height: 16 * f), _p);
    }
  }

  void _scenery(Canvas canvas, int kind, double x, double y, Color sc, int h) {
    final double r = (h % 1000) / 1000.0;
    switch (kind) {
      case _kTuft: {
        _s.strokeWidth = 2.4;
        _s.color = realmLighten(realmDarken(sc, 0.12), 0.1);
        for (int i = -2; i <= 2; i++) {
          canvas.drawLine(Offset(x + i * 3.0, y), Offset(x + i * 5.0, y - 9 - (i % 2).abs() * 5 - r * 3), _s);
        }
        break;
      }
      case _kBush: {
        RealmDraw.shadow(canvas, x, y + 4, 38);
        _p.color = realmDarken(sc, 0.12);
        canvas.drawCircle(Offset(x - 9, y - 4), 11, _p);
        canvas.drawCircle(Offset(x + 9, y - 4), 11, _p);
        canvas.drawCircle(Offset(x, y - 11), 13, _p);
        _p.color = realmLighten(sc, 0.04);
        canvas.drawCircle(Offset(x - 3, y - 14), 6, _p);
        _p.color = realmLighten(sc, 0.3);
        canvas.drawCircle(Offset(x + 7, y - 8), 2.2, _p);
        break;
      }
      case _kPond: {
        final double w = 54 + r * 26;
        _p.color = realmLighten(sc, 0.06);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w + 8, height: w * 0.55 + 6), _p);
        _p.color = Color.lerp(realmDarken(sc, 0.2), const Color(0xFF1E88E5), 0.55) ?? const Color(0xFF1E88E5);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: w * 0.55), _p);
        _s.strokeWidth = 1.5;
        _s.color = Colors.white.withValues(alpha: 0.35);
        canvas.drawArc(Rect.fromCenter(center: Offset(x - 4, y - 2), width: w * 0.5, height: w * 0.22), 3.4, 2.2, false, _s);
        break;
      }
      case _kEmber: {
        RealmDraw.glow(canvas, Offset(x, y - 6), 26, const Color(0xFFFF6D00), alpha: 0.14);
        RealmDraw.shadow(canvas, x, y + 4, 36);
        _p.color = const Color(0xFF3E2723);
        _path.reset();
        _path.moveTo(x - 15, y + 2);
        _path.lineTo(x - 10, y - 14);
        _path.lineTo(x + 2, y - 20);
        _path.lineTo(x + 14, y - 9);
        _path.lineTo(x + 16, y + 2);
        _path.close();
        canvas.drawPath(_path, _p);
        _s.strokeWidth = 2;
        _s.color = const Color(0xFFFF9100);
        canvas.drawLine(Offset(x - 4, y - 14), Offset(x, y - 6), _s);
        canvas.drawLine(Offset(x, y - 6), Offset(x + 8, y - 3), _s);
        break;
      }
      case _kFlower: {
        _s.strokeWidth = 1.8;
        _s.color = realmDarken(sc, 0.05);
        canvas.drawLine(Offset(x, y), Offset(x, y - 10), _s);
        _p.color = h % 2 == 0 ? const Color(0xFFFFF176) : const Color(0xFFF48FB1);
        for (int i = 0; i < 5; i++) {
          final double a = i * 1.2566;
          canvas.drawCircle(Offset(x + cos(a) * 4, y - 12 + sin(a) * 4), 2.6, _p);
        }
        _p.color = const Color(0xFFFFFFFF);
        canvas.drawCircle(Offset(x, y - 12), 2, _p);
        break;
      }
      case _kCrystal: {
        RealmDraw.glow(canvas, Offset(x, y - 8), 24, realmLighten(sc, 0.3), alpha: 0.12);
        _p.color = realmLighten(sc, 0.28);
        for (int i = -1; i <= 1; i++) {
          _path.reset();
          final double hgt = 14 + (i == 0 ? 10 : 0) + r * 4;
          _path.moveTo(x + i * 9 - 5, y);
          _path.lineTo(x + i * 9, y - hgt);
          _path.lineTo(x + i * 9 + 5, y);
          _path.close();
          canvas.drawPath(_path, _p);
        }
        _p.color = Colors.white.withValues(alpha: 0.55);
        canvas.drawCircle(Offset(x - 1, y - 18), 1.8, _p);
        break;
      }
      case _kReed: {
        _s.strokeWidth = 2.2;
        _s.color = realmDarken(sc, 0.02);
        for (int i = -1; i <= 1; i++) {
          canvas.drawLine(Offset(x + i * 5.0, y), Offset(x + i * 6.0, y - 18 - (i == 0 ? 6 : 0)), _s);
        }
        _p.color = const Color(0xFF6D4C41);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y - 25), width: 5, height: 10), _p);
        break;
      }
      case _kShroom: {
        RealmDraw.shadow(canvas, x, y + 3, 24);
        _p.color = const Color(0xFFF5F0E1);
        canvas.drawRect(Rect.fromLTWH(x - 3, y - 9, 6, 10), _p);
        _p.color = realmLighten(sc, 0.2);
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y - 9), width: 26, height: 20), pi, pi, true, _p);
        _p.color = Colors.white.withValues(alpha: 0.8);
        canvas.drawCircle(Offset(x - 5, y - 13), 2, _p);
        canvas.drawCircle(Offset(x + 4, y - 15), 1.6, _p);
        break;
      }
      default: {
        RealmDraw.shadow(canvas, x, y + 3, 28);
        _p.color = const Color(0xFF6D6D78);
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y - 6), width: 24, height: 17), _p);
        _p.color = const Color(0xFF8E8E9A);
        canvas.drawOval(Rect.fromCenter(center: Offset(x - 3, y - 9), width: 12, height: 8), _p);
        break;
      }
    }
  }

  // ---- creatures --------------------------------------------------------------

  /// Draws a creature with its feet at (x, y). Shapes: 0 blob, 1 horned, 2 winged, 3 spiked.
  static void drawCreature(Canvas canvas, int shape, Color col, double x, double y, double scale, double phase, double facing, int seed, double flash, bool elder) {
    final double fx = facing >= 0 ? 1.0 : -1.0;
    final Color dark = realmDarken(col, 0.2);
    final Color light = realmLighten(col, 0.16);
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale * fx, scale);
    RealmDraw.shadow(canvas, 0, 0, 32);
    if (elder) {
      RealmDraw.glow(canvas, const Offset(0, -18), 36 + 3 * sin(phase * 2), const Color(0xFFFFD54F), alpha: 0.22);
    }
    final double bob = sin(phase * 2) * 1.6;
    double eyeY = -18;
    switch (shape) {
      case 0: {
        final double sq = 1 + 0.07 * sin(phase * 2);
        _p.color = dark;
        canvas.drawCircle(const Offset(-9, -2), 4.5, _p);
        canvas.drawCircle(const Offset(9, -2), 4.5, _p);
        _p.color = col;
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -15 + bob), width: 36 / sq, height: 30 * sq), _p);
        _p.color = light;
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -10 + bob), width: 20, height: 14), _p);
        eyeY = -19 + bob;
        break;
      }
      case 1: {
        _p.color = dark;
        canvas.drawRect(Rect.fromLTWH(-9, -8, 6, 8), _p);
        canvas.drawRect(Rect.fromLTWH(3, -8, 6, 8), _p);
        const Color horn = Color(0xFFF5E6C8);
        _p.color = horn;
        _path.reset();
        _path.moveTo(-9, -26 + bob);
        _path.lineTo(-15, -42 + bob);
        _path.lineTo(-3, -29 + bob);
        _path.close();
        canvas.drawPath(_path, _p);
        _path.reset();
        _path.moveTo(9, -26 + bob);
        _path.lineTo(15, -42 + bob);
        _path.lineTo(3, -29 + bob);
        _path.close();
        canvas.drawPath(_path, _p);
        _p.color = col;
        canvas.drawCircle(Offset(0, -17 + bob), 15, _p);
        _p.color = light;
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -10 + bob), width: 18, height: 11), _p);
        eyeY = -20 + bob;
        break;
      }
      case 2: {
        final double flap = sin(phase * 5);
        final double lift = 6 + sin(phase * 2) * 2;
        _s.strokeWidth = 3;
        _s.color = dark;
        canvas.drawArc(Rect.fromLTWH(10, -20, 18, 18), -0.6, 2.2, false, _s);
        for (int side = -1; side <= 1; side += 2) {
          _path.reset();
          _path.moveTo(side * 8.0, -24 - lift);
          _path.quadraticBezierTo(side * 30.0, -44 - lift + flap * 10, side * 34.0, -26 - lift + flap * 14);
          _path.quadraticBezierTo(side * 22.0, -22 - lift, side * 10.0, -14 - lift);
          _path.close();
          _p.color = light;
          canvas.drawPath(_path, _p);
          _s.strokeWidth = 1.5;
          _s.color = dark;
          canvas.drawPath(_path, _s);
        }
        _p.color = col;
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -20 - lift + bob), width: 28, height: 26), _p);
        _p.color = light;
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -15 - lift + bob), width: 16, height: 12), _p);
        _p.color = dark;
        canvas.drawCircle(Offset(-5, -6 - lift * 0.4), 2.6, _p);
        canvas.drawCircle(Offset(5, -6 - lift * 0.4), 2.6, _p);
        eyeY = -24 - lift + bob;
        break;
      }
      default: {
        _p.color = dark;
        canvas.drawRect(Rect.fromLTWH(-9, -7, 6, 7), _p);
        canvas.drawRect(Rect.fromLTWH(3, -7, 6, 7), _p);
        for (int i = 0; i < 5; i++) {
          final double a = -2.75 + i * 0.58;
          _path.reset();
          _path.moveTo(cos(a - 0.28) * 12, -16 + bob + sin(a - 0.28) * 12);
          _path.lineTo(cos(a) * 22, -16 + bob + sin(a) * 22);
          _path.lineTo(cos(a + 0.28) * 12, -16 + bob + sin(a + 0.28) * 12);
          _path.close();
          _p.color = dark;
          canvas.drawPath(_path, _p);
        }
        _p.color = col;
        canvas.drawCircle(Offset(0, -16 + bob), 14, _p);
        _p.color = light;
        canvas.drawOval(Rect.fromCenter(center: Offset(0, -10 + bob), width: 17, height: 10), _p);
        eyeY = -18 + bob;
        break;
      }
    }
    // spots
    if (seed % 3 != 0) {
      _p.color = dark.withValues(alpha: 0.45);
      canvas.drawCircle(Offset(-6.0 + (seed % 5), eyeY + 12), 2.6, _p);
      canvas.drawCircle(Offset(7, eyeY + 9 - (seed % 3)), 2.0, _p);
    }
    // eyes
    _p.color = Colors.white;
    canvas.drawCircle(Offset(-5, eyeY), 4.2, _p);
    canvas.drawCircle(Offset(5, eyeY), 4.2, _p);
    _p.color = const Color(0xFF14101A);
    canvas.drawCircle(Offset(-3.6, eyeY + 0.5), 2.0, _p);
    canvas.drawCircle(Offset(6.4, eyeY + 0.5), 2.0, _p);
    if (shape == 3) {
      _s.strokeWidth = 2;
      _s.color = const Color(0xFF14101A);
      canvas.drawLine(Offset(-9, eyeY - 6), Offset(-2, eyeY - 3), _s);
      canvas.drawLine(Offset(9, eyeY - 6), Offset(2, eyeY - 3), _s);
    }
    if (seed % 4 == 0) {
      _p.color = Colors.white;
      canvas.drawCircle(Offset(0, eyeY - 7), 2.6, _p);
      _p.color = const Color(0xFF14101A);
      canvas.drawCircle(Offset(0.6, eyeY - 7), 1.2, _p);
    }
    if (flash > 0) {
      _p.color = Colors.white.withValues(alpha: _cl(flash * 1.6, 0, 0.75));
      canvas.drawCircle(const Offset(0, -16), 24, _p);
    }
    canvas.restore();
  }

  // ---- battle -----------------------------------------------------------------

  void _paintBattle(Canvas canvas, Size size, BiomeBattle b) {
    _p.color = Colors.black.withValues(alpha: 0.32);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _p);
    final double areaTop = 190;
    double areaBottom = size.height - 360;
    if (areaBottom < areaTop + 120) areaBottom = areaTop + 120;
    final double span = areaBottom - areaTop;
    final double s = _cl(span / 190, 0.9, 2.3);
    final Offset wildPos = Offset(size.width * 0.70, areaTop + span * 0.42);
    final Offset myPos = Offset(size.width * 0.28, areaTop + span * 0.86);
    final Color ground = realmLighten(_groundBase(g.content.subject(b.wild.subjectId).color), 0.06);
    _p.color = ground.withValues(alpha: 0.9);
    canvas.drawOval(Rect.fromCenter(center: wildPos + Offset(0, 6 * s), width: 120 * s, height: 34 * s), _p);
    canvas.drawOval(Rect.fromCenter(center: myPos + Offset(0, 6 * s), width: 120 * s, height: 34 * s), _p);

    double lw = 0;
    double lm = 0;
    if (b.lunge > 0) {
      final double p = 1 - b.lunge / 0.5;
      final double off = sin(p * pi) * 46;
      if (b.lungeWho == 1) lm = off;
      if (b.lungeWho == 2) lw = off;
    }
    final double t = g.time;
    // wild creature
    final double tp = b.tameT > 0 ? 1 - b.tameT / 1.6 : 1.0;
    bool hideWild = b.outcome == 2 && b.tameT <= 0;
    if (b.wild.hp <= 0 && b.wildFlash <= 0) hideWild = true;
    if (b.tameT > 0 && b.mode == 1 && tp >= 0.35 && (b.tameOk || tp < 0.75)) hideWild = true;
    if (!hideWild) {
      double ws = s * (b.wild.elder ? 1.3 : 1.0);
      if (b.tameT > 0 && b.mode == 1 && tp >= 0.25 && tp < 0.35) ws *= 1 - (tp - 0.25) / 0.1;
      if (b.tameT > 0 && b.mode == 1 && !b.tameOk && tp >= 0.75) ws *= _cl((tp - 0.75) / 0.1, 0.0, 1.0);
      drawCreature(canvas, b.wild.shape, b.wild.color, wildPos.dx - lw, wildPos.dy, ws, t * 2.2, -1, b.wild.seed, b.wildFlash, b.wild.elder);
    }
    // my creature
    final BiomeCreature me = g.active;
    drawCreature(canvas, me.shape, me.color, myPos.dx + lm, myPos.dy, s, t * 2.0, 1, me.seed, b.myFlash, false);
    // taming orb
    if (b.tameT > 0 && b.mode == 1) {
      Offset o;
      double wob = 0;
      if (tp < 0.25) {
        final double q = tp / 0.25;
        o = Offset(myPos.dx + (wildPos.dx - myPos.dx) * q, myPos.dy + (wildPos.dy - myPos.dy) * q - sin(q * pi) * 70 * s - 20 * s);
      } else {
        o = Offset(wildPos.dx, wildPos.dy - 10 * s);
        wob = sin(tp * 40) * 0.25;
      }
      if (tp < 0.75 || b.tameOk) {
        canvas.save();
        canvas.translate(o.dx, o.dy);
        canvas.rotate(wob);
        _p.color = const Color(0xFF7C4DFF);
        canvas.drawCircle(Offset.zero, 13 * s, _p);
        _p.color = Colors.white;
        canvas.drawRect(Rect.fromLTWH(-13 * s, -2 * s, 26 * s, 4 * s), _p);
        _p.color = Colors.white.withValues(alpha: 0.7);
        canvas.drawCircle(Offset(-5 * s, -8 * s), 3 * s, _p);
        canvas.restore();
        if (tp > 0.9 && b.tameOk) {
          RealmDraw.glow(canvas, o, 40 * s, const Color(0xFF69F0AE), alpha: 0.3);
        }
      }
    }
    // damage pop
    if (b.popT > 0) {
      final Offset base = b.popWho == 2 ? wildPos : myPos;
      final double rise = (1 - b.popT / 0.9) * 34;
      RealmDraw.text(canvas, b.popText, Offset(base.dx, base.dy - 70 * s - rise), 26, b.popWho == 2 ? const Color(0xFFFFF176) : const Color(0xFFFF8A80), maxWidth: 120);
    }
  }
}
