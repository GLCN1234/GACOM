import '../../character3d/fighter3d.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../darkom_look.dart';
import '../darkom_look_paint.dart';
import 'darkom_hub_net.dart';
import 'darkom_hub_world.dart';

class _Ent {
  final double y;
  final HubRemote? r;
  _Ent(this.y, this.r);
}

/// Draws Neon Plaza with plain canvas shapes. Repaints from the ticker's
/// notifier, never from setState.
class HubPainter extends CustomPainter {
  final HubScene scene;
  HubPainter(this.scene, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();
  final Paint _s = Paint()..style = PaintingStyle.stroke;
  final Map<String, TextPainter> _tpc = <String, TextPainter>{};
  Shader? _vig;
  Size _vigSize = Size.zero;
  static final DarkomLook _fallback = DarkomLook.fromJson(const <String, dynamic>{});

  @override
  bool shouldRepaint(covariant HubPainter old) => true;

  double _fr(double v) => v - v.floorToDouble();
  double _hash(int i, int k) => _fr(sin(i * 12.9898 + k * 78.233) * 43758.5453);

  TextPainter _tp(String text, double size, Color color, {FontWeight weight = FontWeight.w800, double maxW = 220, int maxLines = 1}) {
    final String key = '$text|${size.toStringAsFixed(1)}|${color.value}|${weight.index}|${maxW.toInt()}|$maxLines';
    TextPainter? tp = _tpc[key];
    if (tp == null) {
      if (_tpc.length > 160) _tpc.clear();
      tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight, fontFamily: 'Rajdhani', height: 1.05)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        ellipsis: '..',
      )..layout(maxWidth: maxW);
      _tpc[key] = tp;
    }
    return tp;
  }

  void _neon(Canvas c, String text, Offset center, double size, Color color, double t, int seed, {double maxW = 260}) {
    final double flick = 0.82 + 0.18 * sin(t * 3 + seed * 1.7) + (_hash((t * 6).floor(), seed) > 0.97 ? -0.3 : 0);
    final Color glow = color.withOpacity((0.28 * flick).clamp(0.05, 0.4).toDouble());
    final TextPainter g = _tp(text, size, glow, maxW: maxW);
    for (final Offset o in const <Offset>[Offset(-1.8, 0), Offset(1.8, 0), Offset(0, -1.8), Offset(0, 1.8)]) {
      g.paint(c, center - Offset(g.width / 2, g.height / 2) + o);
    }
    final TextPainter m = _tp(text, size, Color.lerp(color, Colors.white, 0.45 * flick)!, maxW: maxW);
    m.paint(c, center - Offset(m.width / 2, m.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    Fighter3D.begin(shared: 8);
    final HubSim s = scene.sim;
    final double t = s.time;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    canvas.drawRect(Offset.zero & size, _p..color = kHubInk);
    final HubCam cam = hubCamera(size, s.x, s.y);
    canvas.save();
    canvas.scale(cam.zoom);
    canvas.translate(size.width / (2 * cam.zoom) - cam.x, size.height / (2 * cam.zoom) - cam.y);
    final Rect view = cam.view.inflate(140);
    _ground(canvas, view, t);
    _portalPads(canvas, view, t);

    final List<_Ent> ents = <_Ent>[_Ent(s.y, null)];
    final DarkomHubNet? net = scene.net;
    if (net != null) {
      for (final HubRemote r in net.visible(s.x, s.y, nowMs)) {
        ents.add(_Ent(r.y, r));
      }
    }
    ents.sort((_Ent a, _Ent b) => a.y.compareTo(b.y));
    final List<HubBlock> blocks = HubWorld.blocks;
    int bi = 0;
    for (final _Ent e in ents) {
      while (bi < blocks.length && blocks[bi].r.bottom <= e.y) {
        _blockIfVisible(canvas, blocks[bi], view, t);
        bi++;
      }
      if (e.r == null) {
        _person(canvas, null, nowMs);
      } else {
        _person(canvas, e.r, nowMs);
      }
    }
    while (bi < blocks.length) {
      _blockIfVisible(canvas, blocks[bi], view, t);
      bi++;
    }
    _lamps(canvas, view, t);
    _fountainTop(canvas, t);
    // speech and emotes drawn last so nothing hides them
    for (final _Ent e in ents) {
      _overhead(canvas, e.r, nowMs, t);
    }
    canvas.restore();

    _rain(canvas, size, t);
    _vignette(canvas, size);
    _minimap(canvas, size, net, nowMs);
    _joystick(canvas, s);
  }

  // ---------------------------------------------------------------- ground

  void _ground(Canvas c, Rect view, double t) {
    final Rect world = Rect.fromLTWH(0, 0, HubWorld.width, HubWorld.height);
    c.drawRect(world, _p..color = const Color(0xFF090D18));
    // plaza stones
    final Rect v = view.intersect(world);
    if (v.width <= 0 || v.height <= 0) return;
    _s
      ..strokeWidth = 1
      ..color = const Color(0x1400E5FF);
    final double x0 = (v.left / 100).floorToDouble() * 100;
    final double y0 = (v.top / 100).floorToDouble() * 100;
    for (double x = x0; x <= v.right; x += 100) {
      c.drawLine(Offset(x, v.top), Offset(x, v.bottom), _s);
    }
    for (double y = y0; y <= v.bottom; y += 100) {
      c.drawLine(Offset(v.left, y), Offset(v.right, y), _s);
    }
    // main avenues
    c.drawRect(Rect.fromLTWH(850, 190, 100, 470), _p..color = const Color(0xFF0D1324));
    c.drawRect(Rect.fromLTWH(260, 600, 1280, 120), _p..color = const Color(0xFF0D1324));
    c.drawRect(Rect.fromLTWH(850, 740, 100, 480), _p..color = const Color(0xFF0D1324));
    // lane dashes
    _p.color = const Color(0x33FFD54F);
    for (double y = 210; y < 560; y += 40) {
      c.drawRect(Rect.fromLTWH(896, y, 8, 18), _p);
    }
    for (double x = 280; x < 780; x += 40) {
      c.drawRect(Rect.fromLTWH(x, 656, 18, 8), _p);
    }
    for (double x = 1020; x < 1520; x += 40) {
      c.drawRect(Rect.fromLTWH(x, 656, 18, 8), _p);
    }
    for (double y = 800; y < 1200; y += 40) {
      c.drawRect(Rect.fromLTWH(896, y, 8, 18), _p);
    }
    // fountain plaza ring
    _s
      ..strokeWidth = 3
      ..color = const Color(0x3300E5FF);
    c.drawCircle(const Offset(900, 660), 150, _s);
    _s
      ..strokeWidth = 1.5
      ..color = const Color(0x22FF2E93);
    c.drawCircle(const Offset(900, 660), 175, _s);
    // world edge
    _s
      ..strokeWidth = 6
      ..color = const Color(0x88FF2E93);
    c.drawRect(world.deflate(3), _s);
    _s
      ..strokeWidth = 2
      ..color = const Color(0x6600E5FF);
    c.drawRect(world.deflate(12), _s);
    // puddles with ripples
    for (int i = 0; i < HubWorld.puddles.length; i++) {
      final List<double> pd = HubWorld.puddles[i];
      final Rect pr = Rect.fromCenter(center: Offset(pd[0], pd[1]), width: pd[2] * 2, height: pd[3] * 2);
      if (!pr.overlaps(view)) continue;
      c.drawOval(pr, _p..color = const Color(0xCC0A1F33));
      c.drawOval(pr.deflate(2), _p..color = (i % 2 == 0 ? kHubMagenta : kHubCyan).withOpacity(0.10));
      _s
        ..strokeWidth = 1.2
        ..color = const Color(0x55FFFFFF);
      c.drawLine(Offset(pr.left + pr.width * 0.25, pr.center.dy - 2), Offset(pr.left + pr.width * 0.5, pr.center.dy - 2), _s);
      final double ph = _fr(t * 0.7 + i * 0.31);
      _s
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.35 * (1 - ph));
      c.drawOval(Rect.fromCenter(center: pr.center + Offset((i % 3 - 1) * 8.0, 0), width: pd[2] * 1.6 * ph, height: pd[3] * 1.6 * ph), _s);
    }
    // fountain basin (flat)
    const Offset f = Offset(900, 660);
    c.drawOval(Rect.fromCenter(center: f.translate(0, 8), width: 190, height: 150), _p..color = const Color(0x66000000));
    c.drawOval(Rect.fromCenter(center: f, width: 176, height: 140), _p..color = const Color(0xFF1B2236));
    c.drawOval(Rect.fromCenter(center: f, width: 150, height: 116), _p..color = const Color(0xFF0B3550));
    for (int i = 0; i < 3; i++) {
      final double ph = _fr(t * 0.5 + i / 3);
      _s
        ..strokeWidth = 1.5
        ..color = kHubCyan.withOpacity(0.5 * (1 - ph));
      c.drawOval(Rect.fromCenter(center: f, width: 150 * ph, height: 116 * ph), _s);
    }
    _s
      ..strokeWidth = 3
      ..color = kHubCyan.withOpacity(0.7);
    c.drawOval(Rect.fromCenter(center: f, width: 176, height: 140), _s);
  }

  void _fountainTop(Canvas c, double t) {
    const Offset f = Offset(900, 650);
    // pillar and spray
    c.drawRect(Rect.fromLTWH(f.dx - 8, f.dy - 40, 16, 40), _p..color = const Color(0xFF2A3350));
    for (int i = 0; i < 9; i++) {
      final double a = i / 9 * pi * 2 + t * 0.6;
      final double ph = _fr(t * 0.9 + i * 0.11);
      final double rr = 46 * ph;
      final double hh = 60 * sin(ph * pi);
      c.drawCircle(Offset(f.dx + cos(a) * rr, f.dy - 40 - hh + 10 + sin(a) * rr * 0.4), 2.2, _p..color = kHubCyan.withOpacity(0.8 * (1 - ph * 0.6)));
    }
    c.drawCircle(f.translate(0, -44), 10, _p..color = kHubCyan.withOpacity(0.5 + 0.2 * sin(t * 3)));
    _neon(c, 'NEON PLAZA', f.translate(0, -112), 20, kHubMagenta, t, 3);
  }

  void _portalPads(Canvas c, Rect view, double t) {
    final HubPortal? near = scene.near;
    for (final HubPortal p in HubWorld.portals) {
      if (!view.contains(Offset(p.x, p.y))) continue;
      final bool on = near != null && near.id == p.id;
      final double pulse = 0.5 + 0.5 * sin(t * 3 + p.x);
      c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: 110, height: 70), _p..color = p.color.withOpacity(on ? 0.30 : 0.14));
      _s
        ..strokeWidth = on ? 3.5 : 2
        ..color = p.color.withOpacity(on ? 0.95 : 0.45 + 0.25 * pulse);
      c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: 100 + pulse * 6, height: 62 + pulse * 4), _s);
      _s
        ..strokeWidth = 1.5
        ..color = p.color.withOpacity(0.35);
      c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y), width: 70, height: 42), _s);
      final TextPainter lab = _tp(p.label, 10, p.color.withOpacity(on ? 1 : 0.8), maxW: 140);
      lab.paint(c, Offset(p.x - lab.width / 2, p.y + 36));
    }
  }

  // ---------------------------------------------------------------- blocks

  void _blockIfVisible(Canvas c, HubBlock b, Rect view, double t) {
    if (!b.r.inflate(b.h + 20).overlaps(view)) return;
    _block(c, b, t);
  }

  void _block(Canvas c, HubBlock b, double t) {
    final Rect r = b.r;
    final double h = b.h;
    final Rect wall = Rect.fromLTRB(r.left, r.bottom - h, r.right, r.bottom);
    final Rect roof = r.shift(Offset(0, -h));
    c.drawRect(Rect.fromLTRB(r.left - 3, r.bottom, r.right + 9, r.bottom + 9), _p..color = const Color(0x66000000));
    final int seed = (r.left + r.top).toInt();
    switch (b.kind) {
      case 'gate':
        c.drawRect(wall, _p..color = b.wall);
        c.drawRect(roof, _p..color = Color.lerp(b.wall, Colors.black, 0.35)!);
        // windows
        final int n = (r.width / 40).floor();
        for (int i = 0; i < n; i++) {
          final bool lit = _hash(i, seed) > 0.35;
          final Rect w = Rect.fromLTWH(r.left + 14 + i * 40.0, wall.top + 52, 20, 14);
          if (w.right > r.right - 10) continue;
          c.drawRect(w, _p..color = lit ? Color.lerp(b.accent, Colors.white, 0.4)!.withOpacity(0.55) : const Color(0xFF0A0E18));
        }
        // door
        final Rect door = Rect.fromCenter(center: Offset(r.center.dx, r.bottom - 22), width: 50, height: 44);
        c.drawRect(door.inflate(6), _p..color = b.accent.withOpacity(0.16 + 0.08 * sin(t * 2)));
        c.drawRect(door, _p..color = b.accent.withOpacity(0.85));
        c.drawRect(Rect.fromLTRB(door.left + 4, door.top + 4, door.right - 4, door.bottom), _p..color = const Color(0xFF06101A));
        _neon(c, b.sign, Offset(r.center.dx, wall.top + 24), b.sign.length > 8 ? 24 : 26, b.accent, t, seed, maxW: r.width - 20);
        _trim(c, wall, roof, b.accent);
        break;
      case 'stall':
        c.drawRect(wall, _p..color = b.wall);
        for (int i = 0; i < 4; i++) {
          c.drawRect(Rect.fromLTWH(r.left + 12 + i * 38.0, wall.top + 30, 22, 12), _p..color = b.accent.withOpacity(0.35 + 0.25 * _hash(i, seed)));
        }
        c.drawRect(roof, _p..color = const Color(0xFF1A2036));
        final double sw = roof.width / 10;
        for (int i = 0; i < 10; i++) {
          c.drawRect(Rect.fromLTWH(roof.left + i * sw, roof.top, sw, roof.height), _p..color = i.isEven ? b.accent.withOpacity(0.75) : const Color(0xFFDCE6F5).withOpacity(0.8));
        }
        c.drawRect(Rect.fromLTWH(roof.left, roof.bottom - 3, roof.width, 5), _p..color = Colors.black.withOpacity(0.35));
        _neon(c, b.sign, Offset(r.center.dx, wall.top + 14), 15, b.accent, t, seed, maxW: r.width - 10);
        _trim(c, wall, roof, b.accent);
        break;
      case 'board':
        c.drawRect(Rect.fromLTWH(r.left + 8, r.bottom - h, 8, h), _p..color = const Color(0xFF3A2A18));
        c.drawRect(Rect.fromLTWH(r.right - 16, r.bottom - h, 8, h), _p..color = const Color(0xFF3A2A18));
        final Rect board = Rect.fromLTWH(r.left - 6, r.bottom - h - 4, r.width + 12, h - 10);
        c.drawRect(board.shift(const Offset(0, 4)), _p..color = const Color(0xFF241A0E));
        c.drawRect(board, _p..color = const Color(0xFF30220F));
        for (int i = 0; i < 5; i++) {
          c.drawRect(Rect.fromLTWH(board.left + 10 + i * 30.0, board.top + 26, 20, 22), _p..color = const Color(0xFFEFE2BA).withOpacity(0.8));
        }
        _s
          ..strokeWidth = 2.5
          ..color = b.accent;
        c.drawRect(board, _s);
        _neon(c, b.sign, Offset(board.center.dx, board.top + 12), 14, b.accent, t, seed);
        break;
      case 'bench':
        c.drawRect(wall, _p..color = const Color(0xFF1F2740));
        c.drawRect(roof, _p..color = const Color(0xFF2B3556));
        _s
          ..strokeWidth = 1
          ..color = Colors.black45;
        for (double x = roof.left + 10; x < roof.right; x += 12) {
          c.drawLine(Offset(x, roof.top), Offset(x, roof.bottom), _s);
        }
        break;
      case 'crate':
        c.drawRect(wall, _p..color = const Color(0xFF5A3C1E));
        c.drawRect(roof, _p..color = const Color(0xFF7A5430));
        _s
          ..strokeWidth = 1.5
          ..color = Colors.black54;
        c.drawRect(wall, _s);
        c.drawRect(roof, _s);
        c.drawLine(roof.topLeft, roof.bottomRight, _s);
        c.drawLine(roof.topRight, roof.bottomLeft, _s);
        break;
      case 'planter':
        c.drawRect(wall, _p..color = const Color(0xFF1E2A3C));
        c.drawRect(roof, _p..color = const Color(0xFF173A2A));
        for (int i = 0; i < 4; i++) {
          c.drawCircle(Offset(roof.left + 8 + i * 13.0, roof.center.dy), 9, _p..color = b.accent.withOpacity(0.55 + 0.1 * i));
        }
        break;
      default:
        c.drawRect(wall, _p..color = b.wall);
        c.drawRect(roof, _p..color = b.wall);
    }
  }

  void _trim(Canvas c, Rect wall, Rect roof, Color accent) {
    _s
      ..strokeWidth = 2
      ..color = accent.withOpacity(0.9);
    c.drawRect(roof, _s);
    c.drawLine(wall.bottomLeft, wall.bottomRight, _s);
    _s
      ..strokeWidth = 1
      ..color = accent.withOpacity(0.4);
    c.drawLine(wall.topLeft, wall.bottomLeft, _s);
    c.drawLine(wall.topRight, wall.bottomRight, _s);
  }

  void _lamps(Canvas c, Rect view, double t) {
    for (int i = 0; i < HubWorld.lamps.length; i++) {
      final Offset l = HubWorld.lamps[i];
      if (!view.inflate(80).contains(l)) continue;
      final Color col = i % 3 == 0 ? kHubMagenta : (i % 3 == 1 ? kHubCyan : kHubAmber);
      c.drawOval(Rect.fromCenter(center: l, width: 130, height: 56), _p..color = col.withOpacity(0.06));
      c.drawOval(Rect.fromCenter(center: l, width: 76, height: 32), _p..color = col.withOpacity(0.08));
      _s
        ..strokeWidth = 3
        ..color = const Color(0xFF2A3350);
      c.drawLine(l, l.translate(0, -78), _s);
      final double fl = 0.8 + 0.2 * sin(t * 4 + i);
      c.drawCircle(l.translate(0, -80), 14, _p..color = col.withOpacity(0.10 * fl));
      c.drawCircle(l.translate(0, -80), 8, _p..color = col.withOpacity(0.25 * fl));
      c.drawCircle(l.translate(0, -80), 4, _p..color = Colors.white.withOpacity(0.9));
    }
  }

  // --------------------------------------------------------------- people

  void _person(Canvas c, HubRemote? r, int nowMs) {
    final HubSim s = scene.sim;
    final bool me = r == null;
    final DarkomLook look = me ? (scene.myLook ?? _fallback) : r!.look;
    final double x = me ? s.x : r!.x;
    final double y = me ? s.y : r!.y;
    final double facing = me ? s.facing : r!.facing;
    final bool moving = me ? s.moving : r!.drawMoving;
    final double phase = me ? s.phase : r!.phase;
    final String id = me ? scene.myId : r!.id;
    final double a = me ? 1.0 : r!.alpha(nowMs);
    if (a <= 0.02) return;
    // ground shadow and selection ring
    c.drawOval(Rect.fromCenter(center: Offset(x, y + 2), width: 30, height: 10), _p..color = Colors.black.withOpacity(0.45 * a));
    if (!me && scene.selectedId == id) {
      _s
        ..strokeWidth = 2.5
        ..color = kHubCyan.withOpacity(0.5 + 0.4 * sin(s.time * 6));
      c.drawOval(Rect.fromCenter(center: Offset(x, y + 2), width: 44, height: 18), _s);
    }
    final HubEmoteShow? em = scene.sim.emotes[id];
    double bob = 0;
    if (em != null && em.index == 4 && nowMs - em.startMs < 2200) bob = -(sin(s.time * 14)).abs() * 5;
    final bool fade = a < 0.98;
    if (fade) c.saveLayer(Rect.fromLTWH(x - 60, y - 140, 120, 170), Paint()..color = Color.fromRGBO(255, 255, 255, a));
    paintDarkomLook(c, look, x, y + bob, phase: phase, moving: moving, facing: facing, showWeapon: true, aim: facing >= 0 ? 0.35 : pi - 0.35, weaponLen: 40, time: s.time, priority: me);
    paintDarkomNameTag(c, look, x, y + bob, nameColor: me ? const Color(0xFF7CF7FF) : Colors.white);
    if (fade) c.restore();
  }

  void _overhead(Canvas c, HubRemote? r, int nowMs, double t) {
    final HubSim s = scene.sim;
    final bool me = r == null;
    final String id = me ? scene.myId : r!.id;
    final double x = me ? s.x : r!.x;
    final double y = me ? s.y : r!.y;
    final DarkomLook look = me ? (scene.myLook ?? _fallback) : r!.look;
    double top = y - 70 - (look.title != null ? 12 : 0);
    final HubEmoteShow? em = s.emotes[id];
    if (em != null) {
      final int age = nowMs - em.startMs;
      if (age >= 0 && age < 2200 && em.index >= 0 && em.index < kHubEmotes.length) {
        final double pop = (age / 180).clamp(0.0, 1.0).toDouble();
        final double fade = age > 1800 ? 1 - (age - 1800) / 400 : 1;
        _bubble(c, kHubEmotes[em.index].say, x, top - 8 * pop, 12, kHubAmber, const Color(0xFF241A0A), fade.clamp(0.0, 1.0).toDouble(), pop);
        top -= 26;
      }
    }
    final HubBubble? b = s.bubbles[id];
    if (b != null && b.untilMs > nowMs) {
      final double fade = ((b.untilMs - nowMs) / 400).clamp(0.0, 1.0).toDouble();
      _bubble(c, b.text, x, top - 6, 11, Colors.white, const Color(0xFF111A2E), fade, 1);
    }
  }

  void _bubble(Canvas c, String text, double x, double bottom, double size, Color border, Color fill, double alpha, double scale) {
    if (alpha <= 0.01) return;
    final TextPainter tp = _tp(text, size, Colors.white, weight: FontWeight.w700, maxW: 150, maxLines: 3);
    final double w = tp.width + 14;
    final double h = tp.height + 8;
    c.save();
    c.translate(x, bottom);
    c.scale(scale);
    final Rect rr = Rect.fromLTWH(-w / 2, -h - 6, w, h);
    final RRect rrect = RRect.fromRectAndRadius(rr, const Radius.circular(8));
    c.drawRRect(rrect, _p..color = fill.withOpacity(0.92 * alpha));
    _s
      ..strokeWidth = 1.5
      ..color = border.withOpacity(0.9 * alpha);
    c.drawRRect(rrect, _s);
    final Path tail = Path()
      ..moveTo(-5, -6)
      ..lineTo(0, 0)
      ..lineTo(5, -6)
      ..close();
    c.drawPath(tail, _p..color = fill.withOpacity(0.92 * alpha));
    if (alpha < 0.98) {
      c.saveLayer(rr.inflate(4), Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
      tp.paint(c, Offset(-tp.width / 2, -h - 6 + 4));
      c.restore();
    } else {
      tp.paint(c, Offset(-tp.width / 2, -h - 6 + 4));
    }
    c.restore();
  }

  // -------------------------------------------------------------- overlays

  void _rain(Canvas c, Size size, double t) {
    _s
      ..strokeWidth = 1
      ..color = const Color(0x3390CAF9);
    for (int i = 0; i < 70; i++) {
      final double sp = 520 + _hash(i, 3) * 260;
      final double x = (_hash(i, 1) * (size.width + 80) + t * 60) % (size.width + 80) - 40;
      final double y = (_hash(i, 2) * size.height + t * sp) % size.height;
      c.drawLine(Offset(x, y), Offset(x - 3, y + 13), _s);
    }
  }

  void _vignette(Canvas c, Size size) {
    if (_vig == null || _vigSize != size) {
      _vigSize = size;
      _vig = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: const <Color>[Color(0x00000000), Color(0x99000000)],
        stops: const <double>[0.55, 1.0],
      ).createShader(Offset.zero & size);
    }
    c.drawRect(Offset.zero & size, Paint()..shader = _vig);
  }

  void _minimap(Canvas c, Size size, DarkomHubNet? net, int nowMs) {
    const double w = 104;
    const double h = 75;
    final double left = 12;
    final double top = 58 + scene.topInset;
    final Rect m = Rect.fromLTWH(left, top, w, h);
    c.drawRRect(RRect.fromRectAndRadius(m, const Radius.circular(6)), _p..color = const Color(0xAA05060A));
    _s
      ..strokeWidth = 1.2
      ..color = kHubCyan.withOpacity(0.6);
    c.drawRRect(RRect.fromRectAndRadius(m, const Radius.circular(6)), _s);
    final double sx = w / HubWorld.width;
    final double sy = h / HubWorld.height;
    for (final HubBlock b in HubWorld.blocks) {
      if (b.kind != 'gate' && b.kind != 'board') continue;
      c.drawRect(Rect.fromLTWH(left + b.r.left * sx, top + b.r.top * sy, max(3.0, b.r.width * sx), max(3.0, b.r.height * sy)), _p..color = b.accent.withOpacity(0.6));
    }
    c.drawCircle(Offset(left + HubWorld.fountain.x * sx, top + HubWorld.fountain.y * sy), 4, _p..color = const Color(0x6600E5FF));
    if (net != null) {
      for (final HubRemote r in net.visible(scene.sim.x, scene.sim.y, nowMs)) {
        c.drawCircle(Offset(left + r.x * sx, top + r.y * sy), 2, _p..color = kHubCyan);
      }
    }
    c.drawCircle(Offset(left + scene.sim.x * sx, top + scene.sim.y * sy), 3, _p..color = Colors.white);
  }

  void _joystick(Canvas c, HubSim s) {
    if (!s.joyOn) return;
    _s
      ..strokeWidth = 2
      ..color = Colors.white.withOpacity(0.25);
    c.drawCircle(s.joyOrigin, 54, _s);
    c.drawCircle(s.joyOrigin, 54, _p..color = Colors.white.withOpacity(0.05));
    final double len = s.joyDelta.distance;
    final Offset d = len > 54 ? s.joyDelta * (54 / len) : s.joyDelta;
    c.drawCircle(s.joyOrigin + d, 22, _p..color = kHubCyan.withOpacity(0.45));
    _s.color = kHubCyan.withOpacity(0.8);
    c.drawCircle(s.joyOrigin + d, 22, _s);
  }
}
