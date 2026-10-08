import 'package:flutter/foundation.dart';

/// Rules that depend on where GACOM is running.
///
/// On the iPhone/iPad app, Apple requires that digital purchases made inside
/// the app go through Apple In-App Purchase. GACOM uses Paystack on the web
/// and Android app, and Apple In-App Purchase on iOS. Everything else (games,
/// shop items bought with wallet balance, Houses, Edu content) is identical.
///
/// The website opened in Safari on an iPhone is NOT affected: [kIsWeb] is true
/// there, so Paystack stays in use.
class PlatformPolicy {
  PlatformPolicy._();

  static bool get isIosApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// True inside the iOS app: wallet top-ups and Premium are bought through
  /// Apple In-App Purchase there, not Paystack.
  static bool get usesAppleIap => isIosApp;

  /// The Android install button and update prompts are Android-only.
  static bool get allowApkInstall => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
