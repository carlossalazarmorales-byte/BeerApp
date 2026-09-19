import 'dart:convert';
import 'dart:io';

import 'package:beerapp/l10n/generated/app_localizations_en.dart';
import 'package:beerapp/l10n/generated/app_localizations_es.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _messageKeys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  test('every English string has a Spanish translation, and vice versa', () {
    final en = _messageKeys(_arb('app_en.arb'));
    final es = _messageKeys(_arb('app_es.arb'));

    expect(en.difference(es), isEmpty, reason: 'missing in app_es.arb');
    expect(es.difference(en), isEmpty, reason: 'missing in app_en.arb');
  });

  test('every contribution string is described in the template ARB', () {
    final en = _arb('app_en.arb');
    final contributionKeys = _messageKeys(en).where(
      (k) =>
          k.startsWith('contribution') ||
          k.startsWith('suggestBeer') ||
          k.startsWith('suggestBrewery') ||
          k.startsWith('profileContributions'),
    );
    expect(contributionKeys, isNotEmpty);
    for (final key in contributionKeys) {
      expect(en['@$key'], isNotNull, reason: '$key has no @description');
    }
  });

  test('placeholders survive translation', () {
    final en = AppLocalizationsEn();
    final es = AppLocalizationsEs();
    expect(en.contributionValidationTooLong(200), contains('200'));
    expect(es.contributionValidationTooLong(200), contains('200'));
  });

  test('the pending-review wording never claims the catalog changed', () {
    final en = AppLocalizationsEn();
    final es = AppLocalizationsEs();
    for (final text in [
      en.contributionSubmittedTitle,
      en.contributionSubmittedBody,
      en.contributionStatusPending,
      es.contributionSubmittedTitle,
      es.contributionSubmittedBody,
      es.contributionStatusPending,
    ]) {
      expect(text.toLowerCase(), isNot(contains('added')), reason: text);
      expect(text.toLowerCase(), isNot(contains('catalog updated')));
      expect(text.toLowerCase(), isNot(contains('añadid')), reason: text);
    }
    expect(en.contributionSubmittedTitle, 'Suggestion received');
    expect(en.contributionStatusPending, 'Pending review');
  });
}
