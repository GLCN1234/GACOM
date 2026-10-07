import 'package:flutter/material.dart';

class GameLogoData {
  final IconData icon;
  final Color a;
  final Color b;
  const GameLogoData(this.icon, this.a, this.b);
}

/// Built-in logos for GACOM's own Arena games: a coloured gradient tile with a
/// bold glyph. They need no downloads, stay sharp at any size, and take
/// priority over the generic stock photos the store used before.
class GameLogos {
  static const Map<String, GameLogoData> _data = {
    'LUDO': GameLogoData(Icons.casino_rounded, Color(0xFFE53935), Color(0xFFFF8F00)),
    'AYO': GameLogoData(Icons.blur_on_rounded, Color(0xFF6D4C41), Color(0xFFFFB300)),
    'CHECKERS': GameLogoData(Icons.radio_button_checked_rounded, Color(0xFFB71C1C), Color(0xFF212121)),
    'BATTLESHIP': GameLogoData(Icons.directions_boat_rounded, Color(0xFF0D47A1), Color(0xFF00ACC1)),
    'CHESS PUZZLE RUSH': GameLogoData(Icons.bolt_rounded, Color(0xFF283593), Color(0xFFAB47BC)),
    'RUMMY': GameLogoData(Icons.style_rounded, Color(0xFF1B5E20), Color(0xFF66BB6A)),
    'SOLITAIRE': GameLogoData(Icons.view_carousel_rounded, Color(0xFF004D40), Color(0xFF26A69A)),
    'COLOR CLASH': GameLogoData(Icons.palette_rounded, Color(0xFFD81B60), Color(0xFFFFB300)),
    'SUDOKU': GameLogoData(Icons.grid_view_rounded, Color(0xFF3949AB), Color(0xFF29B6F6)),
    'BLOCK DROP': GameLogoData(Icons.view_module_rounded, Color(0xFF6A1B9A), Color(0xFF00E5FF)),
    'BUBBLE SHOOTER': GameLogoData(Icons.bubble_chart_rounded, Color(0xFF00838F), Color(0xFFEC407A)),
    'STACK TOWER': GameLogoData(Icons.layers_rounded, Color(0xFFEF6C00), Color(0xFFFFEE58)),
    'SKY HOPPER': GameLogoData(Icons.flight_rounded, Color(0xFF0288D1), Color(0xFF80DEEA)),
    'DASH RUNNER': GameLogoData(Icons.directions_run_rounded, Color(0xFFFF6F00), Color(0xFFD50000)),
    'STAR BLASTER': GameLogoData(Icons.rocket_launch_rounded, Color(0xFF1A237E), Color(0xFF7C4DFF)),
    'TARGET GALLERY': GameLogoData(Icons.gps_fixed_rounded, Color(0xFFC62828), Color(0xFFFF7043)),
    'FRUIT SLICE': GameLogoData(Icons.content_cut_rounded, Color(0xFF2E7D32), Color(0xFFFF7043)),
    'BASKETBALL SHOOTOUT': GameLogoData(Icons.sports_basketball_rounded, Color(0xFFE65100), Color(0xFF5D4037)),
    'BASKETBALL': GameLogoData(Icons.sports_basketball_rounded, Color(0xFFE65100), Color(0xFF5D4037)),
    'DARTS': GameLogoData(Icons.adjust_rounded, Color(0xFF2E7D32), Color(0xFFC62828)),
    'AIR HOCKEY': GameLogoData(Icons.sports_hockey_rounded, Color(0xFF0277BD), Color(0xFF26C6DA)),
    '8-BALL POOL': GameLogoData(Icons.album_rounded, Color(0xFF004D40), Color(0xFF111111)),
    'PINBALL': GameLogoData(Icons.blur_circular_rounded, Color(0xFF4A148C), Color(0xFFFF4081)),
    'TOWER DEFENSE': GameLogoData(Icons.castle_rounded, Color(0xFF37474F), Color(0xFF66BB6A)),
    'MINI CROSSWORD': GameLogoData(Icons.grid_on_rounded, Color(0xFF1565C0), Color(0xFFFFCA28)),
    'JIGSAW PUZZLE': GameLogoData(Icons.extension_rounded, Color(0xFF00897B), Color(0xFF7E57C2)),
    'CONNECT FOUR': GameLogoData(Icons.grid_4x4_rounded, Color(0xFF1565C0), Color(0xFFFFD600)),
    'REVERSI': GameLogoData(Icons.filter_none_rounded, Color(0xFF263238), Color(0xFF78909C)),
    'MEMORY MATCH': GameLogoData(Icons.psychology_rounded, Color(0xFF7B1FA2), Color(0xFFF06292)),
    'WORD SCRAMBLE': GameLogoData(Icons.sort_by_alpha_rounded, Color(0xFF00695C), Color(0xFF9CCC65)),
    '2048': GameLogoData(Icons.apps_rounded, Color(0xFFEF6C00), Color(0xFFFFCA28)),
    'HANGMAN': GameLogoData(Icons.abc_rounded, Color(0xFF4E342E), Color(0xFFA1887F)),
    'SPEED MATH': GameLogoData(Icons.calculate_rounded, Color(0xFF1565C0), Color(0xFF26C6DA)),
    'SIMON SAYS': GameLogoData(Icons.music_note_rounded, Color(0xFFD81B60), Color(0xFF7C4DFF)),
    'MINESWEEPER': GameLogoData(Icons.flag_rounded, Color(0xFF455A64), Color(0xFFE53935)),
    'BLACKJACK': GameLogoData(Icons.style_rounded, Color(0xFF1B5E20), Color(0xFF212121)),
    'DOTS AND BOXES': GameLogoData(Icons.dialpad_rounded, Color(0xFF3949AB), Color(0xFFEC407A)),
    'NUMBER DUEL': GameLogoData(Icons.speed_rounded, Color(0xFF00838F), Color(0xFFFFB300)),
    'SNAKE': GameLogoData(Icons.timeline_rounded, Color(0xFF2E7D32), Color(0xFFCDDC39)),
    'WHOT': GameLogoData(Icons.casino_rounded, Color(0xFFB71C1C), Color(0xFFFF6F00)),
    'SIGNAL RUN': GameLogoData(Icons.directions_run_rounded, Color(0xFF006064), Color(0xFF00E676)),
    'SIGNAL MATCH': GameLogoData(Icons.hub_rounded, Color(0xFF0D47A1), Color(0xFF00E5FF)),
    'VAULT BREAK': GameLogoData(Icons.lock_rounded, Color(0xFF37474F), Color(0xFFFFB300)),
    'DRONE BREACH': GameLogoData(Icons.satellite_alt_rounded, Color(0xFF212121), Color(0xFFFF6A00)),
    'SURVIVAL SHOOTER': GameLogoData(Icons.track_changes_rounded, Color(0xFF3E2723), Color(0xFFD84315)),
    'VOID PROTOCOLS': GameLogoData(Icons.token_rounded, Color(0xFF1A0033), Color(0xFF8B6BFF)),
    'CHRONO-SPIRE': GameLogoData(Icons.timer_rounded, Color(0xFF4A148C), Color(0xFF00E5FF)),
    'TIC-TAC-TOE': GameLogoData(Icons.close_rounded, Color(0xFF0277BD), Color(0xFF00E5FF)),
    'CHESS': GameLogoData(Icons.extension_rounded, Color(0xFF212121), Color(0xFF8D6E63)),
    'RPS BATTLE': GameLogoData(Icons.back_hand_rounded, Color(0xFFD84315), Color(0xFFFFB300)),
    'TRIVIA': GameLogoData(Icons.quiz_rounded, Color(0xFF6A1B9A), Color(0xFF29B6F6)),
    'REACTION': GameLogoData(Icons.flash_on_rounded, Color(0xFFFFB300), Color(0xFFFF6F00)),
    'COLONY SIEGE': GameLogoData(Icons.shield_rounded, Color(0xFF37474F), Color(0xFF66BB6A)),
    'ASTRA COLONY': GameLogoData(Icons.public_rounded, Color(0xFF1A237E), Color(0xFF00BFA5)),
    'BIOME': GameLogoData(Icons.pets_rounded, Color(0xFF33691E), Color(0xFFCDDC39)),
    'WINDWARD': GameLogoData(Icons.sailing_rounded, Color(0xFF01579B), Color(0xFF4FC3F7)),
    'DELVE': GameLogoData(Icons.flashlight_on_rounded, Color(0xFF1A0033), Color(0xFFFFB300)),
    'CASE FILES': GameLogoData(Icons.manage_search_rounded, Color(0xFF7F0000), Color(0xFFFF8A65)),
    'FRONTIER': GameLogoData(Icons.holiday_village_rounded, Color(0xFFBF360C), Color(0xFFFFCA28)),
    'ODYSSEY': GameLogoData(Icons.explore_rounded, Color(0xFF0D47A1), Color(0xFF00E676)),
    'ARENA GAUNTLET': GameLogoData(Icons.whatshot_rounded, Color(0xFFB71C1C), Color(0xFFFF6A00)),
  };

