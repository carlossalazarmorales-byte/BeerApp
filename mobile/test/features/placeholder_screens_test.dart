import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/collection/presentation/collection_screen.dart';
import 'package:beerapp/features/map/presentation/map_screen.dart';
import 'package:beerapp/features/profile/presentation/profile_screen.dart';
import 'package:beerapp/features/scan/presentation/scan_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_profile_repository.dart';

/// [ProfileScreen] reads [AuthScope.of], so every case is wrapped with one —
/// harmless for the other 4 screens, which don't use it.
Widget _wrap(Widget child) {
  return AuthScope(
    controller: AuthController(
      authRepository: FakeAuthRepository(),
      profileRepository: FakeProfileRepository(),
    ),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  final cases = <String, (Widget Function(), String)>{
    'Map': (() => const MapScreen(), 'Map'),
    'Scan': (() => const ScanScreen(), 'Scan'),
    'Collection': (() => const CollectionScreen(), 'Collection'),
    'Profile': (() => const ProfileScreen(), 'Profile'),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key} screen renders its title without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(entry.value.$1()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The title appears twice by design: once as the AppBar title and
      // once as the large body heading below the icon.
      expect(find.text(entry.value.$2), findsNWidgets(2));
      expect(find.text('Coming soon'), findsOneWidget);
    });
  }
}
