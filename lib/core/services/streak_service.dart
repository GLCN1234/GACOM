import '../services/supabase_service.dart';
import '../../features/edu/edu_subscription_service.dart';

class StreakService {
  /// Call once per game completion — logs today as a played day. Safe
  /// to call repeatedly in one day (upsert), best-effort like the other
  /// game-completion side effects.
  static Future<void> logPlayToday() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      final today = DateTime.now().toUtc();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await SupabaseService.client.from('daily_play_log').upsert({'user_id': uid, 'play_date': dateStr}, onConflict: 'user_id,play_date');
    } catch (_) {}
  }

  static Future<int> currentStreak(String userId) async {
    try {
      final result = await SupabaseService.client.rpc('get_current_streak', params: {'p_user_id': userId});
      return (result as num?)?.toInt() ?? 0;
    } catch (_) { return 0; }
  }

  static Future<int> availableFreezes() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return 0;
    try {
      final rows = await SupabaseService.client.from('streak_freezes').select('id').eq('user_id', uid).filter('used_at', 'is', null);
      return (rows as List).length;
    } catch (_) { return 0; }
  }

  /// Grants a new freeze if the user is premium and hasn't already hit
  /// the monthly cap (2) — regular-play perk only, never touches
  /// competition scoring in any way.
  static Future<bool> grantMonthlyFreezesIfEligible() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;
    final isPro = await EduSubscriptionService.isPro();
    if (!isPro) return false;
    try {
      final now = DateTime.now().toUtc();
      final monthStart = DateTime.utc(now.year, now.month, 1);
      final grantedThisMonth = await SupabaseService.client.from('streak_freezes')
          .select('id').eq('user_id', uid).gte('granted_at', monthStart.toIso8601String());
      if ((grantedThisMonth as List).length >= 2) return false;
      await SupabaseService.client.from('streak_freezes').insert({'user_id': uid});
      return true;
    } catch (_) { return false; }
  }

  static Future<bool> useFreezeForToday() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return false;
    try {
      final today = DateTime.now().toUtc();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final available = await SupabaseService.client.from('streak_freezes')
          .select('id').eq('user_id', uid).filter('used_at', 'is', null).limit(1).maybeSingle();
      if (available == null) return false;
      await SupabaseService.client.from('streak_freezes').update({
        'used_at': DateTime.now().toIso8601String(), 'used_for_date': dateStr,
      }).eq('id', available['id']);
      return true;
    } catch (_) { return false; }
  }
}
