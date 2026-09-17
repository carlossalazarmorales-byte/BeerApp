import 'package:flutter/material.dart';

import '../../../design_system/components/states/empty_state.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/collection_refresh_signal.dart';
import '../domain/models/statistics.dart';
import '../domain/statistics_repository.dart';
import 'statistics_controller.dart';
import 'statistics_error_text.dart';
import 'widgets/amount_spent_section.dart';
import 'widgets/favorites_section.dart';
import 'widgets/monthly_activity_chart.dart';
import 'widgets/stat_tile.dart';
import 'widgets/yearly_activity_chart.dart';

/// Personal Statistics: descriptive summaries only, derived from the user's
/// own beer logs and Collection favorites -- no goals, streaks, or
/// consumption targets (see CLAUDE.md's Responsible Product Design rules).
/// Reached from Profile as a full-screen route (see app/router.dart) and
/// kept fresh via the shared [CollectionRefreshSignal].
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({
    required this.repository,
    required this.refreshSignal,
    super.key,
  });

  final StatisticsRepository repository;
  final CollectionRefreshSignal refreshSignal;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final StatisticsController _controller = StatisticsController(
    repository: widget.repository,
    refreshSignal: widget.refreshSignal,
  );

  @override
  void initState() {
    super.initState();
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.statisticsScreenTitle)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stats = _controller.statistics;

    if (_controller.isLoading && stats == null) {
      return const LoadingState();
    }

    if (_controller.error != null && stats == null) {
      return ErrorState(
        message: statisticsErrorText(context, _controller.error!),
        onRetry: _controller.loadInitial,
      );
    }

    if (stats == null) {
      // Unreachable in practice (isLoading/error cover every non-success
      // path above), but keeps this method total for the type checker.
      return const LoadingState();
    }

    if (!stats.hasAnyStatistics) {
      return RefreshIndicator(
        onRefresh: _controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [EmptyState(message: l10n.statisticsEmptyMessage)],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _OverviewGrid(stats: stats, l10n: l10n),
          const SizedBox(height: AppSpacing.lg),
          AmountSpentSection(amountSpent: stats.amountSpent),
          const SizedBox(height: AppSpacing.lg),
          FavoritesSection(statistics: stats),
          const SizedBox(height: AppSpacing.lg),
          MonthlyActivityChart(points: stats.monthlyActivity),
          const SizedBox(height: AppSpacing.lg),
          YearlyActivityChart(points: stats.yearlyActivity),
        ],
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.stats, required this.l10n});

  final Statistics stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final averageRatingLabel = stats.averageRating == null
        ? l10n.statisticsAverageRatingNoneLabel
        : stats.averageRating!.toStringAsFixed(1);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: [
        StatTile(
          label: l10n.statisticsTotalUniqueBeersLabel,
          value: '${stats.totalUniqueBeers}',
        ),
        StatTile(
          label: l10n.statisticsTotalLogsLabel,
          value: '${stats.totalLogs}',
        ),
        StatTile(
          label: l10n.statisticsCountriesDiscoveredLabel,
          value: '${stats.countriesDiscovered}',
        ),
        StatTile(
          label: l10n.statisticsStylesDiscoveredLabel,
          value: '${stats.stylesDiscovered}',
        ),
        StatTile(
          label: l10n.statisticsBreweriesDiscoveredLabel,
          value: '${stats.breweriesDiscovered}',
        ),
        StatTile(
          label: l10n.statisticsAverageRatingLabel,
          value: averageRatingLabel,
        ),
      ],
    );
  }
}
