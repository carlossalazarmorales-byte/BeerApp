import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/profile.dart';
import '../../auth/domain/profile_repository.dart';

/// Lets an already-complete profile edit its username and display name.
/// Reached only from `ProfileScreen`'s "Edit Profile" card, so
/// `AuthScope.of(context).profile` is always non-null here in practice.
///
/// Both fields are saved together via a single
/// `ProfileRepository.updateEditableProfile` call, never two independent
/// writes -- see docs/DECISIONS.md for why (a duplicate-username failure
/// must never leave display_name partially changed).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.profileRepository, super.key});

  final ProfileRepository profileRepository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSubmitting = false;
  String? _usernameErrorMessage;
  bool _fieldsPrefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthScope.of(context) establishes an InheritedWidget dependency,
    // which cannot be done from initState -- didChangeDependencies is the
    // correct place. Guarded to run exactly once, so a later rebuild (e.g.
    // after AuthScope notifies from an unrelated change) never clobbers
    // text the user has already started editing.
    if (!_fieldsPrefilled) {
      final profile = AuthScope.of(context).profile;
      _usernameController.text = profile?.username ?? '';
      _displayNameController.text = profile?.displayName ?? '';
      _fieldsPrefilled = true;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _usernameErrorMessage = null;
    });
    try {
      // Exactly one repository call -- never a separate username write
      // followed by a separate display-name write.
      await widget.profileRepository.updateEditableProfile(
        username: _usernameController.text,
        displayName: _displayNameController.text,
      );
      if (!mounted) return;
      await AuthScope.of(context).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.editProfileSuccessMessage)));
      Navigator.of(context).pop();
    } on ProfileFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _usernameErrorMessage = failure.code == ProfileFailureCode.usernameTaken
            ? l10n.usernameTakenError
            : l10n.usernameInvalidError;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileScreenTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _usernameController,
                  hintText: l10n.usernameHint,
                  leadingIcon: Icons.person_outline,
                  errorText: _usernameErrorMessage,
                  validator: (value) {
                    final normalized = (value ?? '').trim().toLowerCase();
                    return usernamePattern.hasMatch(normalized)
                        ? null
                        : l10n.usernameInvalidError;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _displayNameController,
                  hintText: l10n.displayNameHint,
                  leadingIcon: Icons.badge_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _isSubmitting
                      ? l10n.loadingStateMessage
                      : l10n.editProfileSaveAction,
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
