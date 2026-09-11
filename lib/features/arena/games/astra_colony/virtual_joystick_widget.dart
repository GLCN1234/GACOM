import 'package:flutter/material.dart';

/// A self-contained virtual joystick. Deliberately built on plain Flutter
/// [GestureDetector] pan events rather than Flame's own joystick component
/// — after two real runtime crashes from less-certain Flame APIs this
/// session, movement input stays on Flutter's most solid ground.
class VirtualJoystickWidget extends StatefulWidget {
  const VirtualJoystickWidget({super.key, required this.onDirectionChanged, this.knobColor = const Color(0xFF3DD6FF), this.baseBorderColor});
  final void Function(Offset direction) onDirectionChanged; // x/y each in [-1, 1]
  final Color knobColor;
  final Color? baseBorderColor;

  @override
  State<VirtualJoystickWidget> createState() => _VirtualJoystickWidgetState();
}

class _VirtualJoystickWidgetState extends State<VirtualJoystickWidget> {
  static const double _baseRadius = 44;
  static const double _knobRadius = 20;
  Offset _knobOffset = Offset.zero;

  void _updateFromLocalPosition(Offset localPos, Offset center) {
    var delta = localPos - center;
    final maxDist = _baseRadius - _knobRadius / 2;
    if (delta.distance > maxDist) {
      delta = Offset.fromDirection(delta.direction, maxDist);
    }
    setState(() => _knobOffset = delta);
    widget.onDirectionChanged(Offset(delta.dx / maxDist, delta.dy / maxDist));
  }

  void _reset() {
    setState(() => _knobOffset = Offset.zero);
    widget.onDirectionChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    const size = _baseRadius * 2;
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onPanStart: (d) => _updateFromLocalPosition(d.localPosition, const Offset(size / 2, size / 2)),
        onPanUpdate: (d) => _updateFromLocalPosition(d.localPosition, const Offset(size / 2, size / 2)),
        onPanEnd: (_) => _reset(),
        onPanCancel: _reset,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: size, height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.35),
              border: Border.all(color: widget.baseBorderColor ?? Colors.white.withOpacity(0.25), width: 1.5),
            ),
          ),
          Transform.translate(
            offset: _knobOffset,
            child: Container(
              width: _knobRadius * 2, height: _knobRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.knobColor.withOpacity(0.85),
                boxShadow: [BoxShadow(color: widget.knobColor.withOpacity(0.5), blurRadius: 10)],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
