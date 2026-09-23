import 'package:beerapp/features/map/presentation/map_legend.dart';
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
  testWidgets('renders all five neutral-worded legend rows', (tester) async {
    await tester.pumpWidget(_wrap(const MapLegend()));

    expect(find.text('No catalog'), findsOneWidget);
    expect(find.text('Catalog available'), findsOneWidget);
    expect(find.text('In your history'), findsOneWidget);
    expect(find.text('Not in history'), findsOneWidget);

    // "In your history" and the beer-point "In history" label intentionally
    // differ (country vs. point), so both distinct strings must be present.
    expect(find.text('In history'), findsOneWidget);
  });

  testWidgets(
    'never uses completion/reward wording (Responsible Product Design)',
    (tester) async {
      await tester.pumpWidget(_wrap(const MapLegend()));

      for (final forbidden in [
        'complete',
        'completion',
        'finish',
        '100%',
        'unlock all',
      ]) {
        expect(
          find.textContaining(forbidden, findRichText: true),
          findsNothing,
          reason: 'legend must never read as a completion/reward mechanic',
        );
      }
    },
  );
}
