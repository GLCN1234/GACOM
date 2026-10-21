import 'package:flutter/material.dart';
import '../../core/services/cosmetics_service.dart';
import '../../features/edu/realms/realm_kit.dart' show RealmDraw;
import 'cosmetic_art.dart';
import 'cosmetic_avatar.dart';
import 'rarity.dart';
import 'weapon_art.dart';

/// Thumbnail of one catalogue item, picked by its category. Shared by the
/// shop and the locker.
class CosmeticItemVisual extends StatelessWidget {
  final Map<String, dynamic> item;
  final double scale;
  const CosmeticItemVisual({super.key, required this.item, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final String? cat = item['category']?.toString();
    final Rarity rarity = Rarity.parse(item['rarity']?.toString());
    final Map<String, dynamic> asset = item['asset'] is Map ? Map<String, dynamic>.from(item['asset'] as Map) : <String, dynamic>{};
    final double k = scale;
    switch (cat) {
      case 'name_color':
        final Color col = CosmeticsService.parseColor(item['value']?.toString()) ?? Tac.text;
        return Text('Aa', style: Tac.display(size: 30 * k, weight: FontWeight.w800, color: col, letter: 0));
      case 'badge':
        return Icon(CosmeticsService.iconForBadge(item['value']?.toString()) ?? Icons.star_outline_rounded, size: 38 * k, color: rarity.color);
      case 'avatar_frame':
        return CosmeticAvatar(radius: 24 * k, name: 'G', frameItem: item);
      case 'hero_outfit':
        return SizedBox(
          width: 70 * k,
          height: 80 * k,
          child: CustomPaint(painter: CosmeticFigurePainter(outfit: asset, trail: const <String, dynamic>{}, scale: 1.5 * k, phase: 0, moving: false)),
        );
      case 'trail':
        return SizedBox(
          width: 110 * k,
          height: 70 * k,
          child: CustomPaint(painter: CosmeticFigurePainter(outfit: const <String, dynamic>{}, trail: asset, scale: 1.1 * k, phase: 6.0, moving: true, dx: 0.7)),
        );
      case 'profile_banner':
        return ProfileBanner(
          bannerItem: item,
          height: 56 * k,
          fallback: const Center(child: Icon(Icons.block_rounded, size: 24, color: Tac.textDim)),
        );
      case 'weapon_skin':
        return WeaponArt(asset: asset, size: 84 * k, rarity: rarity);
      case 'emote':
      case 'spray':
      case 'finisher':
        return cosmeticArtThumb(cat!, asset, scale: k);
      case 'okada':
      case 'siege':
      case 'current':
      case 'pitch':
      case 'market':
        return GameKitSwatch(category: cat!, asset: asset, scale: k, rarity: rarity);
      case 'title':
        final String t = (item['value']?.toString() ?? item['name']?.toString() ?? '').toUpperCase();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(t, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Tac.display(size: 13 * k, weight: FontWeight.w800, color: rarity == Rarity.common ? Tac.gold : rarity.color, letter: 1.2)),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// A kit for one of the GACOM Edu games, shown as the colours it actually
/// paints into that game plus the game's own icon. A kit does not change the
/// avatar, so there is nothing to show on the character stage: this swatch is
/// the preview.
class GameKitSwatch extends StatelessWidget {
  const GameKitSwatch({super.key, required this.category, required this.asset, this.scale = 1.0, this.rarity = Rarity.common});

  final String category;
  final Map<String, dynamic> asset;
  final double scale;
  final Rarity rarity;

  /// The asset keys worth showing for each game, biggest area first.
  static const Map<String, List<String>> _keys = <String, List<String>>{
    'okada': <String>['road', 'bike', 'helmet', 'accent'],
    'siege': <String>['wall', 'banner', 'marcher', 'accent'],
    'current': <String>['water', 'tile', 'swimmer', 'accent'],
    'pitch': <String>['grass', 'kit', 'ball', 'accent'],
    'market': <String>['ground', 'canopy', 'canopy_alt', 'counter'],
  };

  static const Map<String, IconData> _icons = <String, IconData>{
    'okada': Icons.two_wheeler_rounded,
    'siege': Icons.shield_rounded,
    'current': Icons.waves_rounded,
    'pitch': Icons.sports_soccer_rounded,
    'market': Icons.storefront_rounded,
  };

  /// The one style word a kit carries, if it has one.
  static const Map<String, String> _styleKey = <String, String>{
    'okada': 'exhaust',
    'siege': 'style',
    'current': 'surface',
    'pitch': 'pattern',
    'market': 'cloth',
  };

  @override
  Widget build(BuildContext context) {
    final List<String> keys = _keys[category] ?? const <String>['accent'];
    final List<Color> colors = <Color>[];
    for (final String key in keys) {
      final Color? c = CosmeticsService.parseColor(asset[key]?.toString());
      if (c != null) colors.add(c);
    }
    while (colors.length < 2) {
      colors.add(rarity.color);
    }
    final String style = asset[_styleKey[category] ?? '']?.toString() ?? '';
    final double w = 92 * scale;
    final double h = 64 * scale;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10 * scale),
        child: Stack(fit: StackFit.expand, children: <Widget>[
          Row(
            children: <Widget>[
              for (int i = 0; i < colors.length; i++)
                Expanded(flex: i == 0 ? 3 : 2, child: ColoredBox(color: colors[i])),
            ],
          ),
          Center(
            child: Icon(
              _icons[category] ?? Icons.sports_esports_rounded,
              size: 28 * scale,
              color: Colors.white,
              shadows: const <Shadow>[Shadow(color: Colors.black87, blurRadius: 6)],
            ),
          ),
          if (style.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ColoredBox(
                color: Colors.black54,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 2 * scale),
                  child: Text(
                    style.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 8.5 * scale, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Draws the hero with a given outfit and trail (asset json), independent of
/// what is currently equipped.
class CosmeticFigurePainter extends CustomPainter {
  final Map<String, dynamic> outfit;
  final Map<String, dynamic> trail;
  final double scale;
  final double phase;
  final bool moving;
  final double dx; // horizontal position as a fraction of the width

  const CosmeticFigurePainter({required this.outfit, required this.trail, required this.scale, required this.phase, required this.moving, this.dx = 0.5});

  Color _c(Map<String, dynamic> m, String k, Color d) => CosmeticsService.parseColor(m[k]?.toString()) ?? d;

  @override
  void paint(Canvas canvas, Size size) {
    final double x = size.width * dx;
    final double y = size.height / 2 - 4;
    final String kind = trail['kind']?.toString() ?? 'none';
    if (moving && kind != 'none') {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale, scale);
      paintCosmeticTrail(canvas, kind, _c(trail, 'color', const Color(0xFFFFF176)), phase, 1.0);
      canvas.restore();
    }
    RealmDraw.person(
      canvas,
      x,
      y,
      phase: phase,
      moving: moving,
      facing: 1,
      shirt: _c(outfit, 'shirt', const Color(0xFFFF6A00)),
      pants: _c(outfit, 'pants', const Color(0xFF2A3A63)),
      skin: _c(outfit, 'skin', const Color(0xFFF2B785)),
      hair: _c(outfit, 'hair', const Color(0xFF2B1B12)),
      hairStyle: outfit['hair_style']?.toString() ?? 'low',
      scale: scale,
    );
  }

  @override
  bool shouldRepaint(covariant CosmeticFigurePainter old) =>
      old.phase != phase || old.outfit != outfit || old.trail != trail || old.scale != scale || old.moving != moving;
}

/// Character stage: banner, framed avatar, coloured name with badge and
/// title, and an animated hero wearing the outfit and trail. [items] maps a
/// category to an item map (the same shape as an equipped row).
class LoadoutStage extends StatefulWidget {
  final Map<String, dynamic> items;
  final String name;
  final String? avatarUrl;
  final double height;
  const LoadoutStage({super.key, required this.items, required this.name, this.avatarUrl, this.height = 150});

  @override
  State<LoadoutStage> createState() => _LoadoutStageState();
}

class _LoadoutStageState extends State<LoadoutStage> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  int _play = 0; // bumped on tap to replay the emote and finisher
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _asset(String key) {
    final dynamic v = widget.items[key];
    final dynamic a = v is Map ? v['asset'] : null;
    return a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final Color nameColor = CosmeticsService.nameColorFor(widget.items) ?? Tac.text;
    final IconData? badge = CosmeticsService.badgeFor(widget.items);
    final String shown = widget.name.isEmpty ? 'You' : widget.name;
    final Rarity? frameRarity = cosmeticFrameRarity(equipped: widget.items);
    final Color line = (frameRarity != null && frameRarity != Rarity.common) ? frameRarity.color : Tac.gold;
    const ChamferedBorder clipShape = ChamferedBorder(cut: 18, tl: true, tr: false, br: true, bl: false);
    final Map<String, dynamic>? emoteArt = CosmeticsService.artOf(widget.items, 'emote');
    final Map<String, dynamic>? sprayArt = CosmeticsService.artOf(widget.items, 'spray');
    final Map<String, dynamic>? finArt = CosmeticsService.artOf(widget.items, 'finisher');
    final bool canPlay = emoteArt != null || finArt != null;
    return GestureDetector(
      onTap: canPlay ? () => setState(() { _play++; _playing = true; }) : null,
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      height: widget.height,
      foregroundDecoration: ShapeDecoration(shape: ChamferedBorder(cut: 18, side: BorderSide(color: line.withValues(alpha: 0.75), width: 1.2))),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: clipShape),
        child: Stack(fit: StackFit.expand, children: [
          ProfileBanner(
            equipped: widget.items,
            fallback: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF16213A), Tac.panel2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CosmeticAvatar(radius: 30, avatarUrl: widget.avatarUrl, name: shown, equipped: widget.items),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (badge != null) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(badge, size: 17, color: Tac.gold)),
                    Flexible(
                      child: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tac.display(size: 17, weight: FontWeight.w800, color: nameColor, letter: 0.3)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  TitleText(equipped: widget.items, fontSize: 10),
                ]),
              ),
              SizedBox(
                width: 110,
                height: 120,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _ctl,
                      builder: (_, __) => CustomPaint(
                        painter: CosmeticFigurePainter(outfit: _asset('hero_outfit'), trail: _asset('trail'), scale: 1.6, phase: _ctl.value * 6.283185307 * 14, moving: true, dx: 0.62),
                      ),
                    ),
                  ),
                  if (widget.items['weapon'] is Map)
                    Positioned(right: -16, bottom: 4, child: WeaponArt.fromItem(Map<String, dynamic>.from(widget.items['weapon'] as Map), size: 54)),
                ]),
              ),
            ]),
          ),
          if (sprayArt != null)
            Positioned(right: 6, top: 2, child: Opacity(opacity: 0.85, child: SprayArt(kind: sprayArt['kind']?.toString() ?? 'star', color: artColor(sprayArt), size: 44))),
          if (_playing && finArt != null)
            Positioned.fill(
              child: FinisherOverlay(
                key: ValueKey<String>('fin$_play'),
                kind: finArt['kind']?.toString() ?? 'shockwave',
                color: artColor(finArt),
                color2: artColor2(finArt, Colors.white),
                onDone: () { if (mounted) setState(() => _playing = false); },
              ),
            ),
          if (_playing && emoteArt != null)
            Positioned(
              right: 70,
              top: 8,
              child: EmoteBurst(
                key: ValueKey<String>('emo$_play'),
                kind: emoteArt['kind']?.toString() ?? 'gg',
                color: artColor(emoteArt),
                size: 56,
                onDone: () { if (mounted && finArt == null) setState(() => _playing = false); },
              ),
            ),
          if (canPlay && !_playing)
            Positioned(
              left: 10,
              bottom: 4,
              child: Text('Tap to preview', style: Tac.body(size: 10, color: Colors.white54)),
            ),
        ]),
      ),
    ));
  }
}
