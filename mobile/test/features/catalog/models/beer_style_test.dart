import 'package:beerapp/features/catalog/domain/models/beer_style.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses a fully populated row', () {
    final style = BeerStyle.fromJson({
      'id': '22222222-2222-2222-2222-222222222222',
      'name': 'Dry Stout',
      'category': 'Stout',
      'description': 'A dark, roasty beer.',
      'origin_country_id': '11111111-1111-1111-1111-111111111111',
      'typical_abv_min': 4.0,
      'typical_abv_max': 5.5,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(style.name, 'Dry Stout');
    expect(style.category, 'Stout');
    expect(style.originCountryId, '11111111-1111-1111-1111-111111111111');
    expect(style.typicalAbvMin, 4.0);
    expect(style.typicalAbvMax, 5.5);
  });

  test('fromJson tolerates a null-heavy row, matching real dev-seed shape', () {
    final style = BeerStyle.fromJson({
      'id': '22222222-2222-2222-2222-222222222222',
      'name': 'Dry Stout',
      'category': null,
      'description': null,
      'origin_country_id': null,
      'typical_abv_min': null,
      'typical_abv_max': null,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(style.category, isNull);
    expect(style.originCountryId, isNull);
    expect(style.typicalAbvMin, isNull);
    expect(style.typicalAbvMax, isNull);
  });

  test('fromJson parses typical_abv_min/max when the backend sends them as '
      'JSON strings -- the actual wire format (Pydantic v2 serializes Decimal '
      'fields as strings; verified against BeerStyleOut.model_dump_json() '
      'directly, which is what /beer-styles genuinely returns for a style '
      'with a non-null ABV range)', () {
    final style = BeerStyle.fromJson({
      'id': '22222222-2222-2222-2222-222222222222',
      'name': 'Dry Stout',
      'category': 'Stout',
      'description': null,
      'origin_country_id': null,
      'typical_abv_min': '4.00',
      'typical_abv_max': '5.50',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(style.typicalAbvMin, 4.0);
    expect(style.typicalAbvMax, 5.5);
  });
}
