import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';

/// Hand drawn art for the newer cosmetic categories: emotes, sprays and
/// finishers, plus the drawn house emblems. Everything is vector code, no image
/// files, so it stays sharp at any size and weighs nothing.
///
/// An item's asset json looks like {"kind": "bolt", "color": "#FFD166"}.

const List<String> kShapeKinds = <String>['bolt', 'crown', 'flame', 'star', 'heart', 'skull', 'eye', 'trophy'];

Color artColor(Map<String, dynamic>? asset, [Color fallback = const Color(0xFFFFC53D)]) =>
    CosmeticsService.parseColor(asset?['color']?.toString()) ?? fallback;

Color artColor2(Map<String, dynamic>? asset, Color fallback) =>
    CosmeticsService.parseColor(asset?['color2']?.toString()) ?? fallback;

/// The outline of one symbol inside a square of side [s].
Path cosmeticShape(String kind, double s) {
  Offset p(double x, double y) => Offset(x * s, y * s);
  final Path path = Path();
  switch (kind) {
    case 'bolt':
      final List<Offset> pts = <Offset>[p(0.60, 0.02), p(0.20, 0.56), p(0.45, 0.56), p(0.36, 0.98), p(0.80, 0.40), p(0.54, 0.40), p(0.72, 0.02)];
      path.addPolygon(pts, true);
      break;
    case 'crown':
      path.addPolygon(<Offset>[p(0.06, 0.80), p(0.02, 0.26), p(0.27, 0.50), p(0.50, 0.14), p(0.73, 0.50), p(0.98, 0.26), p(0.94, 0.80)], true);
      break;
    case 'flame':
      path.moveTo(s * 0.50, s * 0.02);
      path.cubicTo(s * 0.62, s * 0.26, s * 0.88, s * 0.38, s * 0.86, s * 0.66);
      path.cubicTo(s * 0.85, s * 0.86, s * 0.68, s * 0.98, s * 0.50, s * 0.98);
      path.cubicTo(s * 0.32, s * 0.98, s * 0.14, s * 0.86, s * 0.14, s * 0.64);
      path.cubicTo(s * 0.14, s * 0.46, s * 0.30, s * 0.40, s * 0.36, s * 0.22);
      path.cubicTo(s * 0.44, s * 0.30, s * 0.46, s * 0.34, s * 0.50, s * 0.02);
      path.close();
      break;
    case 'star':
      final List<Offset> pts = <Offset>[];
      for (int i = 0; i < 10; i++) {
        final double r = i.isEven ? 0.5 : 0.21;
        final double a = -pi / 2 + i * pi / 5;
        pts.add(Offset(s * (0.5 + r * cos(a)), s * (0.54 + r * sin(a))));
      }
      path.addPolygon(pts, true);
      break;
    case 'heart':
      path.moveTo(s * 0.50, s * 0.92);
      path.cubicTo(s * 0.00, s * 0.56, s * 0.06, s * 0.10, s * 0.30, s * 0.10);
      path.cubicTo(s * 0.42, s * 0.10, s * 0.50, s * 0.20, s * 0.50, s * 0.28);
      path.cubicTo(s * 0.50, s * 0.20, s * 0.58, s * 0.10, s * 0.70, s * 0.10);
      path.cubicTo(s * 0.94, s * 0.10, s * 1.00, s * 0.56, s * 0.50, s * 0.92);
      path.close();
      break;
    case 'skull':
      final Path head = Path()..addOval(Rect.fromLTWH(s * 0.10, s * 0.04, s * 0.80, s * 0.70));
      final Path jaw = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.28, s * 0.58, s * 0.44, s * 0.38), Radius.circular(s * 0.08)));
      Path skull = Path.combine(PathOperation.union, head, jaw);
      final Path eyes = Path()
        ..addOval(Rect.fromLTWH(s * 0.22, s * 0.34, s * 0.22, s * 0.24))
        ..addOval(Rect.fromLTWH(s * 0.56, s * 0.34, s * 0.22, s * 0.24));
      final Path nose = Path()..addPolygon(<Offset>[p(0.50, 0.58), p(0.44, 0.70), p(0.56, 0.70)], true);
      final Path teeth = Path()
        ..addRect(Rect.fromLTWH(s * 0.38, s * 0.82, s * 0.04, s * 0.14))
        ..addRect(Rect.fromLTWH(s * 0.48, s * 0.82, s * 0.04, s * 0.14))
        ..addRect(Rect.fromLTWH(s * 0.58, s * 0.82, s * 0.04, s * 0.14));
      skull = Path.combine(PathOperation.difference, skull, eyes);
      skull = Path.combine(PathOperation.difference, skull, nose);
      skull = Path.combine(PathOperation.difference, skull, teeth);
      return skull;
    case 'eye':
      path.fillType = PathFillType.evenOdd;
      path.moveTo(s * 0.02, s * 0.50);
      path.quadraticBezierTo(s * 0.50, s * -0.16, s * 0.98, s * 0.50);
      path.quadraticBezierTo(s * 0.50, s * 1.16, s * 0.02, s * 0.50);
      path.close();
      path.addOval(Rect.fromCircle(center: p(0.5, 0.5), radius: s * 0.21));
      path.addOval(Rect.fromCircle(center: p(0.5, 0.5), radius: s * 0.09));
      break;
    case 'trophy':
      path.moveTo(s * 0.22, s * 0.06);
      path.lineTo(s * 0.78, s * 0.06);
      path.lineTo(s * 0.74, s * 0.46);
      path.quadraticBezierTo(s * 0.70, s * 0.64, s * 0.54, s * 0.68);
      path.lineTo(s * 0.54, s * 0.80);
      path.lineTo(s * 0.70, s * 0.84);
      path.lineTo(s * 0.70, s * 0.94);
      path.lineTo(s * 0.30, s * 0.94);
      path.lineTo(s * 0.30, s * 0.84);
      path.lineTo(s * 0.46, s * 0.80);
      path.lineTo(s * 0.46, s * 0.68);
      path.quadraticBezierTo(s * 0.30, s * 0.64, s * 0.26, s * 0.46);
      path.close();
      path.addOval(Rect.fromLTWH(s * 0.02, s * 0.12, s * 0.22, s * 0.28));
      path.addOval(Rect.fromLTWH(s * 0.76, s * 0.12, s * 0.22, s * 0.28));
      break;
    default:
      path.addOval(Rect.fromLTWH(s * 0.1, s * 0.1, s * 0.8, s * 0.8));
  }
  return path;
}

