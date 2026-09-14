import 'package:flutter/material.dart';

/// Type-scale tokens: Plus Jakarta Sans for display/headline/title/label
/// roles (brand and section-header moments), Inter for body/meta text —
/// per `/stitch/amber_froth/DESIGN.md`.
///
/// Only weights actually bundled under `assets/fonts/` are referenced here:
/// Plus Jakarta Sans Bold (700) and ExtraBold (800) — its variable font's
/// weight axis only goes up to 800, so `FontWeight.w900` is never used —
/// and Inter Regular (400).
abstract final class AppTypography {
  static const String _headlineFontFamily = 'Plus Jakarta Sans';
  static const String _bodyFontFamily = 'Inter';

  /// App-bar titles and other single, bold brand moments.
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _headlineFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    height: 1.2,
  );

  /// Section headers and card titles.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _headlineFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Uppercase eyebrow labels and bottom-navigation labels.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _headlineFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    height: 1.2,
  );

  /// Default body copy.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _bodyFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Meta text (timestamps, captions, helper text).
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _bodyFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const TextTheme textTheme = TextTheme(
    headlineLarge: headlineLarge,
    titleLarge: titleLarge,
    labelLarge: labelLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
  );
}
