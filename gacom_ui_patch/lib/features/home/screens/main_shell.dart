import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabController;

  final _navItems = [
    _NavItem(icon: Icons.home_rounded, activeIcon: Icons.home_rounded, label: 'Home', route: AppConstants.homeRoute),
    _NavItem(icon: Icons.sports_esports_outlined, activeIcon: Icons.sports_esports_rounded, label: 'Compete', route: AppConstants.competitionsRoute),
    _NavItem(icon: Icons.add_rounded, activeIcon: Icons.add_rounded, label: 'Post', route: AppConstants.createPostRoute, isFab: true),
    _NavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Community', route: AppConstants.communityRoute),
    _NavItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Store', route: AppConstants.storeRoute),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GacomColors.obsidian,
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _buildNav(),
    );
  }

  Widget _buildNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: GacomColors.darkVoid.withOpacity(0.92),
            border: const Border(
              top: BorderSide(color: GacomColors.border, width: 0.5),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 62,
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  if (item.isFab) return _buildFab(i, item);
                  return _buildNavItem(i, item);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int i, _NavItem item) {
    final isSelected = _selectedIndex == i;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(i, item.route),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? GacomColors.deepOrange.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                  color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFab(int i, _NavItem item) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: () => _onTap(i, item.route),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: GacomColors.orangeGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: GacomColors.deepOrange.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
            .shimmer(duration: 3.seconds, color: Colors.white.withOpacity(0.1)),
        ),
      ),
    );
  }

  void _onTap(int i, String route) {
    if (_selectedIndex != i) {
      setState(() => _selectedIndex = i);
    }
    context.go(route);
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool isFab;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.isFab = false,
  });
}
