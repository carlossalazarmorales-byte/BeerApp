import 'package:beerapp/features/statistics/domain/models/amount_spent.dart';
import 'package:beerapp/features/statistics/domain/models/monthly_activity_point.dart';
import 'package:beerapp/features/statistics/domain/models/statistics.dart';
import 'package:beerapp/features/statistics/domain/models/yearly_activity_point.dart';
import 'package:beerapp/features/statistics/domain/statistics_repository.dart';

const Statistics kEmptyStatistics = Statistics(
  totalUniqueBeers: 0,
  totalLogs: 0,
  countriesDiscovered: 0,
  stylesDiscovered: 0,
  breweriesDiscovered: 0,
  averageRating: null,
  amountSpent: <AmountSpent>[],
  monthlyActivity: <MonthlyActivityPoint>[],
  yearlyActivity: <YearlyActivityPoint>[],
  favoriteStyle: null,
  favoriteCountry: null,
  favoriteBrewery: null,
);

class FakeStatisticsRepository implements StatisticsRepository {
  FakeStatisticsRepository({this.delay = Duration.zero});

  /// Artificial delay before [getStatistics] resolves -- zero by default,
  /// set to a small non-zero value in widget tests that need to observe an
  /// intermediate loading state. Mirrors `FakeCollectionRepository`.
  final Duration delay;

  Statistics? statisticsResult;
  Object? getStatisticsError;

  /// Records call order -- e.g. `getStatistics`, `getStatistics`.
  final List<String> callLog = [];

  @override
  Future<Statistics> getStatistics() async {
    callLog.add('getStatistics');
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final error = getStatisticsError;
    if (error != null) throw error;
    return statisticsResult ?? kEmptyStatistics;
  }
}
