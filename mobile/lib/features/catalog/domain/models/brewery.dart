import 'json_parsing.dart';

class Brewery {
  const Brewery({
    required this.id,
    required this.name,
    required this.countryId,
    required this.verified,
    this.region,
    this.city,
    this.latitude,
    this.longitude,
    this.description,
    this.website,
    this.logoUrl,
  });

  final String id;
  final String name;
  final String countryId;
  final String? region;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? website;
  final String? logoUrl;
  final bool verified;

  factory Brewery.fromJson(Map<String, dynamic> json) {
    return Brewery(
      id: json['id'] as String,
      name: json['name'] as String,
      countryId: json['country_id'] as String,
      region: json['region'] as String?,
      city: json['city'] as String?,
      latitude: parseNullableDouble(json['latitude']),
      longitude: parseNullableDouble(json['longitude']),
      description: json['description'] as String?,
      website: json['website'] as String?,
      logoUrl: json['logo_url'] as String?,
      verified: json['verified'] as bool,
    );
  }
}
