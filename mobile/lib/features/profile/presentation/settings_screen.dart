import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../core/config/legal_config.dart';
import '../../../core/links/external_link_opener.dart';
import '../../../core/locale/locale_scope.dart';
import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/components/states/inline_progress.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/currency/iso_currencies.dart';
import '../../../shared/widgets/placeholder_screen.dart';
import '../../auth/domain/account_repository.dart';
import '../../auth/domain/auth_repository.dart';
import '../../auth/domain/profile.dart';
import '../../auth/domain/profile_repository.dart';

/// Currency, language and account-lifecycle settings. Reached only from
/// `ProfileScreen`'s "Settings" card.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.profileRepository,
    required this.authRepository,
    required this.accountRepository,
    this.legalConfig,
    this.linkOpener,
    super.key,
  });

  final ProfileRepository profileRepository;
  final AuthRepository authRepository;
  final AccountRepository accountRepository;

  /// Where the Privacy Policy / Terms live. Defaults to the build-time
  /// `LEGAL_PRIVACY_URL` / `LEGAL_TERMS_URL`; injectable for tests.
  final LegalConfig? legalConfig;

  /// Opens a legal document in the system browser. Defaults to url_launcher;
  /// injectable for tests.
  final ExternalLinkOpener? linkOpener;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final LegalConfig _legalConfig =
      widget.legalConfig ?? LegalConfig.fromEnvironment();
  late final ExternalLinkOpener _linkOpener =
      widget.linkOpener ?? const UrlLauncherLinkOpener();

  bool _isSavingCurrency = false;
  bool _isSendingPasswordReset = false;
  bool _isDeletingAccount = false;

  Future<void> _pickCurrency() async {
    final l10n = AppLocalizations.of(context);
    final current = AuthScope.of(context).profile?.preferredCurrency;

    final result = await showModalBottomSheet<_PickerResult<String?>>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.settingsCurrencyPickerTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              title: Text(l10n.settingsCurrencyClearOption),
              trailing: current == null ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(const _PickerResult<String?>(null)),
            ),
            for (final code in commonCurrencyCodes)
              ListTile(
                title: Text(code),
                trailing: current == code ? const Icon(Icons.check) : null,
                onTap: () =>
                    Navigator.of(sheetContext)
                        .pop(_PickerResult<String?>(code)),
              ),
          ],
        ),
      ),
    );

    // Sheet dismissed without a selection (back/swipe/tap-outside) returns
    // a bare `null` `result` -- distinct from `_PickerResult(null)`, which
    // is a real "Not set" selection. Without this wrapper, both would be
    // indistinguishable and dismissing the sheet would silently clear the
    // preferred currency.
    if (!mounted || result == null) return;

    setState(() => _isSavingCurrency = true);
    try {
      await widget.profileRepository.setPreferredCurrency(result.value);
      if (!mounted) return;
      await AuthScope.of(context).refreshProfile();
    } on ProfileFailure catch (failure) {
      if (!mounted) return;
      final message = failure.code == ProfileFailureCode.invalidCurrency
          ? l10n.settingsCurrencyInvalidError
          : l10n.authGenericError;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
    } finally {
      if (mounted) setState(() => _isSavingCurrency = false);
    }
  }

  Future<void> _pickLanguage() async {
    final l10n = AppLocalizations.of(context);
    final localeController = LocaleScope.of(context);
    final current = localeController.locale?.languageCode;

    final result = await showModalBottomSheet<_PickerResult<String?>>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.settingsLanguagePickerTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            ListTile(
              title: Text(l10n.settingsLanguageSystemOption),
              trailing: current == null ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(const _PickerResult<String?>(null)),
            ),
            ListTile(
              title: Text(l10n.settingsLanguageEnglishOption),
              trailing: current == 'en' ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(const _PickerResult<String?>('en')),
            ),
            ListTile(
              title: Text(l10n.settingsLanguageSpanishOption),
              trailing: current == 'es' ? const Icon(Icons.check) : null,
              onTap: () =>
                  Navigator.of(sheetContext)
                      .pop(const _PickerResult<String?>('es')),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;
    final code = result.value;
    await localeController.setLocale(code == null ? null : Locale(code));
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context);
    final email = widget.authRepository.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
      return;
    }

    setState(() => _isSendingPasswordReset = true);
    try {
      await widget.authRepository.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsChangePasswordConfirmation)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.authGenericError)));
    } finally {
      if (mounted) setState(() => _isSendingPasswordReset = false);
    }
  }

  /// A legal document row: opens [uri] in the system browser when configured;
  /// otherwise keeps the "not available yet" placeholder. A failed launch shows
  /// one localized message -- never the URL or an exception.
  Future<void> _openLegalDocument(Uri? uri, String title) async {
    if (uri == null) {
      _openLegalPlaceholder(title);
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await _linkOpener.open(uri);
    if (!opened && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsLegalLinkOpenFailed)),
      );
    }
  }

  void _openLegalPlaceholder(String title) {
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlaceholderScreen(
          title: title,
          description: l10n.settingsLegalPlaceholderDescription,
          icon: Icons.description_outlined,
        ),
      ),
    );
  }

  Future<void> _confirmAndDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final username = AuthScope.of(context).profile?.username ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          _DeleteAccountDialog(username: username, l10n: l10n),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    try {
      await widget.accountRepository.deleteAccount();
      if (!mounted) return;
      // Local sign-out only after a confirmed successful delete -- never
      // before. Wrapped in try/catch that discards any exception: the
      // installed gotrue SDK clears local session state and fires
      // `signedOut` synchronously, unconditionally, before it ever attempts
      // the network revoke call that could throw here (the account is
      // already gone server-side at this point) -- see docs/DECISIONS.md.
      // The router reacts to the resulting signedOut event with no further
      // action needed here, and no error must be shown for this specific,
      // already-guaranteed-safe exception.
      try {
        await AuthScope.of(context).signOut();
      } catch (_) {
        // Intentionally swallowed -- see comment above.
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.deleteAccountGenericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = AuthScope.of(context).profile;
    final currencySubtitle =
        profile?.preferredCurrency ?? l10n.settingsCurrencyNotSet;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsScreenTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SettingsRow(
            icon: Icons.attach_money,
            title: l10n.settingsCurrencyRowTitle,
            subtitle: currencySubtitle,
            trailing: _isSavingCurrency
                ? const InlineSpinner(size: 20)
                : const Icon(Icons.chevron_right),
            onTap: _isSavingCurrency ? null : _pickCurrency,
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsRow(
            icon: Icons.language,
            title: l10n.settingsLanguageRowTitle,
            onTap: _pickLanguage,
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsRow(
            icon: Icons.lock_outline,
            title: l10n.settingsChangePasswordRowTitle,
            subtitle: l10n.settingsChangePasswordRowSubtitle,
            trailing: _isSendingPasswordReset
                ? const InlineSpinner(size: 20)
                : const Icon(Icons.chevron_right),
            onTap: _isSendingPasswordReset ? null : _changePassword,
          ),
          const SizedBox(height: AppSpacing.md),
          // ROADMAP.md Phase 12's dedicated "Privacy settings placeholder"
          // task -- distinct from the Privacy Policy *document* row below.
          // No toggles/backend fields/tracking/permissions: this is only
          // the minimal placeholder ROADMAP.md actually asks for.
          _SettingsRow(
            icon: Icons.shield_outlined,
            title: l10n.settingsPrivacySettingsRowTitle,
            onTap: () =>
                _openLegalPlaceholder(l10n.settingsPrivacySettingsRowTitle),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: l10n.settingsPrivacyPolicyRowTitle,
            trailing: _legalConfig.privacyPolicyUri == null
                ? null
                : const Icon(Icons.open_in_new),
            onTap: () => _openLegalDocument(
              _legalConfig.privacyPolicyUri,
              l10n.settingsPrivacyPolicyRowTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SettingsRow(
            icon: Icons.article_outlined,
            title: l10n.settingsTermsOfServiceRowTitle,
            trailing: _legalConfig.termsOfServiceUri == null
                ? null
                : const Icon(Icons.open_in_new),
            onTap: () => _openLegalDocument(
              _legalConfig.termsOfServiceUri,
              l10n.settingsTermsOfServiceRowTitle,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SettingsRow(
            icon: Icons.delete_outline,
            title: l10n.settingsDeleteAccountRowTitle,
            subtitle: l10n.settingsDeleteAccountRowSubtitle,
            iconColor: AppColors.error,
            titleColor: AppColors.error,
            trailing: _isDeletingAccount ? const InlineSpinner(size: 20) : null,
            onTap: _isDeletingAccount ? null : _confirmAndDeleteAccount,
          ),
        ],
      ),
    );
  }
}

/// Wraps a picker's selected value so "the user explicitly picked `null`"
/// (e.g. a currency/language picker's "not set"/"system default" option)
/// stays distinguishable from "the sheet was dismissed with no selection"
/// (back/swipe/tap-outside), which `showModalBottomSheet` also reports as a
/// bare `null` result.
class _PickerResult<T> {
  const _PickerResult(this.value);

  final T value;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius),
          leading: Icon(icon, color: iconColor ?? AppColors.primary),
          title: Text(
            title,
            style: titleColor == null ? null : TextStyle(color: titleColor),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: trailing ?? const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.username, required this.l10n});

  final String username;
  final AppLocalizations l10n;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final matches = _controller.text.trim().toLowerCase() == widget.username;
      if (matches != _matches) setState(() => _matches = matches);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.deleteAccountDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountDialogMessage),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.deleteAccountDialogConfirmHint(widget.username)),
          const SizedBox(height: AppSpacing.sm),
          // The instruction above is plain text; naming the field itself lets a
          // screen reader say what to type when focus lands here (autofocus).
          Semantics(
            label: l10n.deleteAccountDialogConfirmHint(widget.username),
            child: TextField(controller: _controller, autofocus: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelAction),
        ),
        TextButton(
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            l10n.deleteAccountConfirmAction,
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}
