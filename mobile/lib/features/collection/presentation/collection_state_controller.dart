import 'package:flutter/foundation.dart';

import '../../../shared/collection_refresh_signal.dart';
import '../domain/collection_repository.dart';
import 'collection_debug_log.dart';

/// Drives Beer Detail's favorite/wishlist buttons for one beer. Loads
/// independently of the beer's own catalog content (see
/// `BeerDetailScreen`'s doc comment) -- a failure here only disables these
/// two buttons, it never blocks the rest of the screen.
///
/// `setFavorite`/`setWishlist` update optimistically (safe: the backend
/// PATCH is an absolute, idempotent set, never a "toggle" -- see
/// docs/DECISIONS.md) and use their own per-field generation counter, the
/// same stale-response-guard idiom as `DiscoverController`/
/// `BeerLogController`, so a rapid double-tap converges to the
/// last-requested value instead of a stale response rolling back over it.
class CollectionStateController extends ChangeNotifier {
  CollectionStateController({
    required this._repository,
    required this._beerId,
    required this._refreshSignal,
  });

  final CollectionRepository _repository;
  final String _beerId;
  final CollectionRefreshSignal _refreshSignal;

  bool isFavorite = false;
  bool isWishlist = false;
  bool isLoading = false;
  Object? error;

  /// True once the initial [load] has succeeded at least once -- until
  /// then, `isFavorite`/`isWishlist` aren't a confirmed baseline, so Beer
  /// Detail's buttons stay disabled. Deliberately *not* reset by a later
  /// failed [setFavorite]/[setWishlist]: a mutation failure rolls back to
  /// the last-known-good value and is safe to retry, unlike an initial-load
  /// failure where there is no known value at all.
  bool hasLoaded = false;

  int _favoriteGeneration = 0;
  int _wishlistGeneration = 0;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final state = await _repository.getState(_beerId);
      isFavorite = state.isFavorite;
      isWishlist = state.isWishlist;
      hasLoaded = true;
    } catch (e, st) {
      error = e;
      logCollectionError('CollectionStateController.load', e, st);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setFavorite(bool value) async {
    final generation = ++_favoriteGeneration;
    final previous = isFavorite;
    isFavorite = value;
    notifyListeners();
    try {
      final result = await _repository.setState(_beerId, isFavorite: value);
      if (generation != _favoriteGeneration) return;
      isFavorite = result.isFavorite;
      _refreshSignal.notifyChanged();
    } catch (e, st) {
      if (generation != _favoriteGeneration) return;
      isFavorite = previous;
      error = e;
      logCollectionError('CollectionStateController.setFavorite', e, st);
    } finally {
      if (generation == _favoriteGeneration) notifyListeners();
    }
  }

  Future<void> setWishlist(bool value) async {
    final generation = ++_wishlistGeneration;
    final previous = isWishlist;
    isWishlist = value;
    notifyListeners();
    try {
      final result = await _repository.setState(_beerId, isWishlist: value);
      if (generation != _wishlistGeneration) return;
      isWishlist = result.isWishlist;
      _refreshSignal.notifyChanged();
    } catch (e, st) {
      if (generation != _wishlistGeneration) return;
      isWishlist = previous;
      error = e;
      logCollectionError('CollectionStateController.setWishlist', e, st);
    } finally {
      if (generation == _wishlistGeneration) notifyListeners();
    }
  }
}