  static GameLogoData? lookup(String? name) {
    if (name == null) return null;
    final String key = name.trim().toUpperCase();
    final GameLogoData? exact = _data[key];
    if (exact != null) return exact;
    final String flat = _flat(key);
    if (flat.isEmpty) return null;
    for (final MapEntry<String, GameLogoData> e in _data.entries) {
      if (_flat(e.key) == flat) return e.value;
    }
    final String? alias = _aliases[flat];
    return alias == null ? null : _data[alias];
  }

  static String _flat(String s) => s.replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static const Map<String, String> _aliases = {
    'CHRONOSPY': 'CHRONO-SPIRE',
    'CHRONOSPIRES': 'CHRONO-SPIRE',
    'CHRONO': 'CHRONO-SPIRE',
    'VOIDPROTOCOL': 'VOID PROTOCOLS',
    'VOID': 'VOID PROTOCOLS',
  };
}

/// Fills whatever space it is given with the game's logo, or shows [fallback]
/// for games without one (for example third-party store listings).
class GameLogo extends StatelessWidget {
  final String? name;
  final double radius;
  final bool circle;
  final Widget? fallback;
  final Alignment glyphAlignment;
  final double glyphScale;
  final double glyphOpacity;
  const GameLogo({
    super.key,
    required this.name,
    this.radius = 14,
    this.circle = false,
    this.fallback,
    this.glyphAlignment = Alignment.center,
    this.glyphScale = 0.5,
    this.glyphOpacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final data = GameLogos.lookup(name);
    if (data == null) return fallback ?? const SizedBox.shrink();
    final tile = LayoutBuilder(builder: (context, cons) {
      double s = cons.biggest.shortestSide;
      if (s.isInfinite || s <= 0) s = 64;
      final double glyph = s * glyphScale;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [data.a, data.b]),
        ),
        child: Stack(children: [
          Positioned(
            right: -s * 0.18,
            bottom: -s * 0.18,
            child: Container(width: s * 0.62, height: s * 0.62, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.10))),
          ),
          Align(
            alignment: glyphAlignment,
            child: Icon(data.icon, size: glyph, color: Colors.white.withValues(alpha: glyphOpacity), shadows: const [Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))]),
          ),
        ]),
      );
    });
    if (circle) return ClipOval(child: tile);
    if (radius <= 0) return tile;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: tile);
  }
}
