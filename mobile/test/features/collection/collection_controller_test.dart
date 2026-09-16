import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/collection/domain/collection_tab.dart';
import 'package:beerapp/features/collection/domain/models/collection_beer.dart';
import 'package:beerapp/features/collection/presentation/collection_controller.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_collection_repository.dart';

CollectionBeer _beer(String id) => CollectionBeer(
  beerId: id,
  officialName: 'Beer $id',
  breweryName: 'Brewery',
  isFavorite: false,
  isWishlist: false,
);

void main() {
  test('loadInitial populates items from the default (Logged) tab', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('1'), _beer('2')],
        page: 1,
        pageSize: 20,
        total: 2,
      );
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.items, hasLength(2));
    expect(controller.error, isNull);
    expect(controller.hasMore, isFalse);
  });

  test('setTab switches to the requested tab and reloads', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('logged-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..favoritesByPage[1] = PagedResult(
        items: [_beer('fav-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    expect(controller.items.map((b) => b.beerId), ['logged-1']);

    await controller.setTab(CollectionTab.favorites);

    expect(controller.tab, CollectionTab.favorites);
    expect(controller.items.map((b) => b.beerId), ['fav-1']);
  });

  test('setTab to the already-selected tab is a no-op', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    repository.callLog.clear();

    await controller.setTab(CollectionTab.logged);

    expect(repository.callLog, isEmpty);
  });

  test('loadMore appends the next page of the currently active tab', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 1,
        total: 2,
      )
      ..loggedByPage[2] = PagedResult(
        items: [_beer('2')],
        page: 2,
        pageSize: 1,
        total: 2,
      );
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    await controller.loadMore();

    expect(controller.items.map((b) => b.beerId), ['1', '2']);
    expect(controller.hasMore, isFalse);
  });

  test(
    'a tab switch invalidates an in-flight loadMore from the previous tab',
    () async {
      final repository = FakeCollectionRepository()
        ..loggedByPage[1] = PagedResult(
          items: [_beer('logged-1')],
          page: 1,
          pageSize: 1,
          total: 2,
        )
        ..loggedByPage[2] = PagedResult(
          items: [_beer('logged-2')],
          page: 2,
          pageSize: 1,
          total: 2,
        )
        ..favoritesByPage[1] = PagedResult(
          items: [_beer('fav-1')],
          page: 1,
          pageSize: 20,
          total: 1,
        )
        ..getLoggedError = null;
      final controller = CollectionController(
        repository: repository,
        catalogRepository: FakeCatalogRepository(),
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();

      final loadMoreFuture = controller.loadMore();
      await controller.setTab(CollectionTab.favorites);
      expect(controller.items.map((b) => b.beerId), ['fav-1']);

      await loadMoreFuture;

      // loadMore's page-2 Logged response must not have been appended once
      // the tab switch already superseded it.
      expect(controller.items.map((b) => b.beerId), ['fav-1']);
    },
  );

  test(
    'applyFilters sets all three filters atomically in one request',
    () async {
      final repository = FakeCollectionRepository()
        ..loggedByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 20,
          total: 1,
        );
      final controller = CollectionController(
        repository: repository,
        catalogRepository: FakeCatalogRepository(),
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();
      repository.callLog.clear();

      await controller.applyFilters(
        styleId: 'style-1',
        countryId: 'country-1',
        breweryId: 'brewery-1',
      );

      expect(
        repository.callLog.where((c) => c.startsWith('getLogged')),
        hasLength(1),
      );
      expect(controller.appliedStyleId, 'style-1');
      expect(controller.appliedCountryId, 'country-1');
      expect(controller.appliedBreweryId, 'brewery-1');
      expect(controller.activeFilterCount, 3);
    },
  );

  test('clearFilters restores the unfiltered list in one reload', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('all-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    await controller.applyFilters(breweryId: 'brewery-1');

    await controller.clearFilters();

    expect(controller.hasActiveFilters, isFalse);
    expect(controller.items.map((b) => b.beerId), ['all-1']);
  });

  test(
    'refresh preserves existing items on failure rather than clearing them',
    () async {
      final repository = FakeCollectionRepository()
        ..loggedByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 20,
          total: 1,
        );
      final controller = CollectionController(
        repository: repository,
        catalogRepository: FakeCatalogRepository(),
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();

      repository.getLoggedError = Exception('network blip');
      await controller.refresh();

      expect(controller.items.map((b) => b.beerId), ['1']);
      expect(controller.error, isNotNull);
    },
  );

  test('refreshSignal.notifyChanged() triggers a refresh even for a controller '
      'that is not the active/visible screen', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final refreshSignal = CollectionRefreshSignal();
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    repository.callLog.clear();

    // Simulates a mutation elsewhere (e.g. a beer log created from Beer
    // Detail) firing the shared signal -- nothing here ever calls
    // controller.refresh() directly.
    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(
      repository.callLog.where((c) => c.startsWith('getLogged')),
      hasLength(1),
    );
  });

  test('dispose stops listening to the refresh signal', () async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = const PagedResult(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
      );
    final refreshSignal = CollectionRefreshSignal();
    final controller = CollectionController(
      repository: repository,
      catalogRepository: FakeCatalogRepository(),
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    controller.dispose();
    repository.callLog.clear();

    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(repository.callLog, isEmpty);
  });

  test(
    'a filter-option loading failure never blocks the collection list itself',
    () async {
      final repository = FakeCollectionRepository()
        ..loggedByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 20,
          total: 1,
        );
      final catalogRepository = FakeCatalogRepository()
        ..getCountriesError = Exception('lookup service down')
        ..getBreweriesError = Exception('lookup service down');
      final controller = CollectionController(
        repository: repository,
        catalogRepository: catalogRepository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();

      expect(controller.items, hasLength(1));
      expect(controller.error, isNull);
      expect(controller.countryNames, isEmpty);
      expect(controller.breweryOptions, isEmpty);
    },
  );
}
