import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_radii.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';

/// BeerApp's primary call-to-action button: the amber gradient pill used
/// across the Stitch mockups (top-left to bottom-right direction, chosen as
/// the single standard since Stitch itself used the direction
/// inconsistently across screens).
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 100),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.xlRadius,
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryContainer],
                  )
                : null,
            color: enabled ? null : AppColors.surfaceContainerHigh,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: enabled
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                widget.label,
                style: AppTypography.titleLarge.copyWith(
                  color: enabled
                      ? AppColors.onPrimary
                      : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
