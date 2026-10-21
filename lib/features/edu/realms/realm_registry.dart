import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../odyssey/odyssey_screen.dart';
import 'biome/biome_screen.dart';
import 'casefiles/casefiles_screen.dart';
import 'current/current_screen.dart';
import 'delve/delve_screen.dart';
import 'frontier/frontier_screen.dart';
import 'market/market_screen.dart';
import 'okada/okada_screen.dart';
import 'pitch/pitch_screen.dart';
import 'siege/siege_screen.dart';
import 'signal/signal_screen.dart';
import 'strike/strike_screen.dart';
import 'strike/strike_skins.dart';
import 'realm_kit.dart';
import 'windward/windward_screen.dart';

/// One open-world learning game.
class RealmGameInfo {
  final String id;
  final String name;
  final String verb;
  final String tagline;
  final IconData icon;
  final Color color;

  /// Subject ids this game suits best.
  final Set<String> bestFor;
  final Widget Function(RealmConfig config) build;

  /// The id Journey uses for this game's world.
  String get journeyRealmId => id;

  const RealmGameInfo({
    required this.id,
    required this.name,
    required this.verb,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.bestFor,
    required this.build,
  });
}

class RealmRegistry {
  static final List<RealmGameInfo> games = <RealmGameInfo>[
    RealmGameInfo(
      id: 'odyssey',
      name: 'Odyssey',
      verb: 'Roam and answer',
      tagline: 'An endless world of subjects. Collect coins and stars, rest when you like, answer at the checkpoints.',
      icon: Icons.explore_rounded,
      color: const Color(0xFF00897B),
      bestFor: <String>{'math', 'physics', 'english', 'logic', 'coding'},
      build: (RealmConfig c) => OdysseyScreen(config: OdysseyConfig(subjectId: c.subjectId, useSchool: c.useSchool)),
    ),
    RealmGameInfo(
      id: 'biome',
      name: 'Biome',
      verb: 'Collect and battle',
      tagline: 'Find wild creatures, battle them with your knowledge, tame them and build a team.',
      icon: Icons.pets_rounded,
      color: const Color(0xFF7CB342),
      bestFor: <String>{'biology', 'chemistry', 'geography', 'bst'},
      build: (RealmConfig c) => BiomeScreen(config: c),
    ),
    RealmGameInfo(
      id: 'windward',
      name: 'Windward',
      verb: 'Sail and trade',
      tagline: 'Read the wind, sail between islands and trade. The better you know your lessons, the better your prices.',
      icon: Icons.sailing_rounded,
      color: const Color(0xFF0288D1),
      bestFor: <String>{'geography', 'history', 'economics', 'math', 'physics'},
      build: (RealmConfig c) => WindwardScreen(config: c),
    ),
    RealmGameInfo(
      id: 'delve',
      name: 'Delve',
      verb: 'Explore the dark',
      tagline: 'Descend through lightless caves with a dying torch. Rune doors open only for those who know the answer.',
      icon: Icons.flashlight_on_rounded,
      color: const Color(0xFF6A1B9A),
      bestFor: <String>{'chemistry', 'physics', 'coding', 'logic', 'math'},
      build: (RealmConfig c) => DelveScreen(config: c),
    ),
    RealmGameInfo(
      id: 'casefiles',
      name: 'Case Files',
      verb: 'Investigate',
      tagline: 'Walk the town, win clues with correct answers and work out who did it before the day runs out.',
      icon: Icons.manage_search_rounded,
      color: const Color(0xFFC0392B),
      bestFor: <String>{'english', 'history', 'civics', 'logic', 'biology'},
      build: (RealmConfig c) => CaseFilesScreen(config: c),
    ),
    RealmGameInfo(
      id: 'frontier',
      name: 'Frontier',
      verb: 'Build and manage',
      tagline: 'Grow a settlement. A wise council brings blessings, and research needs proof.',
      icon: Icons.holiday_village_rounded,
      color: const Color(0xFFEF6C00),
      bestFor: <String>{'economics', 'civics', 'geography', 'history', 'bst', 'math'},
      build: (RealmConfig c) => FrontierScreen(config: c),
    ),
    RealmGameInfo(
      id: 'okada',
      name: 'Okada Run',
      verb: 'Ride the lanes',
      tagline: 'An endless Lagos ride where the answers hang over the lanes. Ride through the right one and the road opens up.',
      icon: Icons.two_wheeler_rounded,
      color: const Color(0xFFFFC233),
      bestFor: <String>{'math', 'english', 'physics', 'logic'},
      build: (RealmConfig c) => OkadaScreen(config: c),
    ),
    RealmGameInfo(
      id: 'sundial',
      name: 'Sundial City',
      verb: 'Restore the voice',
      tagline: 'A city that lost its voice gets it back one sentence at a time.',
      icon: Icons.history_edu_rounded,
      color: const Color(0xFFF6B93B),
      bestFor: <String>{'english'},
      build: (RealmConfig c) => StrikeScreen(skin: StrikeSkin.sundial, config: c),
    ),
    RealmGameInfo(
      id: 'skyroot',
      name: 'Skyroot Frontier',
      verb: 'Heal the canopy',
      tagline: 'Heal a failing forest canopy before the rains fail.',
      icon: Icons.forest_rounded,
      color: const Color(0xFF4BD37B),
      bestFor: <String>{'biology', 'bst'},
      build: (RealmConfig c) => StrikeScreen(skin: StrikeSkin.skyroot, config: c),
    ),
    RealmGameInfo(
      id: 'signal',
      name: 'Signal Ridge',
      verb: 'Program the bot',
      tagline: 'Write a program from FORWARD, TURN and REPEAT blocks to walk a bot across the ridge and relight the relays.',
      icon: Icons.cell_tower_rounded,
      color: const Color(0xFFFF8A3D),
      bestFor: <String>{'coding', 'logic'},
      build: (RealmConfig c) => SignalScreen(config: c),
    ),
    RealmGameInfo(
      id: 'siege',
      name: 'Gate Siege',
      verb: 'Divide and hold',
      tagline: 'Every marcher carries a number and your weapons are divisions. Take them apart before they reach your gate.',
      icon: Icons.shield_rounded,
      color: const Color(0xFFFFCA28),
      bestFor: <String>{'math', 'logic'},
      build: (RealmConfig c) => SiegeScreen(config: c),
    ),
    RealmGameInfo(
      id: 'current',
      name: 'Word Current',
      verb: 'Swim and read',
      tagline: 'The sentence is on the bank and the words float down the river. Swim into the one that fits.',
      icon: Icons.waves_rounded,
      color: const Color(0xFF4FC3F7),
      bestFor: <String>{'english', 'logic', 'civics'},
      build: (RealmConfig c) => CurrentScreen(config: c),
    ),
    RealmGameInfo(
      id: 'pitch',
      name: 'Set Piece',
      verb: 'Bend it in',
      tagline: 'The goalmouth is painted with the answers. Curve the ball into the right zone and beat the keeper.',
      icon: Icons.sports_soccer_rounded,
      color: const Color(0xFF7CFFA0),
      bestFor: <String>{'math', 'english', 'physics'},
      build: (RealmConfig c) => PitchScreen(config: c),
    ),
    RealmGameInfo(
      id: 'market',
      name: 'Market Run',
      verb: 'Buy, sell, count',
      tagline: 'A trading day with no questions in it. Buy low, sell at your counter and count the change right.',
      icon: Icons.storefront_rounded,
      color: const Color(0xFFFFD166),
      bestFor: <String>{'math', 'economics', 'bst'},
      build: (RealmConfig c) => MarketScreen(config: c),
    ),
  ];

