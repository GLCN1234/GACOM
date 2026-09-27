// Real implementation — only compiled into web builds. Using a
// hidden anchor element's own click() is the standard, native browser
// way to trigger a download without navigating the page away at all —
// no blank/reload flash, since the page itself never actually leaves.
import 'dart:html' as html;

void triggerWebDownload(String url) {
  final anchor = html.AnchorElement(href: url)
    ..download = 'gacom-latest.apk'
    ..target = '_blank';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
