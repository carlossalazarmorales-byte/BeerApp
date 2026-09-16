import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/features/map/domain/models/map_beer.dart';
import 'package:beerapp/features/map/presentation/beer_preview_card.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _beer = MapBeer(
  beerId: 'beer-1',
  officialName: 'La Chouffe',
  breweryName: 'Achouffe',
  latitude: 50.2,
  longitude: 5.7,
  countryName: 'Belgium',
  isTried: true,
  isFavorite: true,
  isWishlist: false,
);

Widget _harness(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  testWidgets('renders beer name, brewery/country subtitle and status chips', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/map',
      routes: [
        GoRoute(
          path: '/map',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const BeerPreviewCard(beer: _beer),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.beerDetail,
          builder: (context, state) => const SizedBox(),
        ),
      ],
    );

    await tester.pumpWidget(_harness(router));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('La Chouffe'), findsOneWidget);
    expect(find.text('Achouffe · Belgium'), findsOneWidget);
    expect(find.text('Tried'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Wishlist'), findsNothing);
  });

  testWidgets(
    'View details dismisses the sheet and navigates to the beer detail route',
    (tester) async {
      String? pushedBeerId;
      final router = GoRouter(
        initialLocation: '/map',
        routes: [
          GoRoute(
            path: '/map',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const BeerPreviewCard(beer: _beer),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.beerDetail,
            builder: (context, state) {
              pushedBeerId = state.pathParameters['beerId'];
              return const Scaffold(body: Text('Beer Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(_harness(router));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('View details'));
      await tester.pumpAndSettle();

      expect(pushedBeerId, 'beer-1');
      expect(find.text('Beer Detail'), findsOneWidget);
      expect(
        find.byType(BeerPreviewCard),
        findsNothing,
        reason: 'the sheet is dismissed before pushing, not left underneath',
      );
    },
  );
}
