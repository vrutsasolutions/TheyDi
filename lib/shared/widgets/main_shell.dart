import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainShell — bottom nav + floating create FAB.
// UI improvements: nav bar has a subtle top shadow instead of a flat border;
// selected item gets a small gradient pill indicator; FAB has a richer glow.
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: const _CreateFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItemData(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home'),
    _NavItemData(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Explore'),
    _NavItemData(
        icon: Icons.event_outlined,
        activeIcon: Icons.event_rounded,
        label: 'My Experiences'),
    _NavItemData(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              // Left two items
              _NavItem(
                data: _items[0],
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                data: _items[1],
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              // Centre gap for FAB
              const Expanded(child: SizedBox()),
              // Right two items
              _NavItem(
                data: _items[2],
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                data: _items[3],
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData(
      {required this.icon, required this.activeIcon, required this.label});
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: isSelected ? TheyDiColors.gradientPrimary : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isSelected ? data.activeIcon : data.icon,
                size: 22,
                color:
                    isSelected ? Colors.white : TheyDiColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TheyDiTextStyles.labelSmall.copyWith(
                color: isSelected
                    ? TheyDiColors.primary
                    : TheyDiColors.textMuted,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 10,
              ),
              child: Text(data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Floating Action Button ────────────────────────────────────────────────────
class _CreateFAB extends StatelessWidget {
  const _CreateFAB();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      margin: const EdgeInsets.only(top: 28),
      decoration: BoxDecoration(
        gradient: TheyDiColors.gradientPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: TheyDiColors.primary.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(AppRoutes.createEvent),
          child: const Icon(Icons.add, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}