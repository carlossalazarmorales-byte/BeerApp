import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../domain/contribution_repository.dart';
import '../domain/models/contribution_input.dart';
import 'contribution_error_text.dart';
import 'contribution_validation.dart';
import 'suggest_beer_controller.dart';
import 'suggest_flow.dart';
import 'widgets/catalog_picker_field.dart';
import 'widgets/contribution_notices.dart';
import 'widgets/duplicate_warning_sheet.dart';

/// The suggest-a-beer form (`PRODUCT.md` §21: "search -> not found -> add
/// missing beer"). A suggestion is a private proposal -- submitting it never
/// adds a beer to the catalog and creates no log, favorite, wishlist entry or
/// achievement.
///
/// The brewery picker offers "Not listed": choosing it reveals a text field
/// that becomes `proposed_brewery_name`, so a beer can be suggested without
/// first suggesting its brewery separately.
class SuggestBeerScreen extends StatefulWidget {
  const SuggestBeerScreen({
    required this.contributionRepository,
    required this.catalogRepository,
    this.initialName,
    this.initialBarcode,
    super.key,
  });

  final ContributionRepository contributionRepository;
  final CatalogRepository catalogRepository;

  /// Prefill from a failed Discover search.
  final String? initialName;

  /// Prefill from a failed barcode scan.
  final String? initialBarcode;

  @override
  State<SuggestBeerScreen> createState() => _SuggestBeerScreenState();
}

