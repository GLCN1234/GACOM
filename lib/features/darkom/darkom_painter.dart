import '../character3d/fighter3d.dart';
import '../character3d/rig.dart' show CharLook;
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../edu/realms/realm_kit.dart';
import 'darkom_combat.dart';
import 'darkom_entities.dart';
import 'darkom_logic.dart';
import 'darkom_story.dart';
import 'darkom_world.dart';

class _Item {
  final double y;
  final int kind; // 0 enemy, 1 courier, 2 hero
  final Object? ref;
  _Item(this.y, this.kind, this.ref);
}

const Color _cyan = Color(0xFF00E5FF);
const Color _red = Color(0xFFFF3D3D);

/// Draws Darkom City with plain canvas shapes: no images.
class DarkomPainter extends CustomPainter {
  final DarkomLogic g;
  DarkomPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();
  final Paint _s = Paint()..style = PaintingStyle.stroke;
  final Map<String, TextPainter> _tp = <String, TextPainter>{};
  double _t = 0;
  Rect _view = Rect.zero;

  static const List<Color> _boxes = <Color>[Color(0xFFB5502B), Color(0xFF2F6B8A), Color(0xFF4F7F3A), Color(0xFFC9A227)];

  @override
  bool shouldRepaint(covariant DarkomPainter old) => true;

  void _text(Canvas c, String s, Offset center, double size, Color color, {double maxW = 220}) {
    final String key = '$s|${size.toStringAsFixed(0)}|${color.value}';
    TextPainter? tp = _tp[key];
    if (tp == null) {
      if (_tp.length > 90) _tp.clear();
      tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani', height: 1.0, shadows: const <Shadow>[Shadow(color: Color(0xDD000000), blurRadius: 3, offset: Offset(0, 1))])),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: maxW);
      _tp[key] = tp;
    }
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    _t = g.time;
    Fighter3D.begin(shared: 8);
    final DarkomTheme th = g.theme;
    final DarkomWorld w = g.world;
    canvas.drawRect(Offset.zero & size, _p..color = const Color(0xFF05060A));
    final double zoom = (size.shortestSide / 470).clamp(0.7, 1.55).toDouble();
    final double hw = size.width / (2 * zoom);
    final double hh = size.height / (2 * zoom);
    double cx = g.camX;
    double cy = g.camY;
    if (DarkomWorld.width > hw * 2) {
      cx = cx < hw ? hw : (cx > DarkomWorld.width - hw ? DarkomWorld.width - hw : cx);
    } else {
      cx = DarkomWorld.width / 2;
    }
    if (DarkomWorld.height > hh * 2) {
      cy = cy < hh ? hh : (cy > DarkomWorld.height - hh ? DarkomWorld.height - hh : cy);
    } else {
      cy = DarkomWorld.height / 2;
    }
    double shx = 0;
    double shy = 0;
    if (g.shakeOn && g.shake > 0) {
      shx = (realmUnit((_t * 60).floor(), 1, 7) - 0.5) * g.shake;
      shy = (realmUnit((_t * 60).floor(), 2, 9) - 0.5) * g.shake;
    }
    canvas.save();
    canvas.translate(size.width / 2 + shx, size.height / 2 + shy);
    canvas.scale(zoom, zoom);
    canvas.translate(-cx, -cy);
    _view = Rect.fromLTWH(cx - hw - 40, cy - hh - 40, hw * 2 + 80, hh * 2 + 80);

    _drawGround(canvas, th, w);
    _drawBlocks(canvas, th, w);
    _drawArena(canvas, th, w);
    _drawMarkers(canvas, th);
    for (final DEnemy e in g.enemies) {
      if (e.alive && _view.contains(Offset(e.x, e.y))) _drawTele(canvas, e);
    }
    for (final DPick pk in g.picks) {
      _drawPick(canvas, pk);
    }
    final List<_Item> items = <_Item>[];
    for (final DEnemy e in g.enemies) {
      if (e.alive && _view.contains(Offset(e.x, e.y))) items.add(_Item(e.y, 0, e));
    }
    final DCourier? cr = g.courier;
    if (cr != null) items.add(_Item(cr.y, 1, cr));
    if (!g.heroDead) items.add(_Item(g.hy, 2, null));
    items.sort((_Item a, _Item b) => a.y.compareTo(b.y));
    for (final _Item it in items) {
      if (it.kind == 0) {
        _drawEnemy(canvas, it.ref as DEnemy);
      } else if (it.kind == 1) {
        _drawCourier(canvas, it.ref as DCourier);
      } else {
        _drawHero(canvas);
      }
    }
    for (final DAxe a in g.axes) {
      _drawAxe(canvas, a);
    }
    for (final DProj p in g.projs) {
      _drawProj(canvas, p);
    }
    _drawFx(canvas);
    _drawParticles(canvas);
    for (final DText t in g.texts) {
      final double a = (t.life / t.maxLife).clamp(0.0, 1.0).toDouble();
      _text(canvas, t.text, Offset(t.x, t.y), t.size, t.color.withValues(alpha: a));
    }
    canvas.restore();
    _drawOverlay(canvas, size);
  }

  // ---- ground and blocks --------------------------------------------------

