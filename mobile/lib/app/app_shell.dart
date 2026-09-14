import 'package:flutter/material.dart';

import '../design_system/components/navigation/bottom_nav_bar.dart';
import '../features/collection/presentation/collection_screen.dart';
import '../features/discover/presentation/discover_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/scan/presentation/scan_screen.dart';

/// The app shell: a [Scaffold] hosting the 5 top-level destinations in an
/// [IndexedStack] (so each tab's widget state is preserved when switching)
/// plus the [BottomNavBar]. No routing package is used — Phase 1 has 5
/// flat, sibling destinations with no auth-gating or deep links, so a
/// locally-held selected index is the entire navigation state needed.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    MapScreen(),
    DiscoverScreen(),
    ScanScreen(),
    CollectionScreen(),
    ProfileScreen(),
  ];

  void _onSelect(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: _screens),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onSelect: _onSelect,
      ),
    );
  }
}
