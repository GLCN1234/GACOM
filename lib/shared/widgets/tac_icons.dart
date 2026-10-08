import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// One icon of the GACOM icon language: SVG path data in a 24 x 24 box and
/// the colour that carries its meaning.
class TacIconDef {
  final String d;
  final Color color;
  const TacIconDef(this.d, this.color);
}

/// The 16 HUD and menu icons from the Arsenal board. Gold is money and
/// rewards, red health and danger, cyan energy and action, green success,
/// violet rare things.
class TacIcons {
  TacIcons._();

  static const String coin = 'coin';
  static const String health = 'health';
  static const String energy = 'energy';
  static const String star = 'star';
  static const String gem = 'gem';
  static const String key = 'key';
  static const String locked = 'locked';
  static const String trophy = 'trophy';
  static const String timer = 'timer';
  static const String lesson = 'lesson';
  static const String science = 'science';
  static const String maths = 'maths';
  static const String chat = 'chat';
  static const String streak = 'streak';
  static const String gift = 'gift';
  static const String house = 'house';

  static const List<String> names = [
    coin, health, energy, star, gem, key, locked, trophy,
    timer, lesson, science, maths, chat, streak, gift, house,
  ];

  static const Map<String, TacIconDef> defs = {
    coin: TacIconDef('M12 3 A9 9 0 1 0 12.1 3 M9 9 H15 M9 15 H15 M12 7 V17', Color(0xFFF6B93B)),
    health: TacIconDef('M12 20 L4 12 A4.5 4.5 0 0 1 12 6 A4.5 4.5 0 0 1 20 12Z', Color(0xFFFF4F66)),
    energy: TacIconDef('M13 2 L5 14 H11 L10 22 L19 9 H13Z', Color(0xFF2ED3E6)),
    star: TacIconDef('M12 3 L14.6 9 L21 9.6 L16 14 L17.6 21 L12 17.4 L6.4 21 L8 14 L3 9.6 L9.4 9Z', Color(0xFFF6B93B)),
    gem: TacIconDef('M6 4 H18 L22 10 L12 21 L2 10Z M2 10 H22', Color(0xFFB060FF)),
    key: TacIconDef('M8 10 A4 4 0 1 0 8.1 10 M11 12 H21 M18 12 V16 M21 12 V15', Color(0xFFF6B93B)),
    locked: TacIconDef('M6 11 H18 V21 H6Z M8 11 V7 A4 4 0 0 1 16 7 V11', Color(0xFF93A3BF)),
    trophy: TacIconDef('M7 4 H17 V10 A5 5 0 0 1 7 10Z M7 6 H3 V8 A3 3 0 0 0 7 11 M17 6 H21 V8 A3 3 0 0 1 17 11 M12 15 V19 M8 20 H16', Color(0xFFF6B93B)),
    timer: TacIconDef('M12 7 V12 L15 14 M12 4 A8 8 0 1 0 12.1 4 M10 2 H14', Color(0xFF2ED3E6)),
    lesson: TacIconDef('M4 5 H11 A1 1 0 0 1 12 6 V20 A2 2 0 0 0 10 18 H4Z M20 5 H13 A1 1 0 0 0 12 6 V20 A2 2 0 0 1 14 18 H20Z', Color(0xFF3C9DFF)),
    science: TacIconDef('M9 3 H15 M10 3 V9 L4 20 H20 L14 9 V3 M7 15 H17', Color(0xFF4BD37B)),
    maths: TacIconDef('M6 3 H18 V21 H6Z M9 7 H15 M9 12 H10 M12 12 H13 M15 12 H15.1 M9 16 H10 M12 16 H13 M15 16 H15.1', Color(0xFF3C9DFF)),
    chat: TacIconDef('M4 5 H20 V16 H11 L6 20 V16 H4Z', Color(0xFF2ED3E6)),
    streak: TacIconDef('M12 3 C14 8 19 9 18 15 A6 6 0 0 1 6 15 C6 11 9 10 9 6 C10 7 11 6 12 3Z', Color(0xFFFF8A3D)),
    gift: TacIconDef('M4 10 H20 V21 H4Z M3 7 H21 V10 H3Z M12 7 V21 M12 7 C9 3 6 4 8 7 M12 7 C15 3 18 4 16 7', Color(0xFFB060FF)),
    house: TacIconDef('M12 3 L20 6 V12 C20 17 16 20 12 22 C8 20 4 17 4 12 V6Z', Color(0xFFF6B93B)),
  };

  /// The meaning colour of [name], or null for an unknown name.
  static Color? colorOf(String name) => defs[name]?.color;
}

String _hex(Color c) {
  String h(int v) => v.clamp(0, 255).toInt().toRadixString(16).padLeft(2, '0');
  return '#${h((c.value >> 16) & 0xFF)}${h((c.value >> 8) & 0xFF)}${h(c.value & 0xFF)}';
}

/// Draws one of the [TacIcons] as a 1.8 stroke, miter-join, square-cap line
/// icon. [color] overrides the meaning colour.
class TacIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  const TacIcon(this.name, {super.key, this.size = 24, this.color});

  static final Map<String, String> _cache = <String, String>{};

  static String svgFor(String name, Color color) {
    final TacIconDef? def = TacIcons.defs[name];
    if (def == null) return '';
    final String key = '$name|${_hex(color)}|${(((color.value >> 24) & 0xFF) / 255.0).toStringAsFixed(2)}';
    return _cache.putIfAbsent(key, () {
      final String op = ((color.value >> 24) & 0xFF) >= 255 ? '' : ' stroke-opacity="${(((color.value >> 24) & 0xFF) / 255.0).toStringAsFixed(2)}"';
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
          'stroke="${_hex(color)}"$op stroke-width="1.8" stroke-linejoin="miter" stroke-linecap="square">'
          '<path d="${def.d}"/></svg>';
    });
  }

  @override
  Widget build(BuildContext context) {
    final TacIconDef? def = TacIcons.defs[name];
    if (def == null) return SizedBox(width: size, height: size);
    final String svg = svgFor(name, color ?? def.color);
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.string(svg, width: size, height: size),
    );
  }
}
