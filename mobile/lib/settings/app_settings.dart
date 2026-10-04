// M1 FE-4: interface language (Urdu or English), kept on the phone.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where [AppSettings] keeps its values between app starts.
abstract interface class SettingsStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
}

/// Keeps values in the phone's plain app storage (shared_preferences).
///
/// Only device settings go here, never patient data: this storage is not
/// encrypted. It is used because it can be read before login, while the local
/// database is locked until the LHW signs in (LI-8).
class SharedPreferencesStore implements SettingsStore {
  SharedPreferencesStore._(this._prefs);

  static Future<SharedPreferencesStore> open(Set<String> keys) async => SharedPreferencesStore._(
    await SharedPreferencesWithCache.create(cacheOptions: SharedPreferencesWithCacheOptions(allowList: keys)),
  );

  final SharedPreferencesWithCache _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);
}

/// Keeps values in memory only, for tests.
class MemorySettingsStore implements SettingsStore {
  final Map<String, String> values = {};

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

/// Settings that belong to the phone rather than to a user's records.
///
/// The interface language is Urdu by default; the LHW can switch to English
/// (M1 FE-4). The whole app follows it: Urdu right to left, English left to
/// right. Voice guidance reads Urdu labels only (LI-6), so it is available
/// only while the app is in Urdu.
class AppSettings extends ChangeNotifier {
  /// Reads the saved language from [store]; without a store, nothing is saved.
  AppSettings({SettingsStore? store}) : this._(store ?? MemorySettingsStore());

  AppSettings._(SettingsStore store) : _store = store, _locale = _localeFor(store.getString(_languageKey));

  /// Opens the phone's storage and reads the saved language.
  static Future<AppSettings> load() async => AppSettings(store: await SharedPreferencesStore.open({_languageKey}));

  static const Locale urdu = Locale('ur');
  static const Locale english = Locale('en');

  /// The languages the app offers, in the order the switch shows them.
  static const List<Locale> languages = [urdu, english];

  static const String _languageKey = 'interface_language';

  final SettingsStore _store;
  Locale _locale;

  Locale get locale => _locale;
  bool get isUrdu => _locale == urdu;

  /// Whether voice guidance (M3 FE-3) may speak. Off in English.
  bool get voiceGuidanceAvailable => voiceGuidanceAvailableFor(_locale);

  /// The same rule for a screen that only knows its locale, for example
  /// `Localizations.localeOf(context)`.
  static bool voiceGuidanceAvailableFor(Locale locale) => locale.languageCode == urdu.languageCode;

  /// Switches the whole app to [locale] and saves the choice on the phone.
  Future<void> setLocale(Locale locale) async {
    final chosen = _localeFor(locale.languageCode);
    if (chosen == _locale) return;
    _locale = chosen;
    notifyListeners();
    await _store.setString(_languageKey, chosen.languageCode);
  }

  /// Anything other than English, including nothing saved yet, means Urdu.
  static Locale _localeFor(String? languageCode) => languageCode == english.languageCode ? english : urdu;
}
