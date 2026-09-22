import 'dart:io';

import 'package:beerapp/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for Phase 15, Stage 2 release-signing wiring and the final release
/// identity. Reads the real Gradle build script and platform project files as text (the same
/// regex-over-source-file approach as `android_manifest_test.dart` / `ios_info_plist_test.dart`),
/// so a change that reintroduces a silent debug-signing fallback -- or renames the identifier in
/// one place but not the others -- fails a test instead of slipping in unnoticed.
///
/// This does NOT prove Gradle actually behaves as the source says (a real Gradle invocation
/// can't run inside `flutter test`); that is verified separately by running Gradle directly. See
/// docs/RELEASE.md, section 8 "Signing".

String _gradle() => File('android/app/build.gradle.kts').readAsStringSync();

const _finalIdentifier = 'com.carlossalazarmorales.beerapp';
const _inspectionFlag = 'allowDebugSigningForReleaseInspection';

void main() {
  group('release signing: fail-closed, no silent debug fallback', () {
    test('the release buildType no longer unconditionally signs with the debug key', () {
      // The original Flutter template line this replaces.
      expect(
        _gradle(),
        isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
      );
    });

    test('release signing is read from a git-ignored key.properties', () {
      final gradle = _gradle();

      expect(gradle, contains('rootProject.file("key.properties")'));
      expect(gradle, contains('keyAlias'));
      expect(gradle, contains('keyPassword'));
      expect(gradle, contains('storeFile'));
      expect(gradle, contains('storePassword'));
    });

    test(
      'without key.properties, a release build fails only via the explicit '
      'inspection-only opt-in -- never falls back to debug signing silently',
      () {
        final gradle = _gradle();

        // The opt-in flag is intentionally specific, not a generic name.
        expect(gradle, contains(_inspectionFlag));
        expect(gradle, contains('-P$_inspectionFlag=true'));
        expect(
          gradle,
          contains('NEVER UPLOAD THIS BUILD TO GOOGLE PLAY'),
          reason: 'the inspection-only opt-in must say plainly not to upload',
        );
        // The failure path points the owner at the runbook.
        expect(gradle, contains('docs/RELEASE.md'));
        // Both real assembleRelease/bundleRelease are covered (Flutter's own task names,
        // confirmed against this project's Gradle output -- no product flavors here).
        expect(gradle, contains('"assembleRelease"'));
        expect(gradle, contains('"bundleRelease"'));
        expect(gradle, contains('GradleException'));
      },
    );

    test('key.properties and keystore files stay git-ignored', () {
      final rootIgnore = File('../.gitignore').readAsStringSync();
      final androidIgnore = File('android/.gitignore').readAsStringSync();

      for (final ignore in [rootIgnore, androidIgnore]) {
        expect(ignore, contains('key.properties'));
        expect(ignore, contains('*.jks'));
        expect(ignore, contains('*.keystore'));
      }
    });
  });

  group('final release identity (Phase 15, Stage 2 decision: unchanged)', () {
    test('Android applicationId and namespace are the final identifier', () {
      final gradle = _gradle();

      expect(gradle, contains('namespace = "$_finalIdentifier"'));
      expect(gradle, contains('applicationId = "$_finalIdentifier"'));
    });

    test('iOS bundle identifier is the same final identifier', () {
      final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync();

      expect(
        pbxproj,
        contains('PRODUCT_BUNDLE_IDENTIFIER = $_finalIdentifier;'),
      );
    });

    test('the auth deep-link scheme is derived from the same identifier', () {
      // Env.authRedirectUri is already cross-checked against the Android manifest and the
      // iOS Info.plist by the other platform tests; this only pins it to the final identifier.
      expect(Env.authRedirectUri.scheme, _finalIdentifier);
    });
  });
}
