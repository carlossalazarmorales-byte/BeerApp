import 'dart:async';

import 'package:beerapp/core/network/api_exception.dart';
import 'package:beerapp/features/catalog/domain/models/beer.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_input.dart';
import 'package:beerapp/features/contributions/domain/models/contribution_summary.dart';
import 'package:beerapp/features/contributions/domain/models/duplicate_candidates.dart';
import 'package:beerapp/features/contributions/presentation/suggest_beer_controller.dart';
import 'package:beerapp/features/contributions/presentation/suggest_flow.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../fakes/fake_catalog_repository.dart';
import '../../../fakes/fake_contribution_repository.dart';
import '../contribution_test_harness.dart';

const _input = BeerContributionInput(
  officialName: 'New Beer',
  breweryId: 'brewery-1',
  barcode: '4006381333931',
);

SuggestBeerController _controller(
  FakeContributionRepository contributions, [
  FakeCatalogRepository? catalog,
]) => SuggestBeerController(
  contributions: contributions,
  catalog: catalog ?? catalogWithOptions(),
);

BeerDuplicateCandidates _candidates({
  Beer? barcodeMatch,
  List<Beer> nameMatches = const [],
  bool alreadySubmitted = false,
  bool pendingBarcode = false,
}) => BeerDuplicateCandidates(
  barcodeMatch: barcodeMatch,
  nameMatches: nameMatches,
  breweryMatches: const [],
  alreadySubmitted: alreadySubmitted,
  pendingBarcodeDuplicateExists: pendingBarcode,
);