class _SuggestBeerScreenState extends State<SuggestBeerScreen> {
  late final SuggestBeerController _controller = SuggestBeerController(
    contributions: widget.contributionRepository,
    catalog: widget.catalogRepository,
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  final TextEditingController _proposedBreweryController =
      TextEditingController();
  final TextEditingController _proposedStyleController =
      TextEditingController();
  final TextEditingController _abvController = TextEditingController();
  late final TextEditingController _barcodeController = TextEditingController(
    text: widget.initialBarcode,
  );

  String? _breweryValue;
  String? _styleValue = noneValue;
  bool _dirty = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    unawaited(_controller.loadOptions());
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _nameController.dispose();
    _proposedBreweryController.dispose();
    _proposedStyleController.dispose();
    _abvController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.phase == SuggestPhase.awaitingConfirmation && !_sheetOpen) {
      unawaited(_showWarnings());
    }
  }

  Future<void> _showWarnings() async {
    final candidates = _controller.candidates;
    if (candidates == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    _sheetOpen = true;
    final confirmed = await DuplicateWarningSheet.show(
      context,
      showPendingBarcodeWarning: candidates.pendingBarcodeDuplicateExists,
      sections: [
        if (candidates.nameMatches.isNotEmpty)
          DuplicateSection(
            title: l10n.contributionDuplicateSimilarBeers,
            items: [
              for (final beer in candidates.nameMatches)
                DuplicateItem(
                  title: beer.officialName,
                  subtitle: beer.abv == null ? null : '${beer.abv}%',
                  onView: () => context.push(AppRoutes.beerDetailPath(beer.id)),
                ),
            ],
          ),
        if (candidates.breweryMatches.isNotEmpty)
          DuplicateSection(
            title: l10n.contributionDuplicateSimilarBreweries,
            items: [
              for (final brewery in candidates.breweryMatches)
                DuplicateItem(title: brewery.name, subtitle: brewery.city),
            ],
          ),
      ],
    );
    _sheetOpen = false;
    if (!mounted) return;
    if (confirmed == true) {
      unawaited(_controller.confirmSubmit());
    } else {
      _controller.reviewAgain();
    }
  }

  BeerContributionInput _buildInput() {
    final proposedBrewery = _breweryValue == notListedValue;
    final proposedStyle = _styleValue == notListedValue;
    final hasCanonicalStyle =
        _styleValue != null &&
        _styleValue != noneValue &&
        _styleValue != notListedValue;
    return BeerContributionInput(
      officialName: _nameController.text.trim(),
      breweryId: proposedBrewery ? null : _breweryValue,
      proposedBreweryName: proposedBrewery
          ? trimmedOrNull(_proposedBreweryController.text)
          : null,
      styleId: hasCanonicalStyle ? _styleValue : null,
      proposedStyleName: proposedStyle
          ? trimmedOrNull(_proposedStyleController.text)
          : null,
      abv: parseAbv(_abvController.text),
      barcode: trimmedOrNull(_barcodeController.text),
    );
  }

  void _onSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    unawaited(_controller.submit(_buildInput()));
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.contributionDiscardTitle),
        content: Text(l10n.contributionDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.contributionDiscardCancelAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.contributionDiscardConfirmAction),
          ),
        ],
      ),
    );
    if (discard == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final submitted = _controller.phase == SuggestPhase.submitted;
        return PopScope(
          canPop: !_dirty || submitted,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmDiscard());
          },
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.suggestBeerScreenTitle)),
            body: _buildBody(context, l10n, submitted),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    bool submitted,
  ) {
    if (submitted) {
      return ContributionSubmittedView(onDone: () => context.pop(true));
    }
    final noOptions =
        _controller.breweryOptions.isEmpty && _controller.styleOptions.isEmpty;
    if (_controller.isLoadingOptions && noOptions) return const LoadingState();
    if (_controller.optionsError != null && noOptions) {
      return ErrorState(
        message: contributionErrorText(context, _controller.optionsError!),
        onRetry: _controller.loadOptions,
      );
    }

    final block = _controller.block;
    final error = _controller.error;
    final existingBeer = _controller.existingBeer;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        onChanged: () {
          // setState (not a bare assignment) so PopScope.canPop is rebuilt
          // with the new value right away -- typing into a field alone would
          // otherwise leave it stale until something else rebuilt.
          if (!_dirty) setState(() => _dirty = true);
          _controller.clearFeedback();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (block != null) ...[
              ContributionBlockedBanner(
                message: block == SuggestBlock.barcodeInCatalog
                    ? l10n.contributionErrorBarcodeInCatalog
                    : l10n.contributionErrorAlreadySubmitted,
                actionLabel:
                    block == SuggestBlock.barcodeInCatalog &&
                        existingBeer != null
                    ? l10n.contributionViewExistingBeerAction
                    : null,
                onAction: existingBeer == null
                    ? null
                    : () => context.push(
                        AppRoutes.beerDetailPath(existingBeer.id),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              controller: _nameController,
              hintText: l10n.suggestBeerNameHint,
              textInputAction: TextInputAction.next,
              validator: (value) => validateRequiredText(l10n, value),
            ),
            const SizedBox(height: AppSpacing.md),
            CatalogPickerField(
              hint: l10n.suggestBeerBreweryLabel,
              options: {
                for (final b in _controller.breweryOptions) b.id: b.name,
              },
              value: _breweryValue,
              notListedLabel: l10n.contributionOptionNotListed,
              onChanged: (value) => setState(() => _breweryValue = value),
              validator: (value) => value == null
                  ? l10n.contributionValidationBreweryRequired
                  : null,
            ),
            if (_breweryValue == notListedValue) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _proposedBreweryController,
                hintText: l10n.suggestBeerProposedBreweryHint,
                validator: (value) => validateRequiredText(l10n, value),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            CatalogPickerField(
              hint: l10n.suggestBeerStyleLabel,
              options: {for (final s in _controller.styleOptions) s.id: s.name},
              value: _styleValue,
              noneLabel: l10n.contributionOptionNoStyle,
              notListedLabel: l10n.contributionOptionNotListed,
              onChanged: (value) => setState(() => _styleValue = value),
            ),
            if (_styleValue == notListedValue) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _proposedStyleController,
                hintText: l10n.suggestBeerProposedStyleHint,
                validator: (value) => validateRequiredText(
                  l10n,
                  value,
                  maxLength: maxShortTextLength,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _abvController,
              hintText: l10n.suggestBeerAbvHint,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) => validateOptionalAbv(l10n, value),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _barcodeController,
              hintText: l10n.suggestBeerBarcodeHint,
              keyboardType: TextInputType.number,
              validator: (value) => validateOptionalBarcode(l10n, value),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (error != null) ...[
              ContributionErrorText(contributionErrorText(context, error)),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_controller.isBusy) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: AppSpacing.md),
            ],
            PrimaryButton(
              label: l10n.contributionSubmitAction,
              onPressed: _controller.isBusy ? null : _onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
