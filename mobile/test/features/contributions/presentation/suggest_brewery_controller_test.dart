import 'dart:async';

import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_input.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
import 'package:beerapp/features/contributions/domain/models/duplicate_candidates.dart';
import 'package:beerapp/features/contributions/presentation/suggest_brewery_controller.dart';
import 'package:beerapp/features/contributions/presentation/suggest_flow.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_contribution_repository.dart';
import '../contribution_test_harness.dart';

const _input = BreweryContributionInput(
  name: 'New Brewery',
  countryId: 'country-1',
);

SuggestBreweryController _controller(FakeContributionRepository repository) =>
    SuggestBreweryController(
      contributions: repository,
      catalog: catalogWithOptions(),
    );

void main() {
  test('loads the country options', () async {
    final controller = _controller(FakeContributionRepository());
    await controller.loadOptions();
    expect(controller.countryOptions.map((c) => c.name), [
      'Germany',
      'Ireland',
    ]);
  });

  test('a clean check submits and ends server-confirmed as pending', () async {
    final repository = FakeContributionRepository();
    final controller = _controller(repository);

    await controller.submit(_input);

    expect(repository.callLog, ['checkBrewery', 'submitBrewery']);
    expect(controller.phase, SuggestPhase.submitted);
    expect(controller.submitted!.kind, ContributionKind.brewery);
    expect(controller.submitted!.status, ContributionStatus.pending);
  });

  test('a second submit while one is in flight is ignored', () async {
    final repository = FakeContributionRepository()
      ..submitGate = Completer<void>();
    final controller = _controller(repository);

    final first = controller.submit(_input);
    await Future<void>.delayed(Duration.zero);
    await controller.submit(_input);
    repository.submitGate!.complete();
    await first;

    expect(repository.submittedBreweries, hasLength(1));
  });

  test('the users own pending duplicate blocks', () async {
    final repository = FakeContributionRepository()
      ..breweryCandidates = const BreweryDuplicateCandidates(
        nameMatches: [],
        alreadySubmitted: true,
      );
    final controller = _controller(repository);

    await controller.submit(_input);

    expect(controller.block, SuggestBlock.alreadySubmitted);
    expect(repository.submittedBreweries, isEmpty);
  });

  test(
    'a same-named catalog brewery is a warning that can be confirmed',
    () async {
      final repository = FakeContributionRepository()
        ..breweryCandidates = const BreweryDuplicateCandidates(
          nameMatches: [testBrewery],
          alreadySubmitted: false,
        );
      final controller = _controller(repository);

      await controller.submit(_input);
      expect(controller.phase, SuggestPhase.awaitingConfirmation);
      expect(repository.submittedBreweries, isEmpty);

      await controller.confirmSubmit();
      expect(controller.phase, SuggestPhase.submitted);
      expect(repository.submittedBreweries, hasLength(1));
    },
  );

  test('"Review" returns to editing and submits nothing', () async {
    final repository = FakeContributionRepository()
      ..breweryCandidates = const BreweryDuplicateCandidates(
        nameMatches: [testBrewery],
        alreadySubmitted: false,
      );
    final controller = _controller(repository);
    await controller.submit(_input);

    controller.reviewAgain();

    expect(controller.phase, SuggestPhase.editing);
    expect(repository.submittedBreweries, isEmpty);
  });

  test('a raced already_submitted 409 blocks', () async {
    final repository = FakeContributionRepository()
      ..submitBreweryError = const ConflictApiException(
        message: 'x',
        statusCode: 409,
        code: 'already_submitted',
      );
    final controller = _controller(repository);

    await controller.submit(_input);

    expect(controller.block, SuggestBlock.alreadySubmitted);
    expect(controller.phase, SuggestPhase.editing);
  });

  test('a network failure surfaces and a retry succeeds', () async {
    final repository = FakeContributionRepository()
      ..submitBreweryError = const NetworkApiException(message: 'offline');
    final controller = _controller(repository);

    await controller.submit(_input);
    expect(controller.error, isA<NetworkApiException>());
    expect(controller.phase, SuggestPhase.editing);

    repository.submitBreweryError = null;
    await controller.submit(_input);
    expect(controller.phase, SuggestPhase.submitted);
  });

  test('a failed duplicate check submits nothing', () async {
    final repository = FakeContributionRepository()
      ..checkBreweryError = const ServiceUnavailableApiException(message: 'x');
    final controller = _controller(repository);

    await controller.submit(_input);

    expect(controller.error, isA<ServiceUnavailableApiException>());
    expect(repository.submittedBreweries, isEmpty);
  });
}
