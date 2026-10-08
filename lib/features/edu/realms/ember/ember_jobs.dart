import 'dart:math';

/// Harbour job kinds.
const int emberJobCargo = 0;
const int emberJobSail = 1;
const int emberJobLamp = 2;
const int emberJobBarter = 3;

String emberSigned(int v) => v > 0 ? '+$v' : '$v';

String emberBearing(int b) => (((b % 360) + 360) % 360).toString().padLeft(3, '0');

int _sum(List<int> xs) {
  int s = 0;
  for (final int x in xs) {
    s += x;
  }
  return s;
}

/// One harbour job. Every job is generated answer first, so it is always
/// solvable, and the player works it by direct manipulation.
abstract class EmberJob {
  int get kind;
  String get title;
  String get statement;

  /// True when the player has done enough to press SUBMIT.
  bool get canSubmit => true;

  bool check();

  /// The correct working in one line.
  String get working;

  /// The correct answer as text.
  String get answerText;

  /// What the player currently has, as text.
  String get chosenText;
}

// ---------------------------------------------------------------------------
// 1. Cargo ratio

class CargoJob extends EmberJob {
  final List<String> names;
  final List<int> parts;
  final int k;
  final List<int> counts;

  CargoJob._(this.names, this.parts, this.k) : counts = List<int>.filled(parts.length, 0);

  factory CargoJob.generate(Random rng, int level) {
    const List<List<String>> sets = <List<String>>[
      <String>['lamp-oil', 'pitch', 'tar'],
      <String>['palm oil', 'shea butter', 'coconut oil'],
      <String>['rice', 'beans', 'yam flour'],
      <String>['salt', 'sugar', 'millet'],
    ];
    const List<List<int>> twos = <List<int>>[
      <int>[1, 2], <int>[1, 3], <int>[2, 3], <int>[3, 4], <int>[2, 5], <int>[3, 5], <int>[4, 5], <int>[3, 7], <int>[5, 7], <int>[1, 4],
    ];
    const List<List<int>> threes = <List<int>>[
      <int>[1, 2, 3], <int>[1, 2, 4], <int>[2, 3, 5], <int>[1, 3, 4], <int>[2, 3, 4], <int>[1, 2, 5], <int>[3, 4, 5],
    ];
    final List<String> nm = sets[rng.nextInt(sets.length)];
    final bool three = level >= 1 && rng.nextInt(3) == 0;
    final List<int> parts = three ? threes[rng.nextInt(threes.length)] : twos[rng.nextInt(twos.length)];
    final int k = 2 + rng.nextInt(level < 2 ? 3 : 6);
    return CargoJob._(nm.sublist(0, parts.length), List<int>.from(parts), k);
  }

  @override
  int get kind => emberJobCargo;

  @override
  String get title => 'Cargo ratio';

  int get partsSum => _sum(parts);

  int get total => k * partsSum;

  int get held => _sum(counts);

  @override
  String get statement => 'Load ${names.join(', ')} in the ratio ${parts.join(' : ')}. The hold must carry exactly $total units.';

  void adjust(int i, int d) {
    if (i < 0 || i >= counts.length) return;
    counts[i] = (counts[i] + d).clamp(0, 99).toInt();
  }

  @override
  bool get canSubmit => held > 0;

  @override
  bool check() {
    if (held != total) return false;
    for (int i = 0; i < parts.length; i++) {
      if (counts[i] != parts[i] * k) return false;
    }
    return true;
  }

  @override
  String get working => '${parts.join(' + ')} = $partsSum parts, and $total / $partsSum = $k units in each part, so ${parts.map((int p) => '${p * k}').join(', ')}.';

  @override
  String get answerText => parts.map((int p) => '${p * k}').join(' : ');

  @override
  String get chosenText => counts.join(' : ');
}

// ---------------------------------------------------------------------------
// 2. Mend the sail

const List<int> emberPieceTwelfths = <int>[6, 4, 3, 2, 1];
const List<String> emberPieceLabels = <String>['1/2', '1/3', '1/4', '1/6', '1/12'];

int _gcd(int a, int b) {
  int x = a.abs();
  int y = b.abs();
  while (y != 0) {
    final int t = x % y;
    x = y;
    y = t;
  }
  return x == 0 ? 1 : x;
}

