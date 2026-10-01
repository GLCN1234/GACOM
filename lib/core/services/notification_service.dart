import 'supabase_service.dart';

class NotificationService {
  /// Real-time unread count — the bell badge subscribes to this
  /// instead of showing a hardcoded dot regardless of actual state.
  static Stream<int> unreadCountStream() {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return Stream.value(0);
    return SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map((rows) => rows.where((r) => r['read'] != true).length);
  }

  static Future<List<Map<String, dynamic>>> list() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return [];
    final data = await SupabaseService.client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<void> markRead(String id) async {
    try { await SupabaseService.client.from('notifications').update({'read': true}).eq('id', id); } catch (_) {}
  }

  static Future<void> markAllRead() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try { await SupabaseService.client.from('notifications').update({'read': true}).eq('user_id', uid).eq('read', false); } catch (_) {}
  }
}
