import 'package:beerapp/features/map/domain/map_mode.dart';
import 'package:beerapp/features/map/presentation/map_mode_selector.dart';
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
    'renders one chip per mode, with the selected one shown as selected',
    (tester) async {
      await tester.pumpWidget(
        _wrap(MapModeSelector(selected: MapMode.tried, onChanged: (_) {})),
      );

      expect(find.text('All beers'), findsOneWidget);
      expect(find.text('Tried'), findsOneWidget);
      expect(find.text('Not tried'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Wishlist'), findsOneWidget);
      expect(find.text('Breweries'), findsOneWidget);

      final chip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Tried'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(chip.selected, isTrue);
    },
  );

  testWidgets('tapping a chip reports the tapped mode', (tester) async {
    MapMode? tapped;
    await tester.pumpWidget(
      _wrap(
        MapModeSelector(
          selected: MapMode.all,
          onChanged: (mode) => tapped = mode,
        ),
      ),
    );

    await tester.tap(find.text('Favorites'));
    await tester.pump();

    expect(tapped, MapMode.favorites);
  });
}
