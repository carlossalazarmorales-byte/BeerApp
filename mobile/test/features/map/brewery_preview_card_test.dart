import 'package:beerapp/features/map/domain/models/map_brewery.dart';
import 'package:beerapp/features/map/presentation/brewery_preview_card.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets(
    'renders name, location, description, website and verified badge',
    (tester) async {
      const brewery = MapBrewery(
        breweryId: 'brewery-1',
        name: 'Brasserie d\'Achouffe',
        latitude: 50.2,
        longitude: 5.7,
        verified: true,
        countryName: 'Belgium',
        city: 'Achouffe',
        description: 'A Belgian brewery known for La Chouffe.',
        website: 'https://achouffe.com',
      );

      await tester.pumpWidget(
        _wrap(const BreweryPreviewCard(brewery: brewery)),
      );

      expect(find.text('Brasserie d\'Achouffe'), findsOneWidget);
      expect(find.text('Achouffe · Belgium'), findsOneWidget);
      expect(
        find.text('A Belgian brewery known for La Chouffe.'),
        findsOneWidget,
      );
      expect(find.text('https://achouffe.com'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    },
  );

  testWidgets('omits optional sections and badge when absent', (tester) async {
    const brewery = MapBrewery(
      breweryId: 'brewery-2',
      name: 'Sierra Desert Test Brewery',
      latitude: 10,
      longitude: 20,
      verified: false,
    );

    await tester.pumpWidget(_wrap(const BreweryPreviewCard(brewery: brewery)));

    expect(find.text('Sierra Desert Test Brewery'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
  });
}
