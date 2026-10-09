import 'dart:math';
import 'dart:ui' show Color;
import 'g3d.dart';

/// Everything that decides how the 3D fighter looks. Cosmetic only.
class CharLook {
  final Color skin;
  final Color hair;
  final Color shirt;
  final Color pants;
  final String hairStyle; // low | afro | braids | locs | wrap | hijab
  final Color accent; // belt, boots trim, shoulder studs
  final String weapon; // sword | dagger | hammer | axe | staff | shield
  final Color metal;
  final Color metalHi;
  final Color metalEx;
  final Color wood;
  final Color? glow;

  const CharLook({
    this.skin = const Color(0xFFF2B785),
    this.hair = const Color(0xFF2B1B12),
    this.shirt = const Color(0xFFFF6A00),
    this.pants = const Color(0xFF2A3A63),
    this.hairStyle = 'low',
    this.accent = const Color(0xFFFFD54F),
    this.weapon = 'sword',
    this.metal = const Color(0xFF98A4B8),
    this.metalHi = const Color(0xFFB8C4D8),
    this.metalEx = const Color(0xFF6B7790),
    this.wood = const Color(0xFF7A4A2B),
    this.glow,
  });

  static Color? _hex(dynamic v) {
    if (v == null) return null;
    try {
      String h = v.toString().replaceFirst('#', '');
      if (h.length == 6) h = 'FF$h';
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return null;
    }
  }

  /// Builds a look from the colours and weapon asset the app already stores.
  factory CharLook.from({
    required Color skin,
    required Color hair,
    required Color shirt,
    required Color pants,
    required String hairStyle,
    required String weapon,
    required Map<String, dynamic> weaponAsset,
    List<int> frameColors = const <int>[],
  }) {
    final CharLook d = const CharLook();
    return CharLook(
      skin: skin,
      hair: hair,
      shirt: shirt,
      pants: pants,
      hairStyle: hairStyle,
      accent: frameColors.isNotEmpty ? Color(frameColors.first) : d.accent,
      weapon: weapon,
      metal: _hex(weaponAsset['metal']) ?? d.metal,
      metalHi: _hex(weaponAsset['hi']) ?? d.metalHi,
      metalEx: _hex(weaponAsset['ex']) ?? d.metalEx,
      wood: _hex(weaponAsset['w']) ?? d.wood,
      glow: _hex(weaponAsset['glow']),
    );
  }

  CharLook withWeapon(String kind, Map<String, dynamic> asset) => CharLook.from(
        skin: skin,
        hair: hair,
        shirt: shirt,
        pants: pants,
        hairStyle: hairStyle,
        weapon: kind,
        weaponAsset: asset,
        frameColors: <int>[accent.value],
      );
}

Color _mul(Color c, double k) {
  final int v = c.value;
  int ch(int x) => (x * k).round().clamp(0, 255);
  return Color.fromARGB(255, ch((v >> 16) & 0xFF), ch((v >> 8) & 0xFF), ch(v & 0xFF));
}

/// The skeleton plus handles to the joints an animation drives.
class CharRig {
  final Bone root; // pelvis, moved by the animation
  final Bone torso;
  final Bone head;
  final Bone shR;
  final Bone elR;
  final Bone wristR;
  final Bone shL;
  final Bone elL;
  final Bone hipR;
  final Bone knR;
  final Bone hipL;
  final Bone knL;
  CharRig(this.root, this.torso, this.head, this.shR, this.elR, this.wristR, this.shL, this.elL, this.hipR, this.knR, this.hipL, this.knL);

  static const double pelvisY = 9.2;

  /// [pose] has [Pose.n] values; see [Pose].
  void apply(List<double> p) {
    root.oy = pelvisY + p[Pose.rootY];
    root.oz = p[Pose.rootZ];
    root.ry = p[Pose.rootRotY];
    torso.rx = p[Pose.torsoX];
    torso.ry = p[Pose.torsoY];
    torso.rz = p[Pose.torsoZ];
    head.rx = p[Pose.headX];
    head.ry = p[Pose.headY];
    shR.rx = p[Pose.shRx];
    shR.rz = p[Pose.shRz];
    elR.rx = p[Pose.elRx];
    elR.rz = p[Pose.elRz];
    wristR.rx = p[Pose.wristRx];
    shL.rx = p[Pose.shLx];
    shL.rz = p[Pose.shLz];
    elL.rx = p[Pose.elLx];
    hipR.rx = p[Pose.hipRx];
    knR.rx = p[Pose.knRx];
    hipL.rx = p[Pose.hipLx];
    knL.rx = p[Pose.knLx];
  }

