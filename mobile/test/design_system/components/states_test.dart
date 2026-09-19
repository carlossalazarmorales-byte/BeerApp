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

  testWidgets('ErrorState uses a custom retry label when given', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(ErrorState(retryLabel: 'Try camera again', onRetry: () {})),
    );

    expect(find.text('Try camera again'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'ErrorState renders no secondary action unless both label and callback are given',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const ErrorState(secondaryLabel: 'Search manually')),
      );
      expect(find.text('Search manually'), findsNothing);
    },
  );

  testWidgets(
    'ErrorState fires the secondary action callback when tapped, alongside retry',
    (tester) async {
      var retried = false;
      var searchedManually = false;
      await tester.pumpWidget(
        _wrap(
          ErrorState(
            onRetry: () => retried = true,
            secondaryLabel: 'Search manually',
            onSecondaryAction: () => searchedManually = true,
          ),
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Search manually'), findsOneWidget);

      await tester.tap(find.text('Search manually'));
      await tester.pump();

      expect(searchedManually, isTrue);
      expect(retried, isFalse);
    },
  );

  testWidgets('ErrorState shows and fires an optional tertiary action', (
    tester,
  ) async {
    var retried = false;
    var searched = false;
    var suggested = false;
    await tester.pumpWidget(
      _wrap(
        ErrorState(
          onRetry: () => retried = true,
          secondaryLabel: 'Search manually',
          onSecondaryAction: () => searched = true,
          tertiaryLabel: 'Suggest this beer',
          onTertiaryAction: () => suggested = true,
        ),
      ),
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Search manually'), findsOneWidget);
    expect(find.text('Suggest this beer'), findsOneWidget);

    await tester.tap(find.text('Suggest this beer'));
    await tester.pump();

    expect(suggested, isTrue);
    expect(retried, isFalse);
    expect(searched, isFalse);
  });

  testWidgets('ErrorState omits the tertiary action without a callback or a '
      'label', (tester) async {
    await tester.pumpWidget(
      _wrap(const ErrorState(tertiaryLabel: 'Suggest this beer')),
    );
    expect(find.text('Suggest this beer'), findsNothing);

    await tester.pumpWidget(_wrap(ErrorState(onTertiaryAction: () {})));
    expect(find.byType(TextButton), findsNothing);
  });
}
