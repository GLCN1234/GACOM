import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  static String? get currentUserId => auth.currentUser?.id;
  static User? get currentUser => auth.currentUser;
  static bool get isLoggedIn => auth.currentSession != null;

  // Storage helpers
  static String getPublicUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }

  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    String? contentType,
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: contentType ?? 'image/jpeg',
            upsert: true,
          ),
        );
    return getPublicUrl(bucket, path);
  }
}

// Re-export for convenience
export 'package:supabase_flutter/supabase_flutter.dart' show Uint8List;
