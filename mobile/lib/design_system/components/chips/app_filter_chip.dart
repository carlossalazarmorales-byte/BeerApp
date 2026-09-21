import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// A pill-shaped, token-styled chip for Discover's search filters --
/// selectable option chips inside the filter sheet, the "Filters" trigger
/// chip, and removable active-filter chips on the main screen.
///
/// Styled explicitly here (not via a global `ThemeData.chipTheme`) so this
/// stays scoped to Discover's filter UI without changing any other chip
/// elsewhere in the app.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    super.key,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
  });

  final String label;
  final bool selected;

  /// Tapping the chip body toggles selection. Null makes the chip
  /// non-interactive (its body, at least -- [onDeleted] still works).
  final ValueChanged<bool>? onSelected;

  /// Shows a trailing remove (x) affordance when set -- used for active
  /// filter chips on the main Discover screen.
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      onDeleted: onDeleted,
      showCheckmark: false,
      backgroundColor: AppColors.surfaceContainerHigh,
      selectedColor: AppColors.primaryContainer,
      disabledColor: AppColors.surfaceContainerHigh,
      labelStyle: AppTypography.labelLarge.copyWith(
        color: selected
            ? AppColors.onPrimaryContainer
            : AppColors.onSurfaceVariant,
      ),
      deleteIconColor: selected
          ? AppColors.onPrimaryContainer
          : AppColors.onSurfaceVariant,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      // The tappable box is padded out to the 48dp minimum touch target (the
      // drawn pill stays centred in it). Density stays compact horizontally
      // only: vertical compaction would subtract 8dp from that minimum.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: const VisualDensity(horizontal: -2),
      shadowColor: Colors.transparent,
      elevation: 0,
      pressElevation: 0,
    );
  }
}
