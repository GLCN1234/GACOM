// Real implementation — only ever compiled into web builds, since this
// file is only selected via the conditional import in main.dart when
// dart.library.html is available. Never imported directly by anything
// that might also target iOS/Android.
import 'dart:html' as html;

void showFatalErrorOnPage(String error, String stack) {
  // Avoid stacking duplicate overlays if multiple errors fire
  html.document.getElementById('gacom-fatal-error')?.remove();
  final div = html.DivElement()
    ..id = 'gacom-fatal-error'
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.left = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.background = '#1a0000'
    ..style.color = '#ffffff'
    ..style.padding = '20px'
    ..style.zIndex = '999999'
    ..style.fontFamily = 'monospace'
    ..style.fontSize = '12px'
    ..style.overflow = 'auto'
    ..style.whiteSpace = 'pre-wrap'
    ..text = '⚠️ App crashed — screenshot this:\n\n$error\n\n$stack';
  html.document.body?.append(div);
}
