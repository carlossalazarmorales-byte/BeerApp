import 'package:flutter/foundation.dart';

import '../domain/contribution_repository.dart';
import '../domain/models/contribution_summary.dart';
import 'contribution_debug_log.dart';

/// Drives the Contributions screen's list of the signed-in user's own
/// submissions: initial load, load-more, refresh.
///
/// Same generation discipline as `BeerLogController`: every request captures
/// [_requestGeneration] and re-checks it before mutating anything, so a
/// superseded request can neither append stale rows nor clobber the loading
/// flags of the request that replaced it.
class ContributionHistoryController extends ChangeNotifier {
  ContributionHistoryController({required this._repository});

  final ContributionRepository _repository;
  static const int _pageSize = 20;

  List<ContributionSummary> items = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  Object? error;
  Object? loadMoreError;

  int _page = 1;
  int _requestGeneration = 0;
  bool _disposed = false;

  Future<void> load() async {
    final generation = ++_requestGeneration;
    isLoading = true;
    isLoadingMore = false;
    error = null;
    loadMoreError = null;
    _notify();
    try {
      final result = await _repository.getHistory(page: 1, pageSize: _pageSize);
      if (generation != _requestGeneration) return;
      items = result.items;
      _page = 1;
      hasMore = _page * _pageSize < result.total;
    } catch (e, st) {
      if (generation != _requestGeneration) return;
      error = e;
      logContributionError('ContributionHistoryController.load', e, st);
    } finally {
      if (generation == _requestGeneration) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMore) return;
    final generation = _requestGeneration;
    isLoadingMore = true;
    loadMoreError = null;
    _notify();
    try {
      final result = await _repository.getHistory(
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (generation != _requestGeneration) return;
      items = [...items, ...result.items];
      _page += 1;
      hasMore = _page * _pageSize < result.total;
    } catch (e, st) {
      if (generation == _requestGeneration) {
        loadMoreError = e;
        logContributionError('ContributionHistoryController.loadMore', e, st);
      }
    } finally {
      if (generation == _requestGeneration) {
        isLoadingMore = false;
        _notify();
      }
    }
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