  static RealmGameInfo? byId(String id) {
    for (final RealmGameInfo g in games) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// A game plus why Ryan is suggesting it.
class RealmPick {
  final RealmGameInfo game;
  final double score;
  final String reason;
  const RealmPick(this.game, this.score, this.reason);
}

/// Ryan's recommendations: suit the subject, favour games the player has not
/// tried, avoid repeating the last game, and rotate daily so no single game
/// is the only one ever played.
class RealmRecs {
  static const String _lastKey = 'realm_last_played';
  static String _playsKey(String id) => 'realm_plays_$id';

  static Future<Map<String, int>> loadPlays() async {
    final Map<String, int> out = <String, int>{};
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      for (final RealmGameInfo g in RealmRegistry.games) {
        out[g.id] = p.getInt(_playsKey(g.id)) ?? 0;
      }
    } catch (e) {
      for (final RealmGameInfo g in RealmRegistry.games) {
        out[g.id] = 0;
      }
    }
    return out;
  }

  static Future<String?> loadLast() async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return p.getString(_lastKey);
    } catch (e) {
      return null;
    }
  }

  static Future<void> recordPlay(String id) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      await p.setInt(_playsKey(id), (p.getInt(_playsKey(id)) ?? 0) + 1);
      await p.setString(_lastKey, id);
    } catch (e) {
      // recommendations are a convenience only
    }
  }

  /// Games ranked best first for this subject ('mix' for all subjects).
  static List<RealmPick> rank({
    required String subjectId,
    required Map<String, int> plays,
    required String? last,
    required String subjectLabel,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    final int day = t.year * 400 + t.month * 31 + t.day;
    final List<RealmPick> out = <RealmPick>[];
    for (int i = 0; i < RealmRegistry.games.length; i++) {
      final RealmGameInfo g = RealmRegistry.games[i];
      double score = 0;
      String reason = 'A fresh pick for today';
      final bool suits = subjectId != 'mix' && g.bestFor.contains(subjectId);
      final int played = plays[g.id] ?? 0;
      if (suits) {
        score += 3;
        reason = 'Great for $subjectLabel';
      } else if (subjectId == 'mix') {
        score += 1.5;
      }
      if (played == 0) {
        score += 2;
        reason = suits ? 'Great for $subjectLabel and new to you' : 'You have not tried this yet';
      } else if (played <= 2) {
        score += 1;
      }
      if (last == g.id) {
        score -= 1.8;
        reason = 'Your last game. Try another, then come back';
      }
      score += (realmHash(day, i, 7) % 100) / 100.0 * 1.4;
      out.add(RealmPick(g, score, reason));
    }
    out.sort((RealmPick a, RealmPick b) => b.score.compareTo(a.score));
    return out;
  }
}
