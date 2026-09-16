import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Maps an [ApiException]'s *type* to localized user-facing text. Never
/// interpolates [ApiException.message] -- that field is raw backend
/// diagnostic text and must not reach a `Text` widget. Mirrors
/// `features/collection/presentation/collection_error_text.dart`; there is
/// no 404/not-found case here, since neither `/map/beers` nor
/// `/map/breweries` ever raises one (see docs/API.md).
String mapErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is UnauthorizedApiException) return l10n.mapErrorUnauthorized;
  if (error is ServiceUnavailableApiException) {
    return l10n.mapErrorServiceUnavailable;
  }
  if (error is NetworkApiException) return l10n.mapErrorNetwork;
  return l10n.mapErrorGeneric;
}
