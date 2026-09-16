import '../../../core/network/api_client.dart';
import '../../catalog/domain/models/paged_result.dart';
import '../domain/collection_repository.dart';
import '../domain/collection_sort.dart';
import '../domain/models/collection_beer.dart';
import '../domain/models/collection_state.dart';
import '../domain/models/collection_state_input.dart';

/// `CollectionRepository` backed by the FastAPI `/collection` endpoints.
/// Never reads/writes `user_beer_collection` via Supabase/PostgREST directly
/// -- `ApiClient` is the only path in, matching the catalog/beer-logs
/// API-only model (see docs/ARCHITECTURE.md).
class ApiCollectionRepository implements CollectionRepository {
  ApiCollectionRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<CollectionBeer>> _getPage(
    String path, {
    required int page,
    required int pageSize,
    required String? countryId,
    required String? styleId,
    required String? breweryId,
    required CollectionSort sort,
  }) async {
    final json = await _client.getJson(
      path,
      query: {
        'page': '$page',
        'page_size': '$pageSize',
        'sort': sort.queryValue,
        'country_id': ?countryId,
        'style_id': ?styleId,
        'brewery_id': ?breweryId,
      },
    ) as Map<String, dynamic>;
    return PagedResult.fromJson(json, CollectionBeer.fromJson);
  }

  @override
  Future<PagedResult<CollectionBeer>> getLogged({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  }) {
    return _getPage(
      '/collection/logged',
      page: page,
      pageSize: pageSize,
      countryId: countryId,
      styleId: styleId,
      breweryId: breweryId,
      sort: sort,
    );
  }

  @override
  Future<PagedResult<CollectionBeer>> getFavorites({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  }) {
    return _getPage(
      '/collection/favorites',
      page: page,
      pageSize: pageSize,
      countryId: countryId,
      styleId: styleId,
      breweryId: breweryId,
      sort: sort,
    );
  }

  @override
  Future<PagedResult<CollectionBeer>> getWishlist({
    int page = 1,
    int pageSize = 20,
    String? countryId,
    String? styleId,
    String? breweryId,
    CollectionSort sort = CollectionSort.recent,
  }) {
    return _getPage(
      '/collection/wishlist',
      page: page,
      pageSize: pageSize,
      countryId: countryId,
      styleId: styleId,
      breweryId: breweryId,
      sort: sort,
    );
  }

  @override
  Future<CollectionState> getState(String beerId) async {
    final json =
        await _client.getJson('/collection/$beerId') as Map<String, dynamic>;
    return CollectionState.fromJson(json);
  }

  @override
  Future<CollectionState> setState(
    String beerId, {
    bool? isFavorite,
    bool? isWishlist,
  }) async {
    final json = await _client.patchJson(
      '/collection/$beerId',
      body: CollectionStateInput(
        isFavorite: isFavorite,
        isWishlist: isWishlist,
      ).toPatchJson(),
    ) as Map<String, dynamic>;
    return CollectionState.fromJson(json);
  }
}
