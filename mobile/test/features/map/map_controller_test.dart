import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:beerapp/features/map/domain/map_mode.dart';
import 'package:beerapp/features/map/domain/models/map_beer.dart';
import 'package:beerapp/features/map/domain/models/map_brewery.dart';
import 'package:beerapp/features/map/domain/models/map_result.dart';
import 'package:beerapp/features/map/presentation/map_controller.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_map_repository.dart';

MapBeer _beer(
  String id, {
  bool tried = false,
  bool favorite = false,
  bool wishlist = false,
}) => MapBeer(
  beerId: id,
  officialName: 'Beer $id',
  breweryName: 'Brewery',
  latitude: 50.0,
  longitude: 5.0,
  isTried: tried,
  isFavorite: favorite,
  isWishlist: wishlist,
);

MapBrewery _brewery(String id) => MapBrewery(
  breweryId: id,
  name: 'Brewery $id',
  latitude: 50.0,
  longitude: 5.0,
  verified: false,
);

MapController _controller({
  FakeMapRepository? repository,
  FakeCatalogRepository? catalogRepository,
  CollectionRefreshSignal? refreshSignal,
}) {
  return MapController(
    repository: repository ?? FakeMapRepository(),
    catalogRepository: catalogRepository ?? FakeCatalogRepository(),
    refreshSignal: refreshSignal ?? CollectionRefreshSignal(),
  );
}

