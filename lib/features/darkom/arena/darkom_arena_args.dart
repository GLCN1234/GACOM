/// What the arena screen needs to start a match. Created by the hub when a
/// challenge is accepted or a squad starts.
class DarkomArenaArgs {
  /// Shared room code. Both sides open the realtime channel 'darkom:arena:<code>'.
  final String code;

  /// 'duel' (1v1, best of 3) or 'squad' (free for all, 2 to 4 players).
  final String mode;

  /// User ids of everyone expected in the match, including the local player.
  final List<String> playerIds;

  /// Set for a duel: the challenge row to report the result against.
  final String? challengeId;

  /// Set for a squad match.
  final String? squadId;

  const DarkomArenaArgs({
    required this.code,
    required this.mode,
    required this.playerIds,
    this.challengeId,
    this.squadId,
  });
}
