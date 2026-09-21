import 'package:beerapp/app/startup_failure_app.dart';
import 'package:beerapp/design_system/components/buttons/primary_button.dart';
import 'package:beerapp/design_system/components/buttons/secondary_button.dart';
import 'package:beerapp/design_system/components/chips/app_filter_chip.dart';
import 'package:beerapp/design_system/components/inputs/app_text_field.dart';
import 'package:beerapp/design_system/components/navigation/bottom_nav_bar.dart';
import 'package:beerapp/design_system/components/states/empty_state.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/design_system/theme/app_theme.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/presentation/beer_list/beer_list_tile.dart';
import 'package:beerapp/features/collection/domain/models/collection_beer.dart';
import 'package:beerapp/features/collection/presentation/collection_tile.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Application accessibility audit: the semantics tree, tap targets, keyboard
/// focus and large-text behaviour of the shared components and list tiles.
/// This is an audit of THIS app's widgets, not a WCAG certification.

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Locale locale = const Locale('en'),
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

const _beer = Beer(
  id: 'b1',
  officialName: 'Golden Harbor Lager',
  breweryId: 'br1',
  verified: true,
  abv: 5.2,
);

const _longNameBeer = Beer(
  id: 'b2',
  officialName:
      'Extraordinarily Long Imperial Barrel Aged Chocolate Hazelnut Stout',
  breweryId: 'br1',
  verified: true,
  abv: 11.5,
);

const _collectionBeer = CollectionBeer(
  beerId: 'b1',
  officialName: 'Golden Harbor Lager',
  breweryName: 'Northern Fox Brewing',
  styleName: 'Pale Lager',
  countryName: 'Ireland',
  isFavorite: true,
  isWishlist: false,
  latestRating: 4,
);

