import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/cosmetics_service.dart';
import '../../core/theme/app_theme.dart';

/// Colours of a frame ring from an equipped-row map (see
/// CosmeticsService.equipped) or a catalogue item. Null means no frame.
List<Color>? cosmeticFrameColors({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
  final Map? src = item ?? (equipped?['avatar_frame'] is Map ? equipped!['avatar_frame'] as Map : null);
  if (src == null) return null;
  final asset = src['asset'];
  if (asset is Map && asset['colors'] is List) {
    final cols = <Color>[];
    for (final c in (asset['colors'] as List)) {
      final col = CosmeticsService.parseColor(c?.toString());
      if (col != null) cols.add(col);
    }
    if (cols.isNotEmpty) return cols;
  }
  switch (src['value']?.toString()) {
    case 'bronze': return const [Color(0xFFCD7F32), Color(0xFF8D5524)];
    case 'gold': return const [Color(0xFFFFD700), Color(0xFFFFA000)];
    case 'flame': return const [Color(0xFFFF6D00), Color(0xFFFF1744)];
    default: return null;
  }
}

/// An avatar (photo or initial) with the equipped frame drawn as a ring.
class CosmeticAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final Map<String, dynamic>? equipped;
  /// Use a catalogue item instead of an equipped row (shop previews).
  final Map<String, dynamic>? frameItem;

  const CosmeticAvatar({super.key, this.avatarUrl, this.name = '', this.radius = 20, this.equipped, this.frameItem});

  @override
  Widget build(BuildContext context) {
    final colors = cosmeticFrameColors(equipped: equipped, item: frameItem);
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final initial = name.trim().isEmpty ? 'G' : name.trim()[0].toUpperCase();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: GacomColors.cardDark,
      backgroundImage: hasUrl ? CachedNetworkImageProvider(avatarUrl!) : null,
      onBackgroundImageError: hasUrl ? (e, s) {} : null,
      child: hasUrl ? null : Text(initial, style: TextStyle(color: GacomColors.textPrimary, fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: radius * 0.8)),
    );
    if (colors == null) return avatar;
    final ring = max(2.0, radius * 0.14);
    final gap = max(1.5, radius * 0.07);
    final gradientColors = colors.length == 1 ? [colors[0], colors[0]] : colors;
    return Container(
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [...gradientColors, gradientColors.first]),
        boxShadow: [BoxShadow(color: gradientColors.first.withValues(alpha: 0.35), blurRadius: radius * 0.6)],
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: GacomColors.obsidian),
        child: avatar,
      ),
    );
  }
}

/// A gradient banner from the equipped profile banner. When none is equipped
/// it shows [fallback] (or nothing visible if that is null).
class ProfileBanner extends StatelessWidget {
  final Map<String, dynamic>? equipped;
  final Map<String, dynamic>? bannerItem;
  final double? height;
  final Widget? fallback;
  final Widget? child;
  final BorderRadius? borderRadius;

  const ProfileBanner({super.key, this.equipped, this.bannerItem, this.height, this.fallback, this.child, this.borderRadius});

  /// The two gradient colours, or null when there is no banner.
  static List<Color>? colorsFor({Map<String, dynamic>? equipped, Map<String, dynamic>? item}) {
    final Map? src = item ?? (equipped?['profile_banner'] is Map ? equipped!['profile_banner'] as Map : null);
    final asset = src?['asset'];
    if (asset is! Map) return null;
    final from = CosmeticsService.parseColor(asset['from']?.toString());
    final to = CosmeticsService.parseColor(asset['to']?.toString());
    if (from == null || to == null) return null;
    return [from, to];
  }

  @override
  Widget build(BuildContext context) {
    final cols = colorsFor(equipped: equipped, item: bannerItem);
    if (cols == null) {
      final fb = fallback ?? const SizedBox.shrink();
      return height == null ? fb : SizedBox(height: height, width: double.infinity, child: fb);
    }
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(colors: cols, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _BannerShinePainter()),
        if (child != null) child!,
      ]),
    );
  }
}

class _BannerShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.07);
    final path = Path()
      ..moveTo(size.width * 0.55, 0)
      ..lineTo(size.width * 0.75, 0)
      ..lineTo(size.width * 0.45, size.height)
      ..lineTo(size.width * 0.25, size.height)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
