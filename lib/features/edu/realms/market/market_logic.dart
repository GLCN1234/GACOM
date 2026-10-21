import 'package:flutter/material.dart';
import '../realm_kit.dart';
import 'market_skins.dart';

double mkCl(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
int mkCli(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// Notes and coins the player hands over as change.
const List<int> mkNotes = <int>[1000, 500, 200, 100, 50, 20, 10];

/// What is traded in the market. Prices are always whole tens, so change can
/// always be made from the notes above.
class MkGood {
  final String name;
  final int base;
  final Color color;
  const MkGood(this.name, this.base, this.color);
}

const List<MkGood> mkGoods = <MkGood>[
  MkGood('Yam', 450, Color(0xFFBCAAA4)),
  MkGood('Rice', 320, Color(0xFFFFF59D)),
  MkGood('Fish', 680, Color(0xFF80DEEA)),
  MkGood('Cloth', 1200, Color(0xFFCE93D8)),
];

/// A supplier stall standing in the market. [x] and [y] are in world units,
/// which the painter maps into the top part of the screen.
class MkStall {
  final int goodIndex;
  final double x;
  final double y;
  int price;
  int stock;
  MkStall(this.goodIndex, this.x, this.y, this.price, this.stock);
}

/// A customer at your own counter: how many units they want, and the note
/// they are paying with.
class MkCustomer {
  final int goodIndex;
  final int units;
  final int total;
  final int paid;
  MkCustomer(this.goodIndex, this.units, this.total, this.paid);

  int get change => paid - total;
}

/// Which panel is open at the bottom of the screen. The world is drawn above
/// the panel, never behind it, so the player is always visible.
const int mkNone = 0;
const int mkBuy = 1;
const int mkSell = 2;

/// Market Run: a trading day with no questions in it. The maths is the money.
/// Buying below the market price is the profit, and giving a customer the
/// right change is the recorded task.
class MarketLogic extends RealmLogic {
  MarketLogic(RealmContent content) : super(content) {
    for (int i = 0; i < mkGoods.length; i++) {
      final double ang = i / mkGoods.length;
      stalls.add(MkStall(
        i,
        0.16 + (i % 2) * 0.62,
        0.18 + (i ~/ 2) * 0.40 + ang * 0.02,
        _rollPrice(i),
        6 + rng.nextInt(8),
      ));
    }
  }

  MarketSkin get skin => MarketSkin.equipped();

  static const double dayLength = 200.0;
  static const int startCash = 6000;
  static const int basketCap = 14;
  static const double counterX = 0.5;
  static const double counterY = 0.82;

  double x = 0.5;
  double y = 0.60;
  double walkPhase = 0;
  double facing = 1;

  int cash = startCash;
  final List<int> basket = List<int>.filled(mkGoods.length, 0);
  final List<MkStall> stalls = <MkStall>[];

  /// The price customers pay today, per good. Buying under it is the profit.
  final List<int> market = <int>[for (final MkGood g in mkGoods) g.base];

  int panel = mkNone;
  int panelStall = -1;
  int buyQty = 1;

  MkCustomer? customer;
  final List<int> handed = <int>[];
  double _nextCustomer = 6;

  int trades = 0;
  int goodChange = 0;
  int badChange = 0;
  double goodFlash = 0;
  double hitFlash = 0;
  String note = '';
  double noteT = 0;

  int get basketCount {
    int n = 0;
    for (final int b in basket) {
      n += b;
    }
    return n;
  }

  int get handedTotal {
    int n = 0;
    for (final int h in handed) {
      n += h;
    }
    return n;
  }

  int get profit => cash - startCash;
  double get dayLeft => dayLength - time;

  int _rollPrice(int goodIndex) {
    final int base = mkGoods[goodIndex].base;
    final int swing = (base * 0.30).round();
    final int raw = base - swing + rng.nextInt(swing * 2);
    return (raw / 10).round() * 10;
  }

  @override
  bool get modal => panel != mkNone;

  @override
  int get hearts => -1;

  @override
  String get resultTitle => 'MARKET CLOSED';

  @override
  List<RealmChip> get chips => <RealmChip>[
        RealmChip('₦$cash', Icons.account_balance_wallet_rounded, skin.accent),
        RealmChip('$basketCount/$basketCap', Icons.shopping_basket_rounded, Colors.white),
        RealmChip('${dayLeft.ceil()}s', Icons.timer_rounded, dayLeft < 30 ? const Color(0xFFFF8A80) : Colors.white70),
      ];

  @override
  Map<String, String> get extraStats => <String, String>{
        'Profit': '₦$profit',
        'Trades': '$trades',
        'Right change': '$goodChange',
        'Wrong change': '$badChange',
      };

  @override
  int get finalScore {
    final int p = profit;
    return (p < 0 ? 0 : p) + goodChange * 50;
  }

  @override
  int get xp => stats.baseXp + (profit > 0 ? (profit / 100).floor() : 0);

  @override
  String? get objectiveText {
    if (panel != mkNone) return null;
    if (customer != null) return 'A customer is waiting at your counter';
    if (basketCount == 0) return 'Buy low at a stall, then sell at your counter';
    return 'Take your basket to your counter and serve a customer';
  }

  /// The stall the player is standing at, or -1.
  int get atStall {
    for (int i = 0; i < stalls.length; i++) {
      final MkStall s = stalls[i];
      if ((s.x - x).abs() < 0.11 && (s.y - y).abs() < 0.10) return i;
    }
    return -1;
  }

  bool get atCounter => (counterX - x).abs() < 0.13 && (counterY - y).abs() < 0.12;

  // -------------------------------------------------------------- actions

  @override
  void onAction(int id) {
    if (over) return;
    if (id != 0) return;
    if (panel != mkNone) {
      close();
      return;
    }
    final int s = atStall;
    if (s >= 0) {
      panel = mkBuy;
      panelStall = s;
      buyQty = 1;
      cues.add('tap');
      return;
    }
    if (atCounter && customer != null) {
      panel = mkSell;
      handed.clear();
      cues.add('tap');
      return;
    }
    note = customer != null ? 'Walk to your counter to serve' : 'Stand at a stall to buy';
    noteT = 1.6;
  }

  @override
  double actionReady(int id) => (atStall >= 0 || (atCounter && customer != null) || panel != mkNone) ? 1 : 0;

  void close() {
    panel = mkNone;
    panelStall = -1;
    handed.clear();
  }

  void setQty(int q) {
    if (panelStall < 0) return;
    final MkStall s = stalls[panelStall];
    final int roomLeft = basketCap - basketCount;
    final int affordable = s.price <= 0 ? 0 : cash ~/ s.price;
    buyQty = mkCli(q, 1, mkCli(roomLeft < affordable ? roomLeft : affordable, 1, s.stock));
  }

  int get buyTotal => panelStall < 0 ? 0 : stalls[panelStall].price * buyQty;

  /// True when the stall's price is under what customers pay today.
  bool get stallIsCheap {
    if (panelStall < 0) return false;
    final MkStall s = stalls[panelStall];
    return s.price < market[s.goodIndex];
  }

  void confirmBuy() {
    if (panelStall < 0) return;
    final MkStall s = stalls[panelStall];
    final int qty = buyQty;
    final int total = s.price * qty;
    if (qty < 1 || total > cash || basketCount + qty > basketCap || qty > s.stock) {
      note = 'You cannot carry or afford that';
      noteT = 1.6;
      return;
    }
    cash -= total;
    basket[s.goodIndex] += qty;
    s.stock -= qty;
    trades++;
    goodFlash = 0.35;
    note = 'Bought $qty ${mkGoods[s.goodIndex].name} for ₦$total';
    noteT = 1.8;
    cues.add('tap');
    close();
  }

  void hand(int noteValue) {
    final MkCustomer? c = customer;
    if (c == null || panel != mkSell) return;
    if (handedTotal + noteValue > c.change + 2000) return;
    handed.add(noteValue);
    cues.add('tap');
  }

  void undoHand() {
    if (handed.isNotEmpty) handed.removeLast();
  }

  /// The change the player handed over is checked against the real change.
  void confirmSale() {
    final MkCustomer? c = customer;
    if (c == null) return;
    if (basket[c.goodIndex] < c.units) {
      note = 'You do not have ${c.units} ${mkGoods[c.goodIndex].name}';
      noteT = 1.8;
      return;
    }
    final int given = handedTotal;
    final bool ok = given == c.change;
    stats.recordTask(
      'math',
      ok,
      prompt: 'Change from ₦${c.paid} for ₦${c.total}',
      chosen: '₦$given',
      answer: '₦${c.change}',
    );
    basket[c.goodIndex] -= c.units;
    trades++;
    if (ok) {
      cash += c.total;
      goodChange++;
      goodFlash = 0.5;
      note = 'Sold. ₦${c.total} in, ₦${c.change} change';
      cues.add('good');
    } else {
      // The customer always leaves with the right change: if you handed over
      // too much they keep it and you are short, and if you handed over too
      // little they ask for the rest, so short-changing never pays.
      cash += given > c.change ? c.paid - given : c.total;
      badChange++;
      hitFlash = 0.5;
      note = given > c.change
          ? 'You gave ₦${given - c.change} too much. It was ₦${c.change}'
          : 'You gave ₦${c.change - given} too little. It was ₦${c.change}';
      cues.add('bad');
    }
    noteT = 2.4;
    customer = null;
    close();
  }

  // -------------------------------------------------------------- frame

  void _newCustomer() {
    // A customer only asks for something the player is actually carrying.
    final List<int> have = <int>[];
    for (int i = 0; i < basket.length; i++) {
      if (basket[i] > 0) have.add(i);
    }
    if (have.isEmpty) return;
    final int g = have[rng.nextInt(have.length)];
    final int units = 1 + rng.nextInt(basket[g] > 4 ? 4 : basket[g]);
    final int total = market[g] * units;
    // The note they pay with is always more than the bill, so change is due.
    int paid = 0;
    for (final int n in <int>[1000, 2000, 5000]) {
      if (n > total) {
        paid = n;
        break;
      }
    }
    if (paid == 0) paid = ((total / 1000).ceil() + 1) * 1000;
    customer = MkCustomer(g, units, total, paid);
    note = 'A customer wants $units ${mkGoods[g].name}';
    noteT = 2.0;
  }

  @override
  void step(double dt) {
    if (over) return;
    if (goodFlash > 0) goodFlash -= dt;
    if (hitFlash > 0) hitFlash -= dt;
    if (noteT > 0) noteT -= dt;

    if (time >= dayLength) {
      over = true;
      cues.add('win');
      return;
    }

    if (panel == mkNone) {
      final double sp = 0.30;
      final double nx = mkCl(x + inputX * sp * dt, 0.05, 0.95);
      final double ny = mkCl(y + inputY * sp * dt, 0.08, 0.92);
      final bool moved = (nx - x).abs() > 0.0001 || (ny - y).abs() > 0.0001;
      if (moved) {
        walkPhase += dt * 9;
        if ((nx - x).abs() > 0.0001) facing = nx > x ? 1 : -1;
      }
      x = nx;
      y = ny;
    }

    // Prices drift through the day, so the same stall is not always the cheapest.
    for (final MkStall s in stalls) {
      if (rng.nextDouble() < dt * 0.08) {
        s.price = _rollPrice(s.goodIndex);
        if (s.stock < 3) s.stock += 2 + rng.nextInt(4);
      }
    }
    for (int i = 0; i < market.length; i++) {
      if (rng.nextDouble() < dt * 0.05) {
        final int base = mkGoods[i].base;
        final int drift = ((rng.nextDouble() - 0.4) * base * 0.12).round();
        market[i] = mkCli((((market[i] + drift) / 10).round()) * 10, (base * 0.75).round(), (base * 1.45).round());
      }
    }

    if (customer == null) {
      _nextCustomer -= dt;
      if (_nextCustomer <= 0) {
        _newCustomer();
        _nextCustomer = 7 + rng.nextDouble() * 5;
      }
    }
  }
}
