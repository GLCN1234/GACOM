import 'package:flutter/material.dart';
import '../../shared/widgets/rarity.dart';

/// A row of up to [max] stars, [stars] of them filled.
class JourneyStarRow extends StatelessWidget {
  final int stars;
  final int max;
  final double size;
  final Color color;
  const JourneyStarRow({super.key, required this.stars, this.max = 3, this.size = 16, this.color = Tac.gold});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < max; i++)
          Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < stars ? color : Tac.keyline),
      ],
    );
  }
}

/// A thin flat progress bar.
class JourneyBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const JourneyBar({super.key, required this.value, this.color = Tac.gold, this.height = 5});

  @override
  Widget build(BuildContext context) {
    final double v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      return Container(
        height: height,
        width: c.maxWidth,
        color: Tac.panel2,
        alignment: Alignment.centerLeft,
        child: Container(width: c.maxWidth * v, height: height, color: color),
      );
    });
  }
}

/// Small "NEW" tag.
class JourneyNewTag extends StatelessWidget {
  const JourneyNewTag({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: Tac.gold,
        shape: ChamferedBorder(cut: 4, side: BorderSide.none),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        child: Text('NEW', style: Tac.display(size: 9, weight: FontWeight.w800, color: Tac.bg, letter: 0.9)),
      ),
    );
  }
}

/// The one line that says Journey is separate from competition.
class JourneyFairNote extends StatelessWidget {
  const JourneyFairNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      const Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.balance_rounded, size: 14, color: Tac.textDim)),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          'Journey never affects competition scores.',
          style: Tac.body(size: 12, weight: FontWeight.w600, color: Tac.textDim),
        ),
      ),
    ]);
  }
}
