/// Where a suggest-a-beer / suggest-a-brewery form is in its lifecycle.
/// Shared by both form controllers so the screens read identically.
enum SuggestPhase {
  /// The user is editing (also the state after any failure or block).
  editing,

  /// The duplicate check is in flight.
  checking,

  /// The check found only non-blocking warnings; the UI asks "Submit anyway?".
  awaitingConfirmation,

  /// The submit request is in flight.
  submitting,

  /// The backend confirmed the suggestion is stored as pending review. Only
  /// this phase may be described as "received" -- never as "added".
  submitted,
}

/// A hard block: the suggestion cannot be submitted as entered.
enum SuggestBlock {
  /// A catalog beer already owns this barcode.
  barcodeInCatalog,

  /// The user already has an identical suggestion pending review.
  alreadySubmitted,
}
