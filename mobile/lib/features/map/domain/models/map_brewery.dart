import '../../../catalog/domain/models/json_parsing.dart';

/// One brewery marker for the world map. Mirrors the backend's
/// `MapBreweryOut` schema -- self-sufficient for `BreweryPreviewCard`. No
/// personal-state fields: breweries have no favorite/wishlist/tried concept
/// (see the Data Model Rule in CLAUDE.md -- personal state lives only on
/// beer-scoped entities).
class MapBrewery {
  const MapBrewery({
    required this.breweryId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.verified,
    this.countryName,
    this.city,
    this.region,
    this.description,
    this.website,
  });

  final String breweryId;
  final String name;
  final double latitude;
  final double longitude;
  final String? countryName;
  final String? city;
  final String? region;
  final String? description;
  final String? website;
  final bool verified;

  factory MapBrewery.fromJson(Map<String, dynamic> json) {
    return MapBrewery(
      breweryId: json['brewery_id'] as String,
      name: json['name'] as String,
      // The backend only ever returns breweries with their own coordinate
      // pair set (see MapRepository), so these are never null on the wire.
      latitude: parseNullableDouble(json['latitude'])!,
      longitude: parseNullableDouble(json['longitude'])!,
      countryName: json['country_name'] as String?,
      city: json['city'] as String?,
      region: json['region'] as String?,
      description: json['description'] as String?,
      website: json['website'] as String?,
      verified: json['verified'] as bool,
    );
  }
}
