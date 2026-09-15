import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/catalog/presentation/beer_list/beer_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_catalog_repository.dart';

Beer _beer(String id) => Beer(
  id: id,
  officialName: 'Beer $id',
  breweryId: 'brewery-1',
  verified: false,
);

void main() {
  test('loadInitial populates items on success', () async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beer('1'), _beer('2')],
        page: 1,
        pageSize: 20,
        total: 2,
      );
    final controller = BeerListController(repository: repository);

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
      final controller = BeerListController(repository: repository);

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
      final controller = BeerListController(repository: repository);

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
      final controller = BeerListController(repository: repository);

      await controller.loadInitial();
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items.map((b) => b.id), ['1', '2']);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items.map((b) => b.id), ['1', '2', '3']);
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
    final controller = BeerListController(repository: repository);
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
      final controller = BeerListController(repository: repository);
      await controller.loadInitial();

      // Fired back-to-back, synchronously -- the second must no-op while the
      // first is still in flight.
      final f1 = controller.loadMore();
      final f2 = controller.loadMore();
      await Future.wait([f1, f2]);

      expect(controller.items.map((b) => b.id), ['1', '2']);
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
    final controller = BeerListController(repository: repository);
    await controller.loadInitial();

    repository.getBeersError = Exception('page 2 failed');
    await controller.loadMore();

    expect(controller.items.map((b) => b.id), ['1']);
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
      final controller = BeerListController(repository: repository);
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

      expect(controller.items.map((b) => b.id), ['1', '2']);
      expect(controller.loadMoreError, isNull);
    },
  );

  test(
    'refresh replaces items, resets to page 1, and clears both error fields',
    () async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beer('1')],
          page: 1,
          pageSize: 1,
          total: 2,
        );
      final controller = BeerListController(repository: repository);
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

      expect(controller.items.map((b) => b.id), ['9']);
      expect(controller.error, isNull);
      expect(controller.loadMoreError, isNull);
      expect(controller.hasMore, isFalse);
    },
  );
}
