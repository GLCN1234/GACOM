import 'dart:math';
import 'dart:ui' show Color, Offset, Path;

/// A tiny software 3D engine: low-poly meshes, a bone hierarchy and a painter's
/// algorithm renderer. Nothing here touches the platform, so it runs the same
/// on web, Android and iOS. Axes: x right, y up, z towards the viewer.

class V3 {
  final double x;
  final double y;
  final double z;
  const V3(this.x, this.y, this.z);
  static const V3 zero = V3(0, 0, 0);
  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 scaled(double s) => V3(x * s, y * s, z * s);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => sqrt(x * x + y * y + z * z);
  V3 normalized() {
    final double l = length;
    return l < 1e-9 ? const V3(0, 1, 0) : V3(x / l, y / l, z / l);
  }
}

/// A 3x3 rotation matrix, row-major.
class M3 {
  final List<double> m;
  const M3(this.m);
  static const M3 identity = M3(<double>[1, 0, 0, 0, 1, 0, 0, 0, 1]);

  /// Rotation about x, then y, then z (all fixed axes).
  static M3 euler(double rx, double ry, double rz) {
    final double cx = cos(rx), sx = sin(rx);
    final double cy = cos(ry), sy = sin(ry);
    final double cz = cos(rz), sz = sin(rz);
    // R = Rz * Ry * Rx
    return M3(<double>[
      cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx,
      sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx,
      -sy, cy * sx, cy * cx,
    ]);
  }

  M3 operator *(M3 o) {
    final List<double> r = List<double>.filled(9, 0);
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        r[i * 3 + j] = m[i * 3] * o.m[j] + m[i * 3 + 1] * o.m[3 + j] + m[i * 3 + 2] * o.m[6 + j];
      }
    }
    return M3(r);
  }

  V3 apply(V3 v) => V3(
        m[0] * v.x + m[1] * v.y + m[2] * v.z,
        m[3] * v.x + m[4] * v.y + m[5] * v.z,
        m[6] * v.x + m[7] * v.y + m[8] * v.z,
      );
}

/// One polygon of a mesh. Convex and planar, wound counter-clockwise seen from outside.
class Face {
  List<int> idx;
  final Color color;
  /// Emissive faces ignore lighting (glowing gems, orbs, eyes).
  final bool glow;
  Face(this.idx, this.color, {this.glow = false});
}

class Mesh {
  final List<V3> verts = <V3>[];
  final List<Face> faces = <Face>[];

  int _v(V3 v) {
    verts.add(v);
    return verts.length - 1;
  }

  /// Makes every face wind outwards, assuming the shape is convex.
  void _orient(int fromVert, int fromFace) {
    double cx = 0, cy = 0, cz = 0;
    final int n = verts.length - fromVert;
    for (int i = fromVert; i < verts.length; i++) {
      cx += verts[i].x;
      cy += verts[i].y;
      cz += verts[i].z;
    }
    final V3 c = V3(cx / n, cy / n, cz / n);
    for (int f = fromFace; f < faces.length; f++) {
      final Face face = faces[f];
      final V3 a = verts[face.idx[0]];
      final V3 b = verts[face.idx[1]];
      final V3 d = verts[face.idx[2]];
      final V3 nrm = (b - a).cross(d - a);
      double fx = 0, fy = 0, fz = 0;
      for (final int i in face.idx) {
        fx += verts[i].x;
        fy += verts[i].y;
        fz += verts[i].z;
      }
      final V3 fc = V3(fx / face.idx.length, fy / face.idx.length, fz / face.idx.length);
      if (nrm.dot(fc - c) < 0) face.idx = face.idx.reversed.toList();
    }
  }

  /// Adds a box centred on [at].
  void box(double w, double h, double d, Color color, {V3 at = V3.zero, Color? top, bool glow = false}) {
    frustum(w, d, w, d, h, color, at: at, top: top, glow: glow);
  }

  /// A box whose top is a different size from its bottom. Centred on [at].
  void frustum(double w1, double d1, double w2, double d2, double h, Color color, {V3 at = V3.zero, Color? top, bool glow = false}) {
    final int v0 = verts.length;
    final int f0 = faces.length;
    final double y0 = -h / 2, y1 = h / 2;
    final List<int> b = <int>[
      _v(V3(-w1 / 2, y0, -d1 / 2) + at),
      _v(V3(w1 / 2, y0, -d1 / 2) + at),
      _v(V3(w1 / 2, y0, d1 / 2) + at),
      _v(V3(-w1 / 2, y0, d1 / 2) + at),
    ];
    final List<int> t = <int>[
      _v(V3(-w2 / 2, y1, -d2 / 2) + at),
      _v(V3(w2 / 2, y1, -d2 / 2) + at),
      _v(V3(w2 / 2, y1, d2 / 2) + at),
      _v(V3(-w2 / 2, y1, d2 / 2) + at),
    ];
    faces.add(Face(<int>[b[0], b[1], b[2], b[3]], color, glow: glow));
    faces.add(Face(<int>[t[0], t[1], t[2], t[3]], top ?? color, glow: glow));
    for (int i = 0; i < 4; i++) {
      final int j = (i + 1) % 4;
      faces.add(Face(<int>[b[i], b[j], t[j], t[i]], color, glow: glow));
    }
    _orient(v0, f0);
  }

