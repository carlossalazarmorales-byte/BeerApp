import '../../../core/network/api_client.dart';
import '../../catalog/domain/models/paged_result.dart';
import '../domain/log_repository.dart';
import '../domain/models/beer_log.dart';
import '../domain/models/beer_log_input.dart';

/// `LogRepository` backed by the FastAPI `/beer-logs` endpoints. Never reads
/// or writes `user_beer_logs` via Supabase/PostgREST directly -- `ApiClient`
/// is the only path in, matching the catalog's API-only model (see
/// docs/ARCHITECTURE.md).
class ApiLogRepository implements LogRepository {
  ApiLogRepository(this._client);

  final ApiClient _client;

  @override
  Future<PagedResult<BeerLog>> getLogs({
    String? beerId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.getJson(
      '/beer-logs',
      query: {'page': '$page', 'page_size': '$pageSize', 'beer_id': ?beerId},
    ) as Map<String, dynamic>;
    return PagedResult.fromJson(json, BeerLog.fromJson);
  }

  @override
  Future<BeerLog> createLog(BeerLogCreateInput input) async {
    final json = await _client.postJson(
      '/beer-logs',
      body: input.toJson(),
    ) as Map<String, dynamic>;
    return BeerLog.fromJson(json);
  }

  @override
  Future<BeerLog> updateLog(String id, BeerLogUpdateInput input) async {
    final json = await _client.patchJson(
      '/beer-logs/$id',
      body: input.toPatchJson(),
    ) as Map<String, dynamic>;
    return BeerLog.fromJson(json);
  }

  @override
  Future<void> deleteLog(String id) {
    return _client.deleteJson('/beer-logs/$id');
  }
}
