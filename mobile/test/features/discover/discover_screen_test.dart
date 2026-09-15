import 'package:beerapp/design_system/components/states/empty_state.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/design_system/components/states/loading_state.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/beer_style.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/discover/presentation/discover_controller.dart';
import 'package:beerapp/features/discover/presentation/discover_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_catalog_repository.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

List<Beer> _beers(int count, {int offset = 0}) => List.generate(
  count,
  (i) => Beer(
    id: 'beer-${offset + i}',
    officialName: 'Beer ${offset + i}',
    breweryId: 'brewery-1',
    verified: false,
  ),
);

Future<void> _settleDebounce(WidgetTester tester) => tester.pump(
  DiscoverController.searchDebounce + const Duration(milliseconds: 50),
);

void main() {
  testWidgets('shows a loading state, then the loaded list', (tester) async {
    final repository =
        FakeCatalogRepository(delay: const Duration(milliseconds: 10))
          ..beersByPage[1] = PagedResult(
            items: _beers(3),
            page: 1,
            pageSize: 20,
            total: 3,
          );

    await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    expect(find.byType(LoadingState), findsNothing);
    expect(find.text('Beer 0'), findsOneWidget);
  });

  testWidgets(
    'shows an error state with retry on first-load failure, and retry recovers',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..getBeersError = Exception('boom');
      await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);

      repository.getBeersError = null;
      repository.beersByPage[1] = PagedResult(
        items: _beers(1),
        page: 1,
        pageSize: 20,
        total: 1,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsNothing);
      expect(find.text('Beer 0'), findsOneWidget);
    },
  );

  testWidgets('shows an empty state when the catalog has no beers', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = const PagedResult(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
      );
    await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('scrolling near the bottom loads and appends the next page', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: _beers(30),
        page: 1,
        pageSize: 30,
        total: 31,
      )
      ..beersByPage[2] = PagedResult(
        items: _beers(1, offset: 30),
        page: 2,
        pageSize: 30,
        total: 31,
      );

    await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Beer 30'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, -20000), 3000);
    await tester.pumpAndSettle();

    expect(find.text('Beer 30'), findsOneWidget);
  });

  testWidgets('typing a search debounces and shows matching results', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beers(1)[0]],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..beersByRequest['1|stout|||'] = PagedResult(
        items: const [
          Beer(
            id: 'stout-1',
            officialName: 'Great Stout',
            breweryId: 'b',
            verified: false,
          ),
        ],
        page: 1,
        pageSize: 20,
        total: 1,
      );

    await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Beer 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'stout');
    // Not yet debounced -- old results still showing.
    await tester.pump();
    expect(find.text('Beer 0'), findsOneWidget);

    await _settleDebounce(tester);
    await tester.pumpAndSettle();

    expect(find.text('Great Stout'), findsOneWidget);
    expect(find.text('Beer 0'), findsNothing);
  });

  testWidgets('clearing the search restores the unfiltered feed', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beers(1)[0]],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..beersByRequest['1|stout|||'] = PagedResult(
        items: const [
          Beer(
            id: 'stout-1',
            officialName: 'Great Stout',
            breweryId: 'b',
            verified: false,
          ),
        ],
        page: 1,
        pageSize: 20,
        total: 1,
      );

    await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'stout');
    await _settleDebounce(tester);
    await tester.pumpAndSettle();
    expect(find.text('Great Stout'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Beer 0'), findsOneWidget);
    expect(find.text('Great Stout'), findsNothing);
  });

  testWidgets('a query matching nothing shows the no-results message', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..beersByPage[1] = PagedResult(
        items: [_beers(1)[0]],
        page: 1,
        pageSize: 20,
        total: 1,
      )
      ..beersByRequest['1|nomatch|||'] = const PagedResult(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
      );

    await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nomatch');
    await _settleDebounce(tester);
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.discoverNoResultsMessage), findsOneWidget);
  });

  group('filters bottom sheet', () {
    FakeCatalogRepository seededRepository() {
      return FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beers(1)[0]],
          page: 1,
          pageSize: 20,
          total: 1,
        )
        ..beerStyles = const [BeerStyle(id: 'style-1', name: 'Stout')]
        ..countries = const [
          Country(
            id: 'country-1',
            isoCode: 'IE',
            name: 'Ireland',
            continent: 'Europe',
          ),
        ]
        ..breweriesByPage[1] = const PagedResult(
          items: [
            Brewery(
              id: 'brewery-1',
              name: 'Guinness',
              countryId: 'country-1',
              verified: true,
            ),
          ],
          page: 1,
          pageSize: 100,
          total: 1,
        )
        ..beersByRequest['1||country-1|style-1|brewery-1'] = PagedResult(
          items: const [
            Beer(
              id: 'filtered-1',
              officialName: 'Filtered Beer',
              breweryId: 'b',
              verified: false,
            ),
          ],
          page: 1,
          pageSize: 20,
          total: 1,
        );
    }

    testWidgets(
      'selecting chips does not call the controller until Show results is tapped',
      (tester) async {
        final repository = seededRepository();
        await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filters'));
        await tester.pumpAndSettle();

        repository.callLog.clear();
        await tester.tap(find.text('Stout'));
        await tester.tap(find.text('Ireland'));
        await tester.tap(find.text('Guinness'));
        await tester.pump();

        expect(
          repository.callLog.where((c) => c.startsWith('getBeers')),
          isEmpty,
        );
        expect(
          find.text('Beer 0'),
          findsOneWidget,
        ); // main screen unaffected while sheet is open

        await tester.tap(find.text('Show results'));
        await tester.pumpAndSettle();

        expect(
          repository.callLog.where((c) => c.startsWith('getBeers')),
          hasLength(1),
        );
        expect(find.text('Filtered Beer'), findsOneWidget);
      },
    );

    testWidgets('dismissing the sheet without confirming changes nothing', (
      tester,
    ) async {
      final repository = seededRepository();
      await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stout'));
      await tester.pump();

      // Dismiss by tapping the scrim above the sheet content.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('Beer 0'), findsOneWidget);
      expect(find.text('Filtered Beer'), findsNothing);
      expect(
        find.text('Filters'),
        findsOneWidget,
      ); // no active-filter count badge
    });

    testWidgets(
      'Clear all inside the sheet only clears the draft until confirmed',
      (tester) async {
        final repository = seededRepository();
        await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filters'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stout'));
        await tester.pump();
        await tester.tap(find.text('Clear all'));
        await tester.pump();
        await tester.tap(find.text('Show results'));
        await tester.pumpAndSettle();

        // Clearing the draft then confirming is equivalent to applying no
        // filters -- the unfiltered feed stays visible.
        expect(find.text('Beer 0'), findsOneWidget);
        expect(find.text('Filtered Beer'), findsNothing);
      },
    );

    testWidgets(
      'removing an active filter chip on the main screen applies immediately',
      (tester) async {
        final repository = seededRepository();
        await tester.pumpWidget(_wrap(DiscoverScreen(repository: repository)));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Filters'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Stout'));
        await tester.tap(find.text('Ireland'));
        await tester.tap(find.text('Guinness'));
        await tester.tap(find.text('Show results'));
        await tester.pumpAndSettle();
        expect(find.text('Filtered Beer'), findsOneWidget);

        repository.beersByRequest['1||country-1||brewery-1'] = PagedResult(
          items: [_beers(1)[0]],
          page: 1,
          pageSize: 20,
          total: 1,
        );
        // Delete the "Stout" active-filter chip's remove icon (Material 3's
        // default FilterChip delete affordance is Icons.clear, distinct from
        // the search field's own Icons.close clear button). The chip row
        // scrolls horizontally, so scroll it into view first.
        final chipFinder = find.ancestor(
          of: find.text('Stout'),
          matching: find.byType(FilterChip),
        );
        final deleteIconFinder = find.descendant(
          of: chipFinder,
          matching: find.byIcon(Icons.clear),
        );
        await tester.ensureVisible(deleteIconFinder);
        await tester.pumpAndSettle();
        await tester.tap(deleteIconFinder);
        await tester.pumpAndSettle();

        expect(find.text('Beer 0'), findsOneWidget);
        expect(find.text('Filtered Beer'), findsNothing);
      },
    );
  });

  testWidgets(
    'navigating to a pushed screen and back preserves query and results '
    '(the same Navigator/state-retention mechanism app/router.dart relies on '
    'for the real beer-detail push)',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beers(1)[0]],
          page: 1,
          pageSize: 20,
          total: 1,
        )
        ..beersByRequest['1|stout|||'] = PagedResult(
          items: const [
            Beer(
              id: 'stout-1',
              officialName: 'Great Stout',
              breweryId: 'b',
              verified: false,
            ),
          ],
          page: 1,
          pageSize: 20,
          total: 1,
        );

      final router = GoRouter(
        initialLocation: '/discover',
        routes: [
          GoRoute(
            path: '/discover',
            builder: (context, state) => DiscoverScreen(repository: repository),
          ),
          GoRoute(
            path: '/detail',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'stout');
      await _settleDebounce(tester);
      await tester.pumpAndSettle();
      expect(find.text('Great Stout'), findsOneWidget);

      router.push('/detail');
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(find.text('Great Stout'), findsOneWidget);
      expect(find.text('stout'), findsOneWidget);
    },
  );
}
