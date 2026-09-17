import 'package:beerapp/features/achievements/domain/achievements_repository.dart';
import 'package:beerapp/features/achievements/domain/models/achievement.dart';

class FakeAchievementsRepository implements AchievementsRepository {
  FakeAchievementsRepository({this.delay = Duration.zero});

  /// Artificial delay before [getAchievements] resolves -- zero by default,
  /// set to a small non-zero value in widget tests that need to observe an
  /// intermediate loading state. Mirrors `FakeStatisticsRepository`.
  final Duration delay;

  List<Achievement> achievementsResult = const [];
  Object? getAchievementsError;

  /// Records call order -- e.g. `getAchievements`, `getAchievements`.
  final List<String> callLog = [];

  @override
  Future<List<Achievement>> getAchievements() async {
    callLog.add('getAchievements');
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final error = getAchievementsError;
    if (error != null) throw error;
    return achievementsResult;
  }
}
