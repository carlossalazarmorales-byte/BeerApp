import 'package:flutter/foundation.dart';

import '../../domain/log_repository.dart';
import '../../domain/models/beer_log.dart';
import '../../domain/models/beer_log_input.dart';
import '../beer_log_debug_log.dart';

/// Drives Beer Detail's "Your logs" section for one beer: paginated list of
/// the current user's own logs, plus create/update/delete.
///
/// Pagination and mutation both mutate shared state (`logs`,
/// `isLoading`/`isLoadingMore`), so every method that starts a request
/// captures the current [_requestGeneration] and checks it again before
/// mutating anything -- including in a `finally` block. A stale request
/// (superseded by a newer [load]/mutation before it resolved) is not merely
/// prevented from appending stale data: it is also forbidden from touching
/// `isLoading`/`isLoadingMore` at all, because by the time it resolves a
/// newer request may legitimately have that flag set to `true` for its own
/// in-flight work, and an unconditional reset would stomp on it.
class BeerLogController extends ChangeNotifier {
  BeerLogController({required this._repository, required this._beerId});

  final LogRepository _repository;
  final String _beerId;
  static const int _pageSize = 20;

  String get beerId => _beerId;

  List<BeerLog> logs = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = false;
  bool isSubmitting = false;
  Object? error;
  Object? loadMoreError;

  int _page = 1;
  int _requestGeneration = 0;

  Future<void> load() async {
    final generation = ++_requestGeneration;
    isLoading = true;
    // Any in-flight loadMore's claim on this flag is superseded now,
    // synchronously -- not left for its (now-stale) finally block to clear.
    isLoadingMore = false;
    error = null;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getLogs(
        beerId: _beerId,
        page: 1,
        pageSize: _pageSize,
      );
      if (generation != _requestGeneration) return;
      logs = result.items;
      _page = 1;
      hasMore = _page * _pageSize < result.total;
    } catch (e, st) {
      if (generation != _requestGeneration) return;
      error = e;
      logBeerLogError('BeerLogController.load', e, st);
    } finally {
      if (generation == _requestGeneration) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    // Not incremented -- this request belongs to the current generation,
    // it doesn't start a new one.
    final generation = _requestGeneration;
    isLoadingMore = true;
    loadMoreError = null;
    notifyListeners();
    try {
      final result = await _repository.getLogs(
        beerId: _beerId,
        page: _page + 1,
        pageSize: _pageSize,
      );
      if (generation != _requestGeneration) return;
      logs = [...logs, ...result.items];
      _page += 1;
      hasMore = _page * _pageSize < result.total;
    } catch (e, st) {
      if (generation == _requestGeneration) {
        loadMoreError = e;
        logBeerLogError('BeerLogController.loadMore', e, st);
      }
    } finally {
      if (generation == _requestGeneration) {
        isLoadingMore = false;
        notifyListeners();
      }
      // else: this request is stale. isLoadingMore is not ours to touch --
      // load() already reset it synchronously when it bumped the
      // generation, or a subsequent loadMore() now owns it instead.
    }
  }

  Future<bool> submitCreate(BeerLogCreateInput input) async {
    if (isSubmitting) return false;
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.createLog(input);
      await load();
      return true;
    } catch (e, st) {
      error = e;
      logBeerLogError('BeerLogController.submitCreate', e, st);
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitUpdate(String logId, BeerLogUpdateInput input) async {
    if (isSubmitting || input.isEmpty) return false;
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.updateLog(logId, input);
      await load();
      return true;
    } catch (e, st) {
      error = e;
      logBeerLogError('BeerLogController.submitUpdate', e, st);
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> submitDelete(String logId) async {
    if (isSubmitting) return false;
    isSubmitting = true;
    notifyListeners();
    try {
      await _repository.deleteLog(logId);
      await load();
      return true;
    } catch (e, st) {
      error = e;
      logBeerLogError('BeerLogController.submitDelete', e, st);
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }
}
