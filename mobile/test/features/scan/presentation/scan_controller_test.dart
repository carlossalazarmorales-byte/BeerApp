import 'dart:async';

import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/scan/domain/scan_state.dart';
import 'package:beerapp/features/scan/presentation/scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../fakes/fake_catalog_repository.dart';

const _beer = Beer(
  id: 'beer-1',
  officialName: 'Test Stout',
  breweryId: 'brewery-1',
  verified: true,
  barcode: '5000213007075',
);

/// Everything here drives detection through an injected barcode stream
/// (see `ScanController`'s `barcodeStream` constructor parameter) rather
/// than the real camera plugin, which needs platform channels `flutter_test`
/// doesn't provide -- this proves the pure state-machine/debounce/guard
/// logic, not native camera behavior.
void main() {
  late FakeCatalogRepository repository;
  late StreamController<BarcodeCapture> barcodes;
  late ScanController controller;

  setUp(() {
    repository = FakeCatalogRepository()
      ..beersByBarcode['5000213007075'] = _beer;
    barcodes = StreamController<BarcodeCapture>();
    controller = ScanController(
      repository: repository,
      barcodeStream: barcodes.stream,
    );
  });

  tearDown(() async {
    // Not unconditionally disposing `controller` here -- one test below
    // deliberately disposes it itself to verify post-dispose behavior, and
    // `ChangeNotifier.dispose()` asserts against being called twice.
    await barcodes.close();
  });

  void detect(String? code) {
    barcodes.add(
      BarcodeCapture(barcodes: [if (code != null) Barcode(rawValue: code)]),
    );
  }

  test(
    'a successful lookup transitions to found with the resolved beer',
    () async {
      detect('5000213007075');
      await pumpEventQueue();

      expect(controller.state.status, ScanStatus.found);
      expect(controller.state.beer, _beer);
      expect(repository.callLog, ['getBeerByBarcode:5000213007075']);
    },
  );

  test('an unknown barcode transitions to notFound, not error', () async {
    repository.getBeerByBarcodeError = const NotFoundApiException(
      message: 'not found',
      statusCode: 404,
    );

    detect('0000000000000');
    await pumpEventQueue();

    expect(controller.state.status, ScanStatus.notFound);
  });

  test('a network failure transitions to error', () async {
    repository.getBeerByBarcodeError = const NetworkApiException(
      message: 'offline',
    );

    detect('5000213007075');
    await pumpEventQueue();

    expect(controller.state.status, ScanStatus.error);
    expect(controller.state.error, isA<NetworkApiException>());
  });

  test('a second detection while the first is still resolving triggers only one lookup', () async {
    repository.extraDelayByCallKey['getBeerByBarcode:5000213007075'] =
        const Duration(milliseconds: 20);

    detect('5000213007075');
    detect('5000213007075');
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await pumpEventQueue();

    expect(
      repository.callLog.where((c) => c.startsWith('getBeerByBarcode')),
      hasLength(1),
    );
    expect(controller.state.status, ScanStatus.found);
  });

  test(
    'a duplicate of an already-shown notFound code is ignored until reset',
    () async {
      repository.getBeerByBarcodeError = const NotFoundApiException(
        message: 'not found',
        statusCode: 404,
      );

      detect('5000213007075');
      await pumpEventQueue();
      expect(controller.state.status, ScanStatus.notFound);

      detect('5000213007075');
      await pumpEventQueue();

      expect(
        repository.callLog.where((c) => c.startsWith('getBeerByBarcode')),
        hasLength(1),
        reason: 'the repeated code must not trigger a second lookup',
      );
    },
  );

  test('a barcode with no usable value is ignored', () async {
    detect(null);
    await pumpEventQueue();

    expect(controller.state.status, isNot(ScanStatus.resolving));
    expect(repository.callLog, isEmpty);
  });

  test(
    'resetForScanning clears the previous result and returns to scanning',
    () async {
      detect('5000213007075');
      await pumpEventQueue();
      expect(controller.state.status, ScanStatus.found);

      controller.resetForScanning();

      expect(controller.state.status, ScanStatus.scanning);
      expect(controller.state.beer, isNull);
    },
  );

  test(
    'a detection arriving while a navigation is already in progress is ignored',
    () async {
      detect('5000213007075');
      await pumpEventQueue();
      expect(controller.state.status, ScanStatus.found);

      // The controller stays in `found` (navigation pending, the screen
      // about to pop with this result) -- a stray extra detection here must
      // not trigger a second lookup/state change.
      detect('5000213007075');
      await pumpEventQueue();

      expect(controller.state.status, ScanStatus.found);
      expect(
        repository.callLog.where((c) => c.startsWith('getBeerByBarcode')),
        hasLength(1),
      );
    },
  );

  test('startIfEligible does nothing while the tab is not active', () async {
    // setActive(true) is never called -- the default/inactive state.
    await controller.startIfEligible();

    expect(controller.state.status, ScanStatus.starting);
  });

  test('a barcode event that arrives after dispose is ignored, not thrown or notified', () async {
    var notified = false;
    controller.addListener(() => notified = true);

    controller.dispose();
    detect('5000213007075');
    await pumpEventQueue();

    expect(notified, isFalse);
  });
}
