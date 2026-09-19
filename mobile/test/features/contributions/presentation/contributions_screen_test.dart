import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/design_system/components/states/empty_state.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/design_system/components/states/loading_state.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
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

ContributionHarness _harness([FakeContributionRepository? contributions]) =>
    ContributionHarness(
      contributions: contributions,
      location: AppRoutes.contributions,
    );

ContributionSummary _item(
  int n, {
  ContributionKind kind = ContributionKind.beer,
  ContributionStatus status = ContributionStatus.pending,
}) => ContributionSummary(
  id: 'c-$n',
  kind: kind,
  title: 'Item $n',
  status: status,
  createdAt: DateTime.utc(2026, 9, 18, 12),
);

void main() {
  testWidgets('shows a loading state, then the history', (tester) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository(
      delay: const Duration(milliseconds: 10),
    )..history.add(_item(1));
    final harness = _harness(repository);
    await tester.pumpWidget(harness.app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(LoadingState), findsNothing);
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('shows both kinds with their status, kind and date', (
    tester,
  ) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository()
      ..history.addAll([_item(2, kind: ContributionKind.brewery), _item(1)]);
    final harness = _harness(repository);
    await harness.open(tester);

    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.textContaining('Beer •'), findsOneWidget);
    expect(find.textContaining('Brewery •'), findsOneWidget);
    // Today every suggestion is pending review -- there is no moderator yet.
    expect(find.text('Pending review'), findsNWidgets(2));
    expect(find.text('Approved'), findsNothing);
  });

  testWidgets('never presents an unrecognized status as approved', (
    tester,
  ) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository()
      ..history.add(_item(1, status: ContributionStatus.unknown));
    final harness = _harness(repository);
    await harness.open(tester);

    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('Approved'), findsNothing);
  });

  testWidgets('states plainly that a suggestion is not a catalog entry', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);

    expect(
      find.text(
        'Suggestions are reviewed before they can join the catalog. Nothing you submit here appears in the catalog until then.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty history shows a message and keeps the actions', (
    tester,
  ) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text("You haven't suggested anything yet."), findsOneWidget);
    expect(find.text('Suggest a beer'), findsOneWidget);
    expect(find.text('Suggest a brewery'), findsOneWidget);
  });

  testWidgets('a failed load shows an error state with retry, actions stay', (
    tester,
  ) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository()
      ..getHistoryError = const NetworkApiException(message: 'offline');
    final harness = _harness(repository);
    await harness.open(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(
      find.text(
        "Couldn't reach the server. Check your connection and try again.",
      ),
      findsOneWidget,
    );
    expect(find.text('Suggest a beer'), findsOneWidget);

    repository
      ..getHistoryError = null
      ..history.add(_item(1));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsNothing);
    expect(find.text('Item 1'), findsOneWidget);
  });

  testWidgets('"Suggest a beer" opens the beer form', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);

    await tester.tap(find.text('Suggest a beer'));
    await tester.pumpAndSettle();

    expect(find.text('Beer name'), findsOneWidget);
  });

  testWidgets('"Suggest a brewery" opens the brewery form', (tester) async {
    _useTallScreen(tester);
    final harness = _harness();
    await harness.open(tester);

    await tester.tap(find.text('Suggest a brewery'));
    await tester.pumpAndSettle();

    expect(find.text('Brewery name'), findsOneWidget);
  });

  testWidgets('a stored suggestion appears in the history after "Done"', (
    tester,
  ) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository();
    final harness = _harness(repository);
    await harness.open(tester);
    expect(find.text("You haven't suggested anything yet."), findsOneWidget);

    await tester.tap(find.text('Suggest a beer'));
    await tester.pumpAndSettle();
    await enterByHint(tester, 'Beer name', 'Brand New Beer');
    await pickFromDropdown(tester, 0, 'Hop House');
    await tapSubmit(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text("You haven't suggested anything yet."), findsNothing);
    expect(find.text('Brand New Beer'), findsOneWidget);
    expect(find.text('Pending review'), findsOneWidget);
    // It was reloaded from the backend, not just inserted locally.
    expect(
      repository.callLog.where((c) => c.startsWith('getHistory')),
      hasLength(2),
    );
  });

  testWidgets('leaving a form without submitting does not reload the history', (
    tester,
  ) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository();
    final harness = _harness(repository);
    await harness.open(tester);

    await tester.tap(find.text('Suggest a beer'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      repository.callLog.where((c) => c.startsWith('getHistory')),
      hasLength(1),
    );
  });

  testWidgets('a long history paginates on scroll', (tester) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeContributionRepository()
      ..history.addAll([for (var i = 30; i >= 1; i--) _item(i)]);
    final harness = _harness(repository);
    await harness.open(tester);
    expect(
      repository.callLog.where((c) => c.startsWith('getHistory')),
      hasLength(1),
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
    await tester.pumpAndSettle();

    expect(
      repository.callLog.where((c) => c.startsWith('getHistory')),
      hasLength(2),
    );

    // The appended page extends the list; scroll on to its last row.
    await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.text('Item 1'), findsOneWidget);
    // Two pages were enough for 30 rows -- no third request.
    expect(
      repository.callLog.where((c) => c.startsWith('getHistory')),
      hasLength(2),
    );
  });

  testWidgets('renders in Spanish', (tester) async {
    _useTallScreen(tester);
    final repository = FakeContributionRepository()
      ..history.add(_item(1, kind: ContributionKind.brewery));
    final harness = _harness(repository);
    await harness.open(tester, locale: const Locale('es'));

    expect(find.text('Contribuciones'), findsOneWidget);
    expect(find.text('Sugerir una cerveza'), findsOneWidget);
    expect(find.text('Sugerir una cervecería'), findsOneWidget);
    expect(find.text('Pendiente de revisión'), findsOneWidget);
    expect(find.textContaining('Cervecería •'), findsOneWidget);
  });
}
