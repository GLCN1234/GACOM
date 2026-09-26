// Real implementation — only ever compiled into web builds, since this
// file is only selected via the conditional import in main.dart when
// dart.library.html is available. Never imported directly by anything
// that might also target iOS/Android.
import 'dart:html' as html;

void showFatalErrorOnPage(String error, String stack) {
  // Avoid stacking duplicate overlays if multiple errors fire
  html.document.getElementById('gacom-fatal-error')?.remove();

  final overlay = html.DivElement()
    ..id = 'gacom-fatal-error'
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.left = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.background = '#0A0A0F'
    ..style.color = '#ffffff'
    ..style.zIndex = '999999'
    ..style.display = 'flex'
    ..style.flexDirection = 'column'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.padding = '24px'
    ..style.fontFamily = 'sans-serif'
    ..style.textAlign = 'center';

  final icon = html.DivElement()
    ..style.fontSize = '40px'
    ..style.marginBottom = '16px'
    ..text = '⚠';
  final title = html.HeadingElement.h2()
    ..text = 'Something went wrong'
    ..style.margin = '0 0 8px 0'
    ..style.fontSize = '18px';
  final subtitle = html.ParagraphElement()
    ..text = 'This screen ran into a problem. Try reloading — your progress elsewhere in the app is safe.'
    ..style.color = '#9CA3AF'
    ..style.fontSize = '14px'
    ..style.maxWidth = '340px'
    ..style.margin = '0 0 24px 0';

  final reloadBtn = html.ButtonElement()
    ..text = 'Reload'
    ..style.background = '#E84B00'
    ..style.color = '#ffffff'
    ..style.border = 'none'
    ..style.borderRadius = '50px'
    ..style.padding = '12px 32px'
    ..style.fontSize = '14px'
    ..style.fontWeight = 'bold'
    ..style.cursor = 'pointer'
    ..style.marginBottom = '16px';
  reloadBtn.onClick.listen((_) => html.window.location.reload());

  final detailsToggle = html.AnchorElement()
    ..text = 'Show technical details'
    ..style.color = '#6B7280'
    ..style.fontSize = '12px'
    ..style.cursor = 'pointer'
    ..style.textDecoration = 'underline';

  final detailsBox = html.PreElement()
    ..text = '$error\n\n$stack'
    ..style.display = 'none'
    ..style.marginTop = '16px'
    ..style.padding = '16px'
    ..style.background = '#1A0000'
    ..style.borderRadius = '8px'
    ..style.fontSize = '11px'
    ..style.textAlign = 'left'
    ..style.maxWidth = '90vw'
    ..style.maxHeight = '40vh'
    ..style.overflow = 'auto'
    ..style.whiteSpace = 'pre-wrap';

  detailsToggle.onClick.listen((_) {
    final showing = detailsBox.style.display != 'none';
    detailsBox.style.display = showing ? 'none' : 'block';
    detailsToggle.text = showing ? 'Show technical details' : 'Hide technical details';
  });

  overlay.append(icon);
  overlay.append(title);
  overlay.append(subtitle);
  overlay.append(reloadBtn);
  overlay.append(detailsToggle);
  overlay.append(detailsBox);
  html.document.body?.append(overlay);
}
