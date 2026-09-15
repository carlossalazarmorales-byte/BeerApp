import 'package:beerapp/features/logging/domain/models/beer_log_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a single provided field sends only that key', () {
    final input = BeerLogUpdateInput(review: 'new text');
    expect(input.toPatchJson(), {'review': 'new text'});
  });

  test('explicit null on venueName sends an explicit null, not omission', () {
    final input = BeerLogUpdateInput(venueName: null);
    expect(input.toPatchJson(), {'venue_name': null});
  });

  test('explicit null on servingVolumeMl sends an explicit null', () {
    final input = BeerLogUpdateInput(servingVolumeMl: null);
    expect(input.toPatchJson(), {'serving_volume_ml': null});
  });

  test('clearing price and currency together sends both keys as null', () {
    final input = BeerLogUpdateInput(price: null, currency: null);
    expect(input.toPatchJson(), {'price': null, 'currency': null});
  });

  test('no arguments at all sends nothing and isEmpty is true', () {
    const input = BeerLogUpdateInput();
    expect(input.toPatchJson(), <String, dynamic>{});
    expect(input.isEmpty, isTrue);
  });

  test('two provided fields send exactly those two keys and no others', () {
    final input = BeerLogUpdateInput(rating: 4, review: 'Nice');
    expect(input.toPatchJson(), {'rating': 4, 'review': 'Nice'});
  });

  test('a non-empty patch reports isEmpty as false', () {
    final input = BeerLogUpdateInput(rating: 4);
    expect(input.isEmpty, isFalse);
  });

  test('consumedAt is serialized as a UTC ISO-8601 string', () {
    final aware = DateTime.utc(2026, 1, 1, 10);
    final input = BeerLogUpdateInput(consumedAt: aware);
    expect(input.toPatchJson()['consumed_at'], aware.toIso8601String());
  });
}
