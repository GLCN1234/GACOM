import 'supabase_service.dart';

/// Admin side of ad pricing, verification levels and ID checks.
class PricingAdmin {
  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  static Future<Map<String, dynamic>?> load() async {
    try {
      final r = await SupabaseService.client.rpc('admin_pricing_get');
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> setRate(String placement, int cpm, int cpc) async {
    try {
      final r = _map(await SupabaseService.client.rpc('admin_set_ad_rate', params: {'p_placement': placement, 'p_cpm': cpm, 'p_cpc': cpc}));
      return r['success'] == true ? null : (r['error'] as String? ?? 'Could not save');
    } catch (_) {
      return 'Could not save';
    }
  }

  static Future<String?> setSettings({required bool reviewFirst, required int maxLive, required int minDaily, required int maxDaily}) async {
    try {
      final r = _map(await SupabaseService.client.rpc('admin_set_ad_settings',
          params: {'p_review_first': reviewFirst, 'p_max_live': maxLive, 'p_min_daily': minDaily, 'p_max_daily': maxDaily}));
      return r['success'] == true ? null : (r['error'] as String? ?? 'Could not save');
    } catch (_) {
      return 'Could not save';
    }
  }

  static Future<String?> setTier(String code, Map<String, dynamic> cfg) async {
    try {
      final r = _map(await SupabaseService.client.rpc('admin_set_tier', params: {'p_code': code, 'p_cfg': cfg}));
      return r['success'] == true ? null : (r['error'] as String? ?? 'Could not save');
    } catch (_) {
      return 'Could not save';
    }
  }

  // ---- ID checks
  static Future<List<Map<String, dynamic>>> idQueue() async {
    try {
      return _list(await SupabaseService.client.rpc('admin_id_queue'));
    } catch (_) {
      return [];
    }
  }

  static Future<String?> signedUrl(String path) async {
    try {
      return await SupabaseService.client.storage.from('id-checks').createSignedUrl(path, 600);
    } catch (_) {
      return null;
    }
  }

  /// Records the decision, then deletes the two pictures.
  static Future<String?> idReview(String userId, bool approve, String? note) async {
    try {
      final r = _map(await SupabaseService.client.rpc('admin_id_review', params: {'p_user': userId, 'p_approve': approve, 'p_note': note}));
      if (r['success'] != true) return r['error'] as String? ?? 'Could not save';
      final paths = ((r['paths'] as List?) ?? []).whereType<String>().toList();
      if (paths.isNotEmpty) {
        try {
          await SupabaseService.client.storage.from('id-checks').remove(paths);
        } catch (_) {}
      }
      return null;
    } catch (_) {
      return 'Could not save';
    }
  }
}
