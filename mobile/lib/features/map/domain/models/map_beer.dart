import '../../../catalog/domain/models/json_parsing.dart';

/// One beer marker for the world map. Mirrors the backend's `MapBeerOut`
/// schema -- self-sufficient for `BeerPreviewCard`, with no field requiring
/// a follow-up request. `latitude`/`longitude` are the beer's own
/// coordinate pair if both are set server-side, otherwise its brewery's
/// pair -- never a mix of the two (see `MapRepository` on the backend).
/// Full beer detail (description, ABV, image, ...) is only fetched via
/// `CatalogRepository.getBeer` if the user taps "View details".
class MapBeer {
  const MapBeer({
    required this.beerId,
    required this.officialName,
    required this.breweryName,
    required this.latitude,
    required this.longitude,
    required this.isTried,
    required this.isFavorite,
    required this.isWishlist,
    this.countryName,
    this.region,
  });

  final String beerId;
  final String officialName;
  final String breweryName;
  final double latitude;
  final double longitude;
  final String? countryName;
  final String? region;
  final bool isTried;
  final bool isFavorite;
  final bool isWishlist;

  factory MapBeer.fromJson(Map<String, dynamic> json) {
    return MapBeer(
      beerId: json['beer_id'] as String,
      officialName: json['official_name'] as String,
      breweryName: json['brewery_name'] as String,
      // The backend only ever returns rows with a resolvable coordinate
      // pair (see MapRepository), so these are never null on the wire.
      latitude: parseNullableDouble(json['latitude'])!,
      longitude: parseNullableDouble(json['longitude'])!,
      countryName: json['country_name'] as String?,
      region: json['region'] as String?,
      isTried: json['is_tried'] as bool,
      isFavorite: json['is_favorite'] as bool,
      isWishlist: json['is_wishlist'] as bool,
    );
  }
}
