import 'dart:math';
import 'package:flutter/material.dart';
import 'darkom_story.dart';

/// The Darkom City mission catalogue: 24 repeatable missions in each of the
/// five districts (120 in all), plus three daily missions picked from the
/// districts a player has reached.
///
/// The server never sees this list. It checks the id (`m_<district>_<nn>`),
/// the unlock rule and that the run is plausible, and it decides the reward
/// from the number alone, so the formulas in [points] and [xp] must match
/// supabase/migrations/20261030_darkom_missions.sql.

const List<String> darkomDistrictKeys = <String>['neon', 'rustyard', 'docks', 'spire', 'grid'];
const List<String> darkomTierNames = <String>['Rookie', 'Veteran', 'Elite', 'Legend'];
const List<Color> darkomTierColors = <Color>[Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFFFD54F), Color(0xFFFF5252)];
const List<String> _roman = <String>['I', 'II', 'III', 'IV'];

/// clear | recover | collect | hunt | survive | escort, repeating through a tier.
const List<String> _kindOrder = <String>['clear', 'recover', 'collect', 'hunt', 'survive', 'escort'];

const List<List<String>> _titles = <List<String>>[
  // clear
  <String>['Street Sweep', 'Yard Purge', 'Quay Cleanup', 'Market Sweep', 'Aisle Purge'],
  // recover
  <String>['Shard Run', 'Scrap Run', 'Cold Cargo', 'Ledger Heist', 'Core Pull'],
  // collect
  <String>['Neon Chips', 'Scrap Hunt', 'Lost Cargo', 'Golden Pages', 'Data Harvest'],
  // hunt (not used, bounties have their own names)
  <String>['', '', '', '', ''],
  // survive
  <String>['Hold the Lights', 'Hold the Gate', 'Lamp Watch', 'Market Siege', 'Rack Siege'],
  // escort
  <String>['Walk the Courier', 'Convoy Run', 'Pier Escort', 'Lift Escort', 'Signal Escort'],
];

/// Bounty names, by district then tier.
const List<List<String>> _bounties = <List<String>>[
  <String>['Static Rat', 'Glare Hound', 'Signal Butcher', 'Blackout King'],
  <String>['Rust Imp', 'Crane Biter', 'Slag Baron', 'Iron Empress'],
  <String>['Tide Stalker', 'Lamp Drowner', 'Anchor Ghoul', 'Leviathan Hand'],
  <String>['Coin Clerk', 'Ledger Wolf', 'Gilded Judge', 'Spire Regent'],
  <String>['Cable Jackal', 'Rack Warden', 'Null Courier', 'Echo Sovereign'],
];

class DarkomMission {
  /// m_neon_07
  final String id;

  /// 1..5, the story chapter that owns this district.
  final int district;

  /// 1..24 inside the district.
  final int n;
  final String kind;
  final String title;
  final String brief;
  final String doneLine;

  /// Kills to make, seconds to hold, or chips to collect.
  final int target;

  /// Whole-mission time limit in seconds, 0 for none.
  final int limit;
  final int lives;
  final double hpMul;
  final double dmgMul;
  final String bounty;

  const DarkomMission({
    required this.id,
    required this.district,
    required this.n,
    required this.kind,
    required this.title,
    required this.brief,
    required this.doneLine,
    required this.target,
    required this.limit,
    required this.lives,
    required this.hpMul,
    required this.dmgMul,
    required this.bounty,
  });

  int get tier => (n - 1) ~/ 6;
  String get tierName => darkomTierNames[tier];
  Color get tierColor => darkomTierColors[tier];
  String get districtKey => darkomDistrictKeys[district - 1];
  DarkomChapterDef get story => darkomChapter(district);
  DarkomTheme get theme => darkomTheme(districtKey);

  int get points => 20 + 20 * tier;
  int get xp => 30 + 20 * tier;
  static const int dailyBonus = 60;

  /// Different layout for every mission.
  int get seedSalt => 7919 * district + 104729 * n;

  /// The Rookie tier is open everywhere. Higher tiers need the district's chapter.
  bool isOpen(int storyChapter) => n <= 6 || district <= min(max(storyChapter, 1), 5);

  String get kindLabel {
    switch (kind) {
      case 'clear':
        return 'Clear $target shades';
      case 'recover':
        return 'Recover the shard';
      case 'collect':
        return 'Collect $target data chips';
      case 'hunt':
        return 'Hunt $bounty';
      case 'survive':
        return 'Hold the zone $target s';
      case 'escort':
        return 'Escort ${story.courierName}';
    }
    return kind;
  }

  IconData get icon {
    switch (kind) {
      case 'clear':
        return Icons.cleaning_services_rounded;
      case 'recover':
        return Icons.diamond_rounded;
      case 'collect':
        return Icons.memory_rounded;
      case 'hunt':
        return Icons.gps_fixed_rounded;
      case 'survive':
        return Icons.shield_moon_rounded;
      case 'escort':
        return Icons.directions_walk_rounded;
    }
    return Icons.flag_rounded;
  }

