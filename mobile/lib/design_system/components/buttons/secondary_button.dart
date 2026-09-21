import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_radii.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Tonal secondary button — a `secondaryContainer` fill with no gradient,
/// used for lower-emphasis actions alongside a [PrimaryButton].
///
/// A null [onPressed] disables it: it is announced as disabled, skipped by
/// keyboard focus, and drawn with the same muted treatment as a disabled
/// [PrimaryButton] so the state is not conveyed by behaviour alone.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled
            ? AppColors.secondaryContainer
            : AppColors.surfaceContainerHigh,
        borderRadius: AppRadii.xlRadius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadii.xlRadius,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.titleLarge.copyWith(
                color: enabled
                    ? AppColors.onSecondaryFixed
                    : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
