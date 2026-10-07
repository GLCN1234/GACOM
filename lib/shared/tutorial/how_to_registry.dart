import 'how_to_arena_a.dart';
import 'how_to_arena_b.dart';
import 'how_to_arena_c.dart';
import 'how_to_model.dart';
import 'how_to_realms.dart';

/// Every game that has a tutorial, by game key.
class HowToRegistry {
  static Map<String, GameHowTo>? _all;

  static Map<String, GameHowTo> get all {
    return _all ??= <String, GameHowTo>{
      ...howToArenaA,
      ...howToArenaB,
      ...howToArenaC,
      ...howToRealms,
    };
  }

  static GameHowTo? byKey(String key) => all[key];
}
