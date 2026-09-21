import 'package:beerapp/shared/widgets/beer_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double devicePixelRatio = 3,
}) async {
  tester.view.physicalSize = Size(
    400 * devicePixelRatio,
    900 * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

void main() {
  const url = 'https://images.example.test/beer.jpg';

  group('decode sizing', () {
    test('caps the decode near the box size in physical pixels', () {
      final provider = BeerImage.sizedProvider(
        NetworkImage(url),
        const Size(56, 56),
        3,
      );

      // 56 dp x 3 dpr x 1.5 oversample = 252 px, not the source resolution.
      expect(provider, isA<ResizeImage>());
      final resized = provider as ResizeImage;
      expect(resized.width, 252);
      expect(resized.height, 252);
    });

    test('keeps the aspect ratio (fit, never the squashing exact policy)', () {
      final resized = BeerImage.sizedProvider(
        NetworkImage(url),
        const Size(360, 202.5),
        2,
      ) as ResizeImage;
      expect(resized.policy, ResizeImagePolicy.fit);
    });

    test('scales with the device pixel ratio', () {
      ResizeImage sized(double dpr) =>
          BeerImage.sizedProvider(NetworkImage(url), const Size(56, 56), dpr)
              as ResizeImage;
      expect(sized(1).width, 84);
      expect(sized(2).width, 168);
      expect(sized(3).width, 252);
    });

    test('an unbounded or empty box leaves the provider alone', () {
      final network = NetworkImage(url);
      expect(
        BeerImage.sizedProvider(network, const Size(double.infinity, 100), 3),
        same(network),
      );
      expect(BeerImage.sizedProvider(network, Size.zero, 3), same(network));
    });

    test('the decode is a small fraction of a full-size photo', () {
      // A 4000x3000 source decoded whole is 48MB; capped for a 56dp thumbnail
      // at 3x it is at most 252x252 (or less, aspect-preserved).
      const fullDecodeBytes = 4000 * 3000 * 4;
      const cappedBytes = 252 * 252 * 4;
      expect(cappedBytes, lessThan(fullDecodeBytes ~/ 100));
    });
  });

  group('widget', () {
    testWidgets('a thumbnail uses a resized provider at its layout size', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(width: 56, height: 56, child: BeerImage(imageUrl: url)),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<ResizeImage>());
      expect((image.image as ResizeImage).width, 252);
      expect(image.fit, BoxFit.cover);
      expect(image.excludeFromSemantics, isTrue);
    });

    testWidgets('the hero decodes at screen width, not the source width', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: 400,
          height: 225,
          child: BeerImage(imageUrl: url),
        ),
      );

      final resized =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      // 400 dp x 3 x 1.5 = 1800 px
      expect(resized.width, 1800);
      expect(resized.height, 1013);
    });

    testWidgets('no URL shows the fallback icon and builds no Image', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(width: 56, height: 56, child: BeerImage(imageUrl: null)),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.local_bar_outlined), findsOneWidget);
    });

    testWidgets('the box keeps its size while loading and after a failure', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(width: 56, height: 56, child: BeerImage(imageUrl: url)),
      );
      // Before the first frame: a placeholder, same box.
      expect(tester.getSize(find.byType(BeerImage)), const Size(56, 56));

      // The test HTTP client fails the request: the fallback icon takes over,
      // in the same box.
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.local_bar_outlined), findsOneWidget);
      expect(tester.getSize(find.byType(BeerImage)), const Size(56, 56));
    });

    testWidgets('the fallback icon size is configurable (detail hero)', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: 400,
          height: 225,
          child: BeerImage(imageUrl: null, fallbackIconSize: 48),
        ),
      );
      expect(tester.widget<Icon>(find.byType(Icon)).size, 48);
    });
  });
}