class SailJob extends EmberJob {
  /// The torn area in twelfths of the sail.
  final int twelfths;

  /// Piece indexes into [emberPieceTwelfths], in the order placed.
  final List<int> placed = <int>[];

  SailJob._(this.twelfths);

  factory SailJob.generate(Random rng, int level) {
    const List<int> pool = <int>[5, 7, 8, 9, 10, 11];
    return SailJob._(pool[rng.nextInt(pool.length)]);
  }

  @override
  int get kind => emberJobSail;

  @override
  String get title => 'Mend the sail';

  String get fractionText {
    final int g = _gcd(twelfths, 12);
    return '${twelfths ~/ g}/${12 ~/ g}';
  }

  int get patched {
    int s = 0;
    for (final int i in placed) {
      s += emberPieceTwelfths[i];
    }
    return s;
  }

  @override
  String get statement => 'A torn part of the sail is $fractionText of the whole sail. Tap pieces on the fraction wall to patch it exactly, with no gaps and no overlap.';

  void add(int piece) {
    if (piece < 0 || piece >= emberPieceTwelfths.length) return;
    if (placed.length >= 14) return;
    placed.add(piece);
  }

  void undo() {
    if (placed.isNotEmpty) placed.removeLast();
  }

  void clear() => placed.clear();

  @override
  bool get canSubmit => placed.isNotEmpty;

  @override
  bool check() => patched == twelfths;

  List<int> _greedy() {
    final List<int> out = <int>[];
    int left = twelfths;
    for (int i = 0; i < emberPieceTwelfths.length; i++) {
      while (left >= emberPieceTwelfths[i]) {
        out.add(i);
        left -= emberPieceTwelfths[i];
      }
    }
    return out;
  }

  @override
  String get working {
    final List<int> g = _greedy();
    return '$fractionText = $twelfths/12 = ${g.map((int i) => '${emberPieceTwelfths[i]}/12').join(' + ')}, which is ${g.map((int i) => emberPieceLabels[i]).join(' + ')}.';
  }

  @override
  String get answerText => _greedy().map((int i) => emberPieceLabels[i]).join(' + ');

  @override
  String get chosenText => placed.isEmpty ? 'No patches' : placed.map((int i) => emberPieceLabels[i]).join(' + ');
}

// ---------------------------------------------------------------------------
// 3. Lamp angles

class LampSector {
  final int start;
  final int sweep;
  const LampSector(this.start, this.sweep);
}

class LampJob extends EmberJob {
  /// 0 bay between two bearings, 1 straight line, 2 triangle, 3 full turn.
  final int variant;
  final List<LampSector> given;
  final int baseBearing;
  final List<int> guides;
  final int answer;
  final String text;
  final String workingText;
  int sweep = 0;

  LampJob._(this.variant, this.given, this.baseBearing, this.guides, this.answer, this.text, this.workingText);

