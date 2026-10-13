import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'darkom_entities.dart';
import 'darkom_logic.dart';
import 'darkom_missions.dart';
import 'darkom_story.dart';

/// Open City terminals: one per quarter. Each is a mission giver and a fast
/// travel point. A terminal you have not reached yet cannot be travelled to,
/// so the first trip between quarters is still on foot.

const List<String> darkomGiverNames = <String>['Mira Vale', 'Old Dozer', 'Sable', 'Kilo'];

/// Mission district number (1 to 5) that each city quarter offers, in the
/// order neon, rustyard, spire, grid.
const List<int> darkomQuarterDistrict = <int>[1, 2, 4, 5];

const String _kPadKey = 'darkom_terminals_seen_v1';

extension DarkomCityLogic on DarkomLogic {
  bool get hasTerminals => world.pads.length == 4;

  int cityQuarterOf(double x, double y) {
    final int i = world.quarters.indexOf(world.districtAt(x, y));
    return i < 0 ? 0 : i;
  }

  String cityQuarterName(int i) => darkomTheme(world.quarters[i]).name;

  void cityInit() {
    if (!this.hasTerminals) return;
    padSeen.add(this.cityQuarterOf(hx, hy));
    SharedPreferences.getInstance().then((SharedPreferences p) {
      final String raw = p.getString(_kPadKey) ?? '';
      for (final String s in raw.split(',')) {
        final int? v = int.tryParse(s);
        if (v != null && v >= 0 && v < 4) padSeen.add(v);
      }
    }, onError: (Object _) {});
  }

  void _citySave() {
    SharedPreferences.getInstance().then((SharedPreferences p) {
      p.setString(_kPadKey, padSeen.join(','));
    }, onError: (Object _) {});
  }

  void cityTick(double dt) {
    if (!this.hasTerminals) return;
    if (travelCd > 0) travelCd -= dt;
    if (travelMsgT > 0) travelMsgT -= dt;
    if (heroDead) {
      padNear = -1;
      return;
    }
    int near = -1;
    for (int i = 0; i < 4; i++) {
      final double d = (world.pads[i] - heroPos).distance;
      if (d < 150 && padSeen.add(i)) {
        _citySave();
        showBanner('TERMINAL FOUND: ${this.cityQuarterName(i).toUpperCase()}', const Color(0xFFFFD54F), dur: 1.8);
      }
      if (d < 95) near = i;
    }
    padNear = near;
  }

  /// Why travel is not possible right now, or null if it is.
  String? cityTravelBlock() {
    if (travelCd > 0) return 'Terminal recharging';
    for (final DEnemy e in enemies) {
      if (!e.alive || !e.aggro) continue;
      final double dx = e.x - hx;
      final double dy = e.y - hy;
      if (dx * dx + dy * dy < 450 * 450) return 'Hostiles too close';
    }
    return null;
  }

  bool cityTravel(int to) {
    if (!this.hasTerminals || to < 0 || to > 3 || !padSeen.contains(to)) return false;
    final String? block = this.cityTravelBlock();
    if (block != null) {
      travelMsg = block;
      travelMsgT = 2.0;
      return false;
    }
    final Offset p = world.pads[to];
    ringFx(hx, hy, 90, const Color(0xFF00E5FF), life: 0.4);
    hx = p.dx;
    hy = p.dy + 46;
    if (world.circleHits(hx, hy, darkomHeroRadius)) {
      hx = p.dx;
      hy = p.dy;
    }
    camX = hx;
    camY = hy;
    kvx = 0;
    kvy = 0;
    invuln = max(invuln, 1.4);
    travelCd = 6;
    checkpoint = Offset(hx, hy);
    projs.removeWhere((DProj pr) => pr.hostile);
    ringFx(hx, hy, 110, const Color(0xFF00E5FF), life: 0.5);
    flashFx(hx, hy, 70, Colors.white, life: 0.25);
    cues.add('win');
    showBanner('ARRIVED: ${this.cityQuarterName(to).toUpperCase()}', const Color(0xFF00E5FF), dur: 1.6);
    return true;
  }

  /// Up to three open, not yet cleared missions this quarter's giver offers.
  List<DarkomMission> cityMissionsFor(int quarter) {
    final int d = darkomQuarterDistrict[quarter < 0 || quarter > 3 ? 0 : quarter];
    final List<DarkomMission> out = <DarkomMission>[];
    for (final DarkomMission m in darkomMissionsIn(d)) {
      if (!m.isOpen(boot.progress.chapter) || boot.cleared.contains(m.id)) continue;
      out.add(m);
      if (out.length >= 3) break;
    }
    return out;
  }
}
