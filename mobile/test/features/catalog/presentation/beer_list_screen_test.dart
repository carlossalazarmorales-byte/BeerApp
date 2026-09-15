import 'package:beerapp/design_system/components/states/empty_state.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/design_system/components/states/loading_state.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/catalog/presentation/beer_list/beer_list_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_catalog_repository.dart';

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

    await tester.pumpWidget(_wrap(BeerListScreen(repository: repository)));
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
      await tester.pumpWidget(_wrap(BeerListScreen(repository: repository)));
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
    await tester.pumpWidget(_wrap(BeerListScreen(repository: repository)));
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

    await tester.pumpWidget(_wrap(BeerListScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Beer 30'), findsNothing);

    await tester.fling(find.byType(ListView), const Offset(0, -20000), 3000);
    await tester.pumpAndSettle();

    expect(find.text('Beer 30'), findsOneWidget);
  });
}
