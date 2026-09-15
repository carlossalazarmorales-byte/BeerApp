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

  List<Country> countries = [];
  List<BeerStyle> beerStyles = [];

  /// Keyed by the requested page number.
  Map<int, PagedResult<Beer>> beersByPage = {};
  Map<String, Beer> beersById = {};
  Map<String, Brewery> breweriesById = {};

  Object? getCountriesError;
  Object? getBeerStylesError;
  Object? getBeersError;
  Object? getBeerError;
  Object? getBreweryError;

  /// Records call order -- used to assert e.g. that `getBrewery` only ever
  /// runs after `getBeer` resolves.
  final List<String> callLog = [];

  Future<void> _maybeDelay() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
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
  }) async {
    callLog.add('getBeers:$page');
    await _maybeDelay();
    final error = getBeersError;
    if (error != null) throw error;
    return beersByPage[page] ??
        const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
  }

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
}
