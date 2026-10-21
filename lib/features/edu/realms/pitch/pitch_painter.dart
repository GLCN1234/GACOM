import 'dart:math';
import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'pitch_logic.dart';
import 'pitch_skins.dart';

/// Draws Set Piece: the pitch, the goal split into labelled zones, the wall,
/// the keeper and the ball in flight.
class PitchPainter extends CustomPainter {
  final PitchLogic g;
  final Paint _p = Paint();

  PitchPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final PitchSkin skin = g.skin;
    _p.shader = null;
    _grass(canvas, size, skin);
    _markings(canvas, size);
    _goal(canvas, size, skin);
    _wall(canvas, size, skin);
    _keeper(canvas, size, skin);
    _aim(canvas, size, skin);
    _taker(canvas, size, skin);
    _ball(canvas, size, skin);

    if (g.hitFlash > 0) {
      _p.color = const Color(0xFFFF1744).withValues(alpha: 0.22 * pcCl(g.hitFlash / 0.55, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
    if (g.goodFlash > 0) {
      _p.color = const Color(0xFF00E676).withValues(alpha: 0.14 * pcCl(g.goodFlash / 0.5, 0.0, 1.0));
      canvas.drawRect(Offset.zero & size, _p);
    }
  }

  void _grass(Canvas canvas, Size size, PitchSkin skin) {
    _p.color = skin.grass;
    canvas.drawRect(Offset.zero & size, _p);
    _p.color = skin.grassAlt;
    final double band = size.height / 9;
    for (int i = 0; i < 9; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * band, size.width, band), _p);
    }
  }

