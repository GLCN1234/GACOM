import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'g3d.dart';
import 'rig.dart';

/// Draws 3D fighters inside the 2D game canvases.
///
/// Each painter calls [begin] once per frame, then [draw] for every person. [draw]
/// returns false when it chose not to draw (3D switched off, or this frame's
/// budget is spent) and the caller paints its flat 2D person instead, so the game
/// never slows down: the local hero and arena fighters always get 3D, other
/// people get it while the per-frame budget lasts.
class Fighter3D {
  static const String _prefKey = 'fighter3d_on';

  /// Master switch, saved on the device.
  static bool enabled = true;
  static bool _loaded = false;
  static int _budget = 0;

  static final Map<int, CharRig> _rigs = <int, CharRig>{};
  static final Cam3D _cam = Cam3D();
  static final Paint _fill = Paint()..style = PaintingStyle.fill;
  static final Paint _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  static final Paint _shadow = Paint()..color = const Color(0x44000000);

  static Future<void> _loadOnce() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      enabled = sp.getBool(_prefKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setEnabled(bool v) async {
    enabled = v;
    _loaded = true;
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      await sp.setBool(_prefKey, v);
    } catch (_) {}
  }

  /// Call at the start of every frame. [shared] is how many non-priority people may be 3D.
  static void begin({int shared = 8}) {
    if (!_loaded) _loadOnce();
    _budget = shared;
  }

  static CharRig _rigFor(CharLook look) {
    final int k = look.sig;
    final CharRig? r = _rigs[k];
    if (r != null) return r;
    if (_rigs.length > 48) _rigs.clear();
    final CharRig n = CharRig.build(look);
    _rigs[k] = n;
    return n;
  }

  /// Draws one fighter. (x, y) is the middle of the torso, the same spot the 2D
  /// person uses, so it can replace it in place. [swing] is the progress of an
  /// attack from 0 to 1, or below 0 when not attacking. [time] is seconds, for idle sway.
  static bool draw(
    Canvas canvas,
    CharLook look,
    double x,
    double y, {
    double phase = 0,
    bool moving = false,
    double facing = 1,
    double scale = 1.0,
    double swing = -1,
    double time = 0,
    double yawAdd = 0,
    bool priority = false,
    bool shadow = true,
  }) {
    if (!enabled) return false;
    if (!priority) {
      if (_budget <= 0) return false;
      _budget--;
    }
    final CharRig rig = _rigFor(look);
    final List<double> pose;
    if (swing >= 0) {
      pose = CharAnims.attackAt(swing, look.weapon, time);
    } else if (moving) {
      pose = CharAnims.runPhase(phase, look.weapon);
    } else {
      pose = CharAnims.idle(time + phase * 0.3, look.weapon);
    }
    rig.apply(pose);

    // The model is about 18.5 units tall; the 2D person is about 46 px tall.
    final double view = 57.5 * scale;
    _cam
      ..yaw = (facing >= 0 ? 0.95 : -0.95) + yawAdd
      ..pitch = 0.2
      ..zoom = 1.0;
    // feet sit 18 px (scaled) below the torso middle in the 2D convention
    if (shadow) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y + 19 * scale), width: 30 * scale, height: 9 * scale), _shadow);
    }
    canvas.save();
    canvas.translate(x - view / 2, y - 5 * scale - view / 2);
    final List<RenderedPoly> polys = Render3D.render(rig.root, _cam, view, view);
    final double ew = priority ? 0.8 : 0.6;
    for (final RenderedPoly r in polys) {
      _fill.color = r.fill;
      canvas.drawPath(r.path, _fill);
      _edge
        ..strokeWidth = ew
        ..color = priority && !r.glow ? Color.lerp(r.fill, const Color(0xFF000000), 0.35)! : r.fill;
      canvas.drawPath(r.path, _edge);
    }
    canvas.restore();
    return true;
  }

  /// A look for the world's characters from plain colours. Weapon 'none' means empty hands.
  static CharLook lookOf({
    required Color skin,
    required Color hair,
    required Color shirt,
    required Color pants,
    String hairStyle = 'low',
    String weapon = 'none',
    Map<String, dynamic>? asset,
    Color? accent,
  }) {
    final Map<String, dynamic> a = asset ?? const <String, dynamic>{};
    return CharLook.from(
      skin: skin,
      hair: hair,
      shirt: shirt,
      pants: pants,
      hairStyle: hairStyle,
      weapon: weapon,
      weaponAsset: a,
      frameColors: accent == null ? const <int>[] : <int>[accent.value],
    );
  }
}

/// Thin arc showing where a swing is going; the 3D body always strikes forward,
/// so this keeps the hit direction readable.
void paintSwingArc(Canvas canvas, double x, double y, double angle, double dir, double progress, double radius, Color color) {
  final double p = progress.clamp(0.0, 1.0).toDouble();
  final double sweep = 2.2 * p;
  final double start = angle - dir * 1.1;
  final Paint s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 4
    ..color = color.withValues(alpha: 0.55 * (1 - p * 0.6));
  canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: radius), start, dir >= 0 ? sweep : -sweep, false, s);
}
