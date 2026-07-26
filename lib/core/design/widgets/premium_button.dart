import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';
import '../tokens/durations.dart';

enum PremiumButtonVariant { primary, secondary, outline }

/// Consistent button styling across the app — primary (solid accent),
/// secondary (glass-tinted), and outline (border only, transparent fill).
class PremiumButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PremiumButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;
  final bool loading;

  const PremiumButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PremiumButtonVariant.primary,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;

    Color bg;
    Color fg;
    Border? border;
    switch (variant) {
      case PremiumButtonVariant.primary:
        bg = disabled ? GColors.primary.withOpacity(0.4) : GColors.primary;
        fg = Colors.white;
        border = null;
        break;
      case PremiumButtonVariant.secondary:
        bg = GColors.card.withOpacity(0.8);
        fg = GColors.textPrimary;
        border = Border.all(color: Colors.white.withOpacity(0.1));
        break;
      case PremiumButtonVariant.outline:
        bg = Colors.transparent;
        fg = disabled ? GColors.textMuted : GColors.primary;
        border = Border.all(color: disabled ? GColors.textMuted.withOpacity(0.3) : GColors.primary);
        break;
    }

    final content = loading
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, color: fg, size: 18), const SizedBox(width: 8)],
            Text(label, style: GText.buttonLabel.copyWith(color: fg)),
          ]);

    return AnimatedContainer(
      duration: GDurations.fast,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(GRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GRadius.pill), border: border),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }
}
