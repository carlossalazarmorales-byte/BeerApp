import 'package:flutter/widgets.dart';

import '../../../core/network/api_exception.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Maps an [ApiException]'s *type* to localized user-facing text. Never
/// interpolates [ApiException.message] -- that field is raw backend
/// diagnostic text (FastAPI/PyJWT/asyncpg-originated) and must not reach a
/// `Text` widget.
String catalogErrorText(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context);
  if (error is UnauthorizedApiException) return l10n.catalogErrorUnauthorized;
  if (error is ServiceUnavailableApiException) {
    return l10n.catalogErrorServiceUnavailable;
  }
  if (error is NetworkApiException) return l10n.catalogErrorNetwork;
  if (error is NotFoundApiException) return l10n.catalogErrorNotFound;
  return l10n.catalogErrorGeneric;
}
