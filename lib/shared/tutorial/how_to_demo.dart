import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'how_to_model.dart';

/// A short looping animation that shows one tutorial step being played.
class HowToDemo extends StatefulWidget {
  final TutorialStep step;
  final Color color;
  const HowToDemo({super.key, required this.step, required this.color});

  @override
  State<HowToDemo> createState() => _HowToDemoState();
}

class _HowToDemoState extends State<HowToDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.color.withValues(alpha: 0.5), width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (BuildContext context, BoxConstraints cons) {
          return AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? _) => _stage(cons.maxWidth, cons.maxHeight, _c.value),
          );
        }),
      ),
    );
  }

  static double _seg(double t, double a, double b) {
    if (t <= a) return 0;
    if (t >= b) return 1;
    final double x = (t - a) / (b - a);
    return x * x * (3 - 2 * x);
  }

  Widget _icon(IconData i, double x, double y, double size, Color c, {double scale = 1, double opacity = 1}) {
    return Positioned(
      left: x - size / 2,
      top: y - size / 2,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(scale: scale, child: Icon(i, size: size, color: c)),
      ),
    );
  }

  Widget _stage(double w, double h, double t) {
    final TutorialStep s = widget.step;
    final Color col = widget.color;
    final List<Widget> ch = <Widget>[];
    final double cx = w / 2;
    final double cy = h / 2;
    final double isz = min(w, h) * 0.26;
    final double fsz = min(w, h) * 0.2;
    switch (s.demo) {
      case DemoKind.drag:
      case DemoKind.swipe: {
        final bool swipe = s.demo == DemoKind.swipe;
        final double len = min(w, h) * (swipe ? 0.5 : 0.42);
        double dxn = s.dx;
        double dyn = s.dy;
        final double m = sqrt(dxn * dxn + dyn * dyn);
        if (m > 0) {
          dxn /= m;
          dyn /= m;
        } else {
          dxn = 1;
        }
        final double p = swipe ? _seg(t, 0.15, 0.55) : _seg(t, 0.1, 0.7);
        final double fade = t > 0.85 ? 1 - (t - 0.85) / 0.15 : 1.0;
        final Offset a = Offset(cx - dxn * len, cy - dyn * len);
        final Offset b = Offset(cx + dxn * len, cy + dyn * len);
        final Offset f = Offset.lerp(a, b, p)!;
        ch.add(_icon(s.target, b.dx, b.dy, isz, col, scale: 1 + (p > 0.95 ? 0.18 : 0.0)));
        if (!swipe) {
          ch.add(Positioned(
            left: a.dx - 34,
            top: a.dy - 34,
            child: Container(width: 68, height: 68, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38, width: 2), color: Colors.white10)),
          ));
        } else {
          ch.add(CustomPaint(size: Size(w, h), painter: _TrailPainter(a, f, Colors.white.withValues(alpha: 0.55))));
        }
        final Offset hero = swipe ? Offset(cx, cy + h * 0.28) : Offset.lerp(a, b, _seg(t, 0.18, 0.78))!;
        ch.add(_icon(s.actor, hero.dx, hero.dy, isz * 0.9, Colors.white, opacity: swipe ? 0.0 : 1.0));
        ch.add(_icon(Icons.touch_app_rounded, f.dx + fsz * 0.25, f.dy + fsz * 0.45, fsz, Colors.white, opacity: fade));
        break;
      }
      case DemoKind.tap: {
        final double p = _seg(t, 0.2, 0.4);
        final double rel = _seg(t, 0.4, 0.55);
        final double press = p * (1 - rel);
        final double ring = _seg(t, 0.4, 0.8);
        ch.add(_icon(s.target, cx, cy, isz * 1.3, col, scale: 1 + press * -0.1 + (ring > 0 && ring < 1 ? 0.1 * sin(ring * pi) : 0.0)));
        if (ring > 0 && ring < 1) {
          ch.add(Positioned(
            left: cx - isz * (0.7 + ring),
            top: cy - isz * (0.7 + ring),
            child: Container(
              width: isz * (1.4 + 2 * ring),
              height: isz * (1.4 + 2 * ring),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col.withValues(alpha: 1 - ring), width: 3)),
            ),
          ));
        }
        ch.add(_icon(Icons.touch_app_rounded, cx + fsz * 0.25, cy + fsz * 0.45 + (1 - p) * h * 0.3 + press * 4, fsz, Colors.white, opacity: _seg(t, 0.05, 0.2) * (t > 0.9 ? 1.0 - (t - 0.9) / 0.1 : 1.0)));
        break;
      }
      case DemoKind.move: {
        final Offset a = Offset(w * 0.28, h * 0.58);
        final Offset b = Offset(w * 0.72, h * 0.58);
        final double pickP = _seg(t, 0.1, 0.25);
        final double slide = _seg(t, 0.5, 0.75);
        final Offset hero = Offset.lerp(a, b, slide)!;
        final bool picked = t > 0.25 && t < 0.75;
        ch.add(Positioned(
          left: b.dx - isz * 0.8,
          top: b.dy - isz * 0.8,
          child: Container(
            width: isz * 1.6,
            height: isz * 1.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col.withValues(alpha: t > 0.4 && t < 0.8 ? 0.9 : 0.35), width: 2),
              color: col.withValues(alpha: t > 0.4 && t < 0.8 ? 0.18 : 0.06),
            ),
          ),
        ));
        ch.add(Positioned(
          left: a.dx - isz * 0.8,
          top: a.dy - isz * 0.8,
          child: Container(
            width: isz * 1.6,
            height: isz * 1.6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: picked && slide < 0.1 ? Colors.white : Colors.white24, width: picked && slide < 0.1 ? 2.5 : 1),
            ),
          ),
        ));
        ch.add(_icon(s.actor, hero.dx, hero.dy, isz, Colors.white));
        ch.add(_icon(s.target, b.dx, b.dy - isz * 1.15, isz * 0.6, col, opacity: 0.8));
        final Offset fa = t < 0.45 ? a : Offset.lerp(a, b, _seg(t, 0.4, 0.5))!;
        final double fo = _seg(t, 0.02, 0.1) * (t > 0.85 ? 1.0 - (t - 0.85) / 0.15 : 1.0);
        final double tapDip = (t > 0.1 && t < 0.2 || t > 0.5 && t < 0.58) ? 5.0 : 0.0;
        ch.add(_icon(Icons.touch_app_rounded, fa.dx + fsz * 0.25, fa.dy + fsz * 0.5 + tapDip + (1 - pickP) * 6, fsz, Colors.white, opacity: fo));
        break;
      }
      case DemoKind.keys: {
        final List<String> keys = s.keys.isEmpty ? const <String>['W', 'A', 'S', 'D'] : s.keys;
        final bool wasd = keys.length == 4 && keys[0] == 'W' && keys[1] == 'A' && keys[2] == 'S' && keys[3] == 'D';
        final bool arrows = keys.length == 4 && keys[0] == 'UP';
        final int active = min(keys.length - 1, (t * keys.length).floor());
        final double ks = min(w, h) * 0.2;
        Widget cap(String k, bool on, {double? width}) => Container(
              width: width ?? ks,
              height: ks,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? col : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: on ? Colors.white : Colors.white30, width: on ? 2 : 1),
              ),
              child: Text(k, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: ks * 0.34)),
            );
        Widget pad;
        if (wasd || arrows) {
          final String up = wasd ? 'W' : 'UP';
          final String lf = wasd ? 'A' : 'LEFT';
          final String dn = wasd ? 'S' : 'DOWN';
          final String rt = wasd ? 'D' : 'RIGHT';
          final double kw = wasd ? ks : ks * 1.45;
          pad = Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            cap(up, active == 0, width: kw),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              cap(lf, active == 1, width: kw),
              const SizedBox(width: 4),
              cap(dn, active == 2, width: kw),
              const SizedBox(width: 4),
              cap(rt, active == 3, width: kw),
            ]),
          ]);
        } else {
          pad = Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            for (int i = 0; i < keys.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              cap(keys[i], i == active, width: keys[i].length > 2 ? ks * (0.9 + keys[i].length * 0.22) : ks),
            ],
          ]);
        }
        final double move = sin(t * 2 * pi);
        ch.add(_icon(s.target, w * 0.84, cy, isz * 0.9, col));
        ch.add(_icon(s.actor, w * 0.62 + move * w * 0.12, cy - h * 0.12, isz, Colors.white));
        ch.add(Positioned(left: w * 0.05, top: 0, bottom: 0, child: Center(child: pad)));
        break;
      }
      case DemoKind.choose: {
        final double pick = _seg(t, 0.35, 0.5);
        final double right = _seg(t, 0.5, 0.6);
        final double bw = w * 0.62;
        final double bh = h * 0.15;
        final double top = h * 0.3;
        ch.add(Positioned(
          left: (w - bw) / 2,
          top: h * 0.08,
          child: Container(
            width: bw,
            height: h * 0.15,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
            alignment: Alignment.center,
            child: Container(width: bw * 0.6, height: 6, decoration: BoxDecoration(color: Colors.white54, borderRadius: BorderRadius.circular(3))),
          ),
        ));
        for (int i = 0; i < 3; i++) {
          final bool isRight = i == 1;
          final Color base = Colors.white.withValues(alpha: 0.1);
          final Color fill = isRight ? Color.lerp(base, const Color(0xFF2E7D32), right)! : base;
          ch.add(Positioned(
            left: (w - bw) / 2,
            top: top + i * (bh + 6),
            child: Container(
              width: bw,
              height: bh,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isRight && right > 0.5 ? const Color(0xFF69F0AE) : Colors.white24),
              ),
              alignment: Alignment.center,
              child: isRight && right > 0.5
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Container(width: bw * (0.3 + 0.1 * i), height: 5, decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(3))),
            ),
          ));
        }
        final Offset fp = Offset.lerp(Offset(w * 0.8, h * 0.95), Offset(w * 0.6, top + (bh + 6) + bh / 2), pick)!;
        ch.add(_icon(Icons.touch_app_rounded, fp.dx + fsz * 0.2, fp.dy + fsz * 0.4, fsz, Colors.white, opacity: _seg(t, 0.1, 0.3) * (t > 0.9 ? 1.0 - (t - 0.9) / 0.1 : 1.0)));
        break;
      }
      case DemoKind.watch: {
        final double pulse = 0.5 + 0.5 * sin(t * 2 * pi);
        ch.add(_icon(s.actor, w * 0.3, cy, isz * 1.1, Colors.white, scale: 1 + 0.06 * pulse));
        ch.add(_icon(Icons.arrow_forward_rounded, cx, cy, isz * 0.6, Colors.white38));
        ch.add(_icon(s.target, w * 0.7, cy, isz * 1.1, col, scale: 1 + 0.12 * pulse));
        ch.add(Positioned(
          left: w * 0.7 - isz,
          top: cy - isz,
          child: Container(width: isz * 2, height: isz * 2, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: col.withValues(alpha: 0.5 * (1 - pulse)), width: 3))),
        ));
        break;
      }
    }
    return Stack(clipBehavior: Clip.hardEdge, children: ch);
  }
}

class _TrailPainter extends CustomPainter {
  final Offset a;
  final Offset b;
  final Color c;
  _TrailPainter(this.a, this.b, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = c
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(a, b, p);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => old.b != b || old.a != a;
}

/// Small coach bubble used under the demo.
class RyanBubble extends StatelessWidget {
  final String text;
  const RyanBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: GacomColors.deepOrange),
        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: const BorderRadius.only(topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14))),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
        ),
      ),
    ]);
  }
}