void _text(Canvas canvas, String t, Offset center, double size, Color color, {double letter = 0}) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900, fontFamily: 'Rajdhani', letterSpacing: letter)),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

// ---------------------------------------------------------------------------
// Emotes
// ---------------------------------------------------------------------------

/// A round glossy emote bubble. [t] runs 0..1 and loops the little pop.
class EmotePainter extends CustomPainter {
  final String kind;
  final Color color;
  final double t;
  const EmotePainter({required this.kind, required this.color, this.t = 0.25});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = min(size.width, size.height);
    final Offset c = size.center(Offset.zero);
    final double pop = 1 + 0.06 * sin(t * 2 * pi * 2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(pop, pop);
    canvas.translate(-c.dx, -c.dy);
    final double r = s * 0.46;
    // bubble
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: <Color>[Color.lerp(color, Colors.white, 0.10)!.withValues(alpha: 0.30), const Color(0xFF0B1020)],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = s * 0.035..color = color.withValues(alpha: 0.9));
    final double box = s * 0.56;
    canvas.save();
    canvas.translate(c.dx - box / 2, c.dy - box / 2);
    if (kind == 'gg') {
      canvas.restore();
      _text(canvas, 'GG', c, s * 0.42, color, letter: s * 0.01);
      canvas.save();
    } else if (kind == 'laugh') {
      final Offset o = Offset(box / 2, box / 2);
      canvas.drawCircle(o, box * 0.5, Paint()..color = const Color(0xFFFFD43B));
      final Paint dark = Paint()..color = const Color(0xFF3B2A06)..style = PaintingStyle.stroke..strokeWidth = box * 0.07..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(box * 0.22, box * 0.40), Offset(box * 0.38, box * 0.34), dark);
      canvas.drawLine(Offset(box * 0.22, box * 0.28), Offset(box * 0.38, box * 0.34), dark);
      canvas.drawLine(Offset(box * 0.78, box * 0.40), Offset(box * 0.62, box * 0.34), dark);
      canvas.drawLine(Offset(box * 0.78, box * 0.28), Offset(box * 0.62, box * 0.34), dark);
      final Path mouth = Path()
        ..moveTo(box * 0.2, box * 0.55)
        ..quadraticBezierTo(box * 0.5, box * 1.0, box * 0.8, box * 0.55)
        ..close();
      canvas.drawPath(mouth, Paint()..color = const Color(0xFF3B2A06));
      canvas.drawCircle(Offset(box * 0.12, box * 0.55 + 3 * sin(t * 2 * pi * 2)), box * 0.05, Paint()..color = const Color(0xFF63D2FF));
      canvas.drawCircle(Offset(box * 0.88, box * 0.55 + 3 * sin(t * 2 * pi * 2)), box * 0.05, Paint()..color = const Color(0xFF63D2FF));
    } else {
      final Path path = cosmeticShape(kind, box);
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = box * 0.03..color = Colors.white.withValues(alpha: 0.55));
    }
    canvas.restore();
    // orbiting sparkles
    for (int i = 0; i < 3; i++) {
      final double a = t * 2 * pi + i * 2 * pi / 3;
      final Offset sp = c + Offset(cos(a), sin(a)) * (r * 1.02);
      canvas.drawCircle(sp, s * 0.026, Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant EmotePainter old) => old.t != t || old.kind != kind || old.color != color;
}

