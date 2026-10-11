// Web: hands the picture to the browser as a download.
import 'dart:html' as html;
import 'dart:typed_data';
import 'save_image.dart';

Future<SaveImageResult> saveImage(Uint8List bytes, String name) async {
  try {
    final blob = html.Blob(<dynamic>[bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..download = name;
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
    return const SaveImageResult(true, 'Saved to your downloads');
  } catch (_) {
    return const SaveImageResult(false, 'Your browser blocked the download. Try the share button instead.');
  }
}
