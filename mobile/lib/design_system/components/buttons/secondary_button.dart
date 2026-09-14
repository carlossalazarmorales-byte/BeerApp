import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_radii.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// Tonal secondary button — a `secondaryContainer` fill with no gradient,
/// used for lower-emphasis actions alongside a [PrimaryButton].
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
    return Material(
      color: AppColors.secondaryContainer,
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
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.onSecondaryFixed,
            ),
          ),
        ),
      ),
    );
  }
}
