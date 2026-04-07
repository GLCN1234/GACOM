import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GacomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Widget? icon;
  final Color? color;
  final double? width;
  final double height;

  const GacomButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.color,
    this.width,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? GacomColors.deepOrange;

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: bg, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            foregroundColor: bg,
          ),
          child: _child(bg),
        ),
      );
    }

    // Gradient filled button
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: color == null ? GacomColors.orangeGradient : null,
          color: color,
          borderRadius: BorderRadius.circular(50),
          boxShadow: [
            BoxShadow(
              color: bg.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: _child(Colors.white)),
      ),
    );
  }

  Widget _child(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
      );
    }
    if (icon != null && label.isEmpty) return icon!;
    if (icon != null) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        icon!,
        const SizedBox(width: 8),
        _txt(textColor),
      ]);
    }
    return _txt(textColor);
  }

  Widget _txt(Color c) => Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.4, color: c));
}
