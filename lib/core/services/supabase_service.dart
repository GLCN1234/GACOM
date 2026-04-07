import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  static String? get currentUserId => auth.currentUser?.id;
  static User? get currentUser => auth.currentUser;
  static bool get isLoggedIn => auth.currentSession != null;

  static Future<void> initialize() async {
    final url = kIsWeb
        ? '${Uri.base.origin}/supabase-proxy'
        : AppConstants.supabaseUrl;
    await Supabase.initialize(
      url: url,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

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
