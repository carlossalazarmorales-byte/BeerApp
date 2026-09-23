import 'package:beerapp/features/map/presentation/map_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_map_repository.dart';

/// MapScreen's config-unavailable path (`MapConfig.isConfigured == false`,
/// which is the default in `flutter test` -- no `--dart-define
/// MAPTILER_API_KEY` is ever passed here) is the only part of this screen
/// safely exercisable in a widget test: with a key configured, the screen
/// builds a real `MapLibreMap`, which creates a native platform view that
/// `flutter test`'s environment doesn't back with a real implementation.
/// The interactive map surface itself (markers, clustering, mode
/// switching, search-driven camera moves) is verified on a real
/// Android device/emulator instead -- see the Phase 8 smoke-test
/// checklist. `MapModeSelector`/`BeerPreviewCard`/`MapLegend` are covered
/// directly in their own widget tests.
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets(
    'without a configured tile provider, shows a localized unavailable message instead of a map',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          MapScreen(
            repository: FakeMapRepository(),
            catalogRepository: FakeCatalogRepository(),
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text("The interactive map isn't set up on this build yet."),
        findsOneWidget,
      );
      expect(
        find.text('Map'),
        findsOneWidget,
        reason: 'AppBar title still renders',
      );
    },
  );
}
