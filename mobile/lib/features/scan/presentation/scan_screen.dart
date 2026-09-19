import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/beer.dart';
import '../../catalog/presentation/catalog_error_text.dart';
import '../domain/scan_state.dart';
import 'scan_controller.dart';

/// Camera barcode scanning -- a secondary, optional shortcut into the same
/// [BeerDetailScreen] manual search already reaches. Never a parallel
/// logging system: a successful scan only ever navigates to that beer's
/// existing detail screen (see app/router.dart's `beerDetail` route); it
/// never creates a beer, a log, or a contribution.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.catalogRepository,
    @visibleForTesting this.controllerOverride,
    super.key,
  });

  final CatalogRepository catalogRepository;

  /// Lets widget tests supply a [ScanController] built with an injected
  /// barcode stream (see `ScanController`'s own `barcodeStream` parameter),
  /// so the not-found/error/found UI states can be driven deterministically
  /// without a real camera plugin. Never set outside tests.
  final ScanController? controllerOverride;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final ScanController _controller =
      widget.controllerOverride ??
      ScanController(repository: widget.catalogRepository);

  bool _activationScheduled = false;
  bool _handlingFound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `StatefulShellRoute.indexedStack` keeps every bottom-nav branch's
    // navigator mounted, so this screen's initState/dispose don't fire on
    // ordinary tab switches -- `TickerMode` is the signal go_router flips
    // for the active vs. inactive branch, and the correct place to react to
    // it is here, not initState.
    final active = TickerMode.valuesOf(context).enabled;
    _controller.setActive(active);
    if (active) {
      _activate();
    } else {
      _controller.stopScanner();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _controller.setAppResumed(false);
        _controller.stopScanner();
      case AppLifecycleState.resumed:
        _controller.setAppResumed(true);
        _activate();
    }
  }

  /// The single orchestration point for "(re)start scanning": mounts the
  /// `MobileScanner` widget first (via [ScanController.resetForScanning],
  /// pure state -- no camera call), then schedules the actual
  /// `start()` for the *next* frame, once that widget is guaranteed to be
  /// attached. Used for the initial activation, returning from a stopped
  /// state, and every "Try camera again"/"Scan again" tap.
  void _activate() {
    if (_activationScheduled) return;
    _activationScheduled = true;
    _controller.resetForScanning();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activationScheduled = false;
      _controller.startIfEligible();
    });
  }

  // Purely for the found-navigation side effect -- rebuilding the visible
  // UI on every controller change is handled separately by `build()`'s own
  // `ListenableBuilder`, not from here.
  void _onControllerChanged() {
    final state = _controller.state;
    if (state.status != ScanStatus.found || _handlingFound) return;
    final beer = state.beer;
    if (beer == null) return;
    _handlingFound = true;
    unawaited(_handleFound(beer));
  }

  Future<void> _handleFound(Beer beer) async {
    // The camera is already stopped by the controller before it set
    // `status = found` -- it stays stopped for this entire push, including
    // while this screen is backgrounded behind BeerDetail.
    await context.push(AppRoutes.beerDetailPath(beer.id));
    if (!mounted) return;
    _controller.onReturnedFromDetail();
    _handlingFound = false;
    // Only resume the camera if this tab is genuinely still the visible,
    // active one -- returning from BeerDetail can land back on any tab if
    // the user navigated elsewhere in between.
    if (TickerMode.valuesOf(context).enabled) {
      _activate();
    }
  }

  void _goToDiscover() {
    // A single-route branch, so this resolves straight to the Discover tab
    // like `navigationShell.goBranch` would -- the normal manual-search
    // screen, which must always stay reachable from here.
    context.go(AppRoutes.discover);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).navScan)),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _controller.state;

    switch (state.status) {
      case ScanStatus.starting:
      case ScanStatus.resolving:
      case ScanStatus.found:
        return const LoadingState();

      case ScanStatus.permissionDenied:
        return ErrorState(
          message: l10n.scanPermissionDeniedMessage,
          retryLabel: l10n.scanTryCameraAgainAction,
          onRetry: _activate,
          secondaryLabel: l10n.scanSearchManuallyAction,
          onSecondaryAction: _goToDiscover,
        );

      case ScanStatus.unsupported:
        return ErrorState(
          message: l10n.scanUnsupportedMessage,
          secondaryLabel: l10n.scanSearchManuallyAction,
          onSecondaryAction: _goToDiscover,
        );

      case ScanStatus.notFound:
        final scannedCode = state.lastDetectedCode;
        return ErrorState(
          message: l10n.scanNotFoundMessage,
          retryLabel: l10n.scanAgainAction,
          onRetry: _activate,
          secondaryLabel: l10n.scanSearchManuallyAction,
          onSecondaryAction: _goToDiscover,
          // Manual search stays the primary path; this only opens the
          // suggest-a-beer form prefilled with the scanned code. It adds
          // nothing to the catalog by itself.
          tertiaryLabel: l10n.contributionSuggestThisBeerAction,
          onTertiaryAction: scannedCode == null
              ? null
              : () => context.push(
                  AppRoutes.suggestBeerPath(barcode: scannedCode),
                ),
        );

      case ScanStatus.error:
        return ErrorState(
          message: catalogErrorText(context, state.error!),
          retryLabel: l10n.scanAgainAction,
          onRetry: _activate,
          secondaryLabel: l10n.scanSearchManuallyAction,
          onSecondaryAction: _goToDiscover,
        );

      case ScanStatus.scanning:
        return MobileScanner(controller: _controller.cameraController);
    }
  }
}