  static CharRig build(CharLook l) {
    final Color skin = l.skin;
    final Color shirt = l.shirt;
    final Color pants = l.pants;
    final Color boots = _mul(l.pants, 0.55);
    final Color belt = _mul(l.accent, 0.8);

    final Bone pelvis = Bone('pelvis', 0, pelvisY, 0);
    pelvis.meshes.add(Mesh()
      ..box(4.2, 1.8, 2.3, pants, at: const V3(0, -0.2, 0))
      ..box(4.5, 0.55, 2.55, belt, at: const V3(0, 0.55, 0)));

    // legs
    Bone leg(String s, double x) {
      final Bone hip = pelvis.child('hip$s', x, -0.7, 0);
      hip.meshes.add(Mesh()..box(1.85, 4.3, 1.9, pants, at: const V3(0, -2.05, 0)));
      final Bone knee = hip.child('knee$s', 0, -4.2, 0);
      knee.meshes.add(Mesh()
        ..box(1.55, 3.9, 1.65, pants, at: const V3(0, -1.9, 0))
        ..box(1.6, 0.5, 1.7, _mul(pants, 0.8), at: const V3(0, -3.75, 0)));
      final Bone ankle = knee.child('ankle$s', 0, -3.9, 0);
      ankle.meshes.add(Mesh()
        ..box(1.7, 1.1, 2.9, boots, at: const V3(0, -0.45, 0.55))
        ..box(1.72, 0.25, 2.92, belt, at: const V3(0, -0.05, 0.55)));
      return hip;
    }

    final Bone hipR = leg('R', -1.15);
    final Bone hipL = leg('L', 1.15);
    final Bone knR = hipR.children.first;
    final Bone knL = hipL.children.first;

    // torso
    final Bone torso = pelvis.child('torso', 0, 0.8, 0);
    torso.meshes.add(Mesh()
      ..frustum(4.3, 2.4, 4.8, 2.6, 5.0, shirt, at: const V3(0, 2.5, 0))
      ..box(1.9, 2.6, 0.12, _mul(shirt, 1.25), at: const V3(0, 2.6, 1.31))
      ..box(5.0, 0.7, 2.7, _mul(shirt, 0.82), at: const V3(0, 4.7, 0)));
    // neck and head
    final Bone neck = torso.child('neck', 0, 5.0, 0);
    neck.meshes.add(Mesh()..cyl(0.65, 0.65, 0.8, 6, skin, at: const V3(0, 0.2, 0)));
    final Bone head = neck.child('head', 0, 0.6, 0);
    head.meshes.add(Mesh()
      ..sphere(1.7, 9, 7, skin, at: const V3(0, 1.5, 0), sy: 1.05)
      ..box(0.42, 0.5, 0.2, const Color(0xFF14110F), at: const V3(-0.62, 1.6, 1.58))
      ..box(0.42, 0.5, 0.2, const Color(0xFF14110F), at: const V3(0.62, 1.6, 1.58))
      ..box(0.9, 0.16, 0.2, _mul(skin, 0.68), at: const V3(0, 0.78, 1.62)));
    _hair(head, l);

    // arms
    Bone arm(String s, double x, bool right) {
      final Bone sh = torso.child('sh$s', x, 4.3, 0);
      sh.meshes.add(Mesh()
        ..sphere(1.0, 6, 4, shirt, at: const V3(0, 0, 0))
        ..box(1.35, 3.3, 1.4, shirt, at: const V3(0, -1.65, 0))
        ..sphere(0.5, 5, 3, l.accent, at: V3(x < 0 ? -0.55 : 0.55, 0.65, 0)));
      final Bone el = sh.child('el$s', 0, -3.2, 0);
      el.meshes.add(Mesh()..box(1.15, 3.0, 1.2, skin, at: const V3(0, -1.5, 0))..box(1.25, 0.55, 1.3, belt, at: const V3(0, -2.8, 0)));
      final Bone wrist = el.child('wrist$s', 0, -3.1, 0);
      wrist.meshes.add(Mesh()..sphere(0.72, 6, 4, skin, at: const V3(0, -0.4, 0)));
      return sh;
    }

    final Bone shR = arm('R', -2.75, true);
    final Bone shL = arm('L', 2.75, false);
    final Bone elR = shR.children.first;
    final Bone elL = shL.children.first;
    final Bone wristR = elR.children.first;
    final Bone wristL = elL.children.first;

    // weapon
    if (l.weapon == 'shield') {
      elL.child('shield', 0.95, -1.6, 0.9).meshes.add(_shield(l));
      wristR.child('grip', 0, -0.4, 0);
    } else {
      final Bone grip = wristR.child('grip', 0, -0.5, 0);
      grip.rx = pi / 2;
      grip.meshes.add(_weapon(l));
    }
    wristL.ox = 0;

    return CharRig(pelvis, torso, head, shR, elR, wristR, shL, elL, hipR, knR, hipL, knL);
  }

