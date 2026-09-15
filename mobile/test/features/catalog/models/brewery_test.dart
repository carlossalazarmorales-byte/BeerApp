import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses a null-heavy row, matching real dev-seed shape', () {
    final brewery = Brewery.fromJson({
      'id': '33333333-3333-3333-3333-333333333333',
      'name': "St. James's Gate Brewery",
      'country_id': '11111111-1111-1111-1111-111111111111',
      'region': null,
      'city': 'Dublin',
      'latitude': null,
      'longitude': null,
      'description': null,
      'website': null,
      'logo_url': null,
      'verified': true,
      'source': 'dev-seed',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(brewery.name, "St. James's Gate Brewery");
    expect(brewery.countryId, '11111111-1111-1111-1111-111111111111');
    expect(brewery.city, 'Dublin');
    expect(brewery.region, isNull);
    expect(brewery.logoUrl, isNull);
    expect(brewery.verified, isTrue);
  });

  test('fromJson parses numeric latitude/longitude as doubles', () {
    final brewery = Brewery.fromJson({
      'id': '33333333-3333-3333-3333-333333333333',
      'name': 'Test Brewery',
      'country_id': '11111111-1111-1111-1111-111111111111',
      'region': null,
      'city': null,
      'latitude': 53.34,
      'longitude': -6.27,
      'description': null,
      'website': null,
      'logo_url': null,
      'verified': false,
      'source': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(brewery.latitude, 53.34);
    expect(brewery.longitude, -6.27);
  });

  test('fromJson parses latitude/longitude when the backend sends them as JSON '
      'strings -- the actual wire format (verified against '
      'BreweryOut.model_dump_json() directly)', () {
    final brewery = Brewery.fromJson({
      'id': '33333333-3333-3333-3333-333333333333',
      'name': 'Test Brewery',
      'country_id': '11111111-1111-1111-1111-111111111111',
      'region': null,
      'city': null,
      'latitude': '53.1',
      'longitude': '-6.2',
      'description': null,
      'website': null,
      'logo_url': null,
      'verified': false,
      'source': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(brewery.latitude, 53.1);
    expect(brewery.longitude, -6.2);
  });
}
