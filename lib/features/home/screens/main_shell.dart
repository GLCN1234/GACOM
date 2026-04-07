import 'dart:ui';
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

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  final _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Home', route: AppConstants.homeRoute),
    _NavItem(icon: Icons.sports_esports_rounded, label: 'Compete', route: AppConstants.competitionsRoute),
    _NavItem(icon: Icons.add_rounded, label: 'Post', route: AppConstants.createPostRoute, isCreate: true),
    _NavItem(icon: Icons.groups_rounded, label: 'Community', route: AppConstants.communityRoute),
    _NavItem(icon: Icons.storefront_rounded, label: 'Store', route: AppConstants.storeRoute),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: widget.child,
      bottomNavigationBar: _GlassNavBar(
        items: _navItems,
        selectedIndex: _selectedIndex,
        pulseAnim: _pulseAnim,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          context.go(_navItems[i].route);
        },
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final Animation<double> pulseAnim;
  final void Function(int) onTap;

  const _GlassNavBar({
    required this.items,
    required this.selectedIndex,
    required this.pulseAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: GacomColors.darkVoid.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: const Border(
              top: BorderSide(color: GacomColors.border, width: 0.8),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(items.length, (i) {
                  final item = items[i];
                  final isSelected = selectedIndex == i;

                  if (item.isCreate) {
                    return _CreateButton(pulseAnim: pulseAnim, onTap: () => onTap(i));
                  }

                  return _NavTile(
                    item: item,
                    isSelected: isSelected,
                    onTap: () => onTap(i),
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

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? GacomColors.deepOrange.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: GacomColors.deepOrange.withOpacity(0.25), width: 0.8)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                item.icon,
                color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted,
                size: isSelected ? 24 : 22,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.5,
                color: isSelected ? GacomColors.deepOrange : GacomColors.textMuted,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  const _CreateButton({required this.pulseAnim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnim,
        builder: (_, child) => Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: GacomColors.orangeGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: GacomColors.deepOrange.withOpacity(0.5 * pulseAnim.value),
                blurRadius: 18 * pulseAnim.value,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
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
