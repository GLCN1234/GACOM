import '../services/supabase_service.dart';

/// One call from any game's game-over moment saves the result — this is
/// what the leaderboard and personal scorecard actually read from.
/// Best-effort: a failed save never interrupts the game itself.
class GameScoreService {
  static Future<void> save({required String gameName, required int score, bool? won}) async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    try {
      await SupabaseService.client.from('game_scores').insert({
        'user_id': uid, 'game_name': gameName, 'score': score, 'won': won,
      });
    } catch (_) {
      // Never let a failed score save interrupt the game itself.
    }
  }
}
