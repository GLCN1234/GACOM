import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../shared/widgets/cosmetic_avatar.dart' show paintCosmeticTrail;
import '../../shared/widgets/weapon_art.dart';
import '../character3d/fighter3d.dart';
import '../character3d/rig.dart';
import '../edu/realms/realm_kit.dart' show RealmDraw;
import 'darkom_armory.dart';
import 'darkom_look.dart';

final Map<String, WeaponPainter> _weaponPainters = <String, WeaponPainter>{};

WeaponPainter _painterFor(DarkomLook look) {
  final String key = '${look.weaponKind}|${jsonEncode(look.weaponAsset)}';
  final WeaponPainter? p = _weaponPainters[key];
  if (p != null) return p;
  if (_weaponPainters.length > 40) _weaponPainters.clear();
  final WeaponPainter np = WeaponPainter(asset: look.weaponAsset);
  _weaponPainters[key] = np;
  return np;
}

final Expando<CharLook> _lookWith = Expando<CharLook>('lookWith');
final Expando<CharLook> _lookBare = Expando<CharLook>('lookBare');

CharLook _charLook(DarkomLook look, bool weapon) {
  final Expando<CharLook> cache = weapon ? _lookWith : _lookBare;
  final CharLook? hit = cache[look];
  if (hit != null) return hit;
  final CharLook made = CharLook.from(
    skin: look.skinColor,
    hair: look.hairColor,
    shirt: look.shirtColor,
    pants: look.pantsColor,
    hairStyle: look.hairStyle,
    weapon: weapon ? look.weaponKind : 'none',
    weaponAsset: look.weaponAsset,
    frameColors: look.frameColors,
  );
  cache[look] = made;
  return made;
}

/// Draws a player (any player, local or remote) at (x, y): outfit, hair,
/// trail and, when [showWeapon] is set, the weapon skin held at [aim].
/// Name and title are drawn by [paintDarkomNameTag].
void paintDarkomLook(
  Canvas canvas,
  DarkomLook look,
  double x,
  double y, {
  double phase = 0,
  bool moving = false,
  double facing = 1,
  double scale = 1.0,
  bool showWeapon = true,
  double aim = 0,
  double weaponLen = 46,
  double swing = -1,
  double time = 0,
  bool priority = false,
}) {
  // 3D first; it carries the weapon skin in the hand. Falls back to the flat person.
  final double face3 = swing >= 0 ? (cos(aim) >= 0 ? 1.0 : -1.0) : facing;
  final bool d3 = Fighter3D.draw(canvas, _charLook(look, showWeapon), x, y, phase: phase, moving: moving, facing: face3, scale: scale, swing: swing, time: time, priority: priority);
  canvas.save();
  canvas.translate(x, y);
  canvas.scale(scale, scale);
  if (!d3) {
    RealmDraw.person(
      canvas,
      0,
      0,
      phase: phase,
      moving: moving,
      facing: facing,
      shirt: look.shirtColor,
      pants: look.pantsColor,
      skin: look.skinColor,
      hair: look.hairColor,
      hairStyle: look.hairStyle,
    );
  }
  if (moving && look.trail != 'none') {
    canvas.save();
    paintCosmeticTrail(canvas, look.trail, look.trailTint, phase, facing >= 0 ? 1.0 : -1.0);
    canvas.restore();
  }
  if (showWeapon && !d3) {
    final double len = weaponLen;
    final double fwd = look.weaponKind == 'shield' ? len * 0.2 : len * 0.28;
    final double cx = cos(aim) * fwd;
    final double cy = -4 + sin(aim) * fwd;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(aim + pi / 2 - DarkomArmory.rotRad(look.weaponKind));
    canvas.translate(-len / 2, -len / 2);
    _painterFor(look).paint(canvas, Size(len, len));
    canvas.restore();
  }
  canvas.restore();
}

/// Name and title above a player at (x, y) (the feet position).
void paintDarkomNameTag(Canvas canvas, DarkomLook look, double x, double y, {double scale = 1.0, Color? nameColor}) {
  final double top = y - 58 * scale;
  if (look.title != null) {
    final TextPainter t = TextPainter(
      text: TextSpan(text: look.title, style: TextStyle(color: const Color(0xFFFFD54F), fontSize: 9 * scale, fontWeight: FontWeight.w700, shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)])),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '..',
    )..layout(maxWidth: 120 * scale);
    t.paint(canvas, Offset(x - t.width / 2, top - 12 * scale));
  }
  final TextPainter n = TextPainter(
    text: TextSpan(text: look.name, style: TextStyle(color: nameColor ?? Colors.white, fontSize: 11 * scale, fontWeight: FontWeight.w800, shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 3)])),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '..',
  )..layout(maxWidth: 110 * scale);
  n.paint(canvas, Offset(x - n.width / 2, top));
}
