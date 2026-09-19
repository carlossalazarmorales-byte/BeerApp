import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../../catalog/domain/models/country.dart';
import '../domain/contribution_repository.dart';
import '../domain/models/contribution_input.dart';
import '../domain/models/contribution_summary.dart';
import '../domain/models/duplicate_candidates.dart';
import 'contribution_debug_log.dart';
import 'contribution_error_text.dart';
import 'suggest_flow.dart';

/// Drives the suggest-a-brewery form. Same lifecycle and guarantees as
/// `SuggestBeerController` (server-confirmed, never optimistic, never
/// touches the catalog); the only hard block here is the user's own
/// identical pending suggestion.
class SuggestBreweryController extends ChangeNotifier {
  SuggestBreweryController({
    required this._contributions,
    required this._catalog,
  });

  final ContributionRepository _contributions;
  final CatalogRepository _catalog;

  List<Country> countryOptions = [];
  bool isLoadingOptions = false;
  Object? optionsError;

  SuggestPhase phase = SuggestPhase.editing;
  Object? error;
  SuggestBlock? block;
  BreweryDuplicateCandidates? candidates;
  ContributionSummary? submitted;

  BreweryContributionInput? _pendingInput;
  bool _disposed = false;

  bool get isBusy =>
      phase == SuggestPhase.checking || phase == SuggestPhase.submitting;

  Future<void> loadOptions() async {
    isLoadingOptions = true;
    optionsError = null;
    _notify();
    try {
      countryOptions = await _catalog.getCountries();
    } catch (e, st) {
      optionsError = e;
      logContributionError('SuggestBreweryController.loadOptions', e, st);
    } finally {
      isLoadingOptions = false;
      _notify();
    }
  }

  Future<void> submit(BreweryContributionInput input) async {
    if (isBusy || phase == SuggestPhase.submitted) return;
    _clearFeedback();
    phase = SuggestPhase.checking;
    _notify();

    final BreweryDuplicateCandidates result;
    try {
      result = await _contributions.checkBreweryDuplicates(input);
    } catch (e, st) {
      error = e;
      phase = SuggestPhase.editing;
      logContributionError('SuggestBreweryController.submit(check)', e, st);
      _notify();
      return;
    }

    if (result.hasBlocking) {
      block = SuggestBlock.alreadySubmitted;
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

  Future<void> confirmSubmit() async {
    final input = _pendingInput;
    if (phase != SuggestPhase.awaitingConfirmation || input == null) return;
    _pendingInput = null;
    await _post(input);
  }

  void reviewAgain() {
    if (phase != SuggestPhase.awaitingConfirmation) return;
    _pendingInput = null;
    candidates = null;
    phase = SuggestPhase.editing;
    _notify();
  }

  Future<void> _post(BreweryContributionInput input) async {
    phase = SuggestPhase.submitting;
    _notify();
    try {
      submitted = await _contributions.submitBrewery(input);
      candidates = null;
      phase = SuggestPhase.submitted;
    } on ConflictApiException catch (e, st) {
      if (e.code == alreadySubmittedCode) {
        block = SuggestBlock.alreadySubmitted;
      } else {
        error = e;
        logContributionError('SuggestBreweryController._post', e, st);
      }
      candidates = null;
      phase = SuggestPhase.editing;
    } catch (e, st) {
      error = e;
      candidates = null;
      phase = SuggestPhase.editing;
      logContributionError('SuggestBreweryController._post', e, st);
    }
    _notify();
  }

  void clearFeedback() {
    if (error == null && block == null) return;
    _clearFeedback();
    _notify();
  }

  void _clearFeedback() {
    error = null;
    block = null;
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
