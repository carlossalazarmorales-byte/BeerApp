import 'package:flutter/foundation.dart';

import '../../../shared/collection_refresh_signal.dart';
import '../domain/achievements_repository.dart';
import '../domain/models/achievement.dart';
import 'achievements_debug_log.dart';

/// Drives the Achievements screen: fetch-on-init, pull-to-refresh, and
/// staying fresh after mutations elsewhere -- via the same
/// [CollectionRefreshSignal] Statistics/Collection/Map already listen to (a
/// favorite/wishlist change re-evaluates achievements server-side; this
/// controller just needs to re-fetch the result). Same stale-response
/// generation-guard pattern as `StatisticsController`.
///
/// Also tracks which achievements are newly unlocked since the *previous*
/// successful load, so the screen can show a transient in-app notification
/// -- never on the very first [loadInitial], only on a later [refresh]. This
/// is purely a client-side diff for display; the server always decides and
/// persists what is actually unlocked (see docs/DECISIONS.md).
class AchievementsController extends ChangeNotifier {
  AchievementsController({
    required this._repository,
    required this._refreshSignal,
  }) {
    _refreshSignal.addListener(_onExternalChange);
  }

  final AchievementsRepository _repository;
  final CollectionRefreshSignal _refreshSignal;

  List<Achievement>? achievements;
  bool isLoading = false;

  /// Full-screen error from the first load failing. A subsequent refresh
  /// failure never sets this once [achievements] is already populated --
  /// see [_load]'s `preserveOnError`.
  Object? error;

  int _requestId = 0;

  /// Null until after the first successful load -- deliberately never
  /// compared against on that first load, so pre-existing unlocks (from
  /// activity that happened before this screen was ever opened) never
  /// surface a notification.
  Set<String>? _previousUnlockedKeys;
  List<Achievement> _newlyUnlocked = const [];

  Future<void> loadInitial() => _load(isInitial: true);

  // A plain pull-to-refresh (or an external mutation signal) re-fetches the
  // same list, so a transient failure preserves the still-valid existing
  // achievements rather than replacing them with a full-screen error --
  // same reasoning as StatisticsController.refresh.
  Future<void> refresh() => _load(preserveOnError: true);

  Future<void> _load({
    bool preserveOnError = false,
    bool isInitial = false,
  }) async {
    final generation = ++_requestId;
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _repository.getAchievements();
      if (generation != _requestId) return;
      _updateNewlyUnlocked(result, isInitial: isInitial);
      achievements = result;
    } catch (e, st) {
      if (generation != _requestId) return;
      error = e;
      if (!preserveOnError) achievements = null;
      logAchievementsError('AchievementsController.load', e, st);
    } finally {
      if (generation == _requestId) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void _updateNewlyUnlocked(
    List<Achievement> result, {
    required bool isInitial,
  }) {
    final newKeys = result
        .where((achievement) => achievement.unlocked)
        .map((achievement) => achievement.key)
        .toSet();
    final previous = _previousUnlockedKeys;
    if (!isInitial && previous != null) {
      final grown = newKeys.difference(previous);
      if (grown.isNotEmpty) {
        _newlyUnlocked = result
            .where((achievement) => grown.contains(achievement.key))
            .toList();
      }
    }
    _previousUnlockedKeys = newKeys;
  }

  /// Returns (and clears) any achievements newly unlocked since the
  /// previous load, for the screen to show a one-shot notification. Drains
  /// on read so a later unrelated rebuild never re-shows the same banner.
  List<Achievement> takeNewlyUnlocked() {
    final taken = _newlyUnlocked;
    _newlyUnlocked = const [];
    return taken;
  }

  void _onExternalChange() => refresh();

  @override
  void dispose() {
    _refreshSignal.removeListener(_onExternalChange);
    super.dispose();
  }
}
