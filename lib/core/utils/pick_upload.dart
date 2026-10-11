import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Lets the user choose a picture and uploads it to [bucket] under their own
/// folder. Returns the public URL, or null when nothing was chosen.
/// Throws a readable message string on failure.
Future<String?> pickAndUploadImage({required String bucket, int maxBytes = 5 * 1024 * 1024}) async {
  final uid = SupabaseService.currentUserId;
  if (uid == null) throw 'Please sign in';
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  if (bytes.isEmpty) throw 'That file is empty';
  if (bytes.length > maxBytes) throw 'That picture is too large. The limit is ${maxBytes ~/ (1024 * 1024)} MB.';
  final name = x.name.toLowerCase();
  final ext = name.endsWith('.png') ? 'png' : (name.endsWith('.webp') ? 'webp' : 'jpg');
  final type = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
  final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
  try {
    await SupabaseService.client.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type, upsert: false));
  } catch (_) {
    throw 'Upload failed. Check your connection and try again.';
  }
  return SupabaseService.client.storage.from(bucket).getPublicUrl(path);
}
