import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/edu/realms/realm_kit.dart' show RealmDraw;
import 'rarity.dart';

/// Colours of a frame ring from an equipped-row map (see
/// CosmeticsService.equipped) or a catalogue item. Null means no frame.
List<Color>? cosmeticFrameColors({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
  final Map? src = item ?? (equipped?['avatar_frame'] is Map ? equipped!['avatar_frame'] as Map : null);
  if (src == null) return null;
  final asset = src['asset'];
  if (asset is Map && asset['colors'] is List) {
    final cols = <Color>[];
    for (final c in (asset['colors'] as List)) {
      final col = CosmeticsService.parseColor(c?.toString());
      if (col != null) cols.add(col);
    }
    if (cols.isNotEmpty) return cols;
  }
  switch (src['value']?.toString()) {
    case 'bronze': return const [Color(0xFFCD7F32), Color(0xFF8D5524)];
    case 'gold': return const [Color(0xFFFFD700), Color(0xFFFFA000)];
    case 'flame': return const [Color(0xFFFF6D00), Color(0xFFFF1744)];
    default: return null;
  }
}

/// Frame style ("circuit", "adire", "voltage", "vault", "crest") from an
/// equipped-row map or catalogue item. Null for older plain-ring frames.
String? cosmeticFrameStyle({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
  final Map? src = item ?? (equipped?['avatar_frame'] is Map ? equipped!['avatar_frame'] as Map : null);
  if (src == null) return null;
  final asset = src['asset'];
  if (asset is Map && asset['style'] != null) return asset['style'].toString();
  return null;
}

/// Rarity of the equipped (or given) frame, or null when there is none.
Rarity? cosmeticFrameRarity({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
  final Map? src = item ?? (equipped?['avatar_frame'] is Map ? equipped!['avatar_frame'] as Map : null);
  if (src == null || src['rarity'] == null) return null;
  return Rarity.parse(src['rarity'].toString());
}

/// Equipped title text, or null.
String? cosmeticTitleFor(Map<String, dynamic>? equipped) => CosmeticsService.titleFor(equipped);

/// An avatar (photo or initial) with the equipped frame drawn as a ring.
class CosmeticAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final Map<String, dynamic>? equipped;
  /// Use a catalogue item instead of an equipped row (shop previews).
  final Map<String, dynamic>? frameItem;

  const CosmeticAvatar({super.key, this.avatarUrl, this.name = '', this.radius = 20, this.equipped, this.frameItem});

  @override
  Widget build(BuildContext context) {
    final colors = cosmeticFrameColors(equipped: equipped, item: frameItem);
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: GacomColors.cardDark,
      backgroundImage: hasUrl ? CachedNetworkImageProvider(avatarUrl!) : null,
      onBackgroundImageError: hasUrl ? (e, s) {} : null,
      child: hasUrl ? null : Text(initial, style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
    );
    if (colors == null) return avatar;
    final style = cosmeticFrameStyle(equipped: equipped, item: frameItem);
    final ring = max(2.0, radius * 0.14) * (style == 'vault' ? 1.7 : 1.0);
    final gap = max(1.5, radius * 0.07);
    final gradientColors = colors.length == 1 ? [colors[0], colors[0]] : colors;
    final base = Container(
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [...gradientColors, gradientColors.first]),
        boxShadow: [BoxShadow(color: gradientColors.first.withValues(alpha: 0.35), blurRadius: radius * 0.6)],
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: GacomColors.obsidian),
        child: avatar,
      ),
    );
    if (style == null) return base;
    final Color c1 = gradientColors.first;
    final Color c2 = gradientColors.last;
    final Widget overlay;
    switch (style) {
      case 'voltage':
        overlay = _VoltageOverlay(c1: c1, c2: c2, ring: ring);
        break;
      case 'circuit':
      case 'adire':
      case 'vault':
      case 'crest':
        overlay = CustomPaint(painter: _FrameStylePainter(style, c1, c2, ring));
        break;
      default:
        return base;
    }
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [base, Positioned.fill(child: IgnorePointer(child: overlay))],
    );
  }
}

