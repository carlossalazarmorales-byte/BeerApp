import 'package:beerapp/features/scan/presentation/scan_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  // Profile (Phase 9) no longer belongs here -- it has a real UI now, not a
  // PlaceholderScreen, and its own dedicated tests in
  // test/features/profile/presentation/profile_screen_test.dart. Add a
  // destination here only while it's still genuinely a PlaceholderScreen.
  final cases = <String, (Widget Function(), String)>{
    'Scan': (() => const ScanScreen(), 'Scan'),
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
