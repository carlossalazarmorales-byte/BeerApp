import 'dart:io';

import 'package:beerapp/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// Static checks of `ios/Runner/Info.plist`. iOS cannot be built or run on this
/// (Windows) machine, so these verify the file's CONTENT only -- nothing here
/// claims the iOS app builds, signs, or handles the link at runtime.

String _plist() =>
    File('ios/Runner/Info.plist')
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

/// XML forbids a double hyphen inside a comment, and a comment may not end in
/// a hyphen. A file that breaks this is not well-formed, so the native toolchain
/// rejects it -- yet a test that strips comments before looking at the file
/// would never notice. Returns a description of each problem (empty = fine).
List<String> illegalXmlComments(String xml) {
  final problems = <String>[];
  var index = 0;
  while (true) {
    final start = xml.indexOf('<!--', index);
    if (start < 0) break;
    final end = xml.indexOf('-->', start + 4);
    if (end < 0) {
      problems.add('unterminated comment at offset $start');
      break;
    }
    final body = xml.substring(start + 4, end);
    if (body.contains('--') || body.endsWith('-')) {
      problems.add('"--" inside the comment at offset $start');
    }
    index = end + 3;
  }
  return problems;
}

Set<String> _keys(String plist) =>
    RegExp(r'<key>([^<]+)</key>')
        .allMatches(plist)
        .map((m) => m.group(1)!)
        .toSet();

void main() {
  group('the file is well-formed XML', () {
    test('no comment contains a double hyphen (which XML forbids)', () {
      expect(
        illegalXmlComments(File('ios/Runner/Info.plist').readAsStringSync()),
        isEmpty,
      );
    });

    test('the checker itself catches a "--" inside a comment', () {
      expect(
        illegalXmlComments('<a><!-- not invented -- it is --></a>'),
        hasLength(1),
      );
      expect(
        illegalXmlComments('<a><!-- fine, with one - hyphen --></a>'),
        isEmpty,
      );
      expect(
        illegalXmlComments('<a><!-- ends in a hyphen ---></a>'),
        hasLength(1),
      );
      expect(illegalXmlComments('<a><!-- never closed </a>'), hasLength(1));
      expect(illegalXmlComments('<a>no comments</a>'), isEmpty);
    });
  });

  group('auth redirect scheme', () {
    test(
      'CFBundleURLTypes registers the same scheme as Env.authRedirectUri',
      () {
        final plist = _plist();

        expect(_keys(plist), contains('CFBundleURLTypes'));
        final schemes = RegExp(
          r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
          dotAll: true,
        ).firstMatch(plist);
        expect(schemes, isNotNull);
        expect(
          RegExp(r'<string>([^<]+)</string>')
              .allMatches(schemes!.group(1)!)
              .map((m) => m.group(1)),
          [Env.authRedirectUri.scheme],
        );
      },
    );

    test('it is the same scheme the Android intent filter uses', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync()
          .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

      expect(
        manifest,
        contains('android:scheme="${Env.authRedirectUri.scheme}"'),
      );
    });

    test('the URL type is named after the scheme (reverse-DNS, our own)', () {
      // Whitespace-tolerant: the file may carry Windows (CRLF) line endings.
      final name = RegExp(
        r'<key>CFBundleURLName</key>\s*<string>([^<]+)</string>',
      ).firstMatch(_plist());

      expect(name, isNotNull);
      expect(name!.group(1), Env.authRedirectUri.scheme);
    });
  });

  group('Google Sign-In on iOS is NOT CONFIGURED', () {
    test(
      'no GIDClientID has been invented (release blocker until supplied)',
      () {
        final plist = _plist();

        if (!_keys(plist).contains('GIDClientID')) {
          // Documented: not configured. This is the expected state today.
          return;
        }
        // If someone adds it, it must be a real-looking Google iOS client ID --
        // never a placeholder that would ship as if it were configured.
        final value = RegExp(
          r'<key>GIDClientID</key>\s*<string>([^<]*)</string>',
        ).firstMatch(plist)!.group(1)!;
        expect(
          value,
          matches(RegExp(r'^\d+-[a-z0-9]+\.apps\.googleusercontent\.com$')),
          reason: 'GIDClientID must be the real Google iOS client ID',
        );
      },
    );
  });

  group('privacy and transport', () {
    test('the camera is the only usage description, with a clear purpose', () {
      final usage = _keys(_plist())
          .where((k) => k.endsWith('UsageDescription'))
          .toSet();

      expect(usage, {'NSCameraUsageDescription'});
      expect(
        RegExp(
          r'<key>NSCameraUsageDescription</key>\s*<string>([^<]+)</string>',
        ).firstMatch(_plist())!.group(1),
        contains('scan'),
      );
    });

    test('App Transport Security is left at its secure default', () {
      final keys = _keys(_plist());

      expect(keys, isNot(contains('NSAppTransportSecurity')));
      expect(_plist(), isNot(contains('NSAllowsArbitraryLoads')));
    });

    test('no background modes, tracking or local-network entitlements', () {
      final keys = _keys(_plist());

      for (final forbidden in [
        'UIBackgroundModes',
        'NSUserTrackingUsageDescription',
        'NSLocalNetworkUsageDescription',
        'NSBonjourServices',
      ]) {
        expect(keys, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
