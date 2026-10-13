import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../../shared/widgets/cosmetic_art.dart';
import '../../shared/widgets/cosmetic_avatar.dart';
import '../../shared/widgets/weapon_art.dart';
import '../edu/realms/realm_kit.dart';
import '../edu/realms/realm_shell.dart' show realmActionPadWidth;
import 'darkom_city.dart';
import 'darkom_coop.dart';
import 'darkom_coop_logic.dart';
import 'darkom_entities.dart';
import 'darkom_ghost.dart' show MissionGhost;
import 'darkom_logic.dart';
import 'darkom_missions.dart';
import 'darkom_service.dart';
import 'darkom_story.dart';
import 'darkom_world.dart';

const Color _hudCyan = Color(0xFF00E5FF);
const Color _hudRed = Color(0xFFFF5252);
const Color _hudGold = Color(0xFFFFD54F);

/// The Darkom City HUD: player bars, boss bar, minimap, the current weapon
/// skin on the SWAP area, and the fixer's messages. Nothing here blocks the
/// joystick except the SWAP card.
Widget darkomHud(BuildContext context, RealmLogic logic, VoidCallback refresh) {
  final DarkomLogic g = logic as DarkomLogic;
  final Size sz = MediaQuery.of(context).size;
  final bool compact = sz.height < 440;
  final DToast? toast = g.toasts.isEmpty ? null : g.toasts.first;
  final double toastW = min(300.0, max(170.0, sz.width - (compact ? 330 : 210)));
  return Positioned.fill(
    child: Stack(children: <Widget>[
      Positioned(left: 10, top: compact ? 44 : 132, child: IgnorePointer(child: _playerBlock(g))),
      if (g.coop != null) Positioned(left: 10, top: compact ? 112 : 214, child: IgnorePointer(child: _squadCard(g, compact))),
      if (g.coop != null && g.heroDead && !g.over)
        Positioned(left: 0, right: 0, top: compact ? 70 : 120, child: IgnorePointer(child: Center(child: _downedCard(g)))),
      if (g.padNear >= 0 && !g.heroDead && !g.over)
        Positioned(left: 0, right: 0, top: compact ? 134 : 190, child: Center(child: _terminalCard(context, g, refresh, compact))),
      if (g.travelMsgT > 0)
        Positioned(left: 0, right: 0, bottom: compact ? 70 : 120, child: IgnorePointer(child: Center(child: _noteChip(g.travelMsg)))),
      Positioned(right: 10, top: compact ? 54 : 132, child: _MapBox(g: g, compact: compact, screenW: sz.width, screenH: sz.height)),
      if (!g.over && !g.missionDone && !g.heroDead)
        Positioned(
          left: compact ? 205 : 12,
          right: compact ? 130 : 12,
          top: compact ? 88 : 140,
          child: IgnorePointer(child: Align(alignment: Alignment.topCenter, child: _tracker(g, compact))),
        ),
      if (toast != null) Positioned(left: 10, bottom: compact ? 10 : 24, child: IgnorePointer(child: _toastCard(toast, toastW))),
      Positioned(right: realmActionPadWidth(compact, 1.22) + (compact ? 6 : 10), bottom: compact ? 8 : 22, child: _swapCard(g, refresh, compact)),
      if (g.mission != null && g.phase == 5 && g.missionDone)
        Positioned.fill(child: _MissionFx(key: ValueKey<String>('${g.mission!.id}:${g.missionStart}'), compact: compact)),
      if (g.mission != null && g.phase == 5 && g.missionDone)
        Positioned(left: 0, right: 0, top: compact ? 86 : 150, child: Center(child: _flowCard(context, g, refresh, compact))),
    ]),
  );
}

