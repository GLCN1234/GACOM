import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/gacom_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          _Tile(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: () {}),
          _Tile(icon: Icons.verified_outlined, title: 'Get Verified', subtitle: 'Verify your identity', onTap: () {}),
          _Tile(icon: Icons.lock_outline_rounded, title: 'Change Password', onTap: () {}),
          _Tile(icon: Icons.account_balance_wallet_outlined, title: 'Bank Accounts', onTap: () {}),
          const _SectionHeader('Preferences'),
          _Tile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),
          _Tile(icon: Icons.privacy_tip_outlined, title: 'Privacy', onTap: () {}),
          _Tile(icon: Icons.language_rounded, title: 'Language', subtitle: 'English', onTap: () {}),
          const _SectionHeader('Support'),
          _Tile(icon: Icons.help_outline_rounded, title: 'Help Center', onTap: () {}),
          _Tile(icon: Icons.bug_report_outlined, title: 'Report a Bug', onTap: () {}),
          _Tile(icon: Icons.info_outline_rounded, title: 'About Gacom', subtitle: 'Version 1.0.0', onTap: () {}),
          const _SectionHeader('Danger Zone'),
          _Tile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            isDestructive: true,
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) context.go(AppConstants.loginRoute);
            },
          ),
          _Tile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete Account',
            isDestructive: true,
            onTap: () => GacomSnackbar.show(context, 'Please contact support to delete your account', isError: false),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w700, fontSize: 12, color: GacomColors.textMuted, letterSpacing: 1.5)),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  const _Tile({required this.icon, required this.title, this.subtitle, required this.onTap, this.isDestructive = false});
  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? GacomColors.error : GacomColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: GacomColors.textMuted, fontSize: 12)) : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted, size: 18),
      onTap: onTap,
    );
  }
}