  /// A cylinder or cone frustum along y, centred on [at].
  void cyl(double rBottom, double rTop, double h, int seg, Color color, {V3 at = V3.zero, Color? cap, bool glow = false}) {
    final int v0 = verts.length;
    final int f0 = faces.length;
    final List<int> b = <int>[];
    final List<int> t = <int>[];
    for (int i = 0; i < seg; i++) {
      final double a = i * 2 * pi / seg;
      b.add(_v(V3(cos(a) * rBottom, -h / 2, sin(a) * rBottom) + at));
      t.add(_v(V3(cos(a) * rTop, h / 2, sin(a) * rTop) + at));
    }
    faces.add(Face(List<int>.from(b), cap ?? color, glow: glow));
    if (rTop > 0.001) faces.add(Face(List<int>.from(t), cap ?? color, glow: glow));
    for (int i = 0; i < seg; i++) {
      final int j = (i + 1) % seg;
      if (rTop > 0.001) {
        faces.add(Face(<int>[b[i], b[j], t[j], t[i]], color, glow: glow));
      } else {
        faces.add(Face(<int>[b[i], b[j], t[i]], color, glow: glow));
      }
    }
    _orient(v0, f0);
  }

  /// A low-poly sphere, centred on [at]; stretch it with [sx], [sy], [sz].
  void sphere(double r, int seg, int rings, Color color, {V3 at = V3.zero, double sx = 1, double sy = 1, double sz = 1, Color? top, bool glow = false}) {
    final int v0 = verts.length;
    final int f0 = faces.length;
    final List<List<int>> grid = <List<int>>[];
    for (int k = 0; k <= rings; k++) {
      final double phi = pi * k / rings;
      final List<int> row = <int>[];
      if (k == 0 || k == rings) {
        row.add(_v(V3(0, (k == 0 ? r : -r) * sy, 0) + at));
      } else {
        for (int i = 0; i < seg; i++) {
          final double a = i * 2 * pi / seg;
          row.add(_v(V3(cos(a) * sin(phi) * r * sx, cos(phi) * r * sy, sin(a) * sin(phi) * r * sz) + at));
        }
      }
      grid.add(row);
    }
    for (int k = 0; k < rings; k++) {
      final List<int> a = grid[k];
      final List<int> b = grid[k + 1];
      final Color c = (top != null && k < rings / 2) ? top : color;
      for (int i = 0; i < seg; i++) {
        final int j = (i + 1) % seg;
        if (a.length == 1) {
          faces.add(Face(<int>[a[0], b[j], b[i]], c, glow: glow));
        } else if (b.length == 1) {
          faces.add(Face(<int>[a[i], a[j], b[0]], c, glow: glow));
        } else {
          faces.add(Face(<int>[a[i], a[j], b[j], b[i]], c, glow: glow));
        }
      }
    }
    _orient(v0, f0);
  }

  /// Adds a copy of [o], rotated then moved.
  void add(Mesh o, {V3 at = V3.zero, double rx = 0, double ry = 0, double rz = 0}) {
    final M3 r = M3.euler(rx, ry, rz);
    final int base = verts.length;
    for (final V3 v in o.verts) {
      verts.add(r.apply(v) + at);
    }
    for (final Face f in o.faces) {
      faces.add(Face(f.idx.map((int i) => i + base).toList(), f.color, glow: f.glow));
    }
  }
}

/// A joint with meshes attached. Rotations are in radians about the joint.
class Bone {
  final String name;
  double ox;
  double oy;
  double oz;
  double rx = 0;
  double ry = 0;
  double rz = 0;
  final List<Mesh> meshes = <Mesh>[];
  final List<Bone> children = <Bone>[];
  Bone(this.name, this.ox, this.oy, this.oz);

  Bone child(String n, double x, double y, double z) {
    final Bone b = Bone(n, x, y, z);
    children.add(b);
    return b;
  }
}

class _Poly {
  final List<double> sx;
  final List<double> sy;
  final double depth;
  final Color color;
  final double light;
  final bool glow;
  _Poly(this.sx, this.sy, this.depth, this.color, this.light, this.glow);
}

/// An orbiting camera plus the renderer.
class Cam3D {
  double yaw = 0.55;
  double pitch = 0.14;
  double dist = 64;
  double targetY = 9.3;
  double zoom = 1.0;
}

class Render3D {
  static const double _lx = -0.42, _ly = 0.72, _lz = 0.55;