  factory LampJob.generate(Random rng, int level) {
    final int variant = rng.nextInt(4);
    final int b0 = 5 * rng.nextInt(72);
    switch (variant) {
      case 0: {
        final int width = 5 * (4 + rng.nextInt(30));
        final int b2 = (b0 + width) % 360;
        final String w = b2 >= b0
            ? '${emberBearing(b2)} - ${emberBearing(b0)} = $width degrees.'
            : '(360 - $b0) + $b2 = $width degrees, because the bay crosses north (bearing 000).';
        return LampJob._(
          0,
          const <LampSector>[],
          b0,
          <int>[b0],
          width,
          'The bay lies between bearing ${emberBearing(b0)} and bearing ${emberBearing(b2)}. The beam starts at ${emberBearing(b0)} and turns clockwise. Sweep it across the whole bay.',
          w,
        );
      }
      case 1: {
        final int g = 5 * (5 + rng.nextInt(26));
        return LampJob._(
          1,
          <LampSector>[LampSector(b0, g)],
          (b0 + g) % 360,
          <int>[b0, (b0 + 180) % 360],
          180 - g,
          'The shore light already shows $g degrees of a straight line. Sweep the beam through the rest of the straight line.',
          'Angles on a straight line add up to 180: 180 - $g = ${180 - g} degrees.',
        );
      }
      case 2: {
        int a1 = 5 * (6 + rng.nextInt(14));
        int a2 = 5 * (6 + rng.nextInt(14));
        if (a1 + a2 > 150) a2 = 150 - a1;
        if (a2 < 30) {
          a2 = 30;
          a1 = 80;
        }
        return LampJob._(
          2,
          <LampSector>[LampSector(b0, a1), LampSector((b0 + a1) % 360, a2)],
          (b0 + a1 + a2) % 360,
          const <int>[],
          180 - a1 - a2,
          'A harbour triangle has two angles of $a1 and $a2 degrees. Sweep the beam through the third angle.',
          'Angles in a triangle add up to 180: 180 - ($a1 + $a2) = ${180 - a1 - a2} degrees.',
        );
      }
      default: {
        final int g1 = 5 * (8 + rng.nextInt(12));
        final int g2 = 5 * (8 + rng.nextInt(12));
        int g3 = 5 * (8 + rng.nextInt(12));
        if (g1 + g2 + g3 > 320) g3 = 5 * ((320 - g1 - g2) ~/ 5);
        if (g3 < 40) g3 = 40;
        final int rest = 360 - g1 - g2 - g3;
        return LampJob._(
          3,
          <LampSector>[LampSector(b0, g1), LampSector((b0 + g1) % 360, g2), LampSector((b0 + g1 + g2) % 360, g3)],
          (b0 + g1 + g2 + g3) % 360,
          const <int>[],
          rest,
          'The lamp already lights $g1, $g2 and $g3 degrees around the tower. Angles round a point add up to 360. Sweep the beam through the rest.',
          '360 - ($g1 + $g2 + $g3) = $rest degrees.',
        );
      }
    }
  }

  @override
  int get kind => emberJobLamp;

  @override
  String get title => 'Lamp angles';

  @override
  String get statement => text;

  void adjust(int d) {
    sweep = (sweep + d).clamp(0, 360).toInt();
  }

  @override
  bool get canSubmit => sweep > 0;

  @override
  bool check() => sweep == answer;

  @override
  String get working => workingText;

  @override
  String get answerText => '$answer degrees';

  @override
  String get chosenText => '$sweep degrees';
}

// ---------------------------------------------------------------------------
// 4. Barter

class BarterJob extends EmberJob {
  final String goods;
  final List<int> packSize;
  final List<int> packPrice;
  final List<int> unit;
  final int need;
  final int best;
  int picked = -1;
  String entry = '';

  BarterJob._(this.goods, this.packSize, this.packPrice, this.unit, this.need, this.best);

  factory BarterJob.generate(Random rng, int level) {
    const List<String> goodsList = <String>['shea butter', 'palm oil', 'rice', 'candles', 'dried fish', 'salt'];
    const List<int> sizes = <int>[4, 5, 6, 8, 10, 12, 15, 20];
    List<int> sz = <int>[];
    List<int> price = <int>[];
    List<int> unit = <int>[];
    int best = 0;
    for (int attempt = 0; attempt < 30; attempt++) {
      final int base = 8 + rng.nextInt(26);
      final Set<int> us = <int>{base};
      while (us.length < 3) {
        us.add(base + rng.nextInt(9) - 3);
      }
      unit = us.toList()..shuffle(rng);
      final List<int> pool = List<int>.from(sizes)..shuffle(rng);
      sz = pool.sublist(0, 3);
      price = <int>[for (int i = 0; i < 3; i++) sz[i] * unit[i]];
      int b = 0;
      int cheapestPack = 0;
      for (int i = 1; i < 3; i++) {
        if (unit[i] < unit[b]) b = i;
        if (price[i] < price[cheapestPack]) cheapestPack = i;
      }
      best = b;
      if (b != cheapestPack || attempt == 29) break;
    }
    final int need = 5 * (3 + rng.nextInt(8));
    return BarterJob._(goodsList[rng.nextInt(goodsList.length)], sz, price, unit, need, best);
  }

  @override
  int get kind => emberJobBarter;

  @override
  String get title => 'Barter';

  static const List<String> stallNames = <String>['A', 'B', 'C'];

  int get total => need * unit[best];

  @override
  String get statement => 'Three stalls sell $goods in different packs. Tap the stall with the lowest price for one unit, then enter what $need units cost at that price.';

  void pick(int i) {
    if (i >= 0 && i < 3) picked = i;
  }

