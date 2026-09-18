import 'package:beerapp/core/locale/locale_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_locale_preference_storage.dart';

void main() {
  test('starts null (follow system) from empty storage', () async {
    final controller = LocaleController(storage: FakeLocalePreferenceStorage());

    expect(controller.locale, isNull);

    await pumpEventQueue();

    expect(controller.locale, isNull);
  });

  test('resolves to the stored language code', () async {
    final controller = LocaleController(
      storage: FakeLocalePreferenceStorage(initialCode: 'es'),
    );

    await pumpEventQueue();

    expect(controller.locale, const Locale('es'));
  });

  test('setLocale persists and updates locale, notifying listeners', () async {
    final storage = FakeLocalePreferenceStorage();
    final controller = LocaleController(storage: storage);
    await pumpEventQueue();

    var notified = false;
    controller.addListener(() => notified = true);

    await controller.setLocale(const Locale('es'));

    expect(controller.locale, const Locale('es'));
    expect(notified, isTrue);
    expect(await storage.getLocaleCode(), 'es');
  });

  test('setLocale(null) clears the override back to "follow system"', () async {
    final storage = FakeLocalePreferenceStorage(initialCode: 'en');
    final controller = LocaleController(storage: storage);
    await pumpEventQueue();
    expect(controller.locale, const Locale('en'));

    await controller.setLocale(null);

    expect(controller.locale, isNull);
    expect(await storage.getLocaleCode(), isNull);
  });
}
