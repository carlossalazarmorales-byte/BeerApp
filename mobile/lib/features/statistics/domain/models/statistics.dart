import 'amount_spent.dart';
import 'monthly_activity_point.dart';
import 'yearly_activity_point.dart';

/// The user's personal statistics: mirrors the backend's `StatisticsOut`
/// field-for-field. Descriptive summaries only -- no goals, streaks, or
/// consumption targets (see CLAUDE.md's Responsible Product Design rules).
class Statistics {
  const Statistics({
    required this.totalUniqueBeers,
    required this.totalLogs,
    required this.countriesDiscovered,
    required this.stylesDiscovered,
    required this.breweriesDiscovered,
    required this.averageRating,
    required this.amountSpent,
    required this.monthlyActivity,
    required this.yearlyActivity,
    required this.favoriteStyle,
    required this.favoriteCountry,
    required this.favoriteBrewery,
  });

  final int totalUniqueBeers;
  final int totalLogs;
  final int countriesDiscovered;
  final int stylesDiscovered;
  final int breweriesDiscovered;

  /// Null when the user has no rated logs -- never 0, which would be a
  /// real, misleadingly bad rating.
  final double? averageRating;

  final List<AmountSpent> amountSpent;

  /// Always exactly 12 points, zero-filled, trailing 12 UTC months.
  final List<MonthlyActivityPoint> monthlyActivity;

  /// One point per UTC calendar year that has >=1 log -- not zero-filled.
  final List<YearlyActivityPoint> yearlyActivity;

  /// Display name of the mode among the user's Collection favorites (see
  /// backend `StatisticsRepository`) -- null when the user has zero
  /// favorites, never a fabricated "most common" among nothing.
  final String? favoriteStyle;
  final String? favoriteCountry;
  final String? favoriteBrewery;

  /// True when there is any meaningful source data for this screen --
  /// either logs or Collection favorites. A user can have zero logs but
  /// non-null favorites (favorited a beer without ever logging it), and
  /// must still see the populated screen, not [EmptyState] -- deliberately
  /// does NOT check [monthlyActivity], which is always 12 zero-filled
  /// points regardless of whether the user has ever logged anything.
  bool get hasAnyStatistics =>
      totalLogs > 0 ||
      favoriteStyle != null ||
      favoriteCountry != null ||
      favoriteBrewery != null;

  factory Statistics.fromJson(Map<String, dynamic> json) => Statistics(
    totalUniqueBeers: json['total_unique_beers'] as int,
    totalLogs: json['total_logs'] as int,
    countriesDiscovered: json['countries_discovered'] as int,
    stylesDiscovered: json['styles_discovered'] as int,
    breweriesDiscovered: json['breweries_discovered'] as int,
    // A bare JSON number, not a Decimal-backed string -- StatisticsOut's
    // average_rating is `float`, unlike Decimal fields such as price/abv.
    averageRating: (json['average_rating'] as num?)?.toDouble(),
    amountSpent: (json['amount_spent'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AmountSpent.fromJson)
        .toList(),
    monthlyActivity: (json['monthly_activity'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(MonthlyActivityPoint.fromJson)
        .toList(),
    yearlyActivity: (json['yearly_activity'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(YearlyActivityPoint.fromJson)
        .toList(),
    favoriteStyle: json['favorite_style'] as String?,
    favoriteCountry: json['favorite_country'] as String?,
    favoriteBrewery: json['favorite_brewery'] as String?,
  );
}