void main() {
  group('picker options', () {
    test('loads breweries and styles', () async {
      final controller = _controller(FakeContributionRepository());
      await controller.loadOptions();

      expect(controller.breweryOptions.single.name, 'Hop House');
      expect(controller.styleOptions.map((s) => s.name), ['IPA', 'Stout']);
      expect(controller.optionsError, isNull);
      expect(controller.isLoadingOptions, isFalse);
    });

    test('a failure is exposed and retry recovers', () async {
      final catalog = catalogWithOptions()..getBeerStylesError = Exception('x');
      final controller = _controller(FakeContributionRepository(), catalog);
      await controller.loadOptions();
      expect(controller.optionsError, isNotNull);

      catalog.getBeerStylesError = null;
      await controller.loadOptions();
      expect(controller.optionsError, isNull);
      expect(controller.styleOptions, isNotEmpty);
    });
  });

  group('submit', () {
    test(
      'a clean check submits straight away and ends server-confirmed',
      () async {
        final repository = FakeContributionRepository();
        final controller = _controller(repository);

        await controller.submit(_input);

        expect(repository.callLog, ['checkBeer', 'submitBeer']);
        expect(controller.phase, SuggestPhase.submitted);
        expect(controller.submitted!.status, ContributionStatus.pending);
        expect(controller.block, isNull);
      },
    );

    test(
      'is not submitted until the backend answers (no optimistic success)',
      () async {
        final repository = FakeContributionRepository()
          ..submitGate = Completer<void>();
        final controller = _controller(repository);

        final future = controller.submit(_input);
        await Future<void>.delayed(Duration.zero);

        expect(controller.phase, SuggestPhase.submitting);
        expect(controller.submitted, isNull);

        repository.submitGate!.complete();
        await future;
        expect(controller.phase, SuggestPhase.submitted);
      },
    );

    test('a second submit while one is in flight is ignored', () async {
      final repository = FakeContributionRepository()
        ..submitGate = Completer<void>();
      final controller = _controller(repository);

      final first = controller.submit(_input);
      await Future<void>.delayed(Duration.zero);
      await controller.submit(_input); // ignored
      await controller.submit(_input); // ignored

      repository.submitGate!.complete();
      await first;

      expect(repository.callLog.where((c) => c == 'submitBeer'), hasLength(1));
      expect(repository.callLog.where((c) => c == 'checkBeer'), hasLength(1));
      expect(repository.history, hasLength(1));
    });

    test('nothing can be submitted again once it succeeded', () async {
      final repository = FakeContributionRepository();
      final controller = _controller(repository);
      await controller.submit(_input);
      await controller.submit(_input);
      expect(repository.submittedBeers, hasLength(1));
    });
  });

  group('hard blocks', () {
    test(
      'a catalog barcode owner blocks and offers the existing beer',
      () async {
        final repository = FakeContributionRepository()
          ..beerCandidates = _candidates(barcodeMatch: testCatalogBeer);
        final controller = _controller(repository);

        await controller.submit(_input);

        expect(controller.block, SuggestBlock.barcodeInCatalog);
        expect(controller.existingBeer!.id, 'beer-1');
        expect(controller.phase, SuggestPhase.editing);
        expect(repository.submittedBeers, isEmpty);
      },
    );

    test('the users own pending duplicate blocks', () async {
      final repository = FakeContributionRepository()
        ..beerCandidates = _candidates(alreadySubmitted: true);
      final controller = _controller(repository);

      await controller.submit(_input);

      expect(controller.block, SuggestBlock.alreadySubmitted);
      expect(repository.submittedBeers, isEmpty);
    });

    test('a raced barcode_in_catalog 409 on the POST is honored and resolves the owner', () async {
      final repository = FakeContributionRepository()
        ..submitBeerError = const ConflictApiException(
          message: 'x',
          statusCode: 409,
          code: 'barcode_in_catalog',
        );
      final catalog = catalogWithOptions()
        ..beersByBarcode['4006381333931'] = testCatalogBeer;
      final controller = _controller(repository, catalog);

      await controller.submit(_input);

      expect(controller.block, SuggestBlock.barcodeInCatalog);
      expect(controller.existingBeer!.id, 'beer-1');
      expect(controller.phase, SuggestPhase.editing);
    });

    test(
      'a raced 409 still blocks when the owner cannot be resolved',
      () async {
        final repository = FakeContributionRepository()
          ..submitBeerError = const ConflictApiException(
            message: 'x',
            statusCode: 409,
            code: 'barcode_in_catalog',
          );
        final catalog = catalogWithOptions()
          ..getBeerByBarcodeError = const NotFoundApiException(message: 'nf');
        final controller = _controller(repository, catalog);

        await controller.submit(_input);

        expect(controller.block, SuggestBlock.barcodeInCatalog);
        expect(controller.existingBeer, isNull);
      },
    );

    test('a raced already_submitted 409 blocks', () async {
      final repository = FakeContributionRepository()
        ..submitBeerError = const ConflictApiException(
          message: 'x',
          statusCode: 409,
          code: 'already_submitted',
        );
      final controller = _controller(repository);

      await controller.submit(_input);

      expect(controller.block, SuggestBlock.alreadySubmitted);
    });

    test('an unrecognized 409 code is a plain error, not a block', () async {
      final repository = FakeContributionRepository()
        ..submitBeerError = const ConflictApiException(
          message: 'x',
          statusCode: 409,
          code: 'something_new',
        );
      final controller = _controller(repository);

      await controller.submit(_input);

      expect(controller.block, isNull);
      expect(controller.error, isA<ConflictApiException>());
    });
  });

  group('non-blocking warnings', () {
    test('similar beers pause for confirmation without submitting', () async {
      final repository = FakeContributionRepository()
        ..beerCandidates = _candidates(nameMatches: [testCatalogBeer]);
      final controller = _controller(repository);

      await controller.submit(_input);

      expect(controller.phase, SuggestPhase.awaitingConfirmation);
      expect(controller.candidates!.nameMatches, hasLength(1));
      expect(controller.block, isNull);
      expect(repository.submittedBeers, isEmpty);
    });

    test(
      'another users pending barcode is a warning that still allows submitting',
      () async {
        final repository = FakeContributionRepository()
          ..beerCandidates = _candidates(pendingBarcode: true);
        final controller = _controller(repository);

        await controller.submit(_input);
        expect(controller.phase, SuggestPhase.awaitingConfirmation);
        expect(controller.candidates!.pendingBarcodeDuplicateExists, isTrue);
        expect(controller.block, isNull);

        await controller.confirmSubmit();

        expect(controller.phase, SuggestPhase.submitted);
        expect(repository.submittedBeers.single.officialName, 'New Beer');
      },
    );

    test('"Review" returns to editing and submits nothing', () async {
      final repository = FakeContributionRepository()
        ..beerCandidates = _candidates(nameMatches: [testCatalogBeer]);
      final controller = _controller(repository);
      await controller.submit(_input);

      controller.reviewAgain();

      expect(controller.phase, SuggestPhase.editing);
      expect(controller.candidates, isNull);
      expect(repository.submittedBeers, isEmpty);
    });

    test(
      'confirmSubmit does nothing unless a confirmation is pending',
      () async {
        final repository = FakeContributionRepository();
        final controller = _controller(repository);
        await controller.confirmSubmit();
        expect(repository.callLog, isEmpty);
      },
    );
  });

  group('failures', () {
    test(
      'a failed duplicate check surfaces the error and submits nothing',
      () async {
        final repository = FakeContributionRepository()
          ..checkBeerError = const NetworkApiException(message: 'offline');
        final controller = _controller(repository);

        await controller.submit(_input);

        expect(controller.error, isA<NetworkApiException>());
        expect(controller.phase, SuggestPhase.editing);
        expect(repository.submittedBeers, isEmpty);
      },
    );

    test('a failed submit surfaces the error and can be retried', () async {
      final repository = FakeContributionRepository()
        ..submitBeerError = const NetworkApiException(message: 'offline');
      final controller = _controller(repository);

      await controller.submit(_input);
      expect(controller.error, isA<NetworkApiException>());
      expect(controller.phase, SuggestPhase.editing);
      expect(controller.submitted, isNull);

      repository.submitBeerError = null;
      await controller.submit(_input);
      expect(controller.phase, SuggestPhase.submitted);
      expect(controller.error, isNull);
    });

    test(
      'clearFeedback drops a stale block/error but keeps the phase',
      () async {
        final repository = FakeContributionRepository()
          ..beerCandidates = _candidates(alreadySubmitted: true);
        final controller = _controller(repository);
        await controller.submit(_input);
        expect(controller.block, isNotNull);

        controller.clearFeedback();

        expect(controller.block, isNull);
        expect(controller.phase, SuggestPhase.editing);
      },
    );

    test('a controller disposed mid-request does not throw', () async {
      final repository = FakeContributionRepository()
        ..submitGate = Completer<void>();
      final controller = _controller(repository);

      final future = controller.submit(_input);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      repository.submitGate!.complete();

      await expectLater(future, completes);
    });
  });
}
