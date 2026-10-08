import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/rarity.dart';

/// Kinds of feedback effect, from the Arsenal board.
enum FxKind { correct, wrong, reward, combo, levelUp, victory }

/// Short full-screen feedback overlays. Every call inserts one non-blocking
/// overlay entry that removes itself, and never throws.
class FeedbackFx {
  FeedbackFx._();

  static const Color _green = Color(0xFF4BD37B);
  static const Color _red = Color(0xFFFF4F66);

  /// Plays [kind]. [color] tints reward rays (pass the item's rarity colour)
  /// and is ignored by the other kinds. For a combo prefer [combo].
  static void play(BuildContext context, FxKind kind, {Color? color}) {
    _insert(context, kind, color: color, count: 0);
  }

  /// Shows an "x[n]" streak counter that warms in colour as [n] grows.
  static void combo(BuildContext context, int n) {
    _insert(context, FxKind.combo, count: n);
  }

  static void _insert(BuildContext context, FxKind kind, {Color? color, required int count}) {
    try {
      final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) return;
      final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      late OverlayEntry entry;
      bool removed = false;
      void done() {
        if (removed) return;
        removed = true;
        try {
          entry.remove();
        } catch (_) {}
      }

      entry = OverlayEntry(
        builder: (BuildContext _) => IgnorePointer(
          child: _FxOverlay(kind: kind, color: color, count: count, reduced: reduce, onDone: done),
        ),
      );
      overlay.insert(entry);
    } catch (_) {
      // Feedback is decoration. Never let it break a game.
    }
  }

  static int _tier(Color? c) {
    if (c == null) return 0;
    for (final Rarity r in Rarity.values) {
      if (r.color == c) return r.index;
    }
    return 0;
  }

  static Duration _duration(FxKind kind, Color? color, bool reduced) {
    if (reduced) return const Duration(milliseconds: 350);
    switch (kind) {
      case FxKind.correct:
        return const Duration(milliseconds: 400);
      case FxKind.wrong:
        return const Duration(milliseconds: 300);
      case FxKind.reward:
        return Duration(milliseconds: 700 + 250 * _tier(color));
      case FxKind.combo:
        return const Duration(milliseconds: 1000);
      case FxKind.levelUp:
        return const Duration(milliseconds: 900);
      case FxKind.victory:
        return const Duration(milliseconds: 800);
    }
  }
}

class _FxOverlay extends StatefulWidget {
  final FxKind kind;
  final Color? color;
  final int count;
  final bool reduced;
  final VoidCallback onDone;
  const _FxOverlay({required this.kind, required this.color, required this.count, required this.reduced, required this.onDone});

  @override
  State<_FxOverlay> createState() => _FxOverlayState();
}

