import 'package:flutter/material.dart';
import '../../../shared/widgets/glass_container.dart';
import '../tokens/radius.dart';

/// Design-system-named entry point for the real glass card — actual
/// BackdropFilter blur underneath (see GlassContainer), not a fake
/// translucent-tint card. This is a naming/organizing wrapper, not a
/// second implementation, so there's exactly one real glass system.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentGlow;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = GRadius.xl,
    this.padding,
    this.margin,
    this.accentGlow,
  });

  @override
  Widget build(BuildContext context) => GlassContainer(
    radius: radius,
    padding: padding,
    margin: margin,
    accentGlow: accentGlow,
    child: child,
  );
}
