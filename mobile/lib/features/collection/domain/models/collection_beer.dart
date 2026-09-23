import '../../../catalog/domain/models/json_parsing.dart';

/// One row of a Collection list (Logged/Favorites/Wishlist tab). Mirrors the
/// backend's `CollectionBeerOut` schema -- brewery/style/country names
/// arrive already joined in the same response, never resolved client-side,
/// since brewery names in particular can't be safely resolved from
/// Discover's capped filter-option cache (see
/// `features/catalog/domain/catalog_filter_options.dart`).
class CollectionBeer {
  const CollectionBeer({
    required this.beerId,
    required this.officialName,
    required this.breweryName,
    required this.isFavorite,
    required this.isWishlist,
    this.styleName,
    this.countryName,
    this.imageUrl,
    this.abv,
    this.latestRating,
    this.latestConsumedAt,
  });

  final String beerId;
  final String officialName;
  final String breweryName;
  final String? styleName;
  final String? countryName;
  final String? imageUrl;
  final double? abv;
  final bool isFavorite;
  final bool isWishlist;

  /// The beer's *latest* log's rating -- never an average across multiple
  /// logs (see docs/DECISIONS.md). `null` means never logged, or logged
  /// with no rating.
  final int? latestRating;
  final DateTime? latestConsumedAt;

  /// Derived, never stored server-side (mirrors the backend repository's
  /// own "no separate has_logged boolean" comment): a non-null latest log
  /// means this beer has at least one log, i.e. it's unlocked.
  bool get isTried => latestRating != null || latestConsumedAt != null;

  factory CollectionBeer.fromJson(Map<String, dynamic> json) {
    return CollectionBeer(
      beerId: json['beer_id'] as String,
      officialName: json['official_name'] as String,
      breweryName: json['brewery_name'] as String,
      styleName: json['style_name'] as String?,
      countryName: json['country_name'] as String?,
      imageUrl: json['image_url'] as String?,
      abv: parseNullableDouble(json['abv']),
      isFavorite: json['is_favorite'] as bool,
      isWishlist: json['is_wishlist'] as bool,
      latestRating: json['latest_rating'] as int?,
      latestConsumedAt: json['latest_consumed_at'] == null
          ? null
          : DateTime.parse(json['latest_consumed_at'] as String),
    );
  }
}
