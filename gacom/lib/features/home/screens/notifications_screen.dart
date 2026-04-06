import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// Blog Detail
class BlogDetailScreen extends StatelessWidget {
  final String blogId;
  const BlogDetailScreen({super.key, required this.blogId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('ARTICLE')),
    body: const Center(child: Text('Blog Detail - Full rich text content', style: TextStyle(color: GacomColors.textMuted))),
  );
}

// Product Detail  
class ProductDetailScreen extends StatelessWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('PRODUCT')),
    body: const Center(child: Text('Product Detail', style: TextStyle(color: GacomColors.textMuted))),
  );
}

// Notifications
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('NOTIFICATIONS')),
    body: const Center(child: Text('Notifications coming soon', style: TextStyle(color: GacomColors.textMuted))),
  );
}

// Search
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('SEARCH')),
    body: const Center(child: Text('Search players, communities, games...', style: TextStyle(color: GacomColors.textMuted))),
  );
}

// Settings
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GacomColors.obsidian,
    appBar: AppBar(title: const Text('SETTINGS')),
    body: ListView(
      children: [
        _SettingsTile(icon: Icons.person_outline_rounded, title: 'Edit Profile', onTap: () {}),
        _SettingsTile(icon: Icons.shield_outlined, title: 'Privacy', onTap: () {}),
        _SettingsTile(icon: Icons.notifications_outlined, title: 'Notifications', onTap: () {}),
        _SettingsTile(icon: Icons.lock_outline_rounded, title: 'Security', onTap: () {}),
        _SettingsTile(icon: Icons.verified_outlined, title: 'Get Verified', onTap: () {}),
        _SettingsTile(icon: Icons.help_outline_rounded, title: 'Help & Support', onTap: () {}),
        _SettingsTile(icon: Icons.logout_rounded, title: 'Sign Out', onTap: () async {
          await supabaseSignOut(context);
        }, isDestructive: true),
      ],
    ),
  );

  Future<void> supabaseSignOut(BuildContext context) async {
    // Import supabase and go_router at the top of your actual file
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  const _SettingsTile({required this.icon, required this.title, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? GacomColors.error : GacomColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontFamily: 'Rajdhani', fontWeight: FontWeight.w600, fontSize: 16)),
      trailing: const Icon(Icons.chevron_right_rounded, color: GacomColors.textMuted),
      onTap: onTap,
    );
  }
}
