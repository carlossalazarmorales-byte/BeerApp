import 'package:beerapp/app/app.dart';
import 'package:beerapp/design_system/components/navigation/bottom_nav_bar.dart';
import 'package:beerapp/design_system/components/navigation/scan_nav_button.dart';
import 'package:beerapp/features/collection/presentation/collection_screen.dart';
import 'package:beerapp/features/discover/presentation/discover_screen.dart';
import 'package:beerapp/features/map/presentation/map_screen.dart';
import 'package:beerapp/features/profile/presentation/profile_screen.dart';
import 'package:beerapp/features/scan/presentation/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

int _selectedTabIndex(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index ?? 0;
}

/// The bottom nav bar's own Text('Map')/etc. label — screen AppBars reuse
/// the same localized strings as their titles, so an unscoped `find.text`
/// would match both.
Finder _navLabel(String label) =>
    find.descendant(of: find.byType(BottomNavBar), matching: find.text(label));

void main() {
  testWidgets('app builds without throwing and defaults to the Map tab', (
    tester,
  ) async {
    await tester.pumpWidget(const BeerApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_selectedTabIndex(tester), 0);
    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('tapping each bottom nav item switches to the matching tab', (
    tester,
  ) async {
    await tester.pumpWidget(const BeerApp());
    await tester.pumpAndSettle();

    await tester.tap(_navLabel('Discover'));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 1);

    await tester.tap(_navLabel('Collection'));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 3);

    await tester.tap(_navLabel('Profile'));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 4);

    await tester.tap(_navLabel('Map'));
    await tester.pumpAndSettle();
    expect(_selectedTabIndex(tester), 0);
  });

  testWidgets(
    'the Scan action navigates to the Scan tab like any other destination',
    (tester) async {
      await tester.pumpWidget(const BeerApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ScanNavButton));
      await tester.pumpAndSettle();

      expect(_selectedTabIndex(tester), 2);
    },
  );

  testWidgets(
    'all 5 feature screens are mounted in the stack (state preserved across switches)',
    (tester) async {
      await tester.pumpWidget(const BeerApp());
      await tester.pumpAndSettle();

      final mapScreenBefore = tester.widget(find.byType(MapScreen));

      await tester.tap(_navLabel('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(_navLabel('Map'));
      await tester.pumpAndSettle();

      // The other 4 tabs are currently offstage (only the selected
      // IndexedStack child paints/hit-tests), so `skipOffstage: false` is
      // required to find them — that offstage-but-mounted state is exactly
      // what proves their widget state is preserved, not rebuilt.
      expect(find.byType(MapScreen), findsOneWidget);
      expect(find.byType(DiscoverScreen, skipOffstage: false), findsOneWidget);
      expect(find.byType(ScanScreen, skipOffstage: false), findsOneWidget);
      expect(
        find.byType(CollectionScreen, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.byType(ProfileScreen, skipOffstage: false), findsOneWidget);

      final mapScreenAfter = tester.widget(find.byType(MapScreen));
      expect(identical(mapScreenBefore, mapScreenAfter), isTrue);
    },
  );
}
