import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/logging/domain/models/beer_log.dart';
import 'package:beerapp/features/logging/domain/models/beer_log_input.dart';
import 'package:beerapp/features/logging/presentation/beer_log/beer_log_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../fakes/fake_log_repository.dart';

BeerLog _log(String id, {DateTime? consumedAt}) => BeerLog(
  id: id,
  userId: 'user-1',
  beerId: 'beer-1',
  consumedAt: consumedAt ?? DateTime.utc(2026, 1, 1),
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('load', () {
    test('populates logs and error stays null on success', () async {
      final repository = FakeLogRepository()..logsById['log-1'] = _log('log-1');
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );

      await controller.load();

      expect(controller.logs, hasLength(1));
      expect(controller.error, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('a failure surfaces as error, logs stays empty', () async {
      final repository = FakeLogRepository()..getLogsError = Exception('boom');
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );

      await controller.load();

      expect(controller.logs, isEmpty);
      expect(controller.error, isNotNull);
    });
  });

  group('pagination', () {
    test(
      'loadMore appends a second page and updates hasMore from total',
      () async {
        final repository = FakeLogRepository();
        for (var i = 1; i <= 25; i++) {
          repository.logsById['log-$i'] = _log(
            'log-$i',
            consumedAt: DateTime.utc(2026, 1, i),
          );
        }
        final controller = BeerLogController(
          repository: repository,
          beerId: 'beer-1',
        );

        await controller.load();
        expect(controller.logs, hasLength(20));
        expect(controller.hasMore, isTrue);

        await controller.loadMore();
        expect(controller.logs, hasLength(25));
        expect(controller.hasMore, isFalse);
        expect(controller.isLoadingMore, isFalse);
      },
    );

    test('loadMore is a no-op when hasMore is false', () async {
      final repository = FakeLogRepository()..logsById['log-1'] = _log('log-1');
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );
      await controller.load();
      expect(controller.hasMore, isFalse);

      await controller.loadMore();

      expect(
        repository.callLog.where((c) => c.startsWith('getLogs')).length,
        1,
        reason: 'loadMore must not issue a request when hasMore is false',
      );
    });

    test(
      'a failed loadMore sets loadMoreError without touching existing logs',
      () async {
        final repository = FakeLogRepository();
        for (var i = 1; i <= 25; i++) {
          repository.logsById['log-$i'] = _log(
            'log-$i',
            consumedAt: DateTime.utc(2026, 1, i),
          );
        }
        final controller = BeerLogController(
          repository: repository,
          beerId: 'beer-1',
        );
        await controller.load();

        repository.getLogsError = Exception('page 2 failed');
        await controller.loadMore();

        expect(controller.loadMoreError, isNotNull);
        expect(
          controller.logs,
          hasLength(20),
          reason: 'existing page must survive a failed loadMore',
        );
      },
    );

    test('loadMore is a no-op while already loading more', () async {
      final repository = FakeLogRepository();
      for (var i = 1; i <= 25; i++) {
        repository.logsById['log-$i'] = _log(
          'log-$i',
          consumedAt: DateTime.utc(2026, 1, i),
        );
      }
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );
      await controller.load();

      final pending = repository.queueManualGetLogsResponse();
      final firstCall = controller.loadMore();
      final secondCall = controller.loadMore(); // should be a no-op immediately

      pending.complete(
        PagedResult(
          items: repository.logsById.values.skip(20).toList(),
          page: 2,
          pageSize: 20,
          total: 25,
        ),
      );
      await firstCall;
      await secondCall;

      expect(
        repository.callLog.where((c) => c.startsWith('getLogs')).length,
        2, // the initial load() + exactly one loadMore()
      );
    });
  });

  group('stale loadMore race safety', () {
    test('a stale loadMore response neither appends nor corrupts a newer request\'s isLoadingMore', () async {
      final repository = FakeLogRepository();
      for (var i = 1; i <= 25; i++) {
        repository.logsById['log-$i'] = _log(
          'log-$i',
          consumedAt: DateTime.utc(2026, 1, i),
        );
      }
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );
      await controller.load();

      // Step 1: start a loadMore whose response we control manually, and
      // leave it unresolved.
      final stalePending = repository.queueManualGetLogsResponse();
      final staleCall = controller.loadMore();
      expect(controller.isLoadingMore, isTrue);

      // Step 2: a full reload runs and completes while step 1 is still
      // in flight. It must synchronously reclaim isLoadingMore.
      await controller.load();
      expect(controller.isLoadingMore, isFalse);
      expect(controller.logs, hasLength(20));

      // Step 3: a fresh loadMore runs normally.
      await controller.loadMore();
      expect(controller.logs, hasLength(25));
      expect(controller.isLoadingMore, isFalse);

      // Step 4: start another loadMore (there is no more data, so this
      // would be a no-op) is irrelevant here -- instead, directly assert
      // step 1's late resolution changes nothing now that it's stale.
      final logsBeforeStaleResolves = List.of(controller.logs);
      stalePending.complete(
        PagedResult(
          items: [_log('stale-intruder')],
          page: 2,
          pageSize: 20,
          total: 26,
        ),
      );
      await staleCall;

      expect(controller.logs, logsBeforeStaleResolves);
      expect(controller.isLoadingMore, isFalse);
      expect(controller.loadMoreError, isNull);
    });
  });

  group('submitCreate/Update/Delete', () {
    test('submitCreate reloads the list on success', () async {
      final repository = FakeLogRepository();
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );
      await controller.load();

      final success = await controller.submitCreate(
        const BeerLogCreateInput(beerId: 'beer-1'),
      );

      expect(success, isTrue);
      expect(controller.logs, hasLength(1));
    });

    test(
      'duplicate/concurrent submitCreate calls result in only one create',
      () async {
        final repository = FakeLogRepository(
          delay: const Duration(milliseconds: 10),
        );
        final controller = BeerLogController(
          repository: repository,
          beerId: 'beer-1',
        );

        final first = controller.submitCreate(
          const BeerLogCreateInput(beerId: 'beer-1'),
        );
        final second = controller.submitCreate(
          const BeerLogCreateInput(beerId: 'beer-1'),
        );

        await Future.wait([first, second]);

        expect(repository.callLog.where((c) => c == 'createLog').length, 1);
      },
    );

    test(
      'submitUpdate refuses to call the repository when the patch is empty',
      () async {
        final repository = FakeLogRepository()
          ..logsById['log-1'] = _log('log-1');
        final controller = BeerLogController(
          repository: repository,
          beerId: 'beer-1',
        );
        await controller.load();

        final success = await controller.submitUpdate(
          'log-1',
          const BeerLogUpdateInput(),
        );

        expect(success, isFalse);
        expect(
          repository.callLog.where((c) => c.startsWith('updateLog')),
          isEmpty,
        );
      },
    );

    test('submitDelete reloads the list on success', () async {
      final repository = FakeLogRepository()..logsById['log-1'] = _log('log-1');
      final controller = BeerLogController(
        repository: repository,
        beerId: 'beer-1',
      );
      await controller.load();

      final success = await controller.submitDelete('log-1');

      expect(success, isTrue);
      expect(controller.logs, isEmpty);
    });
  });
}
