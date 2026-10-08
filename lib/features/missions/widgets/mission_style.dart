import 'package:flutter/material.dart';

/// Colour constants for the Missions screens (Direction A, Tactical Premium).
class MTac {
  MTac._();
  static const Color ground = Color(0xFF080C14);
  static const Color panel = Color(0xFF111826);
  static const Color panelAlt = Color(0xFF0D1320);
  static const Color keyline = Color(0xFF2A3650);
  static const Color gold = Color(0xFFF6B93B);
  static const Color cyan = Color(0xFF2ED3E6);
  static const Color text = Color(0xFFE8EDF7);
  static const Color textDim = Color(0xFF98A4B8);
  static const Color textMuted = Color(0xFF6B7690);
  static const Color ok = Color(0xFF34D399);
  static const Color bad = Color(0xFFFF4F66);
  static const Color warn = Color(0xFFFFB020);
}

/// Rarity colours: common, rare, epic, legendary, mythic.
Color missionRarityColor(String? rarity) {
  switch ((rarity ?? '').toLowerCase()) {
    case 'rare':
      return const Color(0xFF3C9DFF);
    case 'epic':
      return const Color(0xFFB060FF);
    case 'legendary':
      return const Color(0xFFFFB11F);
    case 'mythic':
      return const Color(0xFFFF4F66);
    default:
      return const Color(0xFF98A4B8);
  }
}

TextStyle mHead({double size = 16, Color color = MTac.text, double letterSpacing = 0.6}) =>
    TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, color: color, letterSpacing: letterSpacing);

TextStyle mBody({double size = 13, Color color = MTac.textDim, FontWeight weight = FontWeight.w500}) =>
    TextStyle(fontFamily: 'Rajdhani', fontWeight: weight, fontSize: size, color: color, height: 1.3);

/// Path with the top-right and bottom-left corners cut at 45 degrees.
Path chamferPath(Size size, double cut) {
  final c = cut.clamp(0.0, size.shortestSide / 2).toDouble();
  return Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - c, 0)
    ..lineTo(size.width, c)
    ..lineTo(size.width, size.height)
    ..lineTo(c, size.height)
    ..lineTo(0, size.height - c)
    ..close();
}

class MChamferClipper extends CustomClipper<Path> {
  final double cut;
  const MChamferClipper({this.cut = 12});
  @override
  Path getClip(Size size) => chamferPath(size, cut);
  @override
  bool shouldReclip(covariant MChamferClipper old) => old.cut != cut;
}

class _ChamferPainter extends CustomPainter {
  final Color fill;
  final Color line;
  final double cut;
  final double width;
  const _ChamferPainter({required this.fill, required this.line, required this.cut, required this.width});
  @override
  void paint(Canvas canvas, Size size) {
    final path = chamferPath(size, cut);
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = width);
  }

  @override
  bool shouldRepaint(covariant _ChamferPainter old) =>
      old.fill != fill || old.line != line || old.cut != cut || old.width != width;
}

/// A panel with chamfered corners and a keyline border.
class MPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color fill;
  final Color line;
  final double cut;
  final EdgeInsetsGeometry margin;
  const MPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.fill = MTac.panel,
    this.line = MTac.keyline,
    this.cut = 12,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: CustomPaint(
          painter: _ChamferPainter(fill: fill, line: line, cut: cut, width: 1),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Small status chip such as IN PROGRESS or APPROVED.
class MChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const MChip({super.key, required this.label, required this.color, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          border: Border.all(color: color.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
          Text(label, style: mHead(size: 11, color: color, letterSpacing: 0.8)),
        ]),
      );
}

/// Name with a rarity colour dot.
class MItemTag extends StatelessWidget {
  final String name;
  final String? rarity;
  final Color? textColor;
  const MItemTag({super.key, required this.name, this.rarity, this.textColor});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: missionRarityColor(rarity), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mBody(size: 13, color: textColor ?? MTac.text, weight: FontWeight.w700))),
      ]);
}

/// Solid gold action button with a flat cut look.
class MButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final Color color;
  final bool outlined;
  final IconData? icon;
  const MButton({super.key, required this.label, required this.onTap, this.busy = false, this.color = MTac.gold, this.outlined = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final fg = outlined ? color : MTac.ground;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: ClipPath(
        clipper: const MChamferClipper(cut: 8),
        child: Material(
          color: outlined ? color.withOpacity(0.08) : color,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: outlined ? BoxDecoration(border: Border.all(color: color.withOpacity(0.7))) : null,
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
                else ...[
                  if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
                  Text(label, style: mHead(size: 14, color: fg, letterSpacing: 1)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration mField(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: mBody(color: MTac.textMuted),
      hintStyle: mBody(color: MTac.textMuted),
      filled: true,
      fillColor: MTac.panelAlt,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: MTac.keyline)),
      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: MTac.cyan)),
      border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: MTac.keyline)),
    );

const TextStyle kMInput = TextStyle(color: MTac.text, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15);

/// Human label for a cosmetic category.
String missionCategoryLabel(String? c) {
  if (c == null || c.isEmpty) return 'Item';
  if (c == 'house_banner') return 'Banner';
  if (c == 'house_emblem') return 'Emblem';
  final s = c.replaceAll('_', ' ');
  return s.substring(0, 1).toUpperCase() + s.substring(1);
}

const List<String> kMissionMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// '2026-10-14T23:00:00+00:00' -> '15 Oct, 00:00' (device time).
String missionWhen(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '');
  if (d == null) return '';
  final l = d.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${l.day} ${kMissionMonths[l.month - 1]}, $hh:$mm';
}
