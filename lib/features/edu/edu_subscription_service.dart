import '../../../core/services/supabase_service.dart';

/// Checks if the current user has an active edu subscription.
/// Free tier: Mathematics Foundation level only.
/// Pro: all 24 subjects, all 5 levels.
class EduSubscriptionService {
  static bool? _cachedStatus;
  static DateTime? _cacheTime;

  static const _freeSubject = 'math';
  static const _freeLevelIndex = 0; // Foundation only

  /// Returns true if user has an active paid edu subscription
  static Future<bool> isPro() async {
    // Cache for 5 minutes to avoid hammering the DB
    if (_cachedStatus != null && _cacheTime != null &&
        DateTime.now().difference(_cacheTime!).inMinutes < 5) {
      return _cachedStatus!;
    }
    try {
      final uid = SupabaseService.currentUserId;
      if (uid == null) return false;
      final row = await SupabaseService.client
          .from('edu_subscriptions')
          .select('status')
          .eq('user_id', uid)
          .eq('status', 'active')
          .maybeSingle();
      _cachedStatus = row != null;
      _cacheTime = DateTime.now();
      return _cachedStatus!;
    } catch (_) {
      return false;
    }
  }

  /// Clears cache (call after subscription purchase)
  static void clearCache() { _cachedStatus = null; _cacheTime = null; }

  /// Returns true if the given subject is accessible on the free plan
  static bool isFreeSubject(String subjectId) => subjectId == _freeSubject;

  /// Returns true if the given level index is accessible on the free plan
  static bool isFreeLevel(int levelIndex) => levelIndex == _freeLevelIndex;
}
