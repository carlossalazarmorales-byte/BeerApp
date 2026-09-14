import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radii.dart';
import '../tokens/app_shadows.dart';
import '../tokens/app_typography.dart';

/// Builds BeerApp's single light [ThemeData] from the design tokens.
/// Dark mode is deferred to a later phase.
abstract final class AppTheme {
  static ThemeData get light {
    final baseTextTheme = Typography.material2021(
      platform: TargetPlatform.android,
    ).black.merge(AppTypography.textTheme);

    return ThemeData(
      useMaterial3: true,
      colorScheme: AppColors.lightScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineLarge.copyWith(
          color: AppColors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgRadius),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlRadius),
          textStyle: AppTypography.titleLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: AppRadii.mdRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.mdRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      dividerColor: AppColors.outlineVariant.withValues(alpha: 0.15),
      shadowColor: AppShadows.ambient.first.color,
    );
  }
}
