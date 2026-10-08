import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the "Tactical Premium" identity layer.
class Tac {
  static const Color bg = Color(0xFF080C14);
  static const Color panel = Color(0xFF111826);
  static const Color panel2 = Color(0xFF0D1320);
  static const Color keyline = Color(0xFF2A3650);
  static const Color gold = Color(0xFFF6B93B);
  static const Color cyan = Color(0xFF2ED3E6);
  static const Color text = Color(0xFFE8EDF7);
  static const Color textDim = Color(0xFF8A96AD);
  static const Color ok = Color(0xFF34D399);
  static const Color danger = Color(0xFFFF4F66);

  /// Display face (Oxanium) for headings, numbers and labels.
  static TextStyle display({double size = 16, FontWeight weight = FontWeight.w700, Color color = text, double letter = 0.6, double? height}) {
    return GoogleFonts.oxanium(fontSize: size, fontWeight: weight, color: color, letterSpacing: letter, height: height);
  }

  /// Body face (Rajdhani), matching the rest of the app.
  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w600, Color color = text, double? height}) {
    return TextStyle(fontFamily: 'Rajdhani', fontSize: size, fontWeight: weight, color: color, height: height);
  }

  /// 12500 -> N12,500
  static String naira(num amount) {
    final s = amount.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '₦$buf';
  }

  /// Parses an ISO timestamp from json, or null.
  static DateTime? time(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  /// Reads a json number as int without ever casting to int directly.
  static int intOf(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;
}

/// Rarity ladder. Mythic is never sold, only earned.
enum Rarity {
  common,
  rare,
  epic,
  legendary,
  mythic;

  static Rarity parse(String? s) {
    switch (s?.toLowerCase().trim()) {
      case 'rare':
        return Rarity.rare;
      case 'epic':
        return Rarity.epic;
      case 'legendary':
        return Rarity.legendary;
      case 'mythic':
        return Rarity.mythic;
      default:
        return Rarity.common;
    }
  }

  Color get color {
    switch (this) {
      case Rarity.common:
        return const Color(0xFF98A4B8);
      case Rarity.rare:
        return const Color(0xFF3C9DFF);
      case Rarity.epic:
        return const Color(0xFFB060FF);
      case Rarity.legendary:
        return const Color(0xFFFFB11F);
      case Rarity.mythic:
        return const Color(0xFFFF4F66);
    }
  }

  String get label {
    switch (this) {
      case Rarity.common:
        return 'COMMON';
      case Rarity.rare:
        return 'RARE';
      case Rarity.epic:
        return 'EPIC';
      case Rarity.legendary:
        return 'LEGENDARY';
      case Rarity.mythic:
        return 'MYTHIC';
    }
  }

  /// Epic and above get a glow.
  bool get glows => index >= Rarity.epic.index;
}

/// A rectangle with 45 degree cut corners and an optional keyline.
class ChamferedBorder extends ShapeBorder {
  final double cut;
  final BorderSide side;
  final bool tl;
  final bool tr;
  final bool br;
  final bool bl;

  const ChamferedBorder({this.cut = 12, this.side = BorderSide.none, this.tl = true, this.tr = false, this.br = true, this.bl = false});

  static Path buildPath(Rect r, double cut, bool tl, bool tr, bool br, bool bl) {
    final double c = math.max(0.0, math.min(cut, math.min(r.width, r.height) / 2));
    final Path p = Path();
    p.moveTo(r.left + (tl ? c : 0), r.top);
    p.lineTo(r.right - (tr ? c : 0), r.top);
    if (tr) p.lineTo(r.right, r.top + c);
    p.lineTo(r.right, r.bottom - (br ? c : 0));
    if (br) p.lineTo(r.right - c, r.bottom);
    p.lineTo(r.left + (bl ? c : 0), r.bottom);
    if (bl) p.lineTo(r.left, r.bottom - c);
    p.lineTo(r.left, r.top + (tl ? c : 0));
    p.close();
    return p;
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) => ChamferedBorder(cut: cut * t, side: side.scale(t), tl: tl, tr: tr, br: br, bl: bl);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      buildPath(rect.deflate(side.width), math.max(0.0, cut - side.width * 0.4), tl, tr, br, bl);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => buildPath(rect, cut, tl, tr, br, bl);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final Paint paint = side.toPaint()..strokeJoin = StrokeJoin.miter;
    canvas.drawPath(buildPath(rect.deflate(side.width / 2), cut, tl, tr, br, bl), paint);
  }
}

/// Dark panel with chamfered corners and a keyline.
class TacticalPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? keyline;
  final double cut;
  final double lineWidth;
  final List<BoxShadow>? glow;
  final VoidCallback? onTap;

  const TacticalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.keyline,
    this.cut = 12,
    this.lineWidth = 1,
    this.glow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ChamferedBorder shape = ChamferedBorder(cut: cut, side: BorderSide(color: keyline ?? Tac.keyline, width: lineWidth));
    Widget w = DecoratedBox(
      decoration: ShapeDecoration(color: color ?? Tac.panel, shape: shape, shadows: glow),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap != null) {
      w = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: w);
    }
    return w;
  }
}

