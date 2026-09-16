import 'map_mode.dart';
import 'models/map_beer.dart';
import 'models/map_brewery.dart';
import 'models/map_result.dart';

/// Boundary between the Map screen/controller and however marker data is
/// actually fetched. Screens/controllers depend on this, never directly on
/// `ApiClient`, so controller tests can supply a fake. Mirrors
/// `CatalogRepository`/`CollectionRepository`'s role in their own features.
abstract interface class MapRepository {
  Future<MapResult<MapBeer>> getMapBeers({
    required BeerMapState state,
    String? countryId,
    String? q,
  });

  Future<MapResult<MapBrewery>> getMapBreweries({String? countryId, String? q});
}
