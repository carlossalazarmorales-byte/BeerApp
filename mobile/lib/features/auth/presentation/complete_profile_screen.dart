import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

/// Shown only in `AppAuthStatus.authenticatedIncompleteProfile` — i.e. only
/// for OAuth (Google) sign-ups, which cannot supply a BeerApp username
/// before `auth.users` is created. The router allows no other route until
/// this succeeds; there is deliberately no skip/dismiss action.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({required this.profileRepository, super.key});

  final ProfileRepository profileRepository;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.profileRepository.setUsername(_usernameController.text);
      if (!mounted) return;
      await AuthScope.of(context).refreshProfile();
      // No explicit navigation: the router's redirect reacts to the
      // AuthController status change once refreshProfile() notifies.
    } on ProfileFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _errorMessage = failure.code == ProfileFailureCode.usernameTaken
            ? l10n.usernameTakenError
            : l10n.usernameInvalidError,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.authGenericError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.completeProfileTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.completeProfileDescription,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _usernameController,
                  hintText: l10n.usernameHint,
                  leadingIcon: Icons.person_outline,
                  errorText: _errorMessage,
                  validator: (value) {
                    final normalized = (value ?? '').trim().toLowerCase();
                    return usernamePattern.hasMatch(normalized)
                        ? null
                        : l10n.usernameInvalidError;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _isSubmitting
                      ? l10n.loadingStateMessage
                      : l10n.completeProfileSubmit,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
