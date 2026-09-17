import 'package:beerapp/features/achievements/domain/models/achievement.dart';
import 'package:beerapp/features/achievements/domain/models/achievement_category.dart';
import 'package:beerapp/features/achievements/presentation/achievements_controller.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_achievements_repository.dart';

Achievement _achievement(
  String key, {
  bool unlocked = false,
  AchievementCategory category = AchievementCategory.collection,
}) => Achievement(
  key: key,
  category: category,
  unlocked: unlocked,
  unlockedAt: unlocked ? DateTime(2026, 9, 17) : null,
  progressCurrent: unlocked ? 1 : 0,
  progressTarget: 1,
);

void main() {
  test('loadInitial populates achievements from the repository', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.achievements?.length, 1);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('loadInitial failure sets error and leaves achievements null', () async {
    final repository = FakeAchievementsRepository()
      ..getAchievementsError = Exception('boom');
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    await controller.loadInitial();

    expect(controller.achievements, isNull);
    expect(controller.error, isNotNull);
  });

  test('refresh preserves existing achievements on failure rather than clearing them', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    repository.getAchievementsError = Exception('network blip');
    await controller.refresh();

    expect(controller.achievements?.length, 1);
    expect(controller.error, isNotNull);
  });

  test('a second load supersedes an in-flight first load', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );

    final first = controller.loadInitial();
    repository.achievementsResult = [
      _achievement('collection_first_favorite'),
      _achievement('collection_first_wishlist'),
    ];
    final second = controller.refresh();
    await Future.wait([first, second]);

    expect(controller.achievements?.length, 2);
  });

  test('refreshSignal.notifyChanged() triggers a refresh even for a controller '
      'that is not the active/visible screen', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final refreshSignal = CollectionRefreshSignal();
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    repository.callLog.clear();

    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(repository.callLog, ['getAchievements']);
  });

  test('dispose stops listening to the refresh signal', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final refreshSignal = CollectionRefreshSignal();
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: refreshSignal,
    );
    await controller.loadInitial();
    controller.dispose();
    repository.callLog.clear();

    refreshSignal.notifyChanged();
    await Future<void>.delayed(Duration.zero);

    expect(repository.callLog, isEmpty);
  });

  // -- notification-diff: never on first load, only on a later refresh -----

  test(
    'first load never populates takeNewlyUnlocked even when already unlocked',
    () async {
      final repository = FakeAchievementsRepository()
        ..achievementsResult = [
          _achievement('collection_first_favorite', unlocked: true),
        ];
      final controller = AchievementsController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );

      await controller.loadInitial();

      expect(controller.takeNewlyUnlocked(), isEmpty);
    },
  );

  test('a refresh that adds a newly-unlocked achievement surfaces exactly that item', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();

    repository.achievementsResult = [
      _achievement('collection_first_favorite', unlocked: true),
    ];
    await controller.refresh();

    final newlyUnlocked = controller.takeNewlyUnlocked();
    expect(newlyUnlocked.map((a) => a.key), ['collection_first_favorite']);
  });

  test('takeNewlyUnlocked drains -- a second call returns empty', () async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_achievement('collection_first_favorite')];
    final controller = AchievementsController(
      repository: repository,
      refreshSignal: CollectionRefreshSignal(),
    );
    await controller.loadInitial();
    repository.achievementsResult = [
      _achievement('collection_first_favorite', unlocked: true),
    ];
    await controller.refresh();
    controller.takeNewlyUnlocked();

    expect(controller.takeNewlyUnlocked(), isEmpty);
  });

  test(
    'a refresh with no new unlocks leaves takeNewlyUnlocked empty',
    () async {
      final repository = FakeAchievementsRepository()
        ..achievementsResult = [_achievement('collection_first_favorite')];
      final controller = AchievementsController(
        repository: repository,
        refreshSignal: CollectionRefreshSignal(),
      );
      await controller.loadInitial();

      await controller.refresh();

      expect(controller.takeNewlyUnlocked(), isEmpty);
    },
  );
}
