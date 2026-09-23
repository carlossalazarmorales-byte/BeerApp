import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/discover_beer.dart';
import '../../catalog/presentation/catalog_debug_log.dart';

/// Drives Add Beer's manual search step: the full catalog (including
/// already-tried beers -- a user may deliberately log one again), with the
/// same debounced-search + infinite-scroll pagination shape as
/// `DiscoverController`, just without style/country/brewery filters (Add
/// Beer is a fast lookup, not a browse experience) and without Discover's
/// untried-only restriction -- see docs/QA_ROUND_1.md.
class AddBeerController extends ChangeNotifier {
  AddBeerController({required this._repository});

  static const Duration searchDebounce = Duration(milliseconds: 350);

  final CatalogRepository _repository;

  List<DiscoverBeer> items = [];
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

  int _nextPage = 1;
  int _requestId = 0;
  Timer? _debounceTimer;

  Future<void> loadInitial() => _loadFirstPage();

  /// Re-runs the current query/page-1 request -- used by the error state's
  /// retry action. Distinct from [setQuery], which no-ops when the trimmed
  /// value already equals the applied [query].
  Future<void> refresh() => _loadFirstPage();

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

  Future<void> _loadFirstPage() async {
    final generation = ++_requestId;
    final requestQuery = query;

    isLoadingInitial = true;
    error = null;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getBeers(
        page: 1,
        q: requestQuery.isEmpty ? null : requestQuery,
      );
      if (generation != _requestId) return;

      items = result.items;
      _nextPage = 2;
      hasMore = items.length < result.total;
    } catch (e, st) {
      if (generation != _requestId) return;
      error = e;
      items = [];
      logCatalogError('AddBeerController.loadInitial', e, st);
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
    final page = _nextPage;

    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getBeers(
        page: page,
        q: requestQuery.isEmpty ? null : requestQuery,
      );
      if (generation == _requestId) {
        items = [...items, ...result.items];
        _nextPage = page + 1;
        hasMore = items.length < result.total;
      }
    } catch (e, st) {
      if (generation == _requestId) {
        loadMoreError = e;
      }
      logCatalogError('AddBeerController.loadMore', e, st);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
