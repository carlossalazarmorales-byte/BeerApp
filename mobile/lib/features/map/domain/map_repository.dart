import 'map_mode.dart';
import 'models/map_beer.dart';
import 'models/map_country.dart';
import 'models/map_result.dart';

/// Boundary between the Map screen/controller and however marker/coverage
/// data is actually fetched. Screens/controllers depend on this, never
/// directly on `ApiClient`, so controller tests can supply a fake. Mirrors
/// `CatalogRepository`/`CollectionRepository`'s role in their own features.
abstract interface class MapRepository {
  Future<MapResult<MapBeer>> getMapBeers({
    required BeerMapState state,
    String? countryId,
    String? q,
  });

  /// Per-country catalog/tried counts backing the country-fill layer.
  /// Unpaginated -- bounded by the real number of countries (~250 max),
  /// unlike the capped beer/brewery marker lists.
  Future<List<MapCountry>> getCountryCoverage();
}
