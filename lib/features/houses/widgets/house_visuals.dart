import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Colours offered when founding or editing a house.
const List<String> kHouseColors = ['#E84B00', '#00E5FF', '#8B5CF6', '#34D399', '#FFD700', '#E85B8A', '#3B82F6', '#EF4444'];

Color houseColor(String? hex) {
  if (hex == null) return const Color(0xFFE84B00);
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? const Color(0xFFE84B00) : Color(v);
}

IconData houseEmblemIcon(String? name) {
  switch (name) {
    case 'bolt_rounded': return Icons.bolt_rounded;
    case 'pets_rounded': return Icons.pets_rounded;
    case 'local_fire_department_rounded': return Icons.local_fire_department_rounded;
    case 'castle_rounded': return Icons.castle_rounded;
    case 'rocket_launch_rounded': return Icons.rocket_launch_rounded;
    case 'diamond_rounded': return Icons.diamond_rounded;
    case 'emoji_events_rounded': return Icons.emoji_events_rounded;
    case 'shield_rounded':
    default: return Icons.shield_rounded;
  }
}

LinearGradient houseBannerGradient(Map<String, dynamic>? banner, String? colorHex) {
  final from = banner?['from'];
  final to = banner?['to'];
  if (from is String && to is String) {
    return LinearGradient(colors: [houseColor(from), houseColor(to)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
  final c = houseColor(colorHex);
  return LinearGradient(colors: [c.withOpacity(0.6), GacomColors.surfaceDark], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

String formatPoints(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return n < 0 ? '-$buf' : buf.toString();
}

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// '2026-10-05' -> '5 Oct'
String formatWeekStart(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]}';
}

class HouseEmblem extends StatelessWidget {
  final String? emblem;
  final String? colorHex;
  final double size;
  const HouseEmblem({super.key, this.emblem, this.colorHex, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final c = houseColor(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: c.withOpacity(0.7), width: 1.5)),
      child: Icon(houseEmblemIcon(emblem), color: c, size: size * 0.52),
    );
  }
}

class HouseRoleChip extends StatelessWidget {
  final String role;
  const HouseRoleChip({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final Color c;
    final String label;
    switch (role) {
      case 'captain': c = GacomColors.gold; label = 'CAPTAIN'; break;
      case 'officer': c = GacomColors.accentCyan; label = 'OFFICER'; break;
      default: c = GacomColors.textSecondary; label = 'MEMBER';
    }
    return HouseChip(label: label, color: c);
  }
}

class HouseChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const HouseChip({super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 3)],
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ]),
      );
}

/// Row of colour swatches.
class HouseColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const HouseColorPicker({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: kHouseColors
            .map((c) => GestureDetector(
                  onTap: () => onChanged(c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: houseColor(c),
                      border: Border.all(color: selected.toUpperCase() == c ? Colors.white : Colors.transparent, width: 2.5),
                    ),
                    child: selected.toUpperCase() == c ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                  ),
                ))
            .toList(),
      );
}

Widget houseAvatar(String? url, String name, {double radius = 18}) {
  final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  return CircleAvatar(
    radius: radius,
    backgroundColor: GacomColors.elevatedCard,
    backgroundImage: (url != null && url.isNotEmpty) ? NetworkImage(url) : null,
    child: (url != null && url.isNotEmpty)
        ? null
        : Text(initial, style: TextStyle(color: GacomColors.textPrimary, fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
  );
}

TextStyle houseHeading({double size = 16, Color color = GacomColors.textPrimary}) =>
    TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: size, color: color);
