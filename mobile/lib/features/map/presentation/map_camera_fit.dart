/// Pure decision logic for whether `MapScreen` should recompute and record
/// a camera fit for the map's current search/mode state. Extracted so the
/// loading/error/signature-dedup eligibility check -- the source of a
/// stale-camera-fit race -- can be unit tested without a native MapLibre
/// view.
library;

/// Decides whether a camera fit should happen right now for [signature],
/// and what to record as the new "already fitted" signature if so.
///
/// Returns `null` when no fit should happen:
/// - while [isLoading] is `true` -- a request is in flight, so whatever
///   marker data the caller currently holds is the *previous* result, not
///   the one [signature] describes yet. Fitting here (and, critically,
///   recording [signature] as already-fitted here) is exactly the bug this
///   guards against: a loading-start notification would consume the
///   signature against stale data, and the later notification carrying the
///   real filtered result would then be silently skipped as a duplicate.
/// - when [error] is non-null -- a failed load has nothing valid to fit to.
/// - when [searchActive] is `false`, or [signature] is already
///   [lastFitSignature] -- nothing changed since the last fit.
///
/// Only a completed, successful load for a genuinely new [signature] is
/// eligible, and the caller must record the returned signature even if the
/// eventual point set turns out empty -- an empty *result* is still a
/// completed search, and a later refresh of that same search (e.g. from
/// `CollectionRefreshSignal`) must not re-trigger a fit the user didn't
/// just ask for.
String? cameraFitSignatureToRecord({
  required bool isLoading,
  required Object? error,
  required bool searchActive,
  required String signature,
  required String? lastFitSignature,
}) {
  if (isLoading || error != null) return null;
  if (!searchActive || signature == lastFitSignature) return null;
  return signature;
}
