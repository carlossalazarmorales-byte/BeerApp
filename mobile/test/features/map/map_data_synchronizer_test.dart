import 'dart:async';

import 'package:beerapp/features/map/domain/map_mode.dart';
import 'package:beerapp/features/map/domain/models/map_beer.dart';
import 'package:beerapp/features/map/domain/models/map_brewery.dart';
import 'package:beerapp/features/map/presentation/map_data_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';

const _beersSource = 'beers-src';
const _breweriesSource = 'breweries-src';
const _beerLayers = ['beers-cluster', 'beers-count', 'beers-points'];
const _breweryLayers = ['br-cluster', 'br-count', 'br-points'];

class _Call {
  const _Call(this.kind, this.target, [this.value]);

  final String kind; // 'source' | 'visibility'
  final String target;
  final Object? value;

  @override
  String toString() => '$kind:$target=$value';
}

/// Records every platform call; can delay calls and fail on demand.
class _RecordingSurface implements MapSurface {
  final List<_Call> calls = [];
  Duration delay = Duration.zero;
  Object? failNextSourceWith;
  int concurrent = 0;
  int maxConcurrent = 0;

  /// The last GeoJSON feature ids each source received (what the map "shows").
  final Map<String, List<String>> shown = {};
  final Map<String, bool> visible = {};

