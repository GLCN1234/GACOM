import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';

class AdResult {
  final bool success;
  final String? error;
  final Map<String, dynamic> data;
  const AdResult(this.success, {this.error, this.data = const {}});
}

/// Everything the Advertise screens and the sponsored placements need.
class AdsService {
  static const interests = <String, String>{
    'darkom': 'Darkom City players',
    'chess': 'Chess players',
    'quiz': 'Quiz and word games',
    'shooters': 'Shooter fans',
    'football': 'Football game fans',
    'competitors': 'Tournament players',
    'shoppers': 'Store shoppers',
  };

  static const countries = <String>[
    'Nigeria', 'Ghana', 'Kenya', 'South Africa', 'Egypt', 'Tanzania', 'Uganda',
    'Cameroon', 'Senegal', 'Ethiopia', 'Rwanda', 'Zambia', "Cote d'Ivoire",
    'United Kingdom', 'United States', 'Canada',
  ];

  static const ctas = <String>['Learn more', 'Shop now', 'Play now', 'Sign up', 'Download', 'Join now', 'Watch more', 'Contact us'];

  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  static Future<List<Map<String, dynamic>>> rates() async {
    try {
      return _list(await SupabaseService.client.rpc('ad_rates_list'));
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> platformStats() async {
    try {
      return _map(await SupabaseService.client.rpc('ad_platform_stats'));
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>?> estimate(Map<String, dynamic> cfg) async {
    try {
      final r = await SupabaseService.client.rpc('ad_estimate', params: {'p_cfg': cfg});
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<AdResult> create(Map<String, dynamic> cfg) async {
    try {
      final r = _map(await SupabaseService.client.rpc('ad_create', params: {'p_cfg': cfg}));
      return AdResult(r['success'] == true, error: r['error'] as String?, data: r);
    } catch (_) {
      return const AdResult(false, error: 'Could not reach the server. You were not charged.');
    }
  }

  static Future<AdResult> updateCreative(String id, Map<String, dynamic> cfg) async {
    try {
      final r = _map(await SupabaseService.client.rpc('ad_update_creative', params: {'p_id': id, 'p_cfg': cfg}));
      return AdResult(r['success'] == true, error: r['error'] as String?, data: r);
    } catch (_) {
      return const AdResult(false, error: 'Could not save the changes');
    }
  }

  static Future<AdResult> setStatus(String id, String action) async {
    try {
      final r = _map(await SupabaseService.client.rpc('ad_set_status', params: {'p_id': id, 'p_action': action}));
      return AdResult(r['success'] == true, error: r['error'] as String?, data: r);
    } catch (_) {
      return const AdResult(false, error: 'Could not update the campaign');
    }
  }

  static Future<List<Map<String, dynamic>>> myCampaigns() async {
    try {
      return _list(await SupabaseService.client.rpc('ad_my_campaigns'));
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> stats(String id) async {
    try {
      final r = await SupabaseService.client.rpc('ad_stats', params: {'p_id': id});
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (_) {
      return null;
    }
  }

  // ---- admin
  static Future<List<Map<String, dynamic>>> adminQueue() async {
    try {
      return _list(await SupabaseService.client.rpc('admin_ad_queue'));
    } catch (_) {
      return [];
    }
  }

  static Future<AdResult> adminReview(String id, bool approve, String? note) async {
    try {
      final r = _map(await SupabaseService.client
          .rpc('admin_ad_review', params: {'p_id': id, 'p_approve': approve, 'p_note': note}));
      return AdResult(r['success'] == true, error: r['error'] as String?, data: r);
    } catch (_) {
      return const AdResult(false, error: 'Could not save the decision');
    }
  }

  // ---- delivery
  /// Campaigns shown this session, so one person does not see the same ad in a row.
  static final List<String> _recent = [];
  static bool fullscreenShown = false;

  /// Asks the server for an ad for [placement]. Returns null when none fits.
  static Future<Map<String, dynamic>?> serve(String placement) async {
    if (!SupabaseService.isLoggedIn) return null;
    try {
      final r = await SupabaseService.client
          .rpc('ad_serve', params: {'p_placement': placement, 'p_recent': _recent.length > 4 ? _recent.sublist(_recent.length - 4) : _recent});
      if (r is! Map) return null;
      final m = Map<String, dynamic>.from(r);
      final id = m['campaign']?.toString();
      if (id != null) _recent.add(id);
      return m;
    } catch (e) {
      if (kDebugMode) debugPrint('ad_serve: $e');
      return null;
    }
  }

  /// Records the tap (billing it for traffic campaigns) and opens the advertiser's link.
  static Future<void> click(Map<String, dynamic> ad) async {
    String? url = ad['url'] as String?;
    try {
      final r = await SupabaseService.client.rpc('ad_click', params: {'p_impression': ad['impression']});
      if (r is Map && r['url'] != null) url = r['url'] as String;
    } catch (_) {}
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
