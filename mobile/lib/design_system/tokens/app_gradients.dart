import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Gradient tokens.
abstract final class AppGradients {
  /// The amber call-to-action gradient (top-left to bottom-right), used by
  /// `PrimaryButton` and `ScanNavButton`. Its foreground is
  /// [AppColors.onPrimaryGradient].
  ///
  /// The Stitch reference runs it from `primary` (#795900) to
  /// `primaryContainer` (#ffbf00). That start colour is too dark for any dark
  /// foreground and the end colour is too bright for a light one, so no single
  /// label colour reaches WCAG AA (4.5:1) across it. The start is therefore
  /// [AppColors.primaryGradientStart] -- lighter, same amber hue -- so the
  /// dark [AppColors.onPrimaryGradient] passes over the WHOLE gradient
  /// (worst case 4.90:1; asserted in `test/accessibility/token_contrast_test.dart`).
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryGradientStart, AppColors.primaryContainer],
  );
}
