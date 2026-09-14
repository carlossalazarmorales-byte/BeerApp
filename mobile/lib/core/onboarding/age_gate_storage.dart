import 'package:shared_preferences/shared_preferences.dart';

/// Persists the local, device-only legal-drinking-age acknowledgement.
/// Abstracted so [AgeGateController] can be unit-tested with an in-memory
/// fake instead of touching a real platform channel.
abstract class AgeGateStorage {
  Future<bool> isAcknowledged();
  Future<void> setAcknowledged(bool value);
}

class SharedPreferencesAgeGateStorage implements AgeGateStorage {
  const SharedPreferencesAgeGateStorage();

  static const String _key = 'age_gate_acknowledged';

  @override
  Future<bool> isAcknowledged() async {
    final preferences = SharedPreferencesAsync();
    return await preferences.getBool(_key) ?? false;
  }

  @override
  Future<void> setAcknowledged(bool value) async {
    final preferences = SharedPreferencesAsync();
    await preferences.setBool(_key, value);
  }
}
