import 'dart:convert';

import 'package:beerapp/core/network/access_token_provider.dart';
import 'package:beerapp/core/network/api_client.dart';
import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/contributions/data/api_contribution_repository.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_input.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AlwaysTokenProvider implements AccessTokenProvider {
  @override
  Future<String?> getAccessToken() async => 'token';
}

/// Builds a repository whose HTTP layer records the last request and answers
/// with [respond].
({ApiContributionRepository repository, http.Request Function() request})
_build(http.Response Function(http.Request request) respond) {
  http.Request? captured;
  final client = ApiClient(
    httpClient: MockClient((request) async {
      captured = request;
      return respond(request);
    }),
    baseUrl: 'https://api.example.com',
    accessTokenProvider: _AlwaysTokenProvider(),
  );
  return (
    repository: ApiContributionRepository(client),
    request: () => captured!,
  );
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

http.Response _error(int status, String code) => http.Response(
  jsonEncode({
    'error': {'code': code, 'message': 'diagnostic text'},
  }),
  status,
);

Map<String, dynamic> _beerJson() => {
  'id': 'beer-1',
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

void main() {
  test(
    'getHistory GETs /contributions with pagination and parses the page',
    () async {
      final harness = _build(
        (_) => _json({
          'items': [
            {
              'kind': 'beer',
              'id': 'c-1',
              'title': 'Hazy IPA',
              'status': 'pending',
              'created_at': '2026-09-18T12:00:00Z',
            },
          ],
          'page': 2,
          'page_size': 10,
          'total': 11,
        }),
      );

      final result = await harness.repository.getHistory(page: 2, pageSize: 10);

      final request = harness.request();
      expect(request.method, 'GET');
      expect(request.url.path, '/contributions');
      expect(request.url.queryParameters, {'page': '2', 'page_size': '10'});
      expect(request.headers['Authorization'], 'Bearer token');
      expect(result.total, 11);
      expect(result.items.single.status, ContributionStatus.pending);
    },
  );

  test('submitBeer POSTs the input and returns the pending summary', () async {
    final harness = _build(
      (_) => _json({
        'id': 'c-1',
        'official_name': 'Hazy IPA',
        'brewery_id': 'brewery-1',
        'proposed_brewery_name': null,
        'style_id': null,
        'proposed_style_name': null,
        'abv': '6.50',
        'barcode': null,
        'status': 'pending',
        'created_at': '2026-09-18T12:00:00Z',
      }, 201),
    );

    final summary = await harness.repository.submitBeer(
      const BeerContributionInput(
        officialName: 'Hazy IPA',
        breweryId: 'brewery-1',
        abv: 6.5,
      ),
    );

    final request = harness.request();
    expect(request.method, 'POST');
    expect(request.url.path, '/beer-contributions');
    expect(jsonDecode(request.body), {
      'official_name': 'Hazy IPA',
      'brewery_id': 'brewery-1',
      'abv': '6.5',
    });
    expect(summary.kind, ContributionKind.beer);
    expect(summary.status, ContributionStatus.pending);
  });

  test(
    'submitBrewery POSTs the input and returns the pending summary',
    () async {
      final harness = _build(
        (_) => _json({
          'id': 'c-2',
          'name': 'Hop House',
          'country_id': null,
          'proposed_country_name': 'Atlantis',
          'region': null,
          'city': null,
          'status': 'pending',
          'created_at': '2026-09-18T12:00:00Z',
        }, 201),
      );

      final summary = await harness.repository.submitBrewery(
        const BreweryContributionInput(
          name: 'Hop House',
          proposedCountryName: 'Atlantis',
        ),
      );

      final request = harness.request();
      expect(request.url.path, '/brewery-contributions');
      expect(jsonDecode(request.body), {
        'name': 'Hop House',
        'proposed_country_name': 'Atlantis',
      });
      expect(summary.kind, ContributionKind.brewery);
    },
  );

  test('checkBeerDuplicates GETs the query and parses the flag', () async {
    final harness = _build(
      (_) => _json({
        'barcode_match': null,
        'name_matches': [_beerJson()],
        'brewery_matches': [],
        'already_submitted': false,
        'pending_barcode_duplicate_exists': true,
      }),
    );

    final result = await harness.repository.checkBeerDuplicates(
      const BeerContributionInput(
        officialName: 'Hazy IPA',
        breweryId: 'brewery-1',
        barcode: '036000291452',
        abv: 6.5,
      ),
    );

    final request = harness.request();
    expect(request.method, 'GET');
    expect(request.url.path, '/beer-contributions/duplicate-candidates');
    expect(request.url.queryParameters, {
      'official_name': 'Hazy IPA',
      'brewery_id': 'brewery-1',
      'barcode': '036000291452',
    });
    expect(result.pendingBarcodeDuplicateExists, isTrue);
    expect(result.nameMatches.single.id, 'beer-1');
  });

  test('checkBreweryDuplicates GETs the query and parses matches', () async {
    final harness = _build(
      (_) => _json({'name_matches': [], 'already_submitted': true}),
    );

    final result = await harness.repository.checkBreweryDuplicates(
      const BreweryContributionInput(name: 'Hop House', countryId: 'country-1'),
    );

    final request = harness.request();
    expect(request.url.path, '/brewery-contributions/duplicate-candidates');
    expect(request.url.queryParameters, {
      'name': 'Hop House',
      'country_id': 'country-1',
    });
    expect(result.alreadySubmitted, isTrue);
  });

  test(
    'a beer name with URL-reserved characters survives the query intact',
    () async {
      final harness = _build(
        (_) => _json({
          'barcode_match': null,
          'name_matches': [],
          'brewery_matches': [],
          'already_submitted': false,
          'pending_barcode_duplicate_exists': false,
        }),
      );

      await harness.repository.checkBeerDuplicates(
        const BeerContributionInput(
          officialName: 'IPA & Friends / 50% #1',
          breweryId: 'brewery-1',
        ),
      );

      expect(
        harness.request().url.queryParameters['official_name'],
        'IPA & Friends / 50% #1',
      );
    },
  );

  group('409 responses carry their machine code', () {
    test('barcode_in_catalog', () async {
      final harness = _build((_) => _error(409, 'barcode_in_catalog'));
      await expectLater(
        harness.repository.submitBeer(
          const BeerContributionInput(officialName: 'x', breweryId: 'b'),
        ),
        throwsA(
          isA<ConflictApiException>()
              .having((e) => e.code, 'code', 'barcode_in_catalog')
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test('already_submitted', () async {
      final harness = _build((_) => _error(409, 'already_submitted'));
      await expectLater(
        harness.repository.submitBrewery(
          const BreweryContributionInput(name: 'x', countryId: 'c'),
        ),
        throwsA(
          isA<ConflictApiException>().having(
            (e) => e.code,
            'code',
            'already_submitted',
          ),
        ),
      );
    });
  });

  test(
    'a 404 for a vanished catalog reference is a NotFoundApiException',
    () async {
      final harness = _build((_) => _error(404, 'not_found'));
      await expectLater(
        harness.repository.submitBeer(
          const BeerContributionInput(officialName: 'x', breweryId: 'gone'),
        ),
        throwsA(isA<NotFoundApiException>()),
      );
    },
  );
}
