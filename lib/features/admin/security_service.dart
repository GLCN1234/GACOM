import '../../core/services/supabase_service.dart';

/// Thin wrapper over the admin-only security RPCs. Every call is gated on the
/// server by identity_is_admin(); a non-admin gets a 'forbidden' error.
class SecurityService {
  SecurityService._();

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static Future<Map<String, dynamic>> overview() async =>
      _map(await SupabaseService.client.rpc('admin_security_overview'));

  static Future<Map<String, dynamic>> posture() async =>
      _map(await SupabaseService.client.rpc('admin_security_posture'));

  static Future<Map<String, dynamic>> events({
    String? severity,
    String? status,
    String? kind,
    int limit = 50,
    int offset = 0,
  }) async =>
      _map(await SupabaseService.client.rpc('admin_security_events', params: {
        'p_severity': severity,
        'p_status': status,
        'p_kind': kind,
        'p_limit': limit,
        'p_offset': offset,
      }));

  static Future<void> setStatus(String id, String status, {String? note}) async {
    await SupabaseService.client.rpc('admin_security_ack', params: {
      'p_id': id,
      'p_status': status,
      'p_note': note,
    });
  }

  static Future<Map<String, dynamic>> auditTrail({String? table, int limit = 100}) async =>
      _map(await SupabaseService.client.rpc('admin_audit_trail', params: {
        'p_table': table,
        'p_actor': null,
        'p_limit': limit,
      }));

  static Future<Map<String, dynamic>> adminLogins() async =>
      _map(await SupabaseService.client.rpc('admin_recent_admin_logins'));

  static Future<Map<String, dynamic>> scanNow() async =>
      _map(await SupabaseService.client.rpc('admin_security_scan_now'));
}
