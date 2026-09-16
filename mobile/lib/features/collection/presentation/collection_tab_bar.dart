import 'package:flutter/material.dart';

import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../domain/collection_tab.dart';

/// Segmented Logged/Favorites/Wishlist tab control for the Collection
/// screen. No existing chip/tab component fits a mutually-exclusive
/// three-way selection (`AppFilterChip` is built for independent multi-
/// select filters), so this is built on Material's `SegmentedButton` for
/// built-in accessibility/keyboard support, token-styled to match
/// `AppFilterChip`'s selected/unselected palette.
class CollectionTabBar extends StatelessWidget {
  const CollectionTabBar({
    required this.selected,
    required this.onChanged,
    required this.labels,
    super.key,
  });

  final CollectionTab selected;
  final ValueChanged<CollectionTab> onChanged;
  final Map<CollectionTab, String> labels;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CollectionTab>(
      segments: [
        for (final tab in CollectionTab.values)
          ButtonSegment(value: tab, label: Text(labels[tab] ?? '')),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerHigh,
        foregroundColor: AppColors.onSurfaceVariant,
        selectedBackgroundColor: AppColors.primaryContainer,
        selectedForegroundColor: AppColors.onPrimaryContainer,
        textStyle: AppTypography.labelLarge,
        side: BorderSide.none,
      ),
    );
  }
}