  void _drawGround(Canvas c, DarkomTheme th, DarkomWorld w) {
    const double W = DarkomWorld.width;
    const double H = DarkomWorld.height;
    const double T = 60;
    c.drawRect(const Rect.fromLTWH(-200, -200, W + 400, H + 400), _p..color = const Color(0xFF080910));
    c.drawRect(const Rect.fromLTWH(T, T, W - 2 * T, H - 2 * T), _p..color = th.ground);
    // faint tile grid
    _s
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.025);
    final int gx0 = max(1, (_view.left / T).floor());
    final int gx1 = min(DarkomWorld.cols - 1, (_view.right / T).ceil());
    final int gy0 = max(1, (_view.top / T).floor());
    final int gy1 = min(DarkomWorld.rows - 1, (_view.bottom / T).ceil());
    for (int x = gx0; x <= gx1; x++) {
      c.drawLine(Offset(x * T, T), Offset(x * T, H - T), _s);
    }
    for (int y = gy0; y <= gy1; y++) {
      c.drawLine(Offset(T, y * T), Offset(W - T, y * T), _s);
    }
    // roads
    final double roadBottom = w.waterRow > 0 ? w.waterRow * T : H - T;
    for (final List<int> r in w.vRoads) {
      final Rect rr = Rect.fromLTRB(r[0] * T, T, (r[1] + 1) * T, roadBottom);
      if (rr.overlaps(_view)) c.drawRect(rr, _p..color = th.road);
    }
    for (final List<int> r in w.hRoads) {
      final Rect rr = Rect.fromLTRB(T, r[0] * T, W - T, (r[1] + 1) * T);
      if (rr.overlaps(_view)) c.drawRect(rr, _p..color = th.road);
    }
    // lane dashes
    _p.color = th.roadLine.withValues(alpha: 0.55);
    for (final List<int> r in w.vRoads) {
      final double x = (r[0] + r[1] + 1) * T / 2;
      if (x < _view.left - 10 || x > _view.right + 10) continue;
      double y = max(T, (_view.top / 56).floor() * 56.0);
      for (; y < min(roadBottom, _view.bottom); y += 56) {
        c.drawRect(Rect.fromLTWH(x - 1.5, y, 3, 26), _p);
      }
    }
    for (final List<int> r in w.hRoads) {
      final double y = (r[0] + r[1] + 1) * T / 2;
      if (y < _view.top - 10 || y > _view.bottom + 10) continue;
      double x = max(T, (_view.left / 56).floor() * 56.0);
      for (; x < min(W - T, _view.right); x += 56) {
        c.drawRect(Rect.fromLTWH(x, y - 1.5, 26, 3), _p);
      }
    }
    // water and piers
    if (w.waterRow > 0) {
      final Rect wr = Rect.fromLTRB(T, w.waterRow * T, W - T, H - T);
      c.drawRect(wr, _p..color = th.water);
      _s
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.07);
      for (double y = w.waterRow * T + 14; y < H - T; y += 26) {
        if (y < _view.top || y > _view.bottom) continue;
        for (double x = T + ((y / 26).floor() % 2) * 35; x < W - T; x += 70) {
          if (x < _view.left - 40 || x > _view.right) continue;
          final double sx = sin(_t * 1.6 + x * 0.05 + y * 0.03) * 6;
          c.drawLine(Offset(x + sx, y), Offset(x + sx + 24, y), _s);
        }
      }
      for (int ty = w.waterRow; ty < DarkomWorld.rows - 1; ty++) {
        for (int tx = 1; tx < DarkomWorld.cols - 1; tx++) {
          if (w.cellAt(tx, ty) != 0) continue;
          final Rect pr = Rect.fromLTWH(tx * T, ty * T, T, T);
          if (!pr.overlaps(_view)) continue;
          c.drawRect(pr, _p..color = const Color(0xFF3A2D22));
          _s
            ..strokeWidth = 1.5
            ..color = const Color(0xFF241B14);
          c.drawLine(Offset(pr.left, pr.top + 20), Offset(pr.right, pr.top + 20), _s);
          c.drawLine(Offset(pr.left, pr.top + 40), Offset(pr.right, pr.top + 40), _s);
        }
      }
    }
    // neon edge along the outer wall
    _s
      ..strokeWidth = 3
      ..color = th.neonA.withValues(alpha: 0.5);
    c.drawRect(const Rect.fromLTWH(T, T, W - 2 * T, H - 2 * T), _s);
  }

  void _drawBlocks(Canvas c, DarkomTheme th, DarkomWorld w) {
    const double T = 60;
    for (final DBlock b in w.blocks) {
      final Rect r = Rect.fromLTWH(b.tx * T, b.ty * T, b.tw * T, b.th * T);
      if (!r.overlaps(_view)) continue;
      switch (b.style) {
        case 0:
          _drawBuilding(c, th, b, r);
          break;
        case 1:
          _drawCrate(c, th, b, r);
          break;
        case 2:
          _drawRack(c, th, b, r);
          break;
        case 3:
          _drawPillar(c, th, r);
          break;
        default:
          _drawMonument(c, th, r);
          break;
      }
    }
  }

  void _drawBuilding(Canvas c, DarkomTheme th, DBlock b, Rect r) {
    c.drawRect(r.shift(const Offset(9, 12)), _p..color = Colors.black.withValues(alpha: 0.38));
    final Color base = Color.lerp(th.roof, Colors.white, (b.seed % 5) * 0.012) ?? th.roof;
    final RRect rr = RRect.fromRectAndRadius(r.deflate(1.5), const Radius.circular(6));
    c.drawRRect(rr, _p..color = base);
    c.drawRRect(RRect.fromRectAndRadius(r.deflate(9), const Radius.circular(4)), _p..color = Colors.black.withValues(alpha: 0.18));
    _s
      ..strokeWidth = 3
      ..color = th.roofEdge;
    c.drawRRect(rr, _s);
    final int n = 2 + b.seed % 3;
    for (int i = 0; i < n; i++) {
      final double ux = realmUnit(b.seed, i, 1);
      final double uy = realmUnit(b.seed, i, 2);
      final double bx = r.left + 18 + ux * max(1.0, r.width - 56);
      final double by = r.top + 18 + uy * max(1.0, r.height - 50);
      c.drawRect(Rect.fromLTWH(bx, by, 22, 16), _p..color = realmDarken(th.roofEdge, 0.12));
      c.drawCircle(Offset(bx + 11, by + 8), 5, _p..color = Colors.black.withValues(alpha: 0.4));
    }
    // a lit window strip along one edge
    if (b.seed % 3 == 0) {
      _p.color = th.neonB.withValues(alpha: 0.10 + 0.05 * sin(_t * 2 + b.seed));
      c.drawRect(Rect.fromLTWH(r.left + 12, r.bottom - 14, r.width - 24, 4), _p);
    }
    if (b.sign >= 0) {
      final Color nc = b.colorIdx == 0 ? th.neonA : th.neonB;
      final double fl = 0.8 + 0.2 * sin(_t * 5 + b.seed);
      Rect strip;
      Rect glow;
      switch (b.sign) {
        case 0:
          strip = Rect.fromLTWH(r.left + 10, r.top + 2, r.width - 20, 5);
          glow = Rect.fromLTWH(r.left + 4, r.top - 14, r.width - 8, 16);
          break;
        case 1:
          strip = Rect.fromLTWH(r.right - 7, r.top + 10, 5, r.height - 20);
          glow = Rect.fromLTWH(r.right - 2, r.top + 4, 16, r.height - 8);
          break;
        case 2:
          strip = Rect.fromLTWH(r.left + 10, r.bottom - 7, r.width - 20, 5);
          glow = Rect.fromLTWH(r.left + 4, r.bottom - 2, r.width - 8, 16);
          break;
        default:
          strip = Rect.fromLTWH(r.left + 2, r.top + 10, 5, r.height - 20);
          glow = Rect.fromLTWH(r.left - 14, r.top + 4, 16, r.height - 8);
          break;
      }
      c.drawRRect(RRect.fromRectAndRadius(glow, const Radius.circular(8)), _p..color = nc.withValues(alpha: 0.13 * fl));
      c.drawRRect(RRect.fromRectAndRadius(strip, const Radius.circular(3)), _p..color = nc.withValues(alpha: 0.95 * fl));
    }
  }

  void _drawCrate(Canvas c, DarkomTheme th, DBlock b, Rect r) {
    final bool rusty = th.key == 'rustyard' || th.key == 'docks';
    final Color col = Color.lerp(th.cover, _boxes[b.seed % 4], rusty ? 0.85 : 0.25) ?? th.cover;
    final Rect rr = r.deflate(4);
    c.drawRect(rr.shift(const Offset(6, 8)), _p..color = Colors.black.withValues(alpha: 0.35));
    c.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(3)), _p..color = col);
    _s
      ..strokeWidth = 2
      ..color = Colors.black.withValues(alpha: 0.4);
    if (b.tw * b.th == 1) {
      c.drawLine(rr.topLeft, rr.bottomRight, _s);
      c.drawLine(rr.topRight, rr.bottomLeft, _s);
    } else if (b.tw >= b.th) {
      for (double x = rr.left + 10; x < rr.right - 4; x += 12) {
        c.drawLine(Offset(x, rr.top + 2), Offset(x, rr.bottom - 2), _s);
      }
    } else {
      for (double y = rr.top + 10; y < rr.bottom - 4; y += 12) {
        c.drawLine(Offset(rr.left + 2, y), Offset(rr.right - 2, y), _s);
      }
    }
    _s
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.18);
    c.drawRRect(RRect.fromRectAndRadius(rr, const Radius.circular(3)), _s);
  }

  void _drawRack(Canvas c, DarkomTheme th, DBlock b, Rect r) {
    final Rect rr = r.deflate(3);
    c.drawRect(rr.shift(const Offset(5, 7)), _p..color = Colors.black.withValues(alpha: 0.35));
    c.drawRect(rr, _p..color = realmDarken(th.roof, 0.04));
    _s
      ..strokeWidth = 2
      ..color = th.roofEdge;
    c.drawRect(rr, _s);
    final bool horiz = b.tw >= b.th;
    final int count = (horiz ? rr.width : rr.height) ~/ 20;
    for (int i = 0; i < count; i++) {
      final bool on = ((_t * 1.7 + i * 0.73 + b.seed) % 2.0) < 1.3;
      final bool alt = (i + b.seed) % 5 == 0;
      final Color lc = alt ? th.neonB : th.neonA;
      _p.color = lc.withValues(alpha: on ? 0.9 : 0.25);
      if (horiz) {
        c.drawCircle(Offset(rr.left + 12 + i * 20.0, rr.center.dy), 2.6, _p);
      } else {
        c.drawCircle(Offset(rr.center.dx, rr.top + 12 + i * 20.0), 2.6, _p);
      }
    }
  }

  void _drawPillar(Canvas c, DarkomTheme th, Rect r) {
    final Offset ctr = r.center;
    c.drawCircle(ctr + const Offset(4, 6), 22, _p..color = Colors.black.withValues(alpha: 0.35));
    c.drawCircle(ctr, 22, _p..color = realmLighten(th.roof, 0.04));
    _s
      ..strokeWidth = 3
      ..color = th.neonA.withValues(alpha: 0.85);
    c.drawCircle(ctr, 20, _s);
    c.drawCircle(ctr, 8, _p..color = th.neonA.withValues(alpha: 0.35 + 0.2 * sin(_t * 3 + ctr.dx)));
  }

  void _drawMonument(Canvas c, DarkomTheme th, Rect r) {
    final Offset ctr = r.center;
    c.drawCircle(ctr + const Offset(5, 8), 54, _p..color = Colors.black.withValues(alpha: 0.35));
    c.drawCircle(ctr, 54, _p..color = th.roof);
    _s
      ..strokeWidth = 4
      ..color = th.neonA.withValues(alpha: 0.9);
    c.drawCircle(ctr, 48, _s);
    _s
      ..strokeWidth = 2
      ..color = th.neonB.withValues(alpha: 0.8);
    c.drawCircle(ctr, 30, _s);
    c.drawCircle(ctr, 14, _p..color = th.neonB.withValues(alpha: 0.4 + 0.25 * sin(_t * 2)));
  }

  void _drawArena(Canvas c, DarkomTheme th, DarkomWorld w) {
    final Rect ar = w.arenaRect.inflate(-4);
    if (!ar.overlaps(_view)) return;
    final bool hot = g.phase == 1 || g.phase == 2;
    final double pulse = 0.5 + 0.5 * sin(_t * 3);
    _s
      ..strokeWidth = 3
      ..color = _cyan.withValues(alpha: hot ? 0.35 + 0.35 * pulse : 0.18);
    // dashed rectangle
    const double dash = 24;
    for (double x = ar.left; x < ar.right; x += dash * 2) {
      c.drawLine(Offset(x, ar.top), Offset(min(x + dash, ar.right), ar.top), _s);
      c.drawLine(Offset(x, ar.bottom), Offset(min(x + dash, ar.right), ar.bottom), _s);
    }
    for (double y = ar.top; y < ar.bottom; y += dash * 2) {
      c.drawLine(Offset(ar.left, y), Offset(ar.left, min(y + dash, ar.bottom)), _s);
      c.drawLine(Offset(ar.right, y), Offset(ar.right, min(y + dash, ar.bottom)), _s);
    }
    _s
      ..strokeWidth = 2
      ..color = _cyan.withValues(alpha: hot ? 0.45 : 0.2);
    c.drawCircle(w.arena, 70, _s);
    c.drawCircle(w.arena, 36, _s);
    if (g.phase == 1) {
      c.drawCircle(w.arena, w.arenaRadius, _p..color = _cyan.withValues(alpha: 0.05 + 0.05 * pulse));
      _s
        ..strokeWidth = 3
        ..color = _cyan.withValues(alpha: 0.4 + 0.3 * pulse);
      c.drawCircle(w.arena, w.arenaRadius, _s);
    }
    _text(c, 'ECHO ARENA', w.arena + const Offset(0, -96), 13, _cyan.withValues(alpha: 0.8));
  }

  // ---- objective markers --------------------------------------------------

  void _drawFlag(Canvas c, Offset p, String label, Color col) {
    final double pulse = 0.5 + 0.5 * sin(_t * 3);
    c.drawCircle(p, 70, _p..color = col.withValues(alpha: 0.06 + 0.05 * pulse));
    _s
      ..strokeWidth = 2.5
      ..color = col.withValues(alpha: 0.5 + 0.3 * pulse);
    c.drawCircle(p, 70, _s);
    _s
      ..strokeWidth = 3
      ..color = col;
    c.drawLine(p + const Offset(0, 6), p + const Offset(0, -46), _s);
    final Path flag = Path()
      ..moveTo(p.dx, p.dy - 46)
      ..lineTo(p.dx + 28, p.dy - 37)
      ..lineTo(p.dx, p.dy - 28)
      ..close();
    c.drawPath(flag, _p..color = col);
    _text(c, label, p + const Offset(0, 24), 13, col);
  }

  void _drawMarkers(Canvas c, DarkomTheme th) {
    final double pulse = 0.5 + 0.5 * sin(_t * 4);
    final Offset? shard = g.shard;
    if (shard != null && _view.contains(shard)) {
      c.drawRect(Rect.fromLTWH(shard.dx - 3, shard.dy - 150, 6, 150), _p..color = _cyan.withValues(alpha: 0.22));
      c.drawCircle(shard, 46, _p..color = _cyan.withValues(alpha: 0.10 + 0.08 * pulse));
      c.save();
      c.translate(shard.dx, shard.dy - 10 - 4 * pulse);
      final double s = 1.0 + 0.1 * pulse;
      c.scale(s, s);
      final Path d = Path()
        ..moveTo(0, -18)
        ..lineTo(12, 0)
        ..lineTo(0, 18)
        ..lineTo(-12, 0)
        ..close();
      c.drawPath(d, _p..color = _cyan);
      c.drawPath(d, _s..strokeWidth = 2..color = Colors.white);
      c.restore();
      _text(c, 'MEMORY SHARD', shard + const Offset(0, 36), 12, _cyan);
    }
    for (final Offset chip in g.chipPts) {
      if (!_view.contains(chip)) continue;
      c.drawCircle(chip, 30, _p..color = _cyan.withValues(alpha: 0.08 + 0.08 * pulse));
      c.save();
      c.translate(chip.dx, chip.dy - 6 - 3 * pulse);
      final Rect r = Rect.fromCenter(center: Offset.zero, width: 22, height: 22);
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _p..color = const Color(0xFF0B2A33));
      c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), _s..strokeWidth = 2..color = _cyan);
      c.drawRect(Rect.fromCenter(center: Offset.zero, width: 8, height: 8), _p..color = _cyan);
      c.restore();
    }
    if (g.phase == 0 && g.cKind == 'recover' && g.carrying) {
      _drawFlag(c, g.extractPos, 'EXTRACTION', const Color(0xFF69F0AE));
    }
    if (g.phase == 3) {
      _drawFlag(c, g.extractPos, 'EXTRACTION', const Color(0xFF69F0AE));
    }
    final Offset? gate = g.gate;
    if (gate != null) _drawFlag(c, gate, g.ch.gateName.toUpperCase(), const Color(0xFFFFD54F));
    final Offset? zone = g.zone;
    if (zone != null) {
      final bool inside = (zone - g.heroPos).distance < darkomZoneRadius;
      final Color zc = inside ? const Color(0xFF69F0AE) : const Color(0xFFFFD54F);
      c.drawCircle(zone, darkomZoneRadius, _p..color = zc.withValues(alpha: 0.07 + 0.04 * pulse));
      _s
        ..strokeWidth = 3
        ..color = zc.withValues(alpha: 0.7);
      for (int i = 0; i < 16; i++) {
        final double a0 = i * pi / 8 + _t * 0.3;
        c.drawArc(Rect.fromCircle(center: zone, radius: darkomZoneRadius), a0, pi / 16, false, _s);
      }
      if (g.cTarget > 0) {
        final double f = (g.cTimer / g.cTarget).clamp(0.0, 1.0).toDouble();
        _s
          ..strokeWidth = 6
          ..color = zc;
        c.drawArc(Rect.fromCircle(center: zone, radius: darkomZoneRadius - 12), -pi / 2, 2 * pi * f, false, _s);
      }
      _text(c, 'HOLD THE ZONE', zone + const Offset(0, -darkomZoneRadius - 14), 13, zc);
    }
  }

  // ---- telegraphs ---------------------------------------------------------

  void _drawTele(Canvas c, DEnemy e) {
    if (e.tele <= 0 || e.tShape == 0) return;
    final double p = (1 - e.tele / (e.teleMax <= 0 ? 1.0 : e.teleMax)).clamp(0.0, 1.0).toDouble();
    final Color col = e.type == 'echo' ? _cyan : (e.atk == 4 ? const Color(0xFF80DEEA) : _red);
    final Paint fill = Paint()..color = col.withValues(alpha: 0.10 + 0.22 * p);
    final Paint hot = Paint()..color = col.withValues(alpha: 0.22 + 0.3 * p);
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = col.withValues(alpha: 0.55 + 0.4 * p);
    switch (e.tShape) {
      case 1:
        c.drawCircle(Offset(e.x, e.y), e.tR, fill);
        c.drawCircle(Offset(e.x, e.y), e.tR * p, hot);
        c.drawCircle(Offset(e.x, e.y), e.tR, line);
        break;
      case 2:
        c.drawCircle(Offset(e.ax, e.ay), e.tR, fill);
        c.drawCircle(Offset(e.ax, e.ay), e.tR * p, hot);
        c.drawCircle(Offset(e.ax, e.ay), e.tR, line);
        break;
      case 3: {
        c.save();
        c.translate(e.x, e.y);
        c.rotate(e.tA);
        c.drawRect(Rect.fromLTWH(0, -e.tW, e.tR, e.tW * 2), fill);
        c.drawRect(Rect.fromLTWH(0, -e.tW, e.tR * p, e.tW * 2), hot);
        c.drawRect(Rect.fromLTWH(0, -e.tW, e.tR, e.tW * 2), line);
        c.restore();
        break;
      }
      case 4: {
        final Path sec = Path()
          ..moveTo(e.x, e.y)
          ..arcTo(Rect.fromCircle(center: Offset(e.x, e.y), radius: e.tR), e.tA - e.tW, e.tW * 2, false)
          ..close();
        c.drawPath(sec, fill);
        final Path sec2 = Path()
          ..moveTo(e.x, e.y)
          ..arcTo(Rect.fromCircle(center: Offset(e.x, e.y), radius: max(1.0, e.tR * p)), e.tA - e.tW, e.tW * 2, false)
          ..close();
        c.drawPath(sec2, hot);
        c.drawPath(sec, line);
        break;
      }
      default: {
        for (int i = -1; i <= 1; i++) {
          c.save();
          c.translate(e.x, e.y);
          c.rotate(e.tA + i * e.tW);
          c.drawRect(Rect.fromLTWH(0, -11, e.tR, 22), fill);
          c.drawRect(Rect.fromLTWH(0, -11, e.tR * p, 22), hot);
          c.restore();
        }
        break;
      }
    }
  }

  // ---- entities -----------------------------------------------------------

  void _drawPick(Canvas c, DPick pk) {
    final double pulse = 0.5 + 0.5 * sin(_t * 5 + pk.x);
    c.drawCircle(Offset(pk.x, pk.y), 18, _p..color = const Color(0xFF69F0AE).withValues(alpha: 0.12 + 0.1 * pulse));
    _p.color = const Color(0xFF69F0AE);
    c.drawRect(Rect.fromCenter(center: Offset(pk.x, pk.y - 2), width: 16, height: 5), _p);
    c.drawRect(Rect.fromCenter(center: Offset(pk.x, pk.y - 2), width: 5, height: 16), _p);
  }

  static double _lerpAng(double a, double b, double t) {
    double d = b - a;
    while (d > pi) {
      d -= 2 * pi;
    }
    while (d < -pi) {
      d += 2 * pi;
    }
    return a + d * t;
  }

  static double _weaponLen(String k) {
    switch (k) {
      case 'dagger':
        return 52;
      case 'hammer':
        return 92;
      case 'axe':
        return 80;
      case 'staff':
        return 104;
      case 'shield':
        return 58;
      default:
        return 84;
    }
  }

  static final CharLook _civ3 = CharLook.from(skin: const Color(0xFF8D5A3A), hair: const Color(0xFF1B1B1B), shirt: const Color(0xFF26A69A), pants: const Color(0xFF37474F), hairStyle: 'low', weapon: 'none', weaponAsset: const <String, dynamic>{});
  CharLook? _hl3;
  HeroLook? _hl3Src;
  String _hl3Weapon = '';
  Object? _hl3Asset;

  CharLook _heroLook3(String wk, bool axeAway) {
    final HeroLook h = HeroLook.current;
    final String w = axeAway ? 'none' : wk;
    final Map<String, dynamic> asset = g.armory.assetFor(wk);
    if (_hl3 == null || !identical(_hl3Src, h) || _hl3Weapon != w || !identical(_hl3Asset, asset)) {
      _hl3 = CharLook.from(skin: h.skin, hair: h.hair, shirt: h.shirt, pants: h.pants, hairStyle: h.hairStyle, weapon: w, weaponAsset: asset);
      _hl3Src = h;
      _hl3Weapon = w;
      _hl3Asset = asset;
    }
    return _hl3!;
  }

  void _drawHero(Canvas c) {
    final double x = g.hx;
    final double y = g.hy;
    final String wk = g.weapon;
    RealmDraw.glow(c, Offset(x, y + 6), 28, g.armory.glowFor(wk) ?? _cyan, alpha: 0.10);
    // dash afterimages
    if (g.dashT > 0 || g.chargeT > 0) {
      final double dx = g.dashT > 0 ? g.dashVx : g.chargeVx;
      final double dy = g.dashT > 0 ? g.dashVy : g.chargeVy;
      final double m = sqrt(dx * dx + dy * dy);
      if (m > 1) {
        for (int i = 1; i <= 3; i++) {
          c.drawCircle(Offset(x - dx / m * i * 16, y - dy / m * i * 16 - 4), 12 - i * 2.0, _p..color = _cyan.withValues(alpha: 0.18 - i * 0.04));
        }
      }
    }
    // weapon pose
    final bool axeAway = wk == 'axe' && g.hasHeroAxe();
    double ang = g.faceSign > 0 ? -1.15 : pi + 1.15;
    double hx = x + g.faceSign * 9;
    double hy = y - 12;
    double len = _weaponLen(wk);
    if (g.swingT >= 0) {
      final double p = (g.swingT / (g.swingDur <= 0 ? 1.0 : g.swingDur)).clamp(0.0, 1.0).toDouble();
      final double ease = 1 - (1 - p) * (1 - p);
      switch (g.swingKind) {
        case 'sword':
          ang = g.swingAng + g.swingDir * (-1.4 + 2.8 * ease);
          break;
        case 'dagger': {
          ang = g.swingAng;
          final double f = 20 * sin(p * pi);
          hx += cos(ang) * f;
          hy += sin(ang) * f;
          break;
        }
        case 'hammer': {
          final double up = -pi / 2 + (cos(g.swingAng) >= 0 ? 0.35 : -0.35);
          ang = p < 0.55 ? _lerpAng(ang, up, p / 0.55) : _lerpAng(up, g.swingAng, ((p - 0.55) / 0.2).clamp(0.0, 1.0).toDouble());
          break;
        }
        case 'axe':
          ang = g.swingAng + g.swingDir * (-0.9 + 1.8 * ease);
          break;
        case 'staff':
          ang = g.swingAng;
          break;
        default: {
          // shield bash or charge
          ang = g.swingAng;
          final double f = 24 * sin(p * pi);
          hx += cos(ang) * f;
          hy += sin(ang) * f;
          break;
        }
      }
    } else if (g.spinT >= 0) {
      final double p = (g.spinT / 0.4).clamp(0.0, 1.0).toDouble();
      ang = g.hFace + 2 * pi * p;
    } else if (wk == 'shield' && g.guard > 0) {
      ang = g.hFace;
      final double f = 14;
      hx += cos(ang) * f;
      hy += sin(ang) * f;
      len = 66;
    } else if (wk == 'staff') {
      ang = g.faceSign > 0 ? -1.35 : pi + 1.35;
    }
    final bool behind = sin(ang) < -0.35;
    final bool flick = g.invuln > 0 && g.invuln < 50 && ((_t * 16).floor() % 2 == 0);
    if (flick) c.saveLayer(Rect.fromCenter(center: Offset(x, y), width: 260, height: 260), Paint()..color = const Color(0x77FFFFFF));
    double swing3 = -1;
    double face3 = g.faceSign;
    double spin3 = 0;
    if (g.swingT >= 0) {
      swing3 = (g.swingT / (g.swingDur <= 0 ? 1.0 : g.swingDur)).clamp(0.0, 1.0).toDouble();
      face3 = cos(g.swingAng) >= 0 ? 1.0 : -1.0;
    } else if (g.spinT >= 0) {
      swing3 = (g.spinT / 0.4).clamp(0.0, 1.0).toDouble();
      spin3 = 2 * pi * swing3;
    }
    final bool d3 = Fighter3D.draw(c, _heroLook3(wk, axeAway), x, y - 8,
        phase: g.hphase, moving: g.hmoving || g.dashT > 0 || g.chargeT > 0, facing: face3, scale: 1.2, swing: swing3, time: _t, yawAdd: spin3, priority: true);
    if (d3) {
      if (g.swingT >= 0 && g.swingDur > 0) {
        paintSwingArc(c, x, y - 10, g.swingAng, g.swingDir >= 0 ? 1.0 : -1.0, swing3, wk == 'dagger' ? 26 : 38, g.armory.glowFor(wk) ?? _cyan);
      }
    } else {
      if (!axeAway && behind) g.armory.draw(c, wk, hx, hy, ang, len);
      RealmDraw.person(c, x, y - 8, phase: g.hphase, moving: g.hmoving || g.dashT > 0 || g.chargeT > 0, facing: g.faceSign, hero: true, scale: 1.2);
      if (!axeAway && !behind) g.armory.draw(c, wk, hx, hy, ang, len);
    }
    if (g.hitFlash > 0) {
      c.drawCircle(Offset(x, y - 4), 20, _p..color = _red.withValues(alpha: 0.45 * (g.hitFlash / 0.22).clamp(0.0, 1.0).toDouble()));
    }
    if (g.guard > 0) {
      _s
        ..strokeWidth = 3
        ..color = const Color(0xFF80D8FF).withValues(alpha: 0.7);
      c.drawArc(Rect.fromCircle(center: Offset(x, y - 4), radius: 34), g.hFace - 1.0, 2.0, false, _s);
    }
    if (flick) c.restore();
    final String? title = CosmeticsService.titleFor(CosmeticsService.myLoadout.value);
    _text(c, g.heroName, Offset(x, y - 58), 11, Colors.white.withValues(alpha: 0.95));
    if (title != null) _text(c, title, Offset(x, y - 70), 9.5, const Color(0xFFFFD54F).withValues(alpha: 0.95));
  }

  Color _inv(Color c) {
    final int v = c.value;
    final int r = 255 - ((v >> 16) & 0xFF);
    final int gg = 255 - ((v >> 8) & 0xFF);
    final int b = 255 - (v & 0xFF);
    return Color.fromARGB(255, (r * 0.6).round(), (gg * 0.6).round(), (b * 0.7 + 20).round().clamp(0, 255).toInt());
  }

  void _drawEcho(Canvas c, DEnemy e) {
    final HeroLook look = HeroLook.current;
    final double fs = cos(e.face) >= 0 ? 1.0 : -1.0;
    final int q = (_t * 12).floor();
    final bool glitch = realmUnit(q, e.id, 2) > 0.72;
    final double jx = glitch ? (realmUnit(q, e.id, 1) - 0.5) * 8 : 0;
    final double spawnA = e.spawnT > 0 ? (1 - e.spawnT / 1.5).clamp(0.0, 1.0).toDouble() : 1.0;
    final Rect box = Rect.fromCenter(center: Offset(e.x, e.y), width: 160, height: 160);
    c.saveLayer(box, Paint()..color = Color.fromRGBO(255, 255, 255, spawnA));
    RealmDraw.glow(c, Offset(e.x, e.y + 4), 30, _cyan, alpha: 0.12);
    // two colour fringes
    final bool echo3 = Fighter3D.draw(
        c,
        CharLook.from(skin: _inv(look.skin), hair: _inv(look.hair), shirt: _inv(look.shirt), pants: _inv(look.pants), hairStyle: look.hairStyle, weapon: 'none', weaponAsset: const <String, dynamic>{}),
        e.x + jx,
        e.y - 8,
        phase: e.phase,
        moving: e.moving,
        facing: fs,
        scale: 1.2,
        time: _t);
    if (!echo3) {
      c.saveLayer(box, Paint()..color = const Color(0x66FFFFFF));
      RealmDraw.person(c, e.x - 4 + jx, e.y - 8, phase: e.phase, moving: e.moving, facing: fs, shirt: const Color(0xFF00E5FF), pants: const Color(0xFF00B8D4), skin: const Color(0xFF80DEEA), hair: const Color(0xFF00E5FF), scale: 1.2, hairStyle: look.hairStyle);
      RealmDraw.person(c, e.x + 4 + jx, e.y - 8, phase: e.phase, moving: e.moving, facing: fs, shirt: const Color(0xFFFF2E93), pants: const Color(0xFFC2185B), skin: const Color(0xFFF48FB1), hair: const Color(0xFFFF2E93), scale: 1.2, hairStyle: look.hairStyle);
      c.restore();
    }
    // weapon behind or in front
    double ang = fs > 0 ? -1.15 : pi + 1.15;
    if (e.tele > 0 && e.tShape != 0) {
      final double p = (1 - e.tele / (e.teleMax <= 0 ? 1.0 : e.teleMax)).clamp(0.0, 1.0).toDouble();
      final double target = e.tShape == 2 ? atan2(e.ay - e.y, e.ax - e.x) : e.tA;
      final double up = -pi / 2;
      ang = e.weapon == 'hammer' ? _lerpAng(ang, up, p) : _lerpAng(ang, target - (cos(target) >= 0 ? 1 : -1) * 1.2 * (1 - p), p);
    } else if (e.swingT >= 0) {
      final double target = e.tA;
      ang = target + (cos(target) >= 0 ? 1 : -1) * ((e.swingT / 0.4) * 1.6 - 0.8);
    }
    final bool behind = sin(ang) < -0.35;
    final double wx = e.x + fs * 9 + jx;
    final double wy = e.y - 12;
    if (behind) g.armory.draw(c, e.weapon, wx, wy, ang, _weaponLen(e.weapon), alpha: 0.9);
    if (!echo3) RealmDraw.person(c, e.x + jx, e.y - 8, phase: e.phase, moving: e.moving, facing: fs, shirt: _inv(look.shirt), pants: _inv(look.pants), skin: _inv(look.skin), hair: _inv(look.hair), scale: 1.2, hairStyle: look.hairStyle);
    if (!behind) g.armory.draw(c, e.weapon, wx, wy, ang, _weaponLen(e.weapon), alpha: 0.9);
    if (glitch) {
      for (int i = 0; i < 3; i++) {
        final double sy = e.y - 40 + realmUnit(q, e.id, 10 + i) * 56;
        c.drawRect(Rect.fromLTWH(e.x - 24 + jx * 2, sy, 48, 2.5), _p..color = g.theme.ground.withValues(alpha: 0.85));
        c.drawRect(Rect.fromLTWH(e.x - 20 - jx, sy + 4, 40, 1.5), _p..color = _cyan.withValues(alpha: 0.6));
      }
    }
    if (e.flash > 0) c.drawCircle(Offset(e.x, e.y - 4), 20, _p..color = Colors.white.withValues(alpha: 0.5));
    c.restore();
    _bar(c, e.x, e.y - 52, 46, e.hp / e.maxHp, _cyan);
    _text(c, e.name.isEmpty ? 'ECHO' : e.name, Offset(e.x, e.y - 64), 11, _cyan);
    if (e.stun > 0) _stars(c, e.x, e.y - 40);
  }

  void _stars(Canvas c, double x, double y) {
    for (int i = 0; i < 3; i++) {
      final double a = _t * 6 + i * 2.1;
      c.drawCircle(Offset(x + cos(a) * 12, y + sin(a) * 4), 2.6, _p..color = const Color(0xFFFFD54F));
    }
  }

  void _bar(Canvas c, double cx, double y, double w, double f, Color col) {
    final double ff = f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2 - 1.5, y - 1.5, w + 3, 7), const Radius.circular(3)), _p..color = Colors.black.withValues(alpha: 0.65));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, y, w * ff, 4), const Radius.circular(2)), _p..color = col);
  }

  void _drawEnemy(Canvas c, DEnemy e) {
    if (e.type == 'echo') {
      _drawEcho(c, e);
      return;
    }
    final DarkomEnemyDef def = darkomEnemies[e.type] ?? darkomEnemies['shade']!;
    final double spawnA = e.spawnT > 0 ? (1 - e.spawnT / 0.55).clamp(0.0, 1.0).toDouble() : 1.0;
    final double fx = cos(e.face);
    final double fy = sin(e.face);
    final double wob = sin(e.phase) * (e.moving ? 1.0 : 0.3);
    final double r = e.r;
    if (e.spawnT > 0) {
      _s
        ..strokeWidth = 2
        ..color = def.glow.withValues(alpha: 0.6 * (1 - spawnA));
      c.drawCircle(Offset(e.x, e.y), r * (2.4 - 1.4 * spawnA), _s);
    }
    final bool fade = e.type == 'wraith';
    double alpha = spawnA;
    if (fade) alpha *= 0.62 + 0.18 * sin(_t * 9 + e.id);
    if (fade && e.tele > 0 && e.atk == 4) alpha *= 0.35;
    final bool layer = alpha < 0.98;
    if (layer) c.saveLayer(Rect.fromCenter(center: Offset(e.x, e.y), width: r * 6, height: r * 6), Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    RealmDraw.shadow(c, e.x, e.y + r * 0.9, r * 2.2);
    final Offset ctr = Offset(e.x, e.y - 4 + wob);
    switch (e.type) {
      case 'spitter': {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: r * 1.5, height: r * 2.2), Radius.circular(r * 0.7)), _p..color = def.color);
        _s
          ..strokeWidth = 2
          ..color = def.glow.withValues(alpha: 0.7);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: r * 1.5, height: r * 2.2), Radius.circular(r * 0.7)), _s);
        final double charge = (e.tele > 0 && e.teleMax > 0) ? 1 - e.tele / e.teleMax : 0.0;
        final Offset muzzle = ctr + Offset(fx * (r + 2), fy * (r + 2));
        c.drawCircle(muzzle, 4 + 6 * charge, _p..color = def.glow.withValues(alpha: 0.35));
        c.drawCircle(muzzle, 2.5 + 3 * charge, _p..color = def.glow);
        c.drawCircle(ctr + Offset(fx * 3 - 3, -r * 0.5), 2, _p..color = def.glow);
        c.drawCircle(ctr + Offset(fx * 3 + 3, -r * 0.5), 2, _p..color = def.glow);
        break;
      }
      case 'brute':
      case 'bounty': {
        final bool boss = e.type == 'bounty';
        if (boss) {
          for (int i = 0; i < 8; i++) {
            final double a = i * pi / 4 + _t * 0.5;
            final Path sp = Path()
              ..moveTo(ctr.dx + cos(a - 0.2) * r, ctr.dy + sin(a - 0.2) * r)
              ..lineTo(ctr.dx + cos(a) * (r + 12), ctr.dy + sin(a) * (r + 12))
              ..lineTo(ctr.dx + cos(a + 0.2) * r, ctr.dy + sin(a + 0.2) * r)
              ..close();
            c.drawPath(sp, _p..color = def.glow.withValues(alpha: 0.9));
          }
        }
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: r * 2.0, height: r * 1.8), Radius.circular(r * 0.5)), _p..color = def.color);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr + Offset(0, -r * 0.2), width: r * 2.5, height: r * 0.7), const Radius.circular(5)), _p..color = boss ? const Color(0xFF5A1A22) : const Color(0xFF6A3A22));
        _s
          ..strokeWidth = 2.5
          ..color = def.glow.withValues(alpha: 0.8);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: ctr, width: r * 2.0, height: r * 1.8), Radius.circular(r * 0.5)), _s);
        c.drawCircle(ctr + Offset(fx * 4, -r * 0.95), r * 0.38, _p..color = const Color(0xFF3A2A28));
        c.drawRect(Rect.fromCenter(center: ctr + Offset(fx * 5, -r * 0.95), width: r * 0.6, height: 3), _p..color = def.glow);
        if (e.tele > 0 && e.teleMax > 0) {
          final double pr = 1 - e.tele / e.teleMax;
          c.drawCircle(ctr + Offset(0, -r * 1.4 - 6 * pr), 4, _p..color = _red);
        }
        break;
      }
      case 'wraith': {
        final Path w = Path()
          ..moveTo(ctr.dx - r, ctr.dy - r * 0.2)
          ..quadraticBezierTo(ctr.dx, ctr.dy - r * 1.7, ctr.dx + r, ctr.dy - r * 0.2)
          ..lineTo(ctr.dx + r * 0.7 + wob * 2, ctr.dy + r * 1.3)
          ..lineTo(ctr.dx + r * 0.2, ctr.dy + r * 0.8)
          ..lineTo(ctr.dx - r * 0.2, ctr.dy + r * 1.4)
          ..lineTo(ctr.dx - r * 0.7 - wob * 2, ctr.dy + r * 0.9)
          ..close();
        c.drawPath(w, _p..color = def.color);
        _s
          ..strokeWidth = 2
          ..color = def.glow;
        c.drawPath(w, _s);
        c.drawCircle(ctr + Offset(-4 + fx * 2, -r * 0.3), 2.4, _p..color = const Color(0xFF1B2A33));
        c.drawCircle(ctr + Offset(4 + fx * 2, -r * 0.3), 2.4, _p..color = const Color(0xFF1B2A33));
        break;
      }
      default: {
        // shade
        for (int i = -1; i <= 1; i++) {
          c.drawLine(ctr + Offset(i * r * 0.55, r * 0.5), ctr + Offset(i * r * 0.8 + wob * 3, r * 1.15), _s..strokeWidth = 3..color = def.color);
        }
        c.drawCircle(ctr, r * 1.05, _p..color = def.color);
        _s
          ..strokeWidth = 2
          ..color = def.glow.withValues(alpha: 0.65);
        c.drawCircle(ctr, r * 1.05, _s);
        final Path hood = Path()
          ..moveTo(ctr.dx - r * 0.8, ctr.dy - r * 0.5)
          ..lineTo(ctr.dx, ctr.dy - r * 1.6)
          ..lineTo(ctr.dx + r * 0.8, ctr.dy - r * 0.5)
          ..close();
        c.drawPath(hood, _p..color = def.color);
        c.drawCircle(ctr + Offset(-4 + fx * 2.5, -2), 2.6, _p..color = def.glow);
        c.drawCircle(ctr + Offset(4 + fx * 2.5, -2), 2.6, _p..color = def.glow);
        break;
      }
    }
    if (e.flash > 0) c.drawCircle(ctr, r * 1.15, _p..color = Colors.white.withValues(alpha: 0.55));
    if (layer) c.restore();
    if (e.stun > 0) _stars(c, e.x, e.y - r - 12);
    if (e.bounty) {
      _bar(c, e.x, e.y - r - 30, 70, e.hp / e.maxHp, _red);
      _text(c, e.name, Offset(e.x, e.y - r - 42), 12, const Color(0xFFFF8A80));
      final double bob = 4 * sin(_t * 5);
      final Path chev = Path()
        ..moveTo(e.x - 8, e.y - r - 66 + bob)
        ..lineTo(e.x, e.y - r - 56 + bob)
        ..lineTo(e.x + 8, e.y - r - 66 + bob);
      c.drawPath(chev, _s..strokeWidth = 3..color = _red);
    } else if (e.hp < e.maxHp) {
      _bar(c, e.x, e.y - r - 12, 28, e.hp / e.maxHp, def.glow);
    }
  }

  void _drawCourier(Canvas c, DCourier cr) {
    if (cr.downT > 0) {
      c.drawOval(Rect.fromCenter(center: Offset(cr.x, cr.y + 6), width: 40, height: 16), _p..color = const Color(0xFF26A69A));
      c.drawCircle(Offset(cr.x + 14, cr.y + 4), 7, _p..color = const Color(0xFFF2B785));
      _text(c, '${cr.name} is down', Offset(cr.x, cr.y - 18), 11, const Color(0xFFFF8A80));
      _bar(c, cr.x, cr.y - 8, 34, 1 - (cr.downT / 6.0), const Color(0xFF69F0AE));
      return;
    }
    _s
      ..strokeWidth = 2
      ..color = const Color(0xFF69F0AE).withValues(alpha: 0.6);
    c.drawCircle(Offset(cr.x, cr.y + 8), 20, _s);
    if (!Fighter3D.draw(c, _civ3, cr.x, cr.y - 8, phase: cr.phase, moving: cr.moving, facing: cr.face, scale: 1.05, time: _t)) {
      RealmDraw.person(c, cr.x, cr.y - 8, phase: cr.phase, moving: cr.moving, facing: cr.face, shirt: const Color(0xFF26A69A), pants: const Color(0xFF37474F), skin: const Color(0xFF8D5A3A), hair: const Color(0xFF1B1B1B), scale: 1.05);
    }
    if (cr.flash > 0) c.drawCircle(Offset(cr.x, cr.y - 4), 16, _p..color = _red.withValues(alpha: 0.4));
    _text(c, cr.name, Offset(cr.x, cr.y - 46), 11, const Color(0xFF69F0AE));
    if (cr.hp < cr.maxHp) _bar(c, cr.x, cr.y - 36, 34, cr.hp / cr.maxHp, const Color(0xFF69F0AE));
  }

  void _drawProj(Canvas c, DProj p) {
    Color col;
    switch (p.kind) {
      case 0:
        col = const Color(0xFFFF6E40);
        break;
      case 1:
        col = g.armory.glowFor(g.weapon) ?? _cyan;
        break;
      case 2:
        col = const Color(0xFFB388FF);
        break;
      default:
        col = const Color(0xFFE0F7FA);
        break;
    }
    c.drawCircle(Offset(p.x, p.y), p.r * 2.2, _p..color = col.withValues(alpha: 0.22));
    if (p.kind == 1 || p.kind == 3) {
      final double m = sqrt(p.vx * p.vx + p.vy * p.vy);
      if (m > 1) {
        _s
          ..strokeWidth = p.r * 1.3
          ..strokeCap = StrokeCap.round
          ..color = col;
        c.drawLine(Offset(p.x - p.vx / m * 14, p.y - p.vy / m * 14), Offset(p.x, p.y), _s);
        _s.strokeCap = StrokeCap.butt;
      }
    }
    c.drawCircle(Offset(p.x, p.y), p.r, _p..color = col);
    c.drawCircle(Offset(p.x, p.y), p.r * 0.45, _p..color = Colors.white);
  }

  void _drawAxe(Canvas c, DAxe a) {
    c.drawCircle(Offset(a.x, a.y), 18, _p..color = (a.hostile ? _red : _cyan).withValues(alpha: 0.12));
    c.save();
    c.translate(a.x, a.y);
    c.rotate(a.spin);
    g.armory.draw(c, 'axe', 0, 0, -pi / 2 - 0.35, 64);
    c.restore();
  }

  void _drawFx(Canvas c) {
    for (final DFx f in g.fxs) {
      final double k = (f.life / f.maxLife).clamp(0.0, 1.0).toDouble();
      switch (f.kind) {
        case 0:
          _s
            ..strokeWidth = 4 * k + 1
            ..color = f.color.withValues(alpha: 0.85 * k);
          c.drawCircle(Offset(f.x, f.y), f.r * (0.35 + 0.65 * (1 - k)), _s);
          break;
        case 1: {
          final Rect rr = Rect.fromCircle(center: Offset(f.x, f.y), radius: f.r * (0.7 + 0.3 * (1 - k)));
          _s
            ..strokeWidth = 12 * k + 2
            ..color = f.color.withValues(alpha: 0.30 * k);
          c.drawArc(rr, f.a - f.sweep / 2, f.sweep, false, _s);
          _s
            ..strokeWidth = 4 * k + 1
            ..color = Colors.white.withValues(alpha: 0.85 * k);
          c.drawArc(rr, f.a - f.sweep / 2, f.sweep, false, _s);
          break;
        }
        default:
          c.drawCircle(Offset(f.x, f.y), f.r * (1 + 0.3 * (1 - k)), _p..color = f.color.withValues(alpha: 0.5 * k));
          break;
      }
    }
  }

  void _drawParticles(Canvas c) {
    for (final DPart p in g.parts) {
      final double k = (p.life / p.maxLife).clamp(0.0, 1.0).toDouble();
      c.drawCircle(Offset(p.x, p.y), p.size * (0.4 + 0.6 * k), _p..color = p.color.withValues(alpha: k));
    }
  }

  // ---- screen overlay -----------------------------------------------------

  void _drawOverlay(Canvas c, Size size) {
    final Rect all = Offset.zero & size;
    final Paint vp = Paint()
      ..shader = const RadialGradient(colors: <Color>[Color(0x00000000), Color(0xB0000000)], stops: <double>[0.5, 1.0]).createShader(all);
    c.drawRect(all, vp);
    if (g.hitFlash > 0) {
      c.drawRect(all, _p..color = _red.withValues(alpha: 0.16 * (g.hitFlash / 0.22).clamp(0.0, 1.0).toDouble()));
    }
    if (g.hp < 30 && !g.heroDead) {
      final double pl = 0.5 + 0.5 * sin(_t * 6);
      _s
        ..strokeWidth = 14
        ..color = _red.withValues(alpha: 0.18 + 0.2 * pl);
      c.drawRect(all.deflate(4), _s);
    }
    if (g.heroDead) {
      c.drawRect(all, _p..color = const Color(0xFF000000).withValues(alpha: 0.45));
    }
    if (g.bannerT > 0 && g.banner.isNotEmpty) {
      final double a = g.bannerT > 0.4 ? 1.0 : g.bannerT / 0.4;
      final double rise = (2.4 - g.bannerT).clamp(0.0, 0.3).toDouble();
      final double s = 30 + 4 * (rise / 0.3);
      c.drawRect(Rect.fromLTWH(0, size.height * 0.30 - 22, size.width, 44), _p..color = Colors.black.withValues(alpha: 0.45 * a));
      _text(c, g.banner, Offset(size.width / 2, size.height * 0.30), s, g.bannerColor.withValues(alpha: a), maxW: size.width - 20);
    }
  }
}
