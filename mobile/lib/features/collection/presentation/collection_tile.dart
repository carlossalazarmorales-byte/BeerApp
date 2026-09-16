import 'package:flutter/material.dart';

import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../domain/models/collection_beer.dart';

/// A single row in a Collection list: image, name, brewery/style/country
/// subtitle, and a favorite-star/wishlist-bookmark/rating badge -- the
/// affordances `BeerListTile` has no room for (and doesn't need, since
/// Discover never shows personal state). Kept feature-local since
/// Collection is its only consumer, rather than extending the shared
/// `BeerListTile`.
class CollectionTile extends StatelessWidget {
  const CollectionTile({required this.beer, required this.onTap, super.key});

  final CollectionBeer beer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      beer.breweryName,
      ?beer.styleName,
      ?beer.countryName,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  child: _BeerImage(imageUrl: beer.imageUrl),
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
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      if (beer.isFavorite && beer.isWishlist)
                        const SizedBox(width: AppSpacing.xs),
                      if (beer.isWishlist)
                        const Icon(
                          Icons.bookmark,
                          size: 18,
                          color: AppColors.secondary,
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
    );
  }
}

class _BeerImage extends StatelessWidget {
  const _BeerImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) return const _BeerImageFallback();
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const _BeerImageFallback(),
    );
  }
}

class _BeerImageFallback extends StatelessWidget {
  const _BeerImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.secondaryContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.local_bar_outlined, color: AppColors.secondary),
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
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.onSecondaryFixed,
        ),
      ),
    );
  }
}