/// Static detail painted over the ring for the pattern frame styles.
class _FrameStylePainter extends CustomPainter {
  final String style;
  final Color c1;
  final Color c2;
  final double ring;
  const _FrameStylePainter(this.style, this.c1, this.c2, this.ring);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double outer = size.width / 2;
    final double mid = outer - ring / 2;
    switch (style) {
      case 'circuit':
        _circuit(canvas, c, outer, mid);
        break;
      case 'adire':
        _adire(canvas, c, mid);
        break;
      case 'vault':
        _vault(canvas, c, outer, mid);
        break;
      case 'crest':
        _crest(canvas, c, mid);
        break;
    }
  }

  void _circuit(Canvas canvas, Offset c, double outer, double mid) {
    final Paint trace = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.8, ring * 0.18)
      ..strokeCap = StrokeCap.round;
    final Paint node = Paint()..color = Colors.white;
    final Paint dark = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring * 0.55;
    canvas.drawCircle(c, mid, dark);
    const int n = 12;
    for (int i = 0; i < n; i++) {
      final double a = i * 2 * pi / n + pi / 12;
      final Offset dir = Offset(cos(a), sin(a));
      if (i.isEven) {
        canvas.drawLine(c + dir * (mid - ring * 0.32), c + dir * (mid + ring * 0.32), trace);
        canvas.drawCircle(c + dir * (mid + ring * 0.32), max(0.8, ring * 0.17), node);
      } else {
        canvas.drawArc(Rect.fromCircle(center: c, radius: mid), a - 0.13, 0.26, false, trace);
        final double e = a + 0.13;
        canvas.drawCircle(c + Offset(cos(e), sin(e)) * mid, max(0.8, ring * 0.15), node);
      }
    }
  }

  void _adire(Canvas canvas, Offset c, double mid) {
    final Paint light = Paint()..color = Colors.white.withValues(alpha: 0.92);
    final Paint deep = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.75);
    const int n = 18;
    final double s = ring * 0.36;
    for (int i = 0; i < n; i++) {
      final double a = i * 2 * pi / n;
      canvas.save();
      canvas.translate(c.dx + cos(a) * mid, c.dy + sin(a) * mid);
      canvas.rotate(a + pi / 4);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s * 2, height: s * 2), i.isEven ? light : deep);
      canvas.restore();
      final double b = a + pi / n;
      canvas.drawCircle(c + Offset(cos(b), sin(b)) * mid, max(0.6, ring * 0.1), dot);
    }
  }

  void _vault(Canvas canvas, Offset c, double outer, double mid) {
    canvas.drawCircle(
        c,
        mid,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring * 0.24);
    canvas.drawCircle(
        c,
        outer - ring * 0.06,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, ring * 0.1));
    final Paint bolt = Paint()..color = const Color(0xFF5A3E00);
    final Paint hi = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (int i = 0; i < 8; i++) {
      final double a = i * pi / 4 + pi / 8;
      final Offset p = c + Offset(cos(a), sin(a)) * mid;
      canvas.drawCircle(p, ring * 0.17, bolt);
      canvas.drawCircle(p - Offset(ring * 0.04, ring * 0.04), ring * 0.06, hi);
    }
  }

  void _crest(Canvas canvas, Offset c, double mid) {
    final double cx = c.dx;
    final double cy = c.dy + mid;
    final double w = ring * 2.1;
    final double h = ring * 2.7;
    final Path shield = Path()
      ..moveTo(cx - w / 2, cy - h * 0.45)
      ..lineTo(cx + w / 2, cy - h * 0.45)
      ..lineTo(cx + w / 2, cy + h * 0.05)
      ..quadraticBezierTo(cx + w / 2, cy + h * 0.4, cx, cy + h * 0.55)
      ..quadraticBezierTo(cx - w / 2, cy + h * 0.4, cx - w / 2, cy + h * 0.05)
      ..close();
    canvas.drawPath(shield, Paint()..color = c1);
    canvas.drawPath(
        shield,
        Paint()
          ..color = Tac.bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(0.8, ring * 0.14));
    final Paint cross = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.7, ring * 0.12)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy - h * 0.3), Offset(cx, cy + h * 0.3), cross);
    canvas.drawLine(Offset(cx - w * 0.25, cy - h * 0.08), Offset(cx + w * 0.25, cy - h * 0.08), cross);
    // side studs
    final Paint stud = Paint()..color = c2;
    canvas.drawCircle(Offset(c.dx - mid, c.dy), ring * 0.2, stud);
    canvas.drawCircle(Offset(c.dx + mid, c.dy), ring * 0.2, stud);
    canvas.drawCircle(Offset(c.dx, c.dy - mid), ring * 0.2, stud);
  }

  @override
  bool shouldRepaint(covariant _FrameStylePainter old) =>
      old.style != style || old.c1 != c1 || old.c2 != c2 || old.ring != ring;
}

/// Animated electric arcs for the mythic voltage frame.
class _VoltageOverlay extends StatefulWidget {
  final Color c1;
  final Color c2;
  final double ring;
  const _VoltageOverlay({required this.c1, required this.c2, required this.ring});
  @override
  State<_VoltageOverlay> createState() => _VoltageOverlayState();
}

class _VoltageOverlayState extends State<_VoltageOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _VoltagePainter(widget.c1, widget.c2, widget.ring, _c));
}