/// Shown after a board mission: points, the next mission and a countdown.
/// The player keeps control and can move around until it starts.
Widget _flowCard(BuildContext context, DarkomLogic g, VoidCallback refresh, bool compact) {
  final DarkomMissionResult? r = g.missionRes;
  final DarkomMission? nx = g.nextM;
  final String pts = r == null ? 'saving...' : (r.accepted ? '+${r.points + r.dailyBonus} pts' : 'not counted');
  final double w = min(330.0, MediaQuery.of(context).size.width - (compact ? 330 : 40));
  return Container(
    width: max(220.0, w),
    padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
    decoration: BoxDecoration(
      color: const Color(0xDD0B0D18),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF69F0AE).withValues(alpha: 0.6)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        const Icon(Icons.check_circle_rounded, color: Color(0xFF69F0AE), size: 16),
        const SizedBox(width: 6),
        const Expanded(child: Text('MISSION COMPLETE', style: TextStyle(color: Color(0xFF69F0AE), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1))),
        Text(pts, style: const TextStyle(color: _hudGold, fontSize: 12, fontWeight: FontWeight.w900)),
      ]),
      if (g.newBest)
        const Padding(padding: EdgeInsets.only(top: 3), child: Text('NEW PERSONAL BEST - your ghost now runs this route', style: TextStyle(color: _hudCyan, fontSize: 10.5, fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      if (nx != null)
        Row(children: <Widget>[
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(alignment: Alignment.center, children: <Widget>[
              CircularProgressIndicator(value: (g.nextT / 9.0).clamp(0.0, 1.0).toDouble(), strokeWidth: 3, color: nx.tierColor, backgroundColor: Colors.white12),
              Text('${max(0, g.nextT.ceil())}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text('NEXT: ${nx.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
              Text(nx.kindLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              g.advanceMission();
              refresh();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: nx.tierColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: nx.tierColor)),
              child: const Text('SKIP', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
        ])
      else
        Row(children: <Widget>[
          const Expanded(child: Text('No other mission is open right now.', style: TextStyle(color: Colors.white70, fontSize: 11.5))),
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(10)),
              child: const Text('BOARD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
    ]),
  );
}

Widget _bar(double w, double h, double f, Color c, {Color back = const Color(0x66000000)}) {
  final double ff = f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: back, borderRadius: BorderRadius.circular(h / 2), border: Border.all(color: Colors.white24, width: 1)),
    child: Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: ff,
        child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h / 2))),
      ),
    ),
  );
}

Widget _playerBlock(DarkomLogic g) {
  final Map<String, dynamic>? loadout = CosmeticsService.myLoadout.value;
  final String? title = CosmeticsService.titleFor(loadout);
  final String wk = g.weapon;
  final Widget extra;
  if (wk == 'staff') {
    extra = Padding(padding: const EdgeInsets.only(top: 3), child: _bar(130, 7, g.mana / g.maxMana, const Color(0xFF40C4FF)));
  } else if (wk == 'shield') {
    extra = Padding(padding: const EdgeInsets.only(top: 3), child: _bar(130, 7, g.guard > 0 ? g.guard / 0.6 : 0.0, const Color(0xFF80D8FF)));
  } else {
    extra = const SizedBox.shrink();
  }
  final DEnemy? boss = g.phase == 2 ? g.echo : (g.hunted ?? g.nearestBounty());
  return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
    Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 10, 5),
      decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        CosmeticAvatar(name: g.heroName, radius: 17, equipped: loadout),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
          SizedBox(
            width: 130,
            child: Text(
              title == null ? g.heroName : '${g.heroName}  $title',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(height: 2),
          _bar(130, 10, g.hp / g.maxHp, g.hp < 30 ? _hudRed : const Color(0xFF69F0AE)),
          extra,
        ]),
      ]),
    ),
    if (boss != null && boss.alive)
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          width: 190,
          padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
          decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(12), border: Border.all(color: boss.type == 'echo' ? _hudCyan : _hudRed, width: 1.2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(
              boss.type == 'echo' ? (boss.name.isEmpty ? 'Your Echo' : boss.name) : boss.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: boss.type == 'echo' ? _hudCyan : const Color(0xFFFF8A80), fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
            ),
            const SizedBox(height: 3),
            _bar(170, 8, boss.hp / boss.maxHp, boss.type == 'echo' ? _hudCyan : _hudRed),
          ]),
        ),
      ),
  ]);
}

/// What the player is doing right now, with a progress bar when the goal can
/// be counted: kills, chips, seconds held, the mission clock and lives.
Widget _noteChip(String t) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xDD0B0D18), borderRadius: BorderRadius.circular(16), border: Border.all(color: _hudRed.withValues(alpha: 0.7))),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
  );
}

/// You are down in a squad run: a teammate can pick you up.
Widget _downedCard(DarkomLogic g) {
  final int left = max(0, g.deathT.ceil());
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xDD1A0B0B), borderRadius: BorderRadius.circular(12), border: Border.all(color: _hudRed.withValues(alpha: 0.8))),
    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const Text('YOU ARE DOWN', style: TextStyle(color: _hudRed, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      Text('A teammate can revive you. Back up in ${left}s anyway.', style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]),
  );
}

