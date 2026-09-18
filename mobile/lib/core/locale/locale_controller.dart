import 'package:flutter/widgets.dart';

import 'locale_preference_storage.dart';

/// Local-device language override, independent of any Supabase session or
/// profile field — see `docs/DECISIONS.md` for why this is a local
/// preference (mirroring the existing device-locale-following behavior)
/// rather than a `profiles` column. Only currently-shipped locales (EN/ES)
/// are ever stored; `null` means "follow the system locale".
class LocaleController extends ChangeNotifier {
  LocaleController({LocalePreferenceStorage? storage})
    : _storage = storage ?? const SharedPreferencesLocalePreferenceStorage() {
    _load();
  }

  final LocalePreferenceStorage _storage;

  Locale? _locale;

  /// `null` means "follow system" -- passed straight through to
  /// `MaterialApp.router(locale: ...)`.
  Locale? get locale => _locale;

  Future<void> _load() async {
    final code = await _storage.getLocaleCode();
    _locale = code == null ? null : Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    await _storage.setLocaleCode(locale?.languageCode);
    _locale = locale;
    notifyListeners();
  }
}
