/// A proposed new beer. Exactly one of [breweryId] / [proposedBreweryName]
/// identifies the brewery -- a beer suggestion never references a separate
/// brewery suggestion. At most one of [styleId] / [proposedStyleName].
///
/// There is deliberately no `userId`, `status` or any review field: the
/// backend takes the owner from the session and always stores `pending`.
class BeerContributionInput {
  const BeerContributionInput({
    required this.officialName,
    this.breweryId,
    this.proposedBreweryName,
    this.styleId,
    this.proposedStyleName,
    this.abv,
    this.barcode,
  });

  final String officialName;
  final String? breweryId;
  final String? proposedBreweryName;
  final String? styleId;
  final String? proposedStyleName;
  final double? abv;

  /// As entered/scanned; the backend canonicalizes and validates it (the one
  /// barcode validator lives server-side).
  final String? barcode;

  Map<String, dynamic> toJson() => {
    'official_name': officialName,
    'brewery_id': ?breweryId,
    'proposed_brewery_name': ?proposedBreweryName,
    'style_id': ?styleId,
    'proposed_style_name': ?proposedStyleName,
    // Sent as text so the backend parses it as an exact decimal.
    if (abv != null) 'abv': abv.toString(),
    'barcode': ?barcode,
  };

  /// The identifying subset the duplicate check needs, as query parameters.
  Map<String, String> toDuplicateCheckQuery() => {
    'official_name': officialName,
    'brewery_id': ?breweryId,
    'proposed_brewery_name': ?proposedBreweryName,
    'barcode': ?barcode,
  };
}

/// A proposed new brewery. Exactly one of [countryId] /
/// [proposedCountryName]. No coordinates, website or description are
/// collected -- a moderator verifies and geocodes.
class BreweryContributionInput {
  const BreweryContributionInput({
    required this.name,
    this.countryId,
    this.proposedCountryName,
    this.region,
    this.city,
  });

  final String name;
  final String? countryId;
  final String? proposedCountryName;
  final String? region;
  final String? city;

  Map<String, dynamic> toJson() => {
    'name': name,
    'country_id': ?countryId,
    'proposed_country_name': ?proposedCountryName,
    'region': ?region,
    'city': ?city,
  };

  Map<String, String> toDuplicateCheckQuery() => {
    'name': name,
    'country_id': ?countryId,
    'proposed_country_name': ?proposedCountryName,
  };
}
