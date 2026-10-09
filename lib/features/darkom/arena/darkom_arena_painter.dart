import '../../character3d/fighter3d.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/widgets/weapon_art.dart';
import '../darkom_look.dart';
import '../darkom_look_paint.dart';
import 'darkom_arena_logic.dart';

const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF2E93);
const Color kArenaRingColors0 = Color(0xFF00E5FF);

/// Ring colour under each player so a free for all stays readable.
const List<Color> kArenaRingColors = <Color>[Color(0xFF00E5FF), Color(0xFFFF2E93), Color(0xFFFFD54F), Color(0xFF69F0AE)];

Color arenaRingFor(ArenaGame g, ArenaPlayer p) {
  if (identical(p, g.me)) return kArenaRingColors0;
  if (g.isDuel) return const Color(0xFFFF5252);
  final List<ArenaPlayer> r = g.roster;
  final int i = r.indexWhere((ArenaPlayer q) => identical(q, p));
  return kArenaRingColors[(i < 0 ? 1 : i + 1) % kArenaRingColors.length];
}

/// Draws the arena: neon cyber noir floor, cover blocks, players with their
/// real cosmetic look, bolts, axes and effects. Repaints from a notifier, so
/// no widget rebuilds per frame.
class ArenaPainter extends CustomPainter {
  final ArenaGame g;
  ArenaPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();
  final Paint _s = Paint()..style = PaintingStyle.stroke;
  final Map<String, TextPainter> _tp = <String, TextPainter>{};
  final Map<String, WeaponPainter> _wp = <String, WeaponPainter>{};

  @override
  bool shouldRepaint(covariant ArenaPainter old) => true;

