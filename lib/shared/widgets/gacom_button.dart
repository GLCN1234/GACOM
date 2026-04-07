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
  final bool useGradient;

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
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? GacomColors.deepOrange;

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: height,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: bgColor, width: 1.2),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50)),
            foregroundColor: bgColor,
          ),
          child: _child(bgColor),
        ),
      );
    }

    if (useGradient && color == null) {
      return GestureDetector(
        onTap: isLoading ? null : onPressed,
        child: Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            gradient: GacomColors.orangeGradient,
            borderRadius: BorderRadius.circular(50),
            boxShadow: [
              BoxShadow(
                color: GacomColors.deepOrange.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(child: _child(Colors.white)),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50)),
          elevation: 0,
        ),
        child: _child(Colors.white),
      ),
    );
  }

  Widget _child(Color textColor) {
    if (isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor),
      );
    }
    if (icon != null && label.isEmpty) return icon!;
    if (icon != null) {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        icon!,
        const SizedBox(width: 8),
        _labelText(textColor),
      ]);
    }
    return _labelText(textColor);
  }

  Widget _labelText(Color textColor) => Text(
        label,
        style: TextStyle(
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 1.4,
          color: textColor,
        ),
      );
}
