import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import 'rarity.dart';

/// Parses the small subset of SVG path data used by the weapon silhouettes
/// (absolute M L H V C Z) into a [Path].
Path parseWeaponPath(String d) {
  final Path path = Path();
  final List<String> tokens = RegExp(r'[MLHVCZ]|-?\d*\.?\d+').allMatches(d).map((Match m) => m.group(0)!).toList();
  final RegExp cmdRe = RegExp(r'^[A-Z]$');
  String cmd = '';
  double x = 0;
  double y = 0;
  int i = 0;
  double next() => double.parse(tokens[i++]);
  bool hasNum(int count) {
    if (i + count > tokens.length) return false;
    for (int k = 0; k < count; k++) {
      if (cmdRe.hasMatch(tokens[i + k])) return false;
    }
    return true;
  }

  while (i < tokens.length) {
    final String t = tokens[i];
    if (cmdRe.hasMatch(t)) {
      cmd = t;
      i++;
      if (cmd == 'Z') path.close();
      continue;
    }
    switch (cmd) {
      case 'M':
        if (!hasNum(2)) { i++; break; }
        x = next();
        y = next();
        path.moveTo(x, y);
        cmd = 'L';
        break;
      case 'L':
        if (!hasNum(2)) { i++; break; }
        x = next();
        y = next();
        path.lineTo(x, y);
        break;
      case 'H':
        x = next();
        path.lineTo(x, y);
        break;
      case 'V':
        y = next();
        path.lineTo(x, y);
        break;
      case 'C':
        if (!hasNum(6)) { i++; break; }
        final double x1 = next();
        final double y1 = next();
        final double x2 = next();
        final double y2 = next();
        x = next();
        y = next();
        path.cubicTo(x1, y1, x2, y2, x, y);
        break;
      default:
        i++;
    }
  }
  return path;
}

class _WeaponShape {
  final double rot;
  final String wood;
  final String metal;
  final String trim;
  final double hiFraction;
  const _WeaponShape(this.rot, this.wood, this.metal, this.trim, this.hiFraction);
}

/// Shapes from the Arsenal board, in a 100 x 100 box.
const Map<String, _WeaponShape> _shapes = {
  'hammer': _WeaponShape(30, 'M46 36 H54 V94 H46Z', 'M24 12 H76 V40 H24Z', 'M24 33 H76 V40 H24Z M45 60 H55 V65 H45Z', 0.25),
  'dagger': _WeaponShape(0, 'M46 66 H54 V84 H46Z', 'M50 4 L58 56 L50 64 L42 56Z M34 60 H66 V66 H34Z', 'M45 84 H55 V92 H45Z', 0.18),
  'shield': _WeaponShape(0, 'M0 0', 'M50 8 L86 20 V52 C86 74 68 88 50 94 C32 88 14 74 14 52 V20Z', 'M50 28 L66 50 L50 72 L34 50Z', 0.16),
  'sword': _WeaponShape(20, 'M46 66 H54 V86 H46Z', 'M50 2 L58 58 H42Z M30 58 H70 V65 H30Z', 'M45 86 H55 V94 H45Z', 0.18),
  'staff': _WeaponShape(15, 'M47 26 H53 V96 H47Z', 'M50 4 L62 18 L50 32 L38 18Z', 'M44 34 H56 V39 H44Z', 0.3),
  'axe': _WeaponShape(20, 'M46 14 H54 V96 H46Z', 'M54 14 C86 12 92 44 54 52Z', 'M54 14 C62 14 66 16 68 18 L54 28Z', 0.18),
};

/// A weapon skin drawn from a cosmetic asset map:
/// `{weapon, metal, hi, ex, w, glow?}`. Missing keys fall back to plain
/// steel, and an unknown weapon draws as a sword.
class WeaponArt extends StatefulWidget {
  final Map<String, dynamic> asset;
  final double size;
  final Rarity rarity;
  final bool animate;

  const WeaponArt({super.key, required this.asset, this.size = 96, this.rarity = Rarity.common, this.animate = true});

  /// Builds the art for a cosmetic_items row (or equipped embed).
  static Widget fromItem(Map<String, dynamic>? item, {double size = 96, bool animate = true}) {
    final dynamic a = item?['asset'];
    return WeaponArt(
      asset: a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{},
      size: size,
      rarity: Rarity.parse(item?['rarity']?.toString()),
      animate: animate,
    );
  }

  @override
  State<WeaponArt> createState() => _WeaponArtState();
}

class _WeaponArtState extends State<WeaponArt> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  }

  bool get _hasGlow => CosmeticsService.parseColor(widget.asset['glow']?.toString()) != null;

  void _sync() {
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final bool want = widget.animate && !reduce && widget.rarity == Rarity.mythic && _hasGlow;
    if (want) {
      if (!_ctl.isAnimating) _ctl.repeat(reverse: true);
    } else if (_ctl.isAnimating) {
      _ctl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WeaponArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(painter: WeaponPainter(asset: widget.asset, pulse: _ctl)),
    );
  }
}

class WeaponPainter extends CustomPainter {
  final Map<String, dynamic> asset;
  final Animation<double>? pulse;

  WeaponPainter({required this.asset, this.pulse}) : super(repaint: pulse);

  Color _c(String k, Color d) => CosmeticsService.parseColor(asset[k]?.toString()) ?? d;

  @override
  void paint(Canvas canvas, Size size) {
    final String kind = asset['weapon']?.toString() ?? 'sword';
    final _WeaponShape shape = _shapes[kind] ?? _shapes['sword']!;
    final Color metal = _c('metal', const Color(0xFF98A4B8));
    final Color hi = _c('hi', const Color(0xFFB8C4D8));
    final Color ex = _c('ex', const Color(0xFF6B7790));
    final Color wood = _c('w', const Color(0xFF7A4A2B));
    final Color? glow = CosmeticsService.parseColor(asset['glow']?.toString());

    final Path woodP = parseWeaponPath(shape.wood);
    final Path metalP = parseWeaponPath(shape.metal);
    final Path trimP = parseWeaponPath(shape.trim);

    final double k = math.min(size.width, size.height) / 100.0;
    canvas.save();
    canvas.translate((size.width - 100 * k) / 2, (size.height - 100 * k) / 2);
    canvas.scale(k, k);
    canvas.translate(50, 50);
    canvas.rotate(shape.rot * math.pi / 180.0);
    canvas.translate(-50, -50);

    if (glow != null) {
      final double t = pulse?.value ?? 0.0;
      final double sigma = 4.0 + 3.0 * t;
      final Paint g = Paint()
        ..color = glow.withValues(alpha: 0.55 + 0.35 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
      canvas.drawPath(metalP, g);
      canvas.drawPath(woodP, g);
    }

    canvas.drawPath(woodP, Paint()..color = wood);
    canvas.drawPath(metalP, Paint()..color = metal);

    // Highlight band, clipped to the metal.
    final Rect b = metalP.getBounds();
    final Rect band = Rect.fromLTWH(b.left, b.top, b.width, b.height * shape.hiFraction);
    canvas.save();
    canvas.clipPath(metalP);
    canvas.drawRect(band, Paint()..color = hi);
    canvas.restore();

    canvas.drawPath(trimP, Paint()..color = ex);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WeaponPainter old) => old.asset != asset || old.pulse != pulse;
}
