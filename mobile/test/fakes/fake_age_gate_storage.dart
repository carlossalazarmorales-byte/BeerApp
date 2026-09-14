import 'package:beerapp/core/onboarding/age_gate_storage.dart';

class FakeAgeGateStorage implements AgeGateStorage {
  FakeAgeGateStorage({bool initiallyAcknowledged = false})
    : _acknowledged = initiallyAcknowledged;

  bool _acknowledged;

  @override
  Future<bool> isAcknowledged() async => _acknowledged;

  @override
  Future<void> setAcknowledged(bool value) async => _acknowledged = value;
}
