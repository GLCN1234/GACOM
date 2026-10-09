import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../../shared/widgets/cosmetic_avatar.dart';
import '../../shared/widgets/weapon_art.dart';
import '../edu/realms/realm_kit.dart';
import 'darkom_entities.dart';
import 'darkom_logic.dart';
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
      Positioned(right: 10, top: compact ? 54 : 132, child: IgnorePointer(child: _miniMap(g, compact))),
      if (toast != null) Positioned(left: 10, bottom: compact ? 10 : 24, child: IgnorePointer(child: _toastCard(toast, toastW))),
      Positioned(right: compact ? 144 : 96, bottom: compact ? 8 : 22, child: _swapCard(g, refresh, compact)),
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

Widget _miniMap(DarkomLogic g, bool compact) {
  final double w = compact ? 84 : 112;
  final double h = compact ? 63 : 84;
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
    final double sx = size.width / DarkomWorld.width;
    final double sy = size.height / DarkomWorld.height;
    final Paint p = Paint();
    final DarkomTheme th = g.theme;
    canvas.drawRect(Offset.zero & size, p..color = th.ground);
    final DarkomWorld w = g.world;
    if (w.waterRow > 0) {
      canvas.drawRect(Rect.fromLTRB(60 * sx, w.waterRow * 60 * sy, (DarkomWorld.width - 60) * sx, (DarkomWorld.height - 60) * sy), p..color = th.water);
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
    // you
    final double hx = g.hx * sx;
    final double hy = g.hy * sy;
    canvas.drawCircle(Offset(hx, hy), 3.4, p..color = Colors.white);
    canvas.drawLine(Offset(hx, hy), Offset(hx + cos(g.hFace) * 7, hy + sin(g.hFace) * 7), s..color = Colors.white..strokeWidth = 1.4);
  }
}
