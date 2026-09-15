import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_radii.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../domain/models/beer.dart';

/// A single row in the Discover beer list: image (with a fallback icon when
/// `imageUrl` is null or fails to load -- most seed rows have no image
/// today), name, resolved style/country, and an ABV badge when known.
class BeerListTile extends StatelessWidget {
  const BeerListTile({
    required this.beer,
    required this.onTap,
    super.key,
    this.styleName,
    this.countryName,
  });

  final Beer beer;
  final String? styleName;
  final String? countryName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[?styleName, ?countryName];

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
                    if (subtitleParts.isNotEmpty) ...[
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
                  ],
                ),
              ),
              if (beer.abv != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _AbvBadge(abv: beer.abv!),
              ],
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

class _AbvBadge extends StatelessWidget {
  const _AbvBadge({required this.abv});

  final double abv;

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
        '${abv.toStringAsFixed(1)}%',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.onSecondaryFixed,
        ),
      ),
    );
  }
}