/// Plays one emote: pops in, floats up, fades out, then calls [onDone].
class EmoteBurst extends StatefulWidget {
  final String kind;
  final Color color;
  final double size;
  final VoidCallback? onDone;
  const EmoteBurst({super.key, required this.kind, required this.color, this.size = 84, this.onDone});

  @override
  State<EmoteBurst> createState() => _EmoteBurstState();
}

class _EmoteBurstState extends State<EmoteBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          final double t = _c.value;
          final double inT = (t / 0.18).clamp(0.0, 1.0).toDouble();
          final double scale = Curves.elasticOut.transform(inT);
          final double fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: fade,
            child: Transform.translate(
              offset: Offset(0, -34 * t),
              child: Transform.scale(
                scale: scale,
                child: SizedBox(width: widget.size, height: widget.size, child: CustomPaint(painter: EmotePainter(kind: widget.kind, color: widget.color, t: t * 2))),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sprays
// ---------------------------------------------------------------------------

/// A stencil tag with soft spray edges, speckle and a few drips.
class SprayPainter extends CustomPainter {
  final String kind;
  final Color color;
  const SprayPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double s = min(size.width, size.height) * 0.78;
    final Offset o = Offset((size.width - s) / 2, (size.height - s) / 2 - s * 0.04);
    final Random rnd = Random(kind.hashCode & 0x7fffffff);
    canvas.save();
    canvas.translate(o.dx, o.dy);
    canvas.rotate(-0.06);
    // soft halo, then the body
    final Paint halo = Paint()..color = color.withValues(alpha: 0.38)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.07);
    final Paint body = Paint()..color = color.withValues(alpha: 0.94)..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.012);
    if (kind == 'g') {
      final Offset c = Offset(s / 2, s / 2);
      _text(canvas, 'G', c, s * 1.0, color.withValues(alpha: 0.38));
      _text(canvas, 'G', c, s * 0.92, color);
    } else {
      final Path p = cosmeticShape(kind, s);
      canvas.drawPath(p, halo);
      canvas.drawPath(p, body);
    }
    // speckle
    final Paint dot = Paint()..color = color.withValues(alpha: 0.55);
    for (int i = 0; i < 46; i++) {
      final double a = rnd.nextDouble() * 2 * pi;
      final double d = s * (0.46 + rnd.nextDouble() * 0.2);
      canvas.drawCircle(Offset(s / 2 + cos(a) * d, s / 2 + sin(a) * d), s * (0.004 + rnd.nextDouble() * 0.009), dot);
    }
    // drips
    final Paint drip = Paint()..color = color.withValues(alpha: 0.9)..strokeCap = StrokeCap.round..strokeWidth = s * 0.026;
    for (int i = 0; i < 3; i++) {
      final double x = s * (0.28 + i * 0.22 + rnd.nextDouble() * 0.05);
      final double y0 = s * (0.80 + rnd.nextDouble() * 0.08);
      final double len = s * (0.08 + rnd.nextDouble() * 0.12);
      canvas.drawLine(Offset(x, y0), Offset(x, y0 + len), drip);
      canvas.drawCircle(Offset(x, y0 + len), s * 0.022, drip);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SprayPainter old) => old.kind != kind || old.color != color;
}

class SprayArt extends StatelessWidget {
  final String kind;
  final Color color;
  final double size;
  const SprayArt({super.key, required this.kind, required this.color, this.size = 80});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: SprayPainter(kind: kind, color: color)));
}

// ---------------------------------------------------------------------------
// Finishers
// ---------------------------------------------------------------------------

double _ease(double x) {
  final double v = x.clamp(0.0, 1.0).toDouble();
  return 1 - pow(1 - v, 3).toDouble();
}

