# Urdu font

`JameelNooriNastaleeq.ttf` is the Jameel Noori Nastaleeq font that the scope bundles with the app for all Urdu text (Tools table; M3 FE-1). The team added it in P0-2.

- `pubspec.yaml` declares it as the font family `JameelNooriNastaleeq`.
- `lib/theme/app_theme.dart` uses it as the app-wide font, with a taller line height for Nastaliq.
- `test/app_test.dart` loads the real font in the small-phone overflow test, so the test measures real Nastaliq line heights.

Keep the file name unchanged. If the font is ever replaced, re-run `flutter test` and check every screen on a small phone.