/// Open City terminal: fast travel to terminals you have found, and (solo)
/// the missions this district's giver offers.
Widget _terminalCard(BuildContext context, DarkomLogic g, VoidCallback refresh, bool compact) {
  final int q = g.padNear;
  final List<DarkomMission> offers = g.coop == null ? g.cityMissionsFor(q) : const <DarkomMission>[];
  final double w = min(380.0, MediaQuery.of(context).size.width - (compact ? 340 : 40));
  Widget pill(String label, Color col, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: onTap == null ? const Color(0x33FFFFFF) : col.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: onTap == null ? Colors.white24 : col)),
        child: Text(label, style: TextStyle(color: onTap == null ? Colors.white38 : col, fontSize: 11, fontWeight: FontWeight.w900)),
      ),
    );
  }

  return Container(
    width: max(240.0, w),
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    decoration: BoxDecoration(color: const Color(0xEE0B0D18), borderRadius: BorderRadius.circular(14), border: Border.all(color: _hudGold.withValues(alpha: 0.7))),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        const Icon(Icons.terminal_rounded, color: _hudGold, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text('${darkomGiverNames[q % 4]}  -  ${g.cityQuarterName(q)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _hudGold, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
      ]),
      const SizedBox(height: 6),
      const Text('FAST TRAVEL', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
        for (int i = 0; i < 4; i++)
          if (i != q)
            pill(g.padSeen.contains(i) ? g.cityQuarterName(i) : '${g.cityQuarterName(i)} (not found)', _hudCyan, g.padSeen.contains(i)
                ? () {
                    g.cityTravel(i);
                    refresh();
                  }
                : null),
      ]),
      if (offers.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        const Text('MISSIONS', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        for (final DarkomMission m in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: GestureDetector(
              onTap: () => g.boot.onStartMission?.call(m),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: m.tierColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: m.tierColor.withValues(alpha: 0.8))),
                child: Row(children: <Widget>[
                  Text(m.tierName.toUpperCase(), style: TextStyle(color: m.tierColor, fontSize: 9.5, fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                  const Text('GO', style: TextStyle(color: _hudGold, fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
              ),
            ),
          ),
      ],
    ]),
  );
}

/// City Patrol: everyone in the squad with their health and kills.
Widget _squadCard(DarkomLogic g, bool compact) {
  final DarkomCoop cp = g.coop!;
  final List<Widget> rows = <Widget>[];
  Widget row(String name, double frac, int kills, Color col, bool down) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: col)),
        const SizedBox(width: 5),
        SizedBox(width: 58, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: down ? Colors.white38 : Colors.white, fontSize: compact ? 9.5 : 10.5, fontWeight: FontWeight.w800))),
        _bar(compact ? 44 : 56, 5, down ? 0.0 : frac, down ? Colors.white24 : const Color(0xFF69F0AE)),
        const SizedBox(width: 5),
        Text(down ? 'DOWN' : '$kills', style: TextStyle(color: down ? _hudRed : _hudGold, fontSize: compact ? 9 : 10, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  final String me = cp.args.myId;
  rows.add(row('You', g.hp / g.maxHp, g.coopKills[me] ?? 0, darkomAllyColors[cp.args.slotOf(me) % darkomAllyColors.length], g.heroDead));
  for (final DAlly a in cp.allies.values) {
    if (a.gone) continue;
    rows.add(row(a.name, a.hp / (a.maxHp < 1 ? 1.0 : a.maxHp), g.coopKills[a.id] ?? 0, darkomAllyColors[a.slot % darkomAllyColors.length], a.seen && a.dead));
  }
  return Container(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 3),
    decoration: BoxDecoration(color: const Color(0xAA05060A), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text('SQUAD  ${g.kills} kills', style: const TextStyle(color: Color(0xFF69F0AE), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1)),
      const SizedBox(height: 3),
      ...rows,
    ]),
  );
}

