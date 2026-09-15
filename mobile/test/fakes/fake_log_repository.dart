import 'dart:async';

import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/logging/domain/log_repository.dart';
import 'package:beerapp/features/logging/domain/models/beer_log.dart';
import 'package:beerapp/features/logging/domain/models/beer_log_input.dart';

class FakeLogRepository implements LogRepository {
  FakeLogRepository({this.delay = Duration.zero});

  /// Artificial delay before getLogs/createLog/updateLog/deleteLog resolve
  /// -- zero by default, set to a small non-zero value in tests that need
  /// to observe an intermediate loading state.
  final Duration delay;

  /// In-memory store keyed by log id -- create/update/delete mutate this
  /// directly, so a controller's post-mutation `load()` reload reflects the
  /// change without any extra plumbing.
  final Map<String, BeerLog> logsById = {};

  Object? getLogsError;
  Object? createLogError;
  Object? updateLogError;
  Object? deleteLogError;

  /// Records call order -- e.g. `getLogs:1`, `createLog`, `deleteLog:log-1`.
  final List<String> callLog = [];

  /// Queued manually-completed responses for `getLogs`, consumed in FIFO
  /// order. Lets a test control precisely when one specific call resolves
  /// relative to another -- a fixed [delay] can't reliably reproduce "the
  /// first call resolves *after* the second one already completed", which
  /// the stale-`loadMore()` race regression test needs. Call
  /// [queueManualGetLogsResponse] once per `getLogs` invocation you want to
  /// control; any invocation beyond the number queued falls back to the
  /// normal [delay]/[getLogsError]/in-memory-store behavior.
  final List<Completer<PagedResult<BeerLog>>> _pendingGetLogs = [];

  Completer<PagedResult<BeerLog>> queueManualGetLogsResponse() {
    final completer = Completer<PagedResult<BeerLog>>();
    _pendingGetLogs.add(completer);
    return completer;
  }

  Future<void> _maybeDelay() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<PagedResult<BeerLog>> getLogs({
    String? beerId,
    int page = 1,
    int pageSize = 20,
  }) async {
    callLog.add('getLogs:$page');
    if (_pendingGetLogs.isNotEmpty) {
      return _pendingGetLogs.removeAt(0).future;
    }
    await _maybeDelay();
    final error = getLogsError;
    if (error != null) throw error;

    final all =
        logsById.values
            .where((log) => beerId == null || log.beerId == beerId)
            .toList()
          ..sort((a, b) {
            final byDate = b.consumedAt.compareTo(a.consumedAt);
            return byDate != 0 ? byDate : b.id.compareTo(a.id);
          });
    final start = (page - 1) * pageSize;
    final end = (start + pageSize).clamp(0, all.length);
    final items = start >= all.length
        ? const <BeerLog>[]
        : all.sublist(start, end);
    return PagedResult(
      items: items,
      page: page,
      pageSize: pageSize,
      total: all.length,
    );
  }

  @override
  Future<BeerLog> createLog(BeerLogCreateInput input) async {
    callLog.add('createLog');
    await _maybeDelay();
    final error = createLogError;
    if (error != null) throw error;

    final id = 'log-${logsById.length + 1}';
    final now = DateTime.now().toUtc();
    final log = BeerLog(
      id: id,
      userId: 'user-1',
      beerId: input.beerId,
      rating: input.rating,
      review: input.review,
      consumedAt: input.consumedAt ?? now,
      servingNote: input.servingNote,
      price: input.price,
      currency: input.currency,
      venueName: input.venueName,
      servingVolumeMl: input.servingVolumeMl,
      createdAt: now,
      updatedAt: now,
    );
    logsById[id] = log;
    return log;
  }

  @override
  Future<BeerLog> updateLog(String id, BeerLogUpdateInput input) async {
    callLog.add('updateLog:$id');
    await _maybeDelay();
    final error = updateLogError;
    if (error != null) throw error;

    final existing = logsById[id];
    if (existing == null) throw StateError('FakeLogRepository: no log $id');
    final patch = input.toPatchJson();
    final updated = BeerLog(
      id: existing.id,
      userId: existing.userId,
      beerId: existing.beerId,
      rating: patch.containsKey('rating')
          ? patch['rating'] as int?
          : existing.rating,
      review: patch.containsKey('review')
          ? patch['review'] as String?
          : existing.review,
      consumedAt: patch.containsKey('consumed_at')
          ? DateTime.parse(patch['consumed_at'] as String)
          : existing.consumedAt,
      servingNote: patch.containsKey('serving_note')
          ? patch['serving_note'] as String?
          : existing.servingNote,
      price: patch.containsKey('price')
          ? patch['price'] as double?
          : existing.price,
      currency: patch.containsKey('currency')
          ? patch['currency'] as String?
          : existing.currency,
      venueName: patch.containsKey('venue_name')
          ? patch['venue_name'] as String?
          : existing.venueName,
      servingVolumeMl: patch.containsKey('serving_volume_ml')
          ? patch['serving_volume_ml'] as int?
          : existing.servingVolumeMl,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    logsById[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteLog(String id) async {
    callLog.add('deleteLog:$id');
    await _maybeDelay();
    final error = deleteLogError;
    if (error != null) throw error;
    logsById.remove(id);
  }
}
