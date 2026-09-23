import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/discover/presentation/discover_controller.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_catalog_repository.dart';

Beer _beer(String id) => Beer(
  id: id,
  officialName: 'Beer $id',
  breweryId: 'brewery-1',
  verified: false,
);

Brewery _brewery(String id) => Brewery(
  id: id,
  name: 'Brewery $id',
  countryId: 'country-1',
  verified: false,
);

Future<void> _awaitDebounce() => Future<void>.delayed(
  DiscoverController.searchDebounce + const Duration(milliseconds: 50),
);

void main() {
  test('always requests untried_only=true, with no user-facing toggle to '
      'turn it off -- QA Round 1 Block 1\'s fixed product rule', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();
    expect(repository.receivedUntriedOnly, isTrue);

    await controller.applyFilters(styleId: 'style-1');
    expect(repository.receivedUntriedOnly, isTrue);
  });

  test('a CollectionRefreshSignal notification triggers a silent refresh, '
      'so a beer logged elsewhere (e.g. Add Beer) drops out without a new '
      'search/filter change -- QA Round 1 Block 1 follow-up', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1'), _beer('2')],
        page: 1,
        pageSize: 20,
        total: 2,
      );
    final refreshSignal = CollectionRefreshSignal();
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    expect(controller.items.map((b) => b.beer.id), ['1', '2']);

    repository.beersByPage[1] = PagedResult(
      items: [_beer('2')],
      page: 1,
      pageSize: 20,
      total: 1,
    );
    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(controller.items.map((b) => b.beer.id), ['2']);
  });

  test('the refresh-signal listener is removed on dispose (no leak / no '
      'reload attempt on an already-disposed controller)', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final refreshSignal = CollectionRefreshSignal();
    final controller = DiscoverController(
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

  test('excludes a beer the backend marks as already tried', () async {
    final repository = FakeCatalogRepository()
      ..triedBeerIds = {'1'}
      ..beersByPage[1] = PagedResult(
        items: [_beer('1'), _beer('2')],
        page: 1,
        pageSize: 20,
        total: 2,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    // The fake still returns both rows (it doesn't simulate server-side
    // filtering), but Discover's contract is that isTried is always
    // threaded through per item for the tile to act on.
    expect(controller.items.map((b) => (b.beer.id, b.isTried)), [
      ('1', true),
      ('2', false),
    ]);
  });

  test('loadInitial populates items on success', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1'), _beer('2')],
        page: 1,
        pageSize: 20,
        total: 2,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.items, hasLength(2));
    expect(controller.error, isNull);
    expect(controller.isLoadingInitial, isFalse);
    expect(controller.hasMore, isFalse);
  });

  test(
    'loadInitial surfaces a failure as a full-screen error, items empty',
    () async {
      final repository = FakeCatalogRepository()
        ..getBeersError = Exception('boom');
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();

      expect(controller.items, isEmpty);
      expect(controller.error, isNotNull);
    },
  );

  test(
    'an empty first page (no error) leaves items empty and error null',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = const PagedResult(
          items: [],
          page: 1,
          pageSize: 20,
          total: 0,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();

      expect(controller.items, isEmpty);
      expect(controller.error, isNull);
      expect(controller.hasMore, isFalse);
    },
  );

  test(
    'loadMore appends the next page and advances hasMore/page tracking',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 1,
          total: 3,
        )
        ..beersByPage[2] = PagedResult(
          items: [_beer('2')],
          page: 2,
          pageSize: 1,
          total: 3,
        )
        ..beersByPage[3] = PagedResult(
          items: [_beer('3')],
          page: 3,
          pageSize: 1,
          total: 3,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items.map((b) => b.beer.id), ['1', '2']);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items.map((b) => b.beer.id), ['1', '2', '3']);
      expect(controller.hasMore, isFalse);
    },
  );

  test('loadMore no-ops once hasMore is false', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    expect(controller.hasMore, isFalse);

    await controller.loadMore();

    expect(
      repository.callLog.where((c) => c.startsWith('getBeers')),
      hasLength(1),
    );
  });

  test(
    'concurrent loadMore calls do not duplicate or interleave pages',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 1,
          total: 3,
        )
        ..beersByPage[2] = PagedResult(
          items: [_beer('2')],
          page: 2,
          pageSize: 1,
          total: 3,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();

      final f1 = controller.loadMore();
      final f2 = controller.loadMore();
      await Future.wait([f1, f2]);

      expect(controller.items.map((b) => b.beer.id), ['1', '2']);
      expect(repository.callLog.where((c) => c == 'getBeers:2'), hasLength(1));
    },
  );

  test('a failed loadMore keeps existing items and sets loadMoreError without touching them', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 1,
        total: 3,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    repository.getBeersError = Exception('page 2 failed');
    await controller.loadMore();

    expect(controller.items.map((b) => b.beer.id), ['1']);
    expect(controller.loadMoreError, isNotNull);
    expect(controller.error, isNull);
  });

  test(
    'a retried loadMore after failure does not duplicate the recovered page',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 1,
          total: 2,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();

      repository.getBeersError = Exception('transient');
      await controller.loadMore();
      expect(controller.loadMoreError, isNotNull);

      repository.getBeersError = null;
      repository.beersByPage[2] = PagedResult(
        items: [_beer('2')],
        page: 2,
        pageSize: 1,
        total: 2,
      );
      await controller.loadMore();

      expect(controller.items.map((b) => b.beer.id), ['1', '2']);
      expect(controller.loadMoreError, isNull);
    },
  );

  test('refresh replaces items, resets to page 1, and clears both error fields, preserving old items on refresh failure', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 1,
        total: 2,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    repository.getBeersError = Exception('page 2 failed');
    await controller.loadMore();
    expect(controller.loadMoreError, isNotNull);

    repository.getBeersError = null;
    repository.beersByPage[1] = PagedResult(
      items: [_beer('9')],
      page: 1,
      pageSize: 1,
      total: 1,
    );
    await controller.refresh();

    expect(controller.items.map((b) => b.beer.id), ['9']);
    expect(controller.error, isNull);
    expect(controller.loadMoreError, isNull);
    expect(controller.hasMore, isFalse);
  });

  test('a failed refresh preserves the previously loaded items', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    repository.getBeersError = Exception('network blip');
    await controller.refresh();

    expect(controller.items.map((b) => b.beer.id), ['1']);
    expect(controller.error, isNotNull);
  });

  test('setQuery debounces: rapid calls trigger exactly one request', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = const PagedResult(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
      )
      ..beersByRequest['1|stout|||'] = PagedResult(
        items: [_beer('stout-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    repository.callLog.clear();

    controller.setQuery('s');
    controller.setQuery('st');
    controller.setQuery('stout');
    await _awaitDebounce();

    expect(
      repository.callLog.where((c) => c.startsWith('getBeers')),
      hasLength(1),
    );
    expect(controller.items.map((b) => b.beer.id), ['stout-1']);
    expect(controller.query, 'stout');
  });

  test('clearing the search field reloads immediately, no debounce', () async {
    final repository = FakeCatalogRepository()
      ..beersByRequest['1|stout|||'] = PagedResult(
        items: [_beer('stout-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..beersByPage[1] = PagedResult(
        items: [_beer('all-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    controller.setQuery('stout');
    await _awaitDebounce();
    expect(controller.items.map((b) => b.beer.id), ['stout-1']);

    controller.setQuery('');
    await Future<void>.delayed(Duration.zero);

    expect(controller.query, isEmpty);
    expect(controller.items.map((b) => b.beer.id), ['all-1']);
  });

  test('stale first-page response protection: a slower search does not overwrite a faster later one', () async {
    final repository = FakeCatalogRepository()
      ..beersByRequest['1|first|||'] = PagedResult(
        items: [_beer('first-result')],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..beersByRequest['1|second|||'] = PagedResult(
        items: [_beer('second-result')],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      // "first"'s request is made deliberately slow so it resolves *after*
      // "second"'s (fast) request has already applied its result -- the
      // scenario the generation guard exists for.
      ..extraDelayByCallKey['getBeers:1|first|||'] = const Duration(
        milliseconds: 100,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    controller.setQuery('first');
    await _awaitDebounce();
    final firstRequestFuture = Future<void>.delayed(
      const Duration(milliseconds: 150),
    ); // outlives "first"'s 100ms delay
    controller.setQuery('second');
    await _awaitDebounce();
    // By now "second" (no extra delay) has already resolved and applied.
    expect(controller.items.map((b) => b.beer.id), ['second-result']);

    // Let "first"'s slow, now-stale response resolve and confirm it does
    // not clobber "second"'s already-applied result.
    await firstRequestFuture;
    expect(controller.items.map((b) => b.beer.id), ['second-result']);
  });

  test('stale loadMore response protection: a filter change invalidates an in-flight loadMore', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 1,
        total: 3,
      )
      ..beersByPage[2] = PagedResult(
        items: [_beer('2')],
        page: 2,
        pageSize: 1,
        total: 3,
      )
      ..beersByRequest['1||||brewery-1'] = PagedResult(
        items: [_beer('filtered-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      // loadMore's page-2 request resolves well after the filter change's
      // fast (no extra delay) request already applied its own result.
      ..extraDelayByCallKey['getBeers:2'] = const Duration(milliseconds: 100);
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    final loadMoreFuture = controller.loadMore();
    // Fire a filter change (reloads immediately, no debounce) while
    // loadMore's slower request is still in flight.
    await controller.applyFilters(breweryId: 'brewery-1');
    expect(controller.items.map((b) => b.beer.id), ['filtered-1']);

    // loadMore's page-2 response must not be appended once it resolves
    // after the filter change already superseded it.
    await loadMoreFuture;
    expect(controller.items.map((b) => b.beer.id), ['filtered-1']);
  });

  test(
    'applyFilters sets all three filters atomically in one request',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 20,
          total: 1,
        )
        ..beersByRequest['1||country-1|style-1|brewery-1'] = PagedResult(
          items: [_beer('filtered')],
          page: 1,
          pageSize: 20,
          total: 1,
        );
      final controller = DiscoverController(
        repository: repository,
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
        repository.callLog.where((c) => c.startsWith('getBeers')),
        hasLength(1),
      );
      expect(controller.items.map((b) => b.beer.id), ['filtered']);
      expect(controller.appliedStyleId, 'style-1');
      expect(controller.appliedCountryId, 'country-1');
      expect(controller.appliedBreweryId, 'brewery-1');
      expect(controller.activeFilterCount, 3);
    },
  );

  test('clearFilters restores the unfiltered feed', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('all-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..beersByRequest['1||||brewery-1'] = PagedResult(
        items: [_beer('filtered')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    await controller.applyFilters(breweryId: 'brewery-1');
    expect(controller.items.map((b) => b.beer.id), ['filtered']);

    await controller.clearFilters();

    expect(controller.hasActiveFilters, isFalse);
    expect(controller.items.map((b) => b.beer.id), ['all-1']);
  });

  test('loadMore carries the current query and filters', () async {
    final repository = FakeCatalogRepository()
      ..beersByRequest['1|stout|||brewery-1'] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 1,
        total: 2,
      )
      ..beersByRequest['2|stout|||brewery-1'] = PagedResult(
        items: [_beer('2')],
        page: 2,
        pageSize: 1,
        total: 2,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    await controller.applyFilters(breweryId: 'brewery-1');
    controller.setQuery('stout');
    await _awaitDebounce();
    expect(controller.items.map((b) => b.beer.id), ['1']);

    await controller.loadMore();

    expect(controller.items.map((b) => b.beer.id), ['1', '2']);
  });

  test(
    'zero results after a search is distinguishable from an error',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByRequest['1|nomatch|||'] = const PagedResult(
          items: [],
          page: 1,
          pageSize: 20,
          total: 0,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();

      controller.setQuery('nomatch');
      await _awaitDebounce();

      expect(controller.items, isEmpty);
      expect(controller.error, isNull);
    },
  );

  test('dispose cancels a pending debounce timer', () async {
    final repository = FakeCatalogRepository()
      ..beersByRequest['1|stout|||'] = PagedResult(
        items: [_beer('stout-1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    controller.setQuery('stout');
    controller.dispose();
    // If the debounce timer weren't cancelled, this would fire setQuery's
    // callback, which calls notifyListeners() on a disposed ChangeNotifier
    // and throws.
    await _awaitDebounce();
  });

  test(
    'brewery options load a single page when the catalog fits within it',
    () async {
      final repository = FakeCatalogRepository()
        ..breweriesByPage[1] = PagedResult(
          items: [_brewery('1'), _brewery('2')],
          page: 1,
          pageSize: 100,
          total: 2,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();

      expect(controller.breweryOptions.map((b) => b.id), ['1', '2']);
      expect(
        repository.callLog.where((c) => c.startsWith('getBreweries')),
        hasLength(1),
      );
    },
  );

  test(
    'brewery options page through multiple pages until total is reached',
    () async {
      final repository = FakeCatalogRepository()
        ..breweriesByPage[1] = PagedResult(
          items: List.generate(100, (i) => _brewery('$i')),
          page: 1,
          pageSize: 100,
          total: 150,
        )
        ..breweriesByPage[2] = PagedResult(
          items: List.generate(50, (i) => _brewery('${100 + i}')),
          page: 2,
          pageSize: 100,
          total: 150,
        );
      final controller = DiscoverController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();

      expect(controller.breweryOptions, hasLength(150));
      expect(
        repository.callLog.where((c) => c.startsWith('getBreweries')),
        hasLength(2),
      );
    },
  );

  test('brewery options stop at the page cap without erroring when total exceeds it', () async {
    final repository = FakeCatalogRepository();
    for (var page = 1; page <= 6; page++) {
      repository.breweriesByPage[page] = PagedResult(
        items: List.generate(100, (i) => _brewery('${(page - 1) * 100 + i}')),
        page: page,
        pageSize: 100,
        total: 600,
      );
    }
    final controller = DiscoverController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.breweryOptions, hasLength(500));
    expect(
      repository.callLog.where((c) => c.startsWith('getBreweries')),
      hasLength(5),
    );
  });
}
