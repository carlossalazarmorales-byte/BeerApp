import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/network/api_exception.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/presentation/catalog_debug_log.dart';
import '../domain/scan_state.dart';

/// Drives the Scan screen's camera lifecycle, barcode detection and lookup.
///
/// Responsibilities are deliberately split into three separate methods
/// rather than one ambiguous "retry" call, so state mutation and native
/// camera control can never be accidentally conflated:
///  - [resetForScanning] only ever mutates [state] -- never touches the
///    camera.
///  - [startIfEligible] is the *only* method that ever calls
///    `MobileScannerController.start()`.
///  - [stopScanner] is the *only* method that ever calls
///    `MobileScannerController.stop()`.
///
/// The camera must never keep running behind the beer detail screen,
/// another tab, or a backgrounded app -- see [stopScanner] call sites in
/// `ScanScreen`, and the `_navigationInProgress` guard below, which ensures
/// one decoded barcode causes at most one navigation.
class ScanController extends ChangeNotifier {
  /// [barcodeStream] defaults to `cameraController.barcodes` -- overridable
  /// only so tests can feed synthetic [BarcodeCapture]s and exercise the
  /// debounce/resolve/navigation-guard logic without a real camera plugin
  /// (which needs platform channels `flutter_test` doesn't provide).
  ScanController({
    required this._repository,
    @visibleForTesting Stream<BarcodeCapture>? barcodeStream,
  }) {
    _subscription = (barcodeStream ?? cameraController.barcodes).listen(
      _onBarcodeCapture,
    );
  }

  final CatalogRepository _repository;

