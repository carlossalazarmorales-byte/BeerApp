import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_radii.dart';
import '../../tokens/app_shadows.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import 'scan_nav_button.dart';

/// The 5-destination bottom navigation bar: Map, Discover, Scan,
/// Collection, Profile — matching the tab order used by [AppShell]'s
/// `IndexedStack`. Scan (index 2) always renders as the emphasized
/// [ScanNavButton] rather than a plain nav item.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  static const int scanIndex = 2;

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.xl),
        ),
        boxShadow: AppShadows.navUpward,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavBarItem(
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: l10n.navMap,
                selected: selectedIndex == 0,
                onTap: () => onSelect(0),
              ),
              _NavBarItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: l10n.navDiscover,
                selected: selectedIndex == 1,
                onTap: () => onSelect(1),
              ),
              ScanNavButton(
                semanticLabel: l10n.navScan,
                onTap: () => onSelect(scanIndex),
              ),
              _NavBarItem(
                icon: Icons.collections_bookmark_outlined,
                activeIcon: Icons.collections_bookmark,
                label: l10n.navCollection,
                selected: selectedIndex == 3,
                onTap: () => onSelect(3),
              ),
              _NavBarItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: l10n.navProfile,
                selected: selectedIndex == 4,
                onTap: () => onSelect(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected
        ? AppColors.primary
        : AppColors.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.mdRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? activeIcon : icon, color: color, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTypography.labelLarge.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
