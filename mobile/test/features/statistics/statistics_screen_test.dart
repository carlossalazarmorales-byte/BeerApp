import 'package:beerapp/features/statistics/domain/models/amount_spent.dart';
import 'package:beerapp/features/statistics/domain/models/statistics.dart';
import 'package:beerapp/features/statistics/presentation/statistics_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_statistics_repository.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  testWidgets('shows a loading indicator before the repository resolves', (
    tester,
  ) async {
    final repository = FakeStatisticsRepository(
      delay: const Duration(milliseconds: 50),
    )..statisticsResult = kEmptyStatistics;
    await tester.pumpWidget(
      _wrap(
        StatisticsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'shows an error state with a working retry on first-load failure',
    (tester) async {
      final repository = FakeStatisticsRepository()
        ..getStatisticsError = Exception('boom');
      await tester.pumpWidget(
        _wrap(
          StatisticsScreen(
            repository: repository,
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't load your statistics. Please try again."),
        findsOneWidget,
      );

      repository.getStatisticsError = null;
      repository.statisticsResult = kEmptyStatistics;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        find.text('Log a beer or favorite one to see your statistics here.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows the empty state when there are no logs and no favorites', (
    tester,
  ) async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = kEmptyStatistics;
    await tester.pumpWidget(
      _wrap(
        StatisticsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Log a beer or favorite one to see your statistics here.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders the populated view -- not the empty state -- when there are '
    'zero logs but a favorite exists',
    (tester) async {
      const stats = Statistics(
        totalUniqueBeers: 0,
        totalLogs: 0,
        countriesDiscovered: 0,
        stylesDiscovered: 0,
        breweriesDiscovered: 0,
        averageRating: null,
        amountSpent: [],
        monthlyActivity: [],
        yearlyActivity: [],
        favoriteStyle: 'IPA',
        favoriteCountry: null,
        favoriteBrewery: null,
      );
      final repository = FakeStatisticsRepository()..statisticsResult = stats;
      await tester.pumpWidget(
        _wrap(
          StatisticsScreen(
            repository: repository,
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The populated view, not EmptyState -- the favorite renders
      // normally, and the zero log/discovery counts render as literal "0",
      // not as an empty-state message.
      expect(
        find.text('Log a beer or favorite one to see your statistics here.'),
        findsNothing,
      );
      expect(find.text('0'), findsWidgets);

      // FavoritesSection sits below the fold at the default test viewport
      // size -- scroll it into view rather than asserting blind, which also
      // proves the real screen is scrollable. `find.byType(Scrollable).first`
      // targets the screen's outer ListView specifically -- the overview
      // GridView above it is also a Scrollable (NeverScrollableScrollPhysics
      // only disables scroll gestures, it doesn't remove the Scrollable
      // widget), so the unqualified default finder matches more than one.
      await tester.scrollUntilVisible(
        find.text('IPA'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('IPA'), findsOneWidget);
    },
  );

  testWidgets('renders a fully populated statistics view without throwing', (
    tester,
  ) async {
    const stats = Statistics(
      totalUniqueBeers: 5,
      totalLogs: 7,
      countriesDiscovered: 3,
      stylesDiscovered: 4,
      breweriesDiscovered: 5,
      averageRating: 3.5,
      amountSpent: [AmountSpent(currency: 'USD', total: 12.5)],
      monthlyActivity: [],
      yearlyActivity: [],
      favoriteStyle: 'IPA',
      favoriteCountry: 'Ireland',
      favoriteBrewery: 'Test Brewery',
    );
    final repository = FakeStatisticsRepository()..statisticsResult = stats;
    await tester.pumpWidget(
      _wrap(
        StatisticsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);

    // AmountSpentSection and FavoritesSection sit below the fold at the
    // default test viewport size -- scroll each into view rather than
    // asserting blind, which also proves the real screen is scrollable.
    // `find.byType(Scrollable).first` targets the screen's outer ListView
    // specifically -- the overview GridView above it is also a Scrollable
    // (NeverScrollableScrollPhysics only disables scroll gestures, it
    // doesn't remove the Scrollable widget), so the unqualified default
    // finder matches more than one.
    final outerScrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('USD'),
      200,
      scrollable: outerScrollable,
    );
    expect(find.text('USD'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('IPA'),
      200,
      scrollable: outerScrollable,
    );
    expect(find.text('IPA'), findsOneWidget);
    expect(find.text('Ireland'), findsOneWidget);
    expect(find.text('Test Brewery'), findsOneWidget);
  });

  testWidgets('pull-to-refresh re-fetches statistics', (tester) async {
    final repository = FakeStatisticsRepository()
      ..statisticsResult = kEmptyStatistics;
    await tester.pumpWidget(
      _wrap(
        StatisticsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.callLog.clear();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(repository.callLog, contains('getStatistics'));
  });
}
