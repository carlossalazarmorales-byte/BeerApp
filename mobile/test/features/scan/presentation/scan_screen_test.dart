import 'dart:async';

import 'package:beerapp/app/app_routes.dart';
import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/scan/presentation/scan_controller.dart';
import 'package:beerapp/features/scan/presentation/scan_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../fakes/fake_catalog_repository.dart';

const _beer = Beer(
  id: 'beer-1',
  officialName: 'Test Stout',
  breweryId: 'brewery-1',
  verified: true,
  barcode: '5000213007075',
);

class _PopCountingObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

/// Builds a minimal router with just the routes ScanScreen actually
/// navigates between, so `context.push`/`context.pop` inside it exercise
/// the real go_router integration rather than a reimplementation of it.
/// `/scan` is reached only by pushing (see `AppRoutes.scan`'s doc comment)
/// -- `initialLocation` is a placeholder "Add Beer" stand-in so there is
/// always something for `context.pop()` to return to, exactly like the
/// real Add Beer screen.
class _Harness {
  factory _Harness({
    FakeCatalogRepository? repository,
    Stream<BarcodeCapture>? barcodeStream,
  }) {
    final catalogRepository = repository ?? FakeCatalogRepository();
    final controller = ScanController(
      repository: catalogRepository,
      barcodeStream: barcodeStream ?? const Stream<BarcodeCapture>.empty(),
    );
    final popObserver = _PopCountingObserver();
    final router = GoRouter(
      initialLocation: '/add-placeholder',
      observers: [popObserver],
      routes: [
        GoRoute(
          path: '/add-placeholder',
          builder: (context, state) => const Scaffold(body: Text('Add screen')),
        ),
        GoRoute(
          path: AppRoutes.scan,
          builder: (context, state) => ScanScreen(
            catalogRepository: catalogRepository,
            controllerOverride: controller,
          ),
        ),
        GoRoute(
          path: AppRoutes.beerDetail,
          builder: (context, state) => Scaffold(
            body: Text('Beer detail: ${state.pathParameters['beerId']}'),
          ),
        ),
        GoRoute(
          path: AppRoutes.suggestBeer,
          builder: (context, state) => Scaffold(
            body: Text(
              'Suggest form barcode=${state.uri.queryParameters['barcode']}',
            ),
          ),
        ),
      ],
    );
    return _Harness._(
      controller: controller,
      router: router,
      popObserver: popObserver,
    );
  }

  _Harness._({
    required this.controller,
    required this.router,
    required this.popObserver,
  });

  final ScanController controller;
  final GoRouter router;
  final _PopCountingObserver popObserver;

  // TickerMode(enabled: false) keeps ScanScreen's own automatic
  // activate-the-real-camera attempt (see `didChangeDependencies`) from
  // ever calling `MobileScannerController.start()` in these tests -- that
  // would race against the deliberately-injected barcode stream events
  // below via platform channels `flutter_test` doesn't provide. The
  // barcode-stream/debounce/navigation logic under test doesn't depend on
  // tab-active state at all, only the real camera start/stop calls do.
  Widget get app => TickerMode(
    enabled: false,
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );

  /// Pushes `/scan` the way AddBeerScreen does (`context.push<Beer>`),
  /// returning the future that resolves with whatever `/scan` eventually
  /// pops with. Deliberately NOT `async`/awaiting anything itself -- an
  /// `async` function that `return`s a `Future` chains onto it, so this
  /// call wouldn't return until `/scan` actually pops. Callers pump
  /// separately, then await the returned future whenever (if ever) they
  /// care about its result.
  Future<Beer?> pushScan() => router.push<Beer?>(AppRoutes.scan);
}

