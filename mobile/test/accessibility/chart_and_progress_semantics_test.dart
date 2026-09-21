import 'package:beerapp/design_system/components/states/inline_progress.dart';
import 'package:beerapp/design_system/theme/app_theme.dart';
import 'package:beerapp/features/statistics/domain/models/monthly_activity_point.dart';
import 'package:beerapp/features/statistics/domain/models/yearly_activity_point.dart';
import 'package:beerapp/features/statistics/presentation/widgets/monthly_activity_chart.dart';
import 'package:beerapp/features/statistics/presentation/widgets/yearly_activity_chart.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<MonthlyActivityPoint> _months(List<int> counts) => [
  for (final (i, count) in counts.indexed)
    MonthlyActivityPoint(month: DateTime(2025, 10 + i), logCount: count),
];

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final es = lookupAppLocalizations(const Locale('es'));

  group('monthly chart summary text', () {
    test('states the total and the busiest month', () {
      final points = _months([0, 2, 0, 5, 1, 0, 0, 0, 3, 0, 0, 0]);
      expect(
        monthlyChartSummary(en, points),
        'Monthly activity over the last 12 months: 11 entries in total. '
        'Month with most entries: January, 5 entries.',
      );
    });

    test('uses the singular form for one log', () {
      final points = _months([0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(
        monthlyChartSummary(en, points),
        'Monthly activity over the last 12 months: 1 entry in total. '
        'Month with most entries: December, 1 entry.',
      );
    });

    test('says so when there is no activity at all', () {
      expect(
        monthlyChartSummary(en, _months(List.filled(12, 0))),
        'Monthly activity: no entries in the last 12 months.',
      );
    });

    test('a tie names the earliest month', () {
      final points = _months([0, 4, 0, 4, 0, 0, 0, 0, 0, 0, 0, 0]);
      expect(
        monthlyChartSummary(en, points),
        contains('Month with most entries: November, 4 entries.'),
      );
    });

    test('uses neutral wording: no competitive or goal framing', () {
      final points = _months([0, 2, 0, 5, 1, 0, 0, 0, 3, 0, 0, 0]);
      final summary = monthlyChartSummary(en, points).toLowerCase();
      for (final word in ['busiest', 'best', 'record', 'peak', 'top', 'goal']) {
        expect(summary, isNot(contains(word)), reason: word);
      }
      final spanish = monthlyChartSummary(es, points).toLowerCase();
      for (final word in ['más activo', 'mejor', 'récord', 'pico', 'meta']) {
        expect(spanish, isNot(contains(word)), reason: word);
      }
    });

    test('names every month correctly (full names, EN and ES)', () {
      const en12 = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      const es12 = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      // The window starts in October 2025 (see _months), so index i is
      // calendar month ((9 + i) % 12).
      for (var i = 0; i < 12; i++) {
        final counts = List.filled(12, 0)..[i] = 3;
        final month = (9 + i) % 12;
        expect(
          monthlyChartSummary(en, _months(counts)),
          contains('Month with most entries: ${en12[month]}, 3 entries.'),
        );
        expect(
          monthlyChartSummary(es, _months(counts)),
          contains('Mes con más registros: ${es12[month]}, 3 registros.'),
        );
      }
    });

    test('is localized', () {
      final points = _months([0, 2, 0, 5, 1, 0, 0, 0, 3, 0, 0, 0]);
      final summary = monthlyChartSummary(es, points);
      expect(summary, contains('11 registros en total'));
      expect(summary, contains('Mes con más registros: enero, 5 registros.'));
      expect(summary, isNot(contains('logs')));
      expect(
        monthlyChartSummary(es, _months(List.filled(12, 0))),
        'Actividad mensual: sin registros en los últimos 12 meses.',
      );
    });
  });

  group('yearly chart summary text', () {
    test('lists every year with its count', () {
      final points = [
        const YearlyActivityPoint(year: 2024, logCount: 1),
        const YearlyActivityPoint(year: 2025, logCount: 12),
      ];
      expect(
        yearlyChartSummary(en, points),
        'Yearly activity: 2024: 1 entry, 2025: 12 entries.',
      );
      expect(
        yearlyChartSummary(es, points),
        'Actividad anual: 2024: 1 registro, 2025: 12 registros.',
      );
    });
  });

  group('the charts expose the summary, not their drawing', () {
    testWidgets('MonthlyActivityChart is one labelled image node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        MonthlyActivityChart(
          points: _months([0, 2, 0, 5, 1, 0, 0, 0, 3, 0, 0, 0]),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('^Monthly activity over the last 12')),
        findsOneWidget,
      );
      // None of the drawn month labels is a separate stop for a screen reader.
      expect(find.bySemanticsLabel('Jan'), findsNothing);
      handle.dispose();
    });

    testWidgets('YearlyActivityChart is one labelled image node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const YearlyActivityChart(
          points: [YearlyActivityPoint(year: 2025, logCount: 3)],
        ),
      );

      expect(
        find.bySemanticsLabel('Yearly activity: 2025: 3 entries.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an empty YearlyActivityChart keeps its own text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const YearlyActivityChart(points: []));

      expect(
        find.bySemanticsLabel('No activity recorded yet.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Yearly activity: ')), findsNothing);
      handle.dispose();
    });
  });

  group('charts at 2.0x text scale', () {
    Future<void> pumpScaled(WidgetTester tester, Widget child) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, child);
    }

    testWidgets('MonthlyActivityChart does not overflow', (tester) async {
      await pumpScaled(
        tester,
        MonthlyActivityChart(
          points: _months([1, 2, 3, 4, 5, 6, 7, 8, 9, 1, 2, 3]),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('YearlyActivityChart does not overflow', (tester) async {
      await pumpScaled(
        tester,
        const YearlyActivityChart(
          points: [
            YearlyActivityPoint(year: 2023, logCount: 1),
            YearlyActivityPoint(year: 2024, logCount: 2),
            YearlyActivityPoint(year: 2025, logCount: 3),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('inline progress indicators announce that something is loading', () {
    testWidgets('InlineSpinner', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const InlineSpinner());
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('InlineSpinner keeps its size', (tester) async {
      await _pump(tester, const InlineSpinner(size: 24));
      expect(tester.getSize(find.byType(InlineSpinner)), const Size(24, 24));
    });

    testWidgets('InlineProgressBar', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const InlineProgressBar());
      expect(find.bySemanticsLabel('Loading…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the label is localized', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const InlineSpinner(), locale: const Locale('es'));
      expect(find.bySemanticsLabel(es.loadingStateMessage), findsOneWidget);
      handle.dispose();
    });
  });
}
