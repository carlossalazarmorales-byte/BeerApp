import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import '../buttons/primary_button.dart';

/// Reusable error state with an optional retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message ?? l10n.errorStateDefaultMessage,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.errorStateRetryLabel,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
