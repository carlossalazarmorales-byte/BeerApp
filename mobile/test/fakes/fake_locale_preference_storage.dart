import 'package:beerapp/core/locale/locale_preference_storage.dart';

class FakeLocalePreferenceStorage implements LocalePreferenceStorage {
  FakeLocalePreferenceStorage({String? initialCode}) : _code = initialCode;

  String? _code;

  @override
  Future<String?> getLocaleCode() async => _code;

  @override
  Future<void> setLocaleCode(String? code) async => _code = code;
}
