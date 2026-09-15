import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/design_system/components/states/loading_state.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/beer_style.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:beerapp/features/catalog/presentation/beer_detail/beer_detail_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_catalog_repository.dart';
import '../../../fakes/fake_log_repository.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

FakeCatalogRepository _seededRepository({Duration delay = Duration.zero}) {
  return FakeCatalogRepository(delay: delay)
    ..countries = const [
      Country(
        id: 'country-1',
        isoCode: 'IE',
        name: 'Ireland',
        continent: 'Europe',
      ),
    ]
    ..beerStyles = const [BeerStyle(id: 'style-1', name: 'Dry Stout')]
    ..beersById['beer-1'] = const Beer(
      id: 'beer-1',
      officialName: 'Test Stout',
      breweryId: 'brewery-1',
      styleId: 'style-1',
      countryId: 'country-1',
      abv: 5.5,
      ibu: 40,
      verified: true,
    )
    ..breweriesById['brewery-1'] = const Brewery(
      id: 'brewery-1',
      name: 'Test Brewery',
      countryId: 'country-1',
      city: 'Dublin',
      verified: true,
    );
}

void main() {
  testWidgets(
    'shows a loading state while fetching, then the populated detail',
    (tester) async {
      final repository = _seededRepository(
        delay: const Duration(milliseconds: 10),
      );

      await tester.pumpWidget(
        _wrap(
          BeerDetailScreen(
            repository: repository,
            logRepository: FakeLogRepository(),
            beerId: 'beer-1',
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LoadingState), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpAndSettle();

      expect(find.byType(LoadingState), findsNothing);
      // Appears twice: the AppBar title and the body headline.
      expect(find.text('Test Stout'), findsNWidgets(2));
      expect(find.text('Test Brewery'), findsOneWidget);
      expect(find.text('Dry Stout'), findsOneWidget);
      expect(find.text('Dublin • Ireland'), findsOneWidget);
      expect(find.text('5.5%'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    },
  );

  testWidgets(
    'shows an error state with retry on failure, and retry recovers into the populated detail',
    (tester) async {
      final repository = _seededRepository()
        ..getBeerError = Exception('backend hiccup');

      await tester.pumpWidget(
        _wrap(
          BeerDetailScreen(
            repository: repository,
            logRepository: FakeLogRepository(),
            beerId: 'beer-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);

      repository.getBeerError = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Test Stout'), findsNWidgets(2));
    },
  );

  testWidgets(
    'a NotFoundApiException shows the localized "not found" text, not the raw backend message',
    (tester) async {
      final repository = _seededRepository()
        ..getBeerError = const NotFoundApiException(
          message: 'Beer beer-1 not found',
          statusCode: 404,
          code: 'not_found',
        );

      await tester.pumpWidget(
        _wrap(
          BeerDetailScreen(
            repository: repository,
            logRepository: FakeLogRepository(),
            beerId: 'beer-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This beer could not be found.'), findsOneWidget);
      expect(find.text('Beer beer-1 not found'), findsNothing);
    },
  );

  testWidgets(
    'a generic/raw backend exception is never rendered -- only the localized fallback text is shown',
    (tester) async {
      const rawMessage = 'SELECT failed: relation "beers" does not exist';
      final repository = _seededRepository()
        ..getBeerError = const ApiException(
          message: rawMessage,
          statusCode: 500,
          code: 'internal_error',
        );

      await tester.pumpWidget(
        _wrap(
          BeerDetailScreen(
            repository: repository,
            logRepository: FakeLogRepository(),
            beerId: 'beer-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('We couldn\'t load the beer catalog. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining(rawMessage), findsNothing);
    },
  );

  testWidgets('shows a "Log this beer" button and an empty log-list message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BeerDetailScreen(
          repository: _seededRepository(),
          logRepository: FakeLogRepository(),
          beerId: 'beer-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Log this beer'), findsOneWidget);
    expect(find.text('You haven\'t logged this beer yet.'), findsOneWidget);
  });

  testWidgets(
    'tapping the log button opens the form, and a quick-log submission shows the new entry and a confirmation',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          BeerDetailScreen(
            repository: _seededRepository(),
            logRepository: FakeLogRepository(),
            beerId: 'beer-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Log this beer'));
      await tester.tap(find.text('Log this beer'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Log saved.'), findsOneWidget);
      expect(find.text('You haven\'t logged this beer yet.'), findsNothing);
    },
  );

  testWidgets(
    'a beer-log failure shows a localized message, never the raw backend text, and never blocks the beer content',
    (tester) async {
      const rawMessage = 'relation "user_beer_logs" does not exist';
      final logRepository = FakeLogRepository()
        ..getLogsError = const ApiException(
          message: rawMessage,
          statusCode: 500,
          code: 'internal_error',
        );

      await tester.pumpWidget(
        _wrap(
          BeerDetailScreen(
            repository: _seededRepository(),
            logRepository: logRepository,
            beerId: 'beer-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Beer content still renders even though the log section failed.
      expect(find.text('Test Stout'), findsNWidgets(2));
      expect(find.textContaining(rawMessage), findsNothing);
      expect(
        find.text('We couldn\'t save your log. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('"Load more" is hidden when there is only one page of logs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        BeerDetailScreen(
          repository: _seededRepository(),
          logRepository: FakeLogRepository(),
          beerId: 'beer-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Load more'), findsNothing);
  });
}
