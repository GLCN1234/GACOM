// Android and iOS: saves into the photo gallery. Other desktop platforms
// have no gallery, so they get a clear message.
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'save_image.dart';

Future<SaveImageResult> saveImage(Uint8List bytes, String name) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    return const SaveImageResult(false, 'Saving to a gallery works in the phone app. Use the share button here.');
  }
  try {
    final bool has = await Gal.hasAccess(toAlbum: true);
    if (!has) {
      final bool granted = await Gal.requestAccess(toAlbum: true);
      if (!granted) {
        return const SaveImageResult(false, 'Allow photo access in your phone settings to save the card.');
      }
    }
    await Gal.putImageBytes(bytes, album: 'GACOM');
    return const SaveImageResult(true, 'Saved to your gallery in the GACOM album');
  } catch (e) {
    final String m = e.toString().toLowerCase();
    if (m.contains('access')) {
      return const SaveImageResult(false, 'Allow photo access in your phone settings to save the card.');
    }
    return const SaveImageResult(false, 'Could not save the picture. Try the share button instead.');
  }
}