  void _text(Canvas c, String s, Offset center, double size, Color color) {
    final String key = '$s|${size.toStringAsFixed(0)}|${color.value}';
    TextPainter? tp = _tp[key];
    if (tp == null) {
      if (_tp.length > 80) _tp.clear();
      tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, fontFamily: 'Rajdhani', height: 1.0, shadows: const <Shadow>[Shadow(color: Color(0xDD000000), blurRadius: 3, offset: Offset(0, 1))])),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '..',
      )..layout(maxWidth: 200);
      _tp[key] = tp;
    }
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    Fighter3D.begin(shared: 8);
    canvas.drawRect(Offset.zero & size, _p..color = const Color(0xFF05060A));
    final bool overview = g.phase == ArPhase.lobby || g.phase == ArPhase.failed;
    double zoom;
    double cx;
    double cy;
    if (overview) {
      zoom = min(size.width / (kArW + 80), size.height / (kArH + 80));
      cx = kArW / 2;
      cy = kArH / 2;
    } else {
      zoom = (size.shortestSide / 500).clamp(0.7, 1.5).toDouble();
      final double hw = size.width / (2 * zoom);
      final double hh = size.height / (2 * zoom);
      cx = g.camX;
      cy = g.camY;
      cx = kArW > hw * 2 ? (cx < hw ? hw : (cx > kArW - hw ? kArW - hw : cx)) : kArW / 2;
      cy = kArH > hh * 2 ? (cy < hh ? hh : (cy > kArH - hh ? kArH - hh : cy)) : kArH / 2;
    }
    double shx = 0;
    double shy = 0;
    if (g.shake > 0) {
      shx = sin(g.clock * 131) * g.shake * 0.5;
      shy = cos(g.clock * 97) * g.shake * 0.5;
    }
    canvas.save();
    canvas.translate(size.width / 2 + shx, size.height / 2 + shy);
    canvas.scale(zoom, zoom);
    canvas.translate(-cx, -cy);

    _ground(canvas);
    _blocks(canvas);
    _telegraphs(canvas);
    if (!overview) {
      final List<ArenaPlayer> list = g.roster.toList();
      list.sort((ArenaPlayer a, ArenaPlayer b) => a.y.compareTo(b.y));
      for (final ArenaPlayer p in list) {
        _player(canvas, p);
      }
    }
    for (final ArAxe a in g.axes) {
      _axe(canvas, a);
    }
    for (final ArProj b in g.projs) {
      _bolt(canvas, b);
    }
    _fx(canvas);
    for (final ArPart pt in g.parts) {
      final double a = (pt.life / pt.maxLife).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(Offset(pt.x, pt.y), pt.size * (0.5 + a * 0.5), _p..color = pt.color.withValues(alpha: a));
    }
    for (final ArText t in g.texts) {
      final double a = (t.life / t.maxLife).clamp(0.0, 1.0).toDouble();
      _text(canvas, t.text, Offset(t.x, t.y), t.size, t.color.withValues(alpha: a));
    }
    canvas.restore();
    if (g.phase == ArPhase.fight && g.roundT > kArOverloadAt) {
      final double pulse = 0.08 + 0.06 * sin(g.clock * 6);
      canvas.drawRect(Offset.zero & size, _p..color = const Color(0xFFFF1744).withValues(alpha: pulse));
    }
    if (g.hitFlash > 0) {
      canvas.drawRect(Offset.zero & size, _p..color = const Color(0xFFFF1744).withValues(alpha: (g.hitFlash * 1.2).clamp(0.0, 0.3).toDouble()));
    }
  }

  // ---- world --------------------------------------------------------------

  void _ground(Canvas c) {
    c.drawRect(const Rect.fromLTWH(-200, -200, kArW + 400, kArH + 400), _p..color = const Color(0xFF080910));
    c.drawRect(const Rect.fromLTWH(0, 0, kArW, kArH), _p..color = const Color(0xFF14121F));
    _s
      ..strokeWidth = 1
      ..color = const Color(0xFF45406A).withValues(alpha: 0.28);
    for (double x = 0; x <= kArW; x += 50) {
      c.drawLine(Offset(x, 0), Offset(x, kArH), _s);
    }
    for (double y = 0; y <= kArH; y += 50) {
      c.drawLine(Offset(0, y), Offset(kArW, y), _s);
    }
    // centre mark
    _s
      ..strokeWidth = 2
      ..color = _cyan.withValues(alpha: 0.18);
    c.drawCircle(const Offset(kArW / 2, kArH / 2), 120, _s);
    c.drawLine(const Offset(kArW / 2, 0), const Offset(kArW / 2, kArH), _s);
    c.drawLine(const Offset(0, kArH / 2), const Offset(kArW, kArH / 2), _s);
    // neon border
    _s
      ..strokeWidth = 10
      ..color = _pink.withValues(alpha: 0.18);
    c.drawRect(const Rect.fromLTWH(0, 0, kArW, kArH), _s);
    _s
      ..strokeWidth = 3
      ..color = _pink.withValues(alpha: 0.9);
    c.drawRect(const Rect.fromLTWH(0, 0, kArW, kArH), _s);
  }

  void _blocks(Canvas c) {
    for (final Rect b in g.map.blocks) {
      _p.color = const Color(0x66000000);
      c.drawRect(b.shift(const Offset(5, 7)), _p);
      _p.color = const Color(0xFF241F3A);
      c.drawRect(b, _p);
      _p.color = const Color(0xFF3B2F55);
      c.drawRect(Rect.fromLTRB(b.left, b.top, b.right, b.top + min(14.0, b.height * 0.3)), _p);
      _s
        ..strokeWidth = 5
        ..color = _cyan.withValues(alpha: 0.16);
      c.drawRect(b, _s);
      _s
        ..strokeWidth = 2
        ..color = _cyan.withValues(alpha: 0.85);
      c.drawRect(b, _s);
    }
  }

  void _telegraphs(Canvas c) {
    for (final ArFx f in g.fx) {
      if (f.kind != 3 || f.delay <= 0) continue;
      final double prog = f.warn <= 0 ? 1.0 : (1 - f.delay / f.warn).clamp(0.0, 1.0).toDouble();
      c.drawCircle(Offset(f.x, f.y), f.r * (0.25 + 0.75 * prog), _p..color = const Color(0xFFFF3D3D).withValues(alpha: 0.10 + 0.18 * prog));
      _s
        ..strokeWidth = 2.5
        ..color = const Color(0xFFFF3D3D).withValues(alpha: 0.55 + 0.4 * prog);
      c.drawCircle(Offset(f.x, f.y), f.r, _s);
    }
  }

  // ---- players ------------------------------------------------------------

  double _weaponAim(ArenaPlayer p, DarkomLook look) {
    if (p.swingT >= 0 && p.swingDur > 0) {
      final double t = (p.swingT / p.swingDur).clamp(0.0, 1.0).toDouble();
      switch (p.swingKind) {
        case 'sword':
          return p.swingAng + (-1.1 + 2.2 * t);
        case 'hammer':
          return p.swingAng + (t < 0.55 ? -1.5 * (1 - t / 0.55) - 0.1 : 0.3 * (1 - (t - 0.55) / 0.45));
        default:
          return p.swingAng;
      }
    }
    return p.aim;
  }

  void _player(Canvas c, ArenaPlayer p) {
    final DarkomLook look = p.look;
    final Color ring = arenaRingFor(g, p);
    final bool mine = identical(p, g.me);
    if (!p.alive) {
      _s
        ..strokeWidth = 3
        ..color = ring.withValues(alpha: 0.5);
      c.drawLine(Offset(p.x - 9, p.y - 9), Offset(p.x + 9, p.y + 9), _s);
      c.drawLine(Offset(p.x + 9, p.y - 9), Offset(p.x - 9, p.y + 9), _s);
      return;
    }
    // shadow and ring
    c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y + 3), width: 30, height: 11), _p..color = const Color(0x77000000));
    _s
      ..strokeWidth = 2
      ..color = ring.withValues(alpha: 0.85);
    c.drawOval(Rect.fromCenter(center: Offset(p.x, p.y + 3), width: 34, height: 14), _s);
    final bool dashing = mine ? g.dashT > 0 : (p.flags & 2) != 0;
    final bool guarding = mine ? g.guard > 0 : (p.flags & 1) != 0;
    final bool charging = mine ? g.chargeT > 0 : (p.flags & 4) != 0;
    final bool stunned = mine ? g.stunT > 0 : (p.flags & 16) != 0;
    if (dashing || charging) {
      c.drawCircle(Offset(p.x, p.y - 10), 22, _p..color = ring.withValues(alpha: 0.18));
    }
    final bool axeOut = p.weapon == 'axe' && g.axes.any((ArAxe a) => a.owner == p.id && !a.dead);
    final bool swinging = p.swingT >= 0;
    final double aim = _weaponAim(p, look);
    final double alpha = dashing ? 0.55 : 1.0;
    if (alpha < 0.99) c.saveLayer(Rect.fromLTWH(p.x - 60, p.y - 90, 120, 130), Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    paintDarkomLook(
      c,
      look,
      p.x,
      p.y,
      phase: p.phase,
      moving: p.moving,
      facing: p.face,
      aim: aim,
      showWeapon: !axeOut,
      weaponLen: swinging ? 56 : 46,
      swing: swinging ? (p.swingT / (p.swingDur <= 0 ? 1.0 : p.swingDur)).clamp(0.0, 1.0).toDouble() : -1.0,
      time: g.clock,
      priority: true,
    );
    if (alpha < 0.99) c.restore();
    if (guarding || charging) {
      final double fa = mine ? g.face : p.aim;
      _s
        ..strokeWidth = 4
        ..color = const Color(0xFF80D8FF).withValues(alpha: 0.9);
      c.drawArc(Rect.fromCircle(center: Offset(p.x, p.y - 8), radius: 30), fa - 1.22, 2.44, false, _s);
    }
    if (stunned) {
      for (int i = 0; i < 3; i++) {
        final double a = g.clock * 8 + i * 2.1;
        c.drawCircle(Offset(p.x + cos(a) * 12, p.y - 52 + sin(a) * 4), 2.4, _p..color = const Color(0xFFFFD54F));
      }
    }
    if (p.flash > 0 || (mine && g.hitFlash > 0)) {
      c.drawCircle(Offset(p.x, p.y - 12), 20, _p..color = const Color(0xFFFFFFFF).withValues(alpha: 0.3));
    }
    paintDarkomNameTag(c, look, p.x, p.y, scale: 0.9, nameColor: mine ? _cyan : Colors.white);
    // health bar under the feet
    const double bw = 38;
    final double f = (p.hp / kArHp).clamp(0.0, 1.0).toDouble();
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.x - bw / 2, p.y + 12, bw, 5), const Radius.circular(3)), _p..color = const Color(0xAA000000));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(p.x - bw / 2, p.y + 12, bw * f, 5), const Radius.circular(3)), _p..color = f < 0.3 ? const Color(0xFFFF5252) : const Color(0xFF69F0AE));
    if (p.emoteT > 0 && p.emote.isNotEmpty) {
      _text(c, p.emote, Offset(p.x, p.y - 86), 14, const Color(0xFFFFD54F));
    }
  }

  // ---- projectiles and effects --------------------------------------------

  WeaponPainter? _painterFor(String owner) {
    final ArenaPlayer? o = g.players[owner];
    if (o == null) return null;
    final String key = '$owner|${o.look.weaponKind}';
    WeaponPainter? w = _wp[key];
    if (w == null) {
      if (_wp.length > 12) _wp.clear();
      w = WeaponPainter(asset: o.look.weaponAsset);
      _wp[key] = w;
    }
    return w;
  }

  void _axe(Canvas c, ArAxe a) {
    final WeaponPainter? w = _painterFor(a.owner);
    final ArenaPlayer? o = g.players[a.owner];
    final Color col = o == null ? _cyan : arWeaponColor(o.look);
    c.drawCircle(Offset(a.x, a.y), 16, _p..color = col.withValues(alpha: 0.18));
    if (w == null) return;
    const double len = 42;
    c.save();
    c.translate(a.x, a.y);
    c.rotate(a.spin);
    c.translate(-len / 2, -len / 2);
    w.paint(c, const Size(len, len));
    c.restore();
  }

  void _bolt(Canvas c, ArProj b) {
    final ArenaPlayer? o = g.players[b.owner];
    final Color col = o == null ? _cyan : arWeaponColor(o.look);
    final double ang = atan2(b.vy, b.vx);
    _s
      ..strokeWidth = b.r * 0.9
      ..strokeCap = StrokeCap.round
      ..color = col.withValues(alpha: 0.35);
    c.drawLine(Offset(b.x, b.y), Offset(b.x - cos(ang) * 22, b.y - sin(ang) * 22), _s);
    _s.strokeCap = StrokeCap.butt;
    c.drawCircle(Offset(b.x, b.y), b.r + 3, _p..color = col.withValues(alpha: 0.3));
    c.drawCircle(Offset(b.x, b.y), b.r, _p..color = col);
    c.drawCircle(Offset(b.x, b.y), b.r * 0.5, _p..color = const Color(0xFFFFFFFF));
  }

  void _fx(Canvas c) {
    for (final ArFx f in g.fx) {
      if (f.delay > 0) continue;
      final double t = (1 - f.life / f.maxLife).clamp(0.0, 1.0).toDouble();
      final double a = (1 - t).clamp(0.0, 1.0).toDouble();
      switch (f.kind) {
        case 0:
          _s
            ..strokeWidth = 3.5 * a + 1
            ..color = f.color.withValues(alpha: a * 0.9);
          c.drawCircle(Offset(f.x, f.y), f.r * (0.35 + 0.65 * t), _s);
          break;
        case 1: {
          final Rect r = Rect.fromCircle(center: Offset(f.x, f.y), radius: f.r * (0.6 + 0.4 * t));
          _s
            ..strokeWidth = 9 * a + 2
            ..color = f.color.withValues(alpha: a * 0.8);
          c.drawArc(r, f.a - f.sweep / 2, f.sweep, false, _s);
          _s
            ..strokeWidth = 2
            ..color = const Color(0xFFFFFFFF).withValues(alpha: a * 0.9);
          c.drawArc(r, f.a - f.sweep / 2, f.sweep, false, _s);
          break;
        }
        case 2:
          c.drawCircle(Offset(f.x, f.y), f.r * (0.6 + 0.6 * t), _p..color = f.color.withValues(alpha: a * 0.6));
          break;
        default:
          break;
      }
    }
  }
}

