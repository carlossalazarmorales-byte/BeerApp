import 'package:flutter/material.dart';

import '../../../design_system/components/chips/app_filter_chip.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/map_mode.dart';

/// Single-select mode row (All / Tried / Not tried / Favorites / Wishlist)
/// -- exactly one chip selected at a time, matching `MapController.mode`'s
/// single-select semantics (never independently combinable filters).
class MapModeSelector extends StatelessWidget {
  const MapModeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final MapMode selected;
  final ValueChanged<MapMode> onChanged;

  String _label(AppLocalizations l10n, MapMode mode) {
    switch (mode) {
      case MapMode.all:
        return l10n.mapModeAll;
      case MapMode.tried:
        return l10n.mapModeTried;
      case MapMode.notTried:
        return l10n.mapModeNotTried;
      case MapMode.favorites:
        return l10n.mapModeFavorites;
      case MapMode.wishlist:
        return l10n.mapModeWishlist;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          for (final mode in MapMode.values) ...[
            AppFilterChip(
              label: _label(l10n, mode),
              selected: selected == mode,
              onSelected: (_) => onChanged(mode),
            ),
            if (mode != MapMode.values.last)
              const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
