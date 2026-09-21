import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/components/states/error_state.dart';
import '../../../design_system/components/states/inline_progress.dart';
import '../../../design_system/components/states/loading_state.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/domain/catalog_repository.dart';
import '../domain/contribution_repository.dart';
import '../domain/models/contribution_input.dart';
import 'contribution_error_text.dart';
import 'contribution_validation.dart';
import 'suggest_brewery_controller.dart';
import 'suggest_flow.dart';
import 'widgets/catalog_picker_field.dart';
import 'widgets/contribution_notices.dart';
import 'widgets/duplicate_warning_sheet.dart';

/// The suggest-a-brewery form -- an independent feature (ROADMAP Phase 13's
/// "Brewery submission"), not a prerequisite for suggesting a beer. Like a
/// beer suggestion it is a private proposal: it never creates a catalog
/// brewery.
///
/// No coordinates, website or description are collected; a moderator
/// verifies and geocodes.
class SuggestBreweryScreen extends StatefulWidget {
  const SuggestBreweryScreen({
    required this.contributionRepository,
    required this.catalogRepository,
    super.key,
  });

  final ContributionRepository contributionRepository;
  final CatalogRepository catalogRepository;

  @override
  State<SuggestBreweryScreen> createState() => _SuggestBreweryScreenState();
}

class _SuggestBreweryScreenState extends State<SuggestBreweryScreen> {
  late final SuggestBreweryController _controller = SuggestBreweryController(
    contributions: widget.contributionRepository,
    catalog: widget.catalogRepository,
  );
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _proposedCountryController =
      TextEditingController();
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _countryValue;
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
    _proposedCountryController.dispose();
    _regionController.dispose();
    _cityController.dispose();
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
      showPendingBarcodeWarning: false,
      sections: [
        DuplicateSection(
          title: l10n.contributionDuplicateSimilarBreweries,
          items: [
            for (final brewery in candidates.nameMatches)
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

  BreweryContributionInput _buildInput() {
    final proposedCountry = _countryValue == notListedValue;
    return BreweryContributionInput(
      name: _nameController.text.trim(),
      countryId: proposedCountry ? null : _countryValue,
      proposedCountryName: proposedCountry
          ? trimmedOrNull(_proposedCountryController.text)
          : null,
      region: trimmedOrNull(_regionController.text),
      city: trimmedOrNull(_cityController.text),
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
            appBar: AppBar(title: Text(l10n.suggestBreweryScreenTitle)),
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
    final noOptions = _controller.countryOptions.isEmpty;
    if (_controller.isLoadingOptions && noOptions) return const LoadingState();
    if (_controller.optionsError != null && noOptions) {
      return ErrorState(
        message: contributionErrorText(context, _controller.optionsError!),
        onRetry: _controller.loadOptions,
      );
    }

    final error = _controller.error;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        onChanged: () {
          // See SuggestBeerScreen: setState keeps PopScope.canPop current.
          if (!_dirty) setState(() => _dirty = true);
          _controller.clearFeedback();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_controller.block != null) ...[
              ContributionBlockedBanner(
                message: l10n.contributionErrorAlreadySubmitted,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              controller: _nameController,
              hintText: l10n.suggestBreweryNameHint,
              textInputAction: TextInputAction.next,
              validator: (value) => validateRequiredText(l10n, value),
            ),
            const SizedBox(height: AppSpacing.md),
            CatalogPickerField(
              hint: l10n.suggestBreweryCountryLabel,
              options: {
                for (final c in _controller.countryOptions) c.id: c.name,
              },
              value: _countryValue,
              notListedLabel: l10n.contributionOptionNotListed,
              onChanged: (value) => setState(() => _countryValue = value),
              validator: (value) => value == null
                  ? l10n.contributionValidationCountryRequired
                  : null,
            ),
            if (_countryValue == notListedValue) ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _proposedCountryController,
                hintText: l10n.suggestBreweryProposedCountryHint,
                validator: (value) => validateRequiredText(
                  l10n,
                  value,
                  maxLength: maxShortTextLength,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _regionController,
              hintText: l10n.suggestBreweryRegionHint,
              validator: (value) => validateOptionalText(l10n, value),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _cityController,
              hintText: l10n.suggestBreweryCityHint,
              validator: (value) => validateOptionalText(l10n, value),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (error != null) ...[
              ContributionErrorText(contributionErrorText(context, error)),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_controller.isBusy) ...[
              const InlineProgressBar(),
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
