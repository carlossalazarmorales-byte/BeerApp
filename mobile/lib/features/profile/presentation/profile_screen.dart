import 'package:flutter/material.dart';

import '../../../core/auth/auth_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_screen.dart';

/// Profile destination. Full profile editing (avatar, currency/units,
/// language preference) is Phase 12 — for now this only proves the real
/// username set via Supabase Auth/`/complete-profile` reaches the shell.
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

    return PlaceholderScreen(
      title: l10n.navProfile,
      description: name == null
          ? l10n.profileScreenDescription
          : l10n.profileScreenGreeting(name),
      icon: Icons.person_outline,
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
    );
  }
}
