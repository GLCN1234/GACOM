import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// One answer option, physically present in the world. Walking into it
/// evaluates the answer immediately — correct glows green and the mission
/// advances instantly to the next question's terminals; wrong flashes red
/// and does nothing else, the player just tries a different terminal.
/// Text-wrapped via TextPainter since real question options are full
/// sentences, not single numbers.
class AnswerTerminalComponent extends PositionComponent {
  AnswerTerminalComponent({required Vector2 position, required this.label, required this.isCorrect})
      : super(position: position, size: Vector2(120, 64), anchor: Anchor.center);

  final String label;
  final bool isCorrect;
  bool locked = false; // true once this question has been resolved
  bool _flashWrong = false;
  double _flashTimer = 0;

  void flashWrong() {
    _flashWrong = true;
    _flashTimer = 0.35;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashTimer > 0) {
      _flashTimer -= dt;
      if (_flashTimer <= 0) _flashWrong = false;
    }
  }

  @override
  void render(Canvas canvas) {
    final resolvedGood = locked && isCorrect;
    final baseColor = resolvedGood
        ? const Color(0xFF1B3B2E)
        : _flashWrong
            ? const Color(0xFF3B1B1F)
            : const Color(0xFF1C2438);
    final borderColor = resolvedGood
        ? const Color(0xFF3DDC84)
        : _flashWrong
            ? const Color(0xFFFF5A5F)
            : const Color(0xFF3DD6FF);

    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(10));
    canvas.drawRRect(rect, Paint()..color = baseColor);
    canvas.drawRRect(rect, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 2);

    final glow = Paint()
      ..color = borderColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRRect(rect.inflate(4), glow);

    final tp = TextPainter(
      text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12, height: 1.25)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: '…',
    )..layout(maxWidth: size.x - 12);
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
  }
}