  /// Short rule tags shown on the card.
  List<String> get tags {
    final List<String> t = <String>[];
    if (limit > 0) t.add('Time limit $limit s');
    if (lives == 1) t.add('One life');
    if (lives == 2) t.add('Two lives');
    if (tier >= 2) t.add('Tougher enemies');
    return t;
  }

  /// The mission as a one-contract chapter so the game engine can run it unchanged.
  DarkomChapterDef asChapter() {
    final DarkomChapterDef b = story;
    return DarkomChapterDef(
      n: b.n,
      district: b.district,
      name: b.name,
      fixer: b.fixer,
      fixerRole: b.fixerRole,
      fixerColor: b.fixerColor,
      intro: brief,
      contracts: <DarkomContractDef>[DarkomContractDef(kind, title, target, brief, doneLine)],
      bountyName: bounty.isEmpty ? b.bountyName : bounty,
      courierName: b.courierName,
      gateName: b.gateName,
      echoName: b.echoName,
      echoIntro: b.echoIntro,
      outro: doneLine,
      chatter: b.chatter,
    );
  }
}

DarkomMission _build(int district, int n) {
  final int tier = (n - 1) ~/ 6;
  final int j = (n - 1) % 6;
  final String kind = _kindOrder[j];
  final DarkomChapterDef st = darkomChapter(district);
  final String who = st.fixer;
  int target = 0;
  int limit = 0;
  String title;
  String brief;
  String done;
  String bounty = '';
  switch (kind) {
    case 'clear':
      target = 6 + 4 * tier + (district - 1);
      title = '${_titles[0][district - 1]} ${_roman[tier]}';
      brief = '$who: "Put down $target shades and keep moving. The street has to open again."';
      done = 'Quiet at last. Good work.';
      break;
    case 'recover':
      limit = tier >= 2 ? (tier == 2 ? 150 : 110) : 0;
      title = '${_titles[1][district - 1]} ${_roman[tier]}';
      brief = '$who: "A shard is lying out there. Grab it and bring it back to the extraction gate.${limit > 0 ? ' You have $limit seconds.' : ''}"';
      done = 'The shard is safe. Well run.';
      break;
    case 'collect':
      target = 5 + 2 * tier;
      limit = tier >= 1 ? 110 - 15 * tier : 0;
      title = '${_titles[2][district - 1]} ${_roman[tier]}';
      brief = '$who: "Data chips are scattered across the district. Gather all $target.${limit > 0 ? ' The clock is $limit seconds.' : ''}"';
      done = 'Every chip counted. Nicely done.';
      break;
    case 'hunt':
      bounty = _bounties[district - 1][tier];
      title = 'Bounty: $bounty';
      brief = '$who: "$bounty has been terrorising the district. Find it and finish it."';
      done = '$bounty is down. The city owes you.';
      break;
    case 'survive':
      target = 30 + 10 * tier;
      title = '${_titles[4][district - 1]} ${_roman[tier]}';
      brief = '$who: "Reach the glowing zone and hold it for $target seconds. They will all come."';
      done = 'The zone held. So did you.';
      break;
    default:
      limit = tier >= 2 ? 170 : 0;
      title = '${_titles[5][district - 1]} ${_roman[tier]}';
      brief = '$who: "${st.courierName} needs to reach the gate alive. Stay close and keep the shades off.${limit > 0 ? ' You have $limit seconds.' : ''}"';
      done = '${st.courierName} made it. Good.';
      break;
  }
  return DarkomMission(
    id: 'm_${darkomDistrictKeys[district - 1]}_${n.toString().padLeft(2, '0')}',
    district: district,
    n: n,
    kind: kind,
    title: title,
    brief: brief,
    doneLine: done,
    target: target,
    limit: limit,
    lives: tier == 3 ? 1 : (tier == 2 ? 2 : 3),
    hpMul: 1 + 0.18 * tier,
    dmgMul: 1 + 0.08 * tier,
    bounty: bounty,
  );
}

final List<DarkomMission> darkomMissions = List<DarkomMission>.unmodifiable(<DarkomMission>[
  for (int d = 1; d <= 5; d++)
    for (int n = 1; n <= 24; n++) _build(d, n),
]);

DarkomMission? darkomMissionById(String id) {
  for (final DarkomMission m in darkomMissions) {
    if (m.id == id) return m;
  }
  return null;
}

List<DarkomMission> darkomMissionsIn(int district) =>
    darkomMissions.where((DarkomMission m) => m.district == district).toList();

/// Today's three daily missions. Mirrors darkom_daily_ids in the migration:
/// same day number (days since 2026-01-01, UTC) and the same arithmetic.
List<DarkomMission> darkomDailyMissions(DateTime nowUtc, int storyChapter) {
  final int cap = min(max(storyChapter, 1), 5);
  final int dn = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day).difference(DateTime.utc(2026, 1, 1)).inDays;
  final List<DarkomMission> out = <DarkomMission>[];
  for (int i = 0; i < 3; i++) {
    final int d = (dn * 3 + i * 2 + 1) % cap;
    final int n = ((dn * 7 + i * 11) % 24) + 1;
    out.add(darkomMissions[d * 24 + (n - 1)]);
  }
  return out;
}
