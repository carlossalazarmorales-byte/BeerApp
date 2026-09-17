import 'package:flutter/material.dart';

import '../../domain/models/achievement_category.dart';

/// One icon per category (not per achievement) -- a future achievement in an
/// already-listed category needs no icon work at all.
const Map<AchievementCategory, IconData> achievementCategoryIcons = {
  AchievementCategory.beersTried: Icons.sports_bar,
  AchievementCategory.countries: Icons.public,
  AchievementCategory.styles: Icons.category,
  AchievementCategory.breweries: Icons.factory,
  AchievementCategory.reviews: Icons.rate_review,
  AchievementCategory.ratings: Icons.star,
  AchievementCategory.collection: Icons.favorite,
  AchievementCategory.special: Icons.emoji_events,
};
