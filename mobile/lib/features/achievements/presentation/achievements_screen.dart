import 'package:flutter/material.dart';

import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/collection_refresh_signal.dart';
import '../domain/achievements_repository.dart';
import '../domain/models/achievement.dart';
import '../domain/models/achievement_category.dart';
import 'achievement_localizations.dart';
import 'achievements_controller.dart';
import 'achievements_error_text.dart';
import 'widgets/achievement_category_section.dart';

/// Personal Achievements: locked/unlocked state and neutral progress,
/// derived and persisted entirely server-side -- this screen never decides
/// an achievement is unlocked, it only displays what `GET /achievements`
/// returns (see CLAUDE.md's Responsible Product Design rules and
/// docs/DECISIONS.md). Reached from Profile as a full-screen route (see
/// app/router.dart) and kept fresh via the shared [CollectionRefreshSignal].
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({
    required this.repository,
    required this.refreshSignal,
    super.key,
  });

  final AchievementsRepository repository;
  final CollectionRefreshSignal refreshSignal;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final AchievementsController _controller = AchievementsController(
    repository: widget.repository,
    refreshSignal: widget.refreshSignal,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeShowUnlockBanner);
    _controller.loadInitial();
  }

  @override
  void dispose() {
    _controller.removeListener(_maybeShowUnlockBanner);
    _controller.dispose();
    super.dispose();
  }

  // A separate listener from the ListenableBuilder below, purely for the
  // one-shot notification -- keeps "what to render" and "what to notify
  // about" independent, and `takeNewlyUnlocked()` drains itself so a later
  // unrelated rebuild never re-shows the same banner. Never fires on the
  // controller's very first load (see AchievementsController).
  void _maybeShowUnlockBanner() {
    final newlyUnlocked = _controller.takeNewlyUnlocked();
    if (newlyUnlocked.isEmpty || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = newlyUnlocked.length == 1
        ? l10n.achievementsNewUnlockBannerOne(
            achievementName(l10n, newlyUnlocked.first.key),
          )
        : l10n.achievementsNewUnlockBannerMany(newlyUnlocked.length);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.achievementsScreenTitle)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final achievements = _controller.achievements;

    if (_controller.isLoading && achievements == null) {
      return const LoadingState();
    }

    if (_controller.error != null && achievements == null) {
      return ErrorState(
        message: achievementsErrorText(context, _controller.error!),
        onRetry: _controller.loadInitial,
      );
    }

    if (achievements == null) {
      // Unreachable in practice (isLoading/error cover every non-success
      // path above), but keeps this method total for the type checker.
      return const LoadingState();
    }

    final sections = <MapEntry<AchievementCategory, List<Achievement>>>[
      for (final category in AchievementCategory.values)
        if (achievements.any((a) => a.category == category))
          MapEntry(
            category,
            achievements.where((a) => a.category == category).toList(),
          ),
    ];

    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final section in sections) ...[
            AchievementCategorySection(
              category: section.key,
              achievements: section.value,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
