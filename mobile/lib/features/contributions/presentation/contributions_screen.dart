import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/buttons/secondary_button.dart';
import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/components/states/empty_state.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/contribution_repository.dart';
import '../domain/models/contribution_summary.dart';
import 'contribution_error_text.dart';
import 'contribution_history_controller.dart';

/// Profile -> Contributions: the user's own submission history plus entry
/// points to suggest a beer or a brewery. History is private to the user;
/// every row is a *proposal*, and its status is shown exactly as the backend
/// reports it (today always "Pending review" -- no moderator workflow exists
/// yet).
class ContributionsScreen extends StatefulWidget {
  const ContributionsScreen({required this.repository, super.key});

  final ContributionRepository repository;

  @override
  State<ContributionsScreen> createState() => _ContributionsScreenState();
}

class _ContributionsScreenState extends State<ContributionsScreen> {
  static const double _loadMoreThreshold = 300;

  late final ContributionHistoryController _controller =
      ContributionHistoryController(repository: widget.repository);
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      unawaited(_controller.loadMore());
    }
  }

  /// The forms pop `true` once a suggestion was stored, so the list refreshes
  /// to include it.
  Future<void> _open(String route) async {
    final submitted = await context.push<bool>(route);
    if (submitted == true && mounted) unawaited(_controller.load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.contributionsScreenTitle)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildBody(context, l10n),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final header = _Header(
      onSuggestBeer: () => unawaited(_open(AppRoutes.suggestBeer)),
      onSuggestBrewery: () => unawaited(_open(AppRoutes.suggestBrewery)),
    );

    if (_controller.isLoading && _controller.items.isEmpty) {
      return Column(
        children: [
          header,
          const Expanded(child: LoadingState()),
        ],
      );
    }

    if (_controller.error != null && _controller.items.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: ErrorState(
              message: contributionErrorText(context, _controller.error!),
              onRetry: _controller.load,
            ),
          ),
        ],
      );
    }

    if (_controller.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            header,
            EmptyState(message: l10n.contributionsEmptyMessage),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _controller.load,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: _controller.items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) return header;
          if (index <= _controller.items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: _ContributionTile(item: _controller.items[index - 1]),
            );
          }
          return _Footer(controller: _controller);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSuggestBeer, required this.onSuggestBrewery});

  final VoidCallback onSuggestBeer;
  final VoidCallback onSuggestBrewery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.contributionsIntro,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.contributionsSuggestBeerAction,
            onPressed: onSuggestBeer,
          ),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: l10n.contributionsSuggestBreweryAction,
            onPressed: onSuggestBrewery,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.contributionsHistoryTitle, style: AppTypography.titleLarge),
        ],
      ),
    );
  }
}

class _ContributionTile extends StatelessWidget {
  const _ContributionTile({required this.item});

  final ContributionSummary item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kindLabel = item.kind == ContributionKind.beer
        ? l10n.contributionKindBeer
        : l10n.contributionKindBrewery;
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(item.createdAt.toLocal());
    return AppCard(
      child: Row(
        children: [
          Icon(
            item.kind == ContributionKind.beer
                ? Icons.sports_bar_outlined
                : Icons.factory_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTypography.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$kindLabel • $date',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusChip(status: item.status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ContributionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (status) {
      ContributionStatus.pending => l10n.contributionStatusPending,
      ContributionStatus.approved => l10n.contributionStatusApproved,
      ContributionStatus.rejected => l10n.contributionStatusRejected,
      ContributionStatus.unknown => l10n.contributionStatusUnknown,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer,
        borderRadius: AppRadii.mdRadius,
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.onSecondaryFixed,
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final ContributionHistoryController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final loadMoreError = controller.loadMoreError;
    if (loadMoreError != null) {
      final l10n = AppLocalizations.of(context);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: TextButton(
            onPressed: controller.loadMore,
            child: Text(
              '${contributionErrorText(context, loadMoreError)} '
              '${l10n.errorStateRetryLabel}',
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
