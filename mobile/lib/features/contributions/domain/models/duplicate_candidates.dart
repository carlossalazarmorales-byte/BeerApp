import '../../../catalog/domain/models/beer.dart';
import '../../../catalog/domain/models/brewery.dart';

/// Result of `GET /beer-contributions/duplicate-candidates`.
///
/// [hasBlocking] (a catalog beer already owns the barcode, or the user's own
/// identical suggestion is pending) stops the submission. Everything else is
/// a non-blocking warning the user may override with "Submit anyway".
/// [pendingBarcodeDuplicateExists] is a bare boolean about ANOTHER user's
/// pending suggestion -- the backend never returns that suggestion, its id,
/// or its owner, so there is nothing more to show than the warning itself.
class BeerDuplicateCandidates {
  const BeerDuplicateCandidates({
    required this.barcodeMatch,
    required this.nameMatches,
    required this.breweryMatches,
    required this.alreadySubmitted,
    required this.pendingBarcodeDuplicateExists,
  });

  final Beer? barcodeMatch;
  final List<Beer> nameMatches;
  final List<Brewery> breweryMatches;
  final bool alreadySubmitted;
  final bool pendingBarcodeDuplicateExists;

  bool get hasBlocking => barcodeMatch != null || alreadySubmitted;

  bool get hasWarnings =>
      nameMatches.isNotEmpty ||
      breweryMatches.isNotEmpty ||
      pendingBarcodeDuplicateExists;

  factory BeerDuplicateCandidates.fromJson(Map<String, dynamic> json) {
    final barcodeMatch = json['barcode_match'] as Map<String, dynamic>?;
    return BeerDuplicateCandidates(
      barcodeMatch: barcodeMatch == null ? null : Beer.fromJson(barcodeMatch),
      nameMatches: (json['name_matches'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Beer.fromJson)
          .toList(),
      breweryMatches: (json['brewery_matches'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Brewery.fromJson)
          .toList(),
      alreadySubmitted: json['already_submitted'] as bool,
      pendingBarcodeDuplicateExists:
          json['pending_barcode_duplicate_exists'] as bool,
    );
  }
}

/// Result of `GET /brewery-contributions/duplicate-candidates`.
class BreweryDuplicateCandidates {
  const BreweryDuplicateCandidates({
    required this.nameMatches,
    required this.alreadySubmitted,
  });

  final List<Brewery> nameMatches;
  final bool alreadySubmitted;

  bool get hasBlocking => alreadySubmitted;
  bool get hasWarnings => nameMatches.isNotEmpty;

  factory BreweryDuplicateCandidates.fromJson(Map<String, dynamic> json) {
    return BreweryDuplicateCandidates(
      nameMatches: (json['name_matches'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Brewery.fromJson)
          .toList(),
      alreadySubmitted: json['already_submitted'] as bool,
    );
  }
}
