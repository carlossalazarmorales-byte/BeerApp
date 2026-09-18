import '../../catalog/domain/models/beer.dart';

/// A plain state machine, not a stream/BLoC setup -- Scanner only ever needs
/// one active state at a time, driven by explicit method calls on
/// `ScanController`.
enum ScanStatus {
  /// The screen is mounted but not yet actively scanning: either the Scan
  /// tab isn't the visible branch yet, or the camera hasn't finished
  /// starting.
  starting,

  /// Camera permission was denied. On some platforms a fresh [start]
  /// attempt can re-trigger the OS prompt; on others (once denied, iOS in
  /// particular) it cannot, and system settings is the only way out --
  /// either way, manual search stays available.
  permissionDenied,

  /// Scanning isn't supported on this device (no usable camera).
  unsupported,

  /// The live camera viewfinder is showing and detecting barcodes.
  scanning,

  /// A barcode was decoded and its lookup is in flight.
  resolving,

  /// The barcode resolved to a matching beer. Transient -- the screen reacts
  /// by navigating to that beer's detail screen exactly once, then resets.
  found,

  /// The barcode was decoded but doesn't match any beer in the catalog --
  /// a normal outcome, not an error.
  notFound,

  /// The lookup failed for any other reason (network, backend, etc).
  error,
}

class ScanState {
  const ScanState({
    this.status = ScanStatus.starting,
    this.beer,
    this.error,
    this.lastDetectedCode,
  });

  final ScanStatus status;

  /// Only meaningful while [status] is [ScanStatus.found].
  final Beer? beer;

  /// Only meaningful while [status] is [ScanStatus.error].
  final Object? error;

  /// The most recently decoded barcode, used to debounce repeated
  /// detections of the same physical code.
  final String? lastDetectedCode;

  ScanState copyWith({
    ScanStatus? status,
    Beer? beer,
    Object? error,
    String? lastDetectedCode,
    bool clearBeer = false,
    bool clearError = false,
  }) {
    return ScanState(
      status: status ?? this.status,
      beer: clearBeer ? null : (beer ?? this.beer),
      error: clearError ? null : (error ?? this.error),
      lastDetectedCode: lastDetectedCode ?? this.lastDetectedCode,
    );
  }
}
