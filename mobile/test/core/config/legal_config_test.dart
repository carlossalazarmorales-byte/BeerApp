import 'package:beerapp/core/config/legal_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both documents are configured from valid public https URLs', () {
    final config = LegalConfig.parse(
      privacyPolicyUrl: 'https://legal.example.com/privacy',
      termsOfServiceUrl: 'https://legal.example.com/terms',
    );

    expect(
      config.privacyPolicyUri,
      Uri.parse('https://legal.example.com/privacy'),
    );
    expect(
      config.termsOfServiceUri,
      Uri.parse('https://legal.example.com/terms'),
    );
  });

  test('unset values mean "not configured", never a fabricated URL', () {
    final config = LegalConfig.parse(
      privacyPolicyUrl: '',
      termsOfServiceUrl: '',
    );

    expect(config.privacyPolicyUri, isNull);
    expect(config.termsOfServiceUri, isNull);
  });

  test('each document is configured independently', () {
    final config = LegalConfig.parse(
      privacyPolicyUrl: 'https://legal.example.com/privacy',
      termsOfServiceUrl: '',
    );

    expect(config.privacyPolicyUri, isNotNull);
    expect(config.termsOfServiceUri, isNull);
  });

  test('an unsafe or non-https value is treated as not configured', () {
    for (final unsafe in [
      'http://legal.example.com/privacy',
      'javascript:alert(1)',
      'https://user:pw@legal.example.com/privacy',
      'https://localhost/privacy',
      'https://10.0.2.2/privacy',
      'legal.example.com/privacy',
    ]) {
      final config = LegalConfig.parse(
        privacyPolicyUrl: unsafe,
        termsOfServiceUrl: unsafe,
      );
      expect(config.privacyPolicyUri, isNull, reason: unsafe);
      expect(config.termsOfServiceUri, isNull, reason: unsafe);
    }
  });

  test('with no dart-define values the environment config is unset', () {
    final config = LegalConfig.fromEnvironment();

    expect(config.privacyPolicyUri, isNull);
    expect(config.termsOfServiceUri, isNull);
  });
}
