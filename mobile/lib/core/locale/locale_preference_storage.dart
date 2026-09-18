import 'package:shared_preferences/shared_preferences.dart';

/// Persists the local, device-only language override. `null` means "follow
/// the system locale" — this is never a server-side profile field (see
/// docs/DECISIONS.md for why a `preferred_language` column was rejected in
/// favor of this local-only pattern). Abstracted so [LocaleController] can
/// be unit-tested with an in-memory fake, mirroring
/// `core/onboarding/age_gate_storage.dart`.
abstract class LocalePreferenceStorage {
  /// Returns the stored language code (`'en'`, `'es'`), or `null` if the
  /// user has never overridden the system locale.
  Future<String?> getLocaleCode();

  /// `null` clears the override back to "follow system".
  Future<void> setLocaleCode(String? code);
}

class SharedPreferencesLocalePreferenceStorage
    implements LocalePreferenceStorage {
  const SharedPreferencesLocalePreferenceStorage();

  static const String _key = 'locale_override';

  @override
  Future<String?> getLocaleCode() async {
    final preferences = SharedPreferencesAsync();
    return preferences.getString(_key);
  }

  @override
  Future<void> setLocaleCode(String? code) async {
    final preferences = SharedPreferencesAsync();
    if (code == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, code);
    }
  }
}
