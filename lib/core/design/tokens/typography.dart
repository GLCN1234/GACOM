import 'package:flutter/material.dart';
import 'colors.dart';

/// Named text-style presets, all using the Rajdhani font family already
/// established across GACOM's UI, so screens stop hand-writing repeated
/// TextStyle blocks with slightly different values each time.
class GText {
  static const _family = 'Rajdhani';

  static const displayLarge = TextStyle(fontFamily: _family, fontWeight: FontWeight.w800, fontSize: 28, color: GColors.textPrimary);
  static const headline = TextStyle(fontFamily: _family, fontWeight: FontWeight.w800, fontSize: 20, color: GColors.textPrimary);
  static const title = TextStyle(fontFamily: _family, fontWeight: FontWeight.w700, fontSize: 16, color: GColors.textPrimary);
  static const body = TextStyle(fontFamily: _family, fontWeight: FontWeight.w500, fontSize: 14, color: GColors.textSecondary);
  static const caption = TextStyle(fontFamily: _family, fontWeight: FontWeight.w600, fontSize: 12, color: GColors.textMuted);
  static const label = TextStyle(fontFamily: _family, fontWeight: FontWeight.w700, fontSize: 11, color: GColors.textMuted, letterSpacing: 0.8);

  static const buttonLabel = TextStyle(fontFamily: _family, fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white);
}
