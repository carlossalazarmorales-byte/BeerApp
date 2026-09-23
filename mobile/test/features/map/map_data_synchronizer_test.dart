import 'dart:async';

import 'package:beerapp/features/map/data/country_boundaries.dart';
import 'package:beerapp/features/map/domain/models/map_beer.dart';
import 'package:beerapp/features/map/domain/models/map_country.dart';
import 'package:beerapp/features/map/presentation/map_data_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';

const _beersSource = 'beers-src';
const _countriesSource = 'countries-src';

class _Call {
  const _Call(this.sourceId, this.featureCount);

  final String sourceId;
  final int featureCount;

  @override
  String toString() => '$sourceId=$featureCount';
}

/// Records every platform call; can delay calls and fail on demand.
class _RecordingSurface implements MapSurface {
  final List<_Call> calls = [];
  Duration delay = Duration.zero;
  Object? failNextSourceWith;
  int concurrent = 0;
  int maxConcurrent = 0;

  /// The last GeoJSON feature ids each source received (what the map "shows").
  final Map<String, List<Object?>> shown = {};

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    try {
      final failure = failNextSourceWith;
      if (failure != null) {
        failNextSourceWith = null;
        throw failure;
      }
      final features = data['features'] as List;
      calls.add(_Call(sourceId, features.length));
      shown[sourceId] = [
        for (final feature in features)
          ((feature as Map)['properties'] as Map)['beer_id'] ??
              ((feature)['properties'] as Map)['fill_state'],
      ];
    } finally {
      concurrent--;
    }
  }

  int get sourceUploads => calls.length;
  void clear() => calls.clear();
}

MapBeer _beer(int i, {double? lat, double? lng, bool tried = false}) => MapBeer(
  beerId: 'beer-$i',
  officialName: 'Beer $i',
  breweryName: 'Brewery',
  latitude: lat ?? (i % 90).toDouble(),
  longitude: lng ?? (i % 180).toDouble(),
  isTried: tried,
  isFavorite: false,
  isWishlist: false,
);

List<MapBeer> _beers(int n) => [for (var i = 0; i < n; i++) _beer(i)];

CountryBoundary _boundary(String? isoCode) => CountryBoundary(
  isoCode: isoCode,
  geometry: const {
    'type': 'Polygon',
    'coordinates': [
      [
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 1.0],
        [0.0, 0.0],
      ],
    ],
  },
);

MapCountry _coverage(
  String isoCode, {
  int catalogBeerCount = 1,
  int triedBeerCount = 0,
}) => MapCountry(
  countryId: 'country-$isoCode',
  isoCode: isoCode,
  catalogBeerCount: catalogBeerCount,
  triedBeerCount: triedBeerCount,
);

MapDataSynchronizer _sync(_RecordingSurface surface) => MapDataSynchronizer(
  surface: surface,
  beersSourceId: _beersSource,
  countriesSourceId: _countriesSource,
);

MapSnapshot _snap({
  List<MapBeer> beers = const [],
  List<MapCountry> countryCoverage = const [],
  List<CountryBoundary> countryBoundaries = const [],
}) => MapSnapshot(
  beers: beers,
  countryCoverage: countryCoverage,
  countryBoundaries: countryBoundaries,
);

