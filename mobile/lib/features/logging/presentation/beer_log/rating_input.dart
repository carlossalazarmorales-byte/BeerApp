import 'package:flutter/material.dart';

import '../../../../design_system/tokens/app_colors.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// A row of five tappable stars for the optional 1-5 beer-log rating.
/// Nullable by design -- tapping the currently-selected star clears the
/// rating back to `null` ("not all fields mandatory", PRODUCT.md §12), and
/// no value is ever pre-selected/inferred.
class RatingInput extends StatelessWidget {
  const RatingInput({required this.rating, required this.onChanged, super.key});

  final int? rating;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        final filled = rating != null && value <= rating!;
        return Semantics(
          label: l10n.beerLogRatingStarSemanticLabel(value),
          button: true,
          selected: filled,
          child: IconButton(
            onPressed: () => onChanged(rating == value ? null : value),
            icon: Icon(
              filled ? Icons.star : Icons.star_border,
              color: AppColors.primary,
            ),
          ),
        );
      }),
    );
  }
}
