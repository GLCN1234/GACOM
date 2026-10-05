import 'package:flutter/material.dart';

enum Suit { spades, hearts, diamonds, clubs }

class PlayingCard {
  final int rank; // 1 = Ace ... 13 = King
  final Suit suit;
  const PlayingCard(this.rank, this.suit);

  static const List<String> _labels = ['', 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];

  bool get isRed => suit == Suit.hearts || suit == Suit.diamonds;
  int get id => suit.index * 13 + (rank - 1);
  String get label => _labels[rank];

  @override
  bool operator ==(Object other) => other is PlayingCard && other.rank == rank && other.suit == suit;
  @override
  int get hashCode => id;
  @override
  String toString() => '$label${suit.name[0]}';
}

List<PlayingCard> buildDeck() => [
  for (final s in Suit.values)
    for (int r = 1; r <= 13; r++) PlayingCard(r, s),
];

/// Draws a suit symbol as a vector shape so it never depends on a
/// font having the suit glyphs.
class SuitPainter extends CustomPainter {
  final Suit suit;
  final Color color;
  SuitPainter(this.suit, this.color);

  static Path _heart(double w, double h) {
    double x(double v) => v * w;
    double y(double v) => v * h;
    return Path()
      ..moveTo(x(0.5), y(0.95))
      ..cubicTo(x(0.05), y(0.62), x(-0.02), y(0.28), x(0.27), y(0.12))
      ..cubicTo(x(0.40), y(0.05), x(0.5), y(0.15), x(0.5), y(0.28))
      ..cubicTo(x(0.5), y(0.15), x(0.60), y(0.05), x(0.73), y(0.12))
      ..cubicTo(x(1.02), y(0.28), x(0.95), y(0.62), x(0.5), y(0.95))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    switch (suit) {
      case Suit.hearts:
        canvas.drawPath(_heart(w, h), paint);
        break;
      case Suit.diamonds:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.04)
            ..lineTo(w * 0.9, h * 0.5)
            ..lineTo(w * 0.5, h * 0.96)
            ..lineTo(w * 0.1, h * 0.5)
            ..close(),
          paint,
        );
        break;
      case Suit.spades:
        canvas.save();
        canvas.translate(0, h * 0.8);
        canvas.scale(1, -0.8);
        canvas.drawPath(_heart(w, h), paint);
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.55)
            ..lineTo(w * 0.36, h * 0.97)
            ..lineTo(w * 0.64, h * 0.97)
            ..close(),
          paint,
        );
        break;
      case Suit.clubs:
        canvas.drawCircle(Offset(w * 0.5, h * 0.27), w * 0.2, paint);
        canvas.drawCircle(Offset(w * 0.27, h * 0.56), w * 0.2, paint);
        canvas.drawCircle(Offset(w * 0.73, h * 0.56), w * 0.2, paint);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.5, h * 0.5)
            ..lineTo(w * 0.36, h * 0.97)
            ..lineTo(w * 0.64, h * 0.97)
            ..close(),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(SuitPainter oldDelegate) => oldDelegate.suit != suit || oldDelegate.color != color;
}

class PlayingCardView extends StatelessWidget {
  final PlayingCard? card;
  final bool faceUp;
  final double width;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  const PlayingCardView({
    super.key,
    this.card,
    this.faceUp = true,
    required this.width,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  double get height => width * 1.4;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final showFace = faceUp && c != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: showFace ? (dimmed ? const Color(0xFFD8D8D8) : Colors.white) : const Color(0xFF283593),
          borderRadius: BorderRadius.circular(width * 0.1),
          border: Border.all(
            color: selected ? const Color(0xFFFFD700) : (showFace ? const Color(0xFFB0B0B0) : const Color(0xFF9FA8DA)),
            width: selected ? 2.5 : 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: showFace ? _face(c) : _back(),
      ),
    );
  }

  Widget _back() => Center(
    child: Container(
      width: width * 0.62,
      height: height * 0.7,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.07),
        border: Border.all(color: const Color(0xFF9FA8DA), width: 1),
      ),
    ),
  );

  Widget _face(PlayingCard c) {
    final color = c.isRed ? const Color(0xFFD32F2F) : const Color(0xFF212121);
    return Stack(children: [
      Positioned(
        left: width * 0.08,
        top: width * 0.03,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(c.label, style: TextStyle(fontSize: width * 0.3, fontWeight: FontWeight.w800, color: color, height: 1.1)),
          SizedBox(width: width * 0.03),
          SizedBox(width: width * 0.2, height: width * 0.2, child: CustomPaint(painter: SuitPainter(c.suit, color))),
        ]),
      ),
      Positioned(
        left: width * 0.25,
        bottom: width * 0.1,
        width: width * 0.5,
        height: width * 0.5,
        child: CustomPaint(painter: SuitPainter(c.suit, color)),
      ),
    ]);
  }
}
