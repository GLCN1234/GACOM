import 'package:flutter/material.dart';

/// Story, contracts, dialogue and tuning numbers for Darkom City.
/// Pure data: no game state lives here.

const List<String> darkomWeaponKinds = <String>['sword', 'dagger', 'hammer', 'axe', 'staff', 'shield'];

/// Colours and names of one district.
class DarkomTheme {
  final String key;
  final String name;
  final Color ground;
  final Color road;
  final Color roadLine;
  final Color roof;
  final Color roofEdge;
  final Color neonA;
  final Color neonB;
  final Color cover;
  final Color water;
  const DarkomTheme({
    required this.key,
    required this.name,
    required this.ground,
    required this.road,
    required this.roadLine,
    required this.roof,
    required this.roofEdge,
    required this.neonA,
    required this.neonB,
    required this.cover,
    required this.water,
  });
}

const List<DarkomTheme> darkomThemes = <DarkomTheme>[
  DarkomTheme(
    key: 'neon',
    name: 'Neon Quarter',
    ground: Color(0xFF14121F),
    road: Color(0xFF1D1A2C),
    roadLine: Color(0xFF45406A),
    roof: Color(0xFF241F3A),
    roofEdge: Color(0xFF3A3363),
    neonA: Color(0xFFFF2E93),
    neonB: Color(0xFF00E5FF),
    cover: Color(0xFF3B2F55),
    water: Color(0xFF10253A),
  ),
  DarkomTheme(
    key: 'rustyard',
    name: 'Rustyard',
    ground: Color(0xFF1E1713),
    road: Color(0xFF2A211B),
    roadLine: Color(0xFF6A5338),
    roof: Color(0xFF3A2A20),
    roofEdge: Color(0xFF5E4430),
    neonA: Color(0xFFFF8F00),
    neonB: Color(0xFFFFD54F),
    cover: Color(0xFF8A4B2A),
    water: Color(0xFF10253A),
  ),
  DarkomTheme(
    key: 'docks',
    name: 'Glasswater Docks',
    ground: Color(0xFF0F1B22),
    road: Color(0xFF16262F),
    roadLine: Color(0xFF356070),
    roof: Color(0xFF1C3340),
    roofEdge: Color(0xFF2F5B70),
    neonA: Color(0xFF26C6DA),
    neonB: Color(0xFF69F0AE),
    cover: Color(0xFF4A6A55),
    water: Color(0xFF0A2B44),
  ),
  DarkomTheme(
    key: 'spire',
    name: 'The Spire Markets',
    ground: Color(0xFF1A1620),
    road: Color(0xFF241E2D),
    roadLine: Color(0xFF8A7438),
    roof: Color(0xFF2E2538),
    roofEdge: Color(0xFF6B5A8E),
    neonA: Color(0xFFFFC400),
    neonB: Color(0xFFB388FF),
    cover: Color(0xFF5A4A72),
    water: Color(0xFF10253A),
  ),
  DarkomTheme(
    key: 'grid',
    name: 'The Dead Grid',
    ground: Color(0xFF0A1114),
    road: Color(0xFF101C20),
    roadLine: Color(0xFF1F5C52),
    roof: Color(0xFF14262B),
    roofEdge: Color(0xFF1F7A68),
    neonA: Color(0xFF00E676),
    neonB: Color(0xFFFF1744),
    cover: Color(0xFF2B4A44),
    water: Color(0xFF10253A),
  ),
];

DarkomTheme darkomTheme(String key) {
  for (final DarkomTheme t in darkomThemes) {
    if (t.key == key) return t;
  }
  return darkomThemes[0];
}

/// One contract inside a chapter.
class DarkomContractDef {
  /// clear | recover | escort | hunt | survive
  final String kind;
  final String title;

  /// Kills to make for clear, seconds to hold for survive, otherwise 0.
  final int target;
  final String briefing;
  final String doneLine;
  const DarkomContractDef(this.kind, this.title, this.target, this.briefing, this.doneLine);
}

class DarkomChapterDef {
  final int n;
  final String district;
  final String name;
  final String fixer;
  final String fixerRole;
  final Color fixerColor;
  final String intro;
  final List<DarkomContractDef> contracts;
  final String bountyName;
  final String courierName;
  final String gateName;
  final String echoName;
  final String echoIntro;
  final String outro;
  final List<String> chatter;
  const DarkomChapterDef({
    required this.n,
    required this.district,
    required this.name,
    required this.fixer,
    required this.fixerRole,
    required this.fixerColor,
    required this.intro,
    required this.contracts,
    required this.bountyName,
    required this.courierName,
    required this.gateName,
    required this.echoName,
    required this.echoIntro,
    required this.outro,
    required this.chatter,
  });

