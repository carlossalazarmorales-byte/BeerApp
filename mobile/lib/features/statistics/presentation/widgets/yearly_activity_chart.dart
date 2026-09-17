import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/yearly_activity_point.dart';

/// Bar chart of log counts per UTC calendar year, all-time. Unlike
/// [MonthlyActivityChart], [points] is NOT zero-filled -- a brand-new user
/// (or one whose only activity is favorites, no logs) can have an empty
/// list, shown as a small text message rather than an empty chart.
class YearlyActivityChart extends StatelessWidget {
  const YearlyActivityChart({required this.points, super.key});

  final List<YearlyActivityPoint> points;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statisticsYearlyActivityChartTitle,
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          if (points.isEmpty)
            Text(
              l10n.statisticsYearlyActivityEmptyLabel,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            SizedBox(height: 160, child: _chart()),
        ],
      ),
    );
  }

  Widget _chart() {
    final maxCount = points.fold(
      0,
      (max, p) => p.logCount > max ? p.logCount : max,
    );
    final maxY = (maxCount == 0 ? 1 : maxCount) * 1.2;

    return BarChart(
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
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${points[index].year}',
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
                  width: 20,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
