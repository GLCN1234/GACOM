import 'dart:typed_data';
import 'save_image_io.dart' if (dart.library.html) 'save_image_web.dart' as impl;

/// Outcome of saving a picture for the person.
class SaveImageResult {
  final bool ok;
  final String message;
  const SaveImageResult(this.ok, this.message);
}

/// Saves PNG [bytes]. On the web it downloads the file; in the Android and iOS
/// apps it saves into the photo gallery (album "GACOM").
Future<SaveImageResult> saveImage(Uint8List bytes, String name) => impl.saveImage(bytes, name);
