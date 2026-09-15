import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses a real backend row', () {
    final country = Country.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'iso_code': 'IE',
      'name': 'Ireland',
      'continent': 'Europe',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(country.id, '11111111-1111-1111-1111-111111111111');
    expect(country.isoCode, 'IE');
    expect(country.name, 'Ireland');
    expect(country.continent, 'Europe');
  });
}
