import '../../../core/network/api_client.dart';
import '../domain/achievements_repository.dart';
import '../domain/models/achievement.dart';

/// `AchievementsRepository` backed by the FastAPI `GET /achievements`
/// endpoint. Evaluation/unlocking always happens server-side -- this client
/// only ever reads the result, never decides an achievement is unlocked.
class ApiAchievementsRepository implements AchievementsRepository {
  ApiAchievementsRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Achievement>> getAchievements() async {
    final json = await _client.getJson('/achievements') as Map<String, dynamic>;
    final items = (json['items'] as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(Achievement.fromJson).toList();
  }
}
