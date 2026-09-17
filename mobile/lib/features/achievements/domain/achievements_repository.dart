import 'models/achievement.dart';

/// Boundary between the Achievements UI and however achievements are
/// actually fetched/evaluated. The screen/controller depends on this, never
/// directly on `ApiClient`, so widget/controller tests can supply a fake.
abstract class AchievementsRepository {
  Future<List<Achievement>> getAchievements();
}