  void _markings(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = Colors.white.withValues(alpha: 0.5);
    // Goal area and six yard box, in perspective.
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.06, h * 0.46)
        ..lineTo(w * 0.94, h * 0.46)
        ..lineTo(w * 0.86, h * pcGoalY)
        ..lineTo(w * 0.14, h * pcGoalY)
        ..close(),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.30)
        ..lineTo(w * 0.76, h * 0.30)
        ..lineTo(w * 0.73, h * pcGoalY)
        ..lineTo(w * 0.27, h * pcGoalY)
        ..close(),
      line,
    );
    // The spot.
    _p.color = Colors.white.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(w * 0.5, h * pcSpotY), 3, _p);
  }

  /// The goal, split into one zone per answer. The labels are the answers, so
  /// the player reads the goal rather than a question panel.
  void _goal(Canvas canvas, Size size, PitchSkin skin) {
    final double w = size.width;
    final double h = size.height;
    final double top = h * (pcGoalY - 0.085);
    final double bottom = h * pcGoalY;
    final double left = w * pcGoalLeft;
    final double right = w * pcGoalRight;

    // Net.
    _p.color = Colors.black.withValues(alpha: 0.30);
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), _p);
    final Paint mesh = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.22);
    for (double x = left; x <= right; x += 11) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), mesh);
    }
    for (double y = top; y <= bottom; y += 11) {
      canvas.drawLine(Offset(left, y), Offset(right, y), mesh);
    }

    // Zones.
    final PcZoneData data = _zoneData();
    for (int i = 0; i < data.count; i++) {
      final double zl = left + (right - left) * i / data.count;
      final double zr = left + (right - left) * (i + 1) / data.count;
      final Rect r = Rect.fromLTRB(zl + 1.5, top + 1.5, zr - 1.5, bottom - 1.5);
      Color face = Colors.black.withValues(alpha: 0.42);
      Color edge = skin.accent.withValues(alpha: 0.8);
      if (g.lastZone == i) {
        final bool wasRight = data.answerZone == i;
        face = (wasRight ? const Color(0xFF1B5E20) : const Color(0xFF4E1414)).withValues(alpha: 0.85);
        edge = wasRight ? const Color(0xFF69F0AE) : const Color(0xFFFF8A80);
      } else if (g.phase == pcShow && data.answerZone == i) {
        face = const Color(0xFF1B5E20).withValues(alpha: 0.6);
        edge = const Color(0xFF69F0AE);
      }
      _p.color = face;
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(5)), _p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = edge,
      );
      if (data.labels.length > i) {
        RealmDraw.text(canvas, data.labels[i], r.center, pcCl(r.height * 0.30, 9.0, 15.0), Colors.white, maxWidth: r.width - 6, maxLines: 2);
      }
    }

    // Posts and bar.
    _p.color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(left - 5, top - 4, 5, bottom - top + 4), _p);
    canvas.drawRect(Rect.fromLTWH(right, top - 4, 5, bottom - top + 4), _p);
    canvas.drawRect(Rect.fromLTRB(left - 5, top - 5, right + 5, top), _p);
  }

  PcZoneData _zoneData() {
    final List<String> labels = <String>[];
    int answerZone = -1;
    final q = g.round;
    for (int i = 0; i < g.zones.length; i++) {
      final int idx = g.zones[i];
      if (q != null && idx >= 0 && idx < q.options.length) {
        labels.add(q.options[idx]);
        if (idx == q.answerIndex) answerZone = i;
      } else {
        labels.add('-');
      }
    }
    return PcZoneData(g.zones.length, labels, answerZone);
  }

  void _wall(Canvas canvas, Size size, PitchSkin skin) {
    // The wall wears the away kit so it never reads as your own team.
    final double w = size.width;
    final double h = size.height;
    final double y = h * pcWallY;
    final int n = 4;
    for (int i = 0; i < n; i++) {
      final double f = (i + 0.5) / n;
      final double x = w * (g.wallFrom + (g.wallTo - g.wallFrom) * f);
      final double jump = g.phase == pcFlight ? sin(g.time * 10 + i) * 3 : 0;
      RealmDraw.person(
        canvas,
        x,
        y - jump,
        facing: 1,
        shirt: const Color(0xFFD32F2F),
        pants: const Color(0xFF212121),
        scale: 0.9,
      );
    }
    // A line on the grass showing the wall's span, so the gap is readable.
    _p.color = skin.kitTrim.withValues(alpha: 0.12);
    canvas.drawRect(Rect.fromLTRB(w * g.wallFrom, y + 16, w * g.wallTo, y + 20), _p);
  }

  void _keeper(Canvas canvas, Size size, PitchSkin skin) {
    final double w = size.width;
    final double h = size.height;
    RealmDraw.person(
      canvas,
      w * g.keeperX,
      h * (pcGoalY + 0.045),
      facing: 1,
      moving: g.phase == pcAim,
      phase: g.time * 7,
      shirt: skin.keeper,
      pants: const Color(0xFF263238),
      scale: 0.95,
    );
  }

  /// The aim guide while the player is dragging: where the ball is headed.
  void _aim(Canvas canvas, Size size, PitchSkin skin) {
    if (g.phase != pcAim) return;
    final double mag = sqrt(g.aimX * g.aimX + g.aimY * g.aimY);
    if (mag < 0.12 || g.aimY >= -0.02) return;
    final double w = size.width;
    final double h = size.height;
    final double toX = pcCl(g.ballX + g.aimX * 1.15, 0.04, 0.96);
    final Offset from = Offset(w * g.ballX, h * pcSpotY);
    final Offset to = Offset(w * toX, h * pcGoalY);
    final Offset mid = Offset((from.dx + to.dx) / 2 + w * g.aimX * 0.22, (from.dy + to.dy) / 2);
    final Path p = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    canvas.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = skin.accent.withValues(alpha: 0.30 + 0.45 * pcCl(mag, 0.0, 1.0)),
    );
    _p.color = skin.accent.withValues(alpha: 0.85);
    canvas.drawCircle(to, 6, _p);
  }

  void _taker(Canvas canvas, Size size, PitchSkin skin) {
    if (g.phase != pcAim) return;
    RealmDraw.person(
      canvas,
      size.width * (g.ballX - 0.07),
      size.height * (pcSpotY - 0.01),
      facing: 1,
      hero: true,
      scale: 1.05,
    );
  }

  void _ball(Canvas canvas, Size size, PitchSkin skin) {
    final double w = size.width;
    final double h = size.height;
    final Offset c = Offset(w * g.ballX, h * g.ballY - g.lift * h * 0.06);
    final double r = (w * 0.028) * (1 - 0.35 * pcCl((pcSpotY - g.ballY) / (pcSpotY - pcGoalY), 0.0, 1.0));
    RealmDraw.shadow(canvas, c.dx, h * g.ballY + 4, r * 2.2);
    _p.color = skin.ball;
    canvas.drawCircle(c, r, _p);
    _p.color = const Color(0xFF212121);
    for (int i = 0; i < 5; i++) {
      final double a = g.time * 6 + i * 1.256;
      canvas.drawCircle(Offset(c.dx + cos(a) * r * 0.45, c.dy + sin(a) * r * 0.45), r * 0.18, _p);
    }
  }

  @override
  bool shouldRepaint(PitchPainter old) => true;
}

/// The zone labels for one round, worked out once per frame.
class PcZoneData {
  final int count;
  final List<String> labels;
  final int answerZone;
  const PcZoneData(this.count, this.labels, this.answerZone);
}
