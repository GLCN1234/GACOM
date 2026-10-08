import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../odyssey/odyssey_screen.dart';
import 'biome/biome_screen.dart';
import 'casefiles/casefiles_screen.dart';
import 'delve/delve_screen.dart';
import 'frontier/frontier_screen.dart';
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
      id: 'ember',
      name: 'Ember Archipelago',
      verb: 'Relight the beacons',
      tagline: 'Relight the island beacons before the long night.',
      icon: Icons.local_fire_department_rounded,
      color: const Color(0xFF2ED3E6),
      bestFor: <String>{'math'},
      build: (RealmConfig c) => OdysseyScreen(
        config: OdysseyConfig(
          subjectId: 'math',
          useSchool: c.useSchool,
          realmId: 'ember',
          accent: const Color(0xFF2ED3E6),
          title: 'Ember Archipelago',
          story: 'Relight the island beacons before the long night.',
        ),
      ),
    ),
    RealmGameInfo(
      id: 'sundial',
      name: 'Sundial City',
      verb: 'Restore the voice',
      tagline: 'A city that lost its voice gets it back one sentence at a time.',
      icon: Icons.history_edu_rounded,
      color: const Color(0xFFF6B93B),
      bestFor: <String>{'english'},
      build: (RealmConfig c) => OdysseyScreen(
        config: OdysseyConfig(
          subjectId: 'english',
          useSchool: c.useSchool,
          realmId: 'sundial',
          accent: const Color(0xFFF6B93B),
          title: 'Sundial City',
          story: 'A city that lost its voice gets it back one sentence at a time.',
        ),
      ),
    ),
    RealmGameInfo(
      id: 'skyroot',
      name: 'Skyroot Frontier',
      verb: 'Heal the canopy',
      tagline: 'Heal a failing forest canopy before the rains fail.',
      icon: Icons.forest_rounded,
      color: const Color(0xFF4BD37B),
      bestFor: <String>{'biology', 'bst'},
      build: (RealmConfig c) => OdysseyScreen(
        config: OdysseyConfig(
          subjectId: 'biology',
          useSchool: c.useSchool,
          realmId: 'skyroot',
          accent: const Color(0xFF4BD37B),
          title: 'Skyroot Frontier',
          story: 'Heal a failing forest canopy before the rains fail.',
        ),
      ),
    ),
    RealmGameInfo(
      id: 'signal',
      name: 'Signal Ridge',
      verb: 'Rebuild the network',
      tagline: 'Reconnect the mountain villages by rebuilding the signal network.',
      icon: Icons.cell_tower_rounded,
      color: const Color(0xFFFF8A3D),
      bestFor: <String>{'coding', 'logic'},
      build: (RealmConfig c) => OdysseyScreen(
        config: OdysseyConfig(
          subjectId: 'coding',
          useSchool: c.useSchool,
          realmId: 'signal',
          accent: const Color(0xFFFF8A3D),
          title: 'Signal Ridge',
          story: 'Reconnect the mountain villages by rebuilding the signal network.',
        ),
      ),
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
