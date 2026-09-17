import 'models/statistics.dart';

/// Boundary between the Statistics UI and however statistics are actually
/// fetched. The screen/controller depends on this, never directly on
/// `ApiClient`, so widget/controller tests can supply a fake.
abstract class StatisticsRepository {
  Future<Statistics> getStatistics();
}
