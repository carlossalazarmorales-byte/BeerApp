import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/collection_refresh_signal.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/country.dart';
import '../domain/map_mode.dart';
import '../domain/map_repository.dart';
import '../domain/models/map_beer.dart';
import '../domain/models/map_country.dart';
import 'map_debug_log.dart';

/// Drives the Map screen: the single-select mode, country/region search,
/// first load, pull-to-refresh, and mutation-driven freshness -- with the
/// same generation-counter staleness guard as `DiscoverController`/
/// `CollectionController`.
///
/// Also listens to [CollectionRefreshSignal]: any successful beer-log or
/// favorite/wishlist mutation elsewhere calls [refresh] here, so the Tried/
/// Not tried/Favorites/Wishlist modes -- and the country-fill layer's
/// per-country tried counts -- stay fresh even while the Map tab isn't the
/// visible one -- see the signal's own doc comment for why no
/// navigation-aware mechanism is needed for that.
class MapController extends ChangeNotifier {
  MapController({
    required this._repository,
    required this._catalogRepository,
    required this._refreshSignal,
  }) {
    _refreshSignal.addListener(_onExternalChange);
  }

  static const Duration searchDebounce = Duration(milliseconds: 350);

  final MapRepository _repository;
  final CatalogRepository _catalogRepository;
  final CollectionRefreshSignal _refreshSignal;

  MapMode mode = MapMode.all;
  List<MapBeer> beers = [];
  bool truncated = false;

  /// Per-country catalog/tried counts for the country-fill layer. Unlike
  /// [beers], this is independent of [mode]/[query] -- it always reflects
  /// the full catalog's per-country coverage for the current user, so it is
  /// loaded once and refreshed only on [loadInitial]/[refresh]/an external
  /// mutation signal, never on a mode switch or search.
  List<MapCountry> countryCoverage = [];

  /// The applied search text (trimmed). Distinct from whatever's currently
  /// typed in the search field between keystrokes and the debounce firing.
  String query = '';

  /// Set only when [query] exactly matches a known country name
  /// (case-insensitive) -- see [setQuery]'s doc comment for the full
  /// resolution rule. Mutually exclusive with sending [query] itself as the
  /// free-text `q` param: exactly one of the two is ever sent to the
  /// repository for a given search.
  String? appliedCountryId;

  bool isLoading = false;

  /// Full-screen error. There is no separate "load more" error state --
  /// unlike Discover/Collection, the map is unpaginated (see
  /// docs/DECISIONS.md), so every load is a first/only load. Covers only
  /// the mode/search-scoped beer load, not [countryCoverage] -- a coverage
  /// fetch failure is decorative-overlay-only (see [_loadCountryCoverage])
  /// and never blocks or errors the map itself.
  Object? error;

  List<Country> _countries = [];

  int _requestId = 0;
  Timer? _debounceTimer;

  Future<void> loadInitial() {
    return Future.wait([_load(), _loadCountries(), _loadCountryCoverage()]);
  }

  Future<void> setMode(MapMode newMode) {
    if (newMode == mode) return Future<void>.value();
    mode = newMode;
    return _load();
  }

  /// Debounces [query] by [searchDebounce], then resolves it: an exact
  /// (case-insensitive, trimmed) match against a known country name is sent
  /// as `country_id`; anything else is sent as the free-text `q` param
  /// (region/name search); a blank/whitespace-only value clears both.
  /// Deliberately never a fuzzy/partial country match -- see
  /// docs/DECISIONS.md.
  void setQuery(String value) {
    final trimmed = value.trim();
    _debounceTimer?.cancel();
    if (trimmed == query) return;
    if (trimmed.isEmpty) {
      query = '';
      appliedCountryId = null;
      unawaited(_load());
      return;
    }
    _debounceTimer = Timer(searchDebounce, () {
      query = trimmed;
      appliedCountryId = _resolveCountryId(trimmed);
      unawaited(_load());
    });
  }

  String? _resolveCountryId(String normalizedQuery) {
    final lower = normalizedQuery.toLowerCase();
    for (final country in _countries) {
      if (country.name.toLowerCase() == lower) return country.id;
    }
    return null;
  }

  // A plain pull-to-refresh (or an external mutation signal) re-fetches the
  // *same* mode/search, so a transient failure preserves the still-valid
  // existing markers rather than replacing them with a full-screen error.
  Future<void> refresh() =>
      Future.wait([_load(preserveOnError: true), _loadCountryCoverage()]);

  Future<void> _load({bool preserveOnError = false}) async {
    final generation = ++_requestId;
    final requestMode = mode;
    final requestCountryId = appliedCountryId;
    final requestQ = appliedCountryId == null && query.isNotEmpty
        ? query
        : null;

    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.getMapBeers(
        state: requestMode.beerState,
        countryId: requestCountryId,
        q: requestQ,
      );
      if (generation != _requestId) return;
      beers = result.items;
      truncated = result.truncated;
    } catch (e, st) {
      if (generation != _requestId) return;
      error = e;
      if (!preserveOnError) {
        beers = [];
      }
      logMapError('MapController.load', e, st);
    } finally {
      if (generation == _requestId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadCountries() async {
    try {
      _countries = await _catalogRepository.getCountries();
    } catch (e, st) {
      // Country-name resolution for search is cosmetic here -- a failure
      // just means a country-name search silently falls through to a
      // free-text q search instead (see _resolveCountryId), never blocking
      // the map itself.
      logMapError('MapController.loadCountries', e, st);
    }
  }

  Future<void> _loadCountryCoverage() async {
    try {
      final coverage = await _repository.getCountryCoverage();
      countryCoverage = coverage;
      notifyListeners();
    } catch (e, st) {
      // The country-fill layer is a decorative overlay, not the map's
      // primary content -- a failure here leaves whatever coverage was
      // last loaded (or empty, on a first-load failure) rather than
      // surfacing a full-screen error or blocking beer markers.
      logMapError('MapController.loadCountryCoverage', e, st);
    }
  }

  void _onExternalChange() => refresh();

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _refreshSignal.removeListener(_onExternalChange);
    super.dispose();
  }
}
