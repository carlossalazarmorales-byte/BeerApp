import 'package:beerapp/features/catalog/domain/models/paged_result.dart';
import 'package:beerapp/features/collection/presentation/collection_controller.dart';
import 'package:beerapp/features/collection/presentation/collection_filter_sheet.dart';
import 'package:beerapp/l10n/generated/app_localizations.dart';
import 'package:beerapp/shared/collection_refresh_signal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_catalog_repository.dart';
import '../../fakes/fake_collection_repository.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Future<CollectionController> _controllerWithStyleOption() async {
  final repository = FakeCollectionRepository()
    ..loggedByPage[1] = const PagedResult(
      items: [],
      page: 1,
      pageSize: 20,
      total: 0,
    );
  final controller = CollectionController(
    repository: repository,
    catalogRepository: FakeCatalogRepository(),
    refreshSignal: CollectionRefreshSignal(),
  );
  await controller.loadInitial();
  controller.styleNames = {'style-1': 'Stout'};
  repository.callLog.clear();
  return controller;
}

Future<void> _openSheet(
  WidgetTester tester,
  CollectionController controller,
) async {
  await tester.pumpWidget(
    _wrap(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => CollectionFilterSheet(controller: controller),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'dismissing the sheet without applying leaves filters unchanged and triggers no reload',
    (tester) async {
      final controller = await _controllerWithStyleOption();
      await _openSheet(tester, controller);

      await tester.tap(find.text('Stout'));
      await tester.pumpAndSettle();

      // Dismiss by tapping the scrim, not "Show results".
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(controller.appliedStyleId, isNull);
    },
  );

  testWidgets(
    'tapping "Show results" applies the draft selection and reloads once',
    (tester) async {
      final controller = await _controllerWithStyleOption();
      await _openSheet(tester, controller);

      await tester.tap(find.text('Stout'));
      await tester.tap(find.text('Show results'));
      await tester.pumpAndSettle();

      expect(controller.appliedStyleId, 'style-1');
    },
  );

  testWidgets('"Clear all" resets the in-progress draft before it is applied', (
    tester,
  ) async {
    final controller = await _controllerWithStyleOption();
    await controller.applyFilters(styleId: 'style-1');
    await _openSheet(tester, controller);

    await tester.tap(find.text('Clear all'));
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    expect(controller.appliedStyleId, isNull);
  });
}
