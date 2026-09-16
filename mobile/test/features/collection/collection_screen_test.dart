import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/collection/domain/models/collection_beer.dart';
import 'package:beerapp/features/collection/presentation/collection_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_collection_repository.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

CollectionBeer _beer(String id) => CollectionBeer(
  beerId: id,
  officialName: 'Beer $id',
  breweryName: 'Brewery',
  isFavorite: false,
  isWishlist: false,
);

void main() {
  testWidgets('shows the Logged tab\'s empty state by default', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CollectionScreen(
          repository: FakeCollectionRepository(),
          catalogRepository: FakeCatalogRepository(),
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You haven't logged any beers yet."), findsOneWidget);
  });

  testWidgets(
    'switching to the Favorites tab calls getFavorites and shows its own empty message',
    (tester) async {
      final repository = FakeCollectionRepository();
      await tester.pumpWidget(
        _wrap(
          CollectionScreen(
            repository: repository,
            catalogRepository: FakeCatalogRepository(),
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Favorites'));
      await tester.pumpAndSettle();

      expect(
        repository.callLog.where((c) => c.startsWith('getFavorites')),
        isNotEmpty,
      );
      expect(find.text("You haven't favorited any beers yet."), findsOneWidget);
    },
  );

  testWidgets('switching to the Wishlist tab calls getWishlist', (
    tester,
  ) async {
    final repository = FakeCollectionRepository();
    await tester.pumpWidget(
      _wrap(
        CollectionScreen(
          repository: repository,
          catalogRepository: FakeCatalogRepository(),
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();

    expect(
      repository.callLog.where((c) => c.startsWith('getWishlist')),
      isNotEmpty,
    );
    expect(find.text('Your wishlist is empty.'), findsOneWidget);
  });

  testWidgets('renders a logged beer once loaded', (tester) async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );

    await tester.pumpWidget(
      _wrap(
        CollectionScreen(
          repository: repository,
          catalogRepository: FakeCatalogRepository(),
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beer 1'), findsOneWidget);
  });

  testWidgets('pull-to-refresh re-issues a request for the active tab', (
    tester,
  ) async {
    final repository = FakeCollectionRepository()
      ..loggedByPage[1] = PagedResult(
        items: [_beer('1')],
        page: 1,
        pageSize: 20,
        total: 1,
      );

    await tester.pumpWidget(
      _wrap(
        CollectionScreen(
          repository: repository,
          catalogRepository: FakeCatalogRepository(),
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.callLog.clear();

    await tester.drag(find.text('Beer 1'), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(
      repository.callLog.where((c) => c.startsWith('getLogged')),
      isNotEmpty,
    );
  });
}
