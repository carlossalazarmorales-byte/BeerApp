import 'package:beerapp/features/contributions/domain/models/contribution_input.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
import 'package:beerapp/features/contributions/domain/models/duplicate_candidates.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _beerJson({String id = 'beer-1'}) => {
  'id': id,
  'official_name': 'Hazy IPA',
  'brewery_id': 'brewery-1',
  'style_id': null,
  'country_id': null,
  'region': null,
  'city': null,
  'latitude': null,
  'longitude': null,
  'abv': '6.50',
  'ibu': null,
  'description': null,
  'image_url': null,
  'barcode': '4006381333931',
  'verified': true,
  'source': 'dev-seed',
  'created_at': '2026-09-18T12:00:00Z',
  'updated_at': '2026-09-18T12:00:00Z',
};

Map<String, dynamic> _breweryJson() => {
  'id': 'brewery-1',
  'name': 'Hop House',
  'country_id': 'country-1',
  'region': null,
  'city': 'Munich',
  'latitude': null,
  'longitude': null,
  'description': null,
  'website': null,
  'logo_url': null,
  'verified': true,
  'source': 'dev-seed',
  'created_at': '2026-09-18T12:00:00Z',
  'updated_at': '2026-09-18T12:00:00Z',
};

void main() {
  group('ContributionSummary', () {
    test('parses a history row', () {
      final summary = ContributionSummary.fromJson({
        'kind': 'brewery',
        'id': 'c-1',
        'title': 'Hop House',
        'status': 'pending',
        'created_at': '2026-09-18T12:00:00Z',
      });

      expect(summary.kind, ContributionKind.brewery);
      expect(summary.title, 'Hop House');
      expect(summary.status, ContributionStatus.pending);
      expect(summary.createdAt, DateTime.utc(2026, 9, 18, 12));
    });

    test(
      'parses every modeled status, and never guesses at an unknown one',
      () {
        expect(ContributionStatus.parse('pending'), ContributionStatus.pending);
        expect(
          ContributionStatus.parse('approved'),
          ContributionStatus.approved,
        );
        expect(
          ContributionStatus.parse('rejected'),
          ContributionStatus.rejected,
        );
        // Never mapped to approved (or pending): an unrecognized value stays
        // unknown so the UI cannot claim something the backend didn't say.
        expect(
          ContributionStatus.parse('escalated'),
          ContributionStatus.unknown,
        );
        expect(ContributionStatus.parse(null), ContributionStatus.unknown);
      },
    );

    test('an unknown kind is a parse error, not a silent default', () {
      expect(
        () => ContributionSummary.fromJson({
          'kind': 'label',
          'id': 'c-1',
          'title': 'x',
          'status': 'pending',
          'created_at': '2026-09-18T12:00:00Z',
        }),
        throwsFormatException,
      );
    });

    test('builds from a beer submission response', () {
      final summary = ContributionSummary.fromBeerSubmission({
        'id': 'c-1',
        'official_name': 'Hazy IPA',
        'status': 'pending',
        'created_at': '2026-09-18T12:00:00Z',
      });
      expect(summary.kind, ContributionKind.beer);
      expect(summary.title, 'Hazy IPA');
      expect(summary.status, ContributionStatus.pending);
    });

    test('builds from a brewery submission response', () {
      final summary = ContributionSummary.fromBrewerySubmission({
        'id': 'c-2',
        'name': 'Hop House',
        'status': 'pending',
        'created_at': '2026-09-18T12:00:00Z',
      });
      expect(summary.kind, ContributionKind.brewery);
      expect(summary.title, 'Hop House');
    });
  });

  group('BeerContributionInput', () {
    test('sends only what was provided and never an owner or status', () {
      final json = const BeerContributionInput(
        officialName: 'Hazy IPA',
        breweryId: 'brewery-1',
      ).toJson();

      expect(json, {'official_name': 'Hazy IPA', 'brewery_id': 'brewery-1'});
      expect(json.containsKey('user_id'), isFalse);
      expect(json.containsKey('status'), isFalse);
    });

    test(
      'a proposed brewery carries no brewery id and no contribution ref',
      () {
        final json = const BeerContributionInput(
          officialName: 'Hazy IPA',
          proposedBreweryName: 'Brand New Brewery',
          proposedStyleName: 'Weird Style',
          abv: 6.5,
          barcode: '036000291452',
        ).toJson();

        expect(json, {
          'official_name': 'Hazy IPA',
          'proposed_brewery_name': 'Brand New Brewery',
          'proposed_style_name': 'Weird Style',
          'abv': '6.5',
          'barcode': '036000291452',
        });
        expect(json.keys.any((k) => k.contains('contribution')), isFalse);
      },
    );

    test('the duplicate-check query carries only the identifying fields', () {
      final query = const BeerContributionInput(
        officialName: 'Hazy IPA',
        breweryId: 'brewery-1',
        styleId: 'style-1',
        abv: 6.5,
        barcode: '4006381333931',
      ).toDuplicateCheckQuery();

      expect(query, {
        'official_name': 'Hazy IPA',
        'brewery_id': 'brewery-1',
        'barcode': '4006381333931',
      });
    });
  });

  group('BreweryContributionInput', () {
    test('serializes a canonical country and optional location', () {
      final input = const BreweryContributionInput(
        name: 'Hop House',
        countryId: 'country-1',
        region: 'Bavaria',
        city: 'Munich',
      );
      expect(input.toJson(), {
        'name': 'Hop House',
        'country_id': 'country-1',
        'region': 'Bavaria',
        'city': 'Munich',
      });
      expect(input.toDuplicateCheckQuery(), {
        'name': 'Hop House',
        'country_id': 'country-1',
      });
    });

    test('serializes a proposed country', () {
      final json = const BreweryContributionInput(
        name: 'Hop House',
        proposedCountryName: 'Atlantis',
      ).toJson();
      expect(json, {'name': 'Hop House', 'proposed_country_name': 'Atlantis'});
    });
  });

  group('BeerDuplicateCandidates', () {
    Map<String, dynamic> json({
      Map<String, dynamic>? barcodeMatch,
      List<Map<String, dynamic>> nameMatches = const [],
      List<Map<String, dynamic>> breweryMatches = const [],
      bool alreadySubmitted = false,
      bool pendingBarcode = false,
    }) => {
      'barcode_match': barcodeMatch,
      'name_matches': nameMatches,
      'brewery_matches': breweryMatches,
      'already_submitted': alreadySubmitted,
      'pending_barcode_duplicate_exists': pendingBarcode,
    };

    test('a clean result has no blocks and no warnings', () {
      final result = BeerDuplicateCandidates.fromJson(json());
      expect(result.hasBlocking, isFalse);
      expect(result.hasWarnings, isFalse);
    });

    test('a catalog barcode owner is a HARD block', () {
      final result = BeerDuplicateCandidates.fromJson(
        json(barcodeMatch: _beerJson()),
      );
      expect(result.hasBlocking, isTrue);
      expect(result.barcodeMatch!.id, 'beer-1');
    });

    test('the callers own pending duplicate is a HARD block', () {
      final result = BeerDuplicateCandidates.fromJson(
        json(alreadySubmitted: true),
      );
      expect(result.hasBlocking, isTrue);
    });

    test('name and brewery matches are warnings, never blocks', () {
      final result = BeerDuplicateCandidates.fromJson(
        json(nameMatches: [_beerJson()], breweryMatches: [_breweryJson()]),
      );
      expect(result.hasBlocking, isFalse);
      expect(result.hasWarnings, isTrue);
      expect(result.nameMatches.single.officialName, 'Hazy IPA');
      expect(result.breweryMatches.single.name, 'Hop House');
    });

    test('another users pending barcode is a NON-blocking warning', () {
      final result = BeerDuplicateCandidates.fromJson(
        json(pendingBarcode: true),
      );
      expect(result.pendingBarcodeDuplicateExists, isTrue);
      expect(result.hasWarnings, isTrue);
      expect(result.hasBlocking, isFalse);
    });
  });

  group('BreweryDuplicateCandidates', () {
    test('a name match is a warning; an own pending duplicate blocks', () {
      final warning = BreweryDuplicateCandidates.fromJson({
        'name_matches': [_breweryJson()],
        'already_submitted': false,
      });
      expect(warning.hasWarnings, isTrue);
      expect(warning.hasBlocking, isFalse);

      final blocked = BreweryDuplicateCandidates.fromJson({
        'name_matches': [],
        'already_submitted': true,
      });
      expect(blocked.hasBlocking, isTrue);
    });
  });
}
