import 'package:flutter/material.dart';

import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/lockable_beer_image.dart';
import '../domain/models/collection_beer.dart';

/// A single row in a Collection list: image (with the shared locked/unlocked
/// treatment, via `LockableBeerImage`, same as `BeerListTile`), name,
/// brewery/style/country subtitle, and a favorite-star/wishlist-bookmark/
/// rating badge -- affordances `BeerListTile` has no room for. Kept
/// feature-local since Collection is its only consumer, rather than
/// extending the shared `BeerListTile`.
class CollectionTile extends StatelessWidget {
  const CollectionTile({required this.beer, required this.onTap, super.key});

  final CollectionBeer beer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitleParts = <String>[
      beer.breweryName,
      ?beer.styleName,
      ?beer.countryName,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      // One button for the whole row; favorite/wishlist/rating are announced
      // as part of it (they are otherwise icon-only).
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: AppCard(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: AppRadii.mdRadius,
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: LockableBeerImage(
                      imageUrl: beer.imageUrl,
                      isUnlocked: beer.isTried,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        beer.officialName,
                        style: AppTypography.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitleParts.join(' • '),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (beer.isFavorite)
                          Icon(
                            Icons.star,
                            size: 18,
                            color: AppColors.primary,
                            semanticLabel: l10n.collectionTabFavorites,
                          ),
                        if (beer.isFavorite && beer.isWishlist)
                          const SizedBox(width: AppSpacing.xs),
                        if (beer.isWishlist)
                          Icon(
                            Icons.bookmark,
                            size: 18,
                            color: AppColors.secondary,
                            semanticLabel: l10n.collectionTabWishlist,
                          ),
                      ],
                    ),
                    if (beer.latestRating != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _RatingBadge(rating: beer.latestRating!),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.tertiaryContainer,
        borderRadius: AppRadii.fullRadius,
      ),
      child: Text(
        '$rating/5',
        semanticsLabel: AppLocalizations.of(context)
            .collectionRatingSemanticLabel(rating),
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.onSecondaryFixed,
        ),
      ),
    );
  }
}
