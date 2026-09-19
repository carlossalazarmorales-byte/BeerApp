import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../catalog/domain/catalog_filter_options.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/beer.dart';
import '../../catalog/domain/models/beer_style.dart';
import '../../catalog/domain/models/brewery.dart';
import '../domain/contribution_repository.dart';
import '../domain/models/contribution_input.dart';
import '../domain/models/contribution_summary.dart';
import '../domain/models/duplicate_candidates.dart';
import 'contribution_debug_log.dart';
import 'contribution_error_text.dart';
import 'suggest_flow.dart';

/// Drives the suggest-a-beer form: loading the brewery/style pickers, the
/// duplicate check, and the submit.
///
/// Submission is always server-confirmed -- [phase] only becomes
/// [SuggestPhase.submitted] once the backend has stored the suggestion as
/// pending review. Nothing here is optimistic, and nothing touches the
/// catalog, a beer log, a favorite, a wishlist entry or an achievement.
class SuggestBeerController extends ChangeNotifier {
  SuggestBeerController({required this._contributions, required this._catalog});

  final ContributionRepository _contributions;
  final CatalogRepository _catalog;

  // -- picker options ---------------------------------------------------
  List<Brewery> breweryOptions = [];
  List<BeerStyle> styleOptions = [];
  bool isLoadingOptions = false;
  Object? optionsError;

  // -- flow state ---------------------------------------------------------
  SuggestPhase phase = SuggestPhase.editing;

  /// The last check/submit failure that is not a hard block; cleared on the
  /// next attempt.
  Object? error;

  SuggestBlock? block;

  /// The catalog beer that owns the entered barcode, when known -- lets the
  /// UI offer "View existing beer".
  Beer? existingBeer;

  /// The non-blocking warnings, while [phase] is
  /// [SuggestPhase.awaitingConfirmation].
  BeerDuplicateCandidates? candidates;

  ContributionSummary? submitted;

  BeerContributionInput? _pendingInput;
  bool _disposed = false;

  bool get isBusy =>
      phase == SuggestPhase.checking || phase == SuggestPhase.submitting;

  Future<void> loadOptions() async {
    isLoadingOptions = true;
    optionsError = null;
    _notify();
    try {
      final results = await Future.wait([
        loadBreweryFilterOptions(_catalog),
        _catalog.getBeerStyles(),
      ]);
      breweryOptions = results[0] as List<Brewery>;
      styleOptions = results[1] as List<BeerStyle>;
    } catch (e, st) {
      optionsError = e;
      logContributionError('SuggestBeerController.loadOptions', e, st);
    } finally {
      isLoadingOptions = false;
      _notify();
    }
  }

  /// Step 1 of a submit: run the duplicate check, then either stop at a hard
  /// block, pause for the user's confirmation on a warning, or go straight
  /// to the submit.
  Future<void> submit(BeerContributionInput input) async {
    if (isBusy || phase == SuggestPhase.submitted) return;
    _clearFeedback();
    phase = SuggestPhase.checking;
    _notify();

    final BeerDuplicateCandidates result;
    try {
      result = await _contributions.checkBeerDuplicates(input);
    } catch (e, st) {
      error = e;
      phase = SuggestPhase.editing;
      logContributionError('SuggestBeerController.submit(check)', e, st);
      _notify();
      return;
    }

    if (result.hasBlocking) {
      existingBeer = result.barcodeMatch;
      block = result.barcodeMatch != null
          ? SuggestBlock.barcodeInCatalog
          : SuggestBlock.alreadySubmitted;
      phase = SuggestPhase.editing;
      _notify();
      return;
    }

    if (result.hasWarnings) {
      candidates = result;
      _pendingInput = input;
      phase = SuggestPhase.awaitingConfirmation;
      _notify();
      return;
    }

    await _post(input);
  }

  /// The user chose "Submit anyway" on the warning sheet.
  Future<void> confirmSubmit() async {
    final input = _pendingInput;
    if (phase != SuggestPhase.awaitingConfirmation || input == null) return;
    _pendingInput = null;
    await _post(input);
  }

  /// The user chose "Review" on the warning sheet: back to editing.
  void reviewAgain() {
    if (phase != SuggestPhase.awaitingConfirmation) return;
    _pendingInput = null;
    candidates = null;
    phase = SuggestPhase.editing;
    _notify();
  }

  Future<void> _post(BeerContributionInput input) async {
    phase = SuggestPhase.submitting;
    _notify();
    try {
      submitted = await _contributions.submitBeer(input);
      candidates = null;
      phase = SuggestPhase.submitted;
    } on ConflictApiException catch (e, st) {
      // The check passed but the state changed underneath it (or the check
      // was skipped): the POST is the authority, so honor its hard blocks.
      if (e.code == barcodeInCatalogCode) {
        block = SuggestBlock.barcodeInCatalog;
        existingBeer = await _resolveBarcodeOwner(input.barcode);
      } else if (e.code == alreadySubmittedCode) {
        block = SuggestBlock.alreadySubmitted;
      } else {
        error = e;
        logContributionError('SuggestBeerController._post', e, st);
      }
      candidates = null;
      phase = SuggestPhase.editing;
    } catch (e, st) {
      error = e;
      candidates = null;
      phase = SuggestPhase.editing;
      logContributionError('SuggestBeerController._post', e, st);
    }
    _notify();
  }

  /// Best effort: only used to offer "View existing beer" after a raced
  /// `barcode_in_catalog` 409. Failure just means no shortcut is offered.
  Future<Beer?> _resolveBarcodeOwner(String? barcode) async {
    if (barcode == null) return null;
    try {
      return await _catalog.getBeerByBarcode(barcode);
    } catch (_) {
      return null;
    }
  }

  /// Called when the user edits the form again, so a stale block/error
  /// doesn't linger next to changed input.
  void clearFeedback() {
    if (error == null && block == null) return;
    _clearFeedback();
    _notify();
  }

  void _clearFeedback() {
    error = null;
    block = null;
    existingBeer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