  static void _hair(Bone head, CharLook l) {
    final Color h = l.hair;
    final Mesh m = Mesh();
    switch (l.hairStyle) {
      case 'afro':
        m.sphere(2.35, 9, 7, h, at: const V3(0, 2.2, -0.35));
        break;
      case 'braids':
        m.sphere(1.82, 9, 6, h, at: const V3(0, 1.75, -0.28), sy: 0.95);
        for (int i = -3; i <= 3; i++) {
          m.cyl(0.22, 0.14, 3.4, 5, h, at: V3(i * 0.48, -0.1, -1.55 + (i.abs() * 0.12)));
        }
        break;
      case 'locs':
        m.sphere(1.85, 9, 6, h, at: const V3(0, 1.75, -0.25), sy: 0.95);
        for (int i = -4; i <= 4; i++) {
          m.cyl(0.26, 0.2, 3.0, 5, h, at: V3(i * 0.4, 0.2, -1.5 + (i.abs() * 0.08)));
        }
        break;
      case 'wrap':
        m.sphere(1.84, 9, 6, l.accent, at: const V3(0, 1.8, -0.2), sy: 0.9);
        m.sphere(1.0, 6, 4, l.accent, at: const V3(0, 3.3, -0.6), sy: 0.9);
        break;
      case 'hijab':
        m.sphere(1.98, 9, 7, h, at: const V3(0, 1.45, -0.42), sy: 1.08);
        m.box(3.7, 1.7, 2.9, h, at: const V3(0, -0.45, -0.3));
        break;
      default:
        m.sphere(1.82, 9, 6, h, at: const V3(0, 1.8, -0.3), sy: 0.92);
    }
    head.meshes.add(m);
  }

  // ---- weapons: grip at the origin, blade along +y -------------------------------

