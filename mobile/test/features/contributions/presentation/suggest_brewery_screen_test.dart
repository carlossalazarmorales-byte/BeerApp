import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/core/network/api_exception.dart';
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

ContributionHarness _harness({FakeContributionRepository? contributions}) =>
    ContributionHarness(
      contributions: contributions,
      location: AppRoutes.suggestBrewery,
    );

void main() {
  testWidgets('shows the form fields', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);

    expect(find.text('Suggest a brewery'), findsOneWidget);
    expect(find.text('Brewery name'), findsOneWidget);
    expect(find.text('Country'), findsOneWidget);
    expect(find.text('Region (optional)'), findsOneWidget);
    expect(find.text('City (optional)'), findsOneWidget);
    // No coordinates, website or description are collected.
    expect(find.textContaining('Website'), findsNothing);
    expect(find.textContaining('Latitude'), findsNothing);
  });

  testWidgets('an empty form shows validation and submits nothing', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);

    await tapSubmit(tester);

    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('Choose a country or enter its name.'), findsOneWidget);
    expect(harness.contributions.callLog, isEmpty);
  });

  testWidgets('submitting stores a pending suggestion and says so', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Hop House 2');
    await pickFromDropdown(tester, 0, 'Germany');
    await enterByHint(tester, 'City (optional)', 'Munich');

    await tapSubmit(tester);

    final submitted = harness.contributions.submittedBreweries.single;
    expect(submitted.name, 'Hop House 2');
    expect(submitted.countryId, 'country-1');
    expect(submitted.proposedCountryName, isNull);
    expect(submitted.city, 'Munich');
    expect(submitted.region, isNull);
    expect(find.text('Suggestion received'), findsOneWidget);
    expect(find.textContaining('added'), findsNothing);
    // Only the contribution repository was used -- no beer submission.
    expect(harness.contributions.submittedBeers, isEmpty);
    expect(harness.contributions.callLog, ['checkBrewery', 'submitBrewery']);
  });

  testWidgets('a country that is not listed is proposed as free text', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Atlantis Ales');
    await pickFromDropdown(tester, 0, 'Not listed');
    expect(find.text('Country name'), findsOneWidget);
    await enterByHint(tester, 'Country name', 'Atlantis');

    await tapSubmit(tester);

    final submitted = harness.contributions.submittedBreweries.single;
    expect(submitted.countryId, isNull);
    expect(submitted.proposedCountryName, 'Atlantis');
    expect(find.text('Suggestion received'), findsOneWidget);
  });

  testWidgets('a "Not listed" country still needs a name', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Atlantis Ales');
    await pickFromDropdown(tester, 0, 'Not listed');

    await tapSubmit(tester);

    expect(find.text('This field is required.'), findsOneWidget);
    expect(harness.contributions.callLog, isEmpty);
  });

  testWidgets('a same-named catalog brewery warns without blocking', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness(
      contributions: FakeContributionRepository()
        ..breweryCandidates = const BreweryDuplicateCandidates(
          nameMatches: [testBrewery],
          alreadySubmitted: false,
        ),
    );
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Hop House');
    await pickFromDropdown(tester, 0, 'Germany');

    await tapSubmit(tester);

    expect(find.text('Similar entries found'), findsOneWidget);
    expect(
      find.text('Similar breweries already in the catalog'),
      findsOneWidget,
    );
    expect(find.text('Munich'), findsOneWidget);
    expect(harness.contributions.submittedBreweries, isEmpty);

    await tester.tap(find.text('Submit anyway'));
    await tester.pumpAndSettle();

    expect(harness.contributions.submittedBreweries, hasLength(1));
    expect(find.text('Suggestion received'), findsOneWidget);
  });

  testWidgets('"Review" returns to the form without submitting', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness(
      contributions: FakeContributionRepository()
        ..breweryCandidates = const BreweryDuplicateCandidates(
          nameMatches: [testBrewery],
          alreadySubmitted: false,
        ),
    );
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Hop House');
    await pickFromDropdown(tester, 0, 'Germany');
    await tapSubmit(tester);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Submit suggestion'), findsOneWidget);
    expect(harness.contributions.submittedBreweries, isEmpty);
  });

  testWidgets('your own identical pending suggestion blocks', (tester) async {
    _useTallScreen(tester);
    final harness = _harness(
      contributions: FakeContributionRepository()
        ..breweryCandidates = const BreweryDuplicateCandidates(
          nameMatches: [],
          alreadySubmitted: true,
        ),
    );
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Hop House');
    await pickFromDropdown(tester, 0, 'Germany');

    await tapSubmit(tester);

    expect(
      find.text('You already have an identical suggestion pending review.'),
      findsOneWidget,
    );
    expect(harness.contributions.submittedBreweries, isEmpty);
  });

  testWidgets('a network error keeps the form and a retry succeeds', (
    tester,
  ) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository()
      ..submitBreweryError = const NetworkApiException(message: 'socket');
    final harness = _harness(contributions: repository);
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Hop House 2');
    await pickFromDropdown(tester, 0, 'Germany');

    await tapSubmit(tester);
    expect(
      find.text(
        "Couldn't reach the server. Check your connection and try again.",
      ),
      findsOneWidget,
    );

    repository.submitBreweryError = null;
    await tapSubmit(tester);
    expect(find.text('Suggestion received'), findsOneWidget);
  });

  testWidgets('an edited form asks before discarding', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Half typed');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Discard this suggestion?'), findsOneWidget);
    expect(harness.popped, isFalse);
  });

  testWidgets('"Done" reports that something was stored', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);
    await enterByHint(tester, 'Brewery name', 'Hop House 2');
    await pickFromDropdown(tester, 0, 'Germany');
    await tapSubmit(tester);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(harness.poppedWith, true);
  });

  testWidgets('renders in Spanish', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester, locale: const Locale('es'));

    expect(find.text('Sugerir una cervecería'), findsOneWidget);
    expect(find.text('Nombre de la cervecería'), findsOneWidget);
    expect(find.text('País'), findsOneWidget);
  });
}
