import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';

final userRoleProvider = FutureProvider<String>((ref) async {
  final uid = SupabaseService.currentUserId;
  if (uid == null) return 'user';
  try {
    final p = await SupabaseService.client.from('profiles').select('role').eq('id', uid).single();
    return p['role'] as String? ?? 'user';
  } catch (_) { return 'user'; }
});

final competitionNotifProvider = FutureProvider<int>((ref) async {
  final uid = SupabaseService.currentUserId;
  if (uid == null) return 0;
  try {
    final data = await SupabaseService.client
        .from('notifications').select('id')
        .eq('recipient_id', uid).eq('is_read', false).eq('type', 'competition');
    return (data as List).length;
  } catch (_) { return 0; }
});

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final _tabs = const [
    _Tab(icon: Icons.home_rounded,    label: 'Home',      route: AppConstants.homeRoute),
    _Tab(icon: Icons.article_rounded, label: 'Blog',      route: AppConstants.blogRoute),
    _Tab(icon: Icons.add_rounded,     label: '',          route: AppConstants.createPostRoute, isFab: true),
    _Tab(icon: Icons.chat_rounded,    label: 'Chat',      route: AppConstants.chatRoute),
    _Tab(icon: Icons.groups_rounded,  label: 'Community', route: AppConstants.communityRoute),
    _Tab(icon: Icons.person_rounded,  label: 'Profile',   route: '', isProfile: true),
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override void dispose() { _glowCtrl.dispose(); super.dispose(); }

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    final tab = _tabs[i];
    setState(() => _selectedIndex = i);
    if (tab.isProfile) {
      context.go('/profile/${SupabaseService.currentUserId ?? ''}');
    } else {
      context.go(tab.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleAsync = ref.watch(userRoleProvider);
    final role = roleAsync.valueOrNull ?? 'user';
    final isPrivileged = ['admin', 'super_admin', 'moderator'].contains(role);
    final isExco = role == 'exco';
    final competitionBadge = ref.watch(competitionNotifProvider).valueOrNull ?? 0;

    return Scaffold(
      extendBody: false,
      body: Stack(children: [
        widget.child,
        Positioned(
          left: 12,
          bottom: 80 + (isPrivileged || isExco ? 28 : 0),
          child: _CompetitionFab(badge: competitionBadge),
        ),
        Positioned(
          right: 12,
          bottom: 80 + (isPrivileged || isExco ? 28 : 0),
          child: const _ReelsFab(),
        ),
      ]),
      bottomNavigationBar: _buildNav(context, isPrivileged, isExco, role),
    );
  }

  Widget _buildNav(BuildContext context, bool isPrivileged, bool isExco, String role) {
    // ✅ FIX: context-aware colours — works in both dark AND light mode
    final isDark = GacomColors.isDark(context);
    final navColor = GacomColors.navBg(context);
    final borderCol = GacomColors.borderColor(context);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            // Dark: semi-transparent. Light: white with subtle shadow
            color: isDark ? navColor.withOpacity(0.92) : navColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(top: BorderSide(color: borderCol, width: 0.7)),
            boxShadow: isDark
                ? null
                : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (isPrivileged) _AdminBar(role: role),
              if (isExco) const _ExcoBar(),
              SizedBox(
                height: 64,
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final tab = _tabs[i];
                    final sel = _selectedIndex == i;
                    if (tab.isFab) return _FabButton(anim: _glowAnim, onTap: () => _onTap(i));
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? GacomColors.deepOrange.withOpacity(isDark ? 0.13 : 0.09) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: sel ? Border.all(color: GacomColors.deepOrange.withOpacity(isDark ? 0.3 : 0.2), width: 0.7) : null,
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            AnimatedScale(
                              scale: sel ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                tab.icon,
                                size: 20,
                                // ✅ Inactive icons use context-aware muted colour
                                color: sel ? GacomColors.deepOrange : GacomColors.txtMuted(context),
                              ),
                            ),
                            if (tab.label.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontSize: 8,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel ? GacomColors.deepOrange : GacomColors.txtMuted(context),
                                  letterSpacing: 0.3,
                                ),
                                child: Text(tab.label),
                              ),
                            ],
                          ]),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CompetitionFab extends StatelessWidget {
  final int badge;
  const _CompetitionFab({required this.badge});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go(AppConstants.competitionsRoute),
    child: Stack(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: GacomColors.card(context),        // ✅ context-aware
          shape: BoxShape.circle,
          border: Border.all(color: GacomColors.deepOrange.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.25), blurRadius: 12)],
        ),
        child: const Icon(Icons.sports_esports_rounded, color: GacomColors.deepOrange, size: 22),
      ),
      if (badge > 0)
        Positioned(right: 0, top: 0,
          child: Container(
            width: 18, height: 18,
            decoration: const BoxDecoration(color: GacomColors.error, shape: BoxShape.circle),
            child: Center(child: Text(badge > 9 ? '9+' : '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
          )),
    ]),
  );
}