  static Mesh _weapon(CharLook l) {
    final Mesh m = Mesh();
    final Color glow = l.glow ?? l.metalHi;
    final bool lit = l.glow != null;
    switch (l.weapon) {
      case 'dagger':
        m.cyl(0.26, 0.26, 1.3, 6, l.wood, at: const V3(0, 0, 0));
        m.box(1.5, 0.3, 0.55, l.metalEx, at: const V3(0, 0.75, 0));
        m.frustum(0.62, 0.2, 0.62, 0.2, 2.6, l.metal, at: const V3(0, 2.2, 0));
        m.frustum(0.62, 0.2, 0.04, 0.04, 0.8, l.metal, at: const V3(0, 3.9, 0));
        m.box(0.16, 2.2, 0.24, glow, at: const V3(0, 2.2, 0), glow: lit);
        break;
      case 'hammer':
        m.cyl(0.3, 0.3, 5.4, 6, l.wood, at: const V3(0, 1.6, 0));
        m.box(3.0, 1.9, 1.9, l.metal, at: const V3(0, 4.7, 0), top: l.metalHi);
        m.box(3.15, 0.3, 2.05, l.metalEx, at: const V3(0, 3.9, 0));
        m.box(3.15, 0.3, 2.05, l.metalEx, at: const V3(0, 5.5, 0));
        m.box(0.2, 1.2, 0.2, glow, at: const V3(0, 4.7, 1.0), glow: lit);
        break;
      case 'axe':
        m.cyl(0.3, 0.3, 5.0, 6, l.wood, at: const V3(0, 1.4, 0));
        m.frustum(0.45, 2.3, 0.3, 0.7, 2.4, l.metal, at: const V3(0, 3.7, 1.15), top: l.metalHi);
        m.box(0.5, 0.9, 0.5, l.metalEx, at: const V3(0, 3.7, -0.5));
        m.box(0.2, 2.2, 0.16, glow, at: const V3(0, 3.7, 2.2), glow: lit);
        break;
      case 'staff':
        m.cyl(0.3, 0.3, 8.0, 6, l.wood, at: const V3(0, 2.2, 0));
        m.cyl(0.55, 0.3, 0.7, 6, l.metalEx, at: const V3(0, 6.5, 0));
        m.sphere(0.95, 7, 5, glow, at: const V3(0, 7.7, 0), glow: true);
        m.sphere(0.3, 5, 3, l.metalEx, at: const V3(0, -1.8, 0));
        break;
      default: // sword
        m.cyl(0.28, 0.28, 1.7, 6, l.wood, at: const V3(0, 0, 0));
        m.sphere(0.42, 5, 3, l.metalEx, at: const V3(0, -0.95, 0));
        m.box(2.8, 0.38, 0.7, l.metalEx, at: const V3(0, 1.0, 0));
        m.frustum(0.9, 0.24, 0.9, 0.24, 5.4, l.metal, at: const V3(0, 3.9, 0));
        m.frustum(0.9, 0.24, 0.06, 0.06, 1.0, l.metal, at: const V3(0, 7.1, 0));
        m.box(0.22, 4.8, 0.3, glow, at: const V3(0, 3.9, 0), glow: lit);
    }
    return m;
  }

  static Mesh _shield(CharLook l) {
    final Mesh disc = Mesh();
    disc.cyl(2.5, 2.5, 0.5, 10, l.metal, at: V3.zero, cap: l.metalHi);
    disc.cyl(2.7, 2.7, 0.36, 10, l.metalEx, at: const V3(0, -0.16, 0));
    disc.sphere(0.8, 7, 4, l.metalHi, at: const V3(0, 0.4, 0), sy: 0.6);
    if (l.glow != null) disc.cyl(1.4, 1.4, 0.08, 10, l.glow!, at: const V3(0, 0.27, 0), glow: true);
    final Mesh out = Mesh();
    out.add(disc, rx: pi / 2);
    return out;
  }
}

/// Indexes into a pose: a list of numbers the animations fill in.
class Pose {
  static const int rootY = 0;
  static const int rootZ = 1;
  static const int rootRotY = 2;
  static const int torsoX = 3;
  static const int torsoY = 4;
  static const int torsoZ = 5;
  static const int headX = 6;
  static const int headY = 7;
  static const int shRx = 8;
  static const int shRz = 9;
  static const int elRx = 10;
  static const int shLx = 11;
  static const int shLz = 12;
  static const int elLx = 13;
  static const int hipRx = 14;
  static const int knRx = 15;
  static const int hipLx = 16;
  static const int knLx = 17;
  static const int wristRx = 18;
  static const int elRz = 19;
  static const int n = 20;

  static List<double> blank() => List<double>.filled(n, 0.0);
}

/// Animations. Each returns a pose for time [t] seconds.
class CharAnims {
  static const List<String> names = <String>['idle', 'run', 'attack', 'cheer', 'wave'];

  static String label(String a) {
    switch (a) {
      case 'run':
        return 'Run';
      case 'attack':
        return 'Attack';
      case 'cheer':
        return 'Cheer';
      case 'wave':
        return 'Wave';
      default:
        return 'Idle';
    }
  }

