import '../../catalog/domain/models/paged_result.dart';
import 'models/beer_log.dart';
import 'models/beer_log_input.dart';

/// Boundary between logging UI (Beer Detail's "Your logs" section, the log
/// form) and however beer-log data is actually fetched/persisted. Screens/
/// controllers depend on this, never directly on `ApiClient`, so widget/
/// controller tests can supply a fake.
abstract class LogRepository {
  Future<PagedResult<BeerLog>> getLogs({
    String? beerId,
    int page = 1,
    int pageSize = 20,
  });

  Future<BeerLog> createLog(BeerLogCreateInput input);

  Future<BeerLog> updateLog(String id, BeerLogUpdateInput input);

  Future<void> deleteLog(String id);
}
