import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Transparent, blur-free app bar matching GACOM's dark visual language —
/// use inside a Scaffold with AmbientGlowBackground/GlassContainer content
/// below it so the bar reads as part of the same glass-on-dark system.
class PremiumAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? leading;

  const PremiumAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leading: leading ?? (showBackButton && Navigator.of(context).canPop()
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: GColors.textPrimary), onPressed: () => Navigator.of(context).pop())
          : null),
      title: Text(title, style: GText.headline),
      actions: actions,
    );
  }
}
