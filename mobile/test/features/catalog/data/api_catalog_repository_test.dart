import 'dart:convert';

import 'package:beerapp/core/network/access_token_provider.dart';
import 'package:beerapp/core/network/api_client.dart';
import 'package:beerapp/features/catalog/data/api_catalog_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _AlwaysTokenProvider implements AccessTokenProvider {
  @override
  Future<String?> getAccessToken() async => 'token';
}

void main() {
  test('getCountries parses the plain array response and caches it', () async {
    var callCount = 0;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode([
            {
              'id': '1',
              'iso_code': 'IE',
              'name': 'Ireland',
              'continent': 'Europe',
            },
          ]),
          200,
        );
      }),
      baseUrl: 'https://api.example.com',
      accessTokenProvider: _AlwaysTokenProvider(),
    );
    final repository = ApiCatalogRepository(client);

    final first = await repository.getCountries();
    final second = await repository.getCountries();

    expect(first, hasLength(1));
    expect(first.single.name, 'Ireland');
    expect(identical(first, second), isTrue);
    expect(callCount, 1);
  });

  test('getBeerStyles parses the plain array response and caches it', () async {
    var callCount = 0;
    final client = ApiClient(
      httpClient: MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode([
            {
              'id': '2',
              'name': 'Dry Stout',
              'category': null,
              'description': null,
              'origin_country_id': null,
              'typical_abv_min': null,
              'typical_abv_max': null,
            },
          ]),
          200,
        );
      }),
      baseUrl: 'https://api.example.com',
      accessTokenProvider: _AlwaysTokenProvider(),
    );
    final repository = ApiCatalogRepository(client);

    await repository.getBeerStyles();
    await repository.getBeerStyles();

    expect(callCount, 1);
  });

  test(
    'getBeers parses the Page envelope and forwards filters/pagination',
    () async {
      Uri? capturedUri;
      final client = ApiClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': '4',
                  'official_name': 'Guinness Draught',
                  'brewery_id': '3',
                  'style_id': null,
                  'country_id': null,
                  'region': null,
                  'city': null,
                  'latitude': null,
                  'longitude': null,
                  'abv': null,
                  'ibu': null,
                  'description': null,
                  'image_url': null,
                  'barcode': null,
                  'verified': true,
                  'source': null,
                  'is_tried': false,
                },
              ],
              'page': 2,
              'page_size': 20,
              'total': 21,
            }),
            200,
          );
        }),
        baseUrl: 'https://api.example.com',
        accessTokenProvider: _AlwaysTokenProvider(),
      );
      final repository = ApiCatalogRepository(client);

      final result = await repository.getBeers(page: 2, styleId: 'style-1');

      expect(result.items.single.beer.officialName, 'Guinness Draught');
      expect(result.page, 2);
      expect(result.total, 21);
      expect(capturedUri!.queryParameters['page'], '2');
      expect(capturedUri!.queryParameters['style_id'], 'style-1');
      expect(capturedUri!.queryParameters.containsKey('country_id'), isFalse);
    },
  );

  test('getBeer and getBrewery fetch single resources by id', () async {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.path == '/beers/beer-1') {
          return http.Response(
            jsonEncode({
              'id': 'beer-1',
              'official_name': 'Test Beer',
              'brewery_id': 'brewery-1',
              'style_id': null,
              'country_id': null,
              'region': null,
              'city': null,
              'latitude': null,
              'longitude': null,
              'abv': null,
              'ibu': null,
              'description': null,
              'image_url': null,
              'barcode': null,
              'verified': false,
              'source': null,
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'id': 'brewery-1',
            'name': 'Test Brewery',
            'country_id': 'country-1',
            'region': null,
            'city': null,
            'latitude': null,
            'longitude': null,
            'description': null,
            'website': null,
            'logo_url': null,
            'verified': false,
            'source': null,
          }),
          200,
        );
      }),
      baseUrl: 'https://api.example.com',
      accessTokenProvider: _AlwaysTokenProvider(),
    );
    final repository = ApiCatalogRepository(client);

    final beer = await repository.getBeer('beer-1');
    final brewery = await repository.getBrewery('brewery-1');

    expect(beer.officialName, 'Test Beer');
    expect(brewery.name, 'Test Brewery');
  });
}
