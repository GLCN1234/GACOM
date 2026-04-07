import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  // 6-tab nav: Home, Compete, [FAB Post], Community, Wallet, Profile
  final _tabs = const [
    _Tab(icon: Icons.home_rounded,             label: 'Home',      route: AppConstants.homeRoute),
    _Tab(icon: Icons.sports_esports_rounded,   label: 'Compete',   route: AppConstants.competitionsRoute),
    _Tab(icon: Icons.add_rounded,              label: '',          route: AppConstants.createPostRoute, isFab: true),
    _Tab(icon: Icons.groups_rounded,           label: 'Community', route: AppConstants.communityRoute),
    _Tab(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', route: AppConstants.walletRoute),
    _Tab(icon: Icons.person_rounded,           label: 'Profile',   route: '', isProfile: true),
  ];

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _onTap(int i) {
    HapticFeedback.selectionClick();
    final tab = _tabs[i];
    setState(() => _selectedIndex = i);
    if (tab.isProfile) {
      final uid = SupabaseService.currentUserId ?? '';
      context.go('/profile/$uid');
    } else {
      context.go(tab.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: GacomColors.darkVoid.withOpacity(0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: const Border(
              top: BorderSide(color: GacomColors.border, width: 0.7),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
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
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? GacomColors.deepOrange.withOpacity(0.13)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: sel
                              ? Border.all(
                                  color: GacomColors.deepOrange.withOpacity(0.3),
                                  width: 0.7)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: sel ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                tab.icon,
                                size: 22,
                                color: sel
                                    ? GacomColors.deepOrange
                                    : GacomColors.textMuted,
                              ),
                            ),
                            if (tab.label.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontSize: 9,
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                  color: sel
                                      ? GacomColors.deepOrange
                                      : GacomColors.textMuted,
                                  letterSpacing: 0.4,
                                ),
                                child: Text(tab.label),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FabButton extends StatelessWidget {
  final Animation<double> anim;
  final VoidCallback onTap;
  const _FabButton({required this.anim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Center(
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: GacomColors.orangeGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: GacomColors.deepOrange.withOpacity(0.55 * anim.value),
                    blurRadius: 20 * anim.value,
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String route;
  final bool isFab;
  final bool isProfile;
  const _Tab({
    required this.icon,
    required this.label,
    required this.route,
    this.isFab = false,
    this.isProfile = false,
  });
}
