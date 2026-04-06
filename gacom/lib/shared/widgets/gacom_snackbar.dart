import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class GacomSnackbar {
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color bgColor;
    IconData icon;
    if (isError) {
      bgColor = GacomColors.error;
      icon = Icons.error_outline_rounded;
    } else if (isSuccess) {
      bgColor = GacomColors.success;
      icon = Icons.check_circle_outline_rounded;
    } else {
      bgColor = GacomColors.deepOrange;
      icon = Icons.info_outline_rounded;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: bgColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: duration,
      ),
    );
  }
}
