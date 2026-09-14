import 'package:flutter/material.dart';

import '../../tokens/app_colors.dart';
import '../../tokens/app_radii.dart';
import '../../tokens/app_shadows.dart';
import '../../tokens/app_spacing.dart';

/// A reusable surface card: tonal background, large radius, diffused
/// ambient shadow, no divider lines — per the Stitch "No-Line Rule".
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = AppColors.surfaceContainerLow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadii.lgRadius,
        boxShadow: AppShadows.ambient,
      ),
      child: child,
    );
  }
}
