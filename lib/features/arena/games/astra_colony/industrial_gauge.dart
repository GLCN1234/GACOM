import 'dart:math';
import 'package:flutter/material.dart';

/// An analog gauge dial — a needle sweeping across a semicircular scale
/// toward a target value. This is the Colony Siege indicator style:
/// mechanical and analog, not a glowing pill or a flat progress bar.
class IndustrialGauge extends StatelessWidget {
  const IndustrialGauge({super.key, required this.current, required this.target, this.size = 84, this.overload = false});
  final int current;
  final int target;
  final double size;
  final bool overload;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size * 0.62,
    child: CustomPaint(painter: _GaugePainter(progress: (current / target).clamp(0, 1), overload: overload)),
  );
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.progress, required this.overload});
  final double progress;
  final bool overload;

  static const _amber = Color(0xFFFFA940);
  static const _rust = Color(0xFFB8541F);
  static const _iron = Color(0xFF2B2B2E);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 6;

    // Dial face plate — beveled iron look via a double ring.
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius + 4), pi, pi, false,
      Paint()..color = _iron..style = PaintingStyle.stroke..strokeWidth = 8);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi, false,
      Paint()..color = const Color(0xFF1A1A1C)..style = PaintingStyle.stroke..strokeWidth = 14);

    // Amber fill arc showing progress toward target.
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi * progress, false,
      Paint()
        ..color = overload ? const Color(0xFFFF5A5F) : _amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round);

    // Tick marks.
    for (int i = 0; i <= 8; i++) {
      final angle = pi + (pi * i / 8);
      final tickOuter = center + Offset(cos(angle), sin(angle)) * (radius + 4);
      final tickInner = center + Offset(cos(angle), sin(angle)) * (radius - 6);
      canvas.drawLine(tickInner, tickOuter, Paint()..color = Colors.white38..strokeWidth = 1.5);
    }

    // Needle.
    final needleAngle = pi + (pi * progress);
    final needleTip = center + Offset(cos(needleAngle), sin(needleAngle)) * (radius - 4);
    canvas.drawLine(center, needleTip, Paint()..color = overload ? const Color(0xFFFF5A5F) : _rust..strokeWidth = 3);
    canvas.drawCircle(center, 5, Paint()..color = _rust);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.overload != overload;
}
