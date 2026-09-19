import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
import 'package:beerapp/features/contributions/presentation/contribution_history_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_contribution_repository.dart';

ContributionSummary _item(int n) => ContributionSummary(
  id: 'c-$n',
  kind: n.isEven ? ContributionKind.beer : ContributionKind.brewery,
  title: 'Item $n',
  status: ContributionStatus.pending,
  createdAt: DateTime.utc(2026, 9, 18),
);

void main() {
  test('load fills the list newest-first and reports no more', () async {
    final repository = FakeContributionRepository()
      ..history.addAll([_item(3), _item(2), _item(1)]);
    final controller = ContributionHistoryController(repository: repository);

    await controller.load();

    expect(controller.items.map((i) => i.title), [
      'Item 3',
      'Item 2',
      'Item 1',
    ]);
    expect(controller.hasMore, isFalse);
    expect(controller.error, isNull);
    expect(controller.isLoading, isFalse);
  });

  test('an empty history is not an error', () async {
    final controller = ContributionHistoryController(
      repository: FakeContributionRepository(),
    );
    await controller.load();
    expect(controller.items, isEmpty);
    expect(controller.error, isNull);
  });

  test('loadMore appends the next page and stops at the end', () async {
    final repository = FakeContributionRepository()
      ..history.addAll([for (var i = 45; i >= 1; i--) _item(i)]);
    final controller = ContributionHistoryController(repository: repository);

    await controller.load();
    expect(controller.items, hasLength(20));
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.items, hasLength(40));
    expect(controller.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.items, hasLength(45));
    expect(controller.hasMore, isFalse);

    await controller.loadMore(); // nothing left: no further request
    expect(
      repository.callLog.where((c) => c.startsWith('getHistory')),
      hasLength(3),
    );
  });

  test('a failed load exposes the error and a reload recovers', () async {
    final repository = FakeContributionRepository()
      ..getHistoryError = const NetworkApiException(message: 'offline');
    final controller = ContributionHistoryController(repository: repository);

    await controller.load();
    expect(controller.error, isA<NetworkApiException>());
    expect(controller.items, isEmpty);

    repository.getHistoryError = null;
    repository.history.add(_item(1));
    await controller.load();
    expect(controller.error, isNull);
    expect(controller.items, hasLength(1));
  });

  test('a failed loadMore keeps the loaded rows and can be retried', () async {
    final repository = FakeContributionRepository()
      ..history.addAll([for (var i = 30; i >= 1; i--) _item(i)]);
    final controller = ContributionHistoryController(repository: repository);
    await controller.load();

    repository.getHistoryError = const NetworkApiException(message: 'offline');
    await controller.loadMore();
    expect(controller.items, hasLength(20));
    expect(controller.loadMoreError, isNotNull);
    expect(controller.error, isNull);

    repository.getHistoryError = null;
    await controller.loadMore();
    expect(controller.items, hasLength(30));
    expect(controller.loadMoreError, isNull);
  });

  test('a stale load never overwrites a newer one', () async {
    final repository = FakeContributionRepository(
      delay: const Duration(milliseconds: 10),
    )..history.add(_item(1));
    final controller = ContributionHistoryController(repository: repository);

    final first = controller.load();
    repository.history
      ..clear()
      ..addAll([_item(2), _item(1)]);
    final second = controller.load();
    await Future.wait([first, second]);

    expect(controller.items.map((i) => i.title), ['Item 2', 'Item 1']);
    expect(controller.isLoading, isFalse);
  });

  test('a controller disposed mid-load does not throw', () async {
    final repository = FakeContributionRepository(
      delay: const Duration(milliseconds: 10),
    )..history.add(_item(1));
    final controller = ContributionHistoryController(repository: repository);

    final future = controller.load();
    controller.dispose();
    await expectLater(future, completes);
  });
}
