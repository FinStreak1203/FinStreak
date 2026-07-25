import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/database_providers.dart';
import '../theme/finella_colors.dart';

/// Bottom navigation matching the white & green design:
/// Home · Txns · [FIN AI raised center] · Insights · More
///
/// Branch order in [appRouter] mirrors these positions, so each tap maps to
/// `navigationShell.goBranch(index)` 1:1.
class ScaffoldWithBottomNav extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithBottomNav({super.key, required this.navigationShell});

  static const _green = FinellaColors.navBarGreen; // 0xFF2E7D32

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seed default accounts once for a fresh user (no UI; fire-and-forget).
    ref.watch(userSeedProvider);
    final current = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        color: _green,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // The four side items, with a gap in the middle for FIN AI.
                Row(
                  children: [
                    Expanded(
                        child: _item(0, current, Icons.home_outlined,
                            Icons.home, 'Home')),
                    Expanded(
                        child: _item(1, current, Icons.swap_horiz,
                            Icons.swap_horiz, 'Txns')),
                    const Expanded(child: SizedBox()), // center slot
                    Expanded(
                        child: _item(3, current, Icons.bar_chart_outlined,
                            Icons.bar_chart, 'Insights')),
                    Expanded(
                        child: _item(4, current, Icons.grid_view_outlined,
                            Icons.grid_view_rounded, 'More')),
                  ],
                ),
                // Raised center FIN AI button.
                Positioned(
                  top: -20,
                  child: _finAi(current == 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(int index, int current, IconData icon, IconData activeIcon,
      String label) {
    final selected = current == index;
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _go(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }

  Widget _finAi(bool selected) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _go(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: selected ? Colors.white : const Color(0xFFD8EAD0),
                  width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome,
                color: _green, size: 26),
          ),
          const SizedBox(height: 3),
          const Text('FIN AI',
              style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }

  void _go(int index) => navigationShell.goBranch(
        index,
        // Re-tapping the current tab pops to its root.
        initialLocation: index == navigationShell.currentIndex,
      );
}
