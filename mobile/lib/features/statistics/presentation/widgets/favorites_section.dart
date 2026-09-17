import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/statistics.dart';

/// Favorite style/country/brewery -- shown even when the user has zero logs
/// (favorites are derived from Collection favorites, not from logs), so
/// this section renders normally on the "no logs yet, but has favorites"
/// path that [Statistics.hasAnyStatistics] exists to keep off the
/// full-screen empty state.
class FavoritesSection extends StatelessWidget {
  const FavoritesSection({required this.statistics, super.key});

  final Statistics statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final none = l10n.statisticsFavoriteNoneLabel;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.statisticsFavoritesSectionTitle,
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          _FavoriteRow(
            label: l10n.statisticsFavoriteStyleLabel,
            value: statistics.favoriteStyle ?? none,
          ),
          _FavoriteRow(
            label: l10n.statisticsFavoriteCountryLabel,
            value: statistics.favoriteCountry ?? none,
          ),
          _FavoriteRow(
            label: l10n.statisticsFavoriteBreweryLabel,
            value: statistics.favoriteBrewery ?? none,
          ),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
