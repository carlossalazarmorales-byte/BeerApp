import 'dart:io';

import 'package:beerapp/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the Android release surface. These read the real
/// manifests, so a permission or backup/cleartext change fails a test rather
/// than slipping into a build unnoticed.
///
/// Parsed with plain regexes (comments stripped first) instead of an XML
/// package, to add no dependency for a few attribute checks.

const _main = 'android/app/src/main/AndroidManifest.xml';
const _debug = 'android/app/src/debug/AndroidManifest.xml';
const _profile = 'android/app/src/profile/AndroidManifest.xml';

String _read(String path) =>
    File(path)
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

final _usesPermissionTag = RegExp(r'<uses-permission\b[^>]*>', dotAll: true);

/// True for a `<uses-permission ... tools:node="remove"/>` entry, which asks the
/// manifest merger to DROP a permission a library adds; it is not a request.
bool _isRemoval(String tag) =>
    RegExp(r'tools:node\s*=\s*"remove"').hasMatch(tag);

String? _permissionName(String tag) =>
    RegExp(r'android:name="([^"]+)"').firstMatch(tag)?.group(1);

/// Permissions the manifest REQUESTS. `tools:node="remove"` entries are not
/// counted, so a future, device-proven removal of an inherited permission (see
/// docs/RELEASE.md) cannot be mistaken for a declaration.
Set<String> _permissions(String manifest) => _usesPermissionTag
    .allMatches(manifest)
    .map((m) => m.group(0)!)
    .where((tag) => !_isRemoval(tag))
    .map(_permissionName)
    .whereType<String>()
    .toSet();

/// Permissions the manifest asks the merger to remove via `tools:node="remove"`.
Set<String> _removedPermissions(String manifest) => _usesPermissionTag
    .allMatches(manifest)
    .map((m) => m.group(0)!)
    .where(_isRemoval)
    .map(_permissionName)
    .whereType<String>()
    .toSet();

/// The opening `<application ...>` tag (or self-closing one), attributes only.
String _applicationTag(String manifest) {
  final match = RegExp(
    r'<application\b[^>]*>',
    dotAll: true,
  ).firstMatch(manifest);
  expect(match, isNotNull, reason: 'manifest has an <application> element');
  return match!.group(0)!;
}

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

