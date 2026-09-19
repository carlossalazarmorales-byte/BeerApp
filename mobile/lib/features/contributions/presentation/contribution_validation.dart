import '../../../l10n/generated/app_localizations.dart';

/// Client-side *shape* checks for the contribution forms -- a convenience so
/// obvious mistakes are caught before a round trip. The backend remains the
/// source of truth for every rule (lengths after whitespace normalization,
/// canonical barcode, GS1 check digit): in particular there is deliberately
/// no barcode check-digit logic here, so the one barcode validator stays
/// server-side.

const int maxNameLength = 200;
const int maxShortTextLength = 100;

/// A blank value becomes null so an untouched optional field is simply not
/// sent.
String? trimmedOrNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String? validateRequiredText(
  AppLocalizations l10n,
  String? value, {
  int maxLength = maxNameLength,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return l10n.contributionValidationRequired;
  if (trimmed.length > maxLength) {
    return l10n.contributionValidationTooLong(maxLength);
  }
  return null;
}

String? validateOptionalText(
  AppLocalizations l10n,
  String? value, {
  int maxLength = maxShortTextLength,
}) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.length > maxLength) {
    return l10n.contributionValidationTooLong(maxLength);
  }
  return null;
}

final RegExp _abvShape = RegExp(r'^\d{1,2}([.,]\d{1,2})?$');

/// Parses an ABV the way a user types it (`6.5`, `6,5`), or null when blank
/// or malformed. Range/precision match the backend's `numeric(4,2)`:
/// 0 to 99.99 with at most two decimals.
double? parseAbv(String? value) {
  final trimmed = value?.trim() ?? '';
  if (!_abvShape.hasMatch(trimmed)) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

String? validateOptionalAbv(AppLocalizations l10n, String? value) {
  if ((value?.trim() ?? '').isEmpty) return null;
  return parseAbv(value) == null ? l10n.contributionValidationAbv : null;
}

final RegExp _barcodeShape = RegExp(r'^(\d{8}|\d{12}|\d{13})$');

String? validateOptionalBarcode(AppLocalizations l10n, String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return _barcodeShape.hasMatch(trimmed)
      ? null
      : l10n.contributionValidationBarcode;
}
