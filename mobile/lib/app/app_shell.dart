import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/components/navigation/bottom_nav_bar.dart';

/// The app shell: a [Scaffold] hosting the 5 top-level destinations plus the
/// [BottomNavBar]. Tab switching and per-tab widget-state preservation are
/// now owned by go_router's `StatefulShellRoute.indexedStack` (see
/// `router.dart`) instead of a hand-held `_selectedIndex` — the visible
/// behavior is unchanged from Phase 1, only where the state lives moved.
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: navigationShell.currentIndex,
        onSelect: navigationShell.goBranch,
      ),
    );
  }
}
