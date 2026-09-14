import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/onboarding/age_gate_scope.dart';
import '../../../design_system/components/buttons/primary_button.dart';
import '../../../design_system/components/buttons/secondary_button.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

/// Landing screen and the adult-audience acknowledgement gate. This is the
/// only route reachable before the checkbox is confirmed — see the
/// router's redirect logic, which forces every other route back here until
/// [AgeGateScope]'s controller reports acknowledged. That is the actual
/// enforcement; disabling the buttons here is only a visual affordance.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _ageChecked = false;
  bool _isSigningInWithGoogle = false;
  String? _errorMessage;

  Future<void> _onGooglePressed() async {
    setState(() {
      _isSigningInWithGoogle = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.signInWithGoogle();
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _errorMessage = failure.code == AuthFailureCode.providerNotConfigured
            ? l10n.googleSignInUnavailableError
            : l10n.authGenericError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context).authGenericError;
      });
    } finally {
      if (mounted) setState(() => _isSigningInWithGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ageGate = AgeGateScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.appTitle,
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              CheckboxListTile(
                value: _ageChecked,
                onChanged: (value) =>
                    setState(() => _ageChecked = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.welcomeAgeStatement,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
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
                label: l10n.welcomeCreateAccount,
                onPressed: _ageChecked
                    ? () async {
                        await ageGate.acknowledge();
                        if (context.mounted) context.go(AppRoutes.signUp);
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: l10n.welcomeSignIn,
                onPressed: _ageChecked
                    ? () async {
                        await ageGate.acknowledge();
                        if (context.mounted) context.go(AppRoutes.signIn);
                      }
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: _isSigningInWithGoogle
                    ? l10n.loadingStateMessage
                    : l10n.continueWithGoogle,
                onPressed: (_ageChecked && !_isSigningInWithGoogle)
                    ? () async {
                        await ageGate.acknowledge();
                        await _onGooglePressed();
                      }
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
