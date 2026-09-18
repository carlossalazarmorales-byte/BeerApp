import 'package:beerapp/features/catalog/domain/catalog_repository.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/beer_style.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';

class FakeCatalogRepository implements CatalogRepository {
  FakeCatalogRepository({this.delay = Duration.zero});

  /// Artificial delay before every method resolves -- zero by default (most
  /// tests want synchronous-as-possible fakes), set to a small non-zero
  /// value in widget tests that need to observe an intermediate loading
  /// state via `tester.pump(delay)` before it flips to loaded/error.
  final Duration delay;

  /// Per-call delay override, keyed by the same call-log string [callLog]
  /// records (e.g. `'getBeers:2'`) -- lets a test make one specific request
  /// resolve slower/faster than [delay] to deterministically simulate a race
  /// between two in-flight requests, rather than relying on real timing.
  Map<String, Duration> extraDelayByCallKey = {};

  List<Country> countries = [];
  List<BeerStyle> beerStyles = [];

  /// Keyed by the requested page number. Only consulted when [getBeers] is
  /// called with no `q`/filters -- the common, pre-Phase-5 case -- so
  /// existing tests that only ever set this keep working unchanged.
  Map<int, PagedResult<Beer>> beersByPage = {};

  /// Keyed by `'page|q|countryId|styleId|breweryId'` (see [_beersRequestKey])
  /// -- consulted whenever [getBeers] is called with any `q`/filter set, so
  /// the same page number can return different results for different
  /// searches/filters within one test.
  Map<String, PagedResult<Beer>> beersByRequest = {};

  Map<String, Beer> beersById = {};
  Map<String, Beer> beersByBarcode = {};
  Map<String, Brewery> breweriesById = {};

  /// Keyed by the requested page number, mirroring [beersByPage].
  Map<int, PagedResult<Brewery>> breweriesByPage = {};

  Object? getCountriesError;
  Object? getBeerStylesError;
  Object? getBeersError;
  Object? getBeerError;
  Object? getBeerByBarcodeError;
  Object? getBreweryError;
  Object? getBreweriesError;

  /// Records call order -- used to assert e.g. that `getBrewery` only ever
  /// runs after `getBeer` resolves.
  final List<String> callLog = [];

  Future<void> _maybeDelay([String? callKey]) async {
    final effectiveDelay =
        (callKey != null ? extraDelayByCallKey[callKey] : null) ?? delay;
    if (effectiveDelay > Duration.zero) {
      await Future<void>.delayed(effectiveDelay);
    }
  }

  @override
  Future<List<Country>> getCountries() async {
    callLog.add('getCountries');
    await _maybeDelay();
    final error = getCountriesError;
    if (error != null) throw error;
    return countries;
  }

  @override
  Future<List<BeerStyle>> getBeerStyles() async {
    callLog.add('getBeerStyles');
    await _maybeDelay();
    final error = getBeerStylesError;
    if (error != null) throw error;
    return beerStyles;
  }

  @override
  Future<PagedResult<Beer>> getBeers({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    String? q,
  }) async {
    final hasSearchOrFilter =
        q != null || countryId != null || styleId != null || breweryId != null;
    final callKey = hasSearchOrFilter
        ? 'getBeers:${_beersRequestKey(page, q, countryId, styleId, breweryId)}'
        : 'getBeers:$page';
    callLog.add(callKey);
    await _maybeDelay(callKey);
    final error = getBeersError;
    if (error != null) throw error;
    if (hasSearchOrFilter) {
      return beersByRequest[_beersRequestKey(
            page,
            q,
            countryId,
            styleId,
            breweryId,
          )] ??
          const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
    }
    return beersByPage[page] ??
        const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
  }

  static String _beersRequestKey(
    int page,
    String? q,
    String? countryId,
    String? styleId,
    String? breweryId,
  ) =>
      '$page|${q ?? ''}|${countryId ?? ''}|${styleId ?? ''}|${breweryId ?? ''}';

  @override
  Future<Beer> getBeer(String id) async {
    callLog.add('getBeer:$id');
    await _maybeDelay();
    final error = getBeerError;
    if (error != null) throw error;
    final beer = beersById[id];
    if (beer == null) throw StateError('FakeCatalogRepository: no beer $id');
    return beer;
  }

  @override
  Future<Beer> getBeerByBarcode(String barcode) async {
    final callKey = 'getBeerByBarcode:$barcode';
    callLog.add(callKey);
    await _maybeDelay(callKey);
    final error = getBeerByBarcodeError;
    if (error != null) throw error;
    final beer = beersByBarcode[barcode];
    if (beer == null) {
      throw StateError('FakeCatalogRepository: no beer for barcode $barcode');
    }
    return beer;
  }

  @override
  Future<Brewery> getBrewery(String id) async {
    callLog.add('getBrewery:$id');
    await _maybeDelay();
    final error = getBreweryError;
    if (error != null) throw error;
    final brewery = breweriesById[id];
    if (brewery == null) {
      throw StateError('FakeCatalogRepository: no brewery $id');
    }
    return brewery;
  }

  @override
  Future<PagedResult<Brewery>> getBreweries({
    int page = 1,
    int pageSize = 20,
  }) async {
    callLog.add('getBreweries:$page');
    await _maybeDelay();
    final error = getBreweriesError;
    if (error != null) throw error;
    return breweriesByPage[page] ??
        const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
  }
}
