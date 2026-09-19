import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Backend `error.code` values of the two hard-block 409s (see docs/API.md).
const String barcodeInCatalogCode = 'barcode_in_catalog';
const String alreadySubmittedCode = 'already_submitted';

/// Maps an [ApiException]'s *type* (and, for a 409, its machine-readable
/// `code`) to localized user-facing text. Never interpolates
/// [ApiException.message] -- that is raw backend diagnostic text and must
/// not reach a `Text` widget.
String contributionErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is ConflictApiException) {
    switch (error.code) {
      case barcodeInCatalogCode:
        return l10n.contributionErrorBarcodeInCatalog;
      case alreadySubmittedCode:
        return l10n.contributionErrorAlreadySubmitted;
    }
    return l10n.contributionErrorGeneric;
  }
  if (error is UnauthorizedApiException) {
    return l10n.contributionErrorUnauthorized;
  }
  if (error is ServiceUnavailableApiException) {
    return l10n.contributionErrorServiceUnavailable;
  }
  if (error is NetworkApiException) return l10n.contributionErrorNetwork;
  if (error is NotFoundApiException) return l10n.contributionErrorNotFound;
  if (error is ValidationApiException || error is InvalidRequestApiException) {
    return l10n.contributionErrorValidation;
  }
  return l10n.contributionErrorGeneric;
}