/// Panel keyed to a rarity: coloured keyline, glow for epic and up, an
/// animated shimmer for mythic.
class RarityCard extends StatelessWidget {
  final Rarity rarity;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final bool dimmed;
  final double cut;
  final VoidCallback? onTap;

  const RarityCard({
    super.key,
    required this.rarity,
    required this.child,
    this.padding = const EdgeInsets.all(10),
    this.selected = false,
    this.dimmed = false,
    this.cut = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color rc = rarity.color;
    final ChamferedBorder shape = ChamferedBorder(
      cut: cut,
      side: BorderSide(
        color: dimmed ? Tac.keyline : rc.withValues(alpha: selected ? 1.0 : 0.6),
        width: selected ? 1.7 : 1.1,
      ),
    );
    final List<BoxShadow>? shadows = (rarity.glows && !dimmed)
        ? [BoxShadow(color: rc.withValues(alpha: rarity == Rarity.mythic ? 0.38 : 0.24), blurRadius: selected ? 20 : 14)]
        : null;
    Widget w = DecoratedBox(
      decoration: ShapeDecoration(
        color: dimmed ? Tac.panel2 : null,
        gradient: dimmed
            ? null
            : LinearGradient(colors: [rc.withValues(alpha: 0.12), Tac.panel], begin: Alignment.topLeft, end: Alignment.bottomRight),
        shape: shape,
        shadows: shadows,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(padding: padding, child: child),
            if (rarity == Rarity.mythic && !dimmed) Positioned.fill(child: IgnorePointer(child: _MythicShimmer(color: rc))),
          ],
        ),
      ),
    );
    if (onTap != null) {
      w = GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: w);
    }
    return w;
  }
}

class _MythicShimmer extends StatefulWidget {
  final Color color;
  const _MythicShimmer({required this.color});
  @override
  State<_MythicShimmer> createState() => _MythicShimmerState();
}

class _MythicShimmerState extends State<_MythicShimmer> with SingleTickerProviderStateMixin {
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
  Widget build(BuildContext context) => CustomPaint(painter: _ShimmerPainter(_c, widget.color));
}

class _ShimmerPainter extends CustomPainter {
  final Animation<double> anim;
  final Color color;
  _ShimmerPainter(this.anim, this.color) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double bw = w * 0.28;
    final double skew = h * 0.5;
    final double x = -bw - skew + anim.value * (w + bw + skew * 2);
    final Path p = Path()
      ..moveTo(x + skew, 0)
      ..lineTo(x + skew + bw, 0)
      ..lineTo(x + bw, h)
      ..lineTo(x, h)
      ..close();
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: 0.16));
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) => old.color != color;
}

/// Small rarity tag.
class RarityChip extends StatelessWidget {
  final Rarity rarity;
  final bool compact;
  const RarityChip(this.rarity, {super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final Color rc = rarity.color;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: rc.withValues(alpha: 0.14),
        shape: ChamferedBorder(cut: compact ? 4 : 5, side: BorderSide(color: rc.withValues(alpha: 0.7), width: 0.8)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 1.5 : 3),
        child: Text(rarity.label, style: Tac.display(size: compact ? 9 : 10, weight: FontWeight.w800, color: rc, letter: 0.9)),
      ),
    );
  }
}

/// Chamfered button.
class TacButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;
  final bool loading;
  final IconData? icon;
  final double height;

  const TacButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Tac.gold,
    this.filled = true,
    this.loading = false,
    this.icon,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !loading;
    final Color fg = !enabled ? Tac.textDim : (filled ? Tac.bg : color);
    final ChamferedBorder shape = ChamferedBorder(cut: 8, side: BorderSide(color: enabled ? color : Tac.keyline, width: 1.2));
    return Material(
      color: (filled && enabled) ? color : Colors.transparent,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
            child: loading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 12, weight: FontWeight.w800, color: fg, letter: 0.8))),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live countdown to [until], ticking every second.
class CountdownText extends StatefulWidget {
  final DateTime? until;
  final String prefix;
  final String doneText;
  final TextStyle? style;
  const CountdownText({super.key, required this.until, this.prefix = '', this.doneText = 'Ended', this.style});

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    if (d.inDays >= 1) return '${d.inDays}d ${two(d.inHours % 24)}h ${two(d.inMinutes % 60)}m';
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? u = widget.until;
    if (u == null) return const SizedBox.shrink();
    final Duration d = u.difference(DateTime.now());
    final TextStyle st = widget.style ?? Tac.display(size: 11, color: Tac.textDim, letter: 0.8);
    return Text(d.isNegative ? widget.doneText : '${widget.prefix}${_fmt(d)}', style: st);
  }
}
