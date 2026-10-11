import 'supabase_service.dart';

class HostResult {
  final bool success;
  final String? error;
  final Map<String, dynamic> data;
  const HostResult(this.success, {this.error, this.data = const {}});
}

/// Verification subscription and competition hosting.
class HostingService {
  static Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];

  static HostResult _res(dynamic v) {
    final m = _map(v);
    return HostResult(m['success'] == true, error: m['error'] as String?, data: m);
  }

  static Future<Map<String, dynamic>> verificationState() async {
    try {
      return _map(await SupabaseService.client.rpc('verification_state'));
    } catch (_) {
      return {};
    }
  }

  /// The state plus every level with its limits and assets (for the verification screen).
  static Future<Map<String, dynamic>> overview() async {
    try {
      return _map(await SupabaseService.client.rpc('verification_overview'));
    } catch (_) {
      return {};
    }
  }

  static Future<Map<String, dynamic>> idState() async {
    try {
      return _map(await SupabaseService.client.rpc('id_check_state'));
    } catch (_) {
      return {};
    }
  }

  static Future<HostResult> idSubmit({required String docType, required String fullName, required String docPath, required String selfiePath}) async {
    try {
      return _res(await SupabaseService.client.rpc('id_check_submit',
          params: {'p_doc_type': docType, 'p_full_name': fullName, 'p_doc_path': docPath, 'p_selfie_path': selfiePath}));
    } catch (_) {
      return const HostResult(false, error: 'Could not send your ID. Try again.');
    }
  }

  static Future<HostResult> subscribe(String tier, int months) async {
    try {
      return _res(await SupabaseService.client.rpc('verification_subscribe', params: {'p_tier': tier, 'p_months': months}));
    } catch (_) {
      return const HostResult(false, error: 'Could not reach the server. You were not charged.');
    }
  }

  static Future<bool> isHost() async => (await verificationState())['host'] == true;

  static Future<HostResult> create(Map<String, dynamic> p) async {
    try {
      return _res(await SupabaseService.client.rpc('host_create_competition', params: p));
    } catch (_) {
      return const HostResult(false, error: 'Could not reach the server. You were not charged.');
    }
  }

  static Future<HostResult> update(String id, {required String title, String? description, String? rules, String? banner}) async {
    try {
      return _res(await SupabaseService.client.rpc('host_update_competition', params: {
        'p_id': id, 'p_title': title, 'p_description': description, 'p_rules': rules, 'p_banner_url': banner,
      }));
    } catch (_) {
      return const HostResult(false, error: 'Could not save the changes');
    }
  }

  static Future<HostResult> cancel(String id) async {
    try {
      return _res(await SupabaseService.client.rpc('host_cancel_competition', params: {'p_id': id}));
    } catch (_) {
      return const HostResult(false, error: 'Could not cancel right now');
    }
  }

  static Future<HostResult> finish(String id, List<Map<String, dynamic>> winners) async {
    try {
      return _res(await SupabaseService.client.rpc('host_finish_competition', params: {'p_id': id, 'p_winners': winners}));
    } catch (_) {
      return const HostResult(false, error: 'Could not settle right now. Nothing was paid.');
    }
  }

  static Future<List<Map<String, dynamic>>> mine() async {
    try {
      return _list(await SupabaseService.client.rpc('host_my_competitions'));
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> players(String id) async {
    try {
      return _list(await SupabaseService.client.rpc('host_competition_players', params: {'p_id': id}));
    } catch (_) {
      return [];
    }
  }

  static Future<void> sweep() async {
    try {
      await SupabaseService.client.rpc('comp_sweep');
    } catch (_) {}
  }
}
