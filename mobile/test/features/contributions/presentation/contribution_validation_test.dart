import 'package:beerapp/features/contributions/presentation/contribution_validation.dart';
import 'package:beerapp/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('trimmedOrNull', () {
    test('blank becomes null so an untouched optional field is not sent', () {
      expect(trimmedOrNull(null), isNull);
      expect(trimmedOrNull('   '), isNull);
      expect(trimmedOrNull('  Hazy IPA '), 'Hazy IPA');
    });
  });

  group('validateRequiredText', () {
    test('rejects blank and over-long text', () {
      expect(
        validateRequiredText(l10n, '  '),
        l10n.contributionValidationRequired,
      );
      expect(
        validateRequiredText(l10n, 'x' * 201),
        l10n.contributionValidationTooLong(200),
      );
      expect(
        validateRequiredText(l10n, 'x' * 101, maxLength: 100),
        l10n.contributionValidationTooLong(100),
      );
    });

    test('accepts text at the limit', () {
      expect(validateRequiredText(l10n, 'x' * 200), isNull);
      expect(validateRequiredText(l10n, ' Hazy IPA '), isNull);
    });
  });

  group('validateOptionalText', () {
    test('blank is fine; too long is not', () {
      expect(validateOptionalText(l10n, ''), isNull);
      expect(validateOptionalText(l10n, null), isNull);
      expect(
        validateOptionalText(l10n, 'x' * 101),
        l10n.contributionValidationTooLong(100),
      );
    });
  });

  group('ABV', () {
    test('parses the numbers a user actually types', () {
      expect(parseAbv('6.5'), 6.5);
      expect(parseAbv('6,5'), 6.5); // comma decimal, as in Spanish locales
      expect(parseAbv(' 0 '), 0);
      expect(parseAbv('99.99'), 99.99);
      expect(parseAbv('12'), 12);
    });

    test('rejects what the backend numeric(4,2) would reject', () {
      for (final bad in ['100', '-1', '6.555', 'abc', '', '6.', '.5', '1e2']) {
        expect(parseAbv(bad), isNull, reason: bad);
      }
    });

    test('blank is valid (optional); malformed is not', () {
      expect(validateOptionalAbv(l10n, ''), isNull);
      expect(validateOptionalAbv(l10n, null), isNull);
      expect(validateOptionalAbv(l10n, '6.5'), isNull);
      expect(validateOptionalAbv(l10n, '100'), l10n.contributionValidationAbv);
    });
  });

  group('barcode', () {
    test('checks only the SHAPE -- the check digit stays a server concern', () {
      expect(validateOptionalBarcode(l10n, ''), isNull);
      expect(validateOptionalBarcode(l10n, '96385074'), isNull);
      expect(validateOptionalBarcode(l10n, '036000291452'), isNull);
      expect(validateOptionalBarcode(l10n, '4006381333931'), isNull);
      // Wrong check digit: deliberately NOT rejected client-side.
      expect(validateOptionalBarcode(l10n, '4006381333932'), isNull);
    });

    test('rejects non-digits and unsupported lengths', () {
      for (final bad in ['12345', 'ABCDEFGH', '123456789', '12345678901234']) {
        expect(
          validateOptionalBarcode(l10n, bad),
          l10n.contributionValidationBarcode,
          reason: bad,
        );
      }
    });
  });
}
