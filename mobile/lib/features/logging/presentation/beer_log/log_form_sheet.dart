import 'package:flutter/material.dart';

import '../../../../core/auth/auth_scope.dart';
import '../../../../design_system/components/buttons/primary_button.dart';
import '../../../../design_system/components/inputs/app_text_field.dart';
import '../../../../design_system/tokens/app_spacing.dart';
import '../../../../design_system/tokens/app_typography.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/beer_log.dart';
import '../../domain/models/beer_log_input.dart';
import '../beer_log_error_text.dart';
import 'beer_log_controller.dart';
import 'rating_input.dart';

/// Single expandable bottom sheet covering both the quick-log path (rating,
/// then submit) and the detailed-log path (an "Add details" expansion for
/// review/serving note/price+currency/venue/serving volume) -- one form
/// satisfies both ROADMAP.md Phase 6 tasks rather than two separate flows.
///
/// Also doubles as the edit form when [existing] is supplied.
class LogFormSheet extends StatefulWidget {
  const LogFormSheet({required this.controller, this.existing, super.key});

  final BeerLogController controller;
  final BeerLog? existing;

  static Future<bool?> show(
    BuildContext context, {
    required BeerLogController controller,
    BeerLog? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          LogFormSheet(controller: controller, existing: existing),
    );
  }

  @override
  State<LogFormSheet> createState() => _LogFormSheetState();
}

class _LogFormSheetState extends State<LogFormSheet> {
  int? _rating;
  bool _detailsExpanded = false;
  bool _isSubmitting = false;

  /// Guards the one-time preferred-currency seed below so it never
  /// reapplies on a later rebuild (e.g. after `setState`) and never
  /// overwrites a user's own edit.
  bool _preferredCurrencySeeded = false;

  late final TextEditingController _reviewController;
  late final TextEditingController _servingNoteController;
  late final TextEditingController _priceController;
  late final TextEditingController _currencyController;
  late final TextEditingController _venueController;
  late final TextEditingController _servingVolumeController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _rating = existing?.rating;
    _reviewController = TextEditingController(text: existing?.review);
    _servingNoteController = TextEditingController(text: existing?.servingNote);
    _priceController = TextEditingController(
      text: existing?.price == null
          ? null
          : existing!.price!.toStringAsFixed(2),
    );
    _currencyController = TextEditingController(text: existing?.currency);
    _venueController = TextEditingController(text: existing?.venueName);
    _servingVolumeController = TextEditingController(
      text: existing?.servingVolumeMl?.toString(),
    );
    _detailsExpanded =
        existing != null &&
        (existing.review != null ||
            existing.servingNote != null ||
            existing.price != null ||
            existing.venueName != null ||
            existing.servingVolumeMl != null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthScope.of(context) needs an inherited-widget lookup, which isn't
    // reliably available in initState -- didChangeDependencies is the
    // correct place. Seeds the currency field from the signed-in user's
    // preferred_currency exactly once: only for a brand-new log (never an
    // edit of an existing one, whose stored currency must never be
    // overwritten), and only if the field is still empty at that moment
    // (so a user who already typed something, or a later rebuild, never
    // gets it silently reapplied/clobbered).
    if (widget.existing == null &&
        !_preferredCurrencySeeded &&
        _currencyController.text.isEmpty) {
      final preferred = AuthScope.of(context).profile?.preferredCurrency;
      if (preferred != null) {
        _currencyController.text = preferred;
      }
      _preferredCurrencySeeded = true;
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _servingNoteController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _venueController.dispose();
    _servingVolumeController.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final review = _trimmedOrNull(_reviewController);
    final servingNote = _trimmedOrNull(_servingNoteController);
    final priceText = _trimmedOrNull(_priceController);
    final currency = _trimmedOrNull(_currencyController)?.toUpperCase();
    final venueName = _trimmedOrNull(_venueController);
    final volumeText = _trimmedOrNull(_servingVolumeController);
    final price = priceText == null ? null : double.tryParse(priceText);
    final servingVolumeMl = volumeText == null
        ? null
        : int.tryParse(volumeText);

    final existing = widget.existing;
    final bool success;
    if (existing == null) {
      success = await widget.controller.submitCreate(
        BeerLogCreateInput(
          beerId: widget.controller.beerId,
          rating: _rating,
          review: review,
          servingNote: servingNote,
          price: price,
          currency: currency,
          venueName: venueName,
          servingVolumeMl: servingVolumeMl,
        ),
      );
    } else {
      success = await widget.controller.submitUpdate(
        existing.id,
        BeerLogUpdateInput(
          rating: _rating,
          review: review,
          servingNote: servingNote,
          price: price,
          currency: currency,
          venueName: venueName,
          servingVolumeMl: servingVolumeMl,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    final error = widget.controller.error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? AppLocalizations.of(context).beerLogErrorGeneric
              : beerLogErrorText(context, error),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null
                  ? l10n.beerLogFormTitleCreate
                  : l10n.beerLogFormTitleEdit,
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.beerLogRatingLabel, style: AppTypography.bodySmall),
            RatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_detailsExpanded)
              TextButton(
                onPressed: () => setState(() => _detailsExpanded = true),
                child: Text(l10n.beerLogAddDetailsAction),
              ),
            if (_detailsExpanded) ...[
              AppTextField(
                controller: _reviewController,
                hintText: l10n.beerLogReviewHint,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _servingNoteController,
                hintText: l10n.beerLogServingNoteHint,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _servingVolumeController,
                hintText: l10n.beerLogServingVolumeLabel,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _priceController,
                      hintText: l10n.beerLogPriceHint,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _currencyController,
                      hintText: l10n.beerLogCurrencyHint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _venueController,
                hintText: l10n.beerLogVenueHint,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: l10n.beerLogSaveAction,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
