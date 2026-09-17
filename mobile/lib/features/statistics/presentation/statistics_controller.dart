import 'package:flutter/foundation.dart';

import '../../../shared/collection_refresh_signal.dart';
import '../domain/models/statistics.dart';
import '../domain/statistics_repository.dart';
import 'statistics_debug_log.dart';

/// Drives the Statistics screen: fetch-on-init, pull-to-refresh, and
/// staying fresh after mutations elsewhere -- via the same
/// [CollectionRefreshSignal] Collection/Map already listen to (a new beer
/// log or a favorite/wishlist change both invalidate Statistics too; there
/// is deliberately no separate signal for this feature, see
/// docs/DECISIONS.md). Same stale-response generation-guard pattern as
/// `CollectionController`.
class StatisticsController extends ChangeNotifier {
  StatisticsController({
    required this._repository,
    required this._refreshSignal,
  }) {
    _refreshSignal.addListener(_onExternalChange);
  }

  final StatisticsRepository _repository;
  final CollectionRefreshSignal _refreshSignal;

  Statistics? statistics;
  bool isLoading = false;

  /// Full-screen error from the first load failing. A subsequent refresh
  /// failure never sets this once [statistics] is already populated --
  /// see [_load]'s `preserveOnError`.
  Object? error;

  int _requestId = 0;

  Future<void> loadInitial() => _load();

  // A plain pull-to-refresh (or an external mutation signal) re-fetches the
  // same aggregate, so a transient failure preserves the still-valid
  // existing statistics rather than replacing them with a full-screen
  // error -- same reasoning as CollectionController.refresh.
  Future<void> refresh() => _load(preserveOnError: true);

  Future<void> _load({bool preserveOnError = false}) async {
    final generation = ++_requestId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.getStatistics();
      if (generation != _requestId) return;
      statistics = result;
    } catch (e, st) {
      if (generation != _requestId) return;
      error = e;
      if (!preserveOnError) statistics = null;
      logStatisticsError('StatisticsController.load', e, st);
    } finally {
      if (generation == _requestId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void _onExternalChange() => refresh();

  @override
  void dispose() {
    _refreshSignal.removeListener(_onExternalChange);
    super.dispose();
  }
}