  /// Draws [root] centred in [size]. [paint] receives each lit polygon path.
  static void collect(Bone root, Cam3D cam, double w, double h, List<_Poly> out) {
    final double cyaw = cos(cam.yaw), syaw = sin(cam.yaw);
    final double cp = cos(cam.pitch), sp = sin(cam.pitch);
    final double f = (0.80 * h / 18.5) * cam.dist * cam.zoom;
    final double cx = w / 2, cy = h / 2;
    final double ll = sqrt(_lx * _lx + _ly * _ly + _lz * _lz);

    void walk(Bone b, M3 pr, V3 pt) {
      final M3 r = pr * M3.euler(b.rx, b.ry, b.rz);
      final V3 t = pr.apply(V3(b.ox, b.oy, b.oz)) + pt;
      for (final Mesh m in b.meshes) {
        // vertices into camera space
        final List<V3> cv = List<V3>.generate(m.verts.length, (int i) {
          final V3 wv = r.apply(m.verts[i]) + t;
          final double x = wv.x;
          final double y = wv.y - cam.targetY;
          final double z = wv.z;
          // yaw about y
          final double x1 = x * cyaw + z * syaw;
          final double z1 = -x * syaw + z * cyaw;
          // pitch about x
          final double y2 = y * cp - z1 * sp;
          final double z2 = y * sp + z1 * cp;
          return V3(x1, y2, z2);
        }, growable: false);
        for (final Face face in m.faces) {
          final List<int> ix = face.idx;
          final V3 a = cv[ix[0]];
          final V3 bb = cv[ix[1]];
          final V3 c = cv[ix[2]];
          V3 n = (bb - a).cross(c - a);
          final double nl = n.length;
          if (nl < 1e-9) continue;
          n = n.scaled(1 / nl);
          // centre of the face, for the view vector and depth
          double fx = 0, fy = 0, fz = 0;
          for (final int i in ix) {
            fx += cv[i].x;
            fy += cv[i].y;
            fz += cv[i].z;
          }
          final double inv = 1.0 / ix.length;
          fx *= inv;
          fy *= inv;
          fz *= inv;
          final V3 toCam = V3(-fx, -fy, cam.dist - fz);
          if (n.dot(toCam) <= 0) continue;
          bool behind = false;
          final List<double> sx = <double>[];
          final List<double> sy = <double>[];
          for (final int i in ix) {
            final double d = cam.dist - cv[i].z;
            if (d < 1.0) {
              behind = true;
              break;
            }
            sx.add(cx + cv[i].x * f / d);
            sy.add(cy - cv[i].y * f / d);
          }
          if (behind) continue;
          final double lit = (n.x * _lx + n.y * _ly + n.z * _lz) / ll;
          out.add(_Poly(sx, sy, cam.dist - fz, face.color, lit, face.glow));
        }
      }
      for (final Bone ch in b.children) {
        walk(ch, r, t);
      }
    }

    walk(root, M3.identity, V3.zero);
  }

  static Color _shade(Color c, double lit, bool glow) {
    if (glow) return c;
    final double k = 0.42 + 0.58 * (lit < 0 ? 0 : lit) + 0.10 * (lit < 0 ? lit : 0);
    final double kk = k.clamp(0.22, 1.12);
    int ch(int v) => (v * kk).round().clamp(0, 255);
    final int v = c.value;
    return Color.fromARGB(255, ch((v >> 16) & 0xFF), ch((v >> 8) & 0xFF), ch(v & 0xFF));
  }

  /// Sorted, shaded polygons ready to draw as (path, fill, outline).
  static List<RenderedPoly> render(Bone root, Cam3D cam, double w, double h) {
    final List<_Poly> polys = <_Poly>[];
    collect(root, cam, w, h, polys);
    polys.sort((_Poly a, _Poly b) => b.depth.compareTo(a.depth));
    final List<RenderedPoly> out = <RenderedPoly>[];
    for (final _Poly p in polys) {
      final Path path = Path()..moveTo(p.sx[0], p.sy[0]);
      for (int i = 1; i < p.sx.length; i++) {
        path.lineTo(p.sx[i], p.sy[i]);
      }
      path.close();
      final Color fill = _shade(p.color, p.light, p.glow);
      out.add(RenderedPoly(path, fill, p.glow));
    }
    return out;
  }

  /// A ground ring/shadow as a path, projected with the same camera.
  static Path floorCircle(Cam3D cam, double w, double h, double radius, {int seg = 28}) {
    final double cyaw = cos(cam.yaw), syaw = sin(cam.yaw);
    final double cp = cos(cam.pitch), sp = sin(cam.pitch);
    final double f = (0.80 * h / 18.5) * cam.dist * cam.zoom;
    final Path path = Path();
    for (int i = 0; i <= seg; i++) {
      final double a = i * 2 * pi / seg;
      final double x = cos(a) * radius;
      final double y = -cam.targetY;
      final double z = sin(a) * radius;
      final double x1 = x * cyaw + z * syaw;
      final double z1 = -x * syaw + z * cyaw;
      final double y2 = y * cp - z1 * sp;
      final double z2 = y * sp + z1 * cp;
      final double d = cam.dist - z2;
      final Offset o = Offset(w / 2 + x1 * f / d, h / 2 - y2 * f / d);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    path.close();
    return path;
  }
}

class RenderedPoly {
  final Path path;
  final Color fill;
  final bool glow;
  const RenderedPoly(this.path, this.fill, this.glow);
}
