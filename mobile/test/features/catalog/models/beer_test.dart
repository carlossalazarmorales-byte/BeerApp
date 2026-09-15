import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses a null-heavy row, matching real dev-seed shape', () {
    final beer = Beer.fromJson({
      'id': '44444444-4444-4444-4444-444444444444',
      'official_name': 'Guinness Draught',
      'brewery_id': '33333333-3333-3333-3333-333333333333',
      'style_id': '22222222-2222-2222-2222-222222222222',
      'country_id': '11111111-1111-1111-1111-111111111111',
      'region': null,
      'city': null,
      'latitude': null,
      'longitude': null,
      'abv': null,
      'ibu': null,
      'description': null,
      'image_url': null,
      'barcode': '5000213007072',
      'verified': true,
      'source': 'dev-seed',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(beer.officialName, 'Guinness Draught');
    expect(beer.breweryId, '33333333-3333-3333-3333-333333333333');
    expect(beer.styleId, '22222222-2222-2222-2222-222222222222');
    expect(beer.countryId, '11111111-1111-1111-1111-111111111111');
    expect(beer.abv, isNull);
    expect(beer.ibu, isNull);
    expect(beer.barcode, '5000213007072');
    expect(beer.verified, isTrue);
  });

  test('fromJson parses numeric abv/ibu and a null style/country', () {
    final beer = Beer.fromJson({
      'id': '44444444-4444-4444-4444-444444444444',
      'official_name': 'Test IPA',
      'brewery_id': '33333333-3333-3333-3333-333333333333',
      'style_id': null,
      'country_id': null,
      'region': null,
      'city': null,
      'latitude': null,
      'longitude': null,
      'abv': 6.5,
      'ibu': 55,
      'description': 'A hoppy test beer.',
      'image_url': 'https://example.com/beer.png',
      'barcode': null,
      'verified': false,
      'source': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(beer.styleId, isNull);
    expect(beer.countryId, isNull);
    expect(beer.abv, 6.5);
    expect(beer.ibu, 55);
    expect(beer.description, 'A hoppy test beer.');
    expect(beer.imageUrl, 'https://example.com/beer.png');
  });

  test('fromJson parses abv/latitude/longitude when the backend sends them as '
      'JSON strings -- the actual wire format (Pydantic v2 serializes Decimal '
      'fields as strings, e.g. "4.20", not bare numbers; verified against '
      'BeerOut.model_dump_json() directly)', () {
    final beer = Beer.fromJson({
      'id': '44444444-4444-4444-4444-444444444444',
      'official_name': 'Test IPA',
      'brewery_id': '33333333-3333-3333-3333-333333333333',
      'style_id': null,
      'country_id': null,
      'region': null,
      'city': null,
      'latitude': '53.349805',
      'longitude': '-6.260310',
      'abv': '4.20',
      'ibu': 45,
      'description': null,
      'image_url': null,
      'barcode': null,
      'verified': true,
      'source': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(beer.latitude, 53.349805);
    expect(beer.longitude, -6.26031);
    expect(beer.abv, 4.2);
    expect(beer.ibu, 45);
  });
}
