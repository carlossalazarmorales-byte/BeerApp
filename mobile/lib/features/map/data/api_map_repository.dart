import '../../../core/network/api_client.dart';
import '../domain/map_mode.dart';
import '../domain/map_repository.dart';
import '../domain/models/map_beer.dart';
import '../domain/models/map_brewery.dart';
import '../domain/models/map_result.dart';

/// `MapRepository` backed by the FastAPI `/map/beers`/`/map/breweries`
/// endpoints. Never reads catalog or personal-state tables via Supabase/
/// PostgREST directly -- `ApiClient` is the only path in, per
/// docs/ARCHITECTURE.md.
class ApiMapRepository implements MapRepository {
  ApiMapRepository(this._client);

  final ApiClient _client;

  @override
  Future<MapResult<MapBeer>> getMapBeers({
    required BeerMapState state,
    String? countryId,
    String? q,
  }) async {
    final trimmedQ = q?.trim();
    final json = await _client.getJson(
      '/map/beers',
      query: {
        'state': state.queryValue,
        'country_id': ?countryId,
        if (trimmedQ != null && trimmedQ.isNotEmpty) 'q': trimmedQ,
      },
    ) as Map<String, dynamic>;
    return MapResult.fromJson(json, MapBeer.fromJson);
  }

  @override
  Future<MapResult<MapBrewery>> getMapBreweries({
    String? countryId,
    String? q,
  }) async {
    final trimmedQ = q?.trim();
    final json = await _client.getJson(
      '/map/breweries',
      query: {
        'country_id': ?countryId,
        if (trimmedQ != null && trimmedQ.isNotEmpty) 'q': trimmedQ,
      },
    ) as Map<String, dynamic>;
    return MapResult.fromJson(json, MapBrewery.fromJson);
  }
}
