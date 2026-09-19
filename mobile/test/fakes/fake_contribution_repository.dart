import 'dart:async';

import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/contributions/domain/contribution_repository.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_input.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
import 'package:beerapp/features/contributions/domain/models/duplicate_candidates.dart';

const BeerDuplicateCandidates noBeerDuplicates = BeerDuplicateCandidates(
  barcodeMatch: null,
  nameMatches: [],
  breweryMatches: [],
  alreadySubmitted: false,
  pendingBarcodeDuplicateExists: false,
);

const BreweryDuplicateCandidates noBreweryDuplicates =
    BreweryDuplicateCandidates(nameMatches: [], alreadySubmitted: false);

/// In-memory `ContributionRepository`. A successful submit is stored as
/// `pending` and shows up in [history] (newest first), like the real
/// backend, so a screen's post-submit reload reflects it without plumbing.
class FakeContributionRepository implements ContributionRepository {
  FakeContributionRepository({this.delay = Duration.zero});

  final Duration delay;

  /// Newest first, exactly as `GET /contributions` returns it.
  final List<ContributionSummary> history = [];

  BeerDuplicateCandidates beerCandidates = noBeerDuplicates;
  BreweryDuplicateCandidates breweryCandidates = noBreweryDuplicates;

  Object? getHistoryError;
  Object? submitBeerError;
  Object? submitBreweryError;
  Object? checkBeerError;
  Object? checkBreweryError;

  final List<BeerContributionInput> submittedBeers = [];
  final List<BreweryContributionInput> submittedBreweries = [];
  final List<BeerContributionInput> checkedBeers = [];
  final List<BreweryContributionInput> checkedBreweries = [];

  /// e.g. `getHistory:1`, `checkBeer`, `submitBeer`.
  final List<String> callLog = [];

  /// When set, `submitBeer`/`submitBrewery` wait on it -- lets a test hold a
  /// submit in flight to prove double-submit is prevented.
  Completer<void>? submitGate;

  int _nextId = 1;

  Future<void> _maybeDelay() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<PagedResult<ContributionSummary>> getHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    callLog.add('getHistory:$page');
    await _maybeDelay();
    final error = getHistoryError;
    if (error != null) throw error;
    final start = (page - 1) * pageSize;
    final items = start >= history.length
        ? <ContributionSummary>[]
        : history.sublist(start, (start + pageSize).clamp(0, history.length));
    return PagedResult(
      items: items,
      page: page,
      pageSize: pageSize,
      total: history.length,
    );
  }

  ContributionSummary _store(ContributionKind kind, String title) {
    final summary = ContributionSummary(
      id: 'contribution-${_nextId++}',
      kind: kind,
      title: title,
      status: ContributionStatus.pending,
      createdAt: DateTime.utc(2026, 9, 18, 12),
    );
    history.insert(0, summary);
    return summary;
  }

  @override
  Future<ContributionSummary> submitBeer(BeerContributionInput input) async {
    callLog.add('submitBeer');
    submittedBeers.add(input);
    await _maybeDelay();
    await submitGate?.future;
    final error = submitBeerError;
    if (error != null) throw error;
    return _store(ContributionKind.beer, input.officialName);
  }

  @override
  Future<ContributionSummary> submitBrewery(
    BreweryContributionInput input,
  ) async {
    callLog.add('submitBrewery');
    submittedBreweries.add(input);
    await _maybeDelay();
    await submitGate?.future;
    final error = submitBreweryError;
    if (error != null) throw error;
    return _store(ContributionKind.brewery, input.name);
  }

  @override
  Future<BeerDuplicateCandidates> checkBeerDuplicates(
    BeerContributionInput input,
  ) async {
    callLog.add('checkBeer');
    checkedBeers.add(input);
    await _maybeDelay();
    final error = checkBeerError;
    if (error != null) throw error;
    return beerCandidates;
  }

  @override
  Future<BreweryDuplicateCandidates> checkBreweryDuplicates(
    BreweryContributionInput input,
  ) async {
    callLog.add('checkBrewery');
    checkedBreweries.add(input);
    await _maybeDelay();
    final error = checkBreweryError;
    if (error != null) throw error;
    return breweryCandidates;
  }
}
