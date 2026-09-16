import 'package:flutter/foundation.dart';

import '../../../shared/collection_refresh_signal.dart';
import '../../catalog/domain/catalog_filter_options.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/brewery.dart';
import '../../catalog/domain/models/paged_result.dart';
import '../domain/collection_repository.dart';
import '../domain/collection_sort.dart';
import '../domain/collection_tab.dart';
import '../domain/models/collection_beer.dart';
import 'collection_debug_log.dart';

/// Drives the Collection screen: which tab is active, filters/sort (shared
/// across all three tabs, matching "filters and sort apply within whichever
/// tab is active"), first-page load, pull-to-refresh, infinite-scroll
/// pagination, and filter-option loading -- with the same stale-response
/// guards as `DiscoverController`/`BeerLogController`.
///
/// Also listens to [CollectionRefreshSignal]: any successful mutation
/// elsewhere (a beer log, a favorite/wishlist change) calls [refresh] here,
/// regardless of which tab is active or whether this screen is currently
/// visible -- see the signal's own doc comment for why no navigation-aware
/// mechanism is needed for that.
class CollectionController extends ChangeNotifier {
  CollectionController({
    required this._repository,
    required this._catalogRepository,
    required this._refreshSignal,
  }) {
    _refreshSignal.addListener(_onExternalChange);
  }

  static const int _pageSize = 20;

  final CollectionRepository _repository;
  final CatalogRepository _catalogRepository;
  final CollectionRefreshSignal _refreshSignal;

  CollectionTab tab = CollectionTab.logged;
  CollectionSort sort = CollectionSort.recent;

  /// The applied filters. Distinct from any draft selection held locally by
  /// the filter bottom sheet while it's open -- nothing here changes until
  /// [applyFilters] is called.
  String? appliedCountryId;
  String? appliedStyleId;
  String? appliedBreweryId;

  Map<String, String> countryNames = {};
  Map<String, String> styleNames = {};
  List<Brewery> breweryOptions = [];

  List<CollectionBeer> items = [];
  bool isLoadingInitial = false;
  bool isLoadingMore = false;
  bool hasMore = false;

  /// Full-screen error from the first page failing.
  Object? error;

  /// Inline, append-position error from a later page failing -- existing
  /// [items] stay visible when this is set.
  Object? loadMoreError;

  int _nextPage = 1;
  int _requestId = 0;

  bool get hasActiveFilters =>
      appliedCountryId != null ||
      appliedStyleId != null ||
      appliedBreweryId != null;

  int get activeFilterCount => [
    appliedCountryId,
    appliedStyleId,
    appliedBreweryId,
  ].whereType<String>().length;

  Future<void> loadInitial() {
    return Future.wait([_loadFirstPage(), _loadFilterOptions()]);
  }

  Future<void> setTab(CollectionTab newTab) {
    if (newTab == tab) return Future<void>.value();
    tab = newTab;
    return _loadFirstPage();
  }

  Future<void> setSort(CollectionSort newSort) {
    if (newSort == sort) return Future<void>.value();
    sort = newSort;
    return _loadFirstPage();
  }

  /// The single mutator for filter changes -- sets all three atomically and
  /// triggers exactly one reload of the active tab. Used both by the filter
  /// sheet's "Show results" and by removing one active-filter chip.
  Future<void> applyFilters({
    String? countryId,
    String? styleId,
    String? breweryId,
  }) {
    appliedCountryId = countryId;
    appliedStyleId = styleId;
    appliedBreweryId = breweryId;
    return _loadFirstPage();
  }

  Future<void> clearFilters() =>
      applyFilters(countryId: null, styleId: null, breweryId: null);

  // A plain pull-to-refresh (or an external mutation signal) re-fetches the
  // *same* tab/query, so a transient failure preserves the still-valid
  // existing list rather than replacing it with a full-screen error.
  Future<void> refresh() => _loadFirstPage(preserveItemsOnError: true);

  Future<PagedResult<CollectionBeer>> _fetchPage(int page) {
    switch (tab) {
      case CollectionTab.logged:
        return _repository.getLogged(
          page: page,
          pageSize: _pageSize,
          countryId: appliedCountryId,
          styleId: appliedStyleId,
          breweryId: appliedBreweryId,
          sort: sort,
        );
      case CollectionTab.favorites:
        return _repository.getFavorites(
          page: page,
          pageSize: _pageSize,
          countryId: appliedCountryId,
          styleId: appliedStyleId,
          breweryId: appliedBreweryId,
          sort: sort,
        );
      case CollectionTab.wishlist:
        return _repository.getWishlist(
          page: page,
          pageSize: _pageSize,
          countryId: appliedCountryId,
          styleId: appliedStyleId,
          breweryId: appliedBreweryId,
          sort: sort,
        );
    }
  }

  Future<void> _loadFirstPage({bool preserveItemsOnError = false}) async {
    final generation = ++_requestId;
    isLoadingInitial = true;
    error = null;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _fetchPage(1);
      if (generation != _requestId) return;
      items = result.items;
      _nextPage = 2;
      hasMore = items.length < result.total;
    } catch (e, st) {
      if (generation != _requestId) return;
      error = e;
      if (!preserveItemsOnError) items = [];
      logCollectionError('CollectionController.loadFirstPage', e, st);
    } finally {
      if (generation == _requestId) {
        isLoadingInitial = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoadingInitial || isLoadingMore || !hasMore) return;
    // Not incremented -- this request belongs to the current generation.
    final generation = _requestId;
    final page = _nextPage;
    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _fetchPage(page);
      if (generation == _requestId) {
        items = [...items, ...result.items];
        _nextPage = page + 1;
        hasMore = items.length < result.total;
      }
    } catch (e, st) {
      if (generation == _requestId) {
        loadMoreError = e;
        logCollectionError('CollectionController.loadMore', e, st);
      }
    } finally {
      if (generation == _requestId) {
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final lookups = await loadCatalogNameLookups(_catalogRepository);
      countryNames = lookups.countryNames;
      styleNames = lookups.styleNames;
      notifyListeners();
    } catch (e, st) {
      // Filter *options* are cosmetic here too (see DiscoverController) --
      // a failure never blocks the Collection list itself.
      logCollectionError('CollectionController.loadFilterOptions', e, st);
    }
    try {
      breweryOptions = await loadBreweryFilterOptions(_catalogRepository);
      notifyListeners();
    } catch (e, st) {
      logCollectionError('CollectionController.loadBreweryOptions', e, st);
    }
  }

  void _onExternalChange() {
    refresh();
  }

  @override
  void dispose() {
    _refreshSignal.removeListener(_onExternalChange);
    super.dispose();
  }
}
