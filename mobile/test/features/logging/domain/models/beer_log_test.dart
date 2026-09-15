import 'package:beerapp/features/logging/domain/models/beer_log.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({Object? servingVolumeMl = 330}) => {
  'id': 'log-1',
  'user_id': 'user-1',
  'beer_id': 'beer-1',
  'rating': 4,
  'review': 'Great beer',
  'consumed_at': '2026-01-01T10:00:00+00:00',
  'serving_note': null,
  'price': '5.50',
  'currency': 'USD',
  'venue_name': 'The Local',
  'serving_volume_ml': servingVolumeMl,
  'created_at': '2026-01-01T10:00:00+00:00',
  'updated_at': '2026-01-01T10:00:00+00:00',
};

void main() {
  test('fromJson parses a present serving_volume_ml', () {
    final log = BeerLog.fromJson(_json(servingVolumeMl: 330));
    expect(log.servingVolumeMl, 330);
  });

  test('fromJson parses a null serving_volume_ml', () {
    final log = BeerLog.fromJson(_json(servingVolumeMl: null));
    expect(log.servingVolumeMl, isNull);
  });

  test('fromJson parses price as a double, tolerant of Decimal-as-string', () {
    final log = BeerLog.fromJson(_json());
    expect(log.price, 5.5);
  });

  test('fromJson parses createdAt and updatedAt', () {
    final log = BeerLog.fromJson(_json());
    expect(log.createdAt, DateTime.parse('2026-01-01T10:00:00+00:00'));
    expect(log.updatedAt, DateTime.parse('2026-01-01T10:00:00+00:00'));
  });
}
