import 'package:flutter/foundation.dart';

import 'age_gate_storage.dart';

enum AgeGateStatus { unknown, notAcknowledged, acknowledged }

/// Local-device gate for BeerApp's adult-audience acknowledgement. Kept
/// separate from [AuthController] since it has nothing to do with a
/// Supabase session — see the router, which merges both controllers into
/// one redirect decision so this gate cannot be bypassed by deep-linking
/// straight to an auth route.
class AgeGateController extends ChangeNotifier {
  AgeGateController({AgeGateStorage? storage})
    : _storage = storage ?? const SharedPreferencesAgeGateStorage() {
    _load();
  }

  final AgeGateStorage _storage;

  AgeGateStatus _status = AgeGateStatus.unknown;
  AgeGateStatus get status => _status;

  Future<void> _load() async {
    final acknowledged = await _storage.isAcknowledged();
    _status = acknowledged
        ? AgeGateStatus.acknowledged
        : AgeGateStatus.notAcknowledged;
    notifyListeners();
  }

  Future<void> acknowledge() async {
    await _storage.setAcknowledged(true);
    _status = AgeGateStatus.acknowledged;
    notifyListeners();
  }
}