/// Full-area victory effect. [t] runs 0..1 once.
class FinisherPainter extends CustomPainter {
  final String kind;
  final Color color;
  final Color color2;
  final double t;
  const FinisherPainter({required this.kind, required this.color, required this.color2, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double m = max(size.width, size.height);
    final double fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0).toDouble();
    switch (kind) {
      case 'shockwave':
        for (int i = 0; i < 3; i++) {
          final double lt = ((t - i * 0.12) / 0.7).clamp(0.0, 1.0).toDouble();
          if (lt <= 0) continue;
          canvas.drawCircle(
            c,
            m * 0.62 * _ease(lt),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 14 * (1 - lt) + 2
              ..color = (i == 1 ? color2 : color).withValues(alpha: (1 - lt) * 0.9 * fade)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        if (t < 0.25) canvas.drawCircle(c, m * 0.12 * (1 - t / 0.25) + 6, Paint()..color = Colors.white.withValues(alpha: 1 - t / 0.25));
        break;
      case 'lightning':
        final Random rnd = Random(7);
        for (int b = 0; b < 6; b++) {
          final double flick = ((t * 14 + b).floor() % 2 == 0) ? 1.0 : 0.55;
          final double a = b * pi / 3 + 0.3 + rnd.nextDouble() * 0.4;
          final double reach = m * 0.55 * _ease(t / 0.35);
          final Path p = Path()..moveTo(c.dx, c.dy);
          Offset cur = c;
          const int seg = 9;
          for (int i = 1; i <= seg; i++) {
            final double d = reach * i / seg;
            final double off = (rnd.nextDouble() - 0.5) * m * 0.07;
            cur = c + Offset(cos(a) * d - sin(a) * off, sin(a) * d + cos(a) * off);
            p.lineTo(cur.dx, cur.dy);
          }
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..strokeJoin = StrokeJoin.round..color = color.withValues(alpha: 0.5 * fade * flick)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
          canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..strokeJoin = StrokeJoin.round..color = Colors.white.withValues(alpha: fade * flick));
        }
        canvas.drawCircle(c, 16 * fade, Paint()..color = color.withValues(alpha: 0.6 * fade)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        break;
      case 'slash':
        for (int i = 0; i < 3; i++) {
          final double lt = ((t - i * 0.1) / 0.3).clamp(0.0, 1.0).toDouble();
          if (lt <= 0) continue;
          final double ang = -0.9 + i * 0.75;
          final Offset dir = Offset(cos(ang), sin(ang));
          final Offset a0 = c - dir * m * 0.42 + Offset(0, (i - 1) * m * 0.05);
          final Offset a1 = a0 + dir * m * 0.84 * _ease(lt);
          final double a = (1 - max(0, (t - 0.5)) / 0.5).clamp(0.0, 1.0).toDouble();
          canvas.drawLine(a0, a1, Paint()..strokeCap = StrokeCap.round..strokeWidth = 16..color = color.withValues(alpha: 0.55 * a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          canvas.drawLine(a0, a1, Paint()..strokeCap = StrokeCap.round..strokeWidth = 3.2..color = Colors.white.withValues(alpha: a));
        }
        break;
      case 'nova':
        final double g = _ease(t / 0.6);
        canvas.drawCircle(
          c,
          m * 0.5 * g,
          Paint()
            ..shader = RadialGradient(colors: <Color>[Colors.white.withValues(alpha: 0.95 * fade), color.withValues(alpha: 0.55 * fade), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: max(1, m * 0.5 * g))),
        );
        for (int i = 0; i < 28; i++) {
          final double a = i * 2 * pi / 28;
          final double r0 = m * 0.10 * g;
          final double r1 = m * (0.28 + (i.isEven ? 0.22 : 0.10)) * g;
          canvas.drawLine(c + Offset(cos(a), sin(a)) * r0, c + Offset(cos(a), sin(a)) * r1, Paint()..strokeWidth = i.isEven ? 3 : 1.6..strokeCap = StrokeCap.round..color = (i % 3 == 0 ? color2 : color).withValues(alpha: 0.9 * fade));
        }
        break;
      case 'embers':
        final Random rnd = Random(11);
        for (int i = 0; i < 46; i++) {
          final double delay = rnd.nextDouble() * 0.35;
          final double lt = ((t - delay) / 0.65).clamp(0.0, 1.0).toDouble();
          if (lt <= 0 || lt >= 1) continue;
          final double x = size.width * (0.1 + rnd.nextDouble() * 0.8) + sin(lt * 7 + i) * 14;
          final double y = size.height * (1.02 - lt * (0.5 + rnd.nextDouble() * 0.6));
          final double r = 1.6 + rnd.nextDouble() * 3.2;
          canvas.drawCircle(Offset(x, y), r * 2.4, Paint()..color = color.withValues(alpha: 0.28 * (1 - lt))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          canvas.drawCircle(Offset(x, y), r, Paint()..color = Color.lerp(color2, color, lt)!.withValues(alpha: 1 - lt));
        }
        break;
      case 'fireworks':
        final List<Offset> centers = <Offset>[
          Offset(size.width * 0.28, size.height * 0.34),
          Offset(size.width * 0.72, size.height * 0.28),
          Offset(size.width * 0.5, size.height * 0.5),
        ];
        for (int k = 0; k < centers.length; k++) {
          final double lt = ((t - k * 0.16) / 0.6).clamp(0.0, 1.0).toDouble();
          if (lt <= 0 || lt >= 1) continue;
          final Color col = k == 1 ? color2 : color;
          for (int i = 0; i < 22; i++) {
            final double a = i * 2 * pi / 22;
            final double d = m * 0.2 * _ease(lt);
            final Offset p = centers[k] + Offset(cos(a) * d, sin(a) * d + 26 * lt * lt);
            canvas.drawCircle(p, 3.2 * (1 - lt) + 0.8, Paint()..color = col.withValues(alpha: 1 - lt));
            canvas.drawCircle(p, 7 * (1 - lt), Paint()..color = col.withValues(alpha: 0.25 * (1 - lt))..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
          }
        }
        break;
      default:
        canvas.drawCircle(c, m * 0.4 * _ease(t), Paint()..style = PaintingStyle.stroke..strokeWidth = 6..color = color.withValues(alpha: fade));
    }
  }

  @override
  bool shouldRepaint(covariant FinisherPainter old) => old.t != t || old.kind != kind;
}

/// Plays a finisher once over whatever it sits on, then calls [onDone].
class FinisherOverlay extends StatefulWidget {
  final String kind;
  final Color color;
  final Color color2;
  final VoidCallback? onDone;
  const FinisherOverlay({super.key, required this.kind, required this.color, required this.color2, this.onDone});

  @override
  State<FinisherOverlay> createState() => _FinisherOverlayState();
}

class _FinisherOverlayState extends State<FinisherOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) =>
            CustomPaint(size: Size.infinite, painter: FinisherPainter(kind: widget.kind, color: widget.color, color2: widget.color2, t: _c.value)),
      ),
    );
  }
}

/// A looping preview for shop and locker thumbnails.
class LoopArt extends StatefulWidget {
  final Duration period;
  final Widget Function(double t) builder;
  const LoopArt({super.key, required this.builder, this.period = const Duration(milliseconds: 2400)});

