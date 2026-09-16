import 'package:beerapp/features/collection/domain/models/collection_state.dart';
import 'package:beerapp/features/collection/presentation/collection_state_controller.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_collection_repository.dart';

void main() {
  test('load populates isFavorite/isWishlist on success', () async {
    final repository = FakeCollectionRepository()
      ..stateByBeerId['beer-1'] = const CollectionState(
        beerId: 'beer-1',
        isFavorite: true,
        isWishlist: false,
      );
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.load();

    expect(controller.isFavorite, isTrue);
    expect(controller.isWishlist, isFalse);
    expect(controller.error, isNull);
  });

  test('a load failure sets error and never throws into the caller', () async {
    final repository = FakeCollectionRepository()
      ..getStateError = Exception('boom');
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.load();

    expect(controller.error, isNotNull);
    expect(controller.isFavorite, isFalse);
  });

  test(
    'setFavorite updates optimistically and confirms from the response',
    () async {
      final repository = FakeCollectionRepository();
      final controller = CollectionStateController(
        repository: repository,
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.setFavorite(true);

      expect(controller.isFavorite, isTrue);
      expect(repository.stateByBeerId['beer-1']?.isFavorite, isTrue);
    },
  );

  test('a failed setFavorite rolls back to the previous value', () async {
    final repository = FakeCollectionRepository();
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.setFavorite(true);
    expect(controller.isFavorite, isTrue);

    repository.setStateError = Exception('network blip');
    await controller.setFavorite(false);

    expect(controller.isFavorite, isTrue, reason: 'rolled back on failure');
    expect(controller.error, isNotNull);
  });

  test('a rapid setFavorite(true) then setFavorite(false) converges to false '
      'and never rolls back to the first call\'s optimistic true', () async {
    final repository = FakeCollectionRepository(
      delay: const Duration(milliseconds: 20),
    );
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: CollectionRefreshSignal(),
    );

    final first = controller.setFavorite(true);
    final second = controller.setFavorite(false);
    await Future.wait([first, second]);

    expect(controller.isFavorite, isFalse);
  });

  test('setFavorite does not disturb isWishlist', () async {
    final repository = FakeCollectionRepository()
      ..stateByBeerId['beer-1'] = const CollectionState(
        beerId: 'beer-1',
        isFavorite: false,
        isWishlist: true,
      );
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.load();

    await controller.setFavorite(true);

    expect(controller.isFavorite, isTrue);
    expect(controller.isWishlist, isTrue);
  });

  test('setFavorite notifies the refresh signal on success', () async {
    final repository = FakeCollectionRepository();
    final refreshSignal = CollectionRefreshSignal();
    var notified = 0;
    refreshSignal.addListener(() => notified++);
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: refreshSignal,
    );

    await controller.setFavorite(true);

    expect(notified, 1);
  });

  test('setFavorite does not notify the refresh signal on failure', () async {
    final repository = FakeCollectionRepository()
      ..setStateError = Exception('boom');
    final refreshSignal = CollectionRefreshSignal();
    var notified = 0;
    refreshSignal.addListener(() => notified++);
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: refreshSignal,
    );

    await controller.setFavorite(true);

    expect(notified, 0);
  });

  test('repeated identical setFavorite calls are idempotent', () async {
    final repository = FakeCollectionRepository();
    final controller = CollectionStateController(
      repository: repository,
      beerId: 'beer-1',
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.setFavorite(true);
    await controller.setFavorite(true);

    expect(controller.isFavorite, isTrue);
    expect(
      repository.callLog.where((c) => c == 'setState:beer-1:favorite'),
      hasLength(2),
    );
  });

  group('cross-field independence (favorite/wishlist use separate generation counters)', () {
    test('setFavorite(true) + setWishlist(true) converge correctly when the '
        'favorite response arrives after the wishlist response', () async {
      final repository = FakeCollectionRepository()
        ..extraDelayByCallKey['setState:beer-1:favorite'] = const Duration(
          milliseconds: 30,
        );
      final controller = CollectionStateController(
        repository: repository,
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );

      final favoriteFuture = controller.setFavorite(true);
      final wishlistFuture = controller.setWishlist(true);
      await Future.wait([favoriteFuture, wishlistFuture]);

      // Neither call's completion overwrote the other's field with a
      // stale/default value from its own (full-state) response.
      expect(controller.isFavorite, isTrue);
      expect(controller.isWishlist, isTrue);
    });

    test('setFavorite(true) + setWishlist(true) converge correctly when the '
        'wishlist response arrives after the favorite response', () async {
      final repository = FakeCollectionRepository()
        ..extraDelayByCallKey['setState:beer-1:wishlist'] = const Duration(
          milliseconds: 30,
        );
      final controller = CollectionStateController(
        repository: repository,
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );

      final favoriteFuture = controller.setFavorite(true);
      final wishlistFuture = controller.setWishlist(true);
      await Future.wait([favoriteFuture, wishlistFuture]);

      expect(controller.isFavorite, isTrue);
      expect(controller.isWishlist, isTrue);
    });

    test('independent removals: setFavorite(false) + setWishlist(false) from '
        '{true, true} both apply regardless of response ordering', () async {
      final repository = FakeCollectionRepository()
        ..stateByBeerId['beer-1'] = const CollectionState(
          beerId: 'beer-1',
          isFavorite: true,
          isWishlist: true,
        )
        ..extraDelayByCallKey['setState:beer-1:favorite'] = const Duration(
          milliseconds: 30,
        );
      final controller = CollectionStateController(
        repository: repository,
        beerId: 'beer-1',
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.load();

      final favoriteFuture = controller.setFavorite(false);
      final wishlistFuture = controller.setWishlist(false);
      await Future.wait([favoriteFuture, wishlistFuture]);

      expect(controller.isFavorite, isFalse);
      expect(controller.isWishlist, isFalse);
    });

    test(
      'setFavorite only ever reads isFavorite from the response, never '
      'isWishlist, even though the fake (like the real API) returns full state',
      () async {
        final repository = FakeCollectionRepository()
          ..stateByBeerId['beer-1'] = const CollectionState(
            beerId: 'beer-1',
            isFavorite: false,
            isWishlist: true,
          );
        final controller = CollectionStateController(
          repository: repository,
          beerId: 'beer-1',
          refreshSignal: CollectionRefreshSignal(),
        );
        await controller.load();
        expect(controller.isWishlist, isTrue);

        // A newer, in-flight optimistic wishlist=false must not be
        // clobbered back to true by setFavorite's own (unrelated) response.
        final wishlistFuture = controller.setWishlist(false);
        await controller.setFavorite(true);
        await wishlistFuture;

        expect(controller.isFavorite, isTrue);
        expect(controller.isWishlist, isFalse);
      },
    );
  });
}
