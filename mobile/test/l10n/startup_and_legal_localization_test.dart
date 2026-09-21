import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The strings Stage 4 added must exist, in both languages, be real translations
/// (Spanish differs from English), and never expose technical detail.
const _keys = [
  'settingsLegalLinkOpenFailed',
  'startupFailureConfigurationTitle',
  'startupFailureConfigurationMessage',
  'startupFailureInitializationTitle',
  'startupFailureInitializationMessage',
];

Map<String, dynamic> _arb(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final en = _arb('en');
  final es = _arb('es');

  test('every new string exists in English and Spanish', () {
    for (final key in _keys) {
      expect(en[key], isA<String>(), reason: 'en $key');
      expect(es[key], isA<String>(), reason: 'es $key');
      expect((en[key] as String).trim(), isNotEmpty, reason: 'en $key');
      expect((es[key] as String).trim(), isNotEmpty, reason: 'es $key');
    }
  });

  test('the Spanish text is a translation, not a copy of the English', () {
    for (final key in _keys) {
      expect(es[key], isNot(en[key]), reason: key);
    }
  });

  test('English strings carry a description for translators', () {
    for (final key in _keys) {
      expect(en['@$key'], isA<Map<String, dynamic>>(), reason: key);
      expect((en['@$key'] as Map)['description'], isNotEmpty, reason: key);
    }
  });

  test('none of the strings has a placeholder that could carry a value', () {
    // A `{name}` placeholder is how a URL, error or setting name could leak in.
    for (final key in _keys) {
      expect(en[key] as String, isNot(contains('{')), reason: 'en $key');
      expect(es[key] as String, isNot(contains('{')), reason: 'es $key');
    }
  });

  test('user-facing text never names a setting, URL, key or exception', () {
    for (final locale in [en, es]) {
      for (final key in _keys) {
        final text = (locale[key] as String).toLowerCase();
        for (final leaked in [
          'http',
          'supabase',
          'api_base_url',
          'exception',
          'stack',
          'key',
        ]) {
          expect(
            text,
            isNot(contains(leaked)),
            reason: '$key contains "$leaked"',
          );
        }
      }
    }
  });

  test('English and Spanish still define exactly the same message keys', () {
    Set<String> messageKeys(Map<String, dynamic> arb) =>
        arb.keys.where((k) => !k.startsWith('@')).toSet();

    expect(messageKeys(es), messageKeys(en));
  });
}
