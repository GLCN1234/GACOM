import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static String? get currentUserId => currentUser?.id;

  static Future<void> initialize() async {
    // On web (Netlify), route through the proxy to avoid ERR_QUIC_PROTOCOL_ERROR.
    // Netlify's redirect rule forwards /supabase-proxy/* → real Supabase host.
    final url = kIsWeb
        ? '${Uri.base.origin}${AppConstants.supabaseProxyUrl}'
        : AppConstants.supabaseUrl;

    await Supabase.initialize(
      url: url,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
}
