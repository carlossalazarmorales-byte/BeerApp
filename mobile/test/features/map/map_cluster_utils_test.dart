import 'package:beerapp/features/map/presentation/map_cluster_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseClusterId', () {
    test('accepts an int', () {
      expect(parseClusterId(42), 42);
    });

    test(
      'accepts a double (Android/web platform channels commonly hand back num)',
      () {
        expect(parseClusterId(42.0), 42);
      },
    );

    test('returns null for a non-numeric value, never a default like 0', () {
      expect(parseClusterId('42'), isNull);
      expect(parseClusterId(null), isNull);
      expect(parseClusterId(true), isNull);
    });
  });

  group('geoJsonCoordinatesToLatLng', () {
    test(
      'converts a [longitude, latitude] GeoJSON pair to (latitude, longitude)',
      () {
        final result = geoJsonCoordinatesToLatLng([5.7, 50.2]);

        expect(result, isNotNull);
        expect(result!.longitude, 5.7);
        expect(result.latitude, 50.2);
      },
    );

    test('accepts integer coordinates', () {
      final result = geoJsonCoordinatesToLatLng([10, 20]);

      expect(result!.longitude, 10.0);
      expect(result.latitude, 20.0);
    });

    test('returns null for the wrong element count', () {
      expect(geoJsonCoordinatesToLatLng([1.0]), isNull);
      expect(geoJsonCoordinatesToLatLng([1.0, 2.0, 3.0]), isNull);
    });

    test('returns null for non-numeric elements', () {
      expect(geoJsonCoordinatesToLatLng(['a', 'b']), isNull);
    });

    test('returns null for a non-list value, including absent geometry', () {
      expect(geoJsonCoordinatesToLatLng(null), isNull);
      expect(geoJsonCoordinatesToLatLng('not a list'), isNull);
    });
  });

  group('clusterSourceIdForLayer', () {
    const beersClusterLayerId = 'map-beers-clusters';
    const beersClusterCountLayerId = 'map-beers-cluster-count';
    const breweriesClusterLayerId = 'map-breweries-clusters';
    const breweriesClusterCountLayerId = 'map-breweries-cluster-count';
    const beersSourceId = 'map-beers-source';
    const breweriesSourceId = 'map-breweries-source';

    String? resolve(String layerId) => clusterSourceIdForLayer(
      layerId,
      beersClusterLayerId: beersClusterLayerId,
      beersClusterCountLayerId: beersClusterCountLayerId,
      breweriesClusterLayerId: breweriesClusterLayerId,
      breweriesClusterCountLayerId: breweriesClusterCountLayerId,
      beersSourceId: beersSourceId,
      breweriesSourceId: breweriesSourceId,
    );

    test('maps the beer cluster (circle) layer to the beer source', () {
      expect(resolve(beersClusterLayerId), beersSourceId);
    });

    test(
      'maps the beer cluster count-label layer to the beer source '
      '(the layer a tap can resolve to on Android instead of the circle)',
      () {
        expect(resolve(beersClusterCountLayerId), beersSourceId);
      },
    );

    test('maps the brewery cluster (circle) layer to the brewery source', () {
      expect(resolve(breweriesClusterLayerId), breweriesSourceId);
    });

    test(
      'maps the brewery cluster count label layer to the brewery source',
      () {
        expect(resolve(breweriesClusterCountLayerId), breweriesSourceId);
      },
    );

    test('returns null for any other layer id, never guessing brewery as a fallback', () {
      expect(resolve('map-beers-points'), isNull);
      expect(resolve('map-breweries-points'), isNull);
      expect(resolve('unknown-layer'), isNull);
    });
  });
}
