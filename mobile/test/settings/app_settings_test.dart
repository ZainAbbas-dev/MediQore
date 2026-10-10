import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/settings/app_settings.dart';

void main() {
  test('starts in Urdu when nothing is saved', () {
    final settings = AppSettings(store: MemorySettingsStore());
    expect(settings.locale, AppSettings.urdu);
    expect(settings.isUrdu, isTrue);
  });

  test('switching to English saves the choice', () async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store: store);
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setLocale(AppSettings.english);

    expect(settings.locale, AppSettings.english);
    expect(settings.isUrdu, isFalse);
    expect(notified, 1);
    expect(AppSettings(store: store).locale, AppSettings.english, reason: 'read back on the next app start');
  });

  test('choosing the current language again changes nothing', () async {
    final settings = AppSettings(store: MemorySettingsStore());
    var notified = 0;
    settings.addListener(() => notified++);
    await settings.setLocale(AppSettings.urdu);
    expect(notified, 0);
  });

  test('an unknown saved or requested language falls back to Urdu', () async {
    final store = MemorySettingsStore()..values['interface_language'] = 'fr';
    expect(AppSettings(store: store).locale, AppSettings.urdu);

    final settings = AppSettings(store: MemorySettingsStore());
    await settings.setLocale(AppSettings.english);
    await settings.setLocale(const Locale('fr'));
    expect(settings.locale, AppSettings.urdu);
  });

  test('a test build\'s server address is saved on the phone', () async {
    final store = MemorySettingsStore();
    final settings = AppSettings(store: store);
    expect(settings.serverAddress, isNull, reason: 'the build-time address until one is chosen');

    await settings.setServerAddress('http://192.168.1.20:3000/api/v1');

    expect(AppSettings(store: store).serverAddress, 'http://192.168.1.20:3000/api/v1', reason: 'read back on the next app start');
    expect(AppSettings.storedKeys, contains('server_address'));
  });
}