  /// The key the server knows for contract [i] (0 based).
  String keyFor(int i) => 'c${n}_${i + 1}';
  String get echoKey => 'c${n}_echo';
}

const List<DarkomChapterDef> darkomChapters = <DarkomChapterDef>[
  DarkomChapterDef(
    n: 1,
    district: 'neon',
    name: 'Neon Quarter',
    fixer: 'Mama Nkechi',
    fixerRole: 'the market fixer',
    fixerColor: Color(0xFFFFB300),
    intro: 'The lights came back wrong, child. Every sign in the Quarter buzzes, and the shades crawl out of the glare. Clear the street, bring me a memory shard, and take the Danfo Ghost off my corner. Then we talk about your Echo.',
    contracts: <DarkomContractDef>[
      DarkomContractDef('clear', 'Clean the street', 8, 'Shades are eating the market lights. Put eight of them down and my stalls can open.', 'Quiet street. Good. Next job.'),
      DarkomContractDef('recover', 'The lost shard', 0, 'A memory shard fell near the old bus park. Pick it up and carry it to the extraction gate.', 'The shard hums. It remembers a name. Yours, maybe.'),
      DarkomContractDef('hunt', 'Bounty: Danfo Ghost', 0, 'The Danfo Ghost drives a bus that never stops. Find it and make it stop.', 'The engine is silent. My corner is safe.'),
    ],
    bountyName: 'Danfo Ghost',
    courierName: 'Kunle',
    gateName: 'Gate 1',
    echoName: 'Your Echo',
    echoIntro: 'Walk to the lit clearing. Your Echo waits there wearing your face and your habits. It carries what you lost.',
    outro: 'Your Echo falls and a memory returns. Mama Nkechi nods. The Quarter breathes again.',
    chatter: <String>['Stay on the roads. The shades hate open light.', 'Hear that hum? A shard is near.', 'Dodge the red marks. They always warn you first.', 'Keep moving, child. A target that stands still is a gift.'],
  ),
  DarkomChapterDef(
    n: 2,
    district: 'rustyard',
    name: 'Rustyard',
    fixer: 'Captain Bode',
    fixerRole: 'the yard captain',
    fixerColor: Color(0xFFFF7043),
    intro: 'Rustyard runs on scrap and stubbornness. My apprentice Kunle is stuck on the wrong side of the containers. Get him to the gate, thin out the shades, then deal with Iron Madam before she melts my cranes.',
    contracts: <DarkomContractDef>[
      DarkomContractDef('escort', 'Walk Kunle home', 0, 'Kunle follows you. Shades go for him first, so stay close and lead him to the gate.', 'Kunle is safe and talking too much. Fine by me.'),
      DarkomContractDef('clear', 'Thin the pack', 10, 'The pack is bigger than I like. Ten kills and the yard breathes.', 'The yard is quieter. Not safe, but quieter.'),
      DarkomContractDef('hunt', 'Bounty: Iron Madam', 0, 'Iron Madam hits like a falling crane. Slow, but she never forgets a face. Do not stand in her red circle.', 'Iron Madam is scrap now. Well done.'),
    ],
    bountyName: 'Iron Madam',
    courierName: 'Kunle',
    gateName: 'Gate 3',
    echoName: 'Your Echo',
    echoIntro: 'The clearing by the cranes. Your Echo fights the way you do. Learn from it before it learns from you.',
    outro: 'The Echo breaks apart like old rust. Captain Bode salutes. The way east is open.',
    chatter: <String>['Brutes are slow. Circle them and hit from the side.', 'Use the containers. Walls stop spit.', 'A heavy swing needs room. Step back first.', 'Kunle talks when he is scared. Keep him close.'],
  ),
  DarkomChapterDef(
    n: 3,
    district: 'docks',
    name: 'Glasswater Docks',
    fixer: 'Auntie Sade',
    fixerRole: 'queen of the quay',
    fixerColor: Color(0xFF29B6F6),
    intro: 'The water here turned to glass the night of the blackout. Things walk across it. I need a shard from the cold store, a hold on the lamp square, and the Drowned Captain gone. Pay is fair.',
    contracts: <DarkomContractDef>[
      DarkomContractDef('recover', 'Cold store shard', 0, 'The shard sits near the old warehouses. Wraiths blink in the dark, so keep your eyes on the pale rings.', 'Cold hands, warm shard. Good work.'),
      DarkomContractDef('survive', 'Hold the lamp square', 45, 'Stand in the light for forty five seconds. They will come for it. Leave the light and the clock stops.', 'The lamps held. So did you.'),
      DarkomContractDef('hunt', 'Bounty: Drowned Captain', 0, 'The Drowned Captain still thinks his ship is coming in. Show him it is not.', 'The captain sinks for the last time.'),
    ],
    bountyName: 'Drowned Captain',
    courierName: 'Kunle',
    gateName: 'Gate 5',
    echoName: 'Your Echo',
    echoIntro: 'End of the long pier. Your Echo stands where the lamps end. Whatever you did best, it will do too.',
    outro: 'The glass water ripples and calms. Auntie Sade tips her hat. The Spire is next.',
    chatter: <String>['Wraiths blink. When the pale ring shows, step away.', 'Water is not a road. Stay on the stone.', 'Keep the shard moving. Standing still draws trouble.', 'Lamplight is your friend tonight.'],
  ),
  DarkomChapterDef(
    n: 4,
    district: 'spire',
    name: 'The Spire Markets',
    fixer: 'Dr Ife',
    fixerRole: 'the memory doctor',
    fixerColor: Color(0xFFB388FF),
    intro: 'I study what the blackout did to memory. Your Echo is not your enemy, it is your missing half. Before that, three small things: hold the market steps, bring my courier Tunde to the lift, and stop Lord Ledger, who sells forgotten days.',
    contracts: <DarkomContractDef>[
      DarkomContractDef('survive', 'Hold the market steps', 45, 'Hold the glowing steps for forty five seconds. Crowds of shades will test you.', 'The steps are ours. The merchants cheer.'),
      DarkomContractDef('escort', 'Bring Tunde to the lift', 0, 'Tunde carries my notes. Keep him alive and keep him moving to the lift.', 'My notes are safe. Tunde is complaining. All is well.'),
      DarkomContractDef('hunt', 'Bounty: Lord Ledger', 0, 'Lord Ledger sells memories by the ounce. He wears gold and fires in fans. Watch the aim lines.', 'The ledger is closed.'),
    ],
    bountyName: 'Lord Ledger',
    courierName: 'Tunde',
    gateName: 'Lift 7',
    echoName: 'Your Echo',
    echoIntro: 'The atrium under the Spire. Your Echo remembers everything you have done tonight. So should you.',
    outro: 'Dr Ife smiles at the fading light. Two memories restored. One chapter to go.',
    chatter: <String>['Spitters are weak up close. Rush them.', 'Tunde has soft shoes and a loud mouth. Keep him near.', 'Special moves recharge. Use them often.', 'Shields can send their bolts back.'],
  ),
  DarkomChapterDef(
    n: 5,
    district: 'grid',
    name: 'The Dead Grid',
    fixer: 'Baba Eleja',
    fixerRole: 'keeper of the last signal',
    fixerColor: Color(0xFF00E676),
    intro: 'This is where the blackout began. The racks still hum with everything the city forgot. Clear the aisles, bring me the master shard, and end the Hound. Then face Echo Prime, the first copy, the one that started this.',
    contracts: <DarkomContractDef>[
      DarkomContractDef('clear', 'Clear the aisles', 14, 'The aisles are full. Fourteen shades and the racks go quiet.', 'The hum drops a little. Good.'),
      DarkomContractDef('recover', 'The master shard', 0, 'The master shard sits deep in the grid. Carry it back to the extraction gate, whatever follows you.', 'The master shard is whole. I can hear the city in it.'),
      DarkomContractDef('hunt', 'Bounty: The Hound', 0, 'The Hound was made from every Echo that failed. It is fast and angry. Be faster.', 'The Hound is quiet. It never meant to bite.'),
    ],
    bountyName: 'The Hound',
    courierName: 'Tunde',
    gateName: 'Gate 9',
    echoName: 'Echo Prime',
    echoIntro: 'The core chamber. Echo Prime is waiting, and it has been practising a long time. This is the real fight.',
    outro: 'Echo Prime fades with your name on its lips. The lights of Darkom City steady at last.',
    chatter: <String>['Echo Prime copies your weapon. Use the one you trust.', 'Telegraphs are honest. Read them.', 'Dash through attacks, not away from them.', 'Almost done. Do not rush the last step.'],
  ),
];