class _FxOverlayState extends State<_FxOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: FeedbackFx._duration(widget.kind, widget.color, widget.reduced));
    _c.addStatusListener((AnimationStatus s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Color get _tint {
    switch (widget.kind) {
      case FxKind.correct:
        return FeedbackFx._green;
      case FxKind.wrong:
        return FeedbackFx._red;
      case FxKind.reward:
        return widget.color ?? Tac.gold;
      case FxKind.combo:
        return _comboColor(widget.count);
      case FxKind.levelUp:
        return Tac.gold;
      case FxKind.victory:
        return Colors.white;
    }
  }

  static Color _comboColor(int n) {
    const Color gold = Color(0xFFF6B93B);
    const Color orange = Color(0xFFFF8A3D);
    const Color red = Color(0xFFFF4F66);
    if (n <= 3) return gold;
    if (n <= 5) return Color.lerp(gold, orange, (n - 3) / 2.0) ?? orange;
    if (n <= 10) return Color.lerp(orange, red, (n - 5) / 5.0) ?? red;
    return red;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduced) {
      // Reduced motion: a short static wash, no movement.
      return AnimatedBuilder(
        animation: _c,
        builder: (BuildContext _, Widget? __) {
          final double a = 0.16 * math.sin(math.pi * _c.value);
          return SizedBox.expand(
            child: Stack(children: [
              Positioned.fill(child: ColoredBox(color: _tint.withValues(alpha: a))),
              if (widget.kind == FxKind.combo)
                Align(
                  alignment: const Alignment(0, -0.3),
                  child: Opacity(opacity: math.sin(math.pi * _c.value).clamp(0.0, 1.0).toDouble(), child: _comboText(1.0)),
                ),
            ]),
          );
        },
      );
    }
    if (widget.kind == FxKind.combo) {
      return AnimatedBuilder(
        animation: _c,
        builder: (BuildContext _, Widget? __) {
          final double t = _c.value;
          final double grow = Curves.easeOutBack.transform((t / 0.3).clamp(0.0, 1.0).toDouble());
          final double scale = 0.4 + 0.75 * grow;
          final double fade = t < 0.65 ? 1.0 : (1.0 - (t - 0.65) / 0.35).clamp(0.0, 1.0).toDouble();
          final double rise = t < 0.65 ? 0.0 : (t - 0.65) / 0.35 * 30.0;
          return SizedBox.expand(
            child: Align(
              alignment: const Alignment(0, -0.3),
              child: Opacity(
                opacity: fade,
                child: Transform.translate(offset: Offset(0, -rise), child: Transform.scale(scale: scale, child: _comboText(1.0))),
              ),
            ),
          );
        },
      );
    }
    return SizedBox.expand(
      child: RepaintBoundary(
        child: CustomPaint(painter: _FxPainter(_c, widget.kind, _tint, FeedbackFx._tier(widget.color))),
      ),
    );
  }

  Widget _comboText(double k) {
    final Color c = _tint;
    final int n = widget.count < 2 ? 2 : widget.count;
    final double size = (46 + math.min(n, 20) * 1.6) * k;
    return Text(
      'x$n',
      style: Tac.display(size: size, weight: FontWeight.w800, color: c, letter: 0).copyWith(
        decoration: TextDecoration.none,
        shadows: [Shadow(color: c.withValues(alpha: 0.8), blurRadius: 18), const Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  final Animation<double> anim;
  final FxKind kind;
  final Color color;
  final int tier;

  _FxPainter(this.anim, this.kind, this.color, this.tier) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final double t = anim.value;
    switch (kind) {
      case FxKind.correct:
        _correct(canvas, size, t);
        break;
      case FxKind.wrong:
        _wrong(canvas, size, t);
        break;
      case FxKind.reward:
        _reward(canvas, size, t);
        break;
      case FxKind.levelUp:
        _levelUp(canvas, size, t);
        break;
      case FxKind.victory:
        _victory(canvas, size, t);
        break;
      case FxKind.combo:
        break;
    }
  }

  void _correct(Canvas canvas, Size size, double t) {
    final Offset c = Offset(size.width / 2, size.height * 0.42);
    final double maxR = math.min(size.width, size.height) * 0.38;
    final Paint fill = Paint()..color = color.withValues(alpha: 0.5 * (1 - t));
    canvas.drawCircle(c, 18 + 10 * t, fill);
    for (int i = 0; i < 2; i++) {
      final double lt = ((t - i * 0.15) / (1 - i * 0.15)).clamp(0.0, 1.0).toDouble();
      if (lt <= 0) continue;
      final double r = maxR * Curves.easeOut.transform(lt);
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 4 : 2.5
        ..color = color.withValues(alpha: (i == 0 ? 0.7 : 0.4) * (1 - lt));
      canvas.drawCircle(c, r, ring);
    }
  }

  void _wrong(Canvas canvas, Size size, double t) {
    final Offset c = Offset(size.width / 2, size.height * 0.42);
    final double fade = (1 - t).clamp(0.0, 1.0).toDouble();
    // Soft red wash, kept gentle so it never feels punishing.
    final double r = math.min(size.width, size.height) * 0.6;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.22 * fade), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    final math.Random rnd = math.Random(11);
    final double reach = Curves.easeOut.transform((t / 0.45).clamp(0.0, 1.0).toDouble());
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.miter
      ..strokeCap = StrokeCap.square
      ..color = color.withValues(alpha: 0.7 * fade);
    const int n = 8;
    for (int i = 0; i < n; i++) {
      double ang = (i / n) * math.pi * 2 + rnd.nextDouble() * 0.4;
      final double len = (math.min(size.width, size.height) * (0.22 + rnd.nextDouble() * 0.2)) * reach;
      final Path p = Path()..moveTo(c.dx, c.dy);
      Offset cur = c;
      const int segs = 4;
      for (int s = 1; s <= segs; s++) {
        ang += (rnd.nextDouble() - 0.5) * 0.7;
        cur = cur + Offset(math.cos(ang), math.sin(ang)) * (len / segs);
        p.lineTo(cur.dx, cur.dy);
      }
      canvas.drawPath(p, line);
    }
  }

  void _reward(Canvas canvas, Size size, double t) {
    final Offset c = Offset(size.width / 2, size.height * 0.45);
    final double reach = math.sqrt(size.width * size.width + size.height * size.height);
    final double env = t < 0.2 ? t / 0.2 : (t > 0.65 ? (1 - (t - 0.65) / 0.35) : 1.0);
    final double a = env.clamp(0.0, 1.0).toDouble();
    final double glowR = reach * 0.35;
    canvas.drawCircle(
      c,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.5 * a), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: glowR)),
    );
    final int rays = 14 + tier * 3;
    final double half = (math.pi * 2 / rays) * 0.22;
    final double spin = t * (0.5 + 0.2 * tier);
    final double len = reach * (0.3 + 0.7 * Curves.easeOut.transform(math.min(1.0, t / 0.5)));
    final Paint rp = Paint()..color = color.withValues(alpha: 0.34 * a);
    for (int i = 0; i < rays; i++) {
      final double ang = spin + i * (math.pi * 2 / rays);
      final Path p = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(ang - half) * len, c.dy + math.sin(ang - half) * len)
        ..lineTo(c.dx + math.cos(ang + half) * len, c.dy + math.sin(ang + half) * len)
        ..close();
      canvas.drawPath(p, rp);
    }
  }

  void _levelUp(Canvas canvas, Size size, double t) {
    final double unit = math.min(size.width, size.height) * 0.28;
    final double cx = size.width / 2;
    final double startY = size.height * 0.72;
    final double endY = size.height * 0.3;
    for (int i = 0; i < 3; i++) {
      final double lt = ((t - i * 0.12) / 0.64).clamp(0.0, 1.0).toDouble();
      if (lt <= 0 || lt >= 1) continue;
      final double y = startY + (endY - startY) * Curves.easeOut.transform(lt);
      final double alpha = math.sin(math.pi * lt).clamp(0.0, 1.0).toDouble() * (i == 0 ? 1.0 : 0.7);
      final Path p = Path()
        ..moveTo(cx - unit * 0.5, y + unit * 0.25)
        ..lineTo(cx, y - unit * 0.25)
        ..lineTo(cx + unit * 0.5, y + unit * 0.25);
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = unit * 0.1
          ..strokeCap = StrokeCap.square
          ..strokeJoin = StrokeJoin.miter
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
      );
    }
  }

  void _victory(Canvas canvas, Size size, double t) {
    final Offset c = size.center(Offset.zero);
    final double diag = math.sqrt(size.width * size.width + size.height * size.height) * 0.6;
    final List<double> angles = [115.0, 65.0];
    final List<Color> cols = [Colors.white, const Color(0xFF2ED3E6)];
    for (int i = 0; i < 2; i++) {
      final double lt = ((t - i * 0.12) / 0.6).clamp(0.0, 1.0).toDouble();
      if (lt <= 0) continue;
      final double rad = angles[i] * math.pi / 180.0;
      final Offset dir = Offset(math.cos(rad), math.sin(rad));
      final double head = Curves.easeOut.transform(math.min(1.0, lt / 0.6));
      final double tail = lt < 0.5 ? 0.0 : Curves.easeIn.transform((lt - 0.5) / 0.5);
      final Offset a = c + dir * (-diag + 2 * diag * tail);
      final Offset b = c + dir * (-diag + 2 * diag * head);
      final Paint glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.square
        ..color = cols[i].withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      final Paint core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.square
        ..color = cols[i].withValues(alpha: 0.9);
      canvas.drawLine(a, b, glow);
      canvas.drawLine(a, b, core);
    }
    final double flash = (1 - (t / 0.4)).clamp(0.0, 1.0).toDouble();
    if (flash > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.12 * flash));
    }
  }

  @override
  bool shouldRepaint(covariant _FxPainter old) => old.kind != kind || old.color != color || old.tier != tier;
}
