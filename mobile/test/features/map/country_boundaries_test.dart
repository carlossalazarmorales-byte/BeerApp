import 'package:beerapp/features/map/data/country_boundaries.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the real bundled asset (declared in pubspec.yaml) -- `flutter
/// test` backs `rootBundle` with the actual local file, so this is not a
/// synthetic fixture. See assets/map/NOTICE.txt for the exact source
/// release and its documented ISO-code gaps, which the assertions below
/// verify against by name rather than assuming.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a non-trivial number of country boundaries', () async {
    final boundaries = await CountryBoundaries.load();

    expect(boundaries.length, greaterThan(230));
  });

  test('small island nations dropped by the earlier 1:110m release are present '
      '-- regression for the on-device manual QA finding that fills looked '
      'imprecise/islands were missing', () async {
    final boundaries = await CountryBoundaries.load();
    final isoCodes = boundaries.map((b) => b.isoCode).toSet();

    // Natural Earth 1:110m drops states below its area threshold entirely
    // (not merely simplifies them) -- Seychelles, Maldives, Malta,
    // Singapore, Bahrain and Comoros were all confirmed absent from that
    // release. The 1:50m release used now includes all of them.
    expect(isoCodes, containsAll(['SC', 'MV', 'MT', 'SG', 'BH', 'KM']));
  });

  test('every boundary carries a geometry object', () async {
    final boundaries = await CountryBoundaries.load();

    for (final boundary in boundaries) {
      expect(boundary.geometry['type'], isNotNull);
      expect(boundary.geometry['coordinates'], isNotNull);
    }
  });

  test('most boundaries resolve a clean 2-letter ISO code', () async {
    final boundaries = await CountryBoundaries.load();

    final resolved = boundaries.where((b) => b.isoCode != null).length;
    expect(
      resolved,
      greaterThan(boundaries.length - 10),
      reason:
          'only a handful of disputed/unrecognized territories should '
          'ever fail to resolve -- see assets/map/NOTICE.txt',
    );
    for (final boundary in boundaries) {
      if (boundary.isoCode != null) {
        expect(RegExp(r'^[A-Z]{2}$').hasMatch(boundary.isoCode!), isTrue);
      }
    }
  });

  test('known ambiguous-ISO_A2 countries (documented in NOTICE.txt) still resolve via ISO_A2_EH', () async {
    final boundaries = await CountryBoundaries.load();
    final isoCodes = boundaries.map((b) => b.isoCode).toSet();

    // Norway, France, Kosovo and Taiwan have ISO_A2 == "-99" (or, for
    // Taiwan, the non-standard "CN-TW") in this Natural Earth release,
    // but a clean code in ISO_A2_EH -- proving the loader prefers EH
    // rather than accepting the raw ISO_A2 sentinel/oddity.
    expect(isoCodes, containsAll(['NO', 'FR', 'XK', 'TW']));
  });

  test('a genuinely unresolvable territory (no clean code in either column) has a null isoCode, never a fabricated one', () async {
    final boundaries = await CountryBoundaries.load();
    final unresolved = boundaries.where((b) => b.isoCode == null);

    expect(
      unresolved,
      isNotEmpty,
      reason:
          'Natural Earth has at least "N. Cyprus" and Somaliland unresolved '
          'in both ISO_A2 and ISO_A2_EH at this scale -- see NOTICE.txt',
    );
  });
}