void main() {
  group('custom buttons expose button semantics', () {
    testWidgets('PrimaryButton (enabled) is a labelled, enabled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, PrimaryButton(label: 'Continue', onPressed: () {}));

      expect(
        tester.getSemantics(find.text('Continue')),
        isSemantics(
          label: 'Continue',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('PrimaryButton (disabled) says so and offers no tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const PrimaryButton(label: 'Continue', onPressed: null),
      );

      expect(
        tester.getSemantics(find.text('Continue')),
        isSemantics(
          label: 'Continue',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('SecondaryButton (enabled) is a labelled, enabled button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, SecondaryButton(label: 'Cancel', onPressed: () {}));

      expect(
        tester.getSemantics(find.text('Cancel')),
        isSemantics(
          label: 'Cancel',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('SecondaryButton (disabled) says so', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const SecondaryButton(label: 'Cancel', onPressed: null),
      );

      expect(
        tester.getSemantics(find.text('Cancel')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      handle.dispose();
    });
  });

  group('keyboard / switch access', () {
    testWidgets(
      'PrimaryButton can be focused and activated from the keyboard',
      (tester) async {
        var pressed = 0;
        await _pump(
          tester,
          PrimaryButton(label: 'Continue', onPressed: () => pressed++),
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(pressed, 1);
      },
    );

    testWidgets('a disabled PrimaryButton is skipped by keyboard focus', (
      tester,
    ) async {
      var pressed = 0;
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrimaryButton(label: 'Disabled', onPressed: null),
            PrimaryButton(label: 'Enabled', onPressed: () => pressed++),
          ],
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(pressed, 1, reason: 'first focus stop must be the ENABLED button');
    });
  });

  group('tap targets are at least 48 x 48 dp', () {
    testWidgets('PrimaryButton and SecondaryButton', (tester) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: 'Go', onPressed: () {}),
            SecondaryButton(label: 'No', onPressed: () {}),
          ],
        ),
      );

      for (final type in [PrimaryButton, SecondaryButton]) {
        final size = tester.getSize(find.byType(type));
        expect(size.height, greaterThanOrEqualTo(48), reason: '$type height');
      }
    });

    testWidgets('AppFilterChip hit area', (tester) async {
      await _pump(
        tester,
        AppFilterChip(label: 'Lager', selected: false, onSelected: (_) {}),
      );

      // The tappable area is the chip's layout box (a shrink-wrapped chip is
      // exactly as tall as it looks -- below the 48dp minimum).
      final size = tester.getSize(find.byType(FilterChip));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });

  group('form fields have an accessible name', () {
    testWidgets('AppTextField exposes its hint as the field label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const AppTextField(hintText: 'Email'));

      expect(
        tester.getSemantics(find.byType(TextField)),
        isSemantics(isTextField: true, label: 'Email'),
      );
      handle.dispose();
    });

    testWidgets('an empty field is named once and still draws its hint', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const AppTextField(hintText: 'Email'));

      final data = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(data.label, 'Email', reason: 'not "Email\nEmail"');
      // Hidden from semantics, but the placeholder is still visible.
      expect(find.text('Email'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the name is still announced once text has been typed', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final controller = TextEditingController(text: 'someone@example.com');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        AppTextField(hintText: 'Email', controller: controller),
      );

      final data = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(data.label, contains('Email'));
      expect(data.value, 'someone@example.com');
      handle.dispose();
    });

    testWidgets('a validation error is announced with the field', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const AppTextField(hintText: 'Email', errorText: 'Enter a valid email'),
      );

      final data = tester
          .getSemantics(find.byType(TextField))
          .getSemanticsData();
      expect(
        '${data.label} ${data.hint} ${data.value}',
        contains('Enter a valid email'),
      );
      handle.dispose();
    });
  });

  group('list tiles are single, labelled buttons', () {
    testWidgets('BeerListTile', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        BeerListTile(
          beer: _beer,
          styleName: 'Pale Lager',
          countryName: 'Ireland',
          onTap: () {},
        ),
      );

      final node = tester.getSemantics(find.text('Golden Harbor Lager'));
      expect(node, isSemantics(isButton: true, hasTapAction: true));
      final label = node.getSemanticsData().label;
      expect(label, contains('Golden Harbor Lager'));
      expect(label, contains('Pale Lager'));
      handle.dispose();
    });

    testWidgets('CollectionTile', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, CollectionTile(beer: _collectionBeer, onTap: () {}));

      final node = tester.getSemantics(find.text('Golden Harbor Lager'));
      expect(node, isSemantics(isButton: true, hasTapAction: true));
      expect(node.getSemanticsData().label, contains('Northern Fox Brewing'));
      handle.dispose();
    });
  });

  group('state that is otherwise icon-only is announced', () {
    testWidgets('CollectionTile announces favorite, wishlist and rating', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        CollectionTile(
          beer: const CollectionBeer(
            beerId: 'b1',
            officialName: 'Golden Harbor Lager',
            breweryName: 'Northern Fox Brewing',
            isFavorite: true,
            isWishlist: true,
            latestRating: 4,
          ),
          onTap: () {},
        ),
      );

      final label = tester
          .getSemantics(find.text('Golden Harbor Lager'))
          .getSemanticsData()
          .label;
      expect(label, contains('Favorites'));
      expect(label, contains('Wishlist'));
      expect(label, contains('Rated 4 out of 5'));
      handle.dispose();
    });

    testWidgets('CollectionTile announces state in Spanish', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        CollectionTile(beer: _collectionBeer, onTap: () {}),
        locale: const Locale('es'),
      );

      final label = tester
          .getSemantics(find.text('Golden Harbor Lager'))
          .getSemanticsData()
          .label;
      expect(label, contains('Favoritas'));
      expect(label, contains('Valoración: 4 de 5'));
      handle.dispose();
    });

    testWidgets('each nav item is one button named once', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomNavBar(selectedIndex: 3, onSelect: (_) {}),
        ),
      );

      final node = tester.getSemantics(find.text('Collection'));
      final data = node.getSemanticsData();
      expect(data.label.trim(), 'Collection', reason: 'named exactly once');
      expect(
        node,
        isSemantics(isButton: true, isSelected: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('large text (2.0x) does not overflow', () {
    Future<void> expectNoOverflow(
      WidgetTester tester,
      Widget child, {
      double width = 360,
    }) async {
      await _pump(tester, child, textScale: 2, width: width);
      expect(tester.takeException(), isNull);
    }

    testWidgets('PrimaryButton with a long label', (tester) async {
      await expectNoOverflow(
        tester,
        SizedBox(
          width: 280,
          child: PrimaryButton(
            label: 'Create your BeerApp account today',
            icon: Icons.add,
            onPressed: () {},
          ),
        ),
      );
    });

    testWidgets('SecondaryButton with a long label', (tester) async {
      await expectNoOverflow(
        tester,
        SizedBox(
          width: 280,
          child: SecondaryButton(
            label: 'Continue without creating an account',
            onPressed: () {},
          ),
        ),
      );
    });

    testWidgets('BeerListTile with a long name', (tester) async {
      await expectNoOverflow(
        tester,
        SizedBox(
          width: 340,
          child: BeerListTile(
            beer: _longNameBeer,
            styleName: 'Imperial Stout',
            countryName: 'United States of America',
            onTap: () {},
          ),
        ),
      );
    });

    testWidgets('CollectionTile with a long name', (tester) async {
      await expectNoOverflow(
        tester,
        SizedBox(
          width: 340,
          child: CollectionTile(
            beer: const CollectionBeer(
              beerId: 'b',
              officialName:
                  'Extraordinarily Long Imperial Barrel Aged Chocolate Stout',
              breweryName: 'The Extraordinarily Long Brewery Company Ltd',
              isFavorite: true,
              isWishlist: true,
              latestRating: 5,
            ),
            onTap: () {},
          ),
        ),
      );
    });

    testWidgets('the bottom navigation bar', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomNavBar(selectedIndex: 0, onSelect: (_) {}),
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bottom navigation bar in Spanish', (tester) async {
      await _pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: BottomNavBar(selectedIndex: 3, onSelect: (_) {}),
        ),
        textScale: 2,
        locale: const Locale('es'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('error and empty states', (tester) async {
      await expectNoOverflow(
        tester,
        SizedBox(
          height: 700,
          child: ErrorState(
            message: 'Something went wrong. Try again.',
            onRetry: () {},
          ),
        ),
      );
      await expectNoOverflow(
        tester,
        const SizedBox(
          height: 700,
          child: EmptyState(message: 'Nothing here yet'),
        ),
      );
    });

    testWidgets('a filter chip', (tester) async {
      await expectNoOverflow(
        tester,
        AppFilterChip(
          label: 'India Pale Ale',
          selected: true,
          onSelected: (_) {},
        ),
      );
    });

    testWidgets('the startup failure screen', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        StartupFailureApp(
          kind: StartupFailureKind.initialization,
          onRetry: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
