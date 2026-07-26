import 'package:flutter/material.dart';

/// Standard animation durations — keeps transition timing consistent
/// instead of every screen picking its own arbitrary millisecond value.
class GDurations {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const verySlow = Duration(milliseconds: 600);
}

class GCurves {
  static const standard = Curves.easeOutCubic;
  static const bounce = Curves.elasticOut;
  static const sharp = Curves.easeInOutQuint;
}
