import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';

/// A catalog beer's picture, filling whatever box it is given.
///
/// Used for the list/collection thumbnails and the detail hero. Compared with a
/// bare `Image.network` it:
///
/// - **decodes at display size.** Catalog images are stored at their source
///   resolution; decoding a 12-megapixel photo to draw a 56dp thumbnail costs
///   ~48MB of memory per image. The decode is capped (via [ResizeImage], aspect
///   ratio preserved) at [decodeOversample] x the box's physical pixel size, so
///   `BoxFit.cover` still has enough pixels on the shorter side for typical
///   (up to roughly 3:2) photos;
/// - **shows a stable placeholder** in the same tonal colour as the fallback
///   until the first frame, so the box never flashes empty or changes size;
/// - **falls back to the icon** when there is no URL or the image fails to load.
///
/// The picture is decorative (the beer's name is always next to it), so it adds
/// nothing to the semantics tree. Image URLs and storage are untouched, and the
/// HTTP/disk caching is Flutter's built-in image cache -- no extra package.
class BeerImage extends StatelessWidget {
  const BeerImage({
    required this.imageUrl,
    super.key,
    this.fallbackIconSize = 24,
  });

  final String? imageUrl;
  final double fallbackIconSize;

  /// How many physical pixels per box pixel to decode. Above 1 so that
  /// `BoxFit.cover` on a non-square picture is not under-sampled.
  static const double decodeOversample = 1.5;

  /// [provider], limited to a decode of about [box] x [devicePixelRatio] x
  /// [decodeOversample]. An unbounded box (no size to decode for) leaves the
  /// provider untouched.
  @visibleForTesting
  static ImageProvider sizedProvider(
    ImageProvider provider,
    Size box,
    double devicePixelRatio,
  ) {
    if (!box.width.isFinite || !box.height.isFinite) return provider;
    if (box.isEmpty) return provider;
    final scale = devicePixelRatio * decodeOversample;
    return ResizeImage(
      provider,
      width: (box.width * scale).ceil(),
      height: (box.height * scale).ceil(),
      // `fit` keeps the aspect ratio and never upscales; the default (exact)
      // would squash the picture to the box shape.
      policy: ResizeImagePolicy.fit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null) return _Fallback(iconSize: fallbackIconSize);

    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image(
          image: sizedProvider(
            NetworkImage(url),
            constraints.biggest,
            devicePixelRatio,
          ),
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded || frame != null) return child;
            return const ColoredBox(color: AppColors.secondaryContainer);
          },
          errorBuilder: (context, error, stackTrace) =>
              _Fallback(iconSize: fallbackIconSize),
        );
      },
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.secondaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.local_bar_outlined,
        size: iconSize,
        color: AppColors.secondary,
      ),
    );
  }
}
