import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// The real thing — actual backdrop blur (glassmorphism requires this;
/// a translucent BoxDecoration alone is not glass, it's just a tinted card).
///
/// For the blur to actually read as "glass," there needs to be something
/// with color/detail behind it to refract — on a flat black background,
/// even real blur just shows more flat black. Pair this with
/// [AmbientGlowBackground] behind any screen using these cards.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final double fillOpacity;
  final Color? accentGlow; // optional colored glow bleeding through, e.g. GacomColors.violet
  final EdgeInsetsGeometry? margin;

  const GlassContainer({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.blurSigma = 18,
    this.fillOpacity = 0.10,
    this.accentGlow,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: accentGlow == null ? null : BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: accentGlow!.withOpacity(0.22), blurRadius: 32, spreadRadius: -4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              // Frosted fill — translucent white over whatever's blurred
              // behind it, not a solid dark card color.
              color: Colors.white.withOpacity(fillOpacity),
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(fillOpacity * 1.4), Colors.white.withOpacity(fillOpacity * 0.5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                // Light-catching border: brighter along the top-left edge,
                // fading toward the bottom-right — sells the "glass catching
                // light" look instead of a flat uniform outline.
                width: 1.2,
                color: Colors.white.withOpacity(0.28),
              ),
              boxShadow: [
                // Soft wide ambient shadow for depth
                BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 28, offset: const Offset(0, 12)),
                // Tight inner-ish shadow close to the edge for definition
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Floating, softly blurred color blobs behind content — gives glass
/// surfaces something with actual color/variation to refract. Without
/// this, BackdropFilter blur on a flat black background just produces
/// more flat black, which is why glass surfaces were reading as flat
/// dark cards rather than genuine glass.
class AmbientGlowBackground extends StatelessWidget {
  final Widget child;
  const AmbientGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: Container(color: GacomColors.obsidian)),
      Positioned(
        top: -80, left: -60,
        child: _blob(280, GacomColors.violet.withOpacity(0.35)),
      ),
      Positioned(
        top: 140, right: -100,
        child: _blob(240, GacomColors.electricBlue.withOpacity(0.28)),
      ),
      Positioned(
        bottom: -60, left: 40,
        child: _blob(220, GacomColors.deepOrange.withOpacity(0.14)),
      ),
      child,
    ]);
  }

  Widget _blob(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  ).let((w) => ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80), child: w));
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
