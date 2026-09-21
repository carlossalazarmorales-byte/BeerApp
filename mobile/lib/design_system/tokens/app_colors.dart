import 'package:flutter/material.dart';

/// Color tokens for BeerApp's light theme, sourced from the Stitch visual
/// reference (`/stitch/amber_froth/DESIGN.md` and the shared palette used
/// across every Stitch screen mockup). Roles follow Material 3 naming so
/// they map 1:1 onto [ColorScheme].
abstract final class AppColors {
  static const Color surface = Color(0xFFFAF9F5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F4F0);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E4);
  static const Color surfaceContainerHighest = Color(0xFFE3E2DF);

  static const Color primary = Color(0xFF795900);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFBF00);
  static const Color onPrimaryContainer = Color(0xFF6D5000);

  /// Start of the amber call-to-action gradient (`AppGradients.primary`): 40%
  /// of the way from [primary] to [primaryContainer] (`#af8200`). Lightened from
  /// `primary` so a dark label reaches WCAG AA across the whole gradient.
  static const Color primaryGradientStart = Color(0xFFAF8200);

  /// Label/icon colour on `AppGradients.primary`. The existing dark
  /// [onSurface] token: 4.90:1 at the darkest point of the gradient, 10.3:1 at
  /// the brightest.
  static const Color onPrimaryGradient = onSurface;

  static const Color secondary = Color(0xFF725948);
  static const Color secondaryContainer = Color(0xFFFBD9C2);

  static const Color tertiary = Color(0xFF735C00);
  static const Color tertiaryContainer = Color(0xFFECC54B);

  static const Color onSurface = Color(0xFF1B1C1A);
  static const Color onSurfaceVariant = Color(0xFF504532);

  /// Deep-dark tone used in place of pure black anywhere in the UI
  /// ("never use #000000" per the Stitch design spec).
  static const Color onSecondaryFixed = Color(0xFF29180A);

  static const Color outline = Color(0xFF827660);

  /// Only ever used at 15% opacity, and only where a hairline separator is
  /// unavoidable — the "No-Line Rule" prefers background-color shifts and
  /// spacing over divider lines.
  static const Color outlineVariant = Color(0xFFD4C5AB);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onPrimary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryFixed,
    tertiary: tertiary,
    onTertiary: onPrimary,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onSecondaryFixed,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    error: error,
    onError: onPrimary,
    errorContainer: errorContainer,
    onErrorContainer: onSecondaryFixed,
    shadow: onSecondaryFixed,
    scrim: onSecondaryFixed,
    inverseSurface: onSecondaryFixed,
    onInverseSurface: surface,
    inversePrimary: primaryContainer,
  );
}
