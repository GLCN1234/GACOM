import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Named token wrapper around GacomColors — same source of truth, cleaner
/// design-system-style names for anyone referencing the token layer
/// directly instead of the theme file.
class GColors {
  static const primary = GacomColors.deepOrange;
  static const primaryLight = GacomColors.burnOrange;
  static const primaryPressed = GacomColors.darkOrange;

  static const secondary = GacomColors.violet;
  static const secondaryDeep = GacomColors.violetDeep;
  static const accent = GacomColors.electricBlue;

  static const success = GacomColors.success;
  static const error = GacomColors.error;
  static const warning = GacomColors.warning;

  static const background = GacomColors.obsidian;
  static const surface = GacomColors.surfaceDark;
  static const card = GacomColors.cardDark;
  static const elevated = GacomColors.elevatedCard;

  static const textPrimary = GacomColors.textPrimary;
  static const textSecondary = GacomColors.textSecondary;
  static const textMuted = GacomColors.textMuted;

  static Color onSurface(BuildContext context) => GacomColors.txtSecondary(context);
  static Color border(BuildContext context) => GacomColors.borderColor(context);
}