  @override
  State<LoopArt> createState() => _LoopArtState();
}

class _LoopArtState extends State<LoopArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _c, builder: (BuildContext context, Widget? _) => widget.builder(_c.value));
}

/// Thumbnail for an emote, spray or finisher catalogue item.
Widget cosmeticArtThumb(String category, Map<String, dynamic> asset, {double scale = 1.0}) {
  final String kind = asset['kind']?.toString() ?? 'star';
  final Color color = artColor(asset);
  final Color color2 = artColor2(asset, Colors.white);
  switch (category) {
    case 'emote':
      return LoopArt(builder: (double t) => SizedBox(width: 72 * scale, height: 72 * scale, child: CustomPaint(painter: EmotePainter(kind: kind, color: color, t: t))));
    case 'spray':
      return SprayArt(kind: kind, color: color, size: 76 * scale);
    case 'finisher':
      return LoopArt(
        period: const Duration(milliseconds: 2600),
        builder: (double t) => SizedBox(
          width: 96 * scale,
          height: 78 * scale,
          child: CustomPaint(painter: FinisherPainter(kind: kind, color: color, color2: color2, t: min(0.98, t * 1.15))),
        ),
      );
  }
  return const SizedBox.shrink();
}

/// A house emblem drawn from code. Emblem values look like "draw:crown".
class DrawnEmblemPainter extends CustomPainter {
  final String kind;
  final Color color;
  const DrawnEmblemPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final double s = min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final Path p = cosmeticShape(kind, s);
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = max(1, s * 0.03)..color = Colors.white.withValues(alpha: 0.5));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawnEmblemPainter old) => old.kind != kind || old.color != color;
}