Widget _tracker(DarkomLogic g, bool compact) {
  double? frac;
  String right = '';
  String title;
  IconData icon = Icons.flag_rounded;
  Color color = _hudGold;
  if (g.roam) {
    final String ct = g.coop?.args.contract ?? '';
    if (ct.isNotEmpty) {
      title = g.coopContractTitle(ct);
      color = const Color(0xFF69F0AE);
      icon = Icons.assignment_rounded;
      if (g.cpTarget > 0) frac = ct == 'hold' ? g.cpClock / g.cpTarget : g.cpProgress / g.cpTarget;
      if (ct == 'hold') {
        right = '${max(0, g.cpTarget - g.cpClock.floor())} s';
      } else if (ct == 'bounty') {
        right = g.cpResult == 1 ? 'Down' : 'Find it';
      } else {
        right = '${g.cpProgress}/${g.cpTarget}';
      }
    } else {
      title = g.coop != null ? 'City Patrol' : 'Free roam';
      right = 'Wave ${g.wave}';
      icon = Icons.local_fire_department_rounded;
      color = const Color(0xFFFF9100);
    }
  } else if (g.mission != null) {
    final DarkomMission m = g.mission!;
    title = m.title;
    color = m.tierColor;
    if (g.phase == 0) {
      switch (g.cKind) {
        case 'clear':
          if (g.cTarget > 0) { frac = g.cKills / g.cTarget; right = '${g.cKills}/${g.cTarget}'; }
          icon = Icons.whatshot_rounded;
          break;
        case 'collect':
          if (g.cTarget > 0) { frac = g.collected / g.cTarget; right = '${g.collected}/${g.cTarget}'; }
          icon = Icons.memory_rounded;
          break;
        case 'survive':
          if (g.cTarget > 0) { frac = g.cTimer / g.cTarget; right = '${max(0, (g.cTarget - g.cTimer).ceil())} s'; }
          icon = Icons.shield_rounded;
          break;
        case 'recover':
          frac = g.carrying ? 0.6 : 0.2;
          right = g.carrying ? 'Go to the gate' : 'Find the shard';
          icon = Icons.diamond_rounded;
          break;
        case 'escort':
          right = 'Escort';
          icon = Icons.people_alt_rounded;
          break;
        case 'hunt':
          right = 'Hunt';
          icon = Icons.gps_fixed_rounded;
          break;
      }
    }
  } else {
    title = 'Chapter ${g.ch.n}: ${g.ch.name}';
    if (g.cTarget > 0 && g.phase == 0) {
      frac = (g.cKind == 'collect' ? g.collected : g.cKills) / g.cTarget;
      right = g.cKind == 'collect' ? '${g.collected}/${g.cTarget}' : '${g.cKills}/${g.cTarget}';
    }
  }
  final String? dist = g.objectiveDistance;
  final MissionGhost? bestRun = g.mission == null ? null : g.bestRun;
  return Container(
    constraints: BoxConstraints(maxWidth: compact ? 260 : 330),
    padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
    decoration: BoxDecoration(color: const Color(0xB30B0B0F), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.85), width: 1.2)),
    child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Flexible(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12.5, letterSpacing: 0.6))),
        if (right.isNotEmpty) ...<Widget>[
          const SizedBox(width: 10),
          Text(right, style: const TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13)),
        ],
        if (dist != null) ...<Widget>[
          const SizedBox(width: 10),
          const Icon(Icons.navigation_rounded, color: Colors.white54, size: 12),
          const SizedBox(width: 2),
          Text(dist, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11.5)),
        ],
      ]),
      if (frac != null) ...<Widget>[
        const SizedBox(height: 5),
        _bar(compact ? 200 : 260, 6, frac, color),
      ],
      if (g.mission != null) ...<Widget>[
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          if (bestRun != null) ...<Widget>[
            const Icon(Icons.directions_run_rounded, color: _hudCyan, size: 12),
            const SizedBox(width: 3),
            Text('Best ${bestRun.seconds.round() ~/ 60}:${(bestRun.seconds.round() % 60).toString().padLeft(2, '0')}', style: const TextStyle(color: _hudCyan, fontSize: 10.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
          ],
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(i < g.lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 12, color: i < g.lives ? _hudRed : Colors.white24),
            ),
        ]),
      ],
    ]),
  );
}

/// The corner minimap. Tap it to open it large, tap again to shrink it. It
/// never pauses the game, so it is semi transparent when open.
class _MapBox extends StatefulWidget {
  final DarkomLogic g;
  final bool compact;
  final double screenW;
  final double screenH;
  const _MapBox({required this.g, required this.compact, required this.screenW, required this.screenH});

  @override
  State<_MapBox> createState() => _MapBoxState();
}

class _MapBoxState extends State<_MapBox> {
  bool _big = false;

