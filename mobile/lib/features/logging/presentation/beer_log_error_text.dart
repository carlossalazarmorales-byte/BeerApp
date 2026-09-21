import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Maps an [ApiException]'s *type* to localized user-facing text. Never
/// interpolates [ApiException.message] -- that field is raw backend
/// diagnostic text and must not reach a `Text` widget. Mirrors
/// `features/catalog/presentation/catalog_error_text.dart`, plus the 400
/// case beer logs are the first endpoint to actually raise.
String beerLogErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is InvalidRequestApiException) {
    return l10n.beerLogErrorInvalidRequest;
  }
  if (error is UnauthorizedApiException) return l10n.beerLogErrorUnauthorized;
  if (error is ServiceUnavailableApiException) {
    return l10n.beerLogErrorServiceUnavailable;
  }
  if (error is NetworkApiException) return l10n.beerLogErrorNetwork;
  if (error is NotFoundApiException) return l10n.beerLogErrorNotFound;
  return l10n.beerLogErrorGeneric;
}
