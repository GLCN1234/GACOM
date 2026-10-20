import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Competition flyer. Uses the plain network image so a failure is visible
/// (a message instead of a blank block) and a slow load shows a spinner.
class FlyerImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final bool showError;
  /// True shows the whole flyer (no cropping) at its own shape; false fills the box and crops.
  final bool natural;
  const FlyerImage({super.key, required this.url, this.fit = BoxFit.cover, this.showError = true, this.natural = false});

  @override
  Widget build(BuildContext context) {
    if (natural) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 460, minHeight: 120),
        child: Container(
          color: GacomColors.elevatedCard,
          width: double.infinity,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (c, child, p) => p == null ? child : const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange))),
            errorBuilder: (c, e, st) => const SizedBox(height: 120, child: Center(child: Text('Flyer could not load', style: TextStyle(color: GacomColors.textMuted, fontSize: 11)))),
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (c, child, p) => p == null
          ? child
          : Container(color: GacomColors.elevatedCard, alignment: Alignment.center, child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: GacomColors.deepOrange))),
      errorBuilder: (c, e, s) => Container(
        color: GacomColors.elevatedCard,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: showError
            ? const Text('Flyer could not load', textAlign: TextAlign.center, style: TextStyle(color: GacomColors.textMuted, fontSize: 11))
            : const Icon(Icons.image_not_supported_outlined, color: GacomColors.textMuted, size: 20),
      ),
    );
  }
}