void main() {
  test('loadInitial populates beers from the default (All) mode', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1'), _beer('2')],
        truncated: false,
      );
    final controller = _controller(repository: repository);

    await controller.loadInitial();

    expect(controller.beers, hasLength(2));
    expect(controller.breweries, isEmpty);
    expect(controller.mode, MapMode.all);
    expect(controller.error, isNull);
    expect(controller.truncated, isFalse);
  });

  test('setMode switches to the requested mode and reloads', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('all-1')],
        truncated: false,
      )
      ..beersByRequest['tried||'] = MapResult(
        items: [_beer('tried-1', tried: true)],
        truncated: false,
      );
    final controller = _controller(repository: repository);
    await controller.loadInitial();
    expect(controller.beers.map((b) => b.beerId), ['all-1']);

    await controller.setMode(MapMode.tried);

    expect(controller.mode, MapMode.tried);
    expect(controller.beers.map((b) => b.beerId), ['tried-1']);
  });

  test('setMode to the already-selected mode is a no-op', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1')],
        truncated: false,
      );
    final controller = _controller(repository: repository);
    await controller.loadInitial();
    repository.callLog.clear();

    await controller.setMode(MapMode.all);

    expect(repository.callLog, isEmpty);
  });

  test('switching to Breweries mode clears beers and populates breweries; switching back clears breweries', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1')],
        truncated: false,
      )
      ..breweriesByRequest['|'] = MapResult(
        items: [_brewery('b1')],
        truncated: false,
      );
    final controller = _controller(repository: repository);
    await controller.loadInitial();
    expect(controller.beers, hasLength(1));

    await controller.setMode(MapMode.breweries);

    expect(controller.breweries, hasLength(1));
    expect(
      controller.beers,
      isEmpty,
      reason: 'never both layers populated at once (single-select mode)',
    );

    await controller.setMode(MapMode.all);

    expect(controller.beers, hasLength(1));
    expect(controller.breweries, isEmpty);
  });

  test(
    'a mode switch invalidates an in-flight load from the previous mode',
    () async {
      final repository = FakeMapRepository()
        ..extraDelayByCallKey['getMapBeers:all||'] = const Duration(
          milliseconds: 50,
        )
        ..beersByRequest['all||'] = MapResult(
          items: [_beer('all-1')],
          truncated: false,
        )
        ..beersByRequest['tried||'] = MapResult(
          items: [_beer('tried-1', tried: true)],
          truncated: false,
        );
      final controller = _controller(repository: repository);

      final initialFuture = controller.loadInitial();
      await controller.setMode(MapMode.tried);
      expect(controller.beers.map((b) => b.beerId), ['tried-1']);

      await initialFuture;

      // The slow initial "all" response must not have overwritten the
      // newer "tried" result once it finally resolves.
      expect(controller.beers.map((b) => b.beerId), ['tried-1']);
    },
  );

  test('setQuery resolves an exact country-name match to country_id, not free-text q', () async {
    final catalogRepository = FakeCatalogRepository()
      ..countries = [
        const Country(
          id: 'country-1',
          isoCode: 'BE',
          name: 'Belgium',
          continent: 'Europe',
        ),
      ];
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1')],
        truncated: false,
      )
      ..beersByRequest['all|country-1|'] = MapResult(
        items: [_beer('be-1')],
        truncated: false,
      );
    final controller = _controller(
      repository: repository,
      catalogRepository: catalogRepository,
    );
    await controller.loadInitial();

    controller.setQuery('  belgium  ');
    await Future<void>.delayed(MapController.searchDebounce * 2);

    expect(controller.appliedCountryId, 'country-1');
    expect(controller.beers.map((b) => b.beerId), ['be-1']);
  });

  test(
    'setQuery with no exact country match sends free-text q, not country_id',
    () async {
      final catalogRepository = FakeCatalogRepository()
        ..countries = [
          const Country(
            id: 'country-1',
            isoCode: 'BE',
            name: 'Belgium',
            continent: 'Europe',
          ),
        ];
      final repository = FakeMapRepository()
        ..beersByRequest['all||'] = MapResult(
          items: [_beer('1')],
          truncated: false,
        )
        ..beersByRequest['all||achouffe'] = MapResult(
          items: [_beer('achouffe-1')],
          truncated: false,
        );
      final controller = _controller(
        repository: repository,
        catalogRepository: catalogRepository,
      );
      await controller.loadInitial();

      controller.setQuery('achouffe');
      await Future<void>.delayed(MapController.searchDebounce * 2);

      expect(controller.appliedCountryId, isNull);
      expect(controller.beers.map((b) => b.beerId), ['achouffe-1']);
    },
  );

  test('a partial country-name match is never treated as a country', () async {
    final catalogRepository = FakeCatalogRepository()
      ..countries = [
        const Country(
          id: 'country-1',
          isoCode: 'BE',
          name: 'Belgium',
          continent: 'Europe',
        ),
      ];
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1')],
        truncated: false,
      )
      ..beersByRequest['all||belg'] = MapResult(
        items: [_beer('partial-1')],
        truncated: false,
      );
    final controller = _controller(
      repository: repository,
      catalogRepository: catalogRepository,
    );
    await controller.loadInitial();

    controller.setQuery('belg');
    await Future<void>.delayed(MapController.searchDebounce * 2);

    expect(controller.appliedCountryId, isNull);
    expect(controller.beers.map((b) => b.beerId), ['partial-1']);
  });

  test(
    'clearing the search (blank text) clears both country_id and q',
    () async {
      final catalogRepository = FakeCatalogRepository()
        ..countries = [
          const Country(
            id: 'country-1',
            isoCode: 'BE',
            name: 'Belgium',
            continent: 'Europe',
          ),
        ];
      final repository = FakeMapRepository()
        ..beersByRequest['all||'] = MapResult(
          items: [_beer('all-1')],
          truncated: false,
        )
        ..beersByRequest['all|country-1|'] = MapResult(
          items: [_beer('be-1')],
          truncated: false,
        );
      final controller = _controller(
        repository: repository,
        catalogRepository: catalogRepository,
      );
      await controller.loadInitial();
      controller.setQuery('Belgium');
      await Future<void>.delayed(MapController.searchDebounce * 2);
      expect(controller.beers.map((b) => b.beerId), ['be-1']);

      controller.setQuery('');
      await Future<void>.delayed(Duration.zero);

      expect(controller.query, isEmpty);
      expect(controller.appliedCountryId, isNull);
      expect(controller.beers.map((b) => b.beerId), ['all-1']);
    },
  );

  test(
    'a search change invalidates an in-flight load from a previous search',
    () async {
      final repository = FakeMapRepository()
        ..extraDelayByCallKey['getMapBeers:all||'] = const Duration(
          milliseconds: 50,
        )
        ..beersByRequest['all||'] = MapResult(
          items: [_beer('all-1')],
          truncated: false,
        )
        ..beersByRequest['all||stout'] = MapResult(
          items: [_beer('stout-1')],
          truncated: false,
        );
      final controller = _controller(repository: repository);

      final initialFuture = controller.loadInitial();
      controller.setQuery('stout');
      await Future<void>.delayed(MapController.searchDebounce * 2);
      expect(controller.beers.map((b) => b.beerId), ['stout-1']);

      await initialFuture;

      expect(controller.beers.map((b) => b.beerId), ['stout-1']);
    },
  );

  test('truncated flag is exposed from the repository result', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1')],
        truncated: true,
      );
    final controller = _controller(repository: repository);

    await controller.loadInitial();

    expect(controller.truncated, isTrue);
  });

  test(
    'refresh preserves existing markers on failure rather than clearing them',
    () async {
      final repository = FakeMapRepository()
        ..beersByRequest['all||'] = MapResult(
          items: [_beer('1')],
          truncated: false,
        );
      final controller = _controller(repository: repository);
      await controller.loadInitial();

      repository.getMapBeersError = Exception('network blip');
      await controller.refresh();

      expect(controller.beers.map((b) => b.beerId), ['1']);
      expect(controller.error, isNotNull);
    },
  );

  test('refreshSignal.notifyChanged() triggers a refresh of the currently active mode', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['tried||'] = MapResult(
        items: [_beer('1', tried: true)],
        truncated: false,
      );
    final refreshSignal = CollectionRefreshSignal();
    final controller = _controller(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    controller.mode = MapMode.tried;
    await controller.loadInitial();
    repository.callLog.clear();

    // Simulates a beer-log/favorite mutation elsewhere firing the shared
    // signal -- nothing here ever calls controller.refresh() directly.
    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(
      repository.callLog.where((c) => c.startsWith('getMapBeers:tried')),
      hasLength(1),
    );
  });

  test('a signal ping that resolves after a newer mode switch never overwrites the newer result', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('all-1')],
        truncated: false,
      )
      ..beersByRequest['tried||'] = MapResult(
        items: [_beer('tried-1', tried: true)],
        truncated: false,
      );
    final refreshSignal = CollectionRefreshSignal();
    final controller = _controller(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();

    // The signal's refresh() call re-fetches "all" slowly...
    repository.extraDelayByCallKey['getMapBeers:all||'] = const Duration(
      milliseconds: 50,
    );
    refreshSignal.notifyChanged();
    // ...but a mode switch to "tried" happens before that slow refresh
    // resolves, and must win.
    await controller.setMode(MapMode.tried);
    expect(controller.beers.map((b) => b.beerId), ['tried-1']);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.beers.map((b) => b.beerId), ['tried-1']);
    expect(controller.mode, MapMode.tried);
  });

  test('dispose stops listening to the refresh signal', () async {
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = const MapResult(items: [], truncated: false);
    final refreshSignal = CollectionRefreshSignal();
    final controller = _controller(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    controller.dispose();
    repository.callLog.clear();

    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(repository.callLog, isEmpty);
  });

  test('a country-lookup failure never blocks the map itself, and search falls back to free-text', () async {
    final catalogRepository = FakeCatalogRepository()
      ..getCountriesError = Exception('lookup service down');
    final repository = FakeMapRepository()
      ..beersByRequest['all||'] = MapResult(
        items: [_beer('1')],
        truncated: false,
      )
      ..beersByRequest['all||belgium'] = MapResult(
        items: [_beer('2')],
        truncated: false,
      );
    final controller = _controller(
      repository: repository,
      catalogRepository: catalogRepository,
    );

    await controller.loadInitial();
    expect(controller.beers, hasLength(1));
    expect(controller.error, isNull);

    controller.setQuery('belgium');
    await Future<void>.delayed(MapController.searchDebounce * 2);

    expect(controller.appliedCountryId, isNull);
    expect(controller.beers.map((b) => b.beerId), ['2']);
  });
}