class _VoltagePainter extends CustomPainter {
  final Color c1;
  final Color c2;
  final double ring;
  final Animation<double> t;
  _VoltagePainter(this.c1, this.c2, this.ring, this.t) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double mid = size.width / 2 - ring / 2;
    final int seed = (t.value * 14).floor();
    final double rot = t.value * 2 * pi;
    final Paint glow = Paint()
      ..color = c2.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring * 0.9
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final Paint core = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, ring * 0.2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (int k = 0; k < 5; k++) {
      final double start = rot * (k.isEven ? 0.5 : -0.5) + k * 2 * pi / 5;
      final Random rng = Random(seed * 13 + k);
      final Path path = Path();
      const int steps = 9;
      for (int s = 0; s <= steps; s++) {
        final double ang = start + 0.9 * s / steps;
        final double edge = (s == 0 || s == steps) ? 0.2 : 1.0;
        final double r = mid + (rng.nextDouble() - 0.5) * ring * 1.8 * edge;
        final Offset p = c + Offset(cos(ang), sin(ang)) * r;
        if (s == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  @override
  bool shouldRepaint(covariant _VoltagePainter old) => old.c1 != c1 || old.c2 != c2 || old.ring != ring;
}

/// The equipped title as a small tracked caps line, coloured by rarity.
/// Pass [title] directly, or an [equipped] row to read it from.
class TitleText extends StatelessWidget {
  final Map<String, dynamic>? equipped;
  final String? title;
  final double fontSize;
  final TextAlign? textAlign;
  const TitleText({super.key, this.equipped, this.title, this.fontSize = 12, this.textAlign});

  @override
  Widget build(BuildContext context) {
    final String? t = title ?? CosmeticsService.titleFor(equipped);
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    final Rarity r = Rarity.parse(CosmeticsService.rarityOf(equipped, 'title'));
    final Color col = r == Rarity.common ? Tac.gold : r.color;
    return Text(t.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: textAlign, style: Tac.display(size: fontSize, weight: FontWeight.w700, color: col, letter: 1.4));
  }
}

/// Draws a hero trail. Handles the newer kinds (lightning, dust, aura) here
/// and hands every other kind to [RealmDraw.heroTrail]. The canvas is already
/// translated to the hero; [fx] is 1 when facing right and -1 when left.
void paintCosmeticTrail(Canvas canvas, String kind, Color color, double phase, double fx) {
  switch (kind) {
    case 'lightning':
      final int seed = (phase * 0.35).floor();
      final double flick = 0.55 + 0.45 * sin(phase * 2.2).abs();
      final Paint glow = Paint()
        ..color = color.withValues(alpha: 0.28 * flick)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      final Paint core = Paint()
        ..color = Color.lerp(color, Colors.white, 0.6)!.withValues(alpha: 0.95 * flick)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (int i = 0; i < 3; i++) {
        final Random rng = Random(seed * 5 + i);
        final Path p = Path()..moveTo(-fx * 6, 2.0 + i * 7);
        for (int s = 1; s <= 6; s++) {
          p.lineTo(-fx * (6 + s * 7.0), 2.0 + i * 7 + (rng.nextDouble() - 0.5) * 12);
        }
        canvas.drawPath(p, glow);
        canvas.drawPath(p, core);
      }
      return;
    case 'dust':
      for (int i = 0; i < 9; i++) {
        double f = phase * 0.12 + i / 9;
        f = f - f.floorToDouble();
        final Random rng = Random(((phase * 0.12 + i / 9).floor()) * 11 + i);
        final double px = -fx * (6 + f * 34);
        final double py = 16 - f * 6 + (rng.nextDouble() - 0.5) * 6;
        final double r = 1.4 + f * 3.0;
        canvas.drawCircle(Offset(px, py), r, Paint()..color = color.withValues(alpha: 0.5 * (1 - f)));
      }
      return;
    case 'aura':
      final double pulse = 24 + sin(phase * 0.45) * 3;
      final Rect rect = Rect.fromCircle(center: const Offset(0, 2), radius: pulse);
      canvas.drawCircle(
          const Offset(0, 2),
          pulse,
          Paint()
            ..shader = RadialGradient(colors: [color.withValues(alpha: 0.0), color.withValues(alpha: 0.38), color.withValues(alpha: 0.0)], stops: const [0.55, 0.85, 1.0]).createShader(rect));
      canvas.drawCircle(
          const Offset(0, 2),
          pulse * 0.86,
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      return;
    default:
      RealmDraw.heroTrail(canvas, kind, color, phase, fx);
  }
}

/// A gradient banner from the equipped profile banner. When none is equipped
/// it shows [fallback] (or nothing visible if that is null).
class ProfileBanner extends StatelessWidget {
  final Map<String, dynamic>? equipped;
  final Map<String, dynamic>? bannerItem;
  final double? height;
  final Widget? fallback;
  final Widget? child;
  final BorderRadius? borderRadius;

  const ProfileBanner({super.key, this.equipped, this.bannerItem, this.height, this.fallback, this.child, this.borderRadius});

  /// The two gradient colours, or null when there is no banner.
  static List<Color>? colorsFor({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
    final Map? src = item ?? (equipped?['profile_banner'] is Map ? equipped!['profile_banner'] as Map : null);
    final asset = src?['asset'];
    if (asset is! Map) return null;
    final from = CosmeticsService.parseColor(asset['from']?.toString());
    final to = CosmeticsService.parseColor(asset['to']?.toString());
    if (from == null || to == null) return null;
    return [from, to];
  }

  /// Optional overlay pattern: waves, haze, grid, stripes or hex.
  static String? patternFor({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
    final Map? src = item ?? (equipped?['profile_banner'] is Map ? equipped!['profile_banner'] as Map : null);
    final asset = src?['asset'];
    if (asset is! Map || asset['pattern'] == null) return null;
    return asset['pattern'].toString();
  }

  @override
  Widget build(BuildContext context) {
    final cols = colorsFor(equipped: equipped, item: bannerItem);
    final pattern = patternFor(equipped: equipped, item: bannerItem);
    if (cols == null) {
      final fb = fallback ?? const SizedBox.shrink();
      return height == null ? fb : SizedBox(height: height, width: double.infinity, child: fb);
    }
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(colors: cols, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(fit: StackFit.expand, children: [
        if (pattern != null) CustomPaint(painter: _BannerPatternPainter(pattern)),
        CustomPaint(painter: _BannerShinePainter()),
        if (child != null) child!,
      ]),
    );
  }
}

class _BannerShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final path = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width * 0.75, 0)
      ..lineTo(size.width * 0.45, size.height)
      ..lineTo(size.width * 0.25, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _BannerPatternPainter extends CustomPainter {
  final String pattern;
  const _BannerPatternPainter(this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0 || !w.isFinite || !h.isFinite) return;
    final Paint line = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    switch (pattern) {
      case 'waves':
        for (int k = 0; k < 4; k++) {
          final double base = h * (0.22 + 0.17 * k);
          final double amp = h * 0.06;
          final Path p = Path()..moveTo(0, base);
          for (double x = 0; x <= w; x += 4) {
            p.lineTo(x, base + sin(x / w * 4 * pi + k) * amp);
          }
          canvas.drawPath(p, line);
        }
        break;
      case 'haze':
        final List<Offset> centers = [Offset(w * 0.2, h * 0.3), Offset(w * 0.65, h * 0.7), Offset(w * 0.9, h * 0.2)];
        final List<double> radii = [h * 0.9, h * 1.1, h * 0.7];
        for (int i = 0; i < centers.length; i++) {
          canvas.drawCircle(
              centers[i],
              radii[i],
              Paint()
                ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.0)])
                    .createShader(Rect.fromCircle(center: centers[i], radius: radii[i])));
        }
        break;
      case 'grid':
        final Paint g = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..strokeWidth = 1;
        for (double x = 0; x <= w; x += 22) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), g);
        }
        for (double y = 0; y <= h; y += 22) {
          canvas.drawLine(Offset(0, y), Offset(w, y), g);
        }
        break;
      case 'stripes':
        final Paint st = Paint()
          ..color = Colors.white.withValues(alpha: 0.07)
          ..strokeWidth = 6;
        for (double x = -h; x <= w; x += 20) {
          canvas.drawLine(Offset(x, h), Offset(x + h, 0), st);
        }
        break;
      case 'hex':
        const double r = 16;
        final double dx = r * 1.5;
        final double dy = r * 1.7320508;
        final Paint hx = Paint()
          ..color = Colors.white.withValues(alpha: 0.09)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        int col = 0;
        for (double x = 0; x <= w + r; x += dx, col++) {
          final double off = col.isOdd ? dy / 2 : 0;
          for (double y = -dy; y <= h + dy; y += dy) {
            final Path p = Path();
            for (int i = 0; i < 6; i++) {
              final double a = i * pi / 3;
              final Offset pt = Offset(x + cos(a) * r, y + off + sin(a) * r);
              if (i == 0) {
                p.moveTo(pt.dx, pt.dy);
              } else {
                p.lineTo(pt.dx, pt.dy);
              }
            }
            p.close();
            canvas.drawPath(p, hx);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BannerPatternPainter old) => old.pattern != pattern;
}
