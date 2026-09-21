import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_gradients.dart';
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
  bool _focused = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;

    // A custom-drawn button must declare what a Material button gets for free:
    // its role and enabled state for screen readers, and keyboard / switch
    // focus + activation (Enter/Space arrive as ActivateIntent).
    return Semantics(
      button: true,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          // A disabled button registers no gesture handlers at all, so it also
          // exposes no tap action to assistive technology.
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
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
                gradient: enabled ? AppGradients.primary : null,
                color: enabled ? null : AppColors.surfaceContainerHigh,
              ),
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      borderRadius: AppRadii.xlRadius,
                      border: Border.all(color: AppColors.onSurface, width: 2),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      color: enabled
                          ? AppColors.onPrimaryGradient
                          : AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  // Flexible so a long label (or large system text) wraps
                  // instead of overflowing the button.
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                        color: enabled
                            ? AppColors.onPrimaryGradient
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