void main() {
  group('GeoJSON building: beers', () {
    test('[longitude, latitude] order, feature id, beer_id and is_tried properties', () {
      final collection = beerFeatureCollection([
        _beer(1, lat: 53.34, lng: -6.26, tried: true),
      ]);

      expect(collection['type'], 'FeatureCollection');
      expect((collection['features'] as List).single, {
        'type': 'Feature',
        'id': 'beer-1',
        'geometry': {
          'type': 'Point',
          'coordinates': [-6.26, 53.34],
        },
        'properties': {'beer_id': 'beer-1', 'is_tried': true},
      });
    });

    test('empty input gives an empty, valid collection', () {
      expect(beerFeatureCollection([]), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });

  group('GeoJSON building: country fill', () {
    test('a boundary with no clean ISO code is always zero_catalog', () {
      final collection = countryFillFeatureCollection(
        [_boundary(null)],
        [_coverage('BE', triedBeerCount: 5)],
      );

      final feature = (collection['features'] as List).single as Map;
      expect(
        (feature['properties'] as Map)['fill_state'],
        CountryFillState.zeroCatalog.value,
      );
    });

    test('an ISO code absent from coverage is zero_catalog', () {
      final collection = countryFillFeatureCollection(
        [_boundary('FR')],
        [_coverage('BE')],
      );

      final feature = (collection['features'] as List).single as Map;
      expect(
        (feature['properties'] as Map)['fill_state'],
        CountryFillState.zeroCatalog.value,
      );
    });

    test('a matched country with zero tried beers is zero_history', () {
      final collection = countryFillFeatureCollection(
        [_boundary('BE')],
        [_coverage('BE', triedBeerCount: 0)],
      );

      final feature = (collection['features'] as List).single as Map;
      expect(
        (feature['properties'] as Map)['fill_state'],
        CountryFillState.zeroHistory.value,
      );
    });

    test('a matched country with any tried beers is has_history -- no gradient/tier by ratio', () {
      final low = countryFillFeatureCollection(
        [_boundary('BE')],
        [_coverage('BE', catalogBeerCount: 100, triedBeerCount: 1)],
      );
      final high = countryFillFeatureCollection(
        [_boundary('BE')],
        [_coverage('BE', catalogBeerCount: 100, triedBeerCount: 99)],
      );
      final all = countryFillFeatureCollection(
        [_boundary('BE')],
        [_coverage('BE', catalogBeerCount: 100, triedBeerCount: 100)],
      );

      for (final collection in [low, high, all]) {
        final feature = (collection['features'] as List).single as Map;
        expect(
          (feature['properties'] as Map)['fill_state'],
          CountryFillState.hasHistory.value,
          reason: 'a 1%, 99% and 100% tried country must render identically',
        );
      }
    });

    test('the ISO match is case-insensitive', () {
      final collection = countryFillFeatureCollection(
        [_boundary('be')],
        [_coverage('BE', triedBeerCount: 1)],
      );

      final feature = (collection['features'] as List).single as Map;
      expect(
        (feature['properties'] as Map)['fill_state'],
        CountryFillState.hasHistory.value,
      );
    });

    test('empty input gives an empty, valid collection', () {
      expect(countryFillFeatureCollection([], []), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });

  group('first sync', () {
    test('uploads both sources', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);

      await sync.sync(
        () => _snap(
          beers: _beers(3),
          countryBoundaries: [_boundary('BE')],
          countryCoverage: [_coverage('BE')],
        ),
      );

      expect(surface.shown[_beersSource], ['beer-0', 'beer-1', 'beer-2']);
      expect(surface.shown[_countriesSource], hasLength(1));
      expect(surface.sourceUploads, 2);
    });
  });

  group('no redundant work', () {
    test('an identical resync makes no platform call at all', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(() => _snap(beers: _beers(50)));
      surface.clear();

      await sync.sync(() => _snap(beers: _beers(50)));

      expect(surface.calls, isEmpty);
    });

    test(
      'new list and model instances with the same content are still a no-op',
      () async {
        final surface = _RecordingSurface();
        final sync = _sync(surface);
        final boundaries = [_boundary('BE')];
        await sync.sync(
          () => _snap(
            beers: _beers(20),
            countryBoundaries: boundaries,
            countryCoverage: [_coverage('BE')],
          ),
        );
        surface.clear();

        // A pull-to-refresh returns freshly parsed objects with identical data.
        await sync.sync(
          () => _snap(
            beers: _beers(20),
            countryBoundaries: boundaries,
            countryCoverage: [_coverage('BE')],
          ),
        );

        expect(surface.calls, isEmpty);
      },
    );

    test('the loading-start notification (old data, isLoading) costs nothing', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      final current = _beers(30);
      await sync.sync(() => _snap(beers: current));
      surface.clear();

      // MapController notifies once when a load starts, still holding old data.
      await sync.sync(() => _snap(beers: current));

      expect(surface.calls, isEmpty);
    });

    test('changed beers re-upload ONLY the beers source', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(() => _snap(beers: _beers(10)));
      surface.clear();

      await sync.sync(() => _snap(beers: _beers(11)));

      expect(surface.calls.map((c) => c.toString()), ['$_beersSource=11']);
    });

    test('a beer flipping tried/untried re-uploads the beers source', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(() => _snap(beers: [_beer(1)]));
      surface.clear();

      await sync.sync(() => _snap(beers: [_beer(1, tried: true)]));

      expect(surface.sourceUploads, 1);
    });

    test(
      'changed countryCoverage re-uploads ONLY the countries source',
      () async {
        final surface = _RecordingSurface();
        final sync = _sync(surface);
        final boundaries = [_boundary('BE')];
        await sync.sync(
          () => _snap(countryBoundaries: boundaries, countryCoverage: []),
        );
        surface.clear();

        await sync.sync(
          () => _snap(
            countryBoundaries: boundaries,
            countryCoverage: [_coverage('BE', triedBeerCount: 1)],
          ),
        );

        expect(surface.calls.map((c) => c.toString()), ['$_countriesSource=1']);
      },
    );

    test('countryBoundaries resolving from empty (asset not yet loaded) to loaded forces a re-upload', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(() => _snap(countryBoundaries: const []));
      surface.clear();

      await sync.sync(() => _snap(countryBoundaries: [_boundary('BE')]));

      expect(surface.calls.map((c) => c.toString()), ['$_countriesSource=1']);
    });
  });

  group('invalidate (the style reloaded and the sources are empty again)', () {
    test('forces a full re-upload on the next sync', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(
        () => _snap(beers: _beers(8), countryBoundaries: [_boundary('BE')]),
      );
      surface.clear();

      sync.invalidate();
      await sync.sync(
        () => _snap(beers: _beers(8), countryBoundaries: [_boundary('BE')]),
      );

      expect(surface.sourceUploads, 2);
    });
  });

  group('coalescing', () {
    test(
      'overlapping syncs never run concurrently and end on the latest state',
      () async {
        final surface = _RecordingSurface()
          ..delay = const Duration(milliseconds: 5);
        final sync = _sync(surface);
        var latest = _snap(beers: _beers(1));

        // A burst of notifications while the first sync is still in flight.
        final futures = <Future<void>>[];
        for (var n = 1; n <= 8; n++) {
          latest = _snap(beers: _beers(n));
          futures.add(sync.sync(() => latest));
        }
        await Future.wait(futures);
        // Let any dirty re-run finish.
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(surface.maxConcurrent, 1, reason: 'syncs must not interleave');
        expect(surface.shown[_beersSource], hasLength(8));
        expect(surface.shown[_beersSource]!.first, 'beer-0');
        expect(surface.sourceUploads, lessThan(8));
      },
    );

    test(
      'a request that arrives mid-sync is served from the newest snapshot',
      () async {
        final surface = _RecordingSurface()
          ..delay = const Duration(milliseconds: 10);
        final sync = _sync(surface);
        var snapshot = _snap(beers: _beers(2));

        final first = sync.sync(() => snapshot);
        snapshot = _snap(beers: _beers(9));
        unawaited(sync.sync(() => snapshot));
        await first;
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(surface.shown[_beersSource], hasLength(9));
      },
    );
  });

  group('failure handling', () {
    test(
      'a failing platform call is contained -- sync does not throw',
      () async {
        final surface = _RecordingSurface()
          ..failNextSourceWith = StateError('platform channel failed');

        await expectLater(
          _sync(surface).sync(() => _snap(beers: _beers(3))),
          completes,
        );
      },
    );

    test('a failed piece is retried by the next sync, not skipped', () async {
      final surface = _RecordingSurface()
        ..failNextSourceWith = StateError('boom');
      final sync = _sync(surface);
      await sync.sync(() => _snap(beers: _beers(3)));
      expect(
        surface.shown[_beersSource],
        isNull,
        reason: 'first attempt failed',
      );

      await sync.sync(() => _snap(beers: _beers(3)));

      expect(surface.shown[_beersSource], hasLength(3));
    });

    test('the synchronizer keeps working after a failure', () async {
      final surface = _RecordingSurface()
        ..failNextSourceWith = StateError('boom');
      final sync = _sync(surface);
      await sync.sync(() => _snap(beers: _beers(3)));

      await sync.sync(() => _snap(beers: _beers(4)));

      expect(surface.shown[_beersSource], hasLength(4));
    });
  });
}
