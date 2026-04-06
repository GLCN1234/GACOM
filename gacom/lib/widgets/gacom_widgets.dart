import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

// ── Avatar Widget ──────────────────────────────────────────
class GacomAvatar extends StatelessWidget {
  final String? imageUrl;
  final String username;
  final double size;
  final bool isOnline;
  final bool isVerified;

  const GacomAvatar({
    super.key,
    this.imageUrl,
    required this.username,
    this.size = 40,
    this.isOnline = false,
    this.isVerified = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: GacomColors.primary.withOpacity(0.5), width: 2),
            gradient: imageUrl == null ? const LinearGradient(
              colors: [GacomColors.primary, GacomColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
          ),
          child: ClipOval(
            child: imageUrl != null
                ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover,
                    placeholder: (_, __) => _shimmer(), errorWidget: (_, __, ___) => _initials())
                : _initials(),
          ),
        ),
        if (isOnline) Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: size * 0.28,
            height: size * 0.28,
            decoration: BoxDecoration(
              color: GacomColors.online,
              shape: BoxShape.circle,
              border: Border.all(color: GacomColors.background, width: 2),
            ),
          ),
        ),
        if (isVerified) Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: size * 0.32,
            height: size * 0.32,
            decoration: BoxDecoration(color: GacomColors.primary, shape: BoxShape.circle),
            child: Icon(Icons.verified, size: size * 0.2, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _initials() => Center(
    child: Text(
      username.isNotEmpty ? username[0].toUpperCase() : 'G',
      style: GoogleFonts.rajdhani(
        color: Colors.white,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _shimmer() => Shimmer.fromColors(
    baseColor: GacomColors.cardBorder,
    highlightColor: GacomColors.surfaceVariant,
    child: Container(color: GacomColors.cardBorder),
  );
}

// ── Glow Button ────────────────────────────────────────────
class GlowButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final Color? color;
  final IconData? icon;

  const GlowButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? GacomColors.primary;
    return Container(
      width: width,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: btnColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(text, style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

// ── Gacom Card ─────────────────────────────────────────────
class GacomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final double borderRadius;

  const GacomCard({super.key, required this.child, this.padding, this.onTap, this.borderColor, this.borderRadius = 16});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GacomColors.card,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor ?? GacomColors.cardBorder, width: 1),
        ),
        child: child,
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────
class GacomBadge extends StatelessWidget {
  final String text;
  final Color? color;
  final bool filled;

  const GacomBadge({super.key, required this.text, this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? GacomColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c : c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.rajdhani(
          color: filled ? Colors.white : c,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Shimmer Loader ─────────────────────────────────────────
class GacomShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const GacomShimmer({super.key, required this.height, this.width, this.borderRadius = 12});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: GacomColors.cardBorder,
      highlightColor: GacomColors.surfaceVariant,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: GacomColors.cardBorder,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// ── Stat Chip ──────────────────────────────────────────────
class StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? color;

  const StatChip({super.key, required this.icon, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? GacomColors.textMuted),
        const SizedBox(width: 4),
        Text(value, style: GoogleFonts.outfit(color: color ?? GacomColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

// ── Section Header ─────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.rajdhani(color: GacomColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!, style: GoogleFonts.outfit(color: GacomColors.primary, fontSize: 13)),
          ),
      ],
    );
  }
}

// ── Prize Badge ────────────────────────────────────────────
class PrizeBadge extends StatelessWidget {
  final int amount;
  final bool large;

  const PrizeBadge({super.key, required this.amount, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 16 : 10, vertical: large ? 8 : 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: large ? 18 : 14, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            '₦${_formatAmount(amount)}',
            style: GoogleFonts.rajdhani(
              color: Colors.black,
              fontSize: large ? 16 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toString();
  }
}
