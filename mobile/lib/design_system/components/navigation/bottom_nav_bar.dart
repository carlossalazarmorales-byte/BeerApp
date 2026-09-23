import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_radii.dart';
import '../../tokens/app_shadows.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import 'scan_nav_button.dart';

/// The 5-destination bottom navigation bar: Map, Discover, Add Beer,
/// Collection, Profile — matching the tab order used by [AppShell]'s
/// `IndexedStack`. Add Beer (index 2, formerly Scan -- QA Round 1 Block 1)
/// always renders as the emphasized [ScanNavButton] rather than a plain nav
/// item.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  static const int addIndex = 2;

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
              Flexible(
                child: _NavBarItem(
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map,
                  label: l10n.navMap,
                  selected: selectedIndex == 0,
                  onTap: () => onSelect(0),
                ),
              ),
              Flexible(
                child: _NavBarItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: l10n.navDiscover,
                  selected: selectedIndex == 1,
                  onTap: () => onSelect(1),
                ),
              ),
              ScanNavButton(
                semanticLabel: l10n.navAdd,
                icon: Icons.add,
                onTap: () => onSelect(addIndex),
              ),
              Flexible(
                child: _NavBarItem(
                  icon: Icons.collections_bookmark_outlined,
                  activeIcon: Icons.collections_bookmark,
                  label: l10n.navCollection,
                  selected: selectedIndex == 3,
                  onTap: () => onSelect(3),
                ),
              ),
              Flexible(
                child: _NavBarItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: l10n.navProfile,
                  selected: selectedIndex == 4,
                  onTap: () => onSelect(4),
                ),
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

    // No explicit `label`: the visible Text below already names the item, and
    // an explicit label would be merged with it and announced twice.
    return Semantics(
      button: true,
      selected: selected,
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
                // Like Material's own NavigationBar, labels follow the system
                // text size only up to 1.3x (the bar's height and five
                // destinations do not scale); FittedBox shrinks a long
                // translation to its slot rather than overflowing. The full
                // name stays available to screen readers.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: AppTypography.labelLarge.copyWith(color: color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
