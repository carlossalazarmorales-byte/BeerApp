import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/collection/domain/collection_repository.dart';
import 'package:beerapp/features/collection/domain/collection_sort.dart';
import 'package:beerapp/features/collection/domain/models/collection_beer.dart';
import 'package:beerapp/features/collection/domain/models/collection_state.dart';

class FakeCollectionRepository implements CollectionRepository {
  FakeCollectionRepository({this.delay = Duration.zero});

  /// Artificial delay before every method resolves -- zero by default, set
  /// to a small non-zero value in widget tests that need to observe an
  /// intermediate loading state.
  final Duration delay;

  /// Per-call delay override, keyed by the same call-log string [callLog]
  /// records (e.g. `'setState:beer-1:favorite'`) -- lets a test make one
  /// specific request resolve slower/faster than [delay], to deterministically
  /// prove two concurrent mutations converge correctly regardless of which
  /// one's HTTP response actually lands first. Mirrors
  /// `FakeCatalogRepository.extraDelayByCallKey`.
  Map<String, Duration> extraDelayByCallKey = {};

  /// Keyed by the requested page number -- consulted by whichever of
  /// getLogged/getFavorites/getWishlist is called, independently, so a test
  /// can seed different pages for different tabs.
  Map<int, PagedResult<CollectionBeer>> loggedByPage = {};
  Map<int, PagedResult<CollectionBeer>> favoritesByPage = {};
  Map<int, PagedResult<CollectionBeer>> wishlistByPage = {};

  /// In-memory state store, keyed by beerId -- [setState] mutates this
  /// directly, matching the real backend's "all-false means no row"
  /// invariant, so a controller's post-mutation reload reflects the change
  /// without any extra plumbing.
  final Map<String, CollectionState> stateByBeerId = {};

  Object? getLoggedError;
  Object? getFavoritesError;
  Object? getWishlistError;
  Object? getStateError;
  Object? setStateError;

  /// Records call order -- e.g. `getLogged:1`, `setState:beer-1`.
  final List<String> callLog = [];

  Future<void> _maybeDelay([String? callKey]) async {
    final effectiveDelay =
        (callKey != null ? extraDelayByCallKey[callKey] : null) ?? delay;
    if (effectiveDelay > Duration.zero) {
      await Future<void>.delayed(effectiveDelay);
    }
  }

  @override
  Future<PagedResult<CollectionBeer>> getLogged({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  }) async {
    callLog.add('getLogged:$page');
    await _maybeDelay();
    final error = getLoggedError;
    if (error != null) throw error;
    return loggedByPage[page] ??
        const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
  }

  @override
  Future<PagedResult<CollectionBeer>> getFavorites({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  }) async {
    callLog.add('getFavorites:$page');
    await _maybeDelay();
    final error = getFavoritesError;
    if (error != null) throw error;
    return favoritesByPage[page] ??
        const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
  }

  @override
  Future<PagedResult<CollectionBeer>> getWishlist({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  }) async {
    callLog.add('getWishlist:$page');
    await _maybeDelay();
    final error = getWishlistError;
    if (error != null) throw error;
    return wishlistByPage[page] ??
        const PagedResult(items: [], page: 1, pageSize: 20, total: 0);
  }

  @override
  Future<CollectionState> getState(String beerId) async {
    callLog.add('getState:$beerId');
    await _maybeDelay();
    final error = getStateError;
    if (error != null) throw error;
    return stateByBeerId[beerId] ??
        CollectionState(beerId: beerId, isFavorite: false, isWishlist: false);
  }

  @override
  Future<CollectionState> setState(
    String beerId, {
    bool? isFavorite,
    bool? isWishlist,
  }) async {
    final field = isFavorite != null
        ? 'favorite'
        : (isWishlist != null ? 'wishlist' : 'none');
    final callKey = 'setState:$beerId:$field';
    callLog.add(callKey);
    await _maybeDelay(callKey);
    final error = setStateError;
    if (error != null) throw error;

    final current =
        stateByBeerId[beerId] ??
        CollectionState(beerId: beerId, isFavorite: false, isWishlist: false);
    final resultingFavorite = isFavorite ?? current.isFavorite;
    final resultingWishlist = isWishlist ?? current.isWishlist;
    final result = CollectionState(
      beerId: beerId,
      isFavorite: resultingFavorite,
      isWishlist: resultingWishlist,
    );
    if (!resultingFavorite && !resultingWishlist) {
      stateByBeerId.remove(beerId);
    } else {
      stateByBeerId[beerId] = result;
    }
    return result;
  }
}
