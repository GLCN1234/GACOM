import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/widgets/weapon_art.dart';
import '../darkom_look.dart';
import '../darkom_story.dart';
import 'darkom_arena_logic.dart';
import 'darkom_arena_painter.dart';

const Color _cyan = Color(0xFF00E5FF);
const Color _pink = Color(0xFFFF2E93);
const Color _gold = Color(0xFFFFD54F);
const Color _red = Color(0xFFFF5252);
const Color _green = Color(0xFF69F0AE);
const Color _panel = Color(0xE60B0B12);

const TextStyle _head = TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, letterSpacing: 1.2);

BoxDecoration _glass(Color border, {double radius = 16}) => BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border.withValues(alpha: 0.8), width: 1.3),
    );

Widget _bar(double w, double h, double f, Color c) {
  final double ff = f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(h / 2), border: Border.all(color: Colors.white24, width: 1)),
    child: Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: ff,
        child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h / 2))),
      ),
    ),
  );
}

Widget arenaButton(String label, VoidCallback onTap, {bool secondary = false, bool danger = false, double width = 190}) {
  return SizedBox(
    width: width,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: danger ? const Color(0xFF8E1B2A) : (secondary ? Colors.white12 : _pink),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      onPressed: onTap,
      child: Text(label, style: _head.copyWith(fontSize: 15)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Weapon picker

class ArenaWeaponPicker extends StatelessWidget {
  final ArenaGame game;
  final void Function(String kind) onPick;
  const ArenaWeaponPicker({super.key, required this.game, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final String kind in darkomWeaponKinds) _card(kind),
      ],
    );
  }

  Widget _card(String kind) {
    final DarkomWeaponDef d = darkomWeapon(kind);
    final bool sel = game.chosen == kind;
    return GestureDetector(
      onTap: () => onPick(kind),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 92,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          color: sel ? const Color(0x33FFD54F) : const Color(0x66000000),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _gold : Colors.white24, width: sel ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          SizedBox(
            width: 52,
            height: 52,
            child: WeaponArt(key: ValueKey<String>('arena_${kind}_${game.armory.skinNameFor(kind)}'), asset: game.armory.assetFor(kind), size: 52, rarity: game.armory.rarityFor(kind), animate: sel),
          ),
          const SizedBox(height: 3),
          Text(d.name.toUpperCase(), style: _head.copyWith(fontSize: 12.5)),
          Text(d.blurb, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9.5, height: 1.2)),
          const SizedBox(height: 2),
          Text(d.special, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sel ? _gold : Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lobby

class ArenaLobbyPanel extends StatelessWidget {
  final ArenaGame game;
  final Listenable tick;
  final VoidCallback onReady;
  final VoidCallback onLeave;
  final void Function(String kind) onPick;
  const ArenaLobbyPanel({super.key, required this.game, required this.tick, required this.onReady, required this.onLeave, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tick,
      builder: (BuildContext c, Widget? w) {
        final List<ArenaPlayer> here = game.lobbyPlayers;
        final int want = game.isDuel ? 2 : max(2, game.args.playerIds.length);
        final double left = max(0.0, kArLobbyWait - game.lobbyT);
        final String status;
        if (here.length < 2) {
          status = game.isDuel ? 'Waiting for your opponent  ${left.ceil()}s' : 'Waiting for your squad  ${left.ceil()}s';
        } else if (!game.isDuel && here.length < want && left > 0) {
          status = '${here.length} of $want here. Waiting for the rest  ${left.ceil()}s';
        } else if (game.me.ready) {
          status = 'Ready. Waiting for the others.';
        } else {
          status = 'Pick your weapon, then tap READY.';
        }
        return Container(
          color: const Color(0xDD05060A),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(game.isDuel ? 'DARKOM ARENA  DUEL' : 'DARKOM ARENA  SQUAD', style: _head.copyWith(fontSize: 22, color: _cyan)),
                    const SizedBox(height: 2),
                    Text(game.isDuel ? 'Best of 3 rounds. Same health, same damage, only the look differs.' : 'Free for all. Last one standing wins the round. Best of 3.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 10),
                    Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: <Widget>[
                      for (final ArenaPlayer p in here) _playerCard(p),
                      for (int i = here.length; i < want; i++) _emptyCard(),
                    ]),
                    const SizedBox(height: 8),
                    Text(status, textAlign: TextAlign.center, style: TextStyle(color: here.length < 2 ? _gold : Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: _glass(Colors.white24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                        Text('CHOOSE YOUR WEAPON', style: _head.copyWith(fontSize: 12, color: Colors.white54)),
                        const SizedBox(height: 8),
                        ArenaWeaponPicker(game: game, onPick: onPick),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: <Widget>[
                      arenaButton(game.me.ready ? 'NOT READY' : 'READY', onReady, secondary: game.me.ready, width: 170),
                      arenaButton('LEAVE', onLeave, secondary: true, width: 130),
                    ]),
                  ]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _playerCard(ArenaPlayer p) {
    final DarkomLook look = p.look;
    final bool mine = identical(p, game.me);
    return Container(
      width: 132,
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: _glass(p.ready ? _green : (mine ? _cyan : Colors.white24)),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        SizedBox(width: 90, height: 100, child: CustomPaint(painter: ArenaLookPainter(look, p.ready))),
        Text(mine ? '${look.name} (you)' : look.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _head.copyWith(fontSize: 13)),
        if (look.title != null) Text(look.title!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w700)),
        Text(darkomWeapon(mine ? game.chosen : p.pick).name, style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: (p.ready ? _green : Colors.white24).withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
          child: Text(p.ready ? 'READY' : 'NOT READY', style: TextStyle(color: p.ready ? _green : Colors.white60, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        ),
      ]),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: 132,
      height: 168,
      decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: const <Widget>[
        SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white38)),
        SizedBox(height: 10),
        Text('Waiting...', style: TextStyle(color: Colors.white38, fontSize: 12)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// HUD

class ArenaHud extends StatelessWidget {
  final ArenaGame game;
  final Listenable tick;
  final Listenable frame;
  final VoidCallback onLeave;
  final void Function(int e) onEmote;
  final VoidCallback onAttack;
  final VoidCallback onSpecial;
  final VoidCallback onDash;
  final bool buttons;
  const ArenaHud({
    super.key,
    required this.game,
    required this.tick,
    required this.frame,
    required this.onLeave,
    required this.onEmote,
    required this.onAttack,
    required this.onSpecial,
    required this.onDash,
    this.buttons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: <Widget>[
      AnimatedBuilder(
        animation: tick,
        builder: (BuildContext c, Widget? w) => _top(context),
      ),
      AnimatedBuilder(
        animation: tick,
        builder: (BuildContext c, Widget? w) => _banner(),
      ),
      if (buttons) _buttons(),
    ]);
  }

  Widget _top(BuildContext context) {
    final ArenaGame g = game;
    final ArenaPlayer me = g.me;
    final List<ArenaPlayer> foes = g.opponents();
    final int q = g.linkQuality();
    final Color qc = q == 0 ? _green : (q == 1 ? _gold : _red);
    final String qt = q == 0 ? 'Live' : (q == 1 ? 'Fair' : (q == 2 ? 'Lagging' : 'Lost'));
    final double sw = MediaQuery.of(context).size.width;
    return Stack(children: <Widget>[
      Positioned(
        left: 10,
        top: 6,
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 7),
            decoration: _glass(_cyan, radius: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
              SizedBox(width: 128, child: Text(me.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _head.copyWith(fontSize: 12.5))),
              const SizedBox(height: 3),
              _bar(128, 11, me.hp / kArHp, me.hp < 30 ? _red : _green),
              if (me.weapon == 'staff') Padding(padding: const EdgeInsets.only(top: 3), child: _bar(128, 6, g.mana / 100, const Color(0xFF40C4FF))),
              if (me.weapon == 'shield') Padding(padding: const EdgeInsets.only(top: 3), child: _bar(128, 6, g.guard > 0 ? g.guard / 0.6 : 0.0, const Color(0xFF80D8FF))),
            ]),
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        top: 6,
        child: IgnorePointer(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: max(120.0, sw - 330)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: _glass(_pink, radius: 14),
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Wrap(alignment: WrapAlignment.center, spacing: 10, children: <Widget>[
                    Text('ROUND ${g.round}', style: _head.copyWith(fontSize: 11.5, color: Colors.white54)),
                    for (final ArenaPlayer p in g.roster)
                      Text('${identical(p, me) ? 'YOU' : p.name}  ${p.wins}', style: _head.copyWith(fontSize: 13, color: identical(p, me) ? _cyan : arenaRingFor(g, p))),
                  ]),
                  Text(g.objective, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        right: 8,
        top: 4,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20), border: Border.all(color: qc.withValues(alpha: 0.8))),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(Icons.wifi_rounded, size: 14, color: qc),
                const SizedBox(width: 4),
                Text(qt, style: TextStyle(color: qc, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onLeave,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0x99000000), shape: BoxShape.circle, border: Border.all(color: Colors.white38)),
                child: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          for (final ArenaPlayer p in foes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IgnorePointer(
                child: Container(
                  width: 128,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                  decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(10), border: Border.all(color: arenaRingFor(g, p).withValues(alpha: 0.8))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(p.alive ? p.name : '${p.name}  down', maxLines: 1, overflow: TextOverflow.ellipsis, style: _head.copyWith(fontSize: 11.5, color: p.alive ? Colors.white : Colors.white38)),
                    const SizedBox(height: 2),
                    _bar(112, 7, p.hp / kArHp, p.alive ? _red : Colors.white24),
                  ]),
                ),
              ),
            ),
          Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            _emote(Icons.front_hand_rounded, 'Wave', 0),
            const SizedBox(width: 6),
            _emote(Icons.thumb_up_rounded, 'GG', 1),
          ]),
        ]),
      ),
    ]);
  }

  Widget _emote(IconData icon, String label, int e) {
    return GestureDetector(
      onTap: () => onEmote(e),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _banner() {
    final ArenaGame g = game;
    String text = '';
    double size = 40;
    Color col = Colors.white;
    if (g.phase == ArPhase.countdown) {
      text = '${max(1, g.phaseT.ceil())}';
      size = 64;
      col = _cyan;
    } else if (g.bannerT > 0 && g.banner.isNotEmpty) {
      text = g.banner;
      col = g.banner == 'FIGHT' ? _red : (g.banner == 'GRID OVERLOAD' ? _red : _gold);
    } else if (g.phase == ArPhase.fight && !g.me.alive) {
      text = 'You are down. Watching.';
      size = 18;
      col = Colors.white70;
    }
    if (text.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.35),
        child: Text(text, textAlign: TextAlign.center, style: _head.copyWith(fontSize: size, color: col, shadows: const <Shadow>[Shadow(color: Colors.black, blurRadius: 10)])),
      ),
    );
  }

  Widget _buttons() {
    return Stack(children: <Widget>[
      Positioned(right: 20, bottom: 22, child: _btn(0, 'ATTACK', Icons.flash_on_rounded, 80, onAttack, _pink)),
      Positioned(right: 112, bottom: 30, child: _btn(1, 'SPECIAL', Icons.bolt_rounded, 66, onSpecial, _gold)),
      Positioned(right: 34, bottom: 112, child: _btn(2, 'DASH', Icons.directions_run_rounded, 62, onDash, _cyan)),
    ]);
  }

  Widget _btn(int which, String label, IconData icon, double size, VoidCallback cb, Color color) {
    return Listener(
      onPointerDown: (_) => cb(),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: <Widget>[
          CustomPaint(size: Size(size, size), painter: ArenaRingPainter(game, which, color, repaint: frame)),
          Container(
            width: size - 16,
            height: size - 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.55), border: Border.all(color: color.withValues(alpha: 0.7))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(icon, color: Colors.white, size: size * 0.3),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Between rounds

class ArenaIntermissionPanel extends StatelessWidget {
  final ArenaGame game;
  final Listenable tick;
  final void Function(String kind) onPick;
  const ArenaIntermissionPanel({super.key, required this.game, required this.tick, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tick,
      builder: (BuildContext c, Widget? w) {
        final ArenaGame g = game;
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: _glass(_pink),
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(g.lastRoundLine.isEmpty ? 'Round over' : g.lastRoundLine, style: _head.copyWith(fontSize: 18, color: _gold)),
                  Text('Next round in ${max(0, g.phaseT.ceil())}s. You may change weapon now.', style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
                  const SizedBox(height: 8),
                  ArenaWeaponPicker(game: g, onPick: onPick),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Failed and result

class ArenaFailedCard extends StatelessWidget {
  final ArenaGame game;
  final VoidCallback onLeave;
  const ArenaFailedCard({super.key, required this.game, required this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xDD05060A),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: _glass(_gold),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const Icon(Icons.hourglass_top_rounded, color: _gold, size: 40),
            const SizedBox(height: 8),
            Text(game.failText, textAlign: TextAlign.center, style: _head.copyWith(fontSize: 20)),
            const SizedBox(height: 6),
            const Text('No result was recorded. If they arrive in the next moments the lobby opens again by itself.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 16),
            arenaButton('LEAVE', onLeave),
          ]),
        ),
      ),
    );
  }
}

class ArenaResultCard extends StatelessWidget {
  final ArenaGame game;
  final bool reporting;
  final String reportText;
  final VoidCallback onRematch;
  final VoidCallback onLeave;
  const ArenaResultCard({super.key, required this.game, required this.reporting, required this.reportText, required this.onRematch, required this.onLeave});

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  @override
  Widget build(BuildContext context) {
    final ArenaGame g = game;
    final List<ArenaPlayer> st = g.standings();
    final bool won = g.iWon;
    final String title;
    if (g.isDuel) {
      title = won ? 'VICTORY' : (st.length > 1 && st[0].wins == st[1].wins ? 'DRAW' : 'DEFEAT');
    } else {
      title = won ? 'VICTORY' : 'YOU PLACED ${_ordinal(g.myPlacement)}';
    }
    final Color tc = won ? _gold : (title == 'DRAW' ? Colors.white : _red);
    return Container(
      color: const Color(0xDD05060A),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: _glass(tc),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Icon(won ? Icons.emoji_events_rounded : Icons.shield_rounded, color: tc, size: 42),
                const SizedBox(height: 4),
                Text(title, style: _head.copyWith(fontSize: 30, color: tc)),
                const SizedBox(height: 8),
                for (int i = 0; i < st.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: <Widget>[
                      SizedBox(width: 26, child: Text('${i + 1}', style: _head.copyWith(fontSize: 15, color: Colors.white54))),
                      Expanded(child: Text(identical(st[i], g.me) ? '${st[i].name} (you)' : st[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: _head.copyWith(fontSize: 14, color: identical(st[i], g.me) ? _cyan : Colors.white))),
                      Text('${st[i].wins} ${st[i].wins == 1 ? 'round' : 'rounds'}', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                    if (reporting) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
                    if (reporting) const SizedBox(width: 8),
                    Flexible(child: Text(reporting ? 'Sending your result...' : reportText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                  ]),
                ),
                const SizedBox(height: 14),
                if (g.isDuel) arenaButton('REMATCH', onRematch),
                if (g.isDuel) const SizedBox(height: 8),
                arenaButton('LEAVE', onLeave, secondary: g.isDuel),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
