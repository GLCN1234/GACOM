// Stub used on every platform where dart:html isn't available (iOS,
// Android, desktop). On native platforms Flutter's normal crash reporting
// (device logs, Crashlytics, etc. once wired up) is the right tool anyway —
// this just makes sure the app doesn't fail to compile for mobile, and
// still surfaces the error to the console so it's not silently lost.
void showFatalErrorOnPage(String error, String stack) {
  // ignore: avoid_print
  print('⚠️ FATAL ERROR (no on-screen overlay on this platform): $error\n$stack');
}
