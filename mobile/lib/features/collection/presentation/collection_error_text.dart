import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Maps an [ApiException]'s *type* to localized user-facing text. Never
/// interpolates [ApiException.message] -- that field is raw backend
/// diagnostic text and must not reach a `Text` widget. Mirrors
/// `features/logging/presentation/beer_log_error_text.dart`; there is no
/// 400/invalid-request case here, since nothing in the Collection API ever
/// raises one (see docs/API.md).
String collectionErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is UnauthorizedApiException) {
    return l10n.collectionErrorUnauthorized;
  }
  if (error is ServiceUnavailableApiException) {
    return l10n.collectionErrorServiceUnavailable;
  }
  if (error is NetworkApiException) return l10n.collectionErrorNetwork;
  if (error is NotFoundApiException) return l10n.collectionErrorNotFound;
  return l10n.collectionErrorGeneric;
}
