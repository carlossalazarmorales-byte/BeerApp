import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/monthly_activity_point.dart';

// Not `intl`'s DateFormat -- `intl` is only pulled in transitively by
// generated l10n code today, and a 12-entry month abbreviation lookup
// doesn't justify adding it as a new direct dependency (see
// docs/DECISIONS.md). Localized via ARB keys instead of a hardcoded
// English list, so the chart's x-axis matches the rest of the screen when
// the device/app locale changes.
String _localizedMonthLabel(AppLocalizations l10n, int month) {
  switch (month) {
    case 1:
      return l10n.statisticsMonthJan;
    case 2:
      return l10n.statisticsMonthFeb;
    case 3:
      return l10n.statisticsMonthMar;
    case 4:
      return l10n.statisticsMonthApr;
    case 5:
      return l10n.statisticsMonthMay;
    case 6:
      return l10n.statisticsMonthJun;
    case 7:
      return l10n.statisticsMonthJul;
    case 8:
      return l10n.statisticsMonthAug;
    case 9:
      return l10n.statisticsMonthSep;
    case 10:
      return l10n.statisticsMonthOct;
    case 11:
      return l10n.statisticsMonthNov;
    case 12:
      return l10n.statisticsMonthDec;
    default:
      throw ArgumentError.value(month, 'month', 'Must be 1..12');
  }
}

/// The keys `statisticsMonthLongName` selects on, indexed by month - 1.
const _monthNameKeys = [
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
];

/// The text a screen reader gets in place of the bars: the total, and the month
/// with the most entries (the earliest one, if several tie) so the same fact a
/// sighted user reads off the tallest bar is available. Descriptive only -- no
/// ranking, goal or comparison wording.
@visibleForTesting
String monthlyChartSummary(
  AppLocalizations l10n,
  List<MonthlyActivityPoint> points,
) {
  var total = 0;
  MonthlyActivityPoint? mostEntries;
  for (final point in points) {
    total += point.logCount;
    if (mostEntries == null || point.logCount > mostEntries.logCount) {
      mostEntries = point;
    }
  }
  if (total == 0 || mostEntries == null) {
    return l10n.statisticsMonthlyChartSemanticEmpty;
  }
  return l10n.statisticsMonthlyChartSemanticSummary(
    total,
    l10n.statisticsMonthLongName(_monthNameKeys[mostEntries.month.month - 1]),
    mostEntries.logCount,
  );
}

/// Bar chart of log counts for the trailing 12 UTC months. [points] is
/// always exactly 12 entries (zero-filled), so this never needs an empty
/// state of its own.
class MonthlyActivityChart extends StatelessWidget {
  const MonthlyActivityChart({required this.points, super.key});

  final List<MonthlyActivityPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final maxCount = points.fold(
      0,
      (max, p) => p.logCount > max ? p.logCount : max,
    );
    // Headroom above the tallest bar, and never zero-height even when every
    // month is empty (a brand-new user).
    final maxY = (maxCount == 0 ? 1 : maxCount) * 1.2;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statisticsMonthlyActivityChartTitle,
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          // The bars are drawn, not widgets, so a screen reader would find
          // nothing: describe the chart in one label and hide the drawing.
          Semantics(
            image: true,
            label: monthlyChartSummary(l10n, points),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final label = _localizedMonthLabel(
                              l10n,
                              points[index].month.month,
                            );
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                label,
                                style: AppTypography.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (final (index, point) in points.indexed)
                        BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: point.logCount.toDouble(),
                              color: AppColors.primary,
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