void main() {
  testWidgets('not-found state shows the fallback message and both actions', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..getBeerByBarcodeError = const NotFoundApiException(
        message: 'not found',
        statusCode: 404,
      );
    final barcodes = StreamController<BarcodeCapture>();
    final harness = _Harness(
      repository: repository,
      barcodeStream: barcodes.stream,
    );
    addTearDown(barcodes.close);

    await tester.pumpWidget(harness.app);
    unawaited(harness.pushScan());
    await tester.pumpAndSettle();

    barcodes.add(
      const BarcodeCapture(barcodes: [Barcode(rawValue: '0000000000000')]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("We couldn't find a beer with that barcode in our catalog."),
      findsOneWidget,
    );
    expect(find.text('Scan again'), findsOneWidget);
    expect(find.text('Search manually'), findsOneWidget);
  });

  testWidgets('error state shows a retry and manual-search action', (
    tester,
  ) async {
    final repository = FakeCatalogRepository()
      ..getBeerByBarcodeError = const NetworkApiException(message: 'offline');
    final barcodes = StreamController<BarcodeCapture>();
    final harness = _Harness(
      repository: repository,
      barcodeStream: barcodes.stream,
    );
    addTearDown(barcodes.close);

    await tester.pumpWidget(harness.app);
    unawaited(harness.pushScan());
    await tester.pumpAndSettle();

    barcodes.add(
      const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Check your internet connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Scan again'), findsOneWidget);
    expect(find.text('Search manually'), findsOneWidget);
  });

  testWidgets(
    '"Search manually" pops back to the caller (Add Beer) with no beer, '
    'from the not-found state',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..getBeerByBarcodeError = const NotFoundApiException(
          message: 'not found',
          statusCode: 404,
        );
      final barcodes = StreamController<BarcodeCapture>();
      final harness = _Harness(
        repository: repository,
        barcodeStream: barcodes.stream,
      );
      addTearDown(barcodes.close);

      await tester.pumpWidget(harness.app);
      final resultFuture = harness.pushScan();
      await tester.pumpAndSettle();

      barcodes.add(
        const BarcodeCapture(barcodes: [Barcode(rawValue: '0000000000000')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search manually'));
      await tester.pumpAndSettle();

      expect(find.text('Add screen'), findsOneWidget);
      expect(await resultFuture, isNull);
    },
  );

  testWidgets(
    'the not-found state offers "Suggest this beer" prefilled with the '
    'scanned code, alongside the existing actions',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..getBeerByBarcodeError = const NotFoundApiException(
          message: 'not found',
          statusCode: 404,
        );
      final barcodes = StreamController<BarcodeCapture>();
      final harness = _Harness(
        repository: repository,
        barcodeStream: barcodes.stream,
      );
      addTearDown(barcodes.close);

      await tester.pumpWidget(harness.app);
      unawaited(harness.pushScan());
      await tester.pumpAndSettle();
      barcodes.add(
        const BarcodeCapture(barcodes: [Barcode(rawValue: '036000291452')]),
      );
      await tester.pumpAndSettle();

      // Manual search stays the primary path; the new action is additional.
      expect(find.text('Scan again'), findsOneWidget);
      expect(find.text('Search manually'), findsOneWidget);
      expect(find.text('Suggest this beer'), findsOneWidget);

      await tester.tap(find.text('Suggest this beer'));
      await tester.pumpAndSettle();

      expect(find.text('Suggest form barcode=036000291452'), findsOneWidget);
    },
  );

  testWidgets('"Suggest this beer" is not offered for a network error or a '
      'permission problem', (tester) async {
    final repository = FakeCatalogRepository()
      ..getBeerByBarcodeError = const NetworkApiException(message: 'offline');
    final barcodes = StreamController<BarcodeCapture>();
    final harness = _Harness(
      repository: repository,
      barcodeStream: barcodes.stream,
    );
    addTearDown(barcodes.close);

    await tester.pumpWidget(harness.app);
    unawaited(harness.pushScan());
    await tester.pumpAndSettle();
    barcodes.add(
      const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
    );
    await tester.pumpAndSettle();

    // "Not found" is the only outcome that means the beer may be missing.
    expect(find.text('Suggest this beer'), findsNothing);
  });

  testWidgets(
    'a found beer pops back to the caller with exactly one result, even if '
    'detected twice',
    (tester) async {
      final repository = FakeCatalogRepository()
        ..beersByBarcode['5000213007075'] = _beer;
      final barcodes = StreamController<BarcodeCapture>();
      final harness = _Harness(
        repository: repository,
        barcodeStream: barcodes.stream,
      );
      addTearDown(barcodes.close);

      await tester.pumpWidget(harness.app);
      final resultFuture = harness.pushScan();
      await tester.pumpAndSettle();
      final popsBeforeDetection = harness.popObserver.popCount;

      barcodes
        ..add(
          const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
        )
        ..add(
          const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
        );
      await tester.pumpAndSettle();

      final result = await resultFuture;
      expect(result?.id, 'beer-1');
      expect(find.text('Add screen'), findsOneWidget);
      expect(
        harness.popObserver.popCount - popsBeforeDetection,
        1,
        reason: 'two detections of the same barcode must pop exactly once',
      );
    },
  );
}
