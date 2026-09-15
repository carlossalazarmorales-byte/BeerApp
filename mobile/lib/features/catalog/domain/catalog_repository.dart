import 'models/beer.dart';
import 'models/beer_style.dart';
import 'models/brewery.dart';
import 'models/country.dart';
import 'models/paged_result.dart';

/// Boundary between catalog UI (beer list/detail) and however catalog data
/// is actually fetched. Screens/controllers depend on this, never directly
/// on `ApiClient`, so widget/controller tests can supply a fake.
abstract class CatalogRepository {
  Future<List<Country>> getCountries();

  Future<List<BeerStyle>> getBeerStyles();

  Future<PagedResult<Beer>> getBeers({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
  });

  Future<Beer> getBeer(String id);

  Future<Brewery> getBrewery(String id);
}
