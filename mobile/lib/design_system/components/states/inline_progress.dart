import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// A small indeterminate spinner for a busy action or a "load more" footer.
///
/// [LoadingState] covers a whole screen or section; this is the compact form
/// (a trailing spinner in a row, a footer under a list). Both announce
/// "Loading…" to assistive technology -- a bare `CircularProgressIndicator`
/// is silent to a screen reader.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        semanticsLabel: AppLocalizations.of(context).loadingStateMessage,
      ),
    );
  }
}

/// A thin indeterminate bar shown above content that is refreshing in place.
/// Announces "Loading…" like [InlineSpinner].
class InlineProgressBar extends StatelessWidget {
  const InlineProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      minHeight: 2,
      semanticsLabel: AppLocalizations.of(context).loadingStateMessage,
    );
  }
}
