import 'dart:math';

/// Callback fired when the game being played inside a duel reports a score.
typedef DuelScoreSink = void Function(int score, bool? won);

/// While a duel is running, the game on screen reports its result through
/// this session instead of just saving it, and draws its random numbers from
/// the duel's shared seed so both players get the same puzzle or layout.
///
/// Outside a duel [current] is null and everything behaves as before.
class DuelSession {
  static DuelSession? current;

  final int seed;
  final DuelScoreSink onScore;
  int _counter = 0;

  DuelSession({required this.seed, required this.onScore});

  Random nextRandom() {
    final int n = (seed + 7919 * _counter) & 0x7fffffff;
    _counter++;
    return Random(n);
  }

  void start() => current = this;

  void stop() {
    if (identical(current, this)) current = null;
  }
}

/// Drop-in replacement for `Random()`. Seeded and repeatable inside a duel,
/// ordinary random otherwise.
Random duelRandom() {
  final DuelSession? s = DuelSession.current;
  return s == null ? Random() : s.nextRandom();
}
