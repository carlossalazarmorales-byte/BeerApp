import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses the shared Page[T] envelope', () {
    final page = PagedResult.fromJson({
      'items': [
        {
          'id': '44444444-4444-4444-4444-444444444444',
          'official_name': 'Guinness Draught',
          'brewery_id': '33333333-3333-3333-3333-333333333333',
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
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        },
      ],
      'page': 2,
      'page_size': 5,
      'total': 6,
    }, Beer.fromJson);

    expect(page.items, hasLength(1));
    expect(page.items.single.officialName, 'Guinness Draught');
    expect(page.page, 2);
    expect(page.pageSize, 5);
    expect(page.total, 6);
  });
}
