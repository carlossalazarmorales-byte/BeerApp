import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_repository.dart';

/// Matches the DB CHECK constraint on `profiles.username` — kept in sync
/// manually since Dart can't share a regex with Postgres directly. The
/// database constraint remains the actual source of truth (see
/// supabase/migrations); this is client-side UX only.
final RegExp _usernamePattern = RegExp(r'^[a-z0-9_]{3,20}$');

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      await widget.authRepository.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      context.go(AppRoutes.checkEmail);
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
      appBar: AppBar(title: Text(l10n.signUpTitle)),
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
                  controller: _usernameController,
                  hintText: l10n.usernameHint,
                  leadingIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final normalized = (value ?? '').trim().toLowerCase();
                    return _usernamePattern.hasMatch(normalized)
                        ? null
                        : l10n.usernameInvalidError;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _passwordController,
                  hintText: l10n.passwordHint,
                  leadingIcon: Icons.lock_outline,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => (value == null || value.length < 8)
                      ? l10n.passwordTooShortError
                      : null,
                ),
                const SizedBox(height: AppSpacing.lg),
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
                      : l10n.signUpSubmit,
                  onPressed: _isSubmitting ? null : _submit,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton(
                  onPressed: () => context.go(AppRoutes.signIn),
                  child: Text(l10n.signUpHaveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
