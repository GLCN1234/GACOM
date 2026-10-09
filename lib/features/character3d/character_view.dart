import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'g3d.dart';
import 'rig.dart';

/// A rotatable, animated 3D fighter. Drag to turn it; it turns by itself when left alone.
class Character3DView extends StatefulWidget {
  final CharLook look;
  final String anim;
  final bool interactive;
  final bool autoRotate;
  final double zoom;
  final Color ring;
  const Character3DView({
    super.key,
    required this.look,
    this.anim = 'idle',
    this.interactive = true,
    this.autoRotate = true,
    this.zoom = 1.0,
    this.ring = const Color(0xFF2ED3E6),
  });

  @override
  State<Character3DView> createState() => _Character3DViewState();
}

class _Character3DViewState extends State<Character3DView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);
  final Cam3D _cam = Cam3D();
  late CharRig _rig;
  late List<double> _pose;
  Duration? _last;
  double _t = 0;
  double _idleSince = 99;

  @override
  void initState() {
    super.initState();
    _rig = CharRig.build(widget.look);
    _pose = CharAnims.pose(widget.anim, 0, widget.look.weapon);
    _cam.zoom = widget.zoom;
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(Character3DView old) {
    super.didUpdateWidget(old);
    if (!identical(old.look, widget.look)) {
      _rig = CharRig.build(widget.look);
    }
    _cam.zoom = widget.zoom;
  }

  void _onTick(Duration d) {
    final double dt = _last == null ? 0.016 : ((d - _last!).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = d;
    _t += dt;
    _idleSince += dt;
    final List<double> target = CharAnims.pose(widget.anim, _t, widget.look.weapon);
    final double k = min(1.0, dt * 9);
    for (int i = 0; i < _pose.length; i++) {
      _pose[i] += (target[i] - _pose[i]) * k;
    }
    _rig.apply(_pose);
    if (widget.autoRotate && _idleSince > 2.5) _cam.yaw += dt * 0.55;
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _drag(DragUpdateDetails d) {
    _idleSince = 0;
    _cam.yaw += d.delta.dx * 0.011;
    _cam.pitch = (_cam.pitch - d.delta.dy * 0.006).clamp(-0.12, 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final Widget paint = RepaintBoundary(
      child: CustomPaint(
        painter: _CharPainter(rig: () => _rig, cam: _cam, ring: widget.ring, repaint: _frame),
        size: Size.infinite,
      ),
    );
    if (!widget.interactive) return paint;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: _drag,
      onPanDown: (_) => _idleSince = 0,
      child: paint,
    );
  }
}

class _CharPainter extends CustomPainter {
  final CharRig Function() rig;
  final Cam3D cam;
  final Color ring;
  _CharPainter({required this.rig, required this.cam, required this.ring, required Listenable repaint}) : super(repaint: repaint);

  final Paint _p = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width, h = size.height;
    if (w < 4 || h < 4) return;
    // ground: soft shadow and a ring
    final Path floor = Render3D.floorCircle(cam, w, h, 9.5);
    _p
      ..style = PaintingStyle.fill
      ..color = const Color(0x55000000);
    canvas.drawPath(floor, _p);
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = ring.withValues(alpha: 0.75);
    canvas.drawPath(Render3D.floorCircle(cam, w, h, 10.5), _p);
    _p
      ..strokeWidth = 1.0
      ..color = ring.withValues(alpha: 0.35);
    canvas.drawPath(Render3D.floorCircle(cam, w, h, 12.5), _p);

    final List<RenderedPoly> polys = Render3D.render(rig().root, cam, w, h);
    for (final RenderedPoly r in polys) {
      _p
        ..style = PaintingStyle.fill
        ..color = r.fill;
      canvas.drawPath(r.path, _p);
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round
        ..color = r.glow ? r.fill : Color.lerp(r.fill, const Color(0xFF000000), 0.35)!;
      canvas.drawPath(r.path, _p);
    }
  }

  @override
  bool shouldRepaint(covariant _CharPainter old) => true;
}
