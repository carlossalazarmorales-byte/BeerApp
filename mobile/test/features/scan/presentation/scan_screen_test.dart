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

class _PushCountingObserver extends NavigatorObserver {
  int pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}

/// Builds a minimal router with just the routes ScanScreen actually
/// navigates between, so `context.push`/`context.go` inside it exercise the
/// real go_router integration rather than a reimplementation of it.
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
    final pushObserver = _PushCountingObserver();
    final router = GoRouter(
      initialLocation: '/scan',
      observers: [pushObserver],
      routes: [
        GoRoute(
          path: '/scan',
          builder: (context, state) => ScanScreen(
            catalogRepository: catalogRepository,
            controllerOverride: controller,
          ),
        ),
        GoRoute(
          path: AppRoutes.discover,
          builder: (context, state) =>
              const Scaffold(body: Text('Discover screen')),
        ),
        GoRoute(
          path: AppRoutes.beerDetail,
          builder: (context, state) => Scaffold(
            body: Text('Beer detail: ${state.pathParameters['beerId']}'),
          ),
        ),
      ],
    );
    return _Harness._(
      controller: controller,
      router: router,
      pushObserver: pushObserver,
    );
  }

  _Harness._({
    required this.controller,
    required this.router,
    required this.pushObserver,
  });

  final ScanController controller;
  final GoRouter router;
  final _PushCountingObserver pushObserver;

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
    await tester.pump();

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
    await tester.pump();

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
    '"Search manually" navigates to the Discover screen from the not-found state',
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
      await tester.pump();

      barcodes.add(
        const BarcodeCapture(barcodes: [Barcode(rawValue: '0000000000000')]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search manually'));
      await tester.pumpAndSettle();

      expect(find.text('Discover screen'), findsOneWidget);
    },
  );

  testWidgets(
    'a found beer triggers exactly one navigation push, even if detected twice',
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
      await tester.pump();
      // The initial route build itself already counts as one push --
      // baseline from here so the assertion below is unambiguous about
      // what it's actually counting.
      final pushesBeforeDetection = harness.pushObserver.pushCount;

      barcodes
        ..add(
          const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
        )
        ..add(
          const BarcodeCapture(barcodes: [Barcode(rawValue: '5000213007075')]),
        );
      await tester.pumpAndSettle();

      expect(find.text('Beer detail: beer-1'), findsOneWidget);
      expect(
        harness.pushObserver.pushCount - pushesBeforeDetection,
        1,
        reason: 'two detections of the same barcode must push exactly once',
      );
    },
  );
}
