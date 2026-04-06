import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;

  final _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home', route: AppConstants.homeRoute),
    _NavItem(icon: Icons.sports_esports_rounded, label: 'Compete', route: AppConstants.competitionsRoute),
    _NavItem(icon: Icons.add_circle_rounded, label: 'Post', route: AppConstants.createPostRoute, isCreate: true),
    _NavItem(icon: Icons.groups_rounded, label: 'Communities', route: AppConstants.communityRoute),
    _NavItem(icon: Icons.storefront_rounded, label: 'Store', route: AppConstants.storeRoute),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: GacomColors.darkVoid,
        border: Border(top: BorderSide(color: GacomColors.border, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final isSelected = _selectedIndex == i;
              if (item.isCreate) {
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    context.go(item.route);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      gradient: GacomColors.orangeGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: GacomColors.deepOrange,
                          blurRadius: 15,
                          spreadRadius: 0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                );
              }
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = i);
                  context.go(item.route);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? GacomColors.deepOrange.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final bool isCreate;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isCreate = false,
  });
}