DarkomChapterDef darkomChapter(int n) {
  final int i = n < 1 ? 0 : (n > darkomChapters.length ? darkomChapters.length - 1 : n - 1);
  return darkomChapters[i];
}

/// Story done: free roam waves in the last district.
const String darkomRoamIntro = 'The blackout is over, but the Grid still breeds shades. Baba Eleja pays a bounty for every one you stop. Waves come in numbers, a named hunter arrives every third wave, and the curfew falls at eight minutes. Beat your best score.';

const List<String> darkomRoamBounties = <String>['Static Hound', 'Dead Signal', 'Rack Warden', 'Echo Stray', 'Null Courier'];

// ---------------------------------------------------------------------------
// Tuning

class DarkomEnemyDef {
  final String name;
  final double hp;
  final double speed;
  final double r;
  final double dmg;
  final double reach;
  final double cd;
  final double tele;
  final Color color;
  final Color glow;
  const DarkomEnemyDef(this.name, this.hp, this.speed, this.r, this.dmg, this.reach, this.cd, this.tele, this.color, this.glow);
}

const Map<String, DarkomEnemyDef> darkomEnemies = <String, DarkomEnemyDef>{
  'shade': DarkomEnemyDef('Shade', 40, 100, 15, 12, 48, 1.3, 0.55, Color(0xFF1B1530), Color(0xFF9C6BFF)),
  'spitter': DarkomEnemyDef('Spitter', 30, 78, 14, 13, 340, 2.4, 0.8, Color(0xFF241020), Color(0xFFFF6E40)),
  'brute': DarkomEnemyDef('Brute', 170, 56, 22, 26, 105, 3.2, 1.0, Color(0xFF2B1A14), Color(0xFFFF8A00)),
  'wraith': DarkomEnemyDef('Wraith', 36, 150, 14, 14, 50, 1.8, 0.55, Color(0xFFCFE8F2), Color(0xFF80DEEA)),
  'bounty': DarkomEnemyDef('Bounty', 330, 72, 26, 20, 110, 3.4, 0.9, Color(0xFF2A0F14), Color(0xFFFF1744)),
  'echo': DarkomEnemyDef('Echo', 220, 150, 15, 14, 100, 1.6, 0.6, Color(0xFF101018), Color(0xFF00E5FF)),
};

