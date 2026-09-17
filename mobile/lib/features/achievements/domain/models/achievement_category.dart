/// All product-approved achievement categories (mirrors the backend's
/// `AchievementCategory`), kept in full even though only a subset has
/// catalog entries today -- see docs/DECISIONS.md. `achievement_category_icon.dart`
/// maps each value to one icon; adding a future achievement in an
/// already-listed category needs no change here at all.
enum AchievementCategory {
  beersTried,
  countries,
  styles,
  breweries,
  reviews,
  ratings,
  collection,
  special;

  static AchievementCategory fromApiValue(String value) {
    return AchievementCategory.values.firstWhere(
      (category) => category._apiValue == value,
      orElse: () => AchievementCategory.special,
    );
  }

  String get _apiValue => switch (this) {
    AchievementCategory.beersTried => 'beers_tried',
    AchievementCategory.countries => 'countries',
    AchievementCategory.styles => 'styles',
    AchievementCategory.breweries => 'breweries',
    AchievementCategory.reviews => 'reviews',
    AchievementCategory.ratings => 'ratings',
    AchievementCategory.collection => 'collection',
    AchievementCategory.special => 'special',
  };
}
