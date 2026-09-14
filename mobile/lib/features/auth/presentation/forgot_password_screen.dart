import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/buttons/secondary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;

  /// Shown after any submit attempt — identical whether the email exists
  /// or not, and even (deliberately) on most failures, so this screen
  /// never reveals account existence. See the plan's Security review.
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.authRepository.sendPasswordResetEmail(
        _emailController.text.trim(),
      );
    } catch (_) {
      // Intentionally swallowed: the confirmation message below is shown
      // regardless of outcome, to avoid revealing whether the email exists.
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _submitted
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.forgotPasswordConfirmation,
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SecondaryButton(
                      label: l10n.forgotPasswordBackToSignIn,
                      onPressed: () => context.go(AppRoutes.signIn),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.forgotPasswordDescription,
                        style: AppTypography.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _emailController,
                        hintText: l10n.emailHint,
                        leadingIcon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) =>
                            (value == null || !value.contains('@'))
                            ? l10n.emailInvalidError
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      PrimaryButton(
                        label: _isSubmitting
                            ? l10n.loadingStateMessage
                            : l10n.forgotPasswordSubmit,
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