  void key(String k) {
    if (k == 'DEL') {
      if (entry.isNotEmpty) entry = entry.substring(0, entry.length - 1);
    } else if (k == 'CLR') {
      entry = '';
    } else if (entry.length < 5) {
      if (entry == '0') {
        entry = k;
      } else {
        entry = '$entry$k';
      }
    }
  }

  @override
  bool get canSubmit => picked >= 0 && entry.isNotEmpty;

  @override
  bool check() => picked == best && int.tryParse(entry) == total;

  @override
  String get working {
    final String per = <String>[for (int i = 0; i < 3; i++) '${stallNames[i]}: ${packPrice[i]} / ${packSize[i]} = ${unit[i]}'].join(', ');
    return 'Price for one unit: $per. Stall ${stallNames[best]} is cheapest, so $need x ${unit[best]} = $total naira.';
  }

  @override
  String get answerText => 'Stall ${stallNames[best]}, $total naira';

  @override
  String get chosenText => '${picked >= 0 ? 'Stall ${stallNames[picked]}' : 'No stall'}, ${entry.isEmpty ? 'no total' : '$entry naira'}';
}

// ---------------------------------------------------------------------------
// Boss: the Night Tide

class TideBoss {
  /// The six tide events, signed.
  final List<int> events;

  /// Three counter-moves for each event, signed.
  final List<List<int>> options;

  /// The index of one counter-move per event that reaches the safe mark.
  final List<int> solution;
  final int safe;

  /// The option index chosen so far for each event.
  final List<int> picks = <int>[];

  TideBoss._(this.events, this.options, this.solution, this.safe);

  factory TideBoss.generate(Random rng) {
    final List<int> ev = <int>[];
    final List<List<int>> opts = <List<int>>[];
    final List<int> sol = <int>[];
    int level = 0;
    for (int i = 0; i < 6; i++) {
      int e = 0;
      while (e == 0) {
        e = rng.nextInt(13) - 6;
      }
      if (i >= 1 && ev.isNotEmpty) {
        // Keep a mix of signs: flip the sign now and then.
        final int pos = ev.where((int v) => v > 0).length;
        final int neg = ev.where((int v) => v < 0).length;
        if (pos >= 4 && e > 0) e = -e;
        if (neg >= 4 && e < 0) e = -e;
      }
      int c = 0;
      for (int tries = 0; tries < 40; tries++) {
        c = rng.nextInt(11) - 5;
        if (c == 0) continue;
        if ((level + e + c).abs() <= 9) break;
      }
      if (c == 0) c = level + e > 0 ? -1 : 1;
      level += e + c;
      final Set<int> o = <int>{c};
      while (o.length < 3) {
        final int d = rng.nextInt(13) - 6;
        if (d != 0) o.add(d);
      }
      final List<int> list = o.toList()..shuffle(rng);
      ev.add(e);
      opts.add(list);
      sol.add(list.indexOf(c));
    }
    return TideBoss._(ev, opts, sol, level);
  }

  int get step => picks.length;

  bool get complete => picks.length >= events.length;

  int levelAfter(int n) {
    int lv = 0;
    for (int i = 0; i < n && i < picks.length && i < events.length; i++) {
      lv += events[i] + options[i][picks[i]];
    }
    return lv;
  }

  int get level => levelAfter(picks.length);

  int get eventsTotal => _sum(events);

  bool check() => complete && level == safe;

  void pick(int opt) {
    if (complete || opt < 0 || opt > 2) return;
    picks.add(opt);
  }

  void undo() {
    if (picks.isNotEmpty) picks.removeLast();
  }

  List<int> get solutionMoves => <int>[for (int i = 0; i < events.length; i++) options[i][solution[i]]];

  String get working {
    final int need = safe - eventsTotal;
    return 'The events add up to ${emberSigned(eventsTotal)}. To end at ${emberSigned(safe)} the counter-moves must add up to ${emberSigned(safe)} - (${emberSigned(eventsTotal)}) = ${emberSigned(need)}. One way: ${solutionMoves.map(emberSigned).join(', ')}.';
  }

  String get answerText => solutionMoves.map(emberSigned).join(', ');

  String get chosenText => picks.isEmpty ? 'No moves' : <String>[for (int i = 0; i < picks.length; i++) emberSigned(options[i][picks[i]])].join(', ');
}