  @override
  Widget build(BuildContext context) {
    final bool c = widget.compact;
    final double ratio = widget.g.world.height / widget.g.world.width;
    double w = c ? 112 : 140;
    if (_big) {
      final double maxW = min(widget.screenW * 0.5, 320.0);
      final double maxH = widget.screenH * (c ? 0.62 : 0.4);
      w = min(maxW, maxH / ratio);
    }
    final double h = w * ratio;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _big = !_big),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: <Widget>[
        Opacity(opacity: _big ? 0.92 : 1.0, child: _miniMap(widget.g, w, h)),
        const SizedBox(height: 3),
        Text(_big ? 'Tap to shrink' : 'Tap for big map', style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600)),
        if (_big) ...<Widget>[
          const SizedBox(height: 2),
          const Text('Gold flag: goal   Gold ring: terminal   Red: enemy   Green: ally', style: TextStyle(color: Colors.white54, fontSize: 9)),
        ],
      ]),
    );
  }
}

Widget _miniMap(DarkomLogic g, double w, double h) {
  return Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: const Color(0xAA05060A), borderRadius: BorderRadius.circular(8), border: Border.all(color: g.theme.neonA.withValues(alpha: 0.7), width: 1.5)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CustomPaint(size: Size(w, h), painter: DarkomMiniPainter(g)),
    ),
  );
}

Widget _toastCard(DToast t, double w) {
  final Color c = Color(t.colorValue);
  return Container(
    width: w,
    padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
    decoration: BoxDecoration(color: const Color(0xDD0B0B12), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: c, width: 4), top: const BorderSide(color: Colors.white12), right: const BorderSide(color: Colors.white12), bottom: const BorderSide(color: Colors.white12))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.25), border: Border.all(color: c, width: 1.5)),
        child: Text(t.who.isEmpty ? '?' : t.who[0].toUpperCase(), style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(t.who, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(t.text, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, height: 1.3, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]),
  );
}

Widget _swapCard(DarkomLogic g, VoidCallback refresh, bool compact) {
  final double art = compact ? 44 : 72;
  final String wk = g.weapon;
  final DarkomWeaponDef d = darkomWeapon(wk);
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      g.onAction(3);
      refresh();
    },
    child: Container(
      width: compact ? 62 : 96,
      padding: EdgeInsets.fromLTRB(4, 4, 4, compact ? 4 : 6),
      decoration: BoxDecoration(color: const Color(0xAA000000), borderRadius: BorderRadius.circular(16), border: Border.all(color: (g.armory.glowFor(wk) ?? const Color(0xFF8A96AD)).withValues(alpha: 0.8), width: 1.5)),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        SizedBox(
          width: art,
          height: art,
          child: WeaponArt(key: ValueKey<String>('dk_$wk${g.armory.skinNameFor(wk)}'), asset: g.armory.assetFor(wk), size: art, rarity: g.armory.rarityFor(wk)),
        ),
        Text(d.name.toUpperCase(), maxLines: 1, style: TextStyle(color: Colors.white, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: compact ? 10 : 12, letterSpacing: 1)),
        if (!compact) Text(g.armory.skinNameFor(wk), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          for (int i = 0; i < darkomWeaponKinds.length; i++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(shape: BoxShape.circle, color: i == g.weaponIdx ? _hudGold : Colors.white24),
            ),
        ]),
      ]),
    ),
  );
}

/// The corner minimap: walls, you, enemies as dots and the target as a flag.
class DarkomMiniPainter extends CustomPainter {
  final DarkomLogic g;
  DarkomMiniPainter(this.g);