  Future<void> _enter() async {
    concurrent++;
    if (concurrent > maxConcurrent) maxConcurrent = concurrent;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<void> setGeoJsonSource(
    String sourceId,
    Map<String, dynamic> data,
  ) async {
    await _enter();
    try {
      final failure = failNextSourceWith;
      if (failure != null) {
        failNextSourceWith = null;
        throw failure;
      }
      final features = data['features'] as List;
      calls.add(_Call('source', sourceId, features.length));
      shown[sourceId] = [
        for (final feature in features) (feature as Map)['id'] as String,
      ];
    } finally {
      concurrent--;
    }
  }

  @override
  Future<void> setLayerVisibility(String layerId, bool visible) async {
    await _enter();
    try {
      calls.add(_Call('visibility', layerId, visible));
      this.visible[layerId] = visible;
    } finally {
      concurrent--;
    }
  }

  int get sourceUploads => calls.where((c) => c.kind == 'source').length;
  int get visibilityCalls => calls.where((c) => c.kind == 'visibility').length;
  void clear() => calls.clear();
}

MapBeer _beer(int i, {double? lat, double? lng}) => MapBeer(
  beerId: 'beer-$i',
  officialName: 'Beer $i',
  breweryName: 'Brewery',
  latitude: lat ?? (i % 90).toDouble(),
  longitude: lng ?? (i % 180).toDouble(),
  isTried: false,
  isFavorite: false,
  isWishlist: false,
);

MapBrewery _brewery(int i, {double? lat}) => MapBrewery(
  breweryId: 'brewery-$i',
  name: 'Brewery $i',
  latitude: lat ?? (i % 90).toDouble(),
  longitude: (i % 180).toDouble(),
  verified: true,
);

List<MapBeer> _beers(int n) => [for (var i = 0; i < n; i++) _beer(i)];
List<MapBrewery> _breweries(int n) => [for (var i = 0; i < n; i++) _brewery(i)];

MapDataSynchronizer _sync(_RecordingSurface surface) => MapDataSynchronizer(
  surface: surface,
  beersSourceId: _beersSource,
  breweriesSourceId: _breweriesSource,
  beerLayerIds: _beerLayers,
  breweryLayerIds: _breweryLayers,
);

MapSnapshot _snap({
  List<MapBeer> beers = const [],
  List<MapBrewery> breweries = const [],
  MapMode mode = MapMode.all,
}) => MapSnapshot(beers: beers, breweries: breweries, mode: mode);

void main() {
  group('GeoJSON building', () {
    test('beers: [longitude, latitude] order, feature id and property', () {
      final collection = beerFeatureCollection([
        _beer(1, lat: 53.34, lng: -6.26),
      ]);

      expect(collection['type'], 'FeatureCollection');
      expect((collection['features'] as List).single, {
        'type': 'Feature',
        'id': 'beer-1',
        'geometry': {
          'type': 'Point',
          'coordinates': [-6.26, 53.34],
        },
        'properties': {'beer_id': 'beer-1'},
      });
    });

    test('breweries: same shape with brewery_id', () {
      final collection = breweryFeatureCollection([_brewery(7, lat: 10.5)]);

      final feature = (collection['features'] as List).single as Map;
      expect(feature['id'], 'brewery-7');
      expect(feature['properties'], {'brewery_id': 'brewery-7'});
      expect((feature['geometry'] as Map)['coordinates'], [7.0, 10.5]);
    });

    test('empty input gives an empty, valid collection', () {
      expect(beerFeatureCollection([]), {
        'type': 'FeatureCollection',
        'features': <Object>[],
      });
    });
  });

  group('first sync', () {
    test('uploads both sources and sets every layer\'s visibility', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);

      await sync.sync(() => _snap(beers: _beers(3)));

      expect(surface.shown[_beersSource], ['beer-0', 'beer-1', 'beer-2']);
      expect(surface.shown[_breweriesSource], isEmpty);
      for (final layer in _beerLayers) {
        expect(surface.visible[layer], isTrue, reason: layer);
      }
      for (final layer in _breweryLayers) {
        expect(surface.visible[layer], isFalse, reason: layer);
      }
      expect(surface.sourceUploads, 2);
      expect(surface.visibilityCalls, 6);
    });

    test('breweries mode shows brewery layers and hides beer layers', () async {
      final surface = _RecordingSurface();

      await _sync(surface)
          .sync(() => _snap(breweries: _breweries(2), mode: MapMode.breweries));

      for (final layer in _beerLayers) {
        expect(surface.visible[layer], isFalse, reason: layer);
      }
      for (final layer in _breweryLayers) {
        expect(surface.visible[layer], isTrue, reason: layer);
      }
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
        await sync.sync(
          () => _snap(beers: _beers(20), breweries: _breweries(5)),
        );
        surface.clear();

        // A pull-to-refresh returns freshly parsed objects with identical data.
        await sync.sync(
          () => _snap(beers: _beers(20), breweries: _breweries(5)),
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

      expect(surface.calls.map((c) => c.toString()), [
        'source:$_beersSource=11',
      ]);
    });

    test('changed breweries re-upload ONLY the breweries source', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(() => _snap(breweries: _breweries(4)));
      surface.clear();

      await sync.sync(() => _snap(breweries: _breweries(5)));

      expect(surface.calls.map((c) => c.toString()), [
        'source:$_breweriesSource=5',
      ]);
    });

    test(
      'the fingerprint notices a moved point, a swapped id, and a count change',
      () async {
        final surface = _RecordingSurface();
        final sync = _sync(surface);
        final base = [_beer(1), _beer(2)];
        await sync.sync(() => _snap(beers: base));

        for (final changed in [
          [_beer(1, lat: 60), _beer(2)], // moved latitude
          [_beer(1, lat: 60, lng: 100), _beer(2)], // moved longitude
          [_beer(1, lat: 60, lng: 100), _beer(99)], // different id
          [_beer(1, lat: 60, lng: 100)], // fewer points
        ]) {
          surface.clear();
          await sync.sync(() => _snap(beers: changed));
          expect(surface.sourceUploads, 1, reason: '$changed');
        }
      },
    );

    test(
      'changing between beer modes never touches layer visibility',
      () async {
        final surface = _RecordingSurface();
        final sync = _sync(surface);
        await sync.sync(() => _snap(beers: _beers(5), mode: MapMode.all));
        surface.clear();

        for (final mode in [
          MapMode.tried,
          MapMode.favorites,
          MapMode.wishlist,
        ]) {
          await sync.sync(() => _snap(beers: _beers(5), mode: mode));
        }

        expect(surface.visibilityCalls, 0);
      },
    );

    test(
      'flipping beers<->breweries sets all six layers exactly once',
      () async {
        final surface = _RecordingSurface();
        final sync = _sync(surface);
        await sync.sync(() => _snap(beers: _beers(3)));
        surface.clear();

        await sync.sync(
          () => _snap(breweries: _breweries(3), mode: MapMode.breweries),
        );

        expect(surface.visibilityCalls, 6);
        expect(surface.visible[_beerLayers.first], isFalse);
        expect(surface.visible[_breweryLayers.first], isTrue);

        surface.clear();
        await sync.sync(
          () => _snap(breweries: _breweries(3), mode: MapMode.breweries),
        );
        expect(surface.calls, isEmpty);
      },
    );
  });

  group('invalidate (the style reloaded and the sources are empty again)', () {
    test('forces a full re-upload on the next sync', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      await sync.sync(() => _snap(beers: _beers(8)));
      surface.clear();

      sync.invalidate();
      await sync.sync(() => _snap(beers: _beers(8)));

      expect(surface.sourceUploads, 2);
      expect(surface.visibilityCalls, 6);
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
        // 8 requests collapsed to far fewer uploads than the 16 the old code made.
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
      expect(surface.visible[_beerLayers.first], isTrue);
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

  group('evidence: a scripted user session', () {
    // Each entry is one controller notification, as MapController emits them:
    // a load notifies at its START (still holding the previous data) and at its
    // END (holding the result). Mode/search changes each start a load.
    final beersAll = _beers(2000);
    final beersTried = _beers(1100);
    final beersSearch = _beers(40);
    final breweries = _breweries(1500);
    final script = <(String, MapSnapshot)>[
      ('initial load: start', _snap()),
      ('initial load: end', _snap(beers: beersAll)),
      ('switch to Tried: start', _snap(beers: beersAll, mode: MapMode.tried)),
      ('switch to Tried: end', _snap(beers: beersTried, mode: MapMode.tried)),
      ('search: start', _snap(beers: beersTried, mode: MapMode.tried)),
      ('search: end', _snap(beers: beersSearch, mode: MapMode.tried)),
      (
        'switch to Breweries: start',
        _snap(beers: beersSearch, mode: MapMode.breweries),
      ),
      (
        'switch to Breweries: end',
        _snap(breweries: breweries, mode: MapMode.breweries),
      ),
      (
        'pull-to-refresh: start',
        _snap(breweries: breweries, mode: MapMode.breweries),
      ),
      (
        'pull-to-refresh: end (same data)',
        _snap(breweries: _breweries(1500), mode: MapMode.breweries),
      ),
    ];

    test('platform calls: new algorithm vs the old one', () async {
      // The old _syncMapData: 2 setGeoJsonSource + 6 setLayerVisibility on
      // EVERY notification, unconditionally.
      const oldCallsPerNotification = 2 + 6;
      final oldTotal = script.length * oldCallsPerNotification;

      final surface = _RecordingSurface();
      final sync = _sync(surface);
      sync.invalidate(); // sources were just created
      for (final (_, snapshot) in script) {
        await sync.sync(() => snapshot);
      }
      final newTotal = surface.calls.length;

      // ignore: avoid_print
      print(
        'map sync over ${script.length} notifications: old=$oldTotal calls '
        '(${script.length * 2} source uploads), new=$newTotal calls '
        '(${surface.sourceUploads} source uploads)',
      );
      expect(oldTotal, 80);
      expect(newTotal, lessThan(oldTotal ~/ 2));
      expect(surface.sourceUploads, lessThan(script.length * 2 ~/ 2));
    });

    test('and the map still ends up showing exactly the final state', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      for (final (_, snapshot) in script) {
        await sync.sync(() => snapshot);
      }

      expect(surface.shown[_breweriesSource], hasLength(1500));
      expect(surface.shown[_beersSource], isEmpty);
      expect(surface.visible[_breweryLayers.first], isTrue);
      expect(surface.visible[_beerLayers.first], isFalse);
    });

    test('an exact, documented call count for this script', () async {
      final surface = _RecordingSurface();
      final sync = _sync(surface);
      sync.invalidate();
      for (final (_, snapshot) in script) {
        await sync.sync(() => snapshot);
      }

      // Traced by hand, notification by notification:
      //  1. initial start        -> both sources (2) + all 6 layers
      //  2. initial end          -> beers (1)
      //  4. Tried end            -> beers (1)
      //  6. search end           -> beers (1)
      //  7. Breweries start      -> 6 layers flip (no upload: data unchanged)
      //  8. Breweries end        -> beers cleared (1) + breweries (1)
      //  3,5,9,10 (starts and a same-data refresh) -> nothing.
      expect(surface.sourceUploads, 7);
      expect(surface.visibilityCalls, 12);
      expect(surface.calls, hasLength(19)); // versus 80 before
    });
  });
}
