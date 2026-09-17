import 'package:beerapp/features/achievements/domain/models/achievement.dart';
import 'package:beerapp/features/achievements/domain/models/achievement_category.dart';
import 'package:beerapp/features/achievements/presentation/achievements_screen.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_achievements_repository.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

Achievement _locked(String key, {int current = 0, int target = 1}) =>
    Achievement(
      key: key,
      category: AchievementCategory.collection,
      unlocked: false,
      unlockedAt: null,
      progressCurrent: current,
      progressTarget: target,
    );

Achievement _unlocked(
  String key, {
  AchievementCategory category = AchievementCategory.collection,
}) => Achievement(
  key: key,
  category: category,
  unlocked: true,
  unlockedAt: DateTime(2026, 9, 17),
  progressCurrent: 1,
  progressTarget: 1,
);

void main() {
  testWidgets('shows a loading indicator before the repository resolves', (
    tester,
  ) async {
    final repository = FakeAchievementsRepository(
      delay: const Duration(milliseconds: 50),
    )..achievementsResult = [_locked('collection_first_favorite')];
    await tester.pumpWidget(
      _wrap(
        AchievementsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
  });

  testWidgets(
    'shows an error state with a working retry on first-load failure',
    (tester) async {
      final repository = FakeAchievementsRepository()
        ..getAchievementsError = Exception('boom');
      await tester.pumpWidget(
        _wrap(
          AchievementsScreen(
            repository: repository,
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't load your achievements. Please try again."),
        findsOneWidget,
      );

      repository.getAchievementsError = null;
      repository.achievementsResult = [_locked('collection_first_favorite')];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('First Favorite'), findsOneWidget);
    },
  );

  testWidgets(
    'only renders category sections that have at least one achievement',
    (tester) async {
      final repository = FakeAchievementsRepository()
        ..achievementsResult = [
          _locked('collection_first_favorite'),
          _unlocked(
            'collection_curator',
            category: AchievementCategory.special,
          ),
        ];
      await tester.pumpWidget(
        _wrap(
          AchievementsScreen(
            repository: repository,
            refreshSignal: CollectionRefreshSignal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collection'), findsOneWidget);
      expect(find.text('Special'), findsOneWidget);
      // No entries exist in any other category for this response.
      expect(find.text('Countries'), findsNothing);
      expect(find.text('Styles'), findsNothing);
      expect(find.text('Beers Tried'), findsNothing);
    },
  );

  testWidgets('renders locked and unlocked tiles distinctly', (tester) async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [
        _locked('collection_first_favorite'),
        _unlocked('collection_first_wishlist'),
      ];
    await tester.pumpWidget(
      _wrap(
        AchievementsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Unlocked on 2026-09-17'), findsOneWidget);
  });

  testWidgets('a refresh that introduces a new unlock shows a snackbar', (
    tester,
  ) async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_locked('collection_first_favorite')];
    await tester.pumpWidget(
      _wrap(
        AchievementsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);

    repository.achievementsResult = [_unlocked('collection_first_favorite')];
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Achievement unlocked: First Favorite'), findsOneWidget);
  });

  testWidgets('pull-to-refresh re-fetches achievements', (tester) async {
    final repository = FakeAchievementsRepository()
      ..achievementsResult = [_locked('collection_first_favorite')];
    await tester.pumpWidget(
      _wrap(
        AchievementsScreen(
          repository: repository,
          refreshSignal: CollectionRefreshSignal(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    repository.callLog.clear();

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(repository.callLog, contains('getAchievements'));
  });
}
