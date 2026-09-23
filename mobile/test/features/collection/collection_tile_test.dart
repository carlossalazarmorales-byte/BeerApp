import 'package:beerapp/features/collection/domain/models/collection_beer.dart';
import 'package:beerapp/features/collection/presentation/collection_tile.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

CollectionBeer _beer({DateTime? latestConsumedAt, int? latestRating}) =>
    CollectionBeer(
      beerId: 'beer-1',
      officialName: 'Test Stout',
      breweryName: 'Test Brewery',
      isFavorite: false,
      isWishlist: false,
      latestConsumedAt: latestConsumedAt,
      latestRating: latestRating,
    );

void main() {
  testWidgets('a tried beer (has at least one log) shows unlocked', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        CollectionTile(
          beer: _beer(latestConsumedAt: DateTime.utc(2026, 1, 1)),
          onTap: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets(
    'a beer with no log shows locked -- QA Round 1 Block 1 follow-up: '
    'Collection must keep the correct (non-inverted) rule',
    (tester) async {
      await tester.pumpWidget(
        _wrap(CollectionTile(beer: _beer(), onTap: () {})),
      );

      expect(find.byIcon(Icons.lock), findsOneWidget);
    },
  );
}