/// Spawn mix [shade, spitter, brute, wraith] per chapter.
List<int> darkomSpawnMix(int chapter) {
  switch (chapter) {
    case 1:
      return const <int>[70, 30, 0, 0];
    case 2:
      return const <int>[50, 25, 25, 0];
    case 3:
      return const <int>[38, 20, 14, 28];
    case 4:
      return const <int>[30, 25, 20, 25];
    default:
      return const <int>[25, 25, 25, 25];
  }
}

class DarkomWeaponDef {
  final String kind;
  final String name;
  final double dmg;
  final double cd;
  final double range;
  final double auto;
  final String special;
  final double sdmg;
  final double scd;
  final String blurb;
  const DarkomWeaponDef(this.kind, this.name, this.dmg, this.cd, this.range, this.auto, this.special, this.sdmg, this.scd, this.blurb);
}

const Map<String, DarkomWeaponDef> darkomWeapons = <String, DarkomWeaponDef>{
  'sword': DarkomWeaponDef('sword', 'Sword', 24, 0.38, 108, 190, 'Spin Slash', 32, 7, 'Quick arc slash'),
  'dagger': DarkomWeaponDef('dagger', 'Dagger', 9, 0.55, 64, 140, 'Shadow Stab', 40, 6, 'Fast triple stabs'),
  'hammer': DarkomWeaponDef('hammer', 'Hammer', 46, 1.05, 96, 165, 'Ground Slam', 38, 9, 'Heavy smash, knockback'),
  'axe': DarkomWeaponDef('axe', 'Axe', 22, 0.2, 270, 340, 'Triple Throw', 18, 8, 'Boomerang axe'),
  'staff': DarkomWeaponDef('staff', 'Staff', 19, 0.30, 430, 450, 'Nova Burst', 30, 8, 'Magic bolts, mana'),
  'shield': DarkomWeaponDef('shield', 'Shield', 14, 0.75, 72, 135, 'Charge', 26, 8, 'Block, reflect, bash'),
};

DarkomWeaponDef darkomWeapon(String kind) => darkomWeapons[kind] ?? darkomWeapons['sword']!;

/// Short remarks the fixers make when something good or bad happens.
const List<String> darkomPraise = <String>['Clean work.', 'That is how it is done.', 'The city owes you.', 'Well fought.'];
const List<String> darkomHurtLines = <String>['Move! Do not stand in the red.', 'Dash through it, do not run from it.', 'Breathe. Watch the warnings.'];