  /// EAN-13, EAN-8 and UPC-A only -- the formats Phase 11 actually
  /// supports. UPC-E is deliberately not enabled: it has no established
  /// unambiguous canonical mapping yet (see backend app/services/barcode.py
  /// and docs/DECISIONS.md). No QR/other formats -- there is no arbitrary
  /// code scanning use case for this feature.
  final MobileScannerController cameraController = MobileScannerController(
    autoStart: false,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
    ],
  );

  StreamSubscription<BarcodeCapture>? _subscription;

  ScanState _state = const ScanState();
  ScanState get state => _state;

  bool _disposed = false;
  bool _tabActive = false;
  bool _appResumed = true;

  /// Guards against a decoded barcode causing more than one navigation:
  /// duplicate frames, a second detection arriving while the camera is
  /// stopping, an async lookup racing with an already-in-flight one, or
  /// listener re-entry all no-op while this is true.
  bool _navigationInProgress = false;

  void _setState(ScanState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  /// Called by the screen when the Scan tab's `TickerMode` flips (i.e. it
  /// becomes, or stops being, the active bottom-nav branch).
  void setActive(bool active) {
    _tabActive = active;
  }

  /// Called by the screen on `AppLifecycleState` changes.
  void setAppResumed(bool resumed) {
    _appResumed = resumed;
  }

  /// Pure state mutation: clears any previous result and returns to
  /// [ScanStatus.scanning], which is what causes the screen to (re)mount
  /// the `MobileScanner` widget. Never touches the camera -- pair with a
  /// post-frame [startIfEligible] call (see `ScanScreen._activate`) so the
  /// widget is actually attached before `start()` is invoked.
  void resetForScanning() {
    _setState(
      _state.copyWith(
        status: ScanStatus.scanning,
        clearBeer: true,
        clearError: true,
      ),
    );
  }

  /// The only method that ever calls `cameraController.start()`. Checks
  /// eligibility first (not disposed, the Scan tab is actually active, the
  /// app is resumed, no navigation is currently in progress) and never
  /// starts the camera otherwise -- the next eligible lifecycle event
  /// retries. Widget attachment itself is handled by `mobile_scanner`
  /// (it waits briefly for the `MobileScanner` widget to attach, then
  /// throws `controllerNotAttached`), which this treats as a transient,
  /// silently-retried condition rather than a user-facing error.
  Future<void> startIfEligible() async {
    if (_disposed || !_tabActive || !_appResumed || _navigationInProgress) {
      return;
    }
    if (cameraController.value.isRunning) return;

    try {
      await cameraController.start();
    } on MobileScannerException catch (exception, stackTrace) {
      _handleStartFailure(exception.errorCode, exception, stackTrace);
      return;
    } catch (error, stackTrace) {
      // Any other failure (e.g. the platform plugin isn't available) must
      // still surface as a recoverable error state, never an uncaught
      // exception.
      if (_disposed) return;
      logCatalogError('ScanController.startIfEligible', error, stackTrace);
      _setState(_state.copyWith(status: ScanStatus.error, error: error));
      return;
    }
    if (_disposed) return;

    // A permission/unsupported/generic failure during start() does not
    // throw -- it's captured on the controller's own state instead.
    final error = cameraController.value.error;
    if (error != null) {
      _handleStartFailure(error.errorCode, error, StackTrace.current);
      return;
    }
  }

  void _handleStartFailure(
    MobileScannerErrorCode errorCode,
    Object error,
    StackTrace stackTrace,
  ) {
    switch (errorCode) {
      case MobileScannerErrorCode.controllerNotAttached:
      case MobileScannerErrorCode.controllerInitializing:
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.controllerDisposed:
        // Transient/no-op: never surfaced as a user-facing error. The next
        // eligible lifecycle event (tab re-activated, app resumed, "Try
        // camera again") retries.
        logCatalogError('ScanController.startIfEligible', error, stackTrace);
        return;
      case MobileScannerErrorCode.permissionDenied:
        _setState(_state.copyWith(status: ScanStatus.permissionDenied));
      case MobileScannerErrorCode.unsupported:
        _setState(_state.copyWith(status: ScanStatus.unsupported));
      case MobileScannerErrorCode.genericError:
      case MobileScannerErrorCode.controllerUninitialized:
        logCatalogError('ScanController.startIfEligible', error, stackTrace);
        _setState(_state.copyWith(status: ScanStatus.error, error: error));
    }
  }

  /// The only method that ever calls `cameraController.stop()`. Safe to
  /// call defensively/repeatedly -- `stop()` no-ops if already stopped.
  void stopScanner() {
    if (_disposed) return;
    unawaited(cameraController.stop());
  }

  void _onBarcodeCapture(BarcodeCapture capture) {
    if (_disposed || _navigationInProgress) return;
    if (_state.status == ScanStatus.resolving) return;

    final code = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (code == null || code.isEmpty) return;

    // Debounce: a terminal result for this exact code is already showing --
    // ignore repeated frames of the same physical barcode until the user
    // explicitly scans again.
    if ((_state.status == ScanStatus.notFound ||
            _state.status == ScanStatus.error) &&
        code == _state.lastDetectedCode) {
      return;
    }

    unawaited(_resolve(code));
  }

  Future<void> _resolve(String code) async {
    _setState(
      _state.copyWith(status: ScanStatus.resolving, lastDetectedCode: code),
    );
    try {
      final beer = await _repository.getBeerByBarcode(code);
      if (_disposed || _navigationInProgress) return;
      _navigationInProgress = true;
      stopScanner();
      _setState(_state.copyWith(status: ScanStatus.found, beer: beer));
    } on NotFoundApiException {
      if (_disposed) return;
      _setState(_state.copyWith(status: ScanStatus.notFound));
    } catch (error, stackTrace) {
      if (_disposed) return;
      logCatalogError('ScanController._resolve', error, stackTrace);
      _setState(_state.copyWith(status: ScanStatus.error, error: error));
    }
  }

  /// Called by the screen once it has returned from the beer detail
  /// screen it pushed after a [ScanStatus.found] result. Clears the
  /// navigation guard and resets to scanning -- the screen is responsible
  /// for then calling [startIfEligible] (via its usual post-frame
  /// activation sequence), only if the tab is still active and the app is
  /// still resumed.
  void onReturnedFromDetail() {
    _navigationInProgress = false;
    resetForScanning();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    // `MobileScannerController.dispose()` is async, but `ChangeNotifier`'s
    // (and therefore `State`'s) dispose() is synchronous and cannot await
    // it. Its synchronous cleanup (marking itself disposed, closing its
    // internal barcode stream) happens immediately on this call regardless
    // of whether the returned future is awaited; the remaining native
    // platform teardown is safe to let finish in the background. `stop()`
    // is chained first (not raced independently) so native resources are
    // released in the correct order. Errors are swallowed (logged, not
    // rethrown) -- this is fire-and-forget teardown with nothing left to
    // report a failure to, including the legitimate case of disposing a
    // controller that was never successfully started.
    unawaited(
      cameraController
          .stop()
          .then((_) => cameraController.dispose())
          .catchError((Object error, StackTrace stackTrace) {
            logCatalogError('ScanController.dispose', error, stackTrace);
          }),
    );
    super.dispose();
  }
}
