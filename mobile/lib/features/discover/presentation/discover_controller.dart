import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog_filter_options.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/beer.dart';
import '../../catalog/domain/models/brewery.dart';
import '../../catalog/presentation/catalog_debug_log.dart';

/// Drives the Discover tab: text search, style/country/brewery filters,
/// first-page load, pull-to-refresh, and infinite-scroll pagination -- with
/// explicit guards so concurrent, redundant, or stale (superseded by a newer
/// query/filter) loads can't duplicate/interleave/overwrite results.
class DiscoverController extends ChangeNotifier {
  DiscoverController({required this._repository});

  static const Duration searchDebounce = Duration(milliseconds: 350);

  final CatalogRepository _repository;

  List<Beer> items = [];
  Map<String, String> styleNames = {};
  Map<String, String> countryNames = {};
  List<Brewery> breweryOptions = [];

  bool isLoadingInitial = false;
  bool isLoadingMore = false;
  bool hasMore = true;

  /// Full-screen error from the first page failing.
  Object? error;

  /// Inline, append-position error from a later page failing -- existing
  /// [items] stay visible when this is set.
  Object? loadMoreError;

  /// The applied search text (trimmed). Distinct from whatever's currently
  /// typed in the search field between keystrokes and the debounce firing.
  String query = '';

  /// The applied filters. Distinct from any draft selection held locally by
  /// the filter bottom sheet while it's open -- nothing here changes until
  /// [applyFilters] is called.
  String? appliedStyleId;
  String? appliedCountryId;
  String? appliedBreweryId;

  int _nextPage = 1;
  int _requestId = 0;
  Timer? _debounceTimer;

  bool get hasActiveFilters =>
      appliedStyleId != null ||
      appliedCountryId != null ||
      appliedBreweryId != null;

  int get activeFilterCount => [
    appliedStyleId,
    appliedCountryId,
    appliedBreweryId,
  ].whereType<String>().length;

  Future<void> loadInitial() async {
    await Future.wait([
      _loadFirstPage(),
      _loadLookups(),
      _loadBreweryOptions(),
    ]);
  }

  // A plain pull-to-refresh re-fetches the *same* query/filters, so a
  // transient failure preserves the still-valid existing list rather than
  // replacing it with a full-screen error (matching Phase 4's behavior). A
  // search/filter change is different: on failure there is no valid result
  // set to fall back to for the *new* query, so it clears items and shows
  // the error state instead of silently leaving the previous query's
  // unrelated results on screen.
  Future<void> refresh() => _loadFirstPage(preserveItemsOnError: true);

  /// Debounces the applied [query] by [searchDebounce]. Typing again cancels
  /// any pending timer; clearing to an empty string reloads immediately.
  void setQuery(String value) {
    final trimmed = value.trim();
    _debounceTimer?.cancel();
    if (trimmed.isEmpty) {
      if (query.isEmpty) return;
      query = '';
      unawaited(_loadFirstPage());
      return;
    }
    if (trimmed == query) return;
    _debounceTimer = Timer(searchDebounce, () {
      query = trimmed;
      unawaited(_loadFirstPage());
    });
  }

  /// The single mutator for filter changes -- sets all three atomically,
  /// resets to page 1, and triggers exactly one reload. Used both by the
  /// filter sheet's "Show results" (all three at once) and by removing one
  /// active-filter chip (the other two passed through unchanged).
  Future<void> applyFilters({
    String? styleId,
    String? countryId,
    String? breweryId,
  }) {
    // A filter change shouldn't let a stale pending search apply afterwards.
    _debounceTimer?.cancel();
    appliedStyleId = styleId;
    appliedCountryId = countryId;
    appliedBreweryId = breweryId;
    return _loadFirstPage();
  }

  Future<void> clearFilters() =>
      applyFilters(styleId: null, countryId: null, breweryId: null);

  Future<void> _loadFirstPage({bool preserveItemsOnError = false}) async {
    final generation = ++_requestId;
    final requestQuery = query;
    final requestStyleId = appliedStyleId;
    final requestCountryId = appliedCountryId;
    final requestBreweryId = appliedBreweryId;

    isLoadingInitial = true;
    error = null;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getBeers(
        page: 1,
        q: requestQuery.isEmpty ? null : requestQuery,
        styleId: requestStyleId,
        countryId: requestCountryId,
        breweryId: requestBreweryId,
      );
      if (generation != _requestId) return;

      items = result.items;
      _nextPage = 2;
      hasMore = items.length < result.total;
    } catch (e, st) {
      if (generation != _requestId) return;
      error = e;
      if (!preserveItemsOnError) items = [];
      logCatalogError('DiscoverController.loadInitial', e, st);
    } finally {
      if (generation == _requestId) {
        isLoadingInitial = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoadingInitial || isLoadingMore || !hasMore) return;
    final generation = _requestId;
    final requestQuery = query;
    final requestStyleId = appliedStyleId;
    final requestCountryId = appliedCountryId;
    final requestBreweryId = appliedBreweryId;
    final page = _nextPage;

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getBeers(
        page: page,
        q: requestQuery.isEmpty ? null : requestQuery,
        styleId: requestStyleId,
        countryId: requestCountryId,
        breweryId: requestBreweryId,
      );
      // A query/filter change (or a concurrent refresh) started a new
      // generation while this page was in flight -- its result no longer
      // corresponds to the current result set, so it's discarded rather
      // than appended. `isLoadingMore` still gets reset below regardless --
      // it's scoped to this one loadMore call, not to the generation, and a
      // newer `_loadFirstPage` neither reads nor resets it.
      if (generation == _requestId) {
        items = [...items, ...result.items];
        _nextPage = page + 1;
        hasMore = items.length < result.total;
      }
    } catch (e, st) {
      if (generation == _requestId) {
        loadMoreError = e;
      }
      logCatalogError('DiscoverController.loadMore', e, st);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadLookups() async {
    try {
      final lookups = await loadCatalogNameLookups(_repository);
      countryNames = lookups.countryNames;
      styleNames = lookups.styleNames;
      notifyListeners();
    } catch (e, st) {
      // Style/country name lookups are cosmetic (tile subtitles, filter
      // labels) -- a failure here shouldn't block the beer list itself,
      // which already surfaces its own error state independently.
      logCatalogError('DiscoverController.loadLookups', e, st);
    }
  }

  Future<void> _loadBreweryOptions() async {
    try {
      breweryOptions = await loadBreweryFilterOptions(_repository);
      notifyListeners();
    } catch (e, st) {
      logCatalogError('DiscoverController.loadBreweryOptions', e, st);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
