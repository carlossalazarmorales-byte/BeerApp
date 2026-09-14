import 'package:beerapp/design_system/components/states/empty_state.dart';
import 'package:beerapp/design_system/components/states/error_state.dart';
import 'package:beerapp/design_system/components/states/loading_state.dart';
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
  testWidgets('LoadingState renders a progress indicator', (tester) async {
    await tester.pumpWidget(_wrap(const LoadingState()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('EmptyState renders the default message when none is given', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const EmptyState()));
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('EmptyState renders a custom message when given', (tester) async {
    await tester.pumpWidget(_wrap(const EmptyState(message: 'No beers yet')));
    expect(find.text('No beers yet'), findsOneWidget);
  });

  testWidgets(
    'ErrorState renders the default message and no retry button by default',
    (tester) async {
      await tester.pumpWidget(_wrap(const ErrorState()));
      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets('ErrorState fires the retry callback when tapped', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(_wrap(ErrorState(onRetry: () => retried = true)));

    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(retried, isTrue);
  });
}
