import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = SupabaseService.currentUser?.email ?? 'gamer@gacom.gg';

    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          // ── Profile summary card ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: GacomDecorations.neonCard(radius: 20),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: GacomColors.orangeGradient,
                  shape: BoxShape.circle,
                ),
                child: const Center(child: Icon(Icons.person_rounded, color: Colors.white, size: 28)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Account', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
                Text(email, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: GacomColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: GacomColors.success.withOpacity(0.3)),
                ),
                child: const Text('ACTIVE', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 10, color: GacomColors.success, letterSpacing: 0.8)),
              ),
            ]),
          ).animate().fadeIn().slideY(begin: 0.1, end: 0),

          const SizedBox(height: 24),

          // ── Account ──────────────────────────────────────────────────────
          _SectionLabel('ACCOUNT'),
          _SettingsGroup([
            _Tile(icon: Icons.person_outline_rounded, label: 'Edit Profile', onTap: () => GacomSnackbar.show(context, 'Edit profile coming soon')),
            _Tile(icon: Icons.alternate_email_rounded, label: 'Change Username', onTap: () => GacomSnackbar.show(context, 'Coming soon')),
            _Tile(icon: Icons.lock_outline_rounded, label: 'Change Password', onTap: () => GacomSnackbar.show(context, 'Coming soon')),
            _Tile(icon: Icons.mail_outline_rounded, label: 'Email', subtitle: email, onTap: () {}),
          ]).animate(delay: 60.ms).fadeIn(),

          const SizedBox(height: 20),

          // ── Verification ─────────────────────────────────────────────────
          _SectionLabel('VERIFICATION'),
          _VerificationCard(context: context).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 20),

          // ── Gaming ───────────────────────────────────────────────────────
          _SectionLabel('GAMING'),
          _SettingsGroup([
            _Tile(icon: Icons.sports_esports_rounded, label: 'Gamer Tag', subtitle: 'Update your in-game identity', onTap: () => GacomSnackbar.show(context, 'Coming soon')),
            _Tile(icon: Icons.emoji_events_rounded, label: 'My Competitions', onTap: () => context.go(AppConstants.competitionsRoute)),
            _Tile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet & Payments', onTap: () => context.go(AppConstants.walletRoute)),
            _Tile(icon: Icons.account_balance_outlined, label: 'Bank Accounts', subtitle: 'For withdrawals', onTap: () => GacomSnackbar.show(context, 'Coming soon')),
          ]).animate(delay: 140.ms).fadeIn(),

          const SizedBox(height: 20),

          // ── Preferences ──────────────────────────────────────────────────
          _SectionLabel('PREFERENCES'),
          _SettingsGroup([
            _Tile(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
            _Tile(icon: Icons.privacy_tip_outlined, label: 'Privacy & Safety', onTap: () {}),
            _Tile(icon: Icons.language_rounded, label: 'Language', subtitle: 'English', onTap: () {}),
            _Tile(icon: Icons.dark_mode_outlined, label: 'Appearance', subtitle: 'Dark Mode', onTap: () {}),
          ]).animate(delay: 180.ms).fadeIn(),

          const SizedBox(height: 20),

          // ── Support ──────────────────────────────────────────────────────
          _SectionLabel('SUPPORT'),
          _SettingsGroup([
            _Tile(icon: Icons.help_outline_rounded, label: 'Help Center', onTap: () {}),
            _Tile(icon: Icons.bug_report_outlined, label: 'Report a Bug', onTap: () {}),
            _Tile(icon: Icons.campaign_outlined, label: 'Advertise on Gacom', onTap: () => context.go('/ads')),
            _Tile(icon: Icons.info_outline_rounded, label: 'About Gacom', subtitle: 'Version 1.0.0', onTap: () {}),
          ]).animate(delay: 220.ms).fadeIn(),

          const SizedBox(height: 20),

          // ── Danger Zone ──────────────────────────────────────────────────
          _SectionLabel('DANGER ZONE'),
          _SettingsGroup([
            _Tile(
              icon: Icons.logout_rounded,
              label: 'Sign Out',
              isDestructive: true,
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go(AppConstants.loginRoute);
              },
            ),
            _Tile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Account',
              isDestructive: true,
              onTap: () => GacomSnackbar.show(context, 'Contact support@gacom.gg to delete your account', isError: false),
            ),
          ]).animate(delay: 260.ms).fadeIn(),
        ],
      ),
    );
  }
}

// ── Verification card ─────────────────────────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  final BuildContext context;
  const _VerificationCard({required this.context});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: GacomColors.cardDark,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GacomColors.warning.withOpacity(0.3), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GacomColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_outlined, color: GacomColors.warning, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Get Verified', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 16, color: GacomColors.textPrimary)),
            Text('Stand out with a verified badge', style: TextStyle(color: GacomColors.textMuted, fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: GacomColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Text('₦2,000', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.warning)),
          ),
        ]),
        const SizedBox(height: 14),
        const _VerifyPerk(icon: Icons.check_circle_rounded, text: 'Orange verified badge on your profile'),
        const _VerifyPerk(icon: Icons.check_circle_rounded, text: 'Priority in search results'),
        const _VerifyPerk(icon: Icons.check_circle_rounded, text: 'Access to exclusive verified tournaments'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => GacomSnackbar.show(context, 'Verification flow coming soon'),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: GacomColors.warning.withOpacity(0.12),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: GacomColors.warning.withOpacity(0.4)),
            ),
            child: const Center(
              child: Text('APPLY FOR VERIFICATION',
                  style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 13, color: GacomColors.warning, letterSpacing: 1.2)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _VerifyPerk extends StatelessWidget {
  final IconData icon; final String text;
  const _VerifyPerk({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: GacomColors.success),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: GacomColors.textSecondary, fontSize: 12))),
    ]),
  );
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text, style: const TextStyle(
      fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11,
      color: GacomColors.textMuted, letterSpacing: 2,
    )),
  );
}

// ── Settings group ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<Widget> tiles;
  const _SettingsGroup(this.tiles);
  @override
  Widget build(BuildContext context) => Container(
    decoration: GacomDecorations.glassCard(radius: 18),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: List.generate(tiles.length * 2 - 1, (i) {
          if (i.isOdd) {
            return const Divider(height: 0, indent: 52, color: GacomColors.border);
          }
          return tiles[i ~/ 2];
        }),
      ),
    ),
  );
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? GacomColors.error : GacomColors.textPrimary;
    final iconColor = isDestructive ? GacomColors.error : GacomColors.deepOrange;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 15, color: color)),
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(color: GacomColors.textMuted, fontSize: 11)),
          ])),
          Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted, size: 18),
        ]),
      ),
    );
  }
}
