// Real implementation — only compiled into web builds. Takes the
// already-downloaded bytes and saves them as a correctly MIME-typed
// blob — explicitly setting application/vnd.android.package-archive
// here is what lets Chrome recognize this as an installable APK and
// offer its own "tap to install" action once the download finishes,
// the same way it would for a Play Store-hosted file.
import 'dart:html' as html;
import 'dart:typed_data';

void saveWebDownload(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes], 'application/vnd.android.package-archive');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..target = '_blank';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Opens the full download page, where the browser's own download manager
/// does the work and the person gets step-by-step install help.
void openDownloadPage() {
  html.window.location.assign('/download/');
}
