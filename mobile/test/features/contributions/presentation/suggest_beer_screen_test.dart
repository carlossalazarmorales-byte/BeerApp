import 'dart:async';

import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/features/contributions/domain/models/duplicate_candidates.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_contribution_repository.dart';
import '../contribution_test_harness.dart';

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

BeerDuplicateCandidates _candidates({
  bool nameMatch = false,
  bool pendingBarcode = false,
  bool barcodeOwner = false,
  bool alreadySubmitted = false,
}) => BeerDuplicateCandidates(
  barcodeMatch: barcodeOwner ? testCatalogBeer : null,
  nameMatches: nameMatch ? [testCatalogBeer] : const [],
  breweryMatches: const [],
  alreadySubmitted: alreadySubmitted,
  pendingBarcodeDuplicateExists: pendingBarcode,
);

/// Fills the minimum valid form: a name and the catalog brewery.
Future<void> _fillMinimal(WidgetTester tester) async {
  await enterByHint(tester, 'Beer name', 'New Beer');
  await pickFromDropdown(tester, 0, 'Hop House');
}

void main() {
  testWidgets('loads the pickers, then shows the form', (tester) async {
    _useTallScreen(tester);
    final harness = ContributionHarness();
    await harness.open(tester);

    expect(find.text('Suggest a beer'), findsOneWidget); // app bar
    expect(find.text('Beer name'), findsOneWidget);
    expect(find.text('Brewery'), findsOneWidget);
    expect(
      find.text('Style (optional)'),
      findsNothing,
    ); // has a value: "No style"
    expect(find.text('No style'), findsOneWidget);
    expect(find.text('ABV % (optional)'), findsOneWidget);
    expect(find.text('Barcode (optional)'), findsOneWidget);
    expect(find.text('Submit suggestion'), findsOneWidget);
  });

  testWidgets('an options failure shows an error state and retry recovers', (
    tester,
  ) async {
    _useTallScreen(tester);
    final catalog = catalogWithOptions()..getBeerStylesError = Exception('x');
    final harness = ContributionHarness(catalog: catalog);
    await harness.open(tester);

    expect(find.byType(ErrorState), findsOneWidget);

    catalog.getBeerStylesError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Submit suggestion'), findsOneWidget);
  });

  testWidgets('an empty form shows validation and submits nothing', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = ContributionHarness();
    await harness.open(tester);

    await tapSubmit(tester);

    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('Choose a brewery or enter its name.'), findsOneWidget);
    expect(harness.contributions.callLog, isEmpty);
  });

  testWidgets('a malformed ABV and barcode are caught before any request', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = ContributionHarness();
    await harness.open(tester);
    await _fillMinimal(tester);
    await enterByHint(tester, 'ABV % (optional)', '150');
    await enterByHint(tester, 'Barcode (optional)', '12345');

    await tapSubmit(tester);

    expect(
      find.text('Enter an ABV between 0 and 99.99 with at most 2 decimals.'),
      findsOneWidget,
    );
    expect(
      find.text('Enter digits only (8, 12 or 13 digits).'),
      findsOneWidget,
    );
    expect(harness.contributions.callLog, isEmpty);
  });

  testWidgets(
    'submitting stores a pending suggestion and says so -- never "added"',
    (tester) async {
      _useTallScreen(tester);
      final harness = ContributionHarness();
      await harness.open(tester);
      await _fillMinimal(tester);
      await enterByHint(tester, 'ABV % (optional)', '6,5');

      await tapSubmit(tester);

      final submitted = harness.contributions.submittedBeers.single;
      expect(submitted.officialName, 'New Beer');
      expect(submitted.breweryId, 'brewery-1');
      expect(submitted.proposedBreweryName, isNull);
      expect(submitted.styleId, isNull);
      expect(submitted.abv, 6.5);

      expect(find.text('Suggestion received'), findsOneWidget);
      expect(
        find.text(
          "It's pending review. It won't appear in the catalog until it has been reviewed.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('added', findRichText: true), findsNothing);
      expect(find.textContaining('Beer added'), findsNothing);
      // No consumption side effects exist on this path: the only repository
      // touched is the contribution one, and only for the check + submit.
      expect(harness.contributions.callLog, ['checkBeer', 'submitBeer']);
    },
  );

  testWidgets(
    '"Done" closes the screen and reports that something was stored',
    (tester) async {
      _useTallScreen(tester);
      final harness = ContributionHarness();
      await harness.open(tester);
      await _fillMinimal(tester);
      await tapSubmit(tester);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(harness.popped, isTrue);
      expect(harness.poppedWith, true);
    },
  );

  testWidgets(
    '"Not listed" reveals a text field and needs no separate brewery suggestion',
    (tester) async {
      _useTallScreen(tester);
      final harness = ContributionHarness();
      await harness.open(tester);
      await enterByHint(tester, 'Beer name', 'New Beer');
      expect(find.text('Brewery name'), findsNothing);

      await pickFromDropdown(tester, 0, 'Not listed');
      expect(find.text('Brewery name'), findsOneWidget);
      await enterByHint(tester, 'Brewery name', '  Brand   New Brewery ');
      await tapSubmit(tester);

      final submitted = harness.contributions.submittedBeers.single;
      expect(submitted.breweryId, isNull);
      // The client only trims the edges; the backend collapses internal
      // whitespace (the one normalizer), so it is sent as typed.
      expect(submitted.proposedBreweryName, 'Brand   New Brewery');
      // The beer went through on its own: no brewery contribution exists.
      expect(harness.contributions.submittedBreweries, isEmpty);
      expect(harness.contributions.callLog, ['checkBeer', 'submitBeer']);
      expect(find.text('Suggestion received'), findsOneWidget);
    },
  );

  testWidgets('a "Not listed" brewery still needs a name', (tester) async {
    _useTallScreen(tester);
    final harness = ContributionHarness();
    await harness.open(tester);
    await enterByHint(tester, 'Beer name', 'New Beer');
    await pickFromDropdown(tester, 0, 'Not listed');

    await tapSubmit(tester);

    expect(find.text('This field is required.'), findsOneWidget);
    expect(harness.contributions.callLog, isEmpty);
  });

  testWidgets('a style can be canonical, "Not listed", or left out', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = ContributionHarness();
    await harness.open(tester);
    await _fillMinimal(tester);
    await pickFromDropdown(tester, 1, 'Stout');
    await tapSubmit(tester);
    expect(harness.contributions.submittedBeers.single.styleId, 'style-2');

    final second = ContributionHarness();
    await second.open(tester);
    await _fillMinimal(tester);
    await pickFromDropdown(tester, 1, 'Not listed');
    await enterByHint(tester, 'Style name', 'Weird Style');
    await tapSubmit(tester);
    final proposed = second.contributions.submittedBeers.single;
    expect(proposed.styleId, isNull);
    expect(proposed.proposedStyleName, 'Weird Style');
  });

  testWidgets('prefills the name and barcode from a failed search/scan', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = ContributionHarness(
      location: AppRoutes.suggestBeerPath(
        name: 'Foo & Bar #1',
        barcode: '4006381333931',
      ),
    );
    await harness.open(tester);

    expect(find.text('Foo & Bar #1'), findsOneWidget);
    expect(find.text('4006381333931'), findsOneWidget);
  });

  testWidgets('a prefilled barcode is sent to the backend as entered', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = ContributionHarness(
      location: AppRoutes.suggestBeerPath(barcode: '036000291452'),
    );
    await harness.open(tester);
    await enterByHint(tester, 'Beer name', 'Scanned Beer');
    await pickFromDropdown(tester, 0, 'Hop House');

    await tapSubmit(tester);

    expect(harness.contributions.checkedBeers.single.barcode, '036000291452');
    expect(harness.contributions.submittedBeers.single.barcode, '036000291452');
  });

  group('duplicate handling', () {
    testWidgets(
      'similar beers warn without blocking; "Submit anyway" submits',
      (tester) async {
        _useTallScreen(tester);
        final harness = ContributionHarness(
          contributions: FakeContributionRepository()
            ..beerCandidates = _candidates(nameMatch: true),
        );
        await harness.open(tester);
        await _fillMinimal(tester);

        await tapSubmit(tester);

        expect(find.text('Similar entries found'), findsOneWidget);
        expect(
          find.text('Similar beers already in the catalog'),
          findsOneWidget,
        );
        expect(find.text('Hazy IPA'), findsOneWidget);
        // Nothing was submitted just by warning.
        expect(harness.contributions.submittedBeers, isEmpty);

        await tester.tap(find.text('Submit anyway'));
        await tester.pumpAndSettle();

        expect(harness.contributions.submittedBeers, hasLength(1));
        expect(find.text('Suggestion received'), findsOneWidget);
      },
    );

    testWidgets('"Review" goes back to the form and submits nothing', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..beerCandidates = _candidates(nameMatch: true),
      );
      await harness.open(tester);
      await _fillMinimal(tester);
      await tapSubmit(tester);

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      expect(find.text('Similar entries found'), findsNothing);
      expect(find.text('Submit suggestion'), findsOneWidget);
      expect(harness.contributions.submittedBeers, isEmpty);
      expect(find.text('New Beer'), findsOneWidget); // form input preserved
    });

    testWidgets('dismissing the warning sheet never submits', (tester) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..beerCandidates = _candidates(nameMatch: true),
      );
      await harness.open(tester);
      await _fillMinimal(tester);
      await tapSubmit(tester);

      await tester.tapAt(const Offset(10, 10)); // scrim
      await tester.pumpAndSettle();

      expect(find.text('Similar entries found'), findsNothing);
      expect(harness.contributions.submittedBeers, isEmpty);
    });

    testWidgets('a similar beer can be opened from the warning', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..beerCandidates = _candidates(nameMatch: true),
      );
      await harness.open(tester);
      await _fillMinimal(tester);
      await tapSubmit(tester);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(find.text('Beer detail: beer-1'), findsOneWidget);
    });

    testWidgets(
      "another user's pending barcode is a non-blocking notice with no detail",
      (tester) async {
        _useTallScreen(tester);
        final harness = ContributionHarness(
          contributions: FakeContributionRepository()
            ..beerCandidates = _candidates(pendingBarcode: true),
        );
        await harness.open(tester);
        await _fillMinimal(tester);
        await enterByHint(tester, 'Barcode (optional)', '4006381333931');

        await tapSubmit(tester);

        expect(
          find.text(
            'Another pending suggestion may already include this barcode.',
          ),
          findsOneWidget,
        );
        // No catalog sections: nothing else is revealed.
        expect(find.text('Similar beers already in the catalog'), findsNothing);
        expect(harness.contributions.submittedBeers, isEmpty);

        await tester.tap(find.text('Submit anyway'));
        await tester.pumpAndSettle();

        expect(harness.contributions.submittedBeers, hasLength(1));
        expect(find.text('Suggestion received'), findsOneWidget);
      },
    );

    testWidgets(
      'a barcode already in the catalog blocks and links to that beer',
      (tester) async {
        _useTallScreen(tester);
        final harness = ContributionHarness(
          contributions: FakeContributionRepository()
            ..beerCandidates = _candidates(barcodeOwner: true),
        );
        await harness.open(tester);
        await _fillMinimal(tester);
        await enterByHint(tester, 'Barcode (optional)', '4006381333931');

        await tapSubmit(tester);

        expect(
          find.text('This barcode already belongs to a beer in the catalog.'),
          findsOneWidget,
        );
        expect(harness.contributions.submittedBeers, isEmpty);
        expect(find.text('Suggestion received'), findsNothing);

        await tester.tap(find.text('View existing beer'));
        await tester.pumpAndSettle();
        expect(find.text('Beer detail: beer-1'), findsOneWidget);
      },
    );

    testWidgets('your own identical pending suggestion blocks', (tester) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..beerCandidates = _candidates(alreadySubmitted: true),
      );
      await harness.open(tester);
      await _fillMinimal(tester);

      await tapSubmit(tester);

      expect(
        find.text('You already have an identical suggestion pending review.'),
        findsOneWidget,
      );
      expect(harness.contributions.submittedBeers, isEmpty);
    });

    testWidgets('a block clears as soon as the user edits the form', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..beerCandidates = _candidates(alreadySubmitted: true),
      );
      await harness.open(tester);
      await _fillMinimal(tester);
      await tapSubmit(tester);
      expect(
        find.text('You already have an identical suggestion pending review.'),
        findsOneWidget,
      );

      await enterByHint(tester, 'ABV % (optional)', '5');

      expect(
        find.text('You already have an identical suggestion pending review.'),
        findsNothing,
      );
    });

    testWidgets('a raced 409 from the POST is shown as a block, not a crash', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..submitBeerError = const ConflictApiException(
            message: 'diagnostic',
            statusCode: 409,
            code: 'already_submitted',
          ),
      );
      await harness.open(tester);
      await _fillMinimal(tester);

      await tapSubmit(tester);

      expect(
        find.text('You already have an identical suggestion pending review.'),
        findsOneWidget,
      );
      expect(find.text('diagnostic'), findsNothing); // raw message never shown
    });
  });

  group('failures and re-entrancy', () {
    testWidgets('a network error keeps the form and a retry succeeds', (
      tester,
    ) async {
      _useTallScreen(tester);
      final repository = FakeContributionRepository()
        ..submitBeerError = const NetworkApiException(message: 'socket');
      final harness = ContributionHarness(contributions: repository);
      await harness.open(tester);
      await _fillMinimal(tester);

      await tapSubmit(tester);

      expect(
        find.text(
          "Couldn't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      expect(find.text('socket'), findsNothing);
      expect(find.text('New Beer'), findsOneWidget); // nothing lost
      expect(find.text('Suggestion received'), findsNothing);

      repository.submitBeerError = null;
      await tapSubmit(tester);
      expect(find.text('Suggestion received'), findsOneWidget);
    });

    testWidgets('a 422 from the backend is a generic validation message', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..submitBeerError = const ValidationApiException(message: 'raw'),
      );
      await harness.open(tester);
      await _fillMinimal(tester);

      await tapSubmit(tester);

      expect(
        find.text(
          "Some details aren't valid. Please check the fields and try again.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed duplicate check is reported, not silently skipped', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness(
        contributions: FakeContributionRepository()
          ..checkBeerError = const ServiceUnavailableApiException(message: 'x'),
      );
      await harness.open(tester);
      await _fillMinimal(tester);

      await tapSubmit(tester);

      expect(
        find.text(
          'The service is temporarily unavailable. Please try again shortly.',
        ),
        findsOneWidget,
      );
      expect(harness.contributions.submittedBeers, isEmpty);
    });

    testWidgets(
      'while a submit is in flight the button is disabled: no double submit',
      (tester) async {
        _useTallScreen(tester);
        final repository = FakeContributionRepository()
          ..submitGate = Completer<void>();
        final harness = ContributionHarness(contributions: repository);
        await harness.open(tester);
        await _fillMinimal(tester);

        await tester.ensureVisible(find.text('Submit suggestion'));
        await tester.tap(find.text('Submit suggestion'));
        await tester.pump();
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        // Extra taps while in flight do nothing.
        await tester.tap(find.text('Submit suggestion'), warnIfMissed: false);
        await tester.pump();
        await tester.tap(find.text('Submit suggestion'), warnIfMissed: false);
        await tester.pump();

        repository.submitGate!.complete();
        await tester.pumpAndSettle();

        expect(repository.submittedBeers, hasLength(1));
        expect(find.text('Suggestion received'), findsOneWidget);
      },
    );
  });

  group('leaving the form', () {
    testWidgets('an untouched form closes without asking', (tester) async {
      _useTallScreen(tester);
      final harness = ContributionHarness();
      await harness.open(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard this suggestion?'), findsNothing);
      expect(harness.popped, isTrue);
    });

    testWidgets(
      'an edited form asks first; "Keep editing" stays, "Discard" leaves',
      (tester) async {
        _useTallScreen(tester);
        final harness = ContributionHarness();
        await harness.open(tester);
        await enterByHint(tester, 'Beer name', 'Half typed');

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Discard this suggestion?'), findsOneWidget);
        expect(harness.popped, isFalse);

        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        expect(find.text('Discard this suggestion?'), findsNothing);
        expect(find.text('Half typed'), findsOneWidget);
        expect(harness.popped, isFalse);

        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(harness.popped, isTrue);
        expect(harness.poppedWith, isNull);
        expect(harness.contributions.callLog, isEmpty);
      },
    );

    testWidgets('after a successful submit leaving needs no confirmation', (
      tester,
    ) async {
      _useTallScreen(tester);
      final harness = ContributionHarness();
      await harness.open(tester);
      await _fillMinimal(tester);
      await tapSubmit(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard this suggestion?'), findsNothing);
      expect(harness.popped, isTrue);
    });
  });

  testWidgets('renders in Spanish', (tester) async {
    _useTallScreen(tester);
    final harness = ContributionHarness();
    await harness.open(tester, locale: const Locale('es'));

    expect(find.text('Sugerir una cerveza'), findsOneWidget);
    expect(find.text('Nombre de la cerveza'), findsOneWidget);
    expect(find.text('Sin estilo'), findsOneWidget);

    await enterByHint(tester, 'Nombre de la cerveza', 'Nueva Cerveza');
    await pickFromDropdown(tester, 0, 'Hop House');
    final submit = find.text('Enviar sugerencia');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Sugerencia recibida'), findsOneWidget);
    expect(
      find.text(
        'Está pendiente de revisión. No aparecerá en el catálogo hasta que se haya revisado.',
      ),
      findsOneWidget,
    );
  });
}