  static double _s(double x) {
    final double c = x < 0 ? 0.0 : (x > 1 ? 1.0 : x);
    return c * c * (3 - 2 * c);
  }

  static double _ease(double a, double b, double x) => a + (b - a) * _s(x);

  /// The resting arm pose for [weapon]: [shR, elR, shL, elL].
  static List<double> _guard(String weapon) {
    if (weapon == 'shield') return <double>[-0.12, -0.3, -0.65, -1.35];
    if (weapon == 'staff') return <double>[-0.45, -0.95, -0.2, -0.45];
    return <double>[-0.5, -1.2, -0.18, -0.4];
  }

  static List<double> idle(double t, String weapon) {
    final List<double> p = Pose.blank();
    final List<double> g = _guard(weapon);
    final double b = sin(t * 2.0);
    p[Pose.rootY] = b * 0.12;
    p[Pose.torsoX] = 0.02 + b * 0.015;
    p[Pose.headY] = sin(t * 0.7) * 0.18;
    p[Pose.headX] = -0.03;
    p[Pose.shRx] = g[0] + sin(t * 1.8) * 0.04;
    p[Pose.elRx] = g[1];
    p[Pose.shRz] = -0.1;
    p[Pose.shLx] = g[2] + sin(t * 1.8 + 1) * 0.04;
    p[Pose.elLx] = g[3];
    p[Pose.shLz] = 0.1;
    p[Pose.hipRx] = -0.05;
    p[Pose.hipLx] = 0.05;
    p[Pose.knRx] = 0.08;
    p[Pose.knLx] = 0.1;
    return p;
  }

  static List<double> run(double t, String weapon) {
    final List<double> p = Pose.blank();
    final List<double> g = _guard(weapon);
    final double ph = t * 9.5;
    final double s = sin(ph);
    p[Pose.rootY] = (sin(ph * 2).abs()) * 0.55 - 0.15;
    p[Pose.torsoX] = 0.16;
    p[Pose.torsoY] = s * 0.14;
    p[Pose.headX] = -0.12;
    p[Pose.hipRx] = -s * 0.95;
    p[Pose.hipLx] = s * 0.95;
    p[Pose.knRx] = max(0.0, cos(ph)) * 1.25 + 0.15;
    p[Pose.knLx] = max(0.0, -cos(ph)) * 1.25 + 0.15;
    // weapon arm stays up, the other pumps
    p[Pose.shRx] = g[0] - 0.25 + s * 0.12;
    p[Pose.elRx] = g[1] - 0.2;
    p[Pose.shRz] = -0.08;
    p[Pose.shLx] = weapon == 'shield' ? g[2] : -s * 0.9;
    p[Pose.elLx] = weapon == 'shield' ? g[3] : -1.0 - s * 0.2;
    p[Pose.shLz] = 0.08;
    return p;
  }

  /// Seconds for one swing.
  static double attackLength(String weapon) {
    switch (weapon) {
      case 'dagger':
        return 0.7;
      case 'hammer':
        return 1.5;
      case 'axe':
        return 1.2;
      case 'staff':
        return 1.3;
      case 'shield':
        return 0.9;
      default:
        return 1.0;
    }
  }

