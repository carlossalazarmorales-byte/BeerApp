import 'package:flutter/foundation.dart';

import '../../domain/catalog_repository.dart';
import '../../domain/models/beer.dart';
import '../catalog_debug_log.dart';

/// Drives the Discover tab's beer list: first-page load (plus the
/// country/style name lookups list tiles need), pull-to-refresh, and
/// infinite-scroll pagination -- with explicit guards so concurrent or
/// redundant loads can't duplicate/interleave pages.
class BeerListController extends ChangeNotifier {
  BeerListController({required this._repository});

  final CatalogRepository _repository;

  List<Beer> items = [];
  Map<String, String> styleNames = {};
  Map<String, String> countryNames = {};
  bool isLoadingInitial = false;
  bool isLoadingMore = false;
  bool hasMore = true;

  /// Full-screen error from the first page failing.
  Object? error;

  /// Inline, append-position error from a later page failing -- existing
  /// [items] stay visible when this is set.
  Object? loadMoreError;

  int _nextPage = 1;

  Future<void> loadInitial() => _loadFirstPage();

  Future<void> refresh() => _loadFirstPage();

  Future<void> _loadFirstPage() async {
    if (isLoadingInitial) return;
    isLoadingInitial = true;
    error = null;
    loadMoreError = null;
    notifyListeners();
    try {
      // Started together, not awaited in sequence, so all three are
      // in-flight concurrently (getCountries/getBeerStyles are cheap after
      // their first call, since the repository caches them).
      final beersFuture = _repository.getBeers(page: 1);
      final countriesFuture = _repository.getCountries();
      final stylesFuture = _repository.getBeerStyles();

      final result = await beersFuture;
      final countries = await countriesFuture;
      final styles = await stylesFuture;

      items = result.items;
      countryNames = {for (final c in countries) c.id: c.name};
      styleNames = {for (final s in styles) s.id: s.name};
      _nextPage = 2;
      hasMore = items.length < result.total;
    } catch (e, st) {
      error = e;
      logCatalogError('BeerListController.loadInitial', e, st);
    } finally {
      isLoadingInitial = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingInitial || isLoadingMore || !hasMore) return;
    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getBeers(page: _nextPage);
      items = [...items, ...result.items];
      _nextPage += 1;
      hasMore = items.length < result.total;
    } catch (e, st) {
      loadMoreError = e;
      logCatalogError('BeerListController.loadMore', e, st);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }
}
