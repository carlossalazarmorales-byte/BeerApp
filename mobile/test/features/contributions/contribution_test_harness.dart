import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/beer_style.dart';
import 'package:beerapp/features/catalog/domain/models/brewery.dart';
import 'package:beerapp/features/catalog/domain/models/country.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/contributions/presentation/contributions_screen.dart';
import 'package:beerapp/features/contributions/presentation/suggest_beer_screen.dart';
import 'package:beerapp/features/contributions/presentation/suggest_brewery_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_contribution_repository.dart';

const testBrewery = Brewery(
  id: 'brewery-1',
  name: 'Hop House',
  countryId: 'country-1',
  verified: true,
  city: 'Munich',
);

const testCatalogBeer = Beer(
  id: 'beer-1',
  officialName: 'Hazy IPA',
  breweryId: 'brewery-1',
  verified: true,
  abv: 6.5,
);

/// A catalog with one brewery, two styles and two countries -- enough for
/// every picker.
FakeCatalogRepository catalogWithOptions() {
  return FakeCatalogRepository()
    ..countries = const [
      Country(
        id: 'country-1',
        isoCode: 'DE',
        name: 'Germany',
        continent: 'Europe',
      ),
      Country(
        id: 'country-2',
        isoCode: 'IE',
        name: 'Ireland',
        continent: 'Europe',
      ),
    ]
    ..beerStyles = const [
      BeerStyle(id: 'style-1', name: 'IPA'),
      BeerStyle(id: 'style-2', name: 'Stout'),
    ]
    ..breweriesByPage[1] = const PagedResult(
      items: [testBrewery],
      page: 1,
      pageSize: 100,
      total: 1,
    );
}

/// Mounts the real screens inside a real [GoRouter] so `context.push`/`pop`
/// behave as in the app. A launcher home route pushes the screen under test
/// and records what it popped with.
class ContributionHarness {
  ContributionHarness({
    FakeContributionRepository? contributions,
    FakeCatalogRepository? catalog,
    this.location = AppRoutes.suggestBeer,
  }) : contributions = contributions ?? FakeContributionRepository(),
       catalog = catalog ?? catalogWithOptions();

  final FakeContributionRepository contributions;
  final FakeCatalogRepository catalog;
  final String location;

  /// What the pushed screen popped with (`true` after "Done").
  Object? poppedWith;
  bool popped = false;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                poppedWith = await context.push<Object>(location);
                popped = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.contributions,
        builder: (context, state) =>
            ContributionsScreen(repository: contributions),
      ),
      GoRoute(
        path: AppRoutes.suggestBeer,
        builder: (context, state) => SuggestBeerScreen(
          contributionRepository: contributions,
          catalogRepository: catalog,
          initialName: state.uri.queryParameters['name'],
          initialBarcode: state.uri.queryParameters['barcode'],
        ),
      ),
      GoRoute(
        path: AppRoutes.suggestBrewery,
        builder: (context, state) => SuggestBreweryScreen(
          contributionRepository: contributions,
          catalogRepository: catalog,
        ),
      ),
      GoRoute(
        path: AppRoutes.beerDetail,
        builder: (context, state) => Scaffold(
          body: Text('Beer detail: ${state.pathParameters['beerId']}'),
        ),
      ),
    ],
  );

  Widget app({Locale? locale}) => MaterialApp.router(
    routerConfig: router,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );

  /// Pumps the app and opens [location] on top of the launcher route.
  Future<void> open(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(app(locale: locale));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

/// Picks [label] from the [index]-th dropdown on screen.
Future<void> pickFromDropdown(
  WidgetTester tester,
  int index,
  String label,
) async {
  await tester.ensureVisible(
    find.byType(DropdownButtonFormField<String>).at(index),
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Types into the text field whose hint text is [hint].
Future<void> enterByHint(WidgetTester tester, String hint, String text) async {
  final field = find.widgetWithText(TextFormField, hint);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

/// Taps the primary "Submit suggestion" button.
Future<void> tapSubmit(WidgetTester tester) async {
  final button = find.text('Submit suggestion');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}
