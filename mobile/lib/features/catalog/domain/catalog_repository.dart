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
    String? q,
  });

  Future<Beer> getBeer(String id);

  /// Resolves a scanned barcode to its matching beer via
  /// `GET /beers/barcode/{barcode}`. The backend canonicalizes/validates
  /// the value (UPC-A/EAN-13/EAN-8, check-digit verified); throws
  /// [NotFoundApiException] when no beer has that barcode -- a normal
  /// outcome (a beer without a barcode is normal too), not an error.
  Future<Beer> getBeerByBarcode(String barcode);

  Future<Brewery> getBrewery(String id);

  /// Paginated brewery listing, backed by `GET /breweries`. Added for
  /// Discover's brewery filter -- distinct from [getBrewery], which fetches
  /// a single brewery by id for the beer detail screen.
  Future<PagedResult<Brewery>> getBreweries({int page = 1, int pageSize = 20});
}
