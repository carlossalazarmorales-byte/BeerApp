import '../../../core/network/api_client.dart';
import '../domain/models/statistics.dart';
import '../domain/statistics_repository.dart';

/// `StatisticsRepository` backed by the FastAPI `GET /statistics`
/// aggregate endpoint.
class ApiStatisticsRepository implements StatisticsRepository {
  ApiStatisticsRepository(this._client);

  final ApiClient _client;

  @override
  Future<Statistics> getStatistics() async {
    final json = await _client.getJson('/statistics') as Map<String, dynamic>;
    return Statistics.fromJson(json);
  }
}
