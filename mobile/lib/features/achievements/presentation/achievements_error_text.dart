import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Maps an [ApiException]'s *type* to localized user-facing text. Never
/// interpolates [ApiException.message] -- that field is raw backend
/// diagnostic text and must not reach a `Text` widget. Mirrors
/// `features/statistics/presentation/statistics_error_text.dart`; there is
/// no not-found case here, since `GET /achievements` has no path parameter
/// to 404 on.
String achievementsErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is UnauthorizedApiException) {
    return l10n.achievementsErrorUnauthorized;
  }
  if (error is ServiceUnavailableApiException) {
    return l10n.achievementsErrorServiceUnavailable;
  }
  if (error is NetworkApiException) return l10n.achievementsErrorNetwork;
  return l10n.achievementsErrorGeneric;
}
