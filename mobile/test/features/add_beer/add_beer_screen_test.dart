import 'dart:async';

import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/core/auth/auth_scope.dart';
import 'package:beerapp/features/add_beer/presentation/add_beer_screen.dart';
import 'package:beerapp/features/auth/domain/auth_models.dart';
import 'package:beerapp/features/auth/domain/profile.dart';
import 'package:beerapp/features/auth/presentation/auth_controller.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/scan/presentation/scan_controller.dart';
import 'package:beerapp/features/scan/presentation/scan_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../fakes/fake_auth_repository.dart';
import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_log_repository.dart';
import '../../fakes/fake_profile_repository.dart';

// LogFormSheet reads AuthScope.of(context) -- see beer_detail_screen_test.dart's
// identical note.
AuthController _signedInController() {
  final authRepository = FakeAuthRepository(
    initialUser: const AppUser(id: 'user-1'),
  );
  final profileRepository = FakeProfileRepository()
    ..currentUserId = 'user-1'
    ..seed(const Profile(id: 'user-1', username: 'beerfan'));
  return AuthController(
    authRepository: authRepository,
    profileRepository: profileRepository,
  );
}

/// Builds a minimal router with just Add Beer and Scan, mirroring the real
/// app/router.dart shape (`/add` primary, `/scan` reached only by pushing).
class _Harness {
  factory _Harness({
    required FakeCatalogRepository catalogRepository,
    FakeLogRepository? logRepository,
    Stream<BarcodeCapture>? barcodeStream,
  }) {
    final scanController = ScanController(
      repository: catalogRepository,
      barcodeStream: barcodeStream ?? const Stream<BarcodeCapture>.empty(),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.add,
      routes: [
        GoRoute(
          path: AppRoutes.add,
          builder: (context, state) => AddBeerScreen(
            catalogRepository: catalogRepository,
            logRepository: logRepository ?? FakeLogRepository(),
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
        GoRoute(
          path: AppRoutes.scan,
          // TickerMode(enabled: false) is scoped to just this route (not
          // the whole app, unlike scan_screen_test.dart's harness, which
          // has no LogFormSheet to worry about) -- ScanScreen checks it to
          // avoid calling the real camera plugin in tests, but disabling it
          // app-wide would also freeze LogFormSheet's own slide-in
          // animation, leaving it positioned off-screen and untappable.
          builder: (context, state) => TickerMode(
            enabled: false,
            child: ScanScreen(
              catalogRepository: catalogRepository,
              controllerOverride: scanController,
            ),
          ),
        ),
      ],
    );
    return _Harness._(router: router, scanController: scanController);
  }

  _Harness._({required this.router, required this.scanController});

  final GoRouter router;
  final ScanController scanController;

  Widget get app => AuthScope(
    controller: _signedInController(),
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Beer _beer(String id, String name) =>
    Beer(id: id, officialName: name, breweryId: 'brewery-1', verified: false);

void main() {
  testWidgets('the full catalog is shown -- both an already-tried and an '
      'untried beer are searchable and selectable (never Discover\'s '
      'untried-only restriction)', (tester) async {
    final repository = FakeCatalogRepository()
      ..triedBeerIds = {'tried-1'}
      ..beersByPage[1] = PagedResult(
        items: [
          _beer('tried-1', 'Tried Stout'),
          _beer('new-1', 'New Pale Ale'),
        ],
        page: 1,
        pageSize: 20,
        total: 2,
      );
    final harness = _Harness(catalogRepository: repository);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    expect(find.text('Tried Stout'), findsOneWidget);
    expect(find.text('New Pale Ale'), findsOneWidget);
    expect(
      repository.receivedUntriedOnly,
      isFalse,
      reason: 'Add Beer must request the full catalog, not untried-only',
    );
  });

  testWidgets(
    'a tried beer shows unlocked and an untried beer shows locked -- QA '
    'Round 1 Block 1 follow-up: this was previously inverted '
    '(isUnlocked: !item.isTried)',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..triedBeerIds = {'tried-1'}
        ..beersByPage[1] = PagedResult(
          items: [
            _beer('tried-1', 'Tried Stout'),
            _beer('new-1', 'New Pale Ale'),
          ],
          page: 1,
          pageSize: 20,
          total: 2,
        );
      final harness = _Harness(catalogRepository: repository);

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      // Only the untried beer's tile shows the lock badge.
      expect(find.byIcon(Icons.lock), findsOneWidget);
    },
  );

  testWidgets(
    'selecting a beer (tried or untried) opens the existing log form, and '
    'saving shows a confirmation',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..triedBeerIds = {'tried-1'}
        ..beersByPage[1] = PagedResult(
          items: [_beer('tried-1', 'Tried Stout')],
          page: 1,
          pageSize: 20,
          total: 1,
        );
      final harness = _Harness(catalogRepository: repository);

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tried Stout'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Log saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'saving a NEW log for a previously-untried beer immediately flips its '
    'tile to unlocked, without another search -- QA Round 1 Block 1 '
    'follow-up',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..beersByPage[1] = PagedResult(
          items: [_beer('new-1', 'New Pale Ale')],
          page: 1,
          pageSize: 20,
          total: 1,
        );
      final harness = _Harness(catalogRepository: repository);

      await tester.pumpWidget(harness.app);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsOneWidget);
      final callsBeforeSave = repository.callLog
          .where((c) => c.startsWith('getBeers'))
          .length;

      await tester.tap(find.text('New Pale Ale'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Log saved.'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsNothing);
      expect(
        repository.callLog.where((c) => c.startsWith('getBeers')).length,
        callsBeforeSave,
        reason: 'the tile updates in place -- no new search/reload call',
      );
    },
  );

  testWidgets('"Scan barcode" pushes the scanner, and a known beer (tried or '
      'untried) returned from it opens the same log form -- the scanner '
      'never auto-saves', (tester) async {
    final repository = FakeCatalogRepository()
      ..triedBeerIds = {'beer-1'}
      ..beersByBarcode['5000213007075'] = _beer('beer-1', 'Scanned Stout')
      ..beersByPage[1] = const PagedResult(
        items: [],
        page: 1,
        pageSize: 20,
        total: 0,
      );
    final barcodes = StreamController<BarcodeCapture>();
    final harness = _Harness(
      catalogRepository: repository,
      barcodeStream: barcodes.stream,
    );
    addTearDown(barcodes.close);

    await tester.pumpWidget(harness.app);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan barcode'));
    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsOneWidget);

    barcodes.add(
      const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
    );
    await tester.pumpAndSettle();

    // Back on Add Beer, the identified beer's log form is already open --
    // no intermediate confirmation/auto-save happened.
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Log saved.'), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Log saved.'), findsOneWidget);
  });
}
