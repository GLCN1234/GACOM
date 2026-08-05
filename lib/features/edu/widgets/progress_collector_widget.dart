import 'package:flutter/material.dart';
import '../../../core/theme/theme_kit.dart';

/// The one collect-and-fill mechanic, reskinned per world theme.
/// Subject-agnostic on purpose: it only counts correct answers.
/// It never looks at what the question was about — a math level and
/// an English level fill the exact same bar toward the same celebration.
/// Pass target = the level session's question count (currently 10) so
/// one full bar = one full level session, ending at the existing
/// level-complete screen.
class ProgressCollectorWidget extends StatelessWidget {
  final ThemeKit kit;
  final int current;
  final int target;
  final String? chapterBeat; // from generated_questions[i]['chapter_update']

  const ProgressCollectorWidget({
    super.key, required this.kit, required this.current,
    required this.target, this.chapterBeat,
  });

  @override
  Widget build(BuildContext context) {
    final filled = current.clamp(0, target);
    final isComplete = filled >= target;

    return Column(children: [
      Wrap(
        alignment: WrapAlignment.center,
        children: List.generate(target, (i) {
          final isFilled = i < filled;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250), curve: Curves.easeOutBack,
            width: 26, height: 34, margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isFilled ? kit.primary : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
              border: isFilled ? null : Border.all(color: Colors.white.withOpacity(0.15), width: 2),
            ),
            child: isFilled ? Center(child: Container(width: 8, height: 8,
                decoration: BoxDecoration(color: kit.secondary, shape: BoxShape.circle))) : null,
          );
        }),
      ),
      if (isComplete) ...[
        const SizedBox(height: 20),
        _CompletionBadge(kit: kit),
        if (chapterBeat != null && chapterBeat!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(chapterBeat!, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.85), fontFamily: 'Rajdhani', fontSize: 14, height: 1.4))),
        ],
      ],
    ]);
  }
}

class _CompletionBadge extends StatelessWidget {
  final ThemeKit kit;
  const _CompletionBadge({required this.kit});
  @override
  Widget build(BuildContext context) => SizedBox(height: 90, child: Stack(alignment: Alignment.center, children: [
    ...List.generate(6, (i) {
      final dx = (i.isEven ? 34.0 : -34.0) * ((i % 4 < 2) ? 1 : 0.6);
      final dy = (i % 3 == 0 ? -30.0 : 30.0);
      return Positioned(left: 45 + dx, top: 45 + dy, child: Container(width: 10, height: 10,
        decoration: BoxDecoration(color: i.isEven ? kit.secondary : kit.accent,
          shape: i.isEven ? BoxShape.circle : BoxShape.rectangle)));
    }),
    Container(width: 64, height: 64, decoration: BoxDecoration(color: kit.primary, shape: BoxShape.circle),
      child: Icon(kit.collectibleIcon, color: kit.secondary, size: 30)),
  ]));
}
