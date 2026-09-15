import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/inputs/app_text_field.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Reachable only while `AuthController.passwordRecoveryPending` is true
/// (the router enforces this) — i.e. only right after the user taps a
/// password-reset email link, never by direct navigation.
///
/// KNOWN LIMITATION (upstream, not fixable from application code): if the
/// app is fully force-closed (not just backgrounded) when the recovery
/// link is tapped, supabase_flutter processes the deep link as part of
/// `Supabase.initialize()` itself, before any app-level `onAuthStateChange`
/// listener can be attached — so the `passwordRecovery` event, and
/// therefore this screen, can be missed on a cold start specifically. The
/// user still ends up validly signed in as themselves (no security issue),
/// just not routed here. Documented upstream:
/// https://github.com/supabase/supabase-flutter/issues/937. Warm start
/// (app already running/backgrounded) is unaffected and works correctly.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
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
      await widget.authRepository.updatePassword(_passwordController.text);
      if (!mounted) return;
      await AuthScope.of(context).completePasswordReset();
      // No explicit navigation: clearing passwordRecoveryPending lets the
      // router's normal auth-status rules take over.
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(
        () => _errorMessage = failure.code == AuthFailureCode.samePassword
            ? l10n.passwordSameAsCurrentError
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
      appBar: AppBar(title: Text(l10n.resetPasswordTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _passwordController,
                  hintText: l10n.passwordHint,
                  leadingIcon: Icons.lock_outline,
                  obscureText: true,
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
                      : l10n.resetPasswordSubmit,
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
