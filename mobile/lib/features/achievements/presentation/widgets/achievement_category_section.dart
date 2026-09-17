import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/achievement.dart';
import '../../domain/models/achievement_category.dart';
import 'achievement_category_icon.dart';
import 'achievement_tile.dart';

String _categoryLabel(AppLocalizations l10n, AchievementCategory category) =>
    switch (category) {
      AchievementCategory.beersTried => l10n.achievementsCategoryBeersTried,
      AchievementCategory.countries => l10n.achievementsCategoryCountries,
      AchievementCategory.styles => l10n.achievementsCategoryStyles,
      AchievementCategory.breweries => l10n.achievementsCategoryBreweries,
      AchievementCategory.reviews => l10n.achievementsCategoryReviews,
      AchievementCategory.ratings => l10n.achievementsCategoryRatings,
      AchievementCategory.collection => l10n.achievementsCategoryCollection,
      AchievementCategory.special => l10n.achievementsCategorySpecial,
    };

/// One category heading plus its achievements. The Achievements screen only
/// builds one of these per category that actually has at least one item in
/// the current response -- an empty category never renders a heading (see
/// docs/DECISIONS.md).
class AchievementCategorySection extends StatelessWidget {
  const AchievementCategorySection({
    required this.category,
    required this.achievements,
    super.key,
  });

  final AchievementCategory category;
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              achievementCategoryIcons[category] ?? Icons.emoji_events,
              size: 18,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _categoryLabel(l10n, category),
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final achievement in achievements) ...[
          AchievementTile(achievement: achievement),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}
