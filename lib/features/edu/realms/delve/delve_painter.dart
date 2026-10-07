import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'delve_logic.dart';

/// Draws Delve: the remembered cave, the torch-lit circle and a heavy darkness.
class DelvePainter extends CustomPainter {
  final DelveLogic g;
  final Paint _p = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  Color _tintBase = const Color(0xFF000000);
  Color _floorA = const Color(0xFF000000);
  Color _floorB = const Color(0xFF000000);
  int _tintDepth = -1;

  DelvePainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  static const Color _rockA = Color(0xFF2B2824);
  static const Color _rockB = Color(0xFF332F2A);
  static const Color _rockC = Color(0xFF26231F);
  static const Color _rockLip = Color(0xFF4A443B);

  double _cl(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
  }

  void _prepTint() {
    if (_tintDepth == g.depth) return;
    _tintDepth = g.depth;
    _tintBase = g.tint;
    // Always a readable stone tone of the subject's hue. Dark subject colours
    // used to make the floor pure black, so the torch lit nothing.
    final HSLColor hsl = HSLColor.fromColor(_tintBase);
    final double sat = _cl(hsl.saturation, 0.25, 0.5);
    _floorA = HSLColor.fromAHSL(1.0, hsl.hue, sat, 0.30).toColor();
    _floorB = HSLColor.fromAHSL(1.0, hsl.hue, sat, 0.25).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _prepTint();
    final double w = size.width;
    final double h = size.height;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _p..color = const Color(0xFF000000));
    final double worldW = g.n * DelveLogic.ts;
    final double camX = _cl(g.px - w / 2, 0, worldW > w ? worldW - w : 0);
    final double camY = _cl(g.py - h / 2, 0, worldW > h ? worldW - h : 0);
    canvas.save();
    canvas.translate(-camX, -camY);
    _drawTiles(canvas, camX, camY, w, h);
    _drawPickups(canvas);
    _drawShadowBodies(canvas);
    _drawPlayer(canvas);
    _drawSparks(canvas);
    _drawDarkness(canvas, camX, camY, w, h);
    _drawGlows(canvas);
    _drawEyes(canvas);
    canvas.restore();
    _drawHud(canvas, size);
  }

  void _drawTiles(Canvas canvas, double camX, double camY, double w, double h) {
    const double ts = DelveLogic.ts;
    final int n = g.n;
    int x0 = (camX / ts).floor();
    int y0 = (camY / ts).floor();
    int x1 = ((camX + w) / ts).floor();
    int y1 = ((camY + h) / ts).floor();
    if (x0 < 0) x0 = 0;
    if (y0 < 0) y0 = 0;
    if (x1 > n - 1) x1 = n - 1;
    if (y1 > n - 1) y1 = n - 1;
    for (int ty = y0; ty <= y1; ty++) {
      for (int tx = x0; tx <= x1; tx++) {
        final int idx = ty * n + tx;
        if (!g.seen[idx]) continue;
        final int t = g.grid[idx];
        final double l = tx * ts;
        final double tp = ty * ts;
        final int hsh = realmHash(tx, ty, 17);
        if (t == 0) {
          final int m = hsh % 3;
          _p.color = m == 0 ? _rockA : (m == 1 ? _rockB : _rockC);
          canvas.drawRect(Rect.fromLTWH(l, tp, ts + 0.5, ts + 0.5), _p);
          if (ty + 1 < n && g.grid[idx + n] != 0) {
            _p.color = _rockLip;
            canvas.drawRect(Rect.fromLTWH(l, tp + ts - 9, ts + 0.5, 9), _p);
          }
          if (hsh % 5 == 0) {
            _p.color = const Color(0x22000000);
            canvas.drawCircle(Offset(l + 10 + (hsh % 31).toDouble(), tp + 12 + (hsh % 23).toDouble()), 8, _p);
          }
        } else {
          _p.color = ((tx + ty) % 2 == 0) ? _floorA : _floorB;
          canvas.drawRect(Rect.fromLTWH(l, tp, ts + 0.5, ts + 0.5), _p);
          if (hsh % 4 == 0) {
            _p.color = const Color(0x18FFFFFF);
            canvas.drawCircle(Offset(l + 8 + (hsh % 40).toDouble(), tp + 8 + ((hsh >> 6) % 40).toDouble()), 2.2, _p);
          }
          if (t == 2 || t == 3) {
            _drawDoor(canvas, tx, ty);
          }
        }
      }
    }
    // Stairs
    final int sIdx = g.stairsIndex;
    if (g.seen[sIdx]) {
      final double sx = (sIdx % n) * ts;
      final double sy = (sIdx ~/ n) * ts;
      for (int i = 0; i < 5; i++) {
        _p.color = Color.lerp(const Color(0xFF8FA8B0), const Color(0xFF0A1418), i / 4.0) ?? const Color(0xFF000000);
        final double inset = 4.0 + i * 5.0;
        canvas.drawRect(Rect.fromLTWH(sx + inset, sy + inset, ts - inset * 2, ts - inset * 2), _p);
      }
    }
  }

  void _drawDoor(Canvas canvas, int tx, int ty) {
    const double ts = DelveLogic.ts;
    DelveDoor? door;
    for (final DelveDoor d in g.doors) {
      if (d.tx == tx && d.ty == ty) door = d;
    }
    if (door == null) return;
    final double l = tx * ts;
    final double tp = ty * ts;
    final double oa = door.openAnim;
    final bool horiz = g.solidAt(tx, ty - 1);
    final Color rune = realmLighten(g.content.subject(door.subjectId).color, 0.25);
    if (oa < 1) {
      final double k = 1 - oa;
      _p.color = const Color(0xFF5A5148);
      if (horiz) {
        canvas.drawRect(Rect.fromLTWH(l, tp + 4, ts * 0.5 * k + 6, ts - 8), _p);
        canvas.drawRect(Rect.fromLTWH(l + ts - ts * 0.5 * k - 6, tp + 4, ts * 0.5 * k + 6, ts - 8), _p);
      } else {
        canvas.drawRect(Rect.fromLTWH(l + 4, tp, ts - 8, ts * 0.5 * k + 6), _p);
        canvas.drawRect(Rect.fromLTWH(l + 4, tp + ts - ts * 0.5 * k - 6, ts - 8, ts * 0.5 * k + 6), _p);
      }
      if (!door.open) {
        _stroke.strokeWidth = 2.5;
        _stroke.color = rune.withValues(alpha: 0.9);
        canvas.drawCircle(Offset(l + ts / 2, tp + ts / 2), 13, _stroke);
        canvas.drawLine(Offset(l + ts / 2 - 7, tp + ts / 2 + 6), Offset(l + ts / 2, tp + ts / 2 - 8), _stroke);
        canvas.drawLine(Offset(l + ts / 2, tp + ts / 2 - 8), Offset(l + ts / 2 + 7, tp + ts / 2 + 6), _stroke);
        canvas.drawLine(Offset(l + ts / 2 - 5, tp + ts / 2 + 1), Offset(l + ts / 2 + 5, tp + ts / 2 + 1), _stroke);
      }
    }
  }

  void _drawPickups(Canvas canvas) {
    final double rad = g.lightRadius + 20;
    final double t = g.time;
    for (int i = 0; i < g.pickups.length; i++) {
      final DelvePickup p = g.pickups[i];
      if (p.taken) continue;
      final double dx = p.x - g.px;
      final double dy = p.y - g.py;
      if (dx * dx + dy * dy > rad * rad) continue;
      final double bob = sin(t * 3 + i) * 2;
      if (p.kind == 0) {
        RealmDraw.shadow(canvas, p.x, p.y + 8, 14);
        _p.color = const Color(0xFFFFB300);
        canvas.drawCircle(Offset(p.x, p.y + bob), 7.5, _p);
        _p.color = const Color(0xFFFFE082);
        canvas.drawCircle(Offset(p.x - 1.5, p.y + bob - 1.5), 4.2, _p);
      } else if (p.kind == 1) {
        RealmDraw.glow(canvas, Offset(p.x, p.y), 22, const Color(0xFFFF9800), alpha: 0.22);
        _p.color = const Color(0xFFB0BEC5);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.x - 3.5, p.y - 14 + bob, 7, 7), const Radius.circular(2)), _p);
        _p.color = const Color(0xFFFF9800);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.x - 8, p.y - 8 + bob, 16, 18), const Radius.circular(6)), _p);
        _p.color = const Color(0xFFFFE0B2);
        canvas.drawRect(Rect.fromLTWH(p.x - 5, p.y - 4 + bob, 3, 8), _p);
      } else if (p.kind == 2) {
        RealmDraw.shadow(canvas, p.x, p.y + 12, 30);
        _p.color = const Color(0xFF6D4C41);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.x - 14, p.y - 8, 28, 20), const Radius.circular(4)), _p);
        _p.color = const Color(0xFF8D6E63);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.x - 14, p.y - 12, 28, 9), const Radius.circular(5)), _p);
        _p.color = const Color(0xFFFFCA28);
        canvas.drawRect(Rect.fromLTWH(p.x - 3, p.y - 12, 6, 24), _p);
        canvas.drawCircle(Offset(p.x, p.y + 1), 2.6, _p);
      } else {
        RealmDraw.glow(canvas, Offset(p.x, p.y), 22, const Color(0xFFFF5252), alpha: 0.22);
        _p.color = const Color(0xFFFF5252);
        canvas.drawCircle(Offset(p.x - 5, p.y - 3 + bob), 6, _p);
        canvas.drawCircle(Offset(p.x + 5, p.y - 3 + bob), 6, _p);
        final Path tri = Path()
          ..moveTo(p.x - 10.5, p.y - 0.5 + bob)
          ..lineTo(p.x + 10.5, p.y - 0.5 + bob)
          ..lineTo(p.x, p.y + 12 + bob)
          ..close();
        canvas.drawPath(tri, _p);
      }
    }
  }

  void _drawShadowBodies(Canvas canvas) {
    final double rad = g.lightRadius + 40;
    for (final DelveShadow s in g.shadows) {
      final double dx = s.x - g.px;
      final double dy = s.y - g.py;
      if (dx * dx + dy * dy > rad * rad) continue;
      for (int k = 3; k >= 1; k--) {
        final double off = k * 7.0;
        _p.color = const Color(0xFF3B2A63).withValues(alpha: 0.5 - k * 0.1);
        canvas.drawCircle(Offset(s.x + sin(s.phase + k) * 4, s.y + 6 + off * 0.6), 13.0 - k * 2.5, _p);
      }
      _p.color = const Color(0xFF1B1030);
      canvas.drawCircle(Offset(s.x, s.y), 15 + sin(s.phase * 1.3) * 1.5, _p);
      _stroke.strokeWidth = 2;
      _stroke.color = const Color(0xFF7E57C2).withValues(alpha: 0.6);
      canvas.drawCircle(Offset(s.x, s.y), 15, _stroke);
    }
  }

  void _drawEyes(Canvas canvas) {
    for (final DelveShadow s in g.shadows) {
      final double dx = s.x - g.px;
      final double dy = s.y - g.py;
      if (dx * dx + dy * dy > 330 * 330) continue;
      _p.color = const Color(0xFFFF5252);
      canvas.drawCircle(Offset(s.x - 5, s.y - 2), 2.6, _p);
      canvas.drawCircle(Offset(s.x + 5, s.y - 2), 2.6, _p);
    }
  }

  void _drawPlayer(Canvas canvas) {
    final bool blink = g.invuln > 0 && ((g.time * 12).floor() % 2 == 0);
    if (!blink) {
      RealmDraw.person(canvas, g.px, g.py - 6, phase: g.walk, moving: g.moving, facing: g.facing);
    }
    final double fx = g.facing >= 0 ? 1.0 : -1.0;
    final double flick = 1 + sin(g.time * 17) * 0.06 + sin(g.time * 7.3) * 0.05;
    final Offset hand = Offset(g.px + 12 * fx, g.py - 4);
    RealmDraw.glow(canvas, hand, 11 * flick, const Color(0xFFFFB347), alpha: 0.5);
    _p.color = const Color(0xFFFFF3C4);
    canvas.drawCircle(hand, 4.2, _p);
  }

  void _drawSparks(Canvas canvas) {
    for (final DelveSpark s in g.sparks) {
      final double a = _cl(s.life / s.maxLife, 0, 1);
      _p.color = s.color.withValues(alpha: a);
      canvas.drawCircle(Offset(s.x, s.y), 2.6 * a + 0.6, _p);
    }
  }

  void _drawDarkness(Canvas canvas, double camX, double camY, double w, double h) {
    final double flick = 1 + sin(g.time * 13) * 0.025 + sin(g.time * 5.1) * 0.02;
    final double r = g.lightRadius * flick;
    final Rect view = Rect.fromLTWH(camX - 2, camY - 2, w + 4, h + 4);
    final Rect disc = Rect.fromCircle(center: Offset(g.px, g.py - 4), radius: r);
    _p.shader = RadialGradient(
      colors: const <Color>[Color(0x1AFFB347), Color(0x00000000), Color(0x55000000), Color(0xEB000000)],
      stops: const <double>[0.0, 0.22, 0.62, 1.0],
    ).createShader(disc);
    canvas.drawRect(view, _p);
    _p.shader = null;
  }

  /// Runes and stairs glow faintly through the dark once they have been seen.
  void _drawGlows(Canvas canvas) {
    const double ts = DelveLogic.ts;
    final int n = g.n;
    final double pulse = 0.5 + 0.5 * sin(g.time * 2.4);
    for (final DelveDoor d in g.doors) {
      if (d.open || !g.seen[d.ty * n + d.tx]) continue;
      final Color c = realmLighten(g.content.subject(d.subjectId).color, 0.25);
      RealmDraw.glow(canvas, Offset(d.tx * ts + ts / 2, d.ty * ts + ts / 2), 26 + pulse * 6, c, alpha: 0.18 + pulse * 0.08);
    }
    if (g.seen[g.stairsIndex]) {
      final double sx = (g.stairsIndex % n) * ts + ts / 2;
      final double sy = (g.stairsIndex ~/ n) * ts + ts / 2;
      RealmDraw.glow(canvas, Offset(sx, sy), 30 + pulse * 6, const Color(0xFF80DEEA), alpha: 0.2 + pulse * 0.08);
    }
  }

  void _drawHud(Canvas canvas, Size size) {
    if (g.hurtT > 0) {
      final double a = _cl(g.hurtT / 0.6, 0, 1) * 0.35;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _p..color = Colors.red.withValues(alpha: a));
    }
    if (g.toastT > 0 && !g.modal) {
      RealmDraw.label(canvas, g.toast, Offset(size.width / 2, 104), size: 13, maxWidth: size.width - 70);
    }
  }

  @override
  bool shouldRepaint(covariant DelvePainter oldDelegate) => true;
}
