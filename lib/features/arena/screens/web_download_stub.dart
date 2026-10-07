// No-op on non-web platforms — never called there, since the mobile
// path uses the real in-app downloader instead.
import 'dart:typed_data';
void saveWebDownload(Uint8List bytes, String filename) {}

void openDownloadPage() {}
