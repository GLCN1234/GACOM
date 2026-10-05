import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Clamps a double and always returns a double.
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Shared start screen for the quick arcade games.
class ArcadeStartView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onStart;
  final List<Widget> extra;
  const ArcadeStartView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onStart,
    this.buttonLabel = 'PLAY',
    this.extra = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: GacomColors.deepOrange, size: 54),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 26, color: GacomColors.textPrimary)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 13)),
        if (extra.isNotEmpty) ...[const SizedBox(height: 22), ...extra],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
            onPressed: onStart,
            child: Text(buttonLabel, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
    ),
  );
}

/// A labelled row of choice chips (for difficulty and similar options).
class ArcadeChoiceRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;
  const ArcadeChoiceRow({super.key, required this.label, required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
    const SizedBox(height: 10),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (int i = 0; i < options.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: selected == i ? GacomColors.deepOrange.withValues(alpha: 0.18) : GacomColors.cardDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected == i ? GacomColors.deepOrange : GacomColors.border, width: 1.5),
              ),
              child: Text(options[i], style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 14, color: selected == i ? GacomColors.deepOrange : GacomColors.textPrimary)),
            ),
          ),
        ),
    ]),
  ]);
}

/// Shared game-over / result card.
class ArcadeResultOverlay extends StatelessWidget {
  final bool good;
  final String title;
  final String detail;
  final VoidCallback onAgain;
  final VoidCallback onExit;
  final String againLabel;
  const ArcadeResultOverlay({
    super.key,
    required this.good,
    required this.title,
    required this.detail,
    required this.onAgain,
    required this.onExit,
    this.againLabel = 'PLAY AGAIN',
  });

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.black.withValues(alpha: 0.8),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(26),
        decoration: GacomDecorations.glassCard(context, radius: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(good ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded, color: good ? const Color(0xFFFFD700) : GacomColors.textMuted, size: 52),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white)),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: onExit, child: const Text('EXIT', style: TextStyle(color: GacomColors.textMuted, fontFamily: 'Rajdhani', fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: GacomColors.deepOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
              onPressed: onAgain,
              child: Text(againLabel, style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ]),
      ),
    ),
  );
}
