import 'package:flutter/material.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Standard search bar — tappable (navigates to a real search screen) or
/// live-typing (with onChanged), matching the pill-shaped search inputs
/// already used across Home/Chat/Communities.
class GSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const GSearchBar({
    super.key,
    this.hint = 'Search...',
    this.onTap,
    this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final field = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: GColors.card,
        borderRadius: BorderRadius.circular(GRadius.pill),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, color: GColors.textMuted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: onTap != null
              ? Text(hint, style: GText.body.copyWith(color: GColors.textMuted))
              : TextField(
                  controller: controller,
                  onChanged: onChanged,
                  style: GText.body.copyWith(color: GColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GText.body.copyWith(color: GColors.textMuted),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
        ),
      ]),
    );

    return onTap != null ? GestureDetector(onTap: onTap, child: field) : field;
  }
}
