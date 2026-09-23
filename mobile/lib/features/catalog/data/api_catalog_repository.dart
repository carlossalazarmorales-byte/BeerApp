import '../../../core/network/api_client.dart';
import '../domain/catalog_repository.dart';
import '../domain/models/beer.dart';
import '../domain/models/beer_style.dart';
import '../domain/models/brewery.dart';
import '../domain/models/country.dart';
import '../domain/models/discover_beer.dart';
import '../domain/models/paged_result.dart';

/// `CatalogRepository` backed by the FastAPI catalog endpoints. Never reads
/// catalog tables via Supabase/PostgREST directly -- `ApiClient` is the only
/// path in, per docs/ARCHITECTURE.md.
///
/// `/countries` and `/beer-styles` are small (10/8 rows in dev) and
/// unpaginated, so they're fetched once and cached in-memory for this
/// repository instance's lifetime. `/breweries` is paginated/potentially
/// large and is never prefetched -- callers fetch a single brewery by id
/// when they actually need one (the beer detail screen).
class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._client);

  final ApiClient _client;

  List<Country>? _countriesCache;
  List<BeerStyle>? _beerStylesCache;

  @override
  Future<List<Country>> getCountries() async {
    final cached = _countriesCache;
    if (cached != null) return cached;

    final json = await _client.getJson('/countries') as List<dynamic>;
    final countries = json
        .cast<Map<String, dynamic>>()
        .map(Country.fromJson)
        .toList();
    _countriesCache = countries;
    return countries;
  }

  @override
  Future<List<BeerStyle>> getBeerStyles() async {
    final cached = _beerStylesCache;
    if (cached != null) return cached;

    final json = await _client.getJson('/beer-styles') as List<dynamic>;
    final styles = json
        .cast<Map<String, dynamic>>()
        .map(BeerStyle.fromJson)
        .toList();
    _beerStylesCache = styles;
    return styles;
  }

  @override
  Future<PagedResult<DiscoverBeer>> getBeers({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    String? q,
    bool untriedOnly = false,
  }) async {
    // Trimmed as a courtesy; the backend normalizes independently and is the
    // source of truth (see docs/API.md), so a whitespace-only value here is
    // simply never sent rather than relied upon to be handled server-side.
    final trimmedQ = q?.trim();
    final json = await _client.getJson(
      '/beers',
      query: {
        'page': '$page',
        'page_size': '$pageSize',
        'country_id': ?countryId,
        'style_id': ?styleId,
        'brewery_id': ?breweryId,
        if (trimmedQ != null && trimmedQ.isNotEmpty) 'q': trimmedQ,
        if (untriedOnly) 'untried_only': 'true',
      },
    ) as Map<String, dynamic>;
    return PagedResult.fromJson(json, DiscoverBeer.fromJson);
  }

  @override
  Future<Beer> getBeer(String id) async {
    final json = await _client.getJson('/beers/$id') as Map<String, dynamic>;
    return Beer.fromJson(json);
  }

  @override
  Future<Beer> getBeerByBarcode(String barcode) async {
    final json = await _client.getJson(
      '/beers/barcode/$barcode',
    ) as Map<String, dynamic>;
    return Beer.fromJson(json);
  }

  @override
  Future<Brewery> getBrewery(String id) async {
    final json =
        await _client.getJson('/breweries/$id') as Map<String, dynamic>;
    return Brewery.fromJson(json);
  }

  @override
  Future<PagedResult<Brewery>> getBreweries({
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.getJson(
      '/breweries',
      query: {'page': '$page', 'page_size': '$pageSize'},
    ) as Map<String, dynamic>;
    return PagedResult.fromJson(json, Brewery.fromJson);
  }
}
