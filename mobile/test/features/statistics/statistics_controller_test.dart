import 'package:beerapp/features/statistics/domain/models/statistics.dart';
import 'package:beerapp/features/statistics/presentation/statistics_controller.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_statistics_repository.dart';

Statistics _stats({required int totalLogs}) => Statistics(
  totalUniqueBeers: totalLogs,
  totalLogs: totalLogs,
  countriesDiscovered: 0,
  stylesDiscovered: 0,
  breweriesDiscovered: 0,
  averageRating: null,
  amountSpent: const [],
  monthlyActivity: const [],
  yearlyActivity: const [],
  favoriteStyle: null,
  favoriteCountry: null,
  favoriteBrewery: null,
);

void main() {
  test('loadInitial populates statistics from the repository', () async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = _stats(totalLogs: 5);
    final controller = StatisticsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.statistics?.totalLogs, 5);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('loadInitial failure sets error and leaves statistics null', () async {
    final repository = FakeStatisticsRepository()
      ..getStatisticsError = Exception('boom');
    final controller = StatisticsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.statistics, isNull);
    expect(controller.error, isNotNull);
  });

  test('refresh preserves existing statistics on failure rather than clearing them', () async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = _stats(totalLogs: 3);
    final controller = StatisticsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    repository.getStatisticsError = Exception('network blip');
    await controller.refresh();

    expect(controller.statistics?.totalLogs, 3);
    expect(controller.error, isNotNull);
  });

  test('a second load supersedes an in-flight first load', () async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = _stats(totalLogs: 1);
    final controller = StatisticsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    final first = controller.loadInitial();
    repository.statisticsResult = _stats(totalLogs: 2);
    final second = controller.refresh();
    await Future.wait([first, second]);

    // The stale first response must never overwrite the later one, even
    // though both were in flight concurrently.
    expect(controller.statistics?.totalLogs, 2);
  });

  test('refreshSignal.notifyChanged() triggers a refresh even for a controller '
      'that is not the active/visible screen', () async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = _stats(totalLogs: 1);
    final refreshSignal = CollectionRefreshSignal();
    final controller = StatisticsController(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    repository.callLog.clear();

    // Simulates a mutation elsewhere (a new beer log, a favorite toggle)
    // firing the shared signal -- nothing here calls controller.refresh()
    // directly.
    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(repository.callLog, ['getStatistics']);
  });

  test('dispose stops listening to the refresh signal', () async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = _stats(totalLogs: 1);
    final refreshSignal = CollectionRefreshSignal();
    final controller = StatisticsController(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    controller.dispose();
    repository.callLog.clear();

    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(repository.callLog, isEmpty);
  });
}
