import 'package:beerapp/core/onboarding/age_gate_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_age_gate_storage.dart';

void main() {
  test(
    'starts unknown, then resolves to notAcknowledged from empty storage',
    () async {
      final controller = AgeGateController(storage: FakeAgeGateStorage());

      expect(controller.status, AgeGateStatus.unknown);

      await pumpEventQueue();

      expect(controller.status, AgeGateStatus.notAcknowledged);
    },
  );

  test(
    'resolves to acknowledged when storage already has the flag set',
    () async {
      final controller = AgeGateController(
        storage: FakeAgeGateStorage(initiallyAcknowledged: true),
      );

      await pumpEventQueue();

      expect(controller.status, AgeGateStatus.acknowledged);
    },
  );

  test(
    'acknowledge() persists and updates status, notifying listeners',
    () async {
      final storage = FakeAgeGateStorage();
      final controller = AgeGateController(storage: storage);
      await pumpEventQueue();

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.acknowledge();

      expect(controller.status, AgeGateStatus.acknowledged);
      expect(notified, isTrue);
      expect(await storage.isAcknowledged(), isTrue);
    },
  );
}