/// Floating joystick, drawn above the arena.
class ArenaStickPainter extends CustomPainter {
  final Offset? Function() origin;
  final Offset Function() knob;
  ArenaStickPainter({required this.origin, required this.knob, required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset? so = origin();
    if (so == null) return;
    final Paint p = Paint();
    p.color = Colors.white.withValues(alpha: 0.10);
    canvas.drawCircle(so, 58, p);
    p.style = PaintingStyle.stroke;
    p.strokeWidth = 2;
    p.color = _cyan.withValues(alpha: 0.5);
    canvas.drawCircle(so, 58, p);
    p.style = PaintingStyle.fill;
    p.color = _cyan.withValues(alpha: 0.55);
    canvas.drawCircle(so + knob(), 22, p);
  }

  @override
  bool shouldRepaint(covariant ArenaStickPainter old) => true;
}

/// A cooldown ring around an action button: full when charging, empty when ready.
class ArenaRingPainter extends CustomPainter {
  final ArenaGame g;
  final int which;
  final Color color;
  ArenaRingPainter(this.g, this.which, this.color, {required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final double cd = g.cdFrac(which);
    final Offset c = size.center(Offset.zero);
    final double r = size.shortestSide / 2 - 3;
    final Paint p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white12;
    canvas.drawCircle(c, r, p);
    p.color = cd > 0 ? Colors.white54 : color;
    final double sweep = 2 * pi * (cd > 0 ? 1 - cd : 1.0);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -pi / 2, sweep, false, p);
  }

  @override
  bool shouldRepaint(covariant ArenaRingPainter old) => true;
}

/// A player standing in the lobby: their real look, idle.
class ArenaLookPainter extends CustomPainter {
  final DarkomLook look;
  final bool ready;
  ArenaLookPainter(this.look, this.ready, {Listenable? repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.height / 110;
    paintDarkomLook(canvas, look, size.width / 2, size.height * 0.78, scale: s, aim: -0.4, weaponLen: 46, priority: true);
  }

  @override
  bool shouldRepaint(covariant ArenaLookPainter old) => old.look != look || old.ready != ready;
}
