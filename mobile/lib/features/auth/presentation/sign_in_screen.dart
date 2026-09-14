import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/buttons/secondary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      await widget.authRepository.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // Success: the router reacts to the AuthController's status change —
      // no explicit navigation here.
    } on AuthFailure {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.authInvalidCredentialsError);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = l10n.authGenericError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.signInWithGoogle();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            failure.code == AuthFailureCode.providerNotConfigured
            ? l10n.googleSignInUnavailableError
            : l10n.authGenericError,
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
      appBar: AppBar(title: Text(l10n.signInTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _emailController,
                  hintText: l10n.emailHint,
                  leadingIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => (value == null || !value.contains('@'))
                      ? l10n.emailInvalidError
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _passwordController,
                  hintText: l10n.passwordHint,
                  leadingIcon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: (value) => (value == null || value.isEmpty)
                      ? l10n.passwordRequiredError
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.go(AppRoutes.forgotPassword),
                    child: Text(l10n.signInForgotPassword),
                  ),
                ),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PrimaryButton(
                  label: _isSubmitting
                      ? l10n.loadingStateMessage
                      : l10n.signInSubmit,
                  onPressed: _isSubmitting ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: l10n.continueWithGoogle,
                  onPressed: _isSubmitting ? null : _submitGoogle,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: () => context.go(AppRoutes.signUp),
                  child: Text(l10n.signInNoAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
