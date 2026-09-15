import 'package:flutter/material.dart';

import '../../../../design_system/components/buttons/secondary_button.dart';
import '../../../../design_system/components/cards/app_card.dart';
import '../../../../design_system/components/states/empty_state.dart';
import '../../../../design_system/components/states/error_state.dart';
import '../../../../design_system/components/states/loading_state.dart';
import '../../../../design_system/tokens/app_colors.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/beer_log.dart';
import '../beer_log_error_text.dart';
import 'beer_log_controller.dart';
import 'log_form_sheet.dart';

/// "Your logs" block appended to Beer Detail: this user's past entries for
/// one beer (there may be several -- a beer can be logged multiple times),
/// each tappable to edit, with delete behind a confirmation. Loading/error/
/// empty states here are independent of Beer Detail's own -- the beer can
/// load fine while this section is still loading, erroring, or empty.
class LogListSection extends StatelessWidget {
  const LogListSection({required this.controller, super.key});

  final BeerLogController controller;

  Future<void> _openEdit(BuildContext context, BeerLog log) async {
    final saved = await LogFormSheet.show(
      context,
      controller: controller,
      existing: log,
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).beerLogSavedConfirmation),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, BeerLog log) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.beerLogDeleteConfirmTitle),
        content: Text(l10n.beerLogDeleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.beerLogDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await controller.submitDelete(log.id);
    if (!context.mounted) return;
    final message = success
        ? l10n.beerLogDeletedConfirmation
        : (controller.error == null
              ? l10n.beerLogErrorGeneric
              : beerLogErrorText(context, controller.error!));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (controller.isLoading && controller.logs.isEmpty) {
      return const LoadingState();
    }

    final error = controller.error;
    if (error != null && controller.logs.isEmpty) {
      return ErrorState(
        message: beerLogErrorText(context, error),
        onRetry: controller.load,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.beerLogSectionTitle, style: AppTypography.titleLarge),
        const SizedBox(height: AppSpacing.md),
        if (controller.logs.isEmpty)
          EmptyState(message: l10n.beerLogEmptyMessage)
        else
          ...controller.logs.map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _LogTile(
                log: log,
                onTap: () => _openEdit(context, log),
                onDelete: () => _confirmDelete(context, log),
              ),
            ),
          ),
        if (controller.hasMore) ...[
          const SizedBox(height: AppSpacing.sm),
          if (controller.loadMoreError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                beerLogErrorText(context, controller.loadMoreError!),
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          SecondaryButton(
            label: l10n.beerLogLoadMoreAction,
            onPressed: controller.isLoadingMore ? null : controller.loadMore,
          ),
        ],
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.log,
    required this.onTap,
    required this.onDelete,
  });

  final BeerLog log;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitleParts = <String>[
      _formatDate(log.consumedAt),
      if (log.venueName != null) log.venueName!,
      if (log.servingVolumeMl != null) '${log.servingVolumeMl} ml',
    ];

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (log.rating != null) ...[
                        Icon(Icons.star, size: 16, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${log.rating}/5',
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitleParts.join(' • '),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (log.review != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(log.review!, style: AppTypography.bodyMedium),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.beerLogDeleteAction,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
