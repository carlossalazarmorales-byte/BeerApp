import 'package:flutter/material.dart';

import '../../design_system/tokens/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'beer_image.dart';

/// [BeerImage] plus the shared locked/unlocked visual treatment: a beer is
/// "unlocked" once the current user has at least one log for it.
///
/// UNLOCKED (the default -- unmigrated callers behave exactly like a bare
/// [BeerImage]): the picture is shown normally.
///
/// LOCKED: the picture is grayscale (never blurred, never heavily
/// opaque -- it must stay clearly visible) with a small lock badge in the
/// corner, and an accessible label announces the state. The tile itself
/// stays fully tappable; only the image's presentation changes.
///
/// One shared widget rather than each screen inventing its own dimming
/// logic -- used by Discover's `BeerListTile`, Collection's `CollectionTile`
/// and Beer Detail's hero image.
class LockableBeerImage extends StatelessWidget {
  const LockableBeerImage({
    required this.imageUrl,
    this.isUnlocked = true,
    this.fallbackIconSize = 24,
    super.key,
  });

  final String? imageUrl;
  final bool isUnlocked;
  final double fallbackIconSize;

  /// Luminance-preserving grayscale (Rec. 709 coefficients) -- desaturates
  /// without darkening, so the picture "mutes" rather than looks dimmed.
  static const List<double> _grayscaleMatrix = [
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  Widget build(BuildContext context) {
    final image = BeerImage(
      imageUrl: imageUrl,
      fallbackIconSize: fallbackIconSize,
    );
    if (isUnlocked) return image;

    return Semantics(
      label: AppLocalizations.of(context).beerLockedSemanticLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
            child: image,
          ),
          const Positioned(right: 4, bottom: 4, child: _LockBadge()),
        ],
      ),
    );
  }
}

class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // Redundant with LockableBeerImage's own Semantics label above.
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.onSurface.withValues(alpha: 0.65),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock, size: 12, color: AppColors.surface),
      ),
    );
  }
}
