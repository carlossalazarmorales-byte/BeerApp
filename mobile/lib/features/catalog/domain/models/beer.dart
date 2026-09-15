import 'json_parsing.dart';

/// A single global catalog beer. Read-only mirror of the backend's `BeerOut`
/// schema -- carries no user-specific rating/favorite/wishlist data, per
/// docs/ARCHITECTURE.md's global/personal split.
class Beer {
  const Beer({
    required this.id,
    required this.officialName,
    required this.breweryId,
    required this.verified,
    this.styleId,
    this.countryId,
    this.region,
    this.city,
    this.latitude,
    this.longitude,
    this.abv,
    this.ibu,
    this.description,
    this.imageUrl,
    this.barcode,
  });

  final String id;
  final String officialName;
  final String breweryId;
  final String? styleId;
  final String? countryId;
  final String? region;
  final String? city;
  final double? latitude;
  final double? longitude;
  final double? abv;
  final int? ibu;
  final String? description;
  final String? imageUrl;
  final String? barcode;
  final bool verified;

  factory Beer.fromJson(Map<String, dynamic> json) {
    return Beer(
      id: json['id'] as String,
      officialName: json['official_name'] as String,
      breweryId: json['brewery_id'] as String,
      styleId: json['style_id'] as String?,
      countryId: json['country_id'] as String?,
      region: json['region'] as String?,
      city: json['city'] as String?,
      latitude: parseNullableDouble(json['latitude']),
      longitude: parseNullableDouble(json['longitude']),
      abv: parseNullableDouble(json['abv']),
      ibu: json['ibu'] as int?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      barcode: json['barcode'] as String?,
      verified: json['verified'] as bool,
    );
  }
}