  // key: [p, rootZ, torsoY, torsoX, shR, elR, shL, elL]
  static List<List<double>> _attackKeys(String weapon, List<double> g) {
    switch (weapon) {
      case 'dagger':
        return <List<double>>[
          <double>[0.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
          <double>[0.3, -0.6, 0.55, 0.0, -0.35, -2.0, -0.7, -1.1],
          <double>[0.5, 1.6, -0.5, 0.2, -1.5, -0.15, -0.3, -0.5],
          <double>[0.75, 1.2, -0.3, 0.12, -1.3, -0.3, -0.25, -0.45],
          <double>[1.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
        ];
      case 'staff':
        return <List<double>>[
          <double>[0.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
          <double>[0.4, -0.3, 0.2, -0.15, -2.5, -0.5, -2.2, -0.6],
          <double>[0.58, 0.9, -0.2, 0.25, -1.2, -0.25, -1.0, -0.3],
          <double>[0.8, 0.6, -0.1, 0.15, -1.1, -0.3, -0.9, -0.4],
          <double>[1.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
        ];
      case 'shield':
        return <List<double>>[
          <double>[0.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
          <double>[0.3, -0.5, -0.35, 0.0, -0.1, -0.3, -0.25, -1.9],
          <double>[0.5, 1.7, 0.3, 0.12, -0.2, -0.3, -1.45, -0.1],
          <double>[0.75, 1.3, 0.2, 0.08, -0.2, -0.3, -1.3, -0.3],
          <double>[1.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
        ];
      default: // sword, axe, hammer: overhead cut
        return <List<double>>[
          <double>[0.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
          <double>[0.38, -0.6, 0.5, -0.12, -2.8, -0.9, -0.5, -0.7],
          <double>[0.52, 1.3, -0.6, 0.28, -0.6, -0.35, -0.2, -0.45],
          <double>[0.75, 0.9, -0.4, 0.2, -0.55, -0.5, -0.2, -0.45],
          <double>[1.0, 0.0, 0.0, 0.02, g[0], g[1], g[2], g[3]],
        ];
    }
  }

  static List<double> attack(double t, String weapon) {
    final List<double> p = idle(t, weapon);
    final List<double> g = _guard(weapon);
    final double len = attackLength(weapon);
    final double ph = (t % len) / len;
    final List<List<double>> keys = _attackKeys(weapon, g);
    int k = 0;
    while (k < keys.length - 2 && ph > keys[k + 1][0]) {
      k++;
    }
    final List<double> a = keys[k];
    final List<double> b = keys[k + 1];
    final double x = (ph - a[0]) / (b[0] - a[0]);
    double v(int i) => _ease(a[i], b[i], x);
    p[Pose.rootZ] = v(1);
    p[Pose.torsoY] = v(2);
    p[Pose.torsoX] = v(3);
    p[Pose.shRx] = v(4);
    p[Pose.elRx] = v(5);
    p[Pose.shLx] = v(6);
    p[Pose.elLx] = v(7);
    p[Pose.rootRotY] = -v(2) * 0.4;
    // step into the strike
    p[Pose.hipRx] = -0.15 - max(0.0, v(1)) * 0.28;
    p[Pose.hipLx] = 0.15 + max(0.0, v(1)) * 0.2;
    p[Pose.knRx] = 0.1 + max(0.0, v(1)) * 0.3;
    p[Pose.knLx] = 0.2;
    return p;
  }

  static List<double> cheer(double t, String weapon) {
    final List<double> p = idle(t, weapon);
    final double hop = sin(t * 5.5).abs();
    p[Pose.rootY] = hop * 1.3;
    p[Pose.torsoX] = -0.08;
    p[Pose.headX] = -0.2;
    p[Pose.shRx] = -2.9 + sin(t * 11) * 0.12;
    p[Pose.elRx] = -0.3;
    p[Pose.shRz] = -0.35;
    p[Pose.shLx] = -2.9 + sin(t * 11 + 1.5) * 0.12;
    p[Pose.elLx] = -0.3;
    p[Pose.shLz] = 0.35;
    p[Pose.hipRx] = -0.1 - hop * 0.2;
    p[Pose.hipLx] = 0.1 + hop * 0.2;
    p[Pose.knRx] = 0.2 + hop * 0.5;
    p[Pose.knLx] = 0.2 + hop * 0.5;
    return p;
  }

  static List<double> wave(double t, String weapon) {
    final List<double> p = idle(t, weapon);
    p[Pose.shRx] = -0.1;
    p[Pose.shRz] = -2.5;
    p[Pose.elRx] = -0.1;
    p[Pose.elRz] = -0.35 + sin(t * 8) * 0.55;
    p[Pose.headY] = sin(t * 1.6) * 0.2;
    p[Pose.torsoZ] = 0.04;
    return p;
  }

  static List<double> pose(String anim, double t, String weapon) {
    switch (anim) {
      case 'run':
        return run(t, weapon);
      case 'attack':
        return attack(t, weapon);
      case 'cheer':
        return cheer(t, weapon);
      case 'wave':
        return wave(t, weapon);
      default:
        return idle(t, weapon);
    }
  }
}
