import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../utils/strip_expired_auth_link_stub.dart'
    if (dart.library.html) '../utils/strip_expired_auth_link_web.dart' as strip_url;

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;

  static String? get currentUserId => auth.currentUser?.id;
  static User? get currentUser => auth.currentUser;
  static bool get isLoggedIn => auth.currentSession != null;

  static Future<void> initialize() async {
    _stripExpiredAuthLinkFromUrl();
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  /// A magic/reset link that's already expired arrives with
  /// error=access_denied&error_code=otp_expired in the URL fragment.
  /// Left alone, Supabase's own SDK tries to process it and throws an
  /// uncaught AuthException during startup — a crash for something that
  /// isn't really a bug, just a stale link. Stripping it here means
  /// Supabase never sees it, so there's nothing to throw; the app just
  /// boots normally to the login screen instead.
  static void _stripExpiredAuthLinkFromUrl() {
    strip_url.stripExpiredAuthLinkFromUrl();
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