  @override
  bool shouldRepaint(covariant DarkomMiniPainter old) => true;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / g.world.width;
    final double sy = size.height / g.world.height;
    final Paint p = Paint();
    final DarkomTheme th = g.theme;
    canvas.drawRect(Offset.zero & size, p..color = th.ground);
    final DarkomWorld w = g.world;
    if (w.waterRow > 0) {
      canvas.drawRect(Rect.fromLTRB(60 * sx, w.waterRow * 60 * sy, (g.world.width - 60) * sx, (g.world.height - 60) * sy), p..color = th.water);
    }
    for (final DBlock b in w.blocks) {
      final Rect r = Rect.fromLTWH(b.tx * 60 * sx, b.ty * 60 * sy, b.tw * 60 * sx, b.th * 60 * sy);
      p.color = b.style == 0 || b.style == 4 ? th.roofEdge.withValues(alpha: 0.85) : th.cover.withValues(alpha: 0.7);
      canvas.drawRect(r, p);
    }
    // arena
    final Paint s = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _hudCyan.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(w.arena.dx * sx, w.arena.dy * sy), 7, s);
    // enemies
    for (final DEnemy e in g.enemies) {
      if (!e.alive) continue;
      p.color = e.type == 'echo' ? _hudCyan : (e.bounty ? const Color(0xFFFF1744) : const Color(0xFFFF8A80));
      canvas.drawCircle(Offset(e.x * sx, e.y * sy), e.bounty || e.type == 'echo' ? 3.2 : 1.8, p);
    }
    final DCourier? c = g.courier;
    if (c != null) {
      canvas.drawCircle(Offset(c.x * sx, c.y * sy), 2.6, p..color = const Color(0xFF69F0AE));
    }
    // target flag
    final Offset? t = g.targetPoint;
    if (t != null) {
      final double fx = t.dx * sx;
      final double fy = t.dy * sy;
      canvas.drawLine(Offset(fx, fy), Offset(fx, fy - 11), s..color = _hudGold..strokeWidth = 1.6);
      final Path flag = Path()
        ..moveTo(fx, fy - 11)
        ..lineTo(fx + 7, fy - 8.5)
        ..lineTo(fx, fy - 6)
        ..close();
      canvas.drawPath(flag, p..color = _hudGold);
    }
    for (int i = 0; i < g.world.pads.length; i++) {
      final Offset pd = Offset(g.world.pads[i].dx * sx, g.world.pads[i].dy * sy);
      if (g.padSeen.contains(i)) {
        canvas.drawCircle(pd, 4.2, p..color = _hudGold);
        canvas.drawCircle(pd, 1.6, p..color = const Color(0xFF05060A));
      } else {
        canvas.drawCircle(pd, 4.2, s..color = _hudGold.withValues(alpha: 0.8)..strokeWidth = 1.4);
      }
    }
    for (int i = 0; i < g.cpNodes.length; i++) {
      if (g.cpTaken.contains(i)) continue;
      canvas.drawRect(Rect.fromCenter(center: Offset(g.cpNodes[i].dx * sx, g.cpNodes[i].dy * sy), width: 5, height: 5), p..color = _hudGold);
    }
    final DarkomCoop? cp = g.coop;
    if (cp != null) {
      for (final DAlly a in cp.allies.values) {
        if (!a.alive) continue;
        canvas.drawCircle(Offset(a.x * sx, a.y * sy), 3.0, p..color = darkomAllyColors[a.slot % darkomAllyColors.length]);
      }
    }
    // you
    final double hx = g.hx * sx;
    final double hy = g.hy * sy;
    canvas.drawCircle(Offset(hx, hy), 3.4, p..color = Colors.white);
    canvas.drawLine(Offset(hx, hy), Offset(hx + cos(g.hFace) * 7, hy + sin(g.hFace) * 7), s..color = Colors.white..strokeWidth = 1.4);
  }
}


/// The equipped finisher plays once when a mission is cleared, and an equipped
/// emote can be played from a small button. Cosmetic only.
class _MissionFx extends StatefulWidget {
  final bool compact;
  const _MissionFx({super.key, required this.compact});

  @override
  State<_MissionFx> createState() => _MissionFxState();
}

class _MissionFxState extends State<_MissionFx> {
  bool _fin = true;
  int _emote = 0;
  bool _emoting = false;

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? loadout = CosmeticsService.myLoadout.value;
    final Map<String, dynamic>? fin = CosmeticsService.artOf(loadout, 'finisher');
    final Map<String, dynamic>? emo = CosmeticsService.artOf(loadout, 'emote');
    return Stack(children: <Widget>[
      if (fin != null && _fin)
        Positioned.fill(
          child: FinisherOverlay(
            kind: fin['kind']?.toString() ?? 'shockwave',
            color: artColor(fin),
            color2: artColor2(fin, Colors.white),
            onDone: () { if (mounted) setState(() => _fin = false); },
          ),
        ),
      if (emo != null)
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.compact ? 10 : 36,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            if (_emoting)
              EmoteBurst(
                key: ValueKey<int>(_emote),
                kind: emo['kind']?.toString() ?? 'gg',
                color: artColor(emo),
                size: widget.compact ? 54 : 72,
                onDone: () { if (mounted) setState(() => _emoting = false); },
              ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() { _emote++; _emoting = true; }),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54, border: Border.all(color: artColor(emo), width: 1.6)),
                child: Padding(padding: const EdgeInsets.all(5), child: CustomPaint(painter: EmotePainter(kind: emo['kind']?.toString() ?? 'gg', color: artColor(emo), t: 0.25))),
              ),
            ),
          ]),
        ),
    ]);
  }
}
