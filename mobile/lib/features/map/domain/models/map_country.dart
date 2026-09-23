/// Per-country catalog/tried counts for the map's country-fill layer.
/// Mirrors the backend's `MapCountryCoverageOut` schema. Only countries
/// with at least one catalog beer are ever returned -- a country absent
/// from the response is the "zero catalog" map state, never a zero-count
/// entry (see `MapRepository.getCountryCoverage`).
///
/// Both counts are legitimate derived data, but the map must render only
/// three flat, non-gradient fill states from them (see
/// `country_fill.dart`) -- never a completion percentage or gradient. See
/// docs/QA_ROUND_1.md Block 2 and CLAUDE.md's Responsible Product Design
/// section.
class MapCountry {
  const MapCountry({
    required this.countryId,
    required this.isoCode,
    required this.catalogBeerCount,
    required this.triedBeerCount,
  });

  final String countryId;
  final String isoCode;
  final int catalogBeerCount;
  final int triedBeerCount;

  factory MapCountry.fromJson(Map<String, dynamic> json) {
    return MapCountry(
      countryId: json['country_id'] as String,
      isoCode: json['iso_code'] as String,
      catalogBeerCount: json['catalog_beer_count'] as int,
      triedBeerCount: json['tried_beer_count'] as int,
    );
  }
}
