import '../../catalog/domain/models/paged_result.dart';
import 'collection_sort.dart';
import 'models/collection_beer.dart';
import 'models/collection_state.dart';

/// Boundary between Collection UI (the Collection screen, Beer Detail's
/// favorite/wishlist buttons) and however collection data is actually
/// fetched/persisted. Screens/controllers depend on this, never directly on
/// `ApiClient`, so widget/controller tests can supply a fake.
abstract class CollectionRepository {
  Future<PagedResult<CollectionBeer>> getLogged({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  });

  Future<PagedResult<CollectionBeer>> getFavorites({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  });

  Future<PagedResult<CollectionBeer>> getWishlist({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  });

  /// Never throws a not-found error for a real beer with no collection row
  /// yet -- see docs/API.md's 404-vs-200 distinction on this endpoint.
  Future<CollectionState> getState(String beerId);

  /// Sends the absolute target state for whichever field(s) are set --
  /// never a "toggle" -- so a retried/double-tapped call converges to the
  /// same state (see docs/DECISIONS.md).
  Future<CollectionState> setState(
    String beerId, {
    bool? isFavorite,
    bool? isWishlist,
  });
}
