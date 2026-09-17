import 'package:beerapp/features/statistics/domain/models/monthly_activity_point.dart';
import 'package:beerapp/features/statistics/presentation/widgets/monthly_activity_chart.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One point per calendar month (Jan-Dec 2025) -- exercises every month,
/// not just the trailing-12-window subset a real [Statistics] response
/// would carry, so every localized label gets checked.
final List<MonthlyActivityPoint> _twelveMonths = [
  for (var month = 1; month <= 12; month++)
    MonthlyActivityPoint(month: DateTime(2025, month, 1), logCount: 0),
];

Widget _wrap(Widget child, Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('English locale renders English month abbreviations', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(MonthlyActivityChart(points: _twelveMonths), const Locale('en')),
    );
    await tester.pumpAndSettle();

    for (final label in ['Jan', 'Apr', 'Aug', 'Dec']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets(
    'Spanish locale renders Spanish month abbreviations, not English ones',
    (tester) async {
      await tester.pumpWidget(
        _wrap(MonthlyActivityChart(points: _twelveMonths), const Locale('es')),
      );
      await tester.pumpAndSettle();

      for (final label in ['ene', 'abr', 'ago', 'dic']) {
        expect(find.text(label), findsOneWidget);
      }

      // The bug this regression test guards against: hardcoded English
      // month abbreviations that never localized regardless of app locale.
      for (final label in ['Jan', 'Apr', 'Aug', 'Dec']) {
        expect(find.text(label), findsNothing);
      }
    },
  );
}
