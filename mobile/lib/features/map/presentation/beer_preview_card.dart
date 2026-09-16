import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/models/map_beer.dart';

/// Bottom-sheet preview shown when a beer marker/cluster point is tapped.
/// Renders entirely from [beer] -- a `MapBeerOut`-mirroring, self-sufficient
/// DTO -- so opening this sheet never makes a follow-up network request.
/// Full beer detail (description, ABV, image, ...) is only fetched, via the
/// existing beer detail route, once the user actually taps "View details".
class BeerPreviewCard extends StatelessWidget {
  const BeerPreviewCard({required this.beer, super.key});

  final MapBeer beer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitleParts = [
      beer.breweryName,
      if (beer.countryName != null) beer.countryName!,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(beer.officialName, style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitleParts.join(' · '),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (beer.isFavorite || beer.isWishlist || beer.isTried) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    if (beer.isTried) _StatusChip(label: l10n.mapModeTried),
                    if (beer.isFavorite)
                      _StatusChip(label: l10n.mapModeFavorites),
                    if (beer.isWishlist)
                      _StatusChip(label: l10n.mapModeWishlist),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: l10n.mapBeerPreviewViewDetailsAction,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push(AppRoutes.beerDetailPath(beer.beerId));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.onPrimaryContainer,
        ),
      ),
    );
  }
}