void main() {
  group('the manifests are well-formed XML', () {
    for (final path in [
      'android/app/src/main/AndroidManifest.xml',
      'android/app/src/debug/AndroidManifest.xml',
      'android/app/src/profile/AndroidManifest.xml',
    ]) {
      test('no comment in $path contains a double hyphen', () {
        expect(illegalXmlComments(File(path).readAsStringSync()), isEmpty);
      });
    }
  });

  group('permissions', () {
    test('the release manifest requests INTERNET and CAMERA only', () {
      expect(_permissions(_read(_main)), {
        'android.permission.INTERNET',
        'android.permission.CAMERA',
      });
    });

    test('no storage, media, location, contacts or microphone permission', () {
      final permissions = _permissions(_read(_main));

      for (final forbidden in [
        'STORAGE',
        'MEDIA',
        'LOCATION',
        'CONTACTS',
        'RECORD_AUDIO',
        'PHONE',
        'SMS',
        'BLUETOOTH',
        'POST_NOTIFICATIONS',
      ]) {
        expect(
          permissions.where((p) => p.contains(forbidden)),
          isEmpty,
          reason: forbidden,
        );
      }
    });

    test('debug and profile manifests add at most INTERNET (tooling)', () {
      for (final path in [_debug, _profile]) {
        expect(
          _permissions(_read(path)).difference({'android.permission.INTERNET'}),
          isEmpty,
          reason: path,
        );
      }
    });

    test(
      'a camera is not required to install the app (scanning is optional)',
      () {
        expect(
          _read(_main),
          matches(
            RegExp(
              r'<uses-feature\s+[^>]*android:name="android\.hardware\.camera"[^>]*android:required="false"',
              dotAll: true,
            ),
          ),
        );
      },
    );
  });

  group('permission helpers (prepare a future tools:node="remove")', () {
    const sample = '''
<manifest xmlns:android="a" xmlns:tools="t">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission
      android:name="android.permission.ACCESS_FINE_LOCATION"
      tools:node="remove" />
</manifest>''';

    test(
      'a tools:node="remove" entry is not counted as a requested permission',
      () {
        expect(_permissions(sample), {'android.permission.INTERNET'});
        expect(_removedPermissions(sample), {
          'android.permission.ACCESS_FINE_LOCATION',
        });
      },
    );

    test('the current source manifests remove nothing (removal is device-gated)', () {
      // The location permissions MapLibre adds are intentionally still present:
      // removing them waits for a physical release-build test (docs/RELEASE.md).
      // When that change lands, update this expectation in the same commit.
      for (final path in [_main, _debug, _profile]) {
        expect(_removedPermissions(_read(path)), isEmpty, reason: path);
      }
    });
  });

  group('app name', () {
    test('the launcher label is the working product name "BeerApp"', () {
      expect(
        _applicationTag(_read(_main)),
        contains('android:label="BeerApp"'),
      );
    });
  });

  group('backup', () {
    test('allowBackup is explicitly false in the release manifest', () {
      expect(
        _applicationTag(_read(_main)),
        contains('android:allowBackup="false"'),
      );
    });

    test('no source set turns backup back on', () {
      for (final path in [_main, _debug, _profile]) {
        expect(
          _read(path),
          isNot(contains('android:allowBackup="true"')),
          reason: path,
        );
      }
    });

    test('there are no backup rule files that could re-enable it', () {
      final tag = _applicationTag(_read(_main));
      expect(tag, isNot(contains('fullBackupContent')));
      expect(tag, isNot(contains('dataExtractionRules')));
    });
  });

  group('cleartext traffic', () {
    test(
      'the release manifest allows no cleartext and has no network config',
      () {
        final tag = _applicationTag(_read(_main));

        expect(tag, isNot(contains('usesCleartextTraffic="true"')));
        expect(tag, isNot(contains('networkSecurityConfig')));
        expect(
          File('android/app/src/main/res/xml/network_security_config.xml')
              .existsSync(),
          isFalse,
        );
      },
    );

    test('the profile source set has no cleartext allowance either', () {
      expect(_read(_profile), isNot(contains('networkSecurityConfig')));
      expect(_read(_profile), isNot(contains('usesCleartextTraffic')));
    });

    test(
      'only the DEBUG source set permits cleartext, and only to 10.0.2.2',
      () {
        expect(_read(_debug), contains('android:networkSecurityConfig'));

        final config =
            File('android/app/src/debug/res/xml/network_security_config.xml')
                .readAsStringSync()
                .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

        // No blanket permission: base-config, if present, must not allow cleartext.
        final base =
            RegExp(r'<base-config[^>]*>').firstMatch(config)?.group(0) ?? '';
        expect(base, isNot(contains('cleartextTrafficPermitted="true"')));

        final permitted = RegExp(
          r'<domain-config[^>]*cleartextTrafficPermitted="true"[^>]*>(.*?)</domain-config>',
          dotAll: true,
        ).allMatches(config).toList();
        expect(permitted, hasLength(1));
        final domains = RegExp(r'<domain[^>]*>([^<]+)</domain>')
            .allMatches(permitted.single.group(1)!)
            .map((m) => m.group(1)!.trim())
            .toList();
        expect(domains, ['10.0.2.2']);
      },
    );
  });

  group('auth deep link', () {
    test('the intent filter matches Env.authRedirectUri exactly', () {
      final manifest = _read(_main);
      final data = RegExp(
        r'<data\s+[^>]*android:scheme="([^"]+)"[^>]*android:host="([^"]+)"',
      ).firstMatch(manifest);

      expect(data, isNotNull);
      expect(data!.group(1), Env.authRedirectUri.scheme);
      expect(data.group(2), Env.authRedirectUri.host);
    });

    test('it is a custom scheme, not an http(s) link needing verification', () {
      final manifest = _read(_main);

      expect(manifest, isNot(contains('android:autoVerify')));
      expect(Env.authRedirectUri.scheme, isNot(anyOf('http', 'https')));
    });
  });

  test('the only exported component is the launcher activity', () {
    final exported = RegExp(
      r'<(activity|service|receiver|provider)\b[^>]*android:exported="true"',
    ).allMatches(_read(_main)).toList();

    expect(exported, hasLength(1));
    expect(exported.single.group(1), 'activity');
  });
}