class _ReelsFab extends StatelessWidget {
  const _ReelsFab();
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go('/reels'),
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: GacomColors.card(context),          // ✅ context-aware
        shape: BoxShape.circle,
        border: Border.all(color: GacomColors.deepOrange.withOpacity(0.5), width: 1.5),
        boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.25), blurRadius: 12)],
      ),
      child: const Icon(Icons.play_circle_filled_rounded, color: GacomColors.deepOrange, size: 22),
    ),
  );
}

class _ExcoBar extends StatelessWidget {
  const _ExcoBar();
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go('/exco-dashboard'),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: GacomColors.info.withOpacity(0.08),
        border: Border(
          top: BorderSide(color: GacomColors.info.withOpacity(0.25), width: 0.5),
          bottom: BorderSide(color: GacomColors.borderColor(context).withOpacity(0.5), width: 0.5),
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.badge_rounded, color: GacomColors.info, size: 14),
        const SizedBox(width: 6),
        const Text('MY TEAM DASHBOARD', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: GacomColors.info, letterSpacing: 1.2)),
        const SizedBox(width: 6),
        const Icon(Icons.arrow_forward_ios_rounded, color: GacomColors.info, size: 10),
      ]),
    ),
  );
}

class _AdminBar extends StatelessWidget {
  final String role;
  const _AdminBar({required this.role});
  String get _label { switch (role) { case 'super_admin': return 'SUPER ADMIN'; case 'admin': return 'ADMIN'; default: return 'STAFF'; } }
  Color get _color { switch (role) { case 'super_admin': return const Color(0xFFFF3B3B); case 'admin': return GacomColors.deepOrange; default: return GacomColors.info; } }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go(AppConstants.adminRoute),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        border: Border(
          top: BorderSide(color: _color.withOpacity(0.3), width: 0.5),
          bottom: BorderSide(color: GacomColors.borderColor(context).withOpacity(0.5), width: 0.5),
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.admin_panel_settings_rounded, color: _color, size: 14),
        const SizedBox(width: 6),
        Text('OPEN $_label DASHBOARD', style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.w800, fontSize: 11, color: _color, letterSpacing: 1.2)),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_ios_rounded, color: _color, size: 10),
      ]),
    ),
  );
}

class _FabButton extends StatelessWidget {
  final Animation<double> anim; final VoidCallback onTap;
  const _FabButton({required this.anim, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: 56, child: Center(child: AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          gradient: GacomColors.orangeGradient,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: GacomColors.deepOrange.withOpacity(0.55 * anim.value), blurRadius: 20 * anim.value)],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    ))),
  );
}

class _Tab {
  final IconData icon; final String label; final String route;
  final bool isFab; final bool isProfile;
  const _Tab({required this.icon, required this.label, required this.route, this.isFab = false, this.isProfile = false});
}
