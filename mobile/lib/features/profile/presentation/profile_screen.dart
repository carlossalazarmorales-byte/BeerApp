import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_routes.dart';
import '../../../core/auth/auth_scope.dart';
import '../../../design_system/components/cards/app_card.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radii.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Profile destination. Full profile editing (avatar, currency/units,
/// language preference) is Phase 12 — this screen currently shows the
/// signed-in identity plus an entry point to Statistics (Phase 9). Owns its
/// `Scaffold` directly rather than the shared `PlaceholderScreen` widget --
/// that widget's layout is fixed (icon/title/description/badge only) and
/// has no slot for a navigable card.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await AuthScope.of(context).signOut();
      // Success: the router reacts to the resulting signedOut event -- no
      // explicit navigation here, and no need to reset _isSigningOut since
      // this screen is about to be replaced.
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).authGenericError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = AuthScope.of(context).profile;
    final name = profile?.displayName ?? profile?.username;
    final description = name == null
        ? l10n.profileScreenDescription
        : l10n.profileScreenGreeting(name);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navProfile),
        actions: [
          IconButton(
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            tooltip: l10n.logoutAction,
            onPressed: _isSigningOut ? null : _signOut,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.navProfile,
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            padding: EdgeInsets.zero,
            // ListTile needs a Material ancestor for its ink splashes;
            // AppCard's own background is an opaque DecoratedBox, which sits
            // between ListTile and the nearest real Material otherwise --
            // MaterialType.transparency paints nothing itself, so AppCard's
            // rounded card background still shows through unchanged.
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius),
                leading: const Icon(
                  Icons.bar_chart_outlined,
                  color: AppColors.primary,
                ),
                title: Text(l10n.profileStatisticsCardTitle),
                subtitle: Text(l10n.profileStatisticsCardSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.statistics),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: AppRadii.lgRadius),
                leading: const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.primary,
                ),
                title: Text(l10n.profileAchievementsCardTitle),
                subtitle: Text(l10n.profileAchievementsCardSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.achievements),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
