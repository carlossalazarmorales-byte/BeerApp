import 'json_parsing.dart';

class BeerStyle {
  const BeerStyle({
    required this.id,
    required this.name,
    this.category,
    this.description,
    this.originCountryId,
    this.typicalAbvMin,
    this.typicalAbvMax,
  });

  final String id;
  final String name;
  final String? category;
  final String? description;
  final String? originCountryId;
  final double? typicalAbvMin;
  final double? typicalAbvMax;

  factory BeerStyle.fromJson(Map<String, dynamic> json) {
    return BeerStyle(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      description: json['description'] as String?,
      originCountryId: json['origin_country_id'] as String?,
      typicalAbvMin: parseNullableDouble(json['typical_abv_min']),
      typicalAbvMax: parseNullableDouble(json['typical_abv_max']),
    );
  }
}
